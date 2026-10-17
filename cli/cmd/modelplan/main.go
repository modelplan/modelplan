// Command modelplan is the Model Plan thin client: a read-only view of the verified
// public publication, cached locally and shared with the Claude Code mods and Codex plugin.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/detach"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/render"
	"github.com/modelplan/modelplan/cli/internal/store"
)

var version = "0.1.0-dev"

const (
	exitErr    = 1
	exitUsage  = 2
	exitNoData = 3
	exitBusy   = 75

	staleAfter      = 6 * time.Hour  // status line starts a background sync
	alarmAfter      = 48 * time.Hour // 数据过期 annunciator
	backgroundEvery = 10 * time.Minute
	firstSyncWait   = 3500 * time.Millisecond // hook timeouts are 5 s
)

const usage = `modelplan — Model Plan thin client (read-only, anonymous)

  modelplan lineup [--dev anthropic]   WHICH ENGINE: a developer's models at ★ recommended effort
  modelplan effort [model]             one model's effort ladder (default: Claude Code's current model)
  modelplan models [--dev openai]      models with ★ effort, ability and cost
  modelplan quota                      your own usage windows: this machine's logs, and Codex's own
                                       account reading (--refresh-account asks it now; at most every
                                       5 min in the background; MODELPLAN_CODEX_ACCOUNT=off to skip)
  modelplan codexbar [status|enable <provider…>|disable [provider…]|fetch|refresh]
                                       other plans through CodexBar's CLI (copilot, cursor, zai, kiro,
                                       opencodego): off until enabled; CodexBar keeps the sign-ins,
                                       this client fetches its pinned release and reads its JSON
  modelplan advise [--source codex]    what to do about them now: step up before a reset, step down,
                                       switch back after it, peak hours, cards, public resets
                                       (--hook claude-code|codex: prompt hook; hints shown to the
                                       user once, a task-start brief for the model per thread)
  modelplan declare <planId> [generation]
                                       record which plan pays for another vendor's model (GLM through
                                       Z.ai in Claude Code) in ~/.config/modelplan/local.json, so
                                       advice follows how it counts usage (--remove takes it out)
  modelplan statusline                 one line for Claude Code / other status bars (cache only;
                                       --preview renders a sample without recording it)
  modelplan sync [--force]             refresh the local cache from the verified publication
  modelplan doctor                     show base URL, cache and publication state
  modelplan version

Common flags: --json  --lang zh|en  --offline  --no-color  --base URL
Env: MODELPLAN_BASE, MODELPLAN_CACHE, MODELPLAN_LANG, NO_COLOR,
     MODELPLAN_TASK_BRIEF=off (no task-start brief), MODELPLAN_CODEX_ACCOUNT=off (no Codex account reading),
     MODELPLAN_CODEXBAR=off or a path (no CodexBar, or the CodexBar CLI to run)
`

type common struct {
	json, offline, noColor bool
	lang, base             string
}

