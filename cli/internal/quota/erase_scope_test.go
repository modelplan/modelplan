// SPDX-License-Identifier: MIT
package quota

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

func TestAccountScopeCleanupKeepsIndependentKeyValuesAndBudget(t *testing.T) {
	for _, forget := range []bool{false, true} {
		t.Run(map[bool]string{false: "deny", true: "forget"}[forget], func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			cache := t.TempDir()
			p := Paths{Cache: cache}
			now := time.Now().UTC()
			loginRef := assignSubscription(cache, "kimi-code-login:china", "synthetic-login", now)
			keyRef := assignSubscription(cache, "api-key", "synthetic-explicit-key", now)
			if loginRef == "" || keyRef == "" {
				t.Fatal("identity setup failed")
			}
			state := &readerState{SchemaVersion: 1, Provider: "kimi", NextAttemptAt: now.Add(time.Hour), Entries: []readerEntry{{ProfileKey: "synthetic", Status: "ok", Account: &Account{Subscription: &Binding{Ref: loginRef, Status: "verified", Basis: "kimi-code-login:china"}}}}}
			if err := saveReaderState(cache, state); err != nil {
				t.Fatal(err)
			}
			native, _ := json.Marshal(nativeSnap{SchemaVersion: 1, Providers: []codexbarEntry{{Provider: "kimi", Status: "ok", SubscriptionRef: keyRef}}})
			path := filepath.Join(cache, "observed", "native.json")
			if err := writeAtomic(path, native); err != nil {
				t.Fatal(err)
			}
			if err := reserveReaderAttempt(cache, "kimi", state.NextAttemptAt); err != nil {
				t.Fatal(err)
			}
			if err := EraseScope(p, consent.ScopeKimiAccountUsageSavedLogin, forget); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(readerPath(cache, "kimi")); !os.IsNotExist(err) {
				t.Fatal("saved-login capture survived", err)
			}
			after, _ := os.ReadFile(path)
			if string(after) != string(native) {
				t.Fatal("saved-login revoke erased independent key reading")
			}
			if readerAttemptDue(cache, "kimi", now.Add(10*time.Minute)) {
				t.Fatal("cleanup reset shared budget")
			}
			if ref := lookupSubscription(cache, "api-key", "synthetic-explicit-key"); ref != keyRef {
				t.Fatal("other scope identity erased")
			}
			ref := lookupSubscription(cache, "kimi-code-login:china", "synthetic-login")
			if forget && ref != "" || !forget && ref != loginRef {
				t.Fatal("deny/Forget identity semantics", ref, forget)
			}
		})
	}
}

func TestRetiredScopeErasesCachesWithoutCompiledReader(t *testing.T) {
	for _, forget := range []bool{false, true} {
		t.Run(map[bool]string{false: "deny", true: "forget"}[forget], func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			cache := t.TempDir()
			now := time.Now().UTC()
			ref := assignSubscription(cache, "retired-auth", "synthetic-retired-account", now)
			s := &readerState{SchemaVersion: 1, Provider: "retired-tool", NextAttemptAt: now.Add(time.Hour), Entries: []readerEntry{{Status: "ok", Account: &Account{Subscription: &Binding{Ref: ref, Status: "verified", Basis: "retired-auth"}}}}}
			if err := saveReaderState(cache, s); err != nil {
				t.Fatal(err)
			}
			native, _ := json.Marshal(nativeSnap{SchemaVersion: 1, Providers: []codexbarEntry{{Provider: "retired-tool", SubscriptionRef: ref}, {Provider: "copilot", Status: "ok"}}})
			if err := writeAtomic(nativePath(cache), native); err != nil {
				t.Fatal(err)
			}
			if err := EraseScope(Paths{Cache: cache}, "retired-tool.account_usage.saved_login", forget); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(readerPath(cache, "retired-tool")); !os.IsNotExist(err) {
				t.Fatal("retired reader capture survived", err)
			}
			remaining := loadNative(cache)
			if remaining == nil || len(remaining.Providers) != 1 || remaining.Providers[0].Provider != "copilot" {
				t.Fatal("retired aggregate capture survived or other provider erased", remaining)
			}
			if readerAttemptDue(cache, "retired-tool", now.Add(10*time.Minute)) {
				t.Fatal("retired cache cleanup lost reservation")
			}
			identity := lookupSubscription(cache, "retired-auth", "synthetic-retired-account")
			if forget && identity != "" || !forget && identity != ref {
				t.Fatal("retired identity cleanup semantics", identity, forget)
			}
		})
	}
	t.Run("local", func(t *testing.T) {
		t.Setenv("HOME", t.TempDir())
		cache := t.TempDir()
		dir := filepath.Join(cache, "observed")
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
		stale := filepath.Join(dir, "history-v1-retired-tool-"+strings.Repeat("a", 64)+".json")
		other := filepath.Join(dir, "history-v1-codex-"+strings.Repeat("a", 64)+".json")
		for _, file := range []string{stale, other} {
			if err := os.WriteFile(file, []byte(`{}`), 0600); err != nil {
				t.Fatal(err)
			}
		}
		if err := EraseScope(Paths{Cache: cache}, "retired-tool.local_history", true); err != nil {
			t.Fatal(err)
		}
		if _, err := os.Stat(stale); !os.IsNotExist(err) {
			t.Fatal("retired local history survived", err)
		}
		if _, err := os.Stat(other); err != nil {
			t.Fatal("other tool history erased", err)
		}
	})
}

