package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"runtime"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// codexbarCmd: `modelplan codexbar status|enable|disable|fetch|refresh`. Enabling is the user's
// consent to run CodexBar for those providers; the first run fetches the pinned CodexBar CLI.
func codexbarCmd(args []string, stdout, stderr io.Writer, st *store.Store, c common, quiet bool) int {
	sub, rest := "status", []string(nil)
	if len(args) > 0 {
		sub, rest = args[0], args[1:]
	}
	p := quotaPaths(st)
	home, _ := os.UserHomeDir()
	en := c.lang == "en"
	say := func(zh, enText string, a ...any) {
		if quiet {
			return
		}
		if en {
			fmt.Fprintf(stdout, enText+"\n", a...)
		} else {
			fmt.Fprintf(stdout, zh+"\n", a...)
		}
	}
	switch sub {
	case "status":
		return codexbarStatus(stdout, p, st, home, c)

	case "enable", "disable":
		if sub == "enable" && len(rest) == 0 {
			fmt.Fprintln(stderr, "usage: modelplan codexbar enable <provider…>  (copilot, cursor, kiro, opencodego, zai)")
			return exitUsage
		}
		now := quota.CodexBarEnabled(p.CodexBarFile)
		next := map[string]bool{}
		for _, x := range now {
			next[x] = true
		}
		for _, x := range rest {
			next[strings.ToLower(x)] = sub == "enable"
		}
		if sub == "disable" && len(rest) == 0 {
			next = map[string]bool{}
		}
		var list []string
		for x, on := range next {
			if on {
				list = append(list, x)
			}
		}
		if err := quota.SetCodexBarEnabled(p.CodexBarFile, list); err != nil {
			fmt.Fprintln(stderr, "codexbar:", err)
			return exitUsage
		}
		for _, x := range list {
			if o, ok := quota.Overridden(p, x); ok {
				fmt.Fprintf(stderr, "codexbar: %s is set to %s in connections.json, which decides it; run `modelplan connect %s --backend codexbar` to read it through CodexBar\n", x, o.Backend, x)
			}
		}
		enabled := quota.CodexBarActive(p)
		if len(enabled) == 0 {
			say("已关闭：不再通过 CodexBar 读取任何套餐。", "Off: no plan is read through CodexBar.")
			return 0
		}
		say("通过 CodexBar 读取：%s", "Reading through CodexBar: %s", strings.Join(enabled, ", "))
		if sub == "enable" && !c.offline {
			if quota.CodexBarFetchDue(st.Dir, time.Now()) {
				say("正在后台下载 CodexBar CLI %s（macOS 约 14 MB，Linux 约 53 MB），按锁定的 SHA-256 校验后放在 %s/codexbar。",
					"Fetching CodexBar CLI %s in the background (about 14 MB on macOS, 53 MB on Linux), checked against the pinned SHA-256, into %s/codexbar.",
					quota.CodexBarVersion, st.Dir)
				_ = startDetached("codexbar", "fetch", "--quiet")
			} else {
				_ = startDetached("codexbar", "refresh", "--quiet")
			}
			say("几分钟后运行 modelplan codexbar 查看结果；每家需要的登录或 key 由 CodexBar 保管。",
				"Run `modelplan codexbar` in a minute for the result; CodexBar keeps each vendor's sign-in or key.")
		}
		return 0

	case "fetch":
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()
		bin, err := quota.FetchCodexBar(ctx, st.Dir, os.Getenv("MODELPLAN_CODEXBAR_BASE"))
		if err != nil {
			fmt.Fprintln(stderr, "codexbar fetch:", err)
			bin = quota.CodexBarBin(st.Dir, home) // a copy the user installed, meanwhile
		} else {
			say("CodexBar CLI %s：%s", "CodexBar CLI %s: %s", quota.CodexBarVersion, bin)
		}
		if bin != "" && len(quota.CodexBarActive(p)) > 0 {
			_ = quota.RefreshCodexBar(ctx, p, bin, time.Now())
		}
		if err != nil {
			return exitErr
		}
		return 0

	case "refresh":
		bin := quota.CodexBarBin(st.Dir, home)
		err := quota.RefreshCodexBar(context.Background(), p, bin, time.Now())
		if err != nil && !quiet {
			fmt.Fprintln(stderr, "codexbar:", err)
			return exitErr
		}
		if !quiet {
			return codexbarStatus(stdout, p, st, home, c)
		}
		return 0
	}
	fmt.Fprintln(stderr, "usage: modelplan codexbar [status|enable <provider…>|disable [provider…]|fetch|refresh]")
	return exitUsage
}