func flags(name string, c *common) *flag.FlagSet {
	fs := flag.NewFlagSet(name, flag.ContinueOnError)
	fs.BoolVar(&c.json, "json", false, "machine-readable output")
	fs.BoolVar(&c.offline, "offline", false, "never touch the network")
	fs.BoolVar(&c.noColor, "no-color", false, "disable ANSI colour")
	fs.StringVar(&c.lang, "lang", env("MODELPLAN_LANG", "zh"), "zh or en")
	fs.StringVar(&c.base, "base", env("MODELPLAN_BASE", publication.DefaultBase), "publication base URL")
	return fs
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func main() { os.Exit(run(os.Args[1:], os.Stdin, os.Stdout, os.Stderr)) }

func run(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	if len(args) == 0 || args[0] == "-h" || args[0] == "--help" || args[0] == "help" {
		fmt.Fprint(stdout, usage)
		return 0
	}
	cmd, rest := args[0], args[1:]
	var c common
	fs := flags(cmd, &c)
	fs.SetOutput(stderr)
	dev := fs.String("dev", "", "developer id, e.g. anthropic, openai, zhipuai")
	force := fs.Bool("force", false, "sync: ignore the 10-minute check interval")
	background := fs.Bool("background", false, "sync: detach and return immediately")
	quiet := fs.Bool("quiet", false, "sync: print nothing on success")
	harness := fs.String("harness", "claude-code", "statusline: which harness feeds stdin")
	modelFlag := fs.String("model", "", "statusline: model id when stdin has none")
	effortFlag := fs.String("effort", "", "statusline: current effort when the harness knows it")
	recordOnly := fs.Bool("record-only", false, "statusline: record Claude Code usage windows and print nothing")
	preview := fs.Bool("preview", false, "statusline: render the input without recording it (a sample)")
	source := fs.String("source", "", "advise: only claude-code, codex or user events")
	hook := fs.String("hook", "", "advise: run as a harness hook (claude-code); print only hints not shown before")
	addSystem := fs.String("add-system", "", "advise --hook: a message for the user to show with the hints (a plugin's setup notice)")
	addContext := fs.String("add-context", "", "advise --hook: context for the model to hand over with the hints")
	refreshAccount := fs.Bool("refresh-account", false, "quota: ask Codex for the account's windows and reset credits now")
	remove := fs.Bool("remove", false, "declare: take the plan out of local.json")
	if err := fs.Parse(reorder(rest)); err != nil {
		return exitUsage
	}

	st, err := store.Open()
	if err != nil {
		fmt.Fprintln(stderr, "cache:", err)
		return exitErr
	}
	client, err := publication.New(c.base, st, version)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return exitUsage
	}
	style := render.Style{Color: !c.noColor && os.Getenv("NO_COLOR") == "" && (isTTY(stdout) || cmd == "statusline"), T: render.ZH}
	if c.lang == "en" {
		style.T = render.EN
	}

	switch cmd {
	case "version":
		fmt.Fprintln(stdout, "modelplan", version)
		return 0

	case "sync":
		if *background {
			if err := detach.Start("sync", "--quiet", "--base", c.base); err != nil {
				fmt.Fprintln(stderr, err)
				return exitErr
			}
			return 0
		}
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		res, err := client.Sync(ctx, *force)
		if errors.Is(err, store.ErrBusy) {
			if !*quiet {
				fmt.Fprintln(stderr, err)
			}
			return exitBusy
		}
		if err != nil {
			fmt.Fprintln(stderr, "sync:", err)
			return exitErr
		}
		if !*quiet {
			switch {
			case res.Switched:
				fmt.Fprintln(stdout, "verified publication", res.PublicationID)
			case res.Skipped:
				fmt.Fprintln(stdout, "up to date (checked recently):", res.PublicationID)
			default:
				fmt.Fprintln(stdout, "up to date:", res.PublicationID)
			}
		}
		return 0

	case "quota":
		if *refreshAccount {
			home, _ := os.UserHomeDir()
			err := quota.RefreshCodexAccount(context.Background(), st.Dir, quota.CodexBin(home), time.Now())
			if *quiet {
				return 0
			}
			if err != nil {
				fmt.Fprintln(stderr, "codex account:", err)
			}
		} else if !c.offline {
			refreshAccountLater(st)
		}
		r := quota.Read(quotaPaths(st), time.Now())
		if c.json {
			return printJSON(stdout, r)
		}
		style.Quota(stdout, r)
		return 0

	case "advise":
		if *hook != "" {
			return adviseHook(stdin, stdout, style, st, client, c, *hook, *addSystem, *addContext)
		}
		if !c.offline {
			refreshAccountLater(st)
		}
		d, _, _ := publication.Load(st)
		state := advise.Load(st.Dir)
		now := time.Now()
		es := filterSource(advise.Derive(advise.Input{Report: quota.Read(quotaPaths(st), now), Digest: d, State: state, Now: now}), *source)
		_ = state.Save(st.Dir, now)
		if c.json {
			for i := range es {
				es[i].Text = map[string]string{"zh": render.Style{T: render.ZH}.AdviceLine(es[i]), "en": render.Style{T: render.EN}.AdviceLine(es[i])}
			}
			return printJSON(stdout, map[string]any{"schemaVersion": 1, "evaluatedAt": now.UTC(), "events": nonNil(es)})
		}
		style.Advice(stdout, es)
		return 0

	case "statusline":
		if *recordOnly {
			stdout = io.Discard
		}
		return statusline(stdin, stdout, style, st, c, *harness, *modelFlag, *effortFlag, *preview)

	case "codexbar":
		return codexbarCmd(fs.Args(), stdout, stderr, st, c, *quiet)

	case "declare":
		return declareCmd(fs.Args(), stdout, stderr, st, c, *remove)

	case "doctor":
		s, _ := st.State()
		d, _, lerr := publication.Load(st)
		out := map[string]any{"version": version, "base": c.base, "cache": st.Dir, "state": s}
		if d != nil {
			out["source"], out["release"], out["models"], out["units"] = d.Source, d.Release, len(d.Models), d.Units
		}
		if lerr != nil {
			out["load"] = lerr.Error()
		}
		return printJSON(stdout, out)
	}

	d, s, code := load(client, st, c, stderr)
	if d == nil {
		return code
	}
	switch cmd {
	case "lineup":
		devs := []string{*dev}
		if *dev == "" {
			devs = []string{"anthropic", "openai"}
		}
		if c.json {
			out := map[string]any{"publicationId": d.PublicationID, "units": d.Units, "lineups": map[string]*digest.PublishedLineup{}}
			for _, v := range devs {
				out["lineups"].(map[string]*digest.PublishedLineup)[v] = d.PublishedLineup(v)
			}
			return printJSON(stdout, out)
		}
		for i, v := range devs {
			if i > 0 {
				fmt.Fprintln(stdout)
			}
			if err := style.Lineup(stdout, d, v); err != nil {
				fmt.Fprintln(stderr, err)
				return exitErr
			}
		}
	case "effort":
		q := strings.Join(fs.Args(), " ")
		if q == "" {
			// No model given: the one Claude Code last reported to the status line.
			for _, a := range quota.Read(quotaPaths(st), time.Now()).Accounts {
				if a.Source == "claude-code" && a.Harness != nil && a.Harness.Model != "" {
					q, *harness = a.Harness.Model, "claude-code"
				}
			}
		}
		if q == "" {
			fmt.Fprintln(stderr, "usage: modelplan effort <model id or name>")
			return exitUsage
		}
		m := d.Model(q)
		if m == nil {
			m = d.Match(*harness, q)
		}
		if m == nil {
			fmt.Fprintf(stderr, "%s: %s\n", style.T.NotListed, q)
			return exitErr
		}
		tiers := d.SpeedTiers(m.ID, "")
		if c.json {
			return printJSON(stdout, struct {
				*digest.Model
				SpeedTiers []digest.ModelTier `json:"speedTiers,omitempty"`
			}{m, tiers})
		}
		style.Effort(stdout, m)
		style.Speed(stdout, tiers)
	case "models":
		var ms []digest.Model
		for _, m := range d.Models {
			if *dev == "" || strings.EqualFold(m.DeveloperID, *dev) {
				ms = append(ms, m)
			}
		}
		if c.json {
			return printJSON(stdout, ms)
		}
		for _, m := range ms {
			r := m.Rec()
			a, x := "—", "—"
			if r != nil && r.Ability != nil {
				a = fmt.Sprintf("%.1f", *r.Ability)
			}
			if r != nil && r.Cost != nil {
				x = fmt.Sprintf("%.3g", *r.Cost)
			}
			label := "—"
			if r != nil {
				label = "★" + r.Label
			}
			fmt.Fprintf(stdout, "%-34s %-10s %-8s %6s  %s\n", m.ID, m.DeveloperID, label, a, x)
		}
	default:
		fmt.Fprint(stderr, usage)
		return exitUsage
	}
	if time.Since(s.CheckedAt) > alarmAfter {
		fmt.Fprintln(stderr, style.T.Stale, s.CheckedAt.Format(time.RFC3339))
	}
	return 0
}