func TestHistoryForgetPreservesHyphenatedNeighbor(t *testing.T) {
	for _, tool := range []string{"retired", "grok"} {
		t.Run(tool, func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			cache := t.TempDir()
			dir := filepath.Join(cache, "observed")
			if err := os.MkdirAll(dir, 0700); err != nil {
				t.Fatal(err)
			}
			hash := strings.Repeat("a", 64)
			target := filepath.Join(dir, "history-v1-"+tool+"-"+hash+".json")
			neighbor := filepath.Join(dir, "history-v1-"+tool+"-other-"+hash+".json")
			for _, file := range []string{target, neighbor} {
				if err := os.WriteFile(file, []byte(`{}`), 0600); err != nil {
					t.Fatal(err)
				}
			}
			if err := EraseScope(Paths{Cache: cache}, tool+".local_history", true); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(target); !os.IsNotExist(err) {
				t.Fatal("target history survived", err)
			}
			if _, err := os.Stat(neighbor); err != nil {
				t.Fatal("neighboring tool history erased", err)
			}
		})
	}
}

func TestHistoryScopeCleanupErasesOnlyItsPerformanceRecords(t *testing.T) {
	for _, forget := range []bool{false, true} {
		t.Run(map[bool]string{false: "revoke", true: "forget"}[forget], func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			cache := t.TempDir()
			dir := filepath.Join(cache, "observed")
			if err := os.MkdirAll(dir, 0700); err != nil {
				t.Fatal(err)
			}
			path := filepath.Join(dir, "perf.json")
			b := []byte(`{"schemaVersion":1,"since":"2026-11-01T00:00:00Z","rows":[{"source":"codex"},{"source":"claude-code"}],"live":[{"source":"codex"},{"source":"claude-code"}]}`)
			if err := os.WriteFile(path, b, 0600); err != nil {
				t.Fatal(err)
			}
			if err := EraseScope(Paths{Cache: cache}, consent.ScopeCodexLocalHistory, forget); err != nil {
				t.Fatal(err)
			}
			after, err := os.ReadFile(path)
			if err != nil || strings.Contains(string(after), `"codex"`) || !strings.Contains(string(after), `"claude-code"`) {
				t.Fatalf("wrong source cleanup: %s (%v)", after, err)
			}
		})
	}
}

func TestHistoryLedgerRewriteFailureLeavesOriginal(t *testing.T) {
	path := filepath.Join(t.TempDir(), "perf.json")
	before := []byte(`{"rows":[{"source":"codex"},{"source":"claude-code"}]}`)
	if err := os.WriteFile(path, before, 0600); err != nil {
		t.Fatal(err)
	}
	err := filterCachedSourceWithWriter(path, "perf.json", "codex", true, func(string, []byte) error { return errors.New("simulated failure before atomic rename") })
	if err == nil {
		t.Fatal("rewrite failure was ignored")
	}
	after, err := os.ReadFile(path)
	if err != nil || !bytes.Equal(after, before) {
		t.Fatalf("failed rewrite changed original: %s, %v", after, err)
	}
}

