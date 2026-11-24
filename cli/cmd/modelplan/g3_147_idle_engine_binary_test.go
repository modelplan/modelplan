// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/idlework"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// collect reads server frames for d and returns the notifications among them.
func (p *queryBinary) collect(d time.Duration) []string {
	p.t.Helper()
	var methods []string
	deadline := time.After(d)
	for {
		select {
		case raw, ok := <-p.frames:
			if !ok {
				p.t.Fatal("app-server stdout closed")
			}
			var msg struct {
				Method string `json:"method"`
			}
			if json.Unmarshal(raw, &msg) == nil && msg.Method != "" {
				methods = append(methods, msg.Method)
			}
		case <-deadline:
			return methods
		}
	}
}

// G3-147 (WP-17), through the real app-server: an idle engine with unchanged inputs does no
// repeated parsing and publishes nothing. On the owner's Mac the engine held 150-215% CPU:
// each snapshot's identity reads created and removed a lock file in the observed directory the
// engine watches, so every snapshot started the next, and the reader sources came out in map
// order, so every snapshot was published as a change.
func TestG3147IdleAppServerPublishesNothing(t *testing.T) {
	if testing.Short() {
		t.Skip("starts the real app-server for about 25 s")
	}
	// One time zone, and an idle window clear of midnight: the day rollover is a scheduled
	// republication (Today totals start over), not an idle one.
	t.Setenv("TZ", "UTC")
	home := setupQueryHome(t)
	now := time.Now().UTC()
	// A Claude Code log whose responses predate the recording start, and a Codex rollout.
	claude := filepath.Join(home, ".claude", "projects", "-synthetic", "session.jsonl")
	codex := filepath.Join(home, ".codex", "sessions", now.Format("2006"), now.Format("01"), now.Format("02"), "rollout-g3147.jsonl")
	var c, x strings.Builder
	for i := 0; i < 200; i++ {
		at := now.Add(-72*time.Hour + time.Duration(i)*time.Second).Format(time.RFC3339Nano)
		fmt.Fprintf(&c, `{"type":"assistant","timestamp":%q,"sessionId":"synthetic","requestId":"req-%d","message":{"id":"msg_%d","model":"claude-sonnet-4-5-20250929","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_read_input_tokens":900,"output_tokens":10}}}`+"\n", at, i, i)
		at = now.Add(-2*time.Hour + time.Duration(i)*time.Second).Format(time.RFC3339Nano)
		fmt.Fprintf(&x, `{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"output_tokens":10},"total_token_usage":{"input_tokens":%d,"output_tokens":%d}}}}`+"\n", at, 100*(i+1), 10*(i+1))
	}
	for path, body := range map[string]string{claude: c.String(), codex: x.String()} {
		if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
		old := now.Add(-time.Hour)
		if err := os.Chtimes(path, old, old); err != nil {
			t.Fatal(err)
		}
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		for _, tool := range []string{"codex", "claude"} {
			if err := consent.Set(s, tool, true, "native:"+tool, "native", now.Add(-30*24*time.Hour)); err != nil {
				return err
			}
		}
		s.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		s.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, raw)
	}
	p := startQueryBinaryFor(t, 60*time.Second, binary, []string{"rows"})
	p.call("rows/subscribe", map[string]any{})

	// Settle: the first reads and the first observation (2.5 s after start) may publish.
	started := time.Now()
	for quiet := 0; quiet < 3; {
		if time.Since(started) > 20*time.Second {
			t.Fatal("the app-server never went quiet after start")
		}
		if n := len(p.collect(time.Second)); n == 0 && time.Since(started) > 5*time.Second {
			quiet++
		} else if n != 0 {
			quiet = 0
		}
	}
	if untilMidnight := time.Until(time.Now().UTC().Truncate(24 * time.Hour).Add(24 * time.Hour)); untilMidnight < 10*time.Second {
		p.collect(untilMidnight + 3*time.Second) // let the rollover's publication pass
	}
	observed := filepath.Join(home, "cache", "observed")
	before, err := os.Stat(observed)
	if err != nil {
		t.Fatal(err)
	}
	// 30 polls of the change watcher (200 ms) with nothing new: nothing may be published and the
	// engine's own reads must not change what it watches.
	if got := p.collect(6 * time.Second); len(got) != 0 {
		t.Fatalf("idle app-server published %d notifications: %v", len(got), got)
	}
	after, err := os.Stat(observed)
	if err != nil {
		t.Fatal(err)
	}
	if !after.ModTime().Equal(before.ModTime()) {
		t.Fatal("idle reads changed the observed directory the engine watches")
	}
}