func codexbarStatus(stdout io.Writer, p quota.Paths, st *store.Store, home string, c common) int {
	enabled := quota.CodexBarActive(p)
	bin := quota.CodexBarBin(st.Dir, home)
	r := quota.ReadPermitted(p, time.Now())
	type row struct {
		ID     string `json:"id"`
		Name   string `json:"name"`
		Status string `json:"status"`
		Reason string `json:"reason,omitempty"`
		Needs  string `json:"needs,omitempty"`
	}
	var rows []row
	for _, s := range r.Sources {
		id, ok := strings.CutPrefix(s.Source, "codexbar:")
		if !ok {
			continue
		}
		x := row{ID: id, Name: quota.CodexBarProviders[id].Name, Status: s.Status, Reason: s.Reason}
		if s.Status != "ok" {
			x.Needs = strings.ReplaceAll(quota.CodexBarProviders[id].Needs, "<codexbar>", codexbarCommand(bin))
		}
		rows = append(rows, x)
	}
	if c.json {
		return printJSON(stdout, map[string]any{"schemaVersion": 1, "enabled": nonNilList(enabled), "binary": bin, "pinnedVersion": quota.CodexBarVersion,
			"pinned": quota.CodexBarPinned(st.Dir), "fetch": quota.CodexBarFetchResult(st.Dir), "platform": runtime.GOOS + "/" + runtime.GOARCH, "providers": rows})
	}
	en := c.lang == "en"
	if len(enabled) == 0 {
		if en {
			fmt.Fprintln(stdout, "CodexBar: off. `modelplan codexbar enable cursor zai` reads those plans through CodexBar's CLI.")
		} else {
			fmt.Fprintln(stdout, "CodexBar：未开启。`modelplan codexbar enable cursor zai` 会通过 CodexBar CLI 读取这些套餐的额度。")
		}
		return 0
	}
	fmt.Fprintf(stdout, "CodexBar CLI: %s\n", codexbarBinText(bin, st.Dir, en))
	for _, x := range rows {
		line := fmt.Sprintf("  %-12s %-11s %s", x.ID, x.Status, x.Reason)
		fmt.Fprintln(stdout, strings.TrimRight(line, " "))
		if x.Needs != "" {
			fmt.Fprintf(stdout, "  %-12s → %s\n", "", x.Needs)
		}
	}
	return 0
}

// codexbarBinText: which CodexBar CLI runs, and whether it is the pinned release.
func codexbarBinText(bin, cache string, en bool) string {
	fetch := quota.CodexBarFetchResult(cache)
	switch {
	case bin == "" && strings.Contains(fetch, "failed"):
		return map[bool]string{true: "not available; fetch ", false: "不可用；下载结果 "}[en] + fetch
	case bin == "":
		return map[bool]string{true: "not fetched yet", false: "尚未下载"}[en]
	case quota.CodexBarPinned(cache) && strings.HasPrefix(bin, cache):
		return bin + map[bool]string{true: " (pinned ", false: "（锁定版 "}[en] + quota.CodexBarVersion + map[bool]string{true: ")", false: "）"}[en]
	case os.Getenv("MODELPLAN_CODEXBAR") != "":
		return bin + " (MODELPLAN_CODEXBAR)"
	}
	note := map[bool]string{true: " (installed by you; used until the pinned ", false: "（你自己装的；锁定版 "}[en] + quota.CodexBarVersion +
		map[bool]string{true: " is fetched", false: " 下载好之前临时用它"}[en]
	if strings.Contains(fetch, "failed") {
		note += "; " + fetch
	}
	return bin + note + map[bool]string{true: ")", false: "）"}[en]
}

// codexbarCommand: how the user runs the same CodexBar CLI in a terminal (quoted if needed).
func codexbarCommand(bin string) string {
	if bin == "" {
		return "codexbar"
	}
	if strings.ContainsAny(bin, " '\"") {
		return "'" + strings.ReplaceAll(bin, "'", `'\''`) + "'"
	}
	return bin
}

func nonNilList(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}
