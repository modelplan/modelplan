// SPDX-License-Identifier: MIT
package rows

import (
	"encoding/json"
	"testing"
)

func object(t *testing.T, value any) map[string]json.RawMessage {
	t.Helper()
	b, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	var result map[string]json.RawMessage
	if err := json.Unmarshal(b, &result); err != nil {
		t.Fatal(err)
	}
	return result
}

func TestNullableWireFieldsStayExplicit(t *testing.T) {
	account := Account{Plan: Plan{ID: "unknown"}, ValueState: ValueStateNone, Windows: []Window{}}
	a := object(t, account)
	for _, key := range []string{"subscriptionRef", "accountLocator", "credits", "observedAt", "freshUntil", "lastFailure"} {
		if string(a[key]) != "null" {
			t.Errorf("account.%s=%s, want explicit null", key, a[key])
		}
	}
	if string(a["plan"]) != `{"id":"unknown"}` {
		t.Fatalf("unknown plan leaked a name: %s", a["plan"])
	}
	row := Row{ID: "codex", Kind: KindTool, Name: Name{EN: "Codex", ZH: "Codex"}, Surfaces: []Surface{SurfaceDock, SurfaceMenu, SurfaceSettings}, Consent: ConsentAllowed, State: StatePending, Accounts: []Account{account}}
	r := object(t, row)
	for _, key := range []string{"vendorKey", "nextStep", "expiresAt", "stateAfterExpiry"} {
		if string(r[key]) != "null" {
			t.Errorf("row.%s=%s, want explicit null", key, r[key])
		}
	}
	if string(object(t, Window{})["durationSeconds"]) != "null" {
		t.Fatal("unknown duration must stay nullable")
	}
	step := object(t, NextStep{Action: ActionNone})
	if _, ok := step["availableAt"]; ok {
		t.Fatal("absent optional action time must be omitted")
	}
	if _, ok := step["disabledReason"]; ok {
		t.Fatal("absent optional disabled reason must be omitted")
	}
}

func TestAuthoredNameAndNonrecursiveExpiryShape(t *testing.T) {
	name := Name{EN: "my-plan", ZH: "my-plan", UserAuthored: true}
	if string(object(t, name)["userAuthored"]) != "true" {
		t.Fatal("declared text lost authorship")
	}
	if _, ok := object(t, Name{EN: "Codex", ZH: "Codex"})["userAuthored"]; ok {
		t.Fatal("compiled name acquired authorship")
	}
	expiry := object(t, ExpiryState{State: StateStale, Reason: Reason{Code: CodeStaleReading}})
	if len(expiry) != 3 {
		t.Fatalf("expiry latch is not the three-field state: %v", expiry)
	}
	for _, key := range []string{"state", "reason", "nextStep"} {
		if _, ok := expiry[key]; !ok {
			t.Errorf("expiry missing %s", key)
		}
	}
}

func TestInputCannotBePublishedAsRows(t *testing.T) {
	canary := "private_account_token_123@example.test"
	input := Input{
		Catalogue: []CatalogueEntry{{ToolID: canary}},
		Profiles:  []ProfileState{{ProfileKey: canary}},
		Accounts:  []AccountInput{{Source: canary, Windows: []WindowInput{{Limit: canary, Pool: canary}}}},
		Sources:   []SourceState{{Reason: canary}},
	}
	b, err := json.Marshal(input)
	if err != nil {
		t.Fatal(err)
	}
	if string(b) != "{}" {
		t.Fatalf("raw projection inputs were serializable: %s", b)
	}
}

func TestAccountRouteIsRequiredAndBounded(t *testing.T) {
	for _, route := range []string{"saved_login_api", "runtime_rpc", "local_log", "api_key_api", "local_sqlite", "status_line", "browser_session", "manual", "unknown", "", "private_token@example.test"} {
		in := sampleInput()
		in.Accounts[0].Route = Route(route)
		out := Build(in)
		account := object(t, out.Rows[0].Accounts[0])
		want := route
		if route == "" || route == "private_token@example.test" {
			want = "unknown"
		}
		if string(account["route"]) != `"`+want+`"` {
			t.Fatalf("route %q: got %s, want %q", route, account["route"], want)
		}
	}
}
