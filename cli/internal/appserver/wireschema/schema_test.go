// SPDX-License-Identifier: MIT
package wireschema_test

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/appserver/wireschema"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/santhosh-tekuri/jsonschema/v6"
)

func schema(t *testing.T, name string) *jsonschema.Schema {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	root := filepath.Clean(filepath.Join(filepath.Dir(file), "../../../.."))
	generated, err := wireschema.Generate(root)
	if err != nil {
		t.Fatal(err)
	}
	checked, err := os.ReadFile(filepath.Join(root, "schema/app-cli/app-server.json"))
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(generated, checked) {
		t.Fatal("schema drift: regenerate from Go DTOs")
	}
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(generated))
	if err != nil {
		t.Fatal(err)
	}
	c := jsonschema.NewCompiler()
	c.AssertFormat()
	const id = "https://modelplan.ai/schema/app-cli/app-server.json"
	if err := c.AddResource(id, doc); err != nil {
		t.Fatal(err)
	}
	s, err := c.Compile(id + "#/$defs/" + name)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func validate(t *testing.T, s *jsonschema.Schema, value any) error {
	t.Helper()
	b, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(b))
	if err != nil {
		t.Fatal(err)
	}
	return s.Validate(doc)
}

func TestProductionEncodingsAndContractMutations(t *testing.T) {
	// Go encodes the real DTO, then the schema validates it and a concrete wire
	// decoder consumes it. This is an interface fixture, not claimed CLI stdout.
	p := rows.Build(rows.Input{Now: time.Now(), ConsentGeneration: 7, DeclaredPlanIDs: []string{"team"}})
	message := wire.Success[wire.RowsSnapshot]{JSONRPC: wire.JSONRPC, ID: json.RawMessage(`7`), Result: wire.Envelope[wire.RowsSnapshot]{SessionID: "s-test", StoreEpoch: "e-test", ConsentGeneration: 7, Scopes: []string{"codex.runtime_usage"}, Data: wire.RowsSnapshot{Sequence: 1, Projection: p}}}
	s := schema(t, "Response")
	if err := validate(t, s, message); err != nil {
		t.Fatal(err)
	}
	b, _ := json.Marshal(message)
	var decoded wire.Success[wire.RowsSnapshot]
	if err := json.Unmarshal(b, &decoded); err != nil {
		t.Fatal(err)
	}
	if decoded.Result.Data.Projection.Rows[0].ID != "declared:team" {
		t.Fatal("production DTO decoder lost rows")
	}
	for _, mutate := range []struct {
		name string
		edit func(map[string]any)
	}{
		{"missing session", func(m map[string]any) { delete(m["result"].(map[string]any), "sessionId") }},
		{"generation type", func(m map[string]any) { m["result"].(map[string]any)["consentGeneration"] = "7" }},
		{"result and error", func(m map[string]any) { m["error"] = map[string]any{"code": -32099} }},
		{"private token on result", func(m map[string]any) { m["result"].(map[string]any)["accessToken"] = "token-canary" }},
		{"recursive expiry", func(m map[string]any) {
			env := m["result"].(map[string]any)
			data := env["data"].(map[string]any)
			projection := data["projection"].(map[string]any)
			r := projection["rows"].([]any)[0].(map[string]any)
			r["stateAfterExpiry"] = map[string]any{"rows": []any{}}
		}},
	} {
		t.Run(mutate.name, func(t *testing.T) {
			var m map[string]any
			_ = json.Unmarshal(b, &m)
			mutate.edit(m)
			if err := validate(t, s, m); err == nil {
				t.Fatal("contract mutation accepted")
			}
		})
	}
}

func TestNullableHistoryAndTokenOnlyCredentialResult(t *testing.T) {
	page := wire.HistoryPage{Items: []wire.HistoryItem{{At: time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC)}}}
	if err := validate(t, schema(t, "HistoryPage"), page); err != nil {
		t.Fatal(err)
	}
	b, _ := json.Marshal(page)
	if !bytes.Contains(b, []byte(`"model":null`)) || !bytes.Contains(b, []byte(`"tokens":null`)) {
		t.Fatal("nullable history fields disappeared")
	}
	s := schema(t, "CredentialResult")
	token := "synthetic-access-token"
	ok := wire.CredentialResult{OperationID: "op-1", Outcome: wire.OutcomeOK, AccessToken: &token}
	if err := validate(t, s, ok); err != nil {
		t.Fatal(err)
	}
	for _, outcome := range []wire.CredentialOutcome{wire.OutcomeCanceled, wire.OutcomeDenied, wire.OutcomeNotFound, wire.OutcomeInteractionRequired, wire.OutcomeTimeout, wire.OutcomeError} {
		result := wire.CredentialResult{OperationID: "op-1", Outcome: outcome}
		if err := validate(t, s, result); err != nil {
			t.Fatal(err)
		}
		result.AccessToken = &token
		if err := validate(t, s, result); err == nil {
			t.Fatal("token accepted on non-success")
		}
	}
	ok.AccessToken = nil
	if err := validate(t, s, ok); err == nil {
		t.Fatal("success without token accepted")
	}
}

func TestConsentReceiptAndScopeNullability(t *testing.T) {
	gen := uint64(42)
	receipt := wire.ConsentReceipt{RequestID: "retry-1", Committed: true, CommittedGeneration: &gen, CleanupPending: []string{"claude.account_usage.saved_login"}, Code: wire.ReceiptCleanupPending}
	if err := validate(t, schema(t, "ConsentReceipt"), receipt); err != nil {
		t.Fatal(err)
	}
	facts := wire.ConsentFacts{Scopes: []wire.ConsentScope{{Scope: "codex.runtime_usage", Tool: "codex", Route: rows.RouteRuntimeRPC, State: wire.ConsentUnset}}}
	if err := validate(t, schema(t, "ConsentFacts"), facts); err != nil {
		t.Fatal(err)
	}
	request := wire.ConsentGrantParams{RequestID: "r", ExpectStoreEpoch: "e", Allow: []string{}, Deny: []string{}, Keychain: map[string]wire.KeychainChoice{"claude.account_usage.saved_login": wire.KeychainUnset}}
	if err := validate(t, schema(t, "ConsentGrantParams"), request); err == nil {
		t.Fatal("unset is a fact, not a grant choice")
	}
}
