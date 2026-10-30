// SPDX-License-Identifier: MIT
package localusage

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

const cursorCountFixture = `{"event":"stop","ts":"2026-10-23T10:00:00Z","conversation_id":"private-cursor-session","generation_id":"private-cursor-turn","model":"cursor-test","tokens_present":true,"input_tokens":10,"output_tokens":2,"total_tokens":12,"prompt_preview":"private-cursor-prompt","workspace_roots":["/private/project"],"access_token":"private-cursor-token"}` + "\n"

func TestCursorHistoryProductionCountLog(t *testing.T) {
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	cache := t.TempDir()
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_READERS", "")
	file := filepath.Join(home, ".cursor", "token-usage", "usage.jsonl")
	fixtureFile(t, file, cursorCountFixture)
	before := ProductionHistory(home, cache, "cursor", false, testNow)
	if before.Availability != "consent_required" || before.BytesRead != 0 {
		t.Fatal("Cursor read without local consent", before)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		return consent.Set(s, "cursor", true, "native:cursor", "native", testNow)
	}); err != nil {
		t.Fatal(err)
	}
	grantCursorHistoryFixture(t)
	result := RefreshProductionHistory(context.Background(), home, cache, "cursor", testNow)
	if result.Availability != "ok" || len(result.Rows) != 1 || result.Rows[0].Total == nil || *result.Rows[0].Total != 12 {
		t.Fatal("Cursor typed count producer unavailable", result)
	}
	original, _ := os.ReadFile(file)
	root, access := ProductionHistoryAccess(home, "cursor", false)
	if root != filepath.Dir(file) {
		t.Fatal("unreviewed source root")
	}
	stored, _ := os.ReadFile(historyPath(cache, "cursor", access))
	public, _ := json.Marshal(result)
	for _, bytes := range [][]byte{stored, public} {
		for _, canary := range []string{"private-cursor-session", "private-cursor-turn", "private-cursor-prompt", "/private/project", "private-cursor-token"} {
			if strings.Contains(string(bytes), canary) {
				t.Fatal("Cursor private field escaped numeric projection")
			}
		}
	}
	if got, _ := os.ReadFile(file); string(got) != string(original) {
		t.Fatal("Cursor source modified")
	}
	fixtureFile(t, file, "malformed changed source\n")
	cached := ProductionHistory(home, cache, "cursor", true, testNow.Add(time.Minute))
	if len(cached.Rows) != 1 || *cached.Rows[0].Total != 12 {
		t.Fatal("query refreshed source")
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		return consent.Set(s, "cursor", false, "native:cursor", "native", testNow)
	}); err != nil {
		t.Fatal(err)
	}
	if result := ProductionHistory(home, cache, "cursor", true, testNow); len(result.Rows) != 0 {
		t.Fatal("revoked Cursor history retained")
	}
}

func grantCursorHistoryFixture(t *testing.T) {
	t.Helper()
	s, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	_, err = consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "cursor-local-fixture", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeCursorLocalHistory}, Deny: []string{}}, consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) {
		return consent.Record{ReaderID: "native:cursor", Backend: "native"}, nil
	}, Cleanup: func(string, bool) error { return nil }})
	if err != nil {
		t.Fatal(err)
	}
}

func TestCursorCountsDoNotInferOrKeepInvalidUsage(t *testing.T) {
	for _, raw := range []string{
		`{"event":"stop","tokens_present":false,"total_tokens":999}`,
		`{"event":"prompt","tokens_present":true,"total_tokens":999}`,
		`{"event":"stop","tokens_present":true,"conversation_id":"s","generation_id":"g","ts":"2026-10-23T10:00:00Z","context_tokens":999,"estimated_cost_usd":1}`,
	} {
		rows, err := decodeCursorCounts([]byte(raw))
		if err != nil || len(rows) != 0 {
			t.Fatal("unknown or non-usage record counted")
		}
	}
	for _, value := range []string{`-1`, `1000000000000001`, `1.5`, `"12"`, `true`} {
		raw := `{"event":"stop","tokens_present":true,"conversation_id":"s","generation_id":"g","ts":"2026-10-23T10:00:00Z","total_tokens":` + value + `}`
		if _, err := decodeCursorCounts([]byte(raw)); err == nil {
			t.Fatal("invalid native count accepted")
		}
	}
	raw := `{"event":"stop","tokens_present":true,"conversation_id":"s","generation_id":"g","ts":"2026-10-23T10:00:00Z","input_tokens":10}`
	rows, err := decodeCursorCounts([]byte(raw))
	if err != nil || len(rows) != 1 || rows[0].Counts.Total != nil || rows[0].Counts.Output != nil {
		t.Fatal("absent count inferred")
	}
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	fixtureFile(t, filepath.Join(root, "usage.jsonl"), cursorCountFixture+cursorCountFixture)
	result := RefreshHistory(context.Background(), "cursor", root, cache, a, testNow)
	if len(result.Rows) != 1 || result.Rows[0].Total == nil || *result.Rows[0].Total != 12 {
		t.Fatal("duplicate Cursor turns summed")
	}
}
