// Command modelplan is the ModelPlan thin client: a read-only view of the verified
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
	"strconv"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/connections"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detach"
	"github.com/modelplan/modelplan/cli/internal/diagnostics"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/qwenusage"
	"github.com/modelplan/modelplan/cli/internal/render"
	"github.com/modelplan/modelplan/cli/internal/snapshot"
	"github.com/modelplan/modelplan/cli/internal/speed"
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
	hookSaveBudget  = 4300 * time.Millisecond // leave time to record an error before the host timeout
)

const usage = `modelplan — ModelPlan thin client (read-only, anonymous)

  modelplan lineup [--dev anthropic]   WHICH ENGINE: a developer's models at ★ recommended effort
  modelplan plan [--dev anthropic]     decision view, with connected-plan time rates
  modelplan windows [--provider X]     public billing windows (cache only; --plan ID --model NAME)
  modelplan effort [model]             one model's effort ladder (default: Claude Code's current model),
                                       with your own measured speed per effort when there is some
  modelplan models [--dev openai]      models with ★ effort, ability and cost
  modelplan publication --json         verified public models, lineups and speed tiers; no personal data
  modelplan quota                      your own usage windows: this machine's logs, and Codex's own
                                       account reading (--refresh-account asks it now; at most every
                                       5 min in the background; MODELPLAN_CODEX_ACCOUNT=off to skip)
  modelplan detect [--json]            presence-only tool detection; no credentials or network
  modelplan consent --json             read shared consent and bilingual consent text
  modelplan consent grant --json       atomically apply a per-scope JSON request from stdin
  modelplan consent init --json        establish the store epoch before mutation
  modelplan consent cleanup --json     retry interrupted scoped erasure
  modelplan consent reset confirmed --json
                                       confirmed recovery with a new epoch; grants must be given again
  modelplan connect <provider> [--backend native|codexbar] [--region …] [--key-env NAME]
  modelplan connect --detected [--privacy automatic|passive] [--json]
                                       preview or confirm the pre-checked detected-tool list once
  modelplan connect <tool> --browser-session
                                       separate advanced consent; browser Safe Storage and cookie cache explained
  modelplan disconnect <tool|--all>    revoke consent and delete that tool's cached readings
  modelplan connections [status|refresh]
                                       which reader serves each other plan (connections.json):
                                       native readers ask the vendor with an API key from an
                                       environment variable (zai: Z_AI_API_KEY, opencodego:
                                       OPENCODE_API_KEY; cursor: read-only editor sign-in; kimi: KIMI_CODE_API_KEY, --region china|international;
                                       minimax: MINIMAX_CODING_API_KEY, --region international|china;
                                       kiro asks kiro-cli); the key is never
                                       stored. Providers without one stay on CodexBar
  modelplan codexbar [status|enable <provider…>|disable [provider…]|fetch|refresh]
                                       other plans through CodexBar's CLI (copilot, cursor, zai, kiro,
                                       opencodego): off until enabled; CodexBar keeps the sign-ins,
                                       this client fetches its pinned release and reads its JSON
  modelplan advise [--source codex]    what to do about them now: step up before a reset, step down,
                                       switch back after it, peak hours, cards, public resets
                                       (--hook claude-code|codex: prompt hook; hints shown to the
                                       user once, a task-start brief for the model per thread)
  modelplan desktop                    the personal snapshot for the desktop app (JSON): sessions,
                                       quota, advice, measured speed and a year of tokens per day
                                       (docs/personal-snapshot.md; --read-only writes, refreshes
                                       and starts nothing)
  modelplan project-labels [status|on|off]
                                       name projects by their folder in the snapshot's project
                                       ranking: on by default, the names stay on this machine;
                                       off keeps only opaque references and deletes the stored names
  modelplan qwen-usage --export PATH  optional aggregated Qwen JSON export (local only)
  modelplan usage <gemini|qwen> [enable|disable|status]
                                       opt-in local Gemini/Qwen tokens/model/history (no account quota);
                                       MODELPLAN_GEMINI_HOME selects its local data root
  modelplan history                    how much of each window you used and under which model and
                                       effort, and your measured speed (output tok/s, first token,
                                       turn time and tokens) per configuration, recorded on this
                                       machine only from log timestamps and token counts
                                       (MODELPLAN_HISTORY=off stops both, and the tokens per day)
  modelplan history --effort-suggestion dismiss|off|on
                                       control local weekly effort suggestions (default off; never changes settings)
  modelplan declare <planId> [generation] [--region ID]
                                       record which plan pays for another vendor's model (GLM through
                                       Z.ai in Claude Code) in ~/.config/modelplan/local.json, so
                                       advice follows how it counts usage (--remove takes it out)
  modelplan statusline                 one line for Claude Code / other status bars (cache only;
                                       --preview renders a sample without recording it)
  modelplan sync [--force]             refresh the local cache from the verified publication
  modelplan doctor                     show base URL, cache and publication state
  modelplan doctor readers [--refresh] sanitised native-reader verification; cache only by default
  modelplan doctor --share             sanitised cache source/status report; no readers or network
  modelplan diagnostics --share        copy-safe versions, enabled scopes and recent error codes
  modelplan update                     explicitly update a standalone/Skill copy from the verified publication pin
  modelplan plugin install claude-code|codex
                                       install through the host CLI; otherwise print its commands
  modelplan version

Common flags: --json  --lang zh|en  --offline  --no-color  --base URL
Env: MODELPLAN_BASE, MODELPLAN_CACHE, MODELPLAN_LANG, NO_COLOR,
     MODELPLAN_READERS=passive|off (restrict shared reader permissions),
     MODELPLAN_EFFORT_SUGGESTION=on (opt in to local weekly effort suggestions; default off),
     MODELPLAN_TASK_BRIEF=off (no task-start brief), MODELPLAN_HISTORY=off (no quota history, speed measurement or tokens per day), MODELPLAN_CODEX_ACCOUNT=off (no Codex account reading),
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

// printStaticFlagUsage prints flag names and compiled descriptions only. Values,
// including environment-derived defaults and rejected arguments, never appear.
func printStaticFlagUsage(w io.Writer, fs *flag.FlagSet) {
	fmt.Fprintln(w, "Options:")
	fs.VisitAll(func(f *flag.Flag) {
		_, description := flag.UnquoteUsage(f)
		fmt.Fprintf(w, "  --%s: %s\n", f.Name, description)
	})
}

const diagnosticsUsage = "usage: modelplan diagnostics --share [--app-version VERSION]\n"

func diagnosticsCmd(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("diagnostics", flag.ContinueOnError)
	fs.SetOutput(io.Discard) // flag errors can contain untrusted argument values
	share := fs.Bool("share", false, "")
	appVersion := fs.String("app-version", "", "")
	fs.Bool("json", false, "") // output is always JSON
	if err := fs.Parse(args); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			fmt.Fprint(stdout, diagnosticsUsage)
			return 0
		}
		fmt.Fprint(stderr, diagnosticsUsage)
		return exitUsage
	}
	if !*share || fs.NArg() != 0 {
		fmt.Fprint(stderr, diagnosticsUsage)
		return exitUsage
	}
	st, err := store.Locate()
	if err != nil {
		fmt.Fprintln(stderr, "diagnostics: cache_unavailable")
		return exitErr
	}
	return printJSON(stdout, diagnostics.CollectFeedback(st.Dir, version, *appVersion, time.Now()))
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func main() { os.Exit(run(os.Args[1:], os.Stdin, os.Stdout, os.Stderr)) }

// startDetached runs this binary again in the background; tests replace it.
var startDetached = detach.Start

func run(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	if len(args) > 0 && args[0] == "app-server" {
		return appServerCmd(args[1:], stdin, stdout, stderr)
	}
	if len(args) == 0 || args[0] == "-h" || args[0] == "--help" || args[0] == "help" {
		fmt.Fprint(stdout, usage)
		return 0
	}
	cmd, rest := args[0], args[1:]
	if cmd == "diagnostics" {
		return diagnosticsCmd(rest, stdout, stderr)
	}
	var c common
	fs := flags(cmd, &c)
	fs.SetOutput(io.Discard)
	provider := fs.String("provider", "", "windows: published provider id")
	planFlag := fs.String("plan", "", "windows: published plan id")
	dev := fs.String("dev", "", "developer id, e.g. anthropic, openai, zhipuai")
	force := fs.Bool("force", false, "sync: ignore the 10-minute check interval")
	background := fs.Bool("background", false, "sync: detach and return immediately")
	quiet := fs.Bool("quiet", false, "sync: print nothing on success")
	scheduled := fs.Bool("scheduled", false, "sync/connections refresh: scheduled background refresh")
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
	backend := fs.String("backend", "native", "connect: native (this client's own reader) or codexbar")
	region := fs.String("region", "", "connect: the provider's region (zai: global or bigmodel-cn)")
	profile := fs.String("profile", "", "connect zai: explicit local source (claude-code); no credential read during connect")
	keyEnv := fs.String("key-env", "", "connect: the environment variable that holds the API key")
	detected := fs.Bool("detected", false, "connect: choose detected tools with one consent confirmation")
	privacy := fs.String("privacy", "", "connect --detected: automatic or passive")
	browserSession := fs.Bool("browser-session", false, "connect: separately consent to one advanced browser-session provider")
	all := fs.Bool("all", false, "disconnect: revoke all tools and delete readings")
	qwenExport := fs.String("export", "", "qwen-usage: optional Qwen JSON export file or directory")
	effortSuggestion := fs.String("effort-suggestion", "", "history: dismiss for one week, off, or on (local only)")
	readOnly := fs.Bool("read-only", false, "desktop: read what is on disk without writing, refreshing or starting anything")
	refreshReaders := fs.Bool("refresh", false, "doctor readers: explicitly refresh admitted readers within request budgets")
	share := fs.Bool("share", false, "doctor: print a sanitised share report")
	if err := fs.Parse(reorder(rest)); err != nil {
		if !errors.Is(err, flag.ErrHelp) {
			fmt.Fprintln(stderr, "invalid command flags")
		}
		printStaticFlagUsage(stderr, fs)
		return exitUsage
	}
	if cmd == "lineup" || cmd == "plan" {
		if fs.NArg() > 1 || fs.NArg() == 1 && *dev != "" && !strings.EqualFold(*dev, fs.Arg(0)) {
			fmt.Fprintln(stderr, "usage: modelplan "+cmd+" [developer-id | --dev ID]")
			return exitUsage
		}
		if fs.NArg() == 1 {
			*dev = fs.Arg(0)
		}
		*dev = strings.ToLower(*dev)
	}
	if cmd == "windows" {
		if fs.NArg() != 0 {
			fmt.Fprintln(stderr, "usage: modelplan windows [--provider X] [--plan ID] [--model NAME] [--region REGION] [--json]")
			return exitUsage
		}
		c.offline = true
	}
	if cmd == "doctor" && fs.NArg() > 0 && fs.Arg(0) == "readers" {
		if fs.NArg() != 1 || *share || (c.offline && *refreshReaders) {
			fmt.Fprintln(stderr, "usage: modelplan doctor readers [--json] [--refresh] [--lang en|zh]; --refresh cannot be offline")
			return exitUsage
		}
		return doctorReaders(stdout, stderr, c, *refreshReaders)
	}
	if *refreshReaders {
		fmt.Fprintln(stderr, "--refresh requires doctor readers")
		return exitUsage
	}
	if *share {
		if cmd != "doctor" || fs.NArg() != 0 {
			fmt.Fprintln(stderr, "usage: modelplan doctor --share [--json]")
			return exitUsage
		}
		st, err := store.Locate()
		if err != nil {
			fmt.Fprintln(stderr, "doctor --share: cache location unavailable / 无法定位缓存")
			return exitErr
		}
		return printJSON(stdout, diagnostics.Collect(st.Dir, version))
	}
	if cmd == "update" {
		return updateCmd(fs.Args(), stdout, stderr, c)
	}
	if cmd == "plugin" {
		return pluginCmd(fs.Args(), stdin, stdout, stderr, c)
	}

	if cmd == "publication" && (!c.json || fs.NArg() != 0) {
		fmt.Fprintln(stderr, "usage: modelplan publication --json [--offline]")
		return exitUsage
	}
	if cmd == "consent" && !c.json {
		fmt.Fprintln(stderr, "usage: modelplan consent [grant] --json")
		return exitUsage
	}

	if *effortSuggestion != "" && (cmd != "history" || (*effortSuggestion != "dismiss" && *effortSuggestion != "off" && *effortSuggestion != "on")) {
		fmt.Fprintln(stderr, "usage: modelplan history --effort-suggestion dismiss|off|on")
		return exitUsage
	}

	open := store.Open
	if cmd == "windows" || cmd == "detect" || cmd == "consent" || cmd == "connect" || cmd == "disconnect" || (cmd == "desktop" && *readOnly) || (cmd == "publication" && c.offline) {
		open = store.Locate // creates nothing
	}
	st, err := open()
	if err != nil {
		fmt.Fprintln(stderr, "cache:", err)
		return exitErr
	}
	if cmd == "detect" {
		return detectCmd(fs.Args(), stdout, stderr, st, c)
	}
	if cmd == "consent" {
		return consentCmd(fs.Args(), stdin, stdout, st, c)
	}
	if cmd == "connect" && *detected {
		if fs.NArg() != 0 || *browserSession {
			fmt.Fprintln(stderr, "usage: modelplan connect --detected [--json] [--privacy automatic|passive]")
			return exitUsage
		}
		return connectDetected(stdin, stdout, stderr, st, c, *privacy)
	}
	if cmd == "connect" {
		return connectProvider(fs.Args(), stdin, stdout, stderr, st, c, *backend, *region, *keyEnv, *privacy, *profile, *browserSession)
	}
	if cmd == "disconnect" {
		return disconnectTools(fs.Args(), *all, stdout, stderr, st, c)
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
			if err := startDetached("sync", "--quiet", "--base", c.base); err != nil {
				fmt.Fprintln(stderr, err)
				return exitErr
			}
			return 0
		}
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		client.NoCheckDelay = !*scheduled
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
		if !*quiet {
			detectedHint(st, stderr, c)
		}
		if *refreshAccount && consent.Allowed("codex", consent.Runtime) {
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
			refreshNativeLater(st)
		}
		r := quota.ReadPermitted(quotaPaths(st), time.Now())
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
			refreshNativeLater(st)
		}
		d, _, _ := publication.Load(st)
		state := advise.Load(st.Dir)
		now := time.Now()
		report := quota.ReadPermitted(quotaPaths(st), now)
		observeQuotaHistory(st, report, now)
		observeCodexSpeed(st, now)
		observeAgents(st, now)
		es := filterSource(advise.Derive(advise.Input{Report: report, Digest: d, State: state, Now: now}), *source)
		if c.json {
			saveAdviceState(state, st.Dir, now)
			for i := range es {
				es[i].Text = map[string]string{"zh": render.Style{T: render.ZH}.AdviceLine(es[i]), "en": render.Style{T: render.EN}.AdviceLine(es[i])}
			}
			return printJSON(stdout, map[string]any{"schemaVersion": 1, "evaluatedAt": now.UTC(), "events": nonNil(es)})
		}
		es = claimPaceWarnings(st.Dir, es, now)
		style.Advice(stdout, es)
		for _, e := range es {
			if e.Type == advise.WindowPace {
				state.MarkSeen([]advise.Event{e}, now)
			}
		}
		saveAdviceState(state, st.Dir, now)
		return 0

	case "qwen-usage":
		return qwenUsageCmd(stdout, c, *qwenExport)
	case "usage":
		return usageCmd(fs.Args(), stdout, stderr, c)

	case "history":
		if *effortSuggestion != "" {
			if err := history.SetEffortSuggestion(st.Dir, *effortSuggestion, time.Now()); err != nil {
				fmt.Fprintln(stderr, err)
				return exitErr
			}
			if c.json {
				return printJSON(stdout, map[string]string{"effortSuggestion": *effortSuggestion})
			}
			if c.lang == "en" {
				fmt.Fprintln(stdout, "Local effort suggestion preference:", *effortSuggestion)
			} else {
				fmt.Fprintln(stdout, "本机档位建议设置：", *effortSuggestion)
			}
			return 0
		}
		l := history.Load(st.Dir)
		now := time.Now()
		observeCodexSpeed(st, now)
		observeAgents(st, now)
		measured := speed.Summarize(speed.Load(st.Dir), now)
		if c.json {
			return printJSON(stdout, map[string]any{"schemaVersion": 1, "recording": !history.Off(), "file": history.Path(st.Dir), "cycles": nonNilCycles(l.Cycles),
				"measured": measured, "measuredFile": speed.Path(st.Dir),
				"note": "Recorded on this machine only, never uploaded: per usage window, the use at its last reading and the points each harness configuration spent (points before the first reading are not attributed); per configuration, the measured output rate, time to first token and turn time and tokens, from the harness logs' timestamps and token counts only."})
		}
		d, _, _ := publication.Load(st)
		style.History(stdout, l, d, history.Path(st.Dir), now)
		if v := history.NotifyEffortSuggestion(st.Dir, d, now); v != nil {
			if c.lang == "en" {
				fmt.Fprintln(stdout, "\nDefault effort suggestion (local only)")
			} else {
				fmt.Fprintln(stdout, "\n默认档位建议（仅本机）")
			}
			fmt.Fprintln(stdout, style.EffortSuggestionLine(v))
		}
		fmt.Fprintln(stdout)
		style.Measured(stdout, measured, d, true)
		return 0

	case "desktop":
		return desktopCmd(stdout, st, c, *readOnly)

	case "statusline":
		if *recordOnly {
			stdout = io.Discard
		}
		return statusline(stdin, stdout, style, st, c, *harness, *modelFlag, *effortFlag, *preview)

	case "project-labels":
		return projectLabelsCmd(fs.Args(), stdout, stderr, st, c)

	case "connect", "disconnect", "connections":
		return connectCmd(cmd, fs.Args(), stdout, stderr, st, c, *quiet, *scheduled, *backend, *region, *keyEnv)

	case "codexbar":
		return codexbarCmd(fs.Args(), stdout, stderr, st, c, *quiet)

	case "declare":
		return declareCmd(fs.Args(), stdout, stderr, st, c, *remove, *region)

	case "doctor":
		s, _ := st.State()
		d, _, lerr := publication.Load(st)
		s.Base = publication.DisplayBase(s.Base)
		if s.LastError != "" {
			s.LastError = "previous sync failed"
		}
		out := map[string]any{"version": version, "base": publication.DisplayBase(c.base), "cache": st.Dir, "state": s}
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
	case "publication":
		return printJSON(stdout, d.Publication())
	case "windows":
		if calendar, _, err := publication.LoadWindows(st); err == nil {
			d = calendar
		}
		now := time.Now()
		groups := advise.Windows(d, advise.WindowFilter{Provider: *provider, Plan: *planFlag, Model: *modelFlag, Region: *region}, now)
		if c.json {
			return printJSON(stdout, map[string]any{"schemaVersion": 1, "publicationId": d.PublicationID, "evaluatedAt": now.UTC(), "horizon": d.MultiplierHorizon, "groups": groups})
		}
		style.Windows(stdout, groups)
	case "lineup", "plan":
		devs := []string{*dev}
		if *dev == "" {
			devs = []string{"anthropic", "openai"}
		}
		now := time.Now()
		var models []*digest.Model
		for _, v := range devs {
			models = append(models, d.Developer(v)...)
		}
		report := quota.Report{Accounts: quota.DeclaredPlans(quotaPaths(st).LocalFile, now)}
		billing := advise.Billing(d, report, models, now)
		if c.json {
			out := map[string]any{"billingContext": billing, "billingNote": "Context only: base API reference cost × time rate; the user decides. See modelplan windows.", "evaluatedAt": now.UTC(), "publicationId": d.PublicationID, "units": d.Units, "lineups": map[string]*digest.PublishedLineup{}}
			for _, v := range devs {
				out["lineups"].(map[string]*digest.PublishedLineup)[v] = d.PublishedLineup(v)
			}
			return printJSON(stdout, out)
		}
		for i, v := range devs {
			if i > 0 {
				fmt.Fprintln(stdout)
			}
			if err := style.Lineup(stdout, d, v, billing); err != nil {
				fmt.Fprintln(stderr, err)
				return exitErr
			}
		}
		if len(billing) == 0 {
			style.BillingFootnote(stdout)
		} else {
			style.BillingHint(stdout, billing)
		}
	case "effort":
		q := strings.Join(fs.Args(), " ")
		if q == "" {
			// No model given: the one Claude Code last reported to the status line.
			for _, a := range quota.ReadPermitted(quotaPaths(st), time.Now()).Accounts {
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
		measured := render.MeasuredFor(speed.Summarize(speed.Load(st.Dir), time.Now()), d, m)
		if c.json {
			return printJSON(stdout, struct {
				*digest.Model
				SpeedTiers []digest.ModelTier `json:"speedTiers,omitempty"`
				Measured   []speed.Stat       `json:"measured"`
			}{m, tiers, measured})
		}
		style.Effort(stdout, m)
		style.Speed(stdout, tiers)
		if len(measured) > 0 {
			fmt.Fprintln(stdout)
			style.Measured(stdout, measured, d, true)
		}
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
		client.NoCheckDelay = true
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

// statuslineLockWait bounds how long a status line waits for the reader lock.
var statuslineLockWait = 400 * time.Millisecond

// statusline is cache-only: it may start a detached sync but never waits on the network.
// For Claude Code it also records the usage windows the harness passes on stdin, so the
// Skill and `modelplan quota` can read them later.
func statusline(stdin io.Reader, stdout io.Writer, style render.Style, st *store.Store, c common, harness, modelID, effort string, preview bool) int {
	// Claude Code passes the terminal width; without it the full form is used.
	if cols, err := strconv.Atoi(os.Getenv("COLUMNS")); err == nil && cols > 0 && cols < render.StatuslineWide {
		style.Narrow = true
	}
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
	if preview {
		return statuslineInput(in, stdout, style, st, c, harness, modelID, effort, true)
	}
	// Another session's status line or a hook may hold the lock for a moment; wait briefly
	// rather than drop this session's reading (each session keeps its own in the snapshot).
	ctx, cancel := context.WithTimeout(context.Background(), statuslineLockWait)
	unlock, err := consent.ReaderLockContext(ctx)
	cancel()
	if err != nil {
		return 0
	}
	defer unlock()
	state, err := consent.Load(consent.Path())
	if err != nil {
		return 0
	}
	code := 0
	if err := consent.Publish(state.Fence(), func() error {
		code = statuslineInput(in, stdout, style, st, c, harness, modelID, effort, false)
		return nil
	}); err != nil {
		return 0
	}
	return code
}

func statuslineInput(in quota.StatuslineInput, stdout io.Writer, style render.Style, st *store.Store, c common, harness, modelID, effort string, preview bool) int {
	now := time.Now()
	var acct *quota.Account
	if harness == "claude-code" && (preview || consent.Allowed("claude", consent.Local)) {
		// A custom endpoint (GLM through Z.ai) decides which model an id means and which plan pays.
		in.Endpoint = digest.Endpoint(os.Getenv("ANTHROPIC_BASE_URL"))
		if !preview && consent.Allowed("claude", consent.Local) {
			_ = quota.RecordClaudeCode(st.Dir, in, now)
		}
		a := in.Account(now)
		if !preview && consent.Allowed("claude", consent.Local) {
			quota.AttachRecent(st.Dir, &a)
			_ = history.Observe(st.Dir, quota.Report{Accounts: []quota.Account{a}}, now)
			_ = speed.ObserveClaude(st.Dir, in.TranscriptPath, true, speed.Ingest{Labels: projectLabels(), Subscription: quota.ClaudeSubscription(st.Dir)}, now)
		}
		quota.Evaluate(&a, now)
		acct = &a
	}
	s, _ := st.State()
	if !c.offline && time.Since(s.CheckedAt) > staleAfter && time.Since(s.LastAttemptAt) > backgroundEvery {
		_ = startDetached("sync", "--quiet", "--scheduled", "--base", c.base)
	}
	tail := ""
	if in.FastMode != nil && *in.FastMode {
		tail += " ⚡fast"
	}
	d, s, err := publication.Load(st)
	hint := ""
	if acct != nil {
		// Explicit status-line flags also identify the current configuration for
		// personal advice; do not substitute the publication's recommended effort.
		if modelID != "" {
			acct.Harness.Model = modelID
		}
		if effort != "" {
			acct.Harness.Effort = effort
		}
		var report quota.Report
		report, acct = linkedReport(st, d, *acct, now)
		if style.QuotaSegment(acct, "") != "" {
			hint = statuslineHint(style, st, d, report, now, !preview && stdout != io.Discard)
		}
	}
	q := style.QuotaSegment(acct, hint)
	if q != "" {
		tail += " │ " + q
	}
	if err != nil {
		fmt.Fprintln(stdout, style.Statusline(nil, nil, "", false, "", q != "")+" · "+style.T.Syncing+tail)
		return 0
	}
	m := d.MatchAt(harness, in.Endpoint, modelID, in.Model.DisplayName)
	raw := in.Model.DisplayName
	if raw == "" {
		raw = modelID
	}
	fmt.Fprintln(stdout, style.Statusline(d, m, effort, time.Since(s.CheckedAt) > alarmAfter, raw, q != "")+tail)
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
	full := quota.ReadPermitted(p, now)
	for _, a := range full.Accounts {
		if a.Source != "claude-code" {
			r.Accounts = append(r.Accounts, a)
		}
	}
	eff, _ := advise.Link(&acct, r, d)
	return r, &eff
}

// statuslineHint: the most urgent Claude Code advice as a few characters ("↑High ×1.37",
// "↺★Med", "→Opus 5.5 ★Med ×0.52"). It remembers advised windows so the switch-back hint appears
// after the reset, for 90 minutes from when it first shows, and a better model for a week.
func statuslineHint(style render.Style, st *store.Store, d *digest.Digest, report quota.Report, now time.Time, save bool) string {
	state := advise.Load(st.Dir)
	es := advise.Derive(advise.Input{Report: report, Digest: d, State: state, Now: now})
	hint := ""
	personalAllowed := true
	for _, e := range es {
		if e.Source == "claude-code" && (e.Type == advise.WindowExhausted || e.Type == advise.WindowTight || e.InStatusLine(now)) {
			personalAllowed = false
		}
		if e.Source == "claude-code" && e.InStatusLine(now) {
			if e.Type == advise.WindowPace && save && (e.At == nil || !history.ClaimPaceWarning(st.Dir, e.Key, *e.At, now)) {
				continue
			}
			if hint = style.AdviceShort(e); hint != "" {
				if save {
					state.NoteShown(e, now)
				}
				break
			}
		}
	}
	if save {
		saveAdviceState(state, st.Dir, now)
		if hint == "" && personalAllowed {
			hint = defaultEffortHint(style, st, d, report, now)
		}
	}
	return hint
}

// defaultEffortHint is user-only and cache-only. It matches the current weekly
// pool and explicit harness configuration, so another subscription's history or
// another model's past default cannot supply the status-line hint.
// An unknown plan label matches only other unknown labels.
func defaultEffortHint(style render.Style, st *store.Store, d *digest.Digest, report quota.Report, now time.Time) string {
	if history.Off() || d == nil {
		return ""
	}
	for _, a := range report.Accounts {
		if a.Source != "claude-code" || a.Harness == nil || a.Harness.Endpoint != "" {
			continue
		}
		for _, w := range a.Windows {
			if w.Kind != "weekly" {
				continue
			}
			var cycles []history.Cycle
			for _, c := range history.Load(st.Dir).Cycles {
				if c.Source == a.Source && c.Plan == a.Plan && c.Limit == w.Limit && c.Kind == "weekly" && c.Done(now) &&
					(w.WindowMinutes == 0 || c.WindowMinutes == 0 || c.WindowMinutes == w.WindowMinutes) {
					cycles = append(cycles, c)
				}
			}
			current := history.Share{Model: a.Harness.Model, Effort: a.Harness.Effort,
				Fast: (a.Harness.FastMode != nil && *a.Harness.FastMode) || a.Harness.ServiceTier == "fast"}
			v := history.SuggestDefaultEffort(cycles, current, d, now)
			if v = history.ClaimEffortSuggestion(st.Dir, v, now); v != nil {
				return style.EffortSuggestionShort(v)
			}
		}
	}
	return ""
}

// adviseHook is a UserPromptSubmit hook for Claude Code or Codex (both accept the same
// output). What the user decides on (quota hints, once per event; the question which plan pays
// for another vendor's model) is shown to the user as the hook's systemMessage and never reaches
// the model. The model gets the task-start brief, a ladder for a new model, and one factual
// notice per low/reset quota window per thread. A plugin may pass its setup notice so the
// hook prints one object. It never fails the prompt and never waits on the network.
func adviseHook(stdin io.Reader, stdout io.Writer, style render.Style, st *store.Store, client *publication.Client, c common, harness, system, notice string) int {
	return adviseHookAt(stdin, stdout, style, st, client, c, harness, system, notice, time.Now())
}

func adviseHookAt(stdin io.Reader, stdout io.Writer, style render.Style, st *store.Store, client *publication.Client, c common, harness, system, notice string, now time.Time) int {
	deadline := time.Now().Add(hookSaveBudget)
	b, _ := io.ReadAll(io.LimitReader(stdin, 1<<20))
	if harness != "claude-code" && harness != "codex" {
		return 0
	}
	// Hook input names the prompting thread; nothing else is decoded from it.
	var in struct {
		SessionID      string `json:"session_id"`
		Model          string `json:"model"`
		TranscriptPath string `json:"transcript_path"` // Claude Code: read for local speed measurement
		Event          string `json:"hook_event_name"`
		Source         string `json:"source"` // SessionStart: startup | resume | clear | compact
	}
	_ = json.Unmarshal(b, &in)
	if in.Event == "SessionStart" {
		return sessionStartHook(stdout, style, st, harness, in.SessionID, in.Model, in.Source, now)
	}
	// Without the status line nothing else keeps the publication fresh for Claude Code. With no
	// publication at all (just installed) the first prompt waits briefly for one, so it gets the
	// brief, and a sync that does not finish in time goes on in the background for the next
	// prompt; otherwise a stale one is refreshed in the background.
	d, _, _ := publication.Load(st)
	if s, _ := st.State(); !c.offline && time.Since(s.LastAttemptAt) > backgroundEvery {
		if d == nil {
			ctx, cancel := context.WithTimeout(context.Background(), firstSyncWait)
			client.NoCheckDelay = true
			_, _ = client.Sync(ctx, false)
			cancel()
			if d, _, _ = publication.Load(st); d == nil {
				_ = startDetached("sync", "--quiet", "--scheduled", "--base", c.base)
			}
		} else if time.Since(s.CheckedAt) > staleAfter {
			_ = startDetached("sync", "--quiet", "--scheduled", "--base", c.base)
		}
	}
	state := advise.Load(st.Dir)
	paths := quotaPaths(st)
	if !c.offline {
		refreshNativeLater(st)
	}
	if harness == "claude-code" {
		paths.CodexHome = "" // Codex advice belongs to Codex; skip scanning its logs on every prompt
		if in.SessionID != "" {
			paths.ClaudeSession = in.SessionID
		}
		if !c.offline {
			refreshCodexBarLater(st, now)
		}
	} else {
		if in.SessionID != "" {
			paths.CodexThread = in.SessionID
		}
		if !c.offline {
			refreshAccountLater(st) // the prompt uses the cached reading; the next one gets a fresher one
		}
	}
	var es []advise.Event
	report := quota.ReadPermitted(paths, now)
	observeQuotaHistory(st, report, now)
	if harness == "claude-code" {
		if consent.Allowed("claude", consent.Local) {
			_ = consent.LocalWrite("claude", func() error {
				return speed.ObserveClaude(st.Dir, in.TranscriptPath, false, speed.Ingest{Labels: projectLabels(), Subscription: quota.ClaudeSubscription(st.Dir)}, now)
			})
		}
	} else {
		observeCodexSpeed(st, now)
		observeAgents(st, now)
	}
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
	es = claimPaceWarnings(st.Dir, es, now)
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
		acct := threadAccount(report, harness, in.Model)
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
		for _, fact := range state.QuotaNotices(in.SessionID, acct, now) {
			if fact.Kind == "low" {
				fact.Down, fact.Cheaper = advise.NoticeSteps(acct, report, d, now)
			}
			parts = append(parts, style.QuotaNotice(fact))
		}
	}
	// Personal default-effort suggestions stay in text history and the status
	// line. Hooks must neither expose them to plugins nor consume their notice.
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
	saveAdviceStateUntil(state, st.Dir, now, deadline)
	return 0
}

// threadAccount is the prompting thread's account with only that thread's model and effort.
// Without a reading yet (a first thread, an API-key login, no status line) the quota and the
// current model are unknown.
func threadAccount(report quota.Report, harness, model string) *quota.Account {
	acct := &quota.Account{Source: harness, Headroom: "unknown"}
	for i := range report.Accounts {
		if report.Accounts[i].Source == harness {
			acct = &report.Accounts[i]
		}
	}
	switch {
	case model != "" && (acct.Harness == nil || acct.Harness.Model != model):
		// The hook names the thread's model (Codex); its effort is known only from that thread's log.
		x := *acct
		x.Harness = &quota.Harness{Model: model}
		acct = &x
	case harness == "claude-code" && acct.Harness != nil && acct.Harness.Attribution != "current-thread":
		// The status line's model and effort are another session's (or of unknown session).
		x := *acct
		x.Harness = nil
		acct = &x
	}
	return acct
}

// sessionStartHook: after Claude Code or Codex compacted or resumed a thread, the model gets
// back the low or run-out quota notice that thread was sent, when it still holds. Nothing else
// is sent, refreshed or marked; the next prompt carries on as usual.
func sessionStartHook(stdout io.Writer, style render.Style, st *store.Store, harness, session, model, source string, now time.Time) int {
	if session == "" || (source != "compact" && source != "resume") || os.Getenv("MODELPLAN_TASK_BRIEF") == "off" {
		return 0
	}
	paths := quotaPaths(st)
	if harness == "claude-code" {
		paths.CodexHome, paths.ClaudeSession = "", session
	} else {
		paths.CodexThread = session
	}
	report := quota.ReadPermitted(paths, now)
	if harness == "claude-code" {
		model = "" // as on a prompt: the status line's reading for this session, not the start's default
	}
	acct := threadAccount(report, harness, model)
	n := advise.Load(st.Dir).QuotaResend(session, acct, now)
	if n == nil {
		return 0
	}
	d, _, _ := publication.Load(st)
	n.Down, n.Cheaper = advise.NoticeSteps(acct, report, d, now)
	b, _ := json.Marshal(map[string]any{"hookSpecificOutput": map[string]any{"hookEventName": "SessionStart", "additionalContext": style.QuotaNotice(*n)}})
	fmt.Fprintln(stdout, string(b))
	return 0
}

// refreshAccountLater asks Codex for the account reading (and CodexBar for the enabled
// providers) in the background when the cached one is due, so hooks and the plugin never wait.
func refreshAccountLater(st *store.Store) {
	now := time.Now()
	if consent.Allowed("codex", consent.Runtime) && quota.AccountDue(st.Dir, now) {
		_ = startDetached("quota", "--refresh-account", "--quiet")
	}
	refreshCodexBarLater(st, now)
}

// refreshCodexBarLater runs CodexBar in the background for the enabled providers when the cached
// reading is due (both hooks, quota and advise), so nothing waits for it.
func refreshCodexBarLater(st *store.Store, now time.Time) {
	p := quotaPaths(st)
	if len(quota.CodexBarActive(p)) == 0 {
		return
	}
	switch {
	case quota.CodexBarFetchDue(st.Dir, now):
		_ = startDetached("codexbar", "fetch", "--quiet") // refreshes once fetched
	case quota.CodexBarDue(p, now):
		_ = startDetached("codexbar", "refresh", "--quiet")
	}
}

func claimPaceWarnings(cache string, events []advise.Event, now time.Time) []advise.Event {
	out := make([]advise.Event, 0, len(events))
	for _, event := range events {
		if event.Type == advise.WindowPace && (event.At == nil || !history.ClaimPaceWarning(cache, event.Key, *event.At, now)) {
			continue
		}
		out = append(out, event)
	}
	return out
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

// desktopCmd prints the personal snapshot (docs/personal-snapshot.md) for the desktop app: one
// call gives it the sessions, quota, advice and measured speed. Like the hooks it refreshes the
// Codex account reading, native readers, CodexBar and a stale publication in the background, records the quota
// history and Codex speed, and arms switch-back; it marks nothing as told, which the app does
// for its own notifications.
func desktopCmd(stdout io.Writer, st *store.Store, c common, readOnly bool) int {
	now := time.Now()
	d, ps, _ := publication.Load(st)
	if !c.offline && !readOnly {
		refreshAccountLater(st)
		refreshNativeLater(st)
		if (d == nil || time.Since(ps.CheckedAt) > staleAfter) && time.Since(ps.LastAttemptAt) > backgroundEvery {
			_ = startDetached("sync", "--quiet", "--scheduled", "--base", c.base)
		}
	}
	result := consent.BuildStable(func(admission consent.Admission) snapshot.Snapshot {
		paths := quota.ProductionPathsWithAdmission(st.Dir, version, admission)
		report := quota.ReadPermitted(paths, now)
		if !readOnly {
			observeQuotaHistory(st, report, now)
			observeCodexSpeed(st, now)
			observeAgents(st, now)
			observeLiveSessions(st, paths, report, now)
		}
		state := advise.Load(st.Dir)
		es := advise.Derive(advise.Input{Report: report, Digest: d, State: state, Now: now})
		if !readOnly {
			saveAdviceState(state, st.Dir, now)
		}
		ledger := speed.Load(st.Dir)
		perf, ok := speed.LoadPerf(st.Dir)
		long, longOK := speed.LoadLong(st.Dir)
		pace, paceOK := history.LoadPace(st.Dir)
		home, _ := os.UserHomeDir()
		localUsageFor := func(tool string) localusage.Report {
			status, read := localusage.GeminiStatus, localusage.ReadGemini
			if tool == "qwen" {
				status, read = localusage.QwenStatus, localusage.ReadQwen
			}
			if admission.Allows(tool, consent.Local) {
				return read(home, now)
			}
			r := status(home, now)
			r.Status, r.Enabled, r.Reason = "off", false, "reader-consent-or-privacy"
			return r
		}
		localUsage := localUsageFor("gemini")
		qwenLocal := localUsageFor("qwen")
		var qwenExport *qwenusage.Report
		if path := qwenusage.Configured(); path != "" && admission.Allows("qwen", consent.Local) {
			r := qwenusage.Read(path, now)
			qwenExport = &r
		}
		connectionEnv := connections.Local(paths)
		connectionEnv.Gemini = &localUsage
		connectionEnv.Qwen = &qwenLocal
		// This machine-readable feed is also consumed by plugins. Keep personal
		// default-effort suggestions out, even when explicitly enabled locally.
		boundaries := advise.Boundaries(advise.Input{Report: report, Digest: d, State: state, Now: now})
		return snapshot.Build(snapshot.Input{LocalHistory: localusage.ProductionHistoriesWithAdmission(home, st.Dir, true, now, admission), LocalUsage: []localusage.Report{localUsage, qwenLocal}, Report: report, Digest: d, State: ps, Events: es,
			Measured: speed.Summarize(ledger, now), Ledger: ledger.Rows, Perf: &speed.PerfView{Ledger: perf, OK: ok, Long: long, LongOK: longOK, Recording: !history.Off(), Now: now},
			QwenUsage:   qwenExport,
			Connections: connections.DiagnoseWithAdmission(connectionEnv, report, admission),
			Pace:        &history.PaceView{Ledger: pace, OK: paceOK, Recording: !history.Off(), Now: now}, Boundaries: boundaries,
			Recording: !history.Off(), ProjectLabels: projectLabels(), CLIVersion: version, Now: now})
	}, func(admission consent.Admission) snapshot.Snapshot {
		// A second change publishes only the user's own declarations. No tool
		// account, connection, history, session or advice survives a discarded build.
		home, _ := os.UserHomeDir()
		report := quota.ReadDeclared(quota.Paths{LocalFile: filepath.Join(home, ".config", "modelplan", "local.json")}, now)
		report.ConsentGeneration = admission.Generation()
		report.ConsentStoreEpoch = admission.Fence().StoreEpoch
		report.Sources = append(report.Sources, quota.SourceStatus{Source: "readers", Status: "off", Reason: "consent-changed"})
		return snapshot.Build(snapshot.Input{Report: report, Digest: d, State: ps, CLIVersion: version, Now: now})
	})
	return printJSON(stdout, result)
}

// observeLiveSessions never queries accounts; it only reuses local bindings already read above.
func observeLiveSessions(st *store.Store, paths quota.Paths, report quota.Report, now time.Time) {
	if speed.Off() || !consent.Allowed("claude", consent.Local) || !consent.Allowed("codex", consent.Local) {
		return
	}
	home, _ := os.UserHomeDir()
	claude := os.Getenv("CLAUDE_CONFIG_DIR")
	if claude == "" {
		claude = filepath.Join(home, ".claude")
	}
	refs := map[string]string{}
	for _, a := range report.Accounts {
		if a.Subscription != nil {
			refs[a.Source] = a.Subscription.Ref
		}
	}
	reportWrite(report, func() error {
		return speed.ObserveLive(st.Dir, speed.ActiveLogs(claude, paths.CodexHome, now), projectLabels(), refs, now)
	})
}

// observeCodexSpeed measures what is new in the most recent Codex threads, skipping the ones Codex
// runs by itself.
func observeCodexSpeed(st *store.Store, now time.Time) {
	if !consent.Allowed("codex", consent.Local) {
		return
	}
	_ = consent.LocalWrite("codex", func() error {
		home := quotaPaths(st).CodexHome
		return speed.ObserveCodex(st.Dir, quota.RecentRollouts(home, 8), func(p string) bool { return quota.Background(quota.ThreadOrigin(p), "") },
			speed.Ingest{Labels: projectLabels(), Subscription: quota.CodexSubscription(st.Dir, now)}, now)
	})
}

// projectLabelsCmd shows or sets the project-label switch: on unless the user turned it off (the
// desktop offers it in its settings).
func projectLabelsCmd(args []string, stdout, stderr io.Writer, st *store.Store, c common) int {
	home, _ := os.UserHomeDir()
	file := speed.ProjectLabelsFile(home)
	sub := "status"
	if len(args) > 0 {
		sub = args[0]
	}
	switch sub {
	case "on", "off":
		if err := speed.SetProjectLabels(file, st.Dir, sub == "on"); err != nil {
			fmt.Fprintln(stderr, err)
			return exitErr
		}
	case "status":
	default:
		fmt.Fprintln(stderr, "usage: modelplan project-labels [status|on|off]")
		return exitUsage
	}
	on := speed.ProjectLabels(file)
	if c.json {
		return printJSON(stdout, map[string]any{"projectLabels": on, "file": file})
	}
	switch {
	case on && c.lang == "en":
		fmt.Fprintln(stdout, "Project labels are on: the project ranking names projects by their folder. The names stay on this machine; `modelplan project-labels off` deletes them.")
	case on:
		fmt.Fprintln(stdout, "项目名称已开启：项目排行按文件夹名称显示。名称只留在本机；`modelplan project-labels off` 会删除已记下的名称。")
	case c.lang == "en":
		fmt.Fprintln(stdout, "Project labels are off: projects are kept only as opaque references.")
	default:
		fmt.Fprintln(stdout, "项目名称已关闭：项目只以不透明的引用记录。")
	}
	return 0
}

// observeAgents measures what is new in the other agents' databases (ZCode, OpenCode V2); each
// is read at most every 30 seconds and only when it changed.
func observeAgents(st *store.Store, now time.Time) {
	home, _ := os.UserHomeDir()
	in := speed.Ingest{Labels: projectLabels()}
	if consent.Allowed("zai", consent.Local) {
		_ = consent.LocalWrite("zai", func() error { return speed.ObserveZCode(st.Dir, home, in, now) })
	}
	if consent.Allowed("opencodego", consent.Local) {
		_ = consent.LocalWrite("opencodego", func() error { return speed.ObserveOpenCode(st.Dir, home, in, now) })
	}
}

// projectLabels: project labels are on, unless the user turned them off (`modelplan project-labels off`).
func projectLabels() bool {
	home, _ := os.UserHomeDir()
	return speed.ProjectLabels(speed.ProjectLabelsFile(home))
}

func nonNilCycles(cs []history.Cycle) []history.Cycle {
	if cs == nil {
		return []history.Cycle{}
	}
	return cs
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
	return quota.ProductionPaths(st.Dir, version)
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

var takesValue = map[string]bool{"provider": true, "plan": true, "profile": true, "privacy": true, "effort-suggestion": true, "export": true, "backend": true, "region": true, "key-env": true, "lang": true, "base": true, "dev": true, "harness": true, "model": true, "effort": true, "source": true, "hook": true, "add-system": true, "add-context": true}

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
