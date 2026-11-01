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
	component := map[string]any{"schemaVersion": 1, "kind": "client", "dependencies": map[string]string{"models": dummy, "registry": dummy, "rules": dummy, "calendar": dummy}, "data": map[string]any{"units": map[string]string{"ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"}, "models": []any{}, "lineups": []any{}, "resets": []any{map[string]any{"id": "synthetic-announcement", "provider": "openai", "eventType": "direct_reset_announced", "status": "upstream-announced", "scope": "unmapped synthetic scope", "publishedAt": published, "schedule": map[string]any{"precision": "deadline", "from": deadline, "through": deadline, "label": "before the deadline"}}}, "windows": []any{}}}
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
	if !containsCapability(handshake.Data.Capabilities, "resetEvents") || containsCapability(handshake.Data.Capabilities, "reset_events_v1") {
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
	if len(env.Data.Projection.ResetEvents) != 1 || env.Data.Projection.ResetEvents[0].ID != "synthetic-announcement" || env.Data.Projection.ResetEvents[0].RowID != "codex" {
		t.Fatalf("events: %+v", env.Data.Projection.ResetEvents)
	}
	event := env.Data.Projection.ResetEvents[0]
	if event.Status != "announced" || event.Schedule == nil || event.Schedule.Precision != "deadline" || !event.Schedule.From.Equal(deadline) || !event.Schedule.Through.Equal(deadline) || !event.ExpiresAt.Equal(deadline) {
		t.Fatalf("point deadline changed: %+v", event)
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
	if cockpit["result"] == nil || !strings.Contains(string(cockpit["result"]), `"resetEvents"`) {
		t.Fatalf("negotiated cockpit missing reset events: %s", cockpit["error"])
	}
	detailsClient := startQueryBinaryCaps(t, binary, []string{"rows", "cockpit", "cockpitDetailsV1"})
	details := detailsClient.call("cockpit/query", map[string]any{})
	if details["result"] == nil || !strings.Contains(string(details["result"]), `"details"`) || !strings.Contains(string(details["result"]), `"synthetic-announcement"`) {
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
}

func containsCapability(caps []string, want string) bool {
	for _, cap := range caps {
		if cap == want {
			return true
		}
	}
	return false
}
