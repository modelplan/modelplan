// Package connections reports, per agent and quota source, how far this machine is connected:
// whether the client is installed, its local history is readable, a reader is authorized, and
// quota was read. It only looks at what the other readers already report and at whether known
// paths exist: it runs no client, reads no credential or secret value, and changes nothing.
package connections

import (
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/qwenusage"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// Level is one step of a connection. Status: yes | no | off (turned off by the user) | unknown
// (cannot be told without running or reading more) | not-applicable.
type Level struct {
	Status   string     `json:"status"`
	NextStep string     `json:"nextStep,omitempty"`
	Reason   string     `json:"reason,omitempty"` // a stable code
	Via      string     `json:"via,omitempty"`    // authorization: how
	At       *time.Time `json:"at,omitempty"`     // history, quota: the last successful reading
	// Binding: quota only; how the windows are tied to a subscription: verified when the reader
	// saw the account (accounts[].subscription), else unknown: a meter alone is not an account.
	Binding string `json:"binding,omitempty"`
}

// Connection is one agent or quota source. Support: full (sessions and quota) | sessions-only
// (an agent whose quota is another plan's) | quota-only | detected-only (installed, nothing read).
type Connection struct {
	Keychain      string           `json:"keychain,omitempty"`
	Admitted      *Level           `json:"admitted,omitempty"`
	QuotaAccess   *quota.Selection `json:"quotaAccess,omitempty"`
	Read          string           `json:"read,omitempty"`
	Hosts         []string         `json:"hosts,omitempty"`
	SecretPolicy  string           `json:"secretPolicy,omitempty"`
	Reads         []string         `json:"reads,omitempty"`
	Network       string           `json:"network,omitempty"`
	Privacy       string           `json:"privacy,omitempty"`
	ID            string           `json:"id"`
	Kind          string           `json:"kind"` // agent | quota
	Installed     Level            `json:"installed"`
	History       Level            `json:"history"`
	Authorization Level            `json:"authorization"`
	Quota         Level            `json:"quota"`
	Support       string           `json:"support"`

	LocalUsage *localusage.Report `json:"localUsage,omitempty"`
}

// Env is where to look; tests replace Exists.
type Env struct {
	Paths                                          *quota.Paths
	GOOS                                           string // tests can exercise the macOS Keychain policy without a real Keychain
	Gemini                                         *localusage.Report
	Qwen                                           *localusage.Report
	Home, CodexHome, CodexBarFile, ConnectionsFile string
	Exists                                         func(path string) bool
}

// Local: the machine's own paths.
func Local(p quota.Paths) Env {
	home, _ := os.UserHomeDir()
	return Env{Paths: &p, Home: home, CodexHome: p.CodexHome, CodexBarFile: p.CodexBarFile, ConnectionsFile: p.ConnectionsFile, Exists: func(path string) bool { _, err := os.Stat(path); return err == nil }}
}

// onPath: a command named name on PATH or in the usual install places, found by its path only.
func (e Env) onPath(name string) bool {
	if e.Exists == nil {
		return false
	}
	for _, d := range append(filepath.SplitList(os.Getenv("PATH")), toolcli.SearchDirs(e.Home)...) {
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
	return DiagnoseWithAdmission(e, r, consent.Capture())
}

// DiagnoseWithAdmission shares the reader/projection permission input. The
// command fences the complete snapshot before publishing these diagnostics.
func DiagnoseWithAdmission(e Env, r quota.Report, admission consent.Admission) []Connection {
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
				if strings.HasPrefix(src, "native:") && s.Status != "consent_required" && s.Status != "off" && s.Status != toolcli.RuntimeMissing {
					reason = quota.ReaderErrorCode(s.ErrorCode)
				}
			}
			level := Level{Status: "no", Reason: reason, Binding: "unknown"}
			if reason == toolcli.RuntimeMissing {
				level.NextStep = toolcli.RuntimeNextStep
			}
			return level
		}
		t := a.ObservedAt.UTC()
		l := Level{Status: "yes", At: &t, Binding: "unknown"}
		if s, ok := status[src]; ok && strings.HasPrefix(src, "native:") && s.Status != "ok" {
			l.Reason = quota.ReaderErrorCode(s.ErrorCode)
		}
		if a.Subscription != nil {
			l.Binding = a.Subscription.Status // the reader saw the account (quota's identity.go)
		}
		return l
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
	if failure, ok := status["codex-account"]; ok && failure.Status == toolcli.RuntimeMissing && cx.Quota.Status != "yes" {
		cx.Quota = Level{Status: "no", Reason: toolcli.RuntimeMissing, NextStep: toolcli.RuntimeNextStep, Binding: "unknown"}
	}
	out = append(out, cx)

	// Claude Code: status-line history, plus native-reader consent after a decision.
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
	nativeClaudeConnection(&cc, e, account["claude-code"], status["native:claude"], admission)
	out = append(out, cc)

	// OpenCode V2 and ZCode: sessions from their own databases (speed's sqlite.go); their quota is
	// the plan behind them (OpenCode Go, Z.ai), read as another plan.
	ocdb, zcdb := speed.OpenCodeDB(e.Home), speed.ZCodeDB(e.Home)
	oc := Connection{ID: "opencode", Kind: "agent", Support: "sessions-only",
		Installed:     yesNo(e.onPath("opencode") || (e.Exists != nil && e.Exists(filepath.Join(dataHome(e.Home), "opencode"))), "not-found"),
		History:       yesNo(e.Exists != nil && e.Exists(ocdb), "no-database"),
		Authorization: Level{Status: "not-applicable"},
		Quota:         Level{Status: "not-applicable", Reason: "see-opencodego"}}
	zc := Connection{ID: "zcode", Kind: "agent", Support: "sessions-only",
		Installed:     yesNo(e.onPath("zcode") || e.app("ZCode") || (e.Exists != nil && e.Exists(filepath.Join(e.Home, ".zcode"))), "not-found"),
		History:       yesNo(e.Exists != nil && e.Exists(zcdb), "no-database"),
		Authorization: Level{Status: "not-applicable"},
		Quota:         Level{Status: "not-applicable", Reason: "see-zai"}}
	out = append(out, oc, zc)

	// Other plans' quota, natively or through CodexBar, each provider only when the user enabled
	// it. The entry's id names the backend that serves it.
	sel := map[string]quota.Selection{}
	paths := quota.Paths{CodexBarFile: e.CodexBarFile, ConnectionsFile: e.ConnectionsFile}
	if e.Paths != nil {
		paths = *e.Paths
	}
	ss, err := quota.SelectionsWithAdmission(paths, admission)
	for _, x := range ss {
		sel[x.Provider] = x
	}
	installed := map[string]Level{
		"kiro":       yesNo(e.onPath("kiro-cli"), "not-found"),
		"cursor":     yesNo(e.onPath("cursor") || e.app("Cursor"), "not-found"),
		"opencodego": yesNo(e.onPath("opencode"), "not-found"),
		"copilot":    {Status: "not-applicable"},
		"zai":        {Status: "not-applicable"},
		"kimi":       {Status: "not-applicable"},
		"minimax":    {Status: "not-applicable"},
	}
	for _, p := range []string{"copilot", "cursor", "kiro", "opencodego", "zai", "kimi", "minimax"} {
		c := Connection{ID: "codexbar:" + p, Kind: "quota", Support: "quota-only", Installed: installed[p], History: Level{Status: "not-applicable", Reason: "quota-only"}}
		x, on := sel[p]
		if p == "minimax" {
			c.ID = "native:minimax"
			access := x
			if !on || x.Backend == quota.BackendOff {
				access = quota.Selection{Provider: "minimax", Name: "MiniMax", Backend: quota.BackendOff, Region: "international", KeyEnv: "MINIMAX_CODING_API_KEY", Host: quota.MiniMaxHost("international"), EndpointNotice: quota.MiniMaxEndpointNotice, Read: "env:MINIMAX_CODING_API_KEY", Hosts: []string{quota.MiniMaxHost("international")}}
			}
			c.QuotaAccess = &access
		}
		if p == "kimi" {
			c.ID = "native:kimi"
			access := x
			if !on || x.Backend == quota.BackendOff {
				access = quota.Selection{Provider: "kimi", Name: "Kimi Code", Backend: quota.BackendOff, Region: "china", KeyEnv: "KIMI_CODE_API_KEY", Host: quota.KimiHost("china"), EndpointNotice: quota.KimiEndpointNotice}
			}
			c.QuotaAccess = &access
		}
		switch {
		case err != nil:
			c.Authorization = Level{Status: "no", Reason: "connections-invalid"}
			c.Quota = Level{Status: "no", Reason: "connections-invalid", Binding: "unknown"}
		case on && x.Backend == quota.BackendOff:
			c.Authorization = Level{Status: "off", Reason: "connections.json"}
			c.Quota = Level{Status: "off", Binding: "unknown"}
		case on && x.Backend == quota.BackendNative:
			c.ID = "native:" + p
			if p == "copilot" {
				c.Installed = yesNo(e.onPath("copilot"), "not-found")
			}
			c.Read, c.Hosts, c.SecretPolicy = x.Read, x.Hosts, x.SecretPolicy
			if p == "cursor" || p == "minimax" {
				c.QuotaAccess = &x
			}
			switch x.Blocked {
			case "native-off":
				c.Authorization = Level{Status: "off", Reason: "MODELPLAN_NATIVE"}
			case "no-native-reader":
				c.Authorization = Level{Status: "no", Reason: "no-native-reader"}
			case "no-key":
				c.Authorization = Level{Status: "no", Reason: "key-env-unset", Via: "env:" + x.KeyEnv}
			case "":
				c.Authorization = Level{Status: "yes", Via: "env:" + x.KeyEnv}
				if p == "cursor" {
					c.Authorization.Via = "cursor-local-sign-in"
				} else if x.KeyEnv == "" {
					c.Authorization.Via = "agent-owned-reader" // the agent's own CLI keeps the sign-in (Kiro)
				}
			}
			c.Quota = quotaLevel(c.ID)
		case (p == "kimi" || p == "minimax") && !on:
			c.Authorization = Level{Status: "off", Reason: "not-enabled"}
			c.Quota = Level{Status: "off", Binding: "unknown"}
		case quota.CodexBarOff():
			c.Authorization = Level{Status: "off", Reason: "MODELPLAN_CODEXBAR"}
			c.Quota = Level{Status: "off", Binding: "unknown"}
		case !on:
			c.Authorization = Level{Status: "no", Reason: "not-enabled"}
			c.Quota = Level{Status: "no", Reason: "not-enabled", Binding: "unknown"}
		default:
			c.Authorization = Level{Status: "yes", Via: "codexbar"}
			c.Quota = quotaLevel("codexbar:" + p)
		}
		out = append(out, c)
	}
	for _, source := range []string{"gemini", "qwen"} {
		usage, name := e.Gemini, "gemini"
		if source == "qwen" {
			usage, name = e.Qwen, "qwen"
		}
		if usage == nil {
			status := localusage.GeminiStatus(e.Home, r.EvaluatedAt)
			if source == "qwen" {
				status = localusage.QwenStatus(e.Home, r.EvaluatedAt)
			}
			usage = &status
		}
		c := Connection{ID: source, Kind: "agent", Support: "sessions-only", Installed: yesNo(e.onPath(name), "not-found"), Authorization: Level{Status: "off", Reason: usage.Reason, Via: "local-usage.json"}, History: Level{Status: "off"}, Quota: Level{Status: "not-applicable", Reason: "local-only-no-remote-quota"}, LocalUsage: usage}
		if usage.Enabled && usage.Status != "off" {
			c.Authorization.Status = "yes"
			c.History = Level{Status: "unknown", Reason: usage.Reason}
			if len(usage.Rows) > 0 {
				c.History = Level{Status: "yes", At: usage.LastObservedAt, Reason: usage.Reason}
			}
		}
		out = append(out, c)
	}
	if qwenusage.Configured() != "" {
		out = append(out, qwenWithAdmission(admission))
	}
	return out
}

