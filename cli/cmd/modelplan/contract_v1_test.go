// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/contracttest"
)

func TestDesktopContractV1CommandIsReadOnly(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	t.Setenv("MODELPLAN_CACHE", cache)
	t.Setenv("MODELPLAN_BASE", "http://127.0.0.1:1")
	beforeHome, beforeCache := tree(t, os.Getenv("HOME")), tree(t, cache)
	old := startDetached
	startDetached = func(...string) error { t.Fatal("read-only command spawned helper"); return nil }
	defer func() { startDetached = old }()
	var out, stderr bytes.Buffer
	code := run([]string{"desktop", "--json", "--read-only"}, nil, &out, &stderr)
	if code != 0 {
		t.Fatalf("exit %d: %s", code, stderr.String())
	}
	if err := contracttest.ValidateOutput("desktop", out.Bytes()); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(beforeHome, tree(t, os.Getenv("HOME"))) || !reflect.DeepEqual(beforeCache, tree(t, cache)) {
		t.Fatal("read-only contract check changed local files")
	}
}

func TestPublicationContractV1CommandMatchesGolden(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_CACHE", filepath.Join(t.TempDir(), "cache"))
	f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		var independent map[string]json.RawMessage
		if err := json.Unmarshal([]byte(contracttest.Client), &independent); err != nil {
			t.Fatal(err)
		}
		doc["data"] = independent["data"]
	})
	server, _ := publicationServer(t, &f)
	defer server.Close()
	t.Setenv("MODELPLAN_BASE", server.URL)
	code, out, stderr := publicationRun("--json")
	if code != 0 || stderr != "" {
		t.Fatalf("exit=%d stderr=%s", code, stderr)
	}
	if err := contracttest.ValidateOutput("publication", []byte(out)); err != nil {
		t.Fatal(err)
	}
	var got, want map[string]any
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatal(err)
	}
	golden, err := os.ReadFile("../../../testdata/contract-v1/F01-publication.json")
	if err != nil {
		t.Fatal(err)
	}
	if err = json.Unmarshal(golden, &want); err != nil {
		t.Fatal(err)
	}
	// Only verified envelope identity/time differ: server manifests have real hashes.
	got["publicationId"], got["publishedAt"] = want["publicationId"], want["publishedAt"]
	if !reflect.DeepEqual(got, want) {
		t.Fatal("actual publication command differs from frozen independent golden")
	}
}
