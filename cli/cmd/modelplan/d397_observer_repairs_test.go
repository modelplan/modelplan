// SPDX-License-Identifier: MIT
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/idlework"
	"github.com/modelplan/modelplan/cli/internal/logindex"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

type observerHome struct {
	t                   *testing.T
	home, claude, codex string
	st                  *store.Store
}

// newObserverHome: Claude Code and Codex local history allowed, ModelPlan's cache isolated.
func newObserverHome(t *testing.T) *observerHome {
	t.Helper()
	testenv.IsolateHome(t)
	h := &observerHome{t: t, home: os.Getenv("HOME")}
	h.claude, h.codex = filepath.Join(h.home, "claude"), filepath.Join(h.home, "codex")
	t.Setenv("MODELPLAN_CACHE", filepath.Join(h.home, "cache"))
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_IDENTITY", "")
	t.Setenv("CLAUDE_CONFIG_DIR", h.claude)
	t.Setenv("CODEX_HOME", h.codex)
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		for _, tool := range []string{"codex", "claude"} {
			if err := consent.Set(s, tool, true, "native:"+tool, "native", time.Now().Add(-24*time.Hour)); err != nil {
				return err
			}
		}
		s.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		s.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	h.st = st
	return h
}

func (h *observerHome) write(path, body string, at time.Time) {
	h.t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		h.t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		h.t.Fatal(err)
	}
	if err := os.Chtimes(path, at, at); err != nil {
		h.t.Fatal(err)
	}
}

// accountCaches writes ModelPlan's own Codex account and Claude Code snapshot caches.
func (h *observerHome) accountCaches(codexRef, claudeRef string, at time.Time) {
	h.t.Helper()
	observed := filepath.Join(h.st.Dir, "observed")
	h.write(filepath.Join(observed, "codex-account.json"), fmt.Sprintf(`{"schemaVersion":1,"observedAt":%q,"status":"ok","subscriptionRef":%q}`+"\n", at.UTC().Format(time.RFC3339Nano), codexRef), at)
	h.write(filepath.Join(observed, "claude-code.json"), fmt.Sprintf(`{"schemaVersion":1,"source":"claude-code","observedAt":%q,"identity":{"subscriptionRef":%q}}`+"\n", at.UTC().Format(time.RFC3339Nano), claudeRef), at)
}

// rollout writes a Codex session with a model, a turn and token counts, last written at.
func (h *observerHome) rollout(day string, at time.Time) string {
	line := func(t time.Time, kind, payload string) string {
		return fmt.Sprintf(`{"timestamp":%q,"type":%q,"payload":%s}`+"\n", t.UTC().Format(time.RFC3339Nano), kind, payload)
	}
	path := filepath.Join(h.codex, "sessions", day, "rollout-2026-11-24T10-00-00-synthetic.jsonl")
	h.write(path, line(at.Add(-40*time.Second), "session_meta", `{"id":"SYNTHETIC","source":"cli"}`)+
		line(at.Add(-30*time.Second), "event_msg", `{"type":"task_started"}`)+
		line(at.Add(-20*time.Second), "turn_context", `{"model":"gpt-6.1-sol","effort":"high"}`)+
		line(at.Add(-10*time.Second), "event_msg", `{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"output_tokens":10},"total_token_usage":{"input_tokens":100,"output_tokens":10}}}`), at)
	return path
}

func (h *observerHome) claudeLog(project string, at time.Time) string {
	path := filepath.Join(h.claude, "projects", project, "session.jsonl")
	h.write(path, fmt.Sprintf(`{"type":"assistant","timestamp":%q,"sessionId":"s","requestId":"r","message":{"id":"m","model":"claude-sonnet-4-5-20250929","role":"assistant","content":[],"usage":{"input_tokens":10,"output_tokens":1}}}`+"\n", at.UTC().Add(-10*time.Second).Format(time.RFC3339Nano)), at)
	return path
}

// ledgerStamps is the metadata of every ledger the observers write.
func (h *observerHome) ledgerStamps() string {
	var out []string
	for _, p := range observeLedgers(h.st.Dir) {
		if info, err := os.Stat(p); err == nil {
			out = append(out, fmt.Sprintf("%s:%d:%d", p, info.Size(), info.ModTime().UnixNano()))
		}
	}
	return strings.Join(out, ",")
}

