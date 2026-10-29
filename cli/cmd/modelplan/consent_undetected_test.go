// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func cacheRetiredCatalogue(t *testing.T) {
	t.Helper()
	f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		var data map[string]json.RawMessage
		if err := json.Unmarshal(doc["data"], &data); err != nil {
			t.Fatal(err)
		}
		data["detectorSchemaVersion"] = json.RawMessage("1")
		data["detectorRevision"] = json.RawMessage("4")
		data["detectors"] = json.RawMessage("[]")
		doc["data"] = publicationJSON(t, data)
	})
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	if err := st.PutObject(f.objectHash, f.object); err != nil {
		t.Fatal(err)
	}
	if err := st.PutManifest(f.id, f.manifest); err != nil {
		t.Fatal(err)
	}
	if err := st.SaveState(store.State{PublicationID: f.id, ManifestHash: publicationHash(f.manifest), Component: "client", ComponentHash: f.objectHash}); err != nil {
		t.Fatal(err)
	}
}

func TestConsentAPIPersistedUndetectedAndRetiredGrantsCanBeRevoked(t *testing.T) {
	for _, retired := range []bool{false, true} {
		name := "undetected"
		if retired {
			name = "retired"
		}
		t.Run(name, func(t *testing.T) {
			home := consentAPIHome(t)
			cacheConsentCatalogue(t, "native", "standard", "native:claude")
			grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude"}, nil, nil))
			if retired {
				cacheRetiredCatalogue(t)
			} else if err := os.RemoveAll(filepath.Join(home, ".claude")); err != nil {
				t.Fatal(err)
			}
			before := tree(t, home)
			view := readConsentAPI(t)
			row, exists := apiTools(view.Tools)["claude"]
			if !exists || row.Detected || !row.Allowed {
				t.Fatalf("persisted grant disappeared: %+v", view)
			}
			if !reflect.DeepEqual(before, tree(t, home)) {
				t.Fatal("listing undetected grants wrote files")
			}
			// A persisted grant still cannot be re-granted while undetected.
			consentBefore, err := os.ReadFile(consent.Path())
			if err != nil {
				t.Fatal(err)
			}
			code, out, stderr := consentRun([]string{"consent", "grant", "--json"}, apiRequest(t, 2, view.Generation, []string{"claude"}, nil, nil))
			if code == 0 || stderr != "" || !bytes.Contains([]byte(out), []byte(`"error": "unknown_tool"`)) {
				t.Fatalf("undetected grant admitted: %d %s %s", code, out, stderr)
			}
			consentAfter, _ := os.ReadFile(consent.Path())
			if !bytes.Equal(consentBefore, consentAfter) {
				t.Fatal("rejected grant mutated consent")
			}
			result := grantConsentAPI(t, apiRequest(t, 3, view.Generation, nil, []string{"claude"}, nil))
			row, exists = apiTools(result.Tools)["claude"]
			if !exists || row.Allowed || row.Detected {
				t.Fatalf("revocation readback=%+v", result)
			}
			stored, err := consent.Load(consent.Path())
			if err != nil || stored.Tools["claude"].Allowed {
				t.Fatalf("revocation not durable: %+v %v", stored, err)
			}
			if row, exists := apiTools(readConsentAPI(t).Tools)["claude"]; !exists || row.Allowed || row.Detected {
				t.Fatalf("revoked undetected record vanished: %+v", row)
			}
		})
	}
}

func TestConsentAPIRetiredUnknownToCurrentCatalogueCanBeRevoked(t *testing.T) {
	consentAPIHome(t)
	cacheRetiredCatalogue(t)
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		return consent.Set(s, "retired-tool", true, "native:retired-tool", "native", time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	view := readConsentAPI(t)
	row, exists := apiTools(view.Tools)["retired-tool"]
	if !exists || row.Detected || !row.Allowed || row.AccessClass != "not-read" {
		t.Fatalf("retired record missing or grantable: %+v", view)
	}
	result := grantConsentAPI(t, apiRequest(t, 1, view.Generation, nil, []string{"retired-tool"}, nil))
	if apiTools(result.Tools)["retired-tool"].Allowed {
		t.Fatal("retired grant not revoked")
	}
	code, out, _ := consentRun([]string{"consent", "grant", "--json"}, apiRequest(t, 2, result.Generation, []string{"never-known-tool"}, nil, nil))
	if code == 0 || !bytes.Contains([]byte(out), []byte(`"error": "unknown_tool"`)) {
		t.Fatal(code, out)
	}
}
