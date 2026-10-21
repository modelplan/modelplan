// Package connections reports, per agent and quota source, how far this machine is connected:
// whether the client is installed, its local history is readable, a reader is authorized, and
// quota was read. It only looks at what the other readers already report and at whether known
// paths exist: it runs no client, reads no credential or secret value, and changes nothing.
package connections

import (
	"os"
	"path/filepath"
	"runtime"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Level is one step of a connection. Status: yes | no | off (turned off by the user) | unknown
// (cannot be told without running or reading more) | not-applicable.
type Level struct {
	Status string     `json:"status"`
	Reason string     `json:"reason,omitempty"` // a stable code
	Via    string     `json:"via,omitempty"`    // authorization: how
	At     *time.Time `json:"at,omitempty"`     // history, quota: the last successful reading
	// Binding: quota only; how the windows are tied to a subscription. Always unknown for now:
	// a reading proves a meter, not whose account it is.
	Binding string `json:"binding,omitempty"`
}

// Connection is one agent or quota source. Support: full (sessions and quota) | quota-only |
// detected-only (installed, nothing read yet).
type Connection struct {
	ID            string `json:"id"`
	Kind          string `json:"kind"` // agent | quota
	Installed     Level  `json:"installed"`
	History       Level  `json:"history"`
	Authorization Level  `json:"authorization"`
	Quota         Level  `json:"quota"`
	Support       string `json:"support"`
}

// Env is where to look; tests replace Exists.
type Env struct {
	Home, CodexHome, CodexBarFile string
	Exists                        func(path string) bool
}

// Local: the machine's own paths.
func Local(p quota.Paths) Env {
	home, _ := os.UserHomeDir()
	return Env{Home: home, CodexHome: p.CodexHome, CodexBarFile: p.CodexBarFile, Exists: func(path string) bool { _, err := os.Stat(path); return err == nil }}
}

// onPath: a command named name on PATH or in the usual install places, found by its path only.
func (e Env) onPath(name string) bool {
	if e.Exists == nil {
		return false
	}
	for _, d := range append(filepath.SplitList(os.Getenv("PATH")), filepath.Join(e.Home, ".local", "bin"), filepath.Join(e.Home, "bin"), "/opt/homebrew/bin", "/usr/local/bin") {
		if d != "" && e.Exists(filepath.Join(d, name)) {
			return true
		}
	}
	return false
}

func (e Env) app(name string) bool {
	return runtime.GOOS == "darwin" && e.Exists != nil && (e.Exists(filepath.Join("/Applications", name+".app")) || e.Exists(filepath.Join(e.Home, "Applications", name+".app")))
}

func yesNo(ok bool, reason string) Level {
	if ok {
		return Level{Status: "yes"}
	}
	return Level{Status: "no", Reason: reason}
}

// Diagnose reports every known source, in a fixed order.
func Diagnose(e Env, r quota.Report) []Connection {
	status := map[string]quota.SourceStatus{}
	for _, s := range r.Sources {
		status[s.Source] = s
	}
	account := map[string]*quota.Account{}
	for i := range r.Accounts {
		account[r.Accounts[i].Source] = &r.Accounts[i]
	}
	quotaLevel := func(src string) Level {
		a := account[src]
		if a == nil || len(a.Windows) == 0 {
			reason := "no-reading"
			if s, ok := status[src]; ok && s.Status != "ok" {
				reason = s.Status
			}
			return Level{Status: "no", Reason: reason, Binding: "unknown"}
		}
		t := a.ObservedAt.UTC()
		return Level{Status: "yes", At: &t, Binding: "unknown"}
	}
	var out []Connection

	// Codex: its session logs, and its own account reading through `codex app-server`.
	cx := Connection{ID: "codex", Kind: "agent", Support: "full",
		Installed: yesNo(e.onPath("codex") || e.app("Codex") || (e.Exists != nil && e.Exists(e.CodexHome)), "not-found")}
	switch s := status["codex"]; s.Status {
	case "ok", "empty":
		cx.History = Level{Status: "yes"}
		if a := account["codex"]; a != nil && a.Harness != nil && a.Harness.ObservedAt != nil {
			t := a.Harness.ObservedAt.UTC()
			cx.History.At = &t
		}
	case "":
		cx.History = Level{Status: "unknown"}
	default:
		cx.History = Level{Status: "no", Reason: s.Status}
	}
	cx.Authorization = Level{Status: "yes", Via: "agent-owned-reader"}
	if quota.CodexAccountOff() {
		cx.Authorization = Level{Status: "off", Reason: "MODELPLAN_CODEX_ACCOUNT"}
	}
	cx.Quota = quotaLevel("codex")
	out = append(out, cx)

	// Claude Code: what its status line hands over; nothing to authorize.
	cc := Connection{ID: "claude-code", Kind: "agent", Support: "full",
		Installed:     yesNo(e.onPath("claude") || (e.Exists != nil && e.Exists(filepath.Join(e.Home, ".claude"))), "not-found"),
		Authorization: Level{Status: "not-applicable", Via: "status-line"}}
	switch s := status["claude-code"]; s.Status {
	case "ok":
		cc.History = Level{Status: "yes"}
		if a := account["claude-code"]; a != nil {
			t := a.ObservedAt.UTC()
			cc.History.At = &t
		}
	case "":
		cc.History = Level{Status: "unknown"}
	default:
		cc.History = Level{Status: "no", Reason: s.Status}
	}
	cc.Quota = quotaLevel("claude-code")
	out = append(out, cc)

	// OpenCode: detected only; no session reader yet.
	oc := Connection{ID: "opencode", Kind: "agent", Support: "detected-only",
		Installed:     yesNo(e.onPath("opencode") || (e.Exists != nil && e.Exists(filepath.Join(dataHome(e.Home), "opencode"))), "not-found"),
		History:       Level{Status: "no", Reason: "no-session-reader"},
		Authorization: Level{Status: "not-applicable"},
		Quota:         Level{Status: "not-applicable", Reason: "see-codexbar:opencodego"}}
	out = append(out, oc)

	// Quota through CodexBar, each provider only when the user enabled it.
	enabled := map[string]bool{}
	for _, p := range quota.CodexBarEnabled(e.CodexBarFile) {
		enabled[p] = true
	}
	installed := map[string]Level{
		"kiro":       yesNo(e.onPath("kiro-cli"), "not-found"),
		"cursor":     yesNo(e.onPath("cursor") || e.app("Cursor"), "not-found"),
		"opencodego": yesNo(e.onPath("opencode"), "not-found"),
		"copilot":    {Status: "not-applicable"},
		"zai":        {Status: "not-applicable"},
	}
	for _, p := range []string{"copilot", "cursor", "kiro", "opencodego", "zai"} {
		c := Connection{ID: "codexbar:" + p, Kind: "quota", Support: "quota-only", Installed: installed[p], History: Level{Status: "not-applicable", Reason: "quota-only"}}
		switch {
		case quota.CodexBarOff():
			c.Authorization = Level{Status: "off", Reason: "MODELPLAN_CODEXBAR"}
			c.Quota = Level{Status: "off", Binding: "unknown"}
		case !enabled[p]:
			c.Authorization = Level{Status: "no", Reason: "not-enabled"}
			c.Quota = Level{Status: "no", Reason: "not-enabled", Binding: "unknown"}
		default:
			c.Authorization = Level{Status: "yes", Via: "codexbar"}
			c.Quota = quotaLevel("codexbar:" + p)
		}
		out = append(out, c)
	}
	return out
}

func dataHome(home string) string {
	if d := os.Getenv("XDG_DATA_HOME"); d != "" {
		return d
	}
	return filepath.Join(home, ".local", "share")
}