func dataHome(home string) string {
	if d := os.Getenv("XDG_DATA_HOME"); d != "" {
		return d
	}
	return filepath.Join(home, ".local", "share")
}

// Qwen describes the explicitly selected aggregate export. No runtime discovery.
func Qwen() Connection { return qwenWithAdmission(consent.Capture()) }

func qwenWithAdmission(admission consent.Admission) Connection {
	c := Connection{ID: "qwen-code", Kind: "agent", Support: "usage-only", Installed: Level{Status: "unknown"},
		History: Level{Status: "off", Reason: "not-enabled"}, Authorization: Level{Status: "off", Reason: qwenusage.ExportEnv},
		Quota: Level{Status: "not-applicable", Reason: "local-usage-only"}, Reads: []string{"env:" + qwenusage.ExportEnv},
		Network: "none", Privacy: "Only aggregated tokens and model names are read; no credentials, prompts, replies or account identities are read or stored. Exports are never rewritten."}
	if !admission.Allows("qwen", consent.Local) {
		c.Authorization = Level{Status: "off", Reason: "reader-consent-or-privacy"}
		c.History = Level{Status: "off", Reason: "reader-consent-or-privacy"}
		return c
	}
	if p := qwenusage.Configured(); p != "" {
		c.Reads = append(c.Reads, p)
		c.Authorization = Level{Status: "yes", Via: "user-selected-export"}
		r := qwenusage.Read(p, time.Now())
		c.History = Level{Status: "no", Reason: r.Status}
		if r.Status == "ok" || r.Status == "partial" {
			c.History.Status = "yes"
		}
	}
	return c
}

