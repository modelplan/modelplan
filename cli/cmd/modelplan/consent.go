package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
)

type consentChoice struct {
	Tool     string   `json:"tool"`
	Name     string   `json:"name"`
	Selected bool     `json:"selected"`
	ReaderID string   `json:"readerId"`
	Backend  string   `json:"backend"`
	Access   string   `json:"access"`
	Status   string   `json:"status"`
	Beta     bool     `json:"beta"`
	Group    string   `json:"group"`
	Hosts    []string `json:"hosts"`
	Region   string   `json:"region,omitempty"`
	KeyEnv   string   `json:"keyEnv,omitempty"`
}

func choice(t detect.Tool, mode string) consentChoice {
	x := consentChoice{Tool: t.ProviderID, Name: t.DisplayName, ReaderID: t.ReaderID, Backend: t.Preferred, Status: "available", Beta: t.Beta, Group: "standard", Hosts: consentHosts(t.ProviderID, "")}
	if t.CodexBar.Access == "browser-session" && (t.Preferred == "codexbar" || strings.HasPrefix(t.ReaderID, "codexbar:") || strings.HasPrefix(t.Status, "codexbar-")) {
		x.Group = "advanced"
	}
	x.Access = "Read this tool's existing sign-in and authenticate only to its provider for usage; no credential is stored by ModelPlan."
	if t.ProviderID == "codex" {
		x.Access = "Ask Codex's own runtime and read local session records; no credential is imported."
	}
	if t.ProviderID == "qwen" {
		x.Access = "Read local Qwen usage records; no credential is sent and no remaining quota is inferred."
	}
	if t.ProviderID == "cursor" {
		x.Access = "Read the local editor state.vscdb read-only; Undocumented Cursor endpoints receive the saved sign-in."
	}
	if mode == consent.Passive {
		x.Access = "Read credential-free local records/runtime data or explicitly configured keys only; no automatic credential or Keychain import."
	}
	switch {
	case t.Preferred == "off":
		x.Status = "catalogue-off"
	case t.Preferred == "native" && strings.HasPrefix(t.ReaderID, "codexbar:"):
		x.Status = "native-not-supported"
	case t.Preferred == "codexbar" && t.HelperStatus() != "":
		x.Status = t.HelperStatus()
	case t.Preferred == "codexbar" && mode != consent.Automatic:
		x.Status = "privacy-blocked"
	case t.Preferred == "codexbar":
		x.Access = "Via audited CodexBar with CODEXBAR_DISABLE_KEYCHAIN_ACCESS=1: read this tool's own login or audited read-only, no-quota CLI command; no token refresh or browser import."
		if t.CodexBar.Access == "browser-session" {
			x.Group = "advanced"
			x.Status = "browser-session-explicit-only"
			x.Access = "Browser session (advanced): off by default; use modelplan connect " + t.ProviderID + " --browser-session for a separate explanation and confirmation."
		}
	}
	if len(x.Hosts) == 0 && x.Status == "available" {
		x.Status = "provider-hosts-unknown"
	}
	x.Access += " Destinations / 凭据接收主机: " + strings.Join(x.Hosts, ", ")
	x.Selected = x.Status == "available"
	return x
}
func connectDetected(stdin io.Reader, stdout, stderr io.Writer, st *store.Store, c common, privacy string) int {
	s, err := consent.Load(consent.Path())
	if err != nil {
		fmt.Fprintln(stderr, err)
		return exitErr
	}
	if privacy != "" {
		if privacy != consent.Automatic && privacy != consent.Passive {
			fmt.Fprintln(stderr, "privacy must be automatic or passive")
			return exitUsage
		}
		s.Privacy = privacy
	}
	mode := s.Effective(env("MODELPLAN_READERS", ""))
	rows := []consentChoice{}
	legacy, _ := quota.LoadConnections(quotaPaths(st).ConnectionsFile)
	for _, tool := range detection(st).Tools {
		if tool.Detected {
			if tool.CodexBar.Access == "not-read" && (strings.HasPrefix(tool.ReaderID, "codexbar:") || strings.HasPrefix(tool.Status, "codexbar-")) {
				continue
			}
			x := choice(tool, mode)
			if x.Backend == "native" {
				r, exists := s.Tools[x.Tool]
				if !exists {
					for _, l := range legacy {
						if l.Provider == x.Tool {
							r.Region = l.Region
							r.KeyEnv = l.KeyEnv
						}
					}
				}
				setChoiceRegion(&x, r.Region, r.KeyEnv)
			}
			if mode == consent.Off {
				x.Status = "readers-off"
				x.Selected = false
			}
			rows = append(rows, x)
		}
	}
	if c.json {
		advanced := []consentChoice{}
		for _, x := range rows {
			if x.Group == "advanced" {
				advanced = append(advanced, x)
			}
		}
		return printJSON(stdout, map[string]any{"schemaVersion": 1, "dryRun": true, "privacy": s.Privacy, "effectivePrivacy": mode, "consentTextVersion": consent.TextVersion, "consentText": consent.Text, "tools": rows, "advanced": advanced})
	}
	if len(rows) == 0 {
		fmt.Fprintln(stdout, "No tools detected. / 未检测到工具。 Run modelplan detect for details.")
		return 0
	}
	fmt.Fprintln(stdout, consent.Text)
	if c.lang != "en" {
		fmt.Fprintln(stdout, "允许此账户下的 App、插件和所有 CLI 副本读取所选工具的用量。凭据仅发给对应服务商，不发送给 ModelPlan，也不保存；macOS 可能请求钥匙串权限。可在设置中关闭。")
	}
	for _, group := range []string{"standard", "advanced"} {
		if group == "standard" {
			fmt.Fprintln(stdout, "Standard / 标准")
		} else {
			fmt.Fprintln(stdout, "Advanced browser sessions / 高级浏览器会话 (separate command required)")
		}
		for i, x := range rows {
			if x.Group != group {
				continue
			}
			mark := " "
			if x.Selected {
				mark = "x"
			}
			beta := ""
			if x.Beta {
				beta = " · beta"
			}
			fmt.Fprintf(stdout, "[%s] %d. %s%s · %s · %s\n", mark, i+1, x.Name, beta, x.Status, x.Access)
		}
	}
	fmt.Fprint(stdout, "Selection / 选择 (Enter=checked; numbers separated by commas; none=not now): ")
	if stdin == nil {
		fmt.Fprintln(stderr, "interactive input required; use --json to preview")
		return exitUsage
	}
	scanner := bufio.NewScanner(io.LimitReader(stdin, 8192))
	if !scanner.Scan() {
		fmt.Fprintln(stdout, "Not now; no permissions changed.")
		return 0
	}
	selection := strings.TrimSpace(scanner.Text())
	if strings.EqualFold(selection, "none") {
		rememberOffered(rows)
		fmt.Fprintln(stdout, "Not now; no permissions changed.")
		return 0
	}
	if selection != "" {
		for i := range rows {
			rows[i].Selected = false
		}
		for _, part := range strings.Split(selection, ",") {
			n, err := strconv.Atoi(strings.TrimSpace(part))
			if err != nil || n < 1 || n > len(rows) || rows[n-1].Status != "available" {
				fmt.Fprintln(stderr, "invalid selection")
				return exitUsage
			}
			rows[n-1].Selected = true
		}
	}
	selected := false
	for _, r := range rows {
		selected = selected || r.Selected
	}
	if !selected {
		fmt.Fprintln(stdout, "No tools enabled.")
		return 0
	}
	fmt.Fprint(stdout, "Allow selected tools? / 允许所选工具？ [y/N]: ")
	if !scanner.Scan() {
		fmt.Fprintln(stdout, "Not now; no permissions changed.")
		return 0
	}
	answer := strings.ToLower(strings.TrimSpace(scanner.Text()))
	if answer != "y" && answer != "yes" {
		if answer == "n" || answer == "no" {
			rememberOffered(rows)
		}
		fmt.Fprintln(stdout, "Not now; no permissions changed.")
		return 0
	}
	err = consent.Change(consent.Path(), func(current *consent.State) error {
		if current.Generation != s.Generation {
			return errors.New("consent changed while choosing; retry")
		}
		current.Privacy = s.Privacy
		for _, x := range rows {
			if x.Group == "advanced" {
				continue
			}
			if err := consent.Set(current, x.Tool, x.Selected, x.ReaderID, x.Backend, time.Now()); err != nil {
				return err
			}
			r := current.Tools[x.Tool]
			r.Region = x.Region
			r.KeyEnv = x.KeyEnv
			current.Tools[x.Tool] = r
		}
		return nil
	})
	if err != nil {
		fmt.Fprintln(stderr, err)
		return exitErr
	}
	home, _ := os.UserHomeDir()
	for _, x := range rows {
		if x.Group == "advanced" {
			continue
		}
		if x.Tool == "gemini" {
			err = localusage.SetGemini(home, x.Selected)
		}
		if x.Tool == "qwen" {
			err = localusage.SetQwen(home, x.Selected)
		}
		if err != nil {
			fmt.Fprintln(stderr, "local usage setting:", err)
			return exitErr
		}
	}
	fmt.Fprintln(stdout, "Consent saved. No reader was run. / 已保存授权；未运行读取器。")
	return 0
}

