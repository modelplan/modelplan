// SPDX-License-Identifier: MIT
package swiftwire

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver"
)

func TestChildEnvironmentContractMatchesSupervisor(t *testing.T) {
	expected := appserver.ChildEnvironmentKeys()
	if !sort.StringsAreSorted(expected) {
		t.Fatal("environment names must have stable order")
	}
	seen := map[string]bool{}
	var input []string
	for _, key := range expected {
		if key == "" || seen[key] {
			t.Fatal("empty/duplicate supervision key")
		}
		seen[key] = true
		input = append(input, key+"=synthetic")
	}
	input = append(input, "SECRET=synthetic", "KIMI_API_KEY=synthetic", "KIMI_AUTH_TOKEN=synthetic")
	var filtered []string
	for _, entry := range appserver.ChildEnvironment(input) {
		key, _, _ := strings.Cut(entry, "=")
		filtered = append(filtered, key)
	}
	if !reflect.DeepEqual(filtered, expected) {
		t.Fatal("published keys differ from actual Go child filtering")
	}
	generated, err := ChildEnvironmentContract()
	if err != nil {
		t.Fatal(err)
	}
	stored, err := os.ReadFile(filepath.Join(repoRoot(t), "schema/app-cli/child-environment.json"))
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(stored, generated) {
		t.Fatal("environment contract drift: run go run ./internal/swiftwire/cmd --write")
	}
	var contract struct {
		AllowedKeys []string `json:"allowedKeys"`
	}
	if err := json.Unmarshal(stored, &contract); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(contract.AllowedKeys, expected) {
		t.Fatal("schema environment set differs from Go supervision")
	}
	expected[0] = "MUTATED"
	if appserver.ChildEnvironmentKeys()[0] == "MUTATED" {
		t.Fatal("caller changed the canonical allow-list")
	}
}