// idleWork is what one run of the production idle loops cost over the measured window.
type idleWork struct {
	measured     bool // the run reached the end of its measured window
	window       idlework.Counts
	hotEntries   int64           // entries enumerated by steps that started no discovery walk
	loops        idlework.Counts // work of the watcher and activity steps outside observation passes
	observations int
	treeEntries  int64 // directory entries in the synthetic history: the most one walk can list
	windowTime   time.Duration
	discovered   time.Duration // positive control: delay from insertion until the rollout was signalled
	watched      bool          // the signal carried the new rollout itself
}

// idleGap is a check of the idle-work gate that main does not pass yet. While it is open, its
// metric still has a ceiling: the work measured today, per observation or per walk, so the
// gate fails when the gap gets worse. Its plan item removes it.
type idleGap struct {
	why string
	// allowance returns the run's measured value of the metric and the most it may reach.
	allowance func(run idleWork) (got, ceiling int64)
}

// idleGaps lists the open gaps. A listed check that passes fails the gate, so the fix that
// closes a gap must delete its entry here; an unlisted check that fails is a regression, and a
// listed one that exceeds its allowance is one too.
var idleGaps = map[string]idleGap{
	"entries": {
		why: "energy plan item 2: the activity observer and the Codex rollout index walk every admitted history root each 6 s, and each 30 s observation walks them again, so enumeration grows with history",
		// Each walk lists its root at most once; walks themselves are budgeted separately.
		allowance: func(r idleWork) (int64, int64) { return r.window.Entries, r.window.Walks * r.treeEntries },
	},
	"views": {
		why: "energy plan item 2: each 30 s observation signals a change even when it wrote nothing, and its observe-decisions.json rewrite moves the watched observed directory, so the server builds two views per pass",
		// Two change-driven refreshes per observation, one view build each.
		allowance: func(r idleWork) (int64, int64) { return r.window.Views, 2 * int64(r.observations) },
	},
	"decodes": {
		why: "energy plan item 2: each 30 s observation re-reads the unchanged ledgers and the views it triggers decode them again",
		allowance: func(r idleWork) (int64, int64) {
			return r.window.Decodes, idleDecodesPerObservation * int64(r.observations)
		},
	},
}

// idleDecodesPerObservation is what one idle observation and the two refreshes it triggers
// decode today (its ledgers, then the views' ledgers and rollouts).
const idleDecodesPerObservation = 5

// idleDiscoveryDeadline is the agreed pickup time for a new Codex rollout (D397): one 6 s
// discovery interval plus the watcher's one-second metadata cadence. It is fixed here, not read
// from the implementation, so a slower discovery fails the gate.
const idleDiscoveryDeadline = 6*time.Second + time.Second

// D397 (energy plan item 5, energy-p0-1124). TestG3147IdleAppServerPublishesNothing watches the
// wire only; an engine can stay quiet there while it walks, opens and decodes history on every
// tick. This gate drives the production watcher, activity observer, observation pass and
// change-driven server refresh under a test clock on a large synthetic static home, at two tree
// sizes, and counts the work itself: entries enumerated, content opens and bytes, decodes and
// view builds. With nothing changing, each count must be zero or bounded independently of the
// tree size.
func TestG3147IdleWorkIsFlatOnLargeStaticHome(t *testing.T) { idleWorkGate(t, time.Now()) }