// nativeClaudeConnection reports the current shared grant and production admission;
// status-line history remains a separate source and never proves a native quota read.
func nativeClaudeConnection(c *Connection, e Env, account *quota.Account, source quota.SourceStatus, admission consent.Admission) {
	state, mode := admission.State(), admission.Mode()
	record, decided := state.Tools["claude"]
	if !decided {
		return
	} // Retain credential-free status-line diagnostics for legacy users.
	c.Read = "native:claude"
	c.Keychain = state.KeychainStatus("claude", mode)
	c.Authorization = Level{Status: "off", Via: "native:claude", Reason: "consent_required"}
	admitted := Level{Status: "no", Reason: "not_admitted"}
	c.Admitted = &admitted
	c.Quota = Level{Status: "no", Reason: "not_read", Binding: "unknown"}
	valid := record.Allowed && record.ConsentTextVersion == consent.TextVersion && record.Backend == quota.BackendNative && !record.BrowserSession && (record.ReaderID == "native:claude" || record.ReaderID == "native:claude-code")
	if !valid {
		if !record.Allowed {
			c.Authorization.Reason = "consent_denied"
		}
		c.Quota.Reason = c.Authorization.Reason
		return
	}
	if !state.Allows("claude", consent.Credential, mode) || strings.EqualFold(os.Getenv("MODELPLAN_NATIVE"), "off") || os.Getenv("MODELPLAN_NATIVE") == "0" || strings.EqualFold(os.Getenv("MODELPLAN_NATIVE"), "false") {
		c.Authorization.Reason = "privacy_blocked"
		c.Quota.Reason = "privacy_blocked"
		admitted.Reason = "privacy_blocked"
		return
	}
	c.Authorization = Level{Status: "yes", Via: "native:claude"}
	if e.Paths != nil && quota.ReaderAdmitted(*e.Paths, "claude") {
		admitted = Level{Status: "yes"}
		c.Admitted = &admitted
	}
	if source.Status != "" {
		c.Quota.Reason = source.Status
		if source.ErrorCode != "" && source.Status != "ok" {
			c.Quota.Reason = quota.ReaderErrorCode(source.ErrorCode)
		}
		if source.Status == "ok" {
			c.Quota.Reason = "no_usage_windows"
		}
	}
	if account != nil && account.Via == "native" && len(account.Windows) > 0 && (source.Status == "" || source.Status == "ok") {
		at := account.ObservedAt.UTC()
		c.Quota = Level{Status: "yes", At: &at, Binding: "unknown"}
		if account.Subscription != nil {
			c.Quota.Binding = account.Subscription.Status
		}
	}
	platform := e.GOOS
	if platform == "" {
		platform = runtime.GOOS
	}
	if platform == "darwin" && c.Keychain == "unset" {
		c.Authorization.Reason = "keychain_choice_needed"
		c.Authorization.NextStep = consent.ClaudeKeychainNextStep
		if c.Quota.Status != "yes" {
			c.Quota.Reason = "keychain_choice_needed"
			c.Quota.NextStep = consent.ClaudeKeychainNextStep
		}
	} else if platform == "darwin" && c.Keychain == "denied" && c.Quota.Status != "yes" {
		c.Quota.Reason = "keychain_denied"
		c.Quota.NextStep = "Review Keychain access for Claude Code in Settings"
	}
	if source.Status == "confirmation-needed" || source.Status == "keychain-confirmation-needed" {
		c.Quota.NextStep = "Review Keychain access for Claude Code in Settings"
	}
}