// load refreshes when allowed (at most every 10 minutes) and always falls back to the last verified cache.
func load(client *publication.Client, st *store.Store, c common, stderr io.Writer) (*digest.Digest, store.State, int) {
	if !c.offline {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		_, err := client.Sync(ctx, false)
		cancel()
		if err != nil && !errors.Is(err, store.ErrBusy) {
			fmt.Fprintln(stderr, "sync:", err, "(using cached data)")
		}
	}
	d, s, err := publication.Load(st)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return nil, s, exitNoData
	}
	return d, s, 0
}

// statusline is cache-only: it may start a detached sync but never waits on the network.
// For Claude Code it also records the usage windows the harness passes on stdin, so the
// Skill and `modelplan quota` can read them later.
func statusline(stdin io.Reader, stdout io.Writer, style render.Style, st *store.Store, c common, harness, modelID, effort string, preview bool) int {
	var in quota.StatuslineInput
	if f, ok := stdin.(*os.File); !ok || !isTTY(f) {
		b, _ := io.ReadAll(io.LimitReader(stdin, 1<<16))
		_ = json.Unmarshal(b, &in)
	}
	if modelID == "" {
		modelID = in.Model.ID
	}
	if effort == "" && in.Effort != nil {
		effort = in.Effort.Level
	}
	now := time.Now()
	var acct *quota.Account
	if harness == "claude-code" {
		// A custom endpoint (GLM through Z.ai) decides which model an id means and which plan pays.
		in.Endpoint = digest.Endpoint(os.Getenv("ANTHROPIC_BASE_URL"))
		if !preview {
			_ = quota.RecordClaudeCode(st.Dir, in, now)
		}
		a := in.Account(now)
		quota.Evaluate(&a, now)
		acct = &a
	}
	s, _ := st.State()
	if !c.offline && time.Since(s.CheckedAt) > staleAfter && time.Since(s.LastAttemptAt) > backgroundEvery {
		_ = detach.Start("sync", "--quiet", "--base", c.base)
	}
	tail := ""
	if in.FastMode != nil && *in.FastMode {
		tail += " ⚡fast"
	}
	d, s, err := publication.Load(st)
	hint := ""
	if acct != nil {
		var report quota.Report
		report, acct = linkedReport(st, d, *acct, now)
		hint = statuslineHint(style, st, d, report, now, !preview)
	}
	if q := style.QuotaSegment(acct, hint); q != "" {
		tail += " │ " + q
	}
	if err != nil {
		fmt.Fprintln(stdout, style.Statusline(nil, nil, "", false, "")+" · "+style.T.Syncing+tail)
		return 0
	}
	m := d.MatchAt(harness, in.Endpoint, modelID, in.Model.DisplayName)
	raw := in.Model.DisplayName
	if raw == "" {
		raw = modelID
	}
	fmt.Fprintln(stdout, style.Statusline(d, m, effort, time.Since(s.CheckedAt) > alarmAfter, raw)+tail)
	return 0
}