// macrev2-1219-2: the gate's window comes from its own start time, not the wall clock, so a run
// a few minutes before midnight UTC still measures (and still fails on a regression).
func TestG3147IdleWorkGateRunsNearMidnight(t *testing.T) {
	wall := time.Now().UTC().Truncate(24 * time.Hour).Add(-5 * time.Minute) // yesterday 23:55
	if start := idleWindowStart(wall); !clearOfMidnight(start) {
		t.Fatalf("window start %s for wall clock %s is not clear of midnight", start, wall)
	}
	for _, wall := range []time.Time{wall, wall.Add(4*time.Minute + 59*time.Second), wall.Add(5 * time.Minute), wall.Add(-12 * time.Hour)} {
		if start := idleWindowStart(wall); !clearOfMidnight(start) || start.After(wall) {
			t.Errorf("window start %s for wall clock %s: not clear of midnight or in the future", start, wall)
		}
	}
	idleWorkGate(t, wall)
}

// idleWindow is how much test-clock time one run spans (warm-up, measurement, positive control).
const idleWindow = 6 * time.Minute

func clearOfMidnight(start time.Time) bool {
	start = start.UTC()
	return start.Truncate(24*time.Hour).Add(24*time.Hour).Sub(start) > idleWindow
}

// idleWindowStart is the gate's test-clock start for a run at wall: the wall clock itself, or an
// hour earlier when the run would cross midnight UTC (a scheduled republication, not idle work).
func idleWindowStart(wall time.Time) time.Time {
	start := wall.UTC()
	if !clearOfMidnight(start) {
		start = start.Add(-time.Hour)
	}
	return start
}

func idleWorkGate(t *testing.T, wall time.Time) {
	start := idleWindowStart(wall)
	var small, large idleWork
	t.Run("small", func(t *testing.T) { small = runIdleWork(t, 1, start) })
	t.Run("large", func(t *testing.T) { large = runIdleWork(t, 10, start) })
	if t.Failed() {
		return
	}
	// A child that skipped or stopped early leaves zero values, which would read as closed gaps.
	for name, run := range map[string]idleWork{"small": small, "large": large} {
		if !run.measured || run.observations == 0 || run.window.Walks == 0 || run.treeEntries == 0 {
			t.Fatalf("%s: the run produced no measurement (%+v); the gate cannot pass without one", name, run)
		}
	}
	t.Logf("small: %+v hotEntries=%d observations=%d tree=%d discovered=%s", small.window, small.hotEntries, small.observations, small.treeEntries, small.discovered)
	t.Logf("large: %+v hotEntries=%d observations=%d tree=%d discovered=%s", large.window, large.hotEntries, large.observations, large.treeEntries, large.discovered)

	check := func(name string, ok bool, format string, args ...any) {
		t.Helper()
		msg := fmt.Sprintf(format, args...)
		gap, known := idleGaps[name]
		if !known {
			if !ok {
				t.Errorf("%s: %s", name, msg)
			}
			return
		}
		if ok {
			t.Errorf("idle gap %q is closed; delete its idleGaps entry (%s)", name, gap.why)
			return
		}
		t.Logf("known idle gap %q: %s (%s)", name, msg, gap.why)
		for size, run := range map[string]idleWork{"small": small, "large": large} {
			if got, ceiling := gap.allowance(run); got > ceiling {
				t.Errorf("%s: known idle gap %q got worse: %d against its allowance of %d", size, name, got, ceiling)
			}
		}
	}
	w, l := small.window, large.window
	// The 200 ms watcher and the two-second activity observer only stat files on a static home.
	for name, run := range map[string]idleWork{"small": small, "large": large} {
		if c := run.loops; c.Opens != 0 || c.Bytes != 0 || c.Decodes != 0 || c.Views != 0 {
			t.Errorf("%s: the watcher and activity loops did content work on unchanged input: %+v", name, c)
		}
	}
	// Between discovery walks, the 200 ms watcher and two-second observer only stat known files.
	check("hot-entries", small.hotEntries == 0 && large.hotEntries == 0,
		"steps without a discovery walk enumerated %d (small) and %d (large) entries", small.hotEntries, large.hotEntries)
	// Discovery is paced by time, not by history: the same number of walks at both sizes, at
	// most one per root per discovery interval and per observation pass.
	intervals := int64(large.windowTime/speed.ActivityDiscoveryInterval) + 1
	walkBudget := 3*intervals + 4*int64(large.observations)
	check("walks", w.Walks == l.Walks && l.Walks <= walkBudget,
		"%d (small) and %d (large) discovery walks in %s, budget %d", w.Walks, l.Walks, large.windowTime, walkBudget)
	// Ten times the history must not enumerate ten times the entries.
	check("entries", l.Entries <= w.Entries+w.Entries/2,
		"a 10x larger static tree enumerated %d entries against %d", l.Entries, w.Entries)
	check("opens", l.Opens == w.Opens, "%d (large) against %d (small) content opens", l.Opens, w.Opens)
	check("bytes", l.Bytes <= w.Bytes+w.Bytes/10, "%d (large) against %d (small) content bytes", l.Bytes, w.Bytes)
	check("decodes-bounded", l.Decodes == w.Decodes, "%d (large) against %d (small) decodes", l.Decodes, w.Decodes)
	check("decodes", w.Decodes == 0 && l.Decodes == 0, "%d (small) and %d (large) decodes of unchanged content", w.Decodes, l.Decodes)
	check("views", w.Views == 0 && l.Views == 0, "%d (small) and %d (large) view builds with nothing changed", w.Views, l.Views)
	// The positive control: the gate cannot pass by no longer looking. The rollout goes in right
	// after a discovery pass, the worst case, and must be signalled by the agreed deadline.
	for name, run := range map[string]idleWork{"small": small, "large": large} {
		if run.discovered <= 0 || run.discovered > idleDiscoveryDeadline || !run.watched {
			t.Errorf("%s: a new Codex rollout inserted right after a discovery pass was not signalled within %s (took %s, watched %v)",
				name, idleDiscoveryDeadline, run.discovered, run.watched)
		}
	}
}