// D397 / G3-147 (macrevb-1222-3): with both account caches present, a warmed observer neither
// opens nor decodes them again while they are unchanged, and the counters say so; a changed
// cache is read once more.
func TestObserverReadsUnchangedAccountCachesOnce(t *testing.T) {
	h := newObserverHome(t)
	now := time.Now().UTC().Truncate(time.Second)
	old := now.Add(-time.Hour)
	h.accountCaches("sub-codex-a", "sub-claude-a", old)
	h.rollout("2026/11/20", old)
	h.claudeLog("p", old)
	pass := observeForAppIn(h.st, &logindex.Inventory{})
	pass(now)
	pass(now.Add(30 * time.Second))
	before := idlework.Snapshot()
	pass(now.Add(60 * time.Second))
	pass(now.Add(90 * time.Second))
	if got := idlework.Snapshot().Since(before); got.Opens != 0 || got.Bytes != 0 || got.Decodes != 0 {
		t.Fatalf("warmed observer passes did content work on unchanged account caches: %+v", got)
	}
	if refs := cachedSubscriptions(h.st, now); refs["codex"] != "sub-codex-a" || refs["claude-code"] != "sub-claude-a" {
		t.Fatalf("memoized bindings = %v", refs)
	}
	h.accountCaches("sub-codex-bb", "sub-claude-a", old.Add(time.Minute))
	before = idlework.Snapshot()
	refs := cachedSubscriptions(h.st, now)
	if got := idlework.Snapshot().Since(before); refs["codex"] != "sub-codex-bb" || got.Opens != 2 || got.Decodes != 2 {
		t.Fatalf("a rewritten account cache: refs %v, work %+v (want both caches read once)", refs, got)
	}
}