// linkedReport: what the status line advises on. Usually the session alone; a session on another
// vendor's model (GLM through Z.ai) also needs the declared plan and that vendor's reading, and
// its quota segment shows that plan's windows.
func linkedReport(st *store.Store, d *digest.Digest, acct quota.Account, now time.Time) (quota.Report, *quota.Account) {
	r := quota.Report{Accounts: []quota.Account{acct}}
	if d == nil || acct.Harness == nil {
		return r, &acct
	}
	if m := d.MatchAt("claude-code", acct.Harness.Endpoint, acct.Harness.Model); m == nil || !m.ViaEndpoint("claude-code") {
		return r, &acct
	}
	p := quotaPaths(st)
	p.CodexHome = ""
	full := quota.Read(p, now)
	for _, a := range full.Accounts {
		if a.Source != "claude-code" {
			r.Accounts = append(r.Accounts, a)
		}
	}
	eff, _ := advise.Link(&acct, r, d)
	return r, &eff
}

// statuslineHint: the most urgent Claude Code advice as a few characters ("↑High ×1.37",
// "↺★Med"). It remembers advised windows so the switch-back hint appears after the reset, for
// 90 minutes from when it first shows.
func statuslineHint(style render.Style, st *store.Store, d *digest.Digest, report quota.Report, now time.Time, save bool) string {
	state := advise.Load(st.Dir)
	es := advise.Derive(advise.Input{Report: report, Digest: d, State: state, Now: now})
	if save {
		_ = state.Save(st.Dir, now)
	}
	for _, e := range es {
		if e.Source == "claude-code" && e.InStatusLine(now) {
			if h := style.AdviceShort(e); h != "" {
				return h
			}
		}
	}
	return ""
}

