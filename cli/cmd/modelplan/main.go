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
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/detach"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/publication"
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
  modelplan effort <model>             one model's effort ladder relative to ★
  modelplan models [--dev openai]      models with ★ effort, ability and cost
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

	case "statusline":
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
		if fs.NArg() < 1 {
			fmt.Fprintln(stderr, "usage: modelplan effort <model id or name>")
			return exitUsage
		}
		q := strings.Join(fs.Args(), " ")
		m := d.Model(q)
		if m == nil {
			m = d.Match(*harness, q)
		}
		if m == nil {
			fmt.Fprintf(stderr, "%s: %s\n", style.T.NotListed, q)
			return exitErr
		}
		if c.json {
			return printJSON(stdout, m)
		}
		style.Effort(stdout, m)
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
func statusline(stdin io.Reader, stdout io.Writer, style render.Style, st *store.Store, c common, harness, modelID, effort string) int {
	var in struct {
		Model struct {
			ID          string `json:"id"`
			DisplayName string `json:"display_name"`
		} `json:"model"`
	}
	if f, ok := stdin.(*os.File); !ok || !isTTY(f) {
		b, _ := io.ReadAll(io.LimitReader(stdin, 1<<16))
		_ = json.Unmarshal(b, &in)
	}
	if modelID == "" {
		modelID = in.Model.ID
	}
	s, _ := st.State()
	if !c.offline && time.Since(s.CheckedAt) > staleAfter && time.Since(s.LastAttemptAt) > backgroundEvery {
		_ = detach.Start("sync", "--quiet", "--base", c.base)
	}
	d, s, err := publication.Load(st)
	if err != nil {
		fmt.Fprintln(stdout, style.Statusline(nil, nil, "", false, "")+" · "+style.T.Syncing)
		return 0
	}
	m := d.Match(harness, modelID, in.Model.DisplayName)
	raw := in.Model.DisplayName
	if raw == "" {
		raw = modelID
	}
	fmt.Fprintln(stdout, style.Statusline(d, m, effort, time.Since(s.CheckedAt) > alarmAfter, raw))
	return 0
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

var takesValue = map[string]bool{"lang": true, "base": true, "dev": true, "harness": true, "model": true, "effort": true}

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