// Audit D finding 4: revoking or forgetting one tool's history also drops that tool's imported
// coverage (dates and grant), so the import status no longer reports it; the other tool's stays.
func TestHistoryScopeCleanupErasesItsImportedCoverage(t *testing.T) {
	for _, forget := range []bool{false, true} {
		t.Run(map[bool]string{false: "revoke", true: "forget"}[forget], func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			cache := t.TempDir()
			dir := filepath.Join(cache, "observed")
			if err := os.MkdirAll(dir, 0700); err != nil {
				t.Fatal(err)
			}
			span := `{"from":"2026-10-01T00:00:00Z","through":"2026-10-31T00:00:00Z","epoch":{"storeEpoch":"e","revokedGeneration":0}}`
			b := []byte(`{"schemaVersion":1,"coverage":{"codex":` + span + `,"claude-code":` + span + `},"rows":[{"source":"codex","day":"2026-10-02"},{"source":"claude-code","day":"2026-10-02"}]}`)
			if err := os.WriteFile(filepath.Join(dir, "imported.json"), b, 0600); err != nil {
				t.Fatal(err)
			}
			if err := EraseScope(Paths{Cache: cache}, consent.ScopeCodexLocalHistory, forget); err != nil {
				t.Fatal(err)
			}
			st := speed.ImportStatus(cache)
			if st.Rows != 1 || len(st.Coverage) != 1 || st.Coverage[0].Source != "claude-code" {
				t.Fatalf("codex import left behind: %+v", st)
			}
		})
	}
}

func TestHistoryClearRemovesRequestHashesAndCumulativeTotals(t *testing.T) {
	for _, tool := range []string{"codex", "claude"} {
		t.Run(tool, func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			cache := t.TempDir()
			dir := filepath.Join(cache, "observed")
			if err := os.MkdirAll(dir, 0700); err != nil {
				t.Fatal(err)
			}
			ledger := `{"schemaVersion":1,"since":"2026-11-01T00:00:00Z","rows":[],"files":{"f1":{"offset":9,"seen":"2026-11-12","source":"codex","total":{"input":777}},"legacycursor":{"offset":5,"seen":"2026-11-12"}},"counted":[{"id":"hashclaude1","file":"f1"}],"stores":{"opencode:s1":{"sig":"x","seen":{"hashopen1":1}},"codex:s2":{"sig":"y","seen":{"hashcodex1":1}}}}`
			for _, name := range []string{"speed.json", "perf.json"} {
				if err := os.WriteFile(filepath.Join(dir, name), []byte(ledger), 0600); err != nil {
					t.Fatal(err)
				}
			}
			if err := EraseScope(Paths{Cache: cache}, tool+".local_history", true); err != nil {
				t.Fatal(err)
			}
			// A cursor without a source (an earlier build's) that nothing attributes stays: it may
			// be another tool's, and clearing one tool never drops another's data.
			for _, name := range []string{"speed.json", "perf.json"} {
				b, _ := os.ReadFile(filepath.Join(dir, name))
				got := string(b)
				if !strings.Contains(got, "legacycursor") {
					t.Fatalf("%s dropped an unattributed log cursor: %s", name, got)
				}
				switch tool {
				case "claude":
					if strings.Contains(got, "hashclaude1") {
						t.Fatalf("%s kept counted request hashes: %s", name, got)
					}
					if !strings.Contains(got, "777") || !strings.Contains(got, "hashopen1") || !strings.Contains(got, "hashcodex1") {
						t.Fatalf("%s lost other tools' state: %s", name, got)
					}
				case "codex":
					if strings.Contains(got, "777") || strings.Contains(got, "hashcodex1") {
						t.Fatalf("%s kept codex totals or hashes: %s", name, got)
					}
					if !strings.Contains(got, "hashclaude1") || !strings.Contains(got, "hashopen1") {
						t.Fatalf("%s lost other tools' state: %s", name, got)
					}
				}
			}
		})
	}
}
