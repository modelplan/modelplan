// SPDX-License-Identifier: MIT
package localusage

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

type productionHistoryFixture struct {
	rel, body string
	input     int64
	undated   bool
}

var productionHistoryTests = map[string]productionHistoryFixture{
	"cursor":  {"usage.jsonl", cursorCountFixture, 10, false},
	"amp":     {"T-synthetic.json", `{"id":"synthetic","messages":[{"role":"assistant","messageId":1,"usage":{"model":"amp-test","timestamp":"2026-10-23T10:00:00Z","inputTokens":10,"outputTokens":2}}]}`, 10, false},
	"droid":   {"project/synthetic.settings.json", `{"tokenUsage":{"inputTokens":10,"outputTokens":2}}`, 10, true},
	"kimi":    {"project/synthetic/wire.jsonl", fmt.Sprintf(`{"timestamp":%d,"message":{"type":"StatusUpdate","payload":{"message_id":"synthetic","token_usage":{"input_other":3,"output":2}}}}`+"\n", testNow.Add(-time.Hour).Unix()), 3, false},
	"copilot": {"synthetic/events.jsonl", `{"type":"session.start","timestamp":"2026-10-23T09:00:00Z","data":{}}` + "\n" + `{"type":"session.shutdown","timestamp":"2026-10-23T11:00:00Z","data":{"modelMetrics":{"copilot-test":{"usage":{"inputTokens":10,"outputTokens":2}}}}}` + "\n", 10, false},
	"grok":    {"project/synthetic/usage.json", `{"turns":[{"turnNumber":1,"endedAt":"2026-10-23T10:00:00Z","modelUsage":{"grok-test":{"inputTokens":10,"outputTokens":2}}}]}`, 10, false},
	"qwen":    {"projects/project/chats/synthetic.jsonl", qwenHistoryLine("synthetic", 10), 10, false},
	"gemini":  {"tmp/project/chats/session-synthetic.json", sessionJSON(messageOne), 100, false},
}

func TestProductionHistoryInventory(t *testing.T) {
	for _, tool := range HistoryProviders() {
		if _, ok := productionHistoryTests[tool]; !ok {
			t.Error("no production admission test for history adapter", tool)
		}
	}
}

func TestProductionHistoryAdmission(t *testing.T) {
	for tool, fixture := range productionHistoryTests {
		t.Run(tool, func(t *testing.T) {
			testenv.IsolateHome(t)
			for _, name := range []string{"MODELPLAN_GEMINI_HOME", "MODELPLAN_QWEN_HOME", "MODELPLAN_GEMINI", "MODELPLAN_QWEN", "MODELPLAN_QWEN_USAGE_EXPORT"} {
				t.Setenv(name, "")
			}
			t.Setenv("MODELPLAN_READERS", "")
			t.Setenv("MODELPLAN_HISTORY", "")
			t.Setenv("GROK_HOME", "")
			home, _ := os.UserHomeDir()
			cache := t.TempDir()
			root := productionHistoryRoot(home, tool)
			fixtureFile(t, filepath.Join(root, fixture.rel), fixture.body)
			if tool == "grok" {
				fixtureFile(t, filepath.Join(filepath.Dir(filepath.Join(root, fixture.rel)), "summary.json"), `{"info":{},"created_at":"2026-10-23T09:00:00Z","num_messages":1}`)
			}
			before := ProductionHistory(home, cache, tool, false, testNow)
			if before.Availability != "consent_required" || before.BytesRead != 0 {
				t.Fatal("source read without consent", before)
			}
			if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, tool, true, "native:"+tool, "native", testNow) }); err != nil {
				t.Fatal(err)
			}
			if tool == "cursor" {
				grantCursorHistoryFixture(t)
			}
			if tool == "gemini" {
				if err := SetGemini(home, true); err != nil {
					t.Fatal(err)
				}
			}
			if tool == "qwen" {
				if err := SetQwen(home, true); err != nil {
					t.Fatal(err)
				}
			}
			if !ProductionHistoryDue(home, cache, testNow) {
				t.Fatal("consented local history never due")
			}
			r := ProductionHistory(home, cache, tool, false, testNow)
			rows := r.Rows
			if fixture.undated {
				rows = r.Unallocated
			}
			if len(rows) != 1 || rows[0].Input == nil || *rows[0].Input != fixture.input {
				t.Fatalf("production adapter not wired: %+v", r)
			}
			_, a := ProductionHistoryAccess(home, tool, false)
			if len(a.Key) != 32 || len(a.ProfileRef) != 64 || a.StillValid == nil {
				t.Fatal("production key/consent handoff missing")
			}
			cached := ProductionHistory(home, cache, tool, true, testNow.Add(time.Minute))
			b, _ := json.Marshal(cached)
			if len(b) == 0 || len(cached.Rows)+len(cached.Unallocated) != 1 {
				t.Fatal("cache-only projection lost data", cached)
			}
			t.Setenv("MODELPLAN_READERS", "off")
			off := ProductionHistory(home, cache, tool, false, testNow.Add(time.Hour))
			if off.Availability != "off" || off.BytesRead != 0 || len(off.Rows) != 0 {
				t.Fatal("off admitted history", off)
			}
			t.Setenv("MODELPLAN_READERS", "")
			if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, tool, false, "", "", testNow) }); err != nil {
				t.Fatal(err)
			}
			if a.StillValid() {
				t.Fatal("old history access survived revocation")
			}
			revoked := ProductionHistory(home, cache, tool, false, testNow.Add(time.Hour))
			if revoked.Availability != "consent_required" || revoked.BytesRead != 0 || len(revoked.Rows) != 0 {
				t.Fatal("revoked source admitted", revoked)
			}
		})
	}
}