// adviseHook is a UserPromptSubmit hook for Claude Code or Codex (both accept the same
// output). What the user decides on (quota hints, once per event; the question which plan pays
// for another vendor's model) is shown to the user as the hook's systemMessage and never reaches
// the model. The model gets only the task-start brief: once per thread, plus one line for a model
// the thread was not briefed on. A plugin may pass its own setup notice (system, context) so the
// hook prints one object. It never fails the prompt and never waits on the network.
func adviseHook(stdin io.Reader, stdout io.Writer, style render.Style, st *store.Store, client *publication.Client, c common, harness, system, notice string) int {
	b, _ := io.ReadAll(io.LimitReader(stdin, 1<<20))
	if harness != "claude-code" && harness != "codex" {
		return 0
	}
	// Hook input names the prompting thread; nothing else is decoded from it.
	var in struct {
		SessionID string `json:"session_id"`
		Model     string `json:"model"`
	}
	_ = json.Unmarshal(b, &in)
	now := time.Now()
	// Without the status line nothing else keeps the publication fresh for Claude Code. With no
	// publication at all (just installed) the first prompt waits briefly for one, so it gets the
	// brief, and a sync that does not finish in time goes on in the background for the next
	// prompt; otherwise a stale one is refreshed in the background.
	d, _, _ := publication.Load(st)
	if s, _ := st.State(); !c.offline && time.Since(s.LastAttemptAt) > backgroundEvery {
		if d == nil {
			ctx, cancel := context.WithTimeout(context.Background(), firstSyncWait)
			_, _ = client.Sync(ctx, false)
			cancel()
			if d, _, _ = publication.Load(st); d == nil {
				_ = detach.Start("sync", "--quiet", "--base", c.base)
			}
		} else if time.Since(s.CheckedAt) > staleAfter {
			_ = detach.Start("sync", "--quiet", "--base", c.base)
		}
	}
	state := advise.Load(st.Dir)
	paths := quotaPaths(st)
	if harness == "claude-code" {
		paths.CodexHome = "" // Codex advice belongs to Codex; skip scanning its logs on every prompt
		if in.SessionID != "" {
			paths.ClaudeSession = in.SessionID
		}
		refreshCodexBarLater(st, now)
	} else {
		if in.SessionID != "" {
			paths.CodexThread = in.SessionID
		}
		refreshAccountLater(st) // the prompt uses the cached reading; the next one gets a fresher one
	}
	var es []advise.Event
	report := quota.Read(paths, now)
	for _, e := range advise.Derive(advise.Input{Report: report, Digest: d, State: state, Now: now}) {
		if e.Source == harness || (harness == "claude-code" && e.Source == "user") {
			es = append(es, e)
		}
	}
	// Configuration advice once per model and effort, in whichever thread; account news once.
	for i := range es {
		es[i].Key = advise.ConfigKey(es[i])
	}
	es = state.Unseen(es)
	var parts, shown []string
	if system != "" {
		shown = append(shown, system)
	}
	if notice != "" {
		parts = append(parts, notice)
	}
	// A session on another vendor's model with no declared plan: tell the user once per model.
	if harness == "claude-code" && d != nil {
		for i := range report.Accounts {
			a := &report.Accounts[i]
			if a.Source != harness || a.Harness == nil || a.Harness.Attribution == "recent-thread" {
				continue
			}
			if m, plans := advise.Undeclared(a, report, d); m != nil && state.Once("declare|"+m.ID, now) {
				self, _ := os.Executable()
				shown = append(shown, declareNotice(m, plans, a.Harness.Endpoint, codexbarCommand(self), style.T == render.EN))
			}
		}
	}
	if len(es) > 0 {
		shown = append(shown, style.AdviceNotice(es))
		state.MarkSeen(es, now)
	}
	// The first prompt of a thread gets the task-start brief: the model judges the task, the
	// publication supplies the options.
	if in.SessionID != "" && os.Getenv("MODELPLAN_TASK_BRIEF") != "off" {
		// Without a reading yet (a first thread, an API-key login, no status line) the brief
		// still lists the options and the default; the quota and current model are then unknown.
		acct := &quota.Account{Source: harness, Headroom: "unknown"}
		for i := range report.Accounts {
			if report.Accounts[i].Source == harness {
				acct = &report.Accounts[i]
			}
		}
		switch {
		case in.Model != "" && (acct.Harness == nil || acct.Harness.Model != in.Model):
			// The hook names the thread's model (Codex); its effort is known only from that thread's log.
			x := *acct
			x.Harness = &quota.Harness{Model: in.Model}
			acct = &x
		case harness == "claude-code" && acct.Harness != nil && acct.Harness.Attribution != "current-thread":
			// The status line's model and effort are another session's (or of unknown session).
			x := *acct
			x.Harness = nil
			acct = &x
		}
		model := ""
		if acct.Harness != nil {
			model = acct.Harness.Model
		}
		if brief := advise.TaskStart(acct, report, d, now); brief != nil {
			switch state.BriefDue(in.SessionID, model, now) {
			case advise.BriefFull:
				parts = append(parts, render.TaskBrief(brief))
			case advise.BriefSwitch:
				if l := render.TaskBriefUpdate(brief); l != "" {
					parts = append(parts, l)
				}
			}
		}
	}
	if len(parts) > 0 || len(shown) > 0 {
		out := map[string]any{}
		if len(shown) > 0 {
			out["systemMessage"] = strings.Join(shown, "\n")
		}
		if len(parts) > 0 {
			out["hookSpecificOutput"] = map[string]any{"hookEventName": "UserPromptSubmit", "additionalContext": strings.Join(parts, "\n\n")}
		}
		b, _ := json.Marshal(out)
		fmt.Fprintln(stdout, string(b))
	}
	_ = state.Save(st.Dir, now)
	return 0
}

