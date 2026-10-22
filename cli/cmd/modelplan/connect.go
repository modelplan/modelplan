package main

import (
	"context"
	"fmt"
	"io"
	"sort"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// connectCmd: `connect <provider>` chooses the backend that reads a provider (connections.json),
// `disconnect <provider>` turns it off (its codexbar.json setting too), `connections` shows the
// effective choice per provider without reading anything, and `connections refresh` asks the
// native readers now.
func connectCmd(cmd string, args []string, stdout, stderr io.Writer, st *store.Store, c common, quiet bool, backend, region, keyEnv string) int {
	p := quotaPaths(st)
	switch cmd {
	case "connect", "disconnect":
		if len(args) != 1 {
			fmt.Fprintf(stderr, "usage: modelplan %s <provider>  (%s)\n", cmd, strings.Join(providerIDs(), ", "))
			return exitUsage
		}
		prov := strings.ToLower(args[0])
		s := quota.QuotaSource{Provider: prov, Backend: quota.BackendNative, Enabled: cmd == "connect", Region: region, KeyEnv: keyEnv}
		switch {
		case cmd == "disconnect":
			s.Region, s.KeyEnv = "", ""
		case backend == "codexbar" || backend == quota.BackendCodexBar:
			s.Backend, s.Region, s.KeyEnv = quota.BackendCodexBar, "", ""
		case backend != "native":
			fmt.Fprintln(stderr, "connect: --backend is native or codexbar")
			return exitUsage
		default:
			if _, _, ok := quota.NativeReader(prov); !ok {
				fmt.Fprintf(stderr, "connect: %s has no native reader yet; use --backend codexbar\n", prov)
				return exitUsage
			}
		}
		if err := quota.SetConnection(p.ConnectionsFile, s); err != nil {
			fmt.Fprintln(stderr, "connect:", err)
			return exitUsage
		}
		if cmd == "connect" && !c.offline {
			if s.Backend == quota.BackendNative {
				_ = startDetached("connections", "refresh", "--quiet")
			} else if quota.CodexBarFetchDue(st.Dir, time.Now()) {
				_ = startDetached("codexbar", "fetch", "--quiet")
			} else {
				_ = startDetached("codexbar", "refresh", "--quiet")
			}
		}
		return connectionsStatus(stdout, stderr, p, c, quiet)

	case "connections":
		sub := "status"
		if len(args) > 0 {
			sub = args[0]
		}
		switch sub {
		case "status":
			return connectionsStatus(stdout, stderr, p, c, quiet)
		case "refresh":
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
			defer cancel()
			if err := quota.RefreshNative(ctx, p, time.Now()); err != nil {
				if !quiet {
					fmt.Fprintln(stderr, "connections:", err)
				}
				return exitErr
			}
			return connectionsStatus(stdout, stderr, p, c, quiet)
		}
		fmt.Fprintln(stderr, "usage: modelplan connections [status|refresh]")
		return exitUsage
	}
	return exitUsage
}

func providerIDs() []string {
	var ids []string
	for id := range quota.CodexBarProviders {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	return ids
}

// connectionsStatus prints the effective backend per provider and its last reading.
func connectionsStatus(stdout, stderr io.Writer, p quota.Paths, c common, quiet bool) int {
	ss, err := quota.Selections(p)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return exitErr
	}
	if quiet {
		return 0
	}
	r := quota.Read(p, time.Now())
	status := map[string]quota.SourceStatus{}
	for _, s := range r.Sources {
		status[s.Source] = s
	}
	type row struct {
		quota.Selection
		Reading *quota.SourceStatus `json:"reading,omitempty"`
	}
	rows := []row{}
	for _, x := range ss {
		w := row{Selection: x}
		src := map[string]string{quota.BackendNative: "native:", quota.BackendCodexBar: "codexbar:"}[x.Backend]
		if s, ok := status[src+x.Provider]; ok && src != "" {
			w.Reading = &s
		}
		rows = append(rows, w)
	}
	if c.json {
		return printJSON(stdout, map[string]any{"file": p.ConnectionsFile, "connections": rows})
	}
	if len(rows) == 0 {
		if c.lang == "en" {
			fmt.Fprintln(stdout, "No other plan is connected. `modelplan connect zai` reads Z.ai / GLM with the key in Z_AI_API_KEY.")
		} else {
			fmt.Fprintln(stdout, "没有连接其他套餐。`modelplan connect zai` 用 Z_AI_API_KEY 里的 key 读取 Z.ai / GLM。")
		}
		return 0
	}
	for _, w := range rows {
		line := fmt.Sprintf("%-11s %-16s %s", w.Provider, w.Backend, w.Origin)
		if w.Backend == quota.BackendNative {
			set := "unset"
			if w.KeySet {
				set = "set"
			}
			line += fmt.Sprintf(" · %s · %s %s", w.Region, w.KeyEnv, set)
		}
		if w.Blocked != "" {
			line += " · blocked: " + w.Blocked
		}
		if w.Reading != nil {
			line += " · " + w.Reading.Status
			if w.Reading.Reason != "" {
				line += " (" + w.Reading.Reason + ")"
			}
		}
		fmt.Fprintln(stdout, line)
	}
	return 0
}
