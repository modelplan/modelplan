package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func TestDetectHasNoNetworkCommandsOrWrites(t *testing.T) {
	isolateHome(t)
	home := os.Getenv("HOME")
	cache := filepath.Join(home, "not-created")
	t.Setenv("MODELPLAN_CACHE", cache)
	t.Setenv("PATH", filepath.Join(home, "bin"))
	os.Mkdir(filepath.Join(home, ".claude"), 0700)
	oldVersion := version
	version = "1.0.0"
	t.Cleanup(func() { version = oldVersion })
	oldStart := startDetached
	startDetached = func(...string) error { t.Fatal("started background command"); return nil }
	t.Cleanup(func() { startDetached = oldStart })
	var out, errOut bytes.Buffer
	code := run([]string{"detect", "--json", "--base", "invalid-and-never-used"}, strings.NewReader(""), &out, &errOut)
	if code != 0 {
		t.Fatal(code, errOut.String())
	}
	var r detect.Report
	if err := json.Unmarshal(out.Bytes(), &r); err != nil {
		t.Fatal(err)
	}
	if r.CatalogueSource != "built-in" || !r.Tools[0].Detected {
		t.Fatal(out.String())
	}
	if _, err := os.Stat(cache); !os.IsNotExist(err) {
		t.Fatal("detect wrote cache")
	}
	if strings.Contains(out.String(), home) {
		t.Fatal("home leaked")
	}
}

func TestDetectUsesVerifiedCatalogueAndRejectsInvalidReplacement(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	t.Setenv("MODELPLAN_CACHE", cache)
	t.Setenv("PATH", t.TempDir())
	oldVersion := version
	version = "1.0.0"
	t.Cleanup(func() { version = oldVersion })
	f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		var data map[string]json.RawMessage
		json.Unmarshal(doc["data"], &data)
		data["detectorSchemaVersion"] = json.RawMessage("1")
		data["detectorRevision"] = json.RawMessage("9")
		data["detectors"] = json.RawMessage(`[{"providerId":"fixture","displayName":"Fixture","readerId":"native:fixture","preferred":"native","minCli":"0.1.0","beta":true,"detectionStatus":"signals","signals":[{"type":"future-rule"}]}]`)
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
	invalid := bytes.Replace(f.object, []byte(`"preferred":"native"`), []byte(`"preferred":"shell"`), 1)
	if _, err := digest.Parse("client", invalid); err == nil {
		t.Fatal("invalid replacement admitted")
	}

	var out, errOut bytes.Buffer
	if code := run([]string{"detect", "--json"}, nil, &out, &errOut); code != 0 {
		t.Fatal(code, errOut.String())
	}
	if !strings.Contains(out.String(), `"catalogueRevision": 9`) || !strings.Contains(out.String(), `"catalogueSource": "publication"`) {
		t.Fatal(out.String())
	}
}