// refreshAccountLater asks Codex for the account reading (and CodexBar for the enabled
// providers) in the background when the cached one is due, so hooks and the plugin never wait.
func refreshAccountLater(st *store.Store) {
	now := time.Now()
	if quota.AccountDue(st.Dir, now) {
		_ = detach.Start("quota", "--refresh-account", "--quiet")
	}
	refreshCodexBarLater(st, now)
}

// refreshCodexBarLater runs CodexBar in the background for the enabled providers when the cached
// reading is due (both hooks, quota and advise), so nothing waits for it.
func refreshCodexBarLater(st *store.Store, now time.Time) {
	p := quotaPaths(st)
	if len(quota.CodexBarEnabled(p.CodexBarFile)) == 0 {
		return
	}
	switch {
	case quota.CodexBarFetchDue(st.Dir, now):
		_ = detach.Start("codexbar", "fetch", "--quiet") // refreshes once fetched
	case quota.CodexBarDue(p, now):
		_ = detach.Start("codexbar", "refresh", "--quiet")
	}
}

func filterSource(es []advise.Event, source string) []advise.Event {
	if source == "" {
		return es
	}
	var out []advise.Event
	for _, e := range es {
		if e.Source == source {
			out = append(out, e)
		}
	}
	return out
}

func nonNil(es []advise.Event) []advise.Event {
	if es == nil {
		return []advise.Event{}
	}
	return es
}

// quotaPaths: the shared cache, $CODEX_HOME (default ~/.codex), ~/.config/modelplan/local.json and
// ~/.config/modelplan/codexbar.json.
func quotaPaths(st *store.Store) quota.Paths {
	home, _ := os.UserHomeDir()
	codex := os.Getenv("CODEX_HOME")
	if codex == "" {
		codex = filepath.Join(home, ".codex")
	}
	// Codex sets CODEX_THREAD_ID and Claude Code CLAUDE_CODE_SESSION_ID for the commands a
	// thread runs, so a Skill calling `modelplan quota` reads that thread's own model and effort.
	return quota.Paths{Cache: st.Dir, CodexHome: codex, LocalFile: filepath.Join(home, ".config", "modelplan", "local.json"),
		CodexBarFile: filepath.Join(home, ".config", "modelplan", "codexbar.json"), CodexThread: os.Getenv("CODEX_THREAD_ID"), ClaudeSession: os.Getenv("CLAUDE_CODE_SESSION_ID")}
}

// reorder lets flags follow positional args: `modelplan effort opus --json`.
func reorder(args []string) []string {
	var fl, pos []string
	for i := 0; i < len(args); i++ {
		a := args[i]
		if strings.HasPrefix(a, "-") {
			fl = append(fl, a)
			name := strings.TrimLeft(a, "-")
			if !strings.Contains(name, "=") && takesValue[name] && i+1 < len(args) {
				fl = append(fl, args[i+1])
				i++
			}
			continue
		}
		pos = append(pos, a)
	}
	return append(fl, pos...)
}

var takesValue = map[string]bool{"lang": true, "base": true, "dev": true, "harness": true, "model": true, "effort": true, "source": true, "hook": true, "add-system": true, "add-context": true}

func printJSON(w io.Writer, v any) int {
	e := json.NewEncoder(w)
	e.SetIndent("", "  ")
	e.SetEscapeHTML(false)
	if err := e.Encode(v); err != nil {
		return exitErr
	}
	return 0
}

func isTTY(w any) bool {
	f, ok := w.(*os.File)
	if !ok {
		return false
	}
	fi, err := f.Stat()
	return err == nil && fi.Mode()&os.ModeCharDevice != 0
}
