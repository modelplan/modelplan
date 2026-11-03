// SPDX-License-Identifier: MIT
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appcontract"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/store"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func syntheticHash(b []byte) string { h := sha256.Sum256(b); return hex.EncodeToString(h[:]) }
func TestResetEventsVerifiedPublicationRealBinary(t *testing.T) {
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	t.Setenv("MODELPLAN_CACHE", filepath.Join(home, "cache"))
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	t.Setenv("MODELPLAN_READERS", "")
	if err := os.MkdirAll(filepath.Join(home, ".codex"), 0700); err != nil {
		t.Fatal(err)
	}
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	published := now.Add(-time.Minute).Format(time.RFC3339)
	deadline := now.Add(2 * time.Hour).Truncate(time.Second)
	dummy := strings.Repeat("a", 64)
	component := map[string]any{"schemaVersion": 1, "kind": "client", "dependencies": map[string]string{"models": dummy, "registry": dummy, "rules": dummy, "calendar": dummy}, "data": map[string]any{"units": map[string]string{"ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"}, "models": []any{}, "lineups": []any{}, "resets": []any{map[string]any{"id": "synthetic-announcement", "provider": "openai", "eventType": "direct_reset_announced", "status": "upstream-announced", "scope": "unmapped synthetic scope", "url": "https://aihot.news/openai-reset", "observationUrl": "https://x.com/OpenAI/status/123", "publishedAt": published, "schedule": map[string]any{"precision": "deadline", "from": deadline, "through": deadline, "label": "before the deadline"}}}, "windows": []any{}}}
	data := component["data"].(map[string]any)
	data["resets"] = append(data["resets"].([]any),
		map[string]any{"id": "synthetic-official-only", "provider": "openai", "eventType": "direct_reset_announced", "status": "upstream-announced", "publishedAt": published, "url": "https://status.openai.com/incidents/only"},
		map[string]any{"id": "synthetic-official-pair", "provider": "openai", "eventType": "direct_reset_announced", "status": "upstream-announced", "publishedAt": published, "url": "https://aihot.news/openai-reset", "observationUrl": "https://status.openai.com/incidents/pair"},
		map[string]any{"id": "synthetic-missing", "provider": "openai", "eventType": "direct_reset_announced", "status": "upstream-announced", "publishedAt": published},
		map[string]any{"id": "synthetic-unsafe", "provider": "openai", "eventType": "direct_reset_announced", "status": "upstream-announced", "publishedAt": published, "url": "https://aihot.news/users/alice", "observationUrl": "https://status.openai.com/incidents/abc?tracking=123"},
		map[string]any{"id": "synthetic-confirmed", "provider": "openai", "eventType": "direct_reset_announced", "status": "upstream-announced", "publishedAt": published, "url": "https://aihot.news/reset-announced"},
		map[string]any{"provider": "openai", "eventType": "direct_reset_reported_complete", "status": "upstream-confirmed", "publishedAt": published, "confirms": "synthetic-confirmed", "url": "https://aihot.news/reset-confirmed", "observationUrl": "https://x.com/OpenAI/status/456"})
	blob, _ := json.Marshal(component)
	hash := syntheticHash(blob)
	refs := map[string]any{}
	for _, name := range []string{"methods", "registry", "models", "plans", "rules", "news", "calendar"} {
		refs[name] = map[string]any{"schemaVersion": 1, "hash": dummy, "bytes": 2}
	}
	refs["client"] = map[string]any{"schemaVersion": 1, "hash": hash, "bytes": len(blob)}
	core := struct {
		SchemaVersion     int               `json:"schemaVersion"`
		ComparisonVersion string            `json:"comparisonVersion"`
		Methods           map[string]string `json:"methods"`
		Components        map[string]any    `json:"components"`
	}{1, "synthetic", map[string]string{"index": "unified-v03-estimator-0.1.0-internal", "recommendation": "balanced-coding-absolute-v4"}, refs}
	coreBytes, _ := json.Marshal(core)
	id := syntheticHash(coreBytes)[:24]
	manifest := append(append([]byte(nil), coreBytes[:len(coreBytes)-1]...), []byte(`,"publicationId":"`+id+`","publishedAt":"`+published+`"}`)...)
	if err := st.PutObject(hash, blob); err != nil {
		t.Fatal(err)
	}
	if err := st.PutManifest(id, manifest); err != nil {
		t.Fatal(err)
	}
	if err := st.SaveState(store.State{PublicationID: id, ManifestHash: syntheticHash(manifest), Component: "client", ComponentHash: hash}); err != nil {
		t.Fatal(err)
	}
	if _, _, err := publication.Load(st); err != nil {
		t.Fatalf("synthetic publication is not verified: %v", err)
	}
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, raw)
	}
	p := startQueryBinaryCaps(t, binary, []string{"rows", "resetEvents"})
	var handshake struct {
		Data struct {
			Capabilities []string `json:"capabilities"`
		} `json:"data"`
	}
	if err := json.Unmarshal(p.initialize["result"], &handshake); err != nil {
		t.Fatal(err)
	}
	if !containsCapability(handshake.Data.Capabilities, "resetEvents") || !containsCapability(handshake.Data.Capabilities, "resetEventLinksV1") || containsCapability(handshake.Data.Capabilities, "reset_events_v1") {
		t.Fatalf("unexpected server capabilities: %v", handshake.Data.Capabilities)
	}
	response := p.call("rows/subscribe", map[string]any{})
	var env struct {
		Data struct {
			Projection struct {
				ResetEvents []struct {
					ID        string    `json:"id"`
					RowID     string    `json:"rowId"`
					Status    string    `json:"status"`
					ExpiresAt time.Time `json:"expiresAt"`
					Schedule  *struct {
						Precision string    `json:"precision"`
						From      time.Time `json:"from"`
						Through   time.Time `json:"through"`
					} `json:"schedule"`
				} `json:"resetEvents"`
			} `json:"projection"`
		} `json:"data"`
	}
	if err := json.Unmarshal(response["result"], &env); err != nil {
		t.Fatalf("rows result: %v %s", err, response["error"])
	}
	if len(env.Data.Projection.ResetEvents) != 6 || env.Data.Projection.ResetEvents[0].ID != "synthetic-announcement" || env.Data.Projection.ResetEvents[0].RowID != "codex" {
		t.Fatalf("events: %+v", env.Data.Projection.ResetEvents)
	}
	event := env.Data.Projection.ResetEvents[0]
	if event.Status != "announced" || event.Schedule == nil || event.Schedule.Precision != "deadline" || !event.Schedule.From.Equal(deadline) || !event.Schedule.Through.Equal(deadline) || !event.ExpiresAt.Equal(deadline) {
		t.Fatalf("point deadline changed: %+v", event)
	}
	if strings.Contains(string(response["result"]), `"links"`) {
		t.Fatal("old events client received links")
	}
	linked := startQueryBinaryCaps(t, binary, []string{"rows", "resetEvents", "resetEventLinksV1", "cockpitDetailsV1"})
	linkedRows := linked.call("rows/subscribe", map[string]any{})
	linkedCockpit := linked.call("cockpit/query", map[string]any{})
	for name, response := range map[string]map[string]json.RawMessage{"rows": linkedRows, "cockpit": linkedCockpit} {
		if !strings.Contains(string(response["result"]), `"https://aihot.news/openai-reset"`) || !strings.Contains(string(response["result"]), `"https://x.com/OpenAI/status/123"`) {
			t.Fatalf("%s missing published links: %s %s", name, response["result"], response["error"])
		}
	}
	// Missing and unsafe sources remain visible without links; confirmations
	// carry the confirmation's own reviewed publication fields.
	var findEvent func(any, string) map[string]any
	findEvent = func(v any, id string) map[string]any {
		switch x := v.(type) {
		case map[string]any:
			if x["id"] == id {
				return x
			}
			for _, child := range x {
				if found := findEvent(child, id); found != nil {
					return found
				}
			}
		case []any:
			for _, child := range x {
				if found := findEvent(child, id); found != nil {
					return found
				}
			}
		}
		return nil
	}
	for name, response := range map[string]map[string]json.RawMessage{"rows": linkedRows, "cockpit": linkedCockpit} {
		var payload any
		if err := json.Unmarshal(response["result"], &payload); err != nil {
			t.Fatal(err)
		}
		for _, id := range []string{"synthetic-missing", "synthetic-unsafe"} {
			event := findEvent(payload, id)
			if event == nil {
				t.Fatalf("%s lost %s", name, id)
			}
			source, ok := event["source"].(map[string]any)
			if !ok || source["links"] != nil {
				t.Fatalf("%s exposed unsafe links: %v", name, event)
			}
		}
		for id, url := range map[string]string{"synthetic-official-only": "https://status.openai.com/incidents/only", "synthetic-official-pair": "https://status.openai.com/incidents/pair"} {
			event := findEvent(payload, id)
			encoded, _ := json.Marshal(event)
			if event == nil || !strings.Contains(string(encoded), url) || strings.Contains(string(encoded), `"original"`) {
				t.Fatalf("%s missing independent official citation: %s", name, encoded)
			}
		}
		event := findEvent(payload, "synthetic-confirmed")
		if event == nil || event["status"] != "confirmed" {
			t.Fatalf("%s missing confirmation: %v", name, event)
		}
		b, _ := json.Marshal(event)
		if !strings.Contains(string(b), "reset-confirmed") || !strings.Contains(string(b), "/status/456") {
			t.Fatalf("%s confirmation links: %s", name, b)
		}
	}
	assertChanged := func(client *queryBinary, scope, requestID string, wantLinks bool) {
		t.Helper()
		var facts wire.Envelope[wire.ConsentFacts]
		current := client.call("consent/get", map[string]any{})
		if err := json.Unmarshal(current["result"], &facts); err != nil {
			t.Fatal(err)
		}
		grant := client.call("consent/grant", wire.ConsentGrantParams{RequestID: requestID, ExpectStoreEpoch: facts.StoreEpoch, ExpectGeneration: facts.ConsentGeneration, TextVersion: consent.TextVersion, Allow: []string{}, Deny: []string{scope}})
		if grant["error"] != nil {
			t.Fatalf("grant: %s", grant["error"])
		}
		deadline := time.After(5 * time.Second)
		for {
			var raw []byte
			if len(client.notifications) > 0 {
				raw = client.notifications[0]
				client.notifications = client.notifications[1:]
			} else {
				select {
				case raw = <-client.frames:
				case <-deadline:
					t.Fatal("rows/changed timed out")
				}
			}
			var msg map[string]json.RawMessage
			if json.Unmarshal(raw, &msg) != nil || string(msg["method"]) != `"rows/changed"` {
				continue
			}
			if !strings.Contains(string(msg["params"]), `"synthetic-announcement"`) {
				continue
			}
			if wantLinks && (!strings.Contains(string(msg["params"]), "https://status.openai.com/incidents/only") || !strings.Contains(string(msg["params"]), "https://status.openai.com/incidents/pair")) {
				t.Fatalf("changed notification omitted official citations: %s", raw)
			}
			if strings.Contains(string(msg["params"]), `"links"`) != wantLinks {
				t.Fatalf("changed links mismatch: %s", raw)
			}
			return
		}
	}
	encoded, err := json.Marshal(response)
	if err != nil {
		t.Fatal(err)
	}
	validator, err := appcontract.NewValidator("../../..")
	if err != nil {
		t.Fatal(err)
	}
	if err := validator.Validate("app-server", encoded); err != nil {
		t.Fatalf("deadline response violates production schema: %v", err)
	}
	cockpit := p.call("cockpit/query", map[string]any{})
	if cockpit["result"] == nil || !strings.Contains(string(cockpit["result"]), `"resetEvents"`) || strings.Contains(string(cockpit["result"]), `"links"`) {
		t.Fatalf("negotiated cockpit missing reset events: %s", cockpit["error"])
	}
	detailsClient := startQueryBinaryCaps(t, binary, []string{"rows", "cockpit", "cockpitDetailsV1"})
	details := detailsClient.call("cockpit/query", map[string]any{})
	if details["result"] == nil || !strings.Contains(string(details["result"]), `"details"`) || !strings.Contains(string(details["result"]), `"synthetic-announcement"`) || strings.Contains(string(details["result"]), `"links"`) {
		t.Fatalf("negotiated cockpit details missing: %s", details["error"])
	}
	encodedDetails, err := json.Marshal(details)
	if err != nil {
		t.Fatal(err)
	}
	if err := validator.Validate("app-server", encodedDetails); err != nil {
		t.Fatalf("cockpit details violate schema: %v", err)
	}
	configured := detailsClient.call("cockpit/query", map[string]any{"redBelow": 16})
	if configured["result"] == nil {
		t.Fatalf("negotiated threshold rejected: %s", configured["error"])
	}
	legacy := startQueryBinaryCaps(t, binary, []string{"rows", "reset_events_v1"})
	if rejected := legacy.call("cockpit/query", map[string]any{"redBelow": 16}); rejected["error"] == nil {
		t.Fatal("legacy client accepted negotiated-only threshold")
	}
	old := legacy.call("rows/subscribe", map[string]any{})
	legacyCockpit := legacy.call("cockpit/query", map[string]any{})
	if legacyCockpit["result"] == nil || strings.Contains(string(legacyCockpit["result"]), `"resetEvents"`) || strings.Contains(string(legacyCockpit["result"]), `"details"`) {
		t.Fatalf("legacy cockpit negotiation: %s", legacyCockpit["error"])
	}
	if strings.Contains(string(old["result"]), "resetEvents") {
		t.Fatal("unnegotiated client received reset events")
	}
	assertChanged(p, consent.ScopeCursorLocalHistory, "old-link-capability", false)
	assertChanged(linked, consent.ScopeCodexLocalHistory, "new-link-capability", true)
}

func containsCapability(caps []string, want string) bool {
	for _, cap := range caps {
		if cap == want {
			return true
		}
	}
	return false
}
