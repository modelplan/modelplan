// SPDX-License-Identifier: MIT
package rows

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"testing"
)

func TestModelScopeWireFixtureAndSafety(t *testing.T) {
	in := sampleInput()
	general := in.Accounts[0].Windows[0]
	model := general
	model.ModelIDs = []string{"opus"}
	secret := general
	secret.ModelIDs = []string{"account_token_123"}
	in.Accounts[0].Windows = []WindowInput{model, general, secret}
	got := Build(in)
	if err := Validate(in, got); err != nil {
		t.Fatal(err)
	}
	ws := rowByID(t, got, "codex").Accounts[0].Windows
	if len(ws) != 2 || ws[0].ModelScope != nil || ws[1].ModelScope == nil || !reflect.DeepEqual(ws[1].ModelScope.Models, []string{"opus"}) {
		t.Fatalf("general / model / withheld: %+v", ws)
	}
	reversed := in
	reversed.Accounts = append([]AccountInput(nil), in.Accounts...)
	reversed.Accounts[0].Windows = []WindowInput{secret, general, model}
	if !reflect.DeepEqual(got, Build(reversed)) {
		t.Fatal("scope collision ordering depends on provider input order")
	}
	broken := got
	broken.Rows = append([]Row(nil), got.Rows...)
	broken.Rows[0].Accounts = append([]Account(nil), got.Rows[0].Accounts...)
	broken.Rows[0].Accounts[0].Windows = append([]Window(nil), ws...)
	broken.Rows[0].Accounts[0].Windows[1].ModelScope = &ModelScope{Models: []string{"sonnet"}}
	if err := Validate(in, broken); err == nil {
		t.Fatal("invented scope accepted")
	}
	data, err := json.MarshalIndent(got, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	data = append(data, '\n')
	_, file, _, _ := runtime.Caller(0)
	path := filepath.Join(filepath.Dir(file), "../../..", "schema/app-cli/captures/rows-model-scope.json")
	if os.Getenv("UPDATE_MODEL_SCOPE_FIXTURE") == "1" {
		if err := os.WriteFile(path, data, 0644); err != nil {
			t.Fatal(err)
		}
	}
	stored, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(data, stored) {
		t.Fatal("model scope fixture drift")
	}
}
