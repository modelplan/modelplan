// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestUnavailableBackendPublishesAuthoritativeConsentVersion(t *testing.T) {
	view, err := (UnavailableBackend{}).Get(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if view.Consent.TextVersion != consent.TextVersion {
		t.Fatalf("fallback text version = %d, want producer version %d", view.Consent.TextVersion, consent.TextVersion)
	}
	raw, err := json.Marshal(view.Consent)
	if err != nil {
		t.Fatal(err)
	}
	var emitted struct {
		TextVersion int                 `json:"consentTextVersion"`
		Scopes      []wire.ConsentScope `json:"scopes"`
	}
	if err := json.Unmarshal(raw, &emitted); err != nil {
		t.Fatal(err)
	}
	if emitted.TextVersion != consent.TextVersion || emitted.Scopes == nil || len(emitted.Scopes) != 0 {
		t.Fatalf("fallback facts lost version or empty scopes: %+v", emitted)
	}
	// Older consumers ignore the additive version field and retain their facts.
	var legacy struct {
		Scopes []wire.ConsentScope `json:"scopes"`
	}
	if err := json.Unmarshal(raw, &legacy); err != nil || legacy.Scopes == nil || len(legacy.Scopes) != 0 {
		t.Fatalf("legacy facts decoding failed: %+v, %v", legacy, err)
	}
	if view.Stamp.Epoch != "unavailable" || view.Health.State != wire.HealthDegraded {
		t.Fatal("publishing the text version must not make the fallback authoritative")
	}
}