// D397 (macrevb-1222-4): a log path the inventory remembered is refused when its ancestry
// changed before the observation read it (a project or date directory replaced by a symlink
// to a directory outside the admitted root): no content open and no ledger change.
func TestObserverRefusesRememberedPathsWithChangedAncestry(t *testing.T) {
	h := newObserverHome(t)
	now := time.Now().UTC().Truncate(time.Second)
	recent := now.Add(-5 * time.Second)
	h.rollout("2026/11/24", recent)
	h.claudeLog("p", recent)
	pass := observeForAppIn(h.st, &logindex.Inventory{})
	pass(now) // the inventory now remembers both paths

	outside := filepath.Join(h.home, "outside")
	for _, dir := range []string{filepath.Join(h.codex, "sessions", "2026", "11", "24"), filepath.Join(h.claude, "projects", "p")} {
		moved := filepath.Join(outside, filepath.Base(dir)+"-"+filepath.Base(filepath.Dir(dir)))
		if err := os.MkdirAll(outside, 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.Rename(dir, moved); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(moved, dir); err != nil {
			t.Fatal(err)
		}
	}
	ledgers := h.ledgerStamps()
	before := idlework.Snapshot()
	results := pass(now.Add(time.Second)) // before the inventory's next check: cached paths
	if got := idlework.Snapshot().Since(before); got.Opens != 0 || got.Bytes != 0 {
		t.Fatalf("the observer opened remembered paths through a replaced ancestor: %+v (%+v)", got, results)
	}
	if h.ledgerStamps() != ledgers {
		t.Fatalf("a refused pass changed a ledger: %+v", results)
	}
}

// D397 (macrevb-1222-4, round 2): the ancestry changes after the confinement check passed and
// before the readers open the logs. The opens are anchored to the admitted roots, so they fail:
// no content is read and no ledger changes.
func TestObserverOpensStayUnderTheRootWhenAncestryChangesAfterTheCheck(t *testing.T) {
	for _, source := range []string{"codex", "claude", "live"} {
		t.Run(source, func(t *testing.T) { observerOpenRace(t, source) })
	}
}

// observerOpenRace swaps the ancestors when the given observer has passed its check.
func observerOpenRace(t *testing.T, source string) {
	h := newObserverHome(t)
	now := time.Now().UTC().Truncate(time.Second)
	recent := now.Add(-5 * time.Second)
	h.rollout("2026/11/24", recent)
	h.claudeLog("p", recent)
	pass := observeForAppIn(h.st, &logindex.Inventory{})
	pass(now)

	swapped := false
	observeOpenHook = func(at string) {
		if swapped || at != source {
			return
		}
		swapped = true
		outside := filepath.Join(h.home, "outside")
		for _, dir := range []string{filepath.Join(h.codex, "sessions", "2026", "11", "24"), filepath.Join(h.claude, "projects", "p")} {
			moved := filepath.Join(outside, filepath.Base(dir)+"-"+filepath.Base(filepath.Dir(dir)))
			if err := os.MkdirAll(outside, 0o700); err != nil {
				t.Error(err)
			}
			if err := os.Rename(dir, moved); err != nil {
				t.Error(err)
			}
			if err := os.Symlink(moved, dir); err != nil {
				t.Error(err)
			}
			// What sits outside the root now has unread lines: a read through the swapped
			// ancestor would record them.
			entries, _ := os.ReadDir(moved)
			for _, e := range entries {
				f, err := os.OpenFile(filepath.Join(moved, e.Name()), os.O_APPEND|os.O_WRONLY, 0)
				if err != nil {
					t.Error(err)
					continue
				}
				at := now.Add(-2 * time.Second).Format(time.RFC3339Nano)
				// Bulk that only a read of the outside copy can account for.
				filler := fmt.Sprintf(`{"timestamp":%q,"type":"response_item","payload":{"text":"%s"}}`+"\n", at, strings.Repeat("x", 1000))
				fmt.Fprint(f, strings.Repeat(filler, 1024))
				fmt.Fprintf(f, `{"type":"assistant","timestamp":%q,"sessionId":"s","requestId":"r2","message":{"id":"m2","model":"claude-outside-model","role":"assistant","content":[],"usage":{"input_tokens":20,"output_tokens":2}}}`+"\n", at)
				fmt.Fprintf(f, `{"timestamp":%q,"type":"turn_context","payload":{"model":"gpt-outside-model","effort":"low"}}`+"\n", at)
				fmt.Fprintf(f, `{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":200,"output_tokens":20},"total_token_usage":{"input_tokens":300,"output_tokens":30}}}}`+"\n", at)
				f.Close()
			}
		}
	}
	t.Cleanup(func() { observeOpenHook = nil })
	before := idlework.Snapshot()
	results := pass(now.Add(time.Second))
	if !swapped {
		t.Fatalf("the %s observer never reached its reads: %+v", source, results)
	}
	// ModelPlan's own ledgers are a few kilobytes; the outside copies carry a megabyte each.
	if got := idlework.Snapshot().Since(before); got.Bytes >= 128<<10 {
		t.Fatalf("%d content bytes read after the ancestor was swapped out of the root: %+v", got.Bytes, results)
	}
	// The other observers may still write; what must never reach a ledger is the content only
	// the outside copies hold.
	for _, p := range observeLedgers(h.st.Dir) {
		if b, _ := os.ReadFile(p); strings.Contains(string(b), "outside-model") {
			t.Fatalf("a read followed an ancestor swapped after the check and recorded it in %s: %+v", filepath.Base(p), results)
		}
	}
}

// D397 / privacy (macrevb-1222-5): when the consent generation and the cached account change
// between an observation's discovery and its commit, nothing bound to the earlier account is
// published under the new generation; the next pass binds the new account.
func TestObserverNeverCommitsAnEarlierBindingUnderALaterGrant(t *testing.T) {
	h := newObserverHome(t)
	now := time.Now().UTC().Truncate(time.Second)
	h.accountCaches("sub-codex-a", "sub-claude-a", now.Add(-time.Hour))
	// A recording that started before the turn, and one complete Codex turn: the speed
	// observation records a session bound to the account.
	h.write(speed.PerfPath(h.st.Dir), fmt.Sprintf(`{"schemaVersion":1,"since":%q,"rows":[]}`, now.Add(-time.Hour).Format(time.RFC3339Nano)), now.Add(-time.Hour))
	cx := func(at time.Time, kind, payload string) string {
		return fmt.Sprintf(`{"timestamp":%q,"type":%q,"payload":%s}`+"\n", at.Format(time.RFC3339Nano), kind, payload)
	}
	turn := now.Add(-60 * time.Second)
	h.write(filepath.Join(h.codex, "sessions", "2026", "11", "24", "rollout-2026-11-24T10-00-00-turn.jsonl"),
		cx(turn.Add(-time.Second), "session_meta", `{"id":"SYNTHETIC-TURN","source":"cli"}`)+
			cx(turn, "event_msg", `{"type":"task_started"}`)+
			cx(turn, "turn_context", `{"model":"gpt-6.1-sol","effort":"high"}`)+
			cx(turn.Add(12*time.Second), "event_msg", fmt.Sprintf(`{"type":"item_completed","item":{"type":"AgentMessage","id":"i"},"started_at_ms":%d}`, turn.Add(2*time.Second).UnixMilli()))+
			cx(turn.Add(12*time.Second), "event_msg", `{"type":"token_count","info":{"last_token_usage":{"output_tokens":600}}}`)+
			cx(turn.Add(30*time.Second), "event_msg", `{"type":"task_complete","duration_ms":30000}`), now.Add(-5*time.Second))
	fired := false
	observeCommitHook = func(string) {
		if fired {
			return
		}
		fired = true
		// Another grant is committed (local history stays allowed) and a refresh records
		// another signed-in account.
		if err := consent.Change(consent.Path(), func(s *consent.State) error {
			s.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
			return nil
		}); err != nil {
			t.Error(err)
		}
		h.accountCaches("sub-codex-b", "sub-claude-b", now.Add(-30*time.Minute))
	}
	t.Cleanup(func() { observeCommitHook = nil })
	pass := observeForAppIn(h.st, &logindex.Inventory{})
	pass(now)
	if !fired {
		t.Fatal("the observation never reached its commit")
	}
	ledgers := func() string {
		var all string
		for _, p := range observeLedgers(h.st.Dir) {
			b, _ := os.ReadFile(p)
			all += string(b)
		}
		return all
	}
	if got := ledgers(); strings.Contains(got, "sub-codex-a") {
		t.Fatal("an observation committed under the new grant carries the earlier account's binding")
	}
	pass(now.Add(time.Second))
	if got := ledgers(); strings.Contains(got, "sub-codex-a") || !strings.Contains(got, "sub-codex-b") {
		t.Fatalf("the next pass did not bind the current account: a=%v b=%v", strings.Contains(got, "sub-codex-a"), strings.Contains(got, "sub-codex-b"))
	}
	if _, ok := speed.LoadPerf(h.st.Dir); !ok {
		t.Fatal("no performance ledger")
	}
}