// runIdleWork builds the production app-server on a synthetic static home of the given scale,
// steps its idle loops under a test clock from start and returns the work done after warm-up.
func runIdleWork(t *testing.T, scale int, start time.Time) idleWork {
	t.Setenv("TZ", "UTC")
	home := setupQueryHome(t)
	writeStaticHistory(t, home, start, scale)
	var run idleWork
	for _, root := range []string{filepath.Join(home, ".claude"), filepath.Join(home, ".codex")} {
		_ = filepath.WalkDir(root, func(string, fs.DirEntry, error) error { run.treeEntries++; return nil })
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		for _, tool := range []string{"codex", "claude"} {
			if err := consent.Set(s, tool, true, "native:"+tool, "native", start.Add(-30*24*time.Hour)); err != nil {
				return err
			}
		}
		s.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		s.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}

	at := start
	clock := func() time.Time { return at }
	var shared *appserver.SharedBackend
	var scheduler *appserver.RefreshScheduler
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	server, closeBackend, err := newAppServerWithSources(ctx, appServerOptions{}, appServerSources{Clock: clock,
		Built: func(b *appserver.SharedBackend, s *appserver.RefreshScheduler) { shared, scheduler = b, s }})
	if err != nil || server == nil || shared == nil || scheduler == nil {
		t.Fatalf("app-server: %v", err)
	}
	defer closeBackend()
	steps := shared.IdleSteps()

	// The production cadences: watcher 200 ms, activity 2 s, observation 2.5 s after start and
	// then every 30 s. A signalled change costs the refresh the server runs for it: the view
	// token capture and the view build (macrev2-1219-5), through the server's own entry.
	const tick = 200 * time.Millisecond
	observeAt := start.Add(appserver.ObserveFirstDelay)
	afterObserve := false
	step := func() {
		before, observed := idlework.Snapshot(), false
		steps.Watch(at)
		if at.Sub(start)%(2*time.Second) == 0 {
			steps.Activity(ctx, at)
		}
		if !at.Before(observeAt) {
			scheduler.ObserveOnce(at)
			observeAt = at.Add(30 * time.Second)
			run.observations++
			observed = true
		}
		if steps.Pending() {
			if err := server.RefreshAfterChange(ctx); err != nil {
				t.Fatalf("change-driven refresh: %v", err)
			}
		}
		done := idlework.Snapshot().Since(before)
		if done.Walks == 0 {
			run.hotEntries += done.Entries
		}
		// The poll after an observation sees its diagnostics write; both belong to the pass.
		if !observed && !afterObserve {
			run.loops = run.loops.Plus(done)
		}
		afterObserve = observed
		at = at.Add(tick)
	}
	// Warm up through the first two observations, then measure five observation deadlines and
	// about thirty discovery intervals.
	for at.Before(start.Add(40 * time.Second)) {
		step()
	}
	run.hotEntries, run.observations, run.loops = 0, 0, idlework.Counts{}
	base, measured := idlework.Snapshot(), at
	for at.Before(measured.Add(180 * time.Second)) {
		step()
	}
	run.window = idlework.Snapshot().Since(base)
	run.windowTime = at.Sub(measured)

	// Positive control (macrev2-1219-4): a new rollout today must still be noticed by the agreed
	// deadline. Wait for a watcher poll that ran a discovery walk, then insert at once, so the
	// rollout waits a whole discovery interval: a slower cadence cannot hide behind a lucky timer.
	steps.Pending()
	for from := at; ; {
		if at.Sub(from) > time.Minute {
			t.Fatal("the change watcher ran no discovery walk in a minute")
		}
		before := idlework.Snapshot()
		steps.Watch(at)
		at = at.Add(tick)
		if idlework.Snapshot().Since(before).Walks > 0 {
			break
		}
	}
	steps.Pending()
	inserted := at
	day := filepath.Join(home, ".codex", "sessions", inserted.Format("2006"), inserted.Format("01"), inserted.Format("02"))
	rollout := filepath.Join(day, "rollout-"+inserted.Format("2006-01-02T15-04-05")+"-g3147new.jsonl")
	if err := os.MkdirAll(day, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(rollout, []byte(`{"type":"session_meta","payload":{}}`+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(rollout, inserted, inserted); err != nil {
		t.Fatal(err)
	}
	for at.Before(inserted.Add(30 * time.Second)) {
		steps.Watch(at)
		if steps.Pending() {
			run.discovered, run.watched = at.Sub(inserted), steps.Watching(rollout)
			break
		}
		at = at.Add(tick)
	}
	run.measured = true
	return run
}

// writeStaticHistory lays out an owner-shaped history that nothing writes to any more: Claude
// projects with sessions and subagents, and Codex rollouts over many days, all well outside
// the live window. Scale multiplies the tree; each file stays small.
func writeStaticHistory(t *testing.T, home string, now time.Time, scale int) {
	t.Helper()
	write := func(path, body string, at time.Time) {
		if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(path, at, at); err != nil {
			t.Fatal(err)
		}
	}
	for p := 0; p < 20*scale; p++ {
		for s := 0; s < 8; s++ {
			at := now.Add(-time.Duration(2+p%40) * 24 * time.Hour)
			line := fmt.Sprintf(`{"type":"assistant","timestamp":%q,"sessionId":"s%d-%d","requestId":"r%d","message":{"id":"m%d-%d","model":"claude-sonnet-4-5-20250929","role":"assistant","content":[],"usage":{"input_tokens":10,"output_tokens":1}}}`+"\n",
				at.Format(time.RFC3339Nano), p, s, s, p, s)
			dir := filepath.Join(home, ".claude", "projects", fmt.Sprintf("-synthetic-%d", p))
			write(filepath.Join(dir, fmt.Sprintf("session-%d.jsonl", s)), line, at)
			if s == 0 {
				write(filepath.Join(dir, fmt.Sprintf("session-%d", s), "subagents", "agent-1.jsonl"), line, at)
			}
		}
	}
	for d := 0; d < 30*scale; d++ {
		at := now.Add(-time.Duration(2+d) * 24 * time.Hour)
		dir := filepath.Join(home, ".codex", "sessions", at.Format("2006"), at.Format("01"), at.Format("02"))
		for r := 0; r < 5; r++ {
			line := fmt.Sprintf(`{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,"output_tokens":1},"total_token_usage":{"input_tokens":10,"output_tokens":1}}}}`+"\n", at.Format(time.RFC3339Nano))
			write(filepath.Join(dir, fmt.Sprintf("rollout-%s-%d.jsonl", at.Format("2006-01-02T15-04-05"), r)), line, at.Add(time.Duration(r)*time.Minute))
		}
	}
}