func TestProductionHistoryForgetKeepsOtherToolsAndGate(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_HISTORY", "")
	home, _ := os.UserHomeDir()
	cache := t.TempDir()
	for _, tool := range []string{"amp", "droid"} {
		fixture := productionHistoryTests[tool]
		fixtureFile(t, filepath.Join(productionHistoryRoot(home, tool), fixture.rel), fixture.body)
		if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, tool, true, "native:"+tool, "native", testNow) }); err != nil {
			t.Fatal(err)
		}
		ProductionHistory(home, cache, tool, false, testNow)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "amp", false, "", "", testNow) }); err != nil {
		t.Fatal(err)
	}
	if err := ForgetProductionHistory(cache, "amp"); err != nil {
		t.Fatal(err)
	}
	files, err := filepath.Glob(filepath.Join(cache, "observed", "history-v1-amp-*.json"))
	if err != nil || len(files) != 0 {
		t.Fatal("Amp captures remained", files, err)
	}
	gate, _ := historyGatePaths(cache, "amp")
	if _, err := os.Stat(gate); err != nil {
		t.Fatal("request floor removed", err)
	}
	r := ProductionHistory(home, cache, "droid", true, testNow)
	if len(r.Unallocated) != 1 {
		t.Fatal("another tool's history removed", r)
	}
}

func TestProductionHistoryLocalOptOutVetoesSharedGrant(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_QWEN_HOME", "")
	t.Setenv("MODELPLAN_QWEN", "")
	home, _ := os.UserHomeDir()
	cache := t.TempDir()
	fixture := productionHistoryTests["qwen"]
	fixtureFile(t, filepath.Join(productionHistoryRoot(home, "qwen"), fixture.rel), fixture.body)
	if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "qwen", true, "native:qwen", "native", testNow) }); err != nil {
		t.Fatal(err)
	}
	if err := SetQwen(home, true); err != nil {
		t.Fatal(err)
	}
	_, access := ProductionHistoryAccess(home, "qwen", false)
	if !access.Allowed || !access.StillValid() {
		t.Fatal("explicit local opt-in missing")
	}
	if err := SetQwen(home, false); err != nil {
		t.Fatal(err)
	}
	if access.StillValid() {
		t.Fatal("in-flight local read survived source opt-out")
	}
	r := ProductionHistory(home, cache, "qwen", false, testNow)
	if r.BytesRead != 0 || len(r.Rows) != 0 {
		t.Fatal("source opt-out bypassed", r)
	}
}
