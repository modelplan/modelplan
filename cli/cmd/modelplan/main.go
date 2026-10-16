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
)

const usage = `modelplan — Model Plan thin client (read-only, anonymous)

  modelplan lineup [--dev anthropic]   WHICH ENGINE: a developer's models at ★ recommended effort
  modelplan effort [model]             one model's effort ladder (default: Claude Code's current model)
  modelplan models [--dev openai]      models with ★ effort, ability and cost
  modelplan quota                      your own usage windows: this machine's logs, and Codex's own
                                       account reading (--refresh-account asks it now; at most every
                                       5 min in the background; MODELPLAN_CODEX_ACCOUNT=off to skip)
  modelplan advise [--source codex]    what to do about them now: step up before a reset, step down,
                                       switch back after it, peak hours, cards, public resets
                                       (--hook claude-code|codex: prompt hook, each hint once)
  modelplan statusline                 one line for Claude Code / other status bars (cache only)
  modelplan sync [--force]             refresh the local cache from the verified publication
  modelplan doctor                     show base URL, cache and publication state
  modelplan version

Common flags: --json  --lang zh|en  --offline  --no-color  --base URL
Env: MODELPLAN_BASE, MODELPLAN_CACHE, MODELPLAN_LANG, NO_COLOR
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
	source := fs.String("source", "", "advise: only claude-code, codex or user events")
	hook := fs.String("hook", "", "advise: run as a harness hook (claude-code); print only hints not shown before")
	refreshAccount := fs.Bool("refresh-account", false, "quota: ask Codex for the account's windows and reset credits now")
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
			return adviseHook(stdin, stdout, style, st, *hook)
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
		return statusline(stdin, stdout, style, st, c, *harness, *modelFlag, *effortFlag)

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
func statusline(stdin io.Reader, stdout io.Writer, style render.Style, st *store.Store, c common, harness, modelID, effort string) int {
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
		_ = quota.RecordClaudeCode(st.Dir, in, now)
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
		hint = statuslineHint(style, st, d, *acct, now)
	}
	if q := style.QuotaSegment(acct, hint); q != "" {
		tail += " │ " + q
	}
	if err != nil {
		fmt.Fprintln(stdout, style.Statusline(nil, nil, "", false, "")+" · "+style.T.Syncing+tail)
		return 0
	}
	m := d.Match(harness, modelID, in.Model.DisplayName)
	raw := in.Model.DisplayName
	if raw == "" {
		raw = modelID
	}
	fmt.Fprintln(stdout, style.Statusline(d, m, effort, time.Since(s.CheckedAt) > alarmAfter, raw)+tail)
	return 0
}

// statuslineHint: the most urgent Claude Code advice as a few characters ("↑High ×1.37",
// "↺★Med"). It remembers advised windows so the switch-back hint appears after the reset.
func statuslineHint(style render.Style, st *store.Store, d *digest.Digest, acct quota.Account, now time.Time) string {
	state := advise.Load(st.Dir)
	es := advise.Derive(advise.Input{Report: quota.Report{Accounts: []quota.Account{acct}}, Digest: d, State: state, Now: now})
	_ = state.Save(st.Dir, now)
	for _, e := range es {
		if e.Source == "claude-code" {
			if h := style.AdviceShort(e); h != "" {
				return h
			}
		}
	}
	return ""
}

// adviseHook is a UserPromptSubmit hook for Claude Code or Codex (both accept the same
// output): new advice goes to the model as additional context, once per event. It never
// fails the prompt and never touches the network.
func adviseHook(stdin io.Reader, stdout io.Writer, style render.Style, st *store.Store, harness string) int {
	b, _ := io.ReadAll(io.LimitReader(stdin, 1<<20))
	if harness != "claude-code" && harness != "codex" {
		return 0
	}
	// Hook input names the prompting thread; nothing else is decoded from it.
	var in struct {
		SessionID string `json:"session_id"`
	}
	_ = json.Unmarshal(b, &in)
	now := time.Now()
	d, _, _ := publication.Load(st)
	state := advise.Load(st.Dir)
	paths := quotaPaths(st)
	if harness == "claude-code" {
		paths.CodexHome = "" // Codex advice belongs to Codex; skip scanning its logs on every prompt
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
	es = state.Unseen(es)
	var parts []string
	if len(es) > 0 {
		parts = append(parts, style.AdviceContext(es))
		state.MarkSeen(es, now)
	}
	// The first prompt of a Codex thread also gets the task-start brief: the model judges the
	// task, the publication supplies the options. Once per thread.
	if harness == "codex" && in.SessionID != "" && os.Getenv("MODELPLAN_TASK_BRIEF") != "off" {
		for i := range report.Accounts {
			if a := &report.Accounts[i]; a.Source == "codex" {
				if brief := advise.TaskStart(a, d, now); brief != nil && state.Once("task_start|"+in.SessionID, now) {
					parts = append(parts, render.TaskBrief(brief))
				}
			}
		}
	}
	if len(parts) > 0 {
		out := map[string]any{"hookSpecificOutput": map[string]any{"hookEventName": "UserPromptSubmit", "additionalContext": strings.Join(parts, "\n\n")}}
		b, _ := json.Marshal(out)
		fmt.Fprintln(stdout, string(b))
	}
	_ = state.Save(st.Dir, now)
	return 0
}

// refreshAccountLater asks Codex for the account reading in the background when the cached one
// is due, so hooks and the plugin never wait for it.
func refreshAccountLater(st *store.Store) {
	if quota.AccountDue(st.Dir, time.Now()) {
		_ = detach.Start("quota", "--refresh-account", "--quiet")
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

// quotaPaths: the shared cache, $CODEX_HOME (default ~/.codex) and ~/.config/modelplan/local.json.
func quotaPaths(st *store.Store) quota.Paths {
	home, _ := os.UserHomeDir()
	codex := os.Getenv("CODEX_HOME")
	if codex == "" {
		codex = filepath.Join(home, ".codex")
	}
	// Codex sets CODEX_THREAD_ID for the commands a thread runs, so a Skill calling
	// `modelplan quota` from Codex reads that thread's own model and effort.
	return quota.Paths{Cache: st.Dir, CodexHome: codex, LocalFile: filepath.Join(home, ".config", "modelplan", "local.json"), CodexThread: os.Getenv("CODEX_THREAD_ID")}
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

var takesValue = map[string]bool{"lang": true, "base": true, "dev": true, "harness": true, "model": true, "effort": true, "source": true, "hook": true}

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