func rememberOffered(rows []consentChoice) {
	// Not now preserves existing grants but suppresses automatic repeat hints.
	_ = consent.Change(consent.Path(), func(s *consent.State) error {
		for _, x := range rows {
			s.Hinted[x.Tool] = true
		}
		return nil
	})
}

func disconnectTools(args []string, all bool, stdout, stderr io.Writer, st *store.Store, c common) int {
	if (all && len(args) != 0) || (!all && len(args) != 1) {
		fmt.Fprintln(stderr, "usage: modelplan disconnect <tool|--all>")
		return exitUsage
	}
	s, err := consent.Load(consent.Path())
	if err != nil {
		fmt.Fprintln(stderr, err)
		return exitErr
	}
	ids := []string{}
	if all {
		for id := range s.Tools {
			ids = append(ids, id)
		}
		for _, tool := range detection(st).Tools {
			ids = append(ids, tool.ProviderID)
		}
		ids = append(ids, providerIDs()...)
	} else {
		ids = append(ids, strings.ToLower(args[0]))
	}
	for i, id := range ids {
		if id == "claude-code" {
			ids[i] = "claude"
		}
		if !consent.ValidTool(ids[i]) {
			fmt.Fprintln(stderr, "invalid tool ID")
			return exitUsage
		}
	}
	sort.Strings(ids)
	unique := ids[:0]
	for _, id := range ids {
		if len(unique) == 0 || id != unique[len(unique)-1] {
			unique = append(unique, id)
		}
	}
	ids = unique
	// Revoke first. A purge failure must never leave a tool enabled.
	err = consent.Change(consent.Path(), func(current *consent.State) error {
		for _, id := range ids {
			if err := consent.Set(current, id, false, "", "", time.Now()); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		fmt.Fprintln(stderr, "disconnect: consent not changed:", err)
		return exitErr
	}
	if err == nil {
		for _, id := range ids {
			p := quotaPaths(st)
			if quota.ProviderName(id) != "" {
				err = quota.SetConnection(p.ConnectionsFile, quota.QuotaSource{Provider: id, Backend: quota.BackendNative, Enabled: false})
				if err != nil {
					break
				}
			}
			if err = quota.ForgetTool(quotaPaths(st), id); err != nil {
				break
			}
			if s.Tools[id].BrowserCookieCache {
				if err = quota.ClearBrowserCookies(context.Background(), quotaPaths(st), id); err != nil {
					break
				}
				err = consent.Change(consent.Path(), func(current *consent.State) error {
					r := current.Tools[id]
					if r.Allowed {
						return errors.New("consent changed during cookie cleanup; retry")
					}
					r.BrowserCookieCache = false
					current.Tools[id] = r
					return nil
				})
				if err != nil {
					break
				}
			}
		}
	}
	if err != nil {
		fmt.Fprintln(stderr, "disconnect: permissions revoked; cache cleanup:", err)
		return exitErr
	}
	if c.json {
		ss, err := quota.Selections(quotaPaths(st))
		if err != nil {
			fmt.Fprintln(stderr, err)
			return exitErr
		}
		return printJSON(stdout, map[string]any{"disconnected": ids, "readingsDeleted": true, "connections": ss})
	}
	fmt.Fprintln(stdout, "Disconnected; cached readings deleted / 已断开并删除缓存读数:", strings.Join(ids, ", "))
	return 0
}

// A newly found tool gets a single CLI hint. Explicit previews/detection never
// mark it seen, and previous consent/refusal/revocation is never asked again.
func detectedHint(st *store.Store, stderr io.Writer, c common) {
	if c.json {
		return
	}
	s, err := consent.Load(consent.Path())
	if err != nil {
		return
	}
	ids := []string{}
	for _, t := range detection(st).Tools {
		if _, decided := s.Tools[t.ProviderID]; t.Detected && t.Preferred != "off" && !decided && !s.Hinted[t.ProviderID] {
			ids = append(ids, t.ProviderID)
		}
	}
	if len(ids) == 0 {
		return
	}
	err = consent.Change(consent.Path(), func(current *consent.State) error {
		for _, id := range ids {
			current.Hinted[id] = true
		}
		return nil
	})
	if err == nil {
		fmt.Fprintln(stderr, "New tool(s) detected / 检测到新工具:", strings.Join(ids, ", ")+"; modelplan connect --detected")
	}
}
