package main

import (
	"archive/tar"
	"archive/zip"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func updateArchive(t *testing.T) []byte {
	t.Helper()
	name := "modelplan_" + runtime.GOOS + "_" + runtime.GOARCH + "/modelplan"
	body := []byte("verified CLI update fixture")
	var archive bytes.Buffer
	if runtime.GOOS == "windows" {
		w := zip.NewWriter(&archive)
		f, err := w.Create(name + ".exe")
		if err != nil {
			t.Fatal(err)
		}
		if _, err := f.Write(body); err != nil {
			t.Fatal(err)
		}
		if err := w.Close(); err != nil {
			t.Fatal(err)
		}
	} else {
		gz := gzip.NewWriter(&archive)
		w := tar.NewWriter(gz)
		if err := w.WriteHeader(&tar.Header{Name: name, Typeflag: tar.TypeReg, Mode: 0755, Size: int64(len(body))}); err != nil {
			t.Fatal(err)
		}
		if _, err := w.Write(body); err != nil {
			t.Fatal(err)
		}
		if err := w.Close(); err != nil {
			t.Fatal(err)
		}
		if err := gz.Close(); err != nil {
			t.Fatal(err)
		}
	}
	return archive.Bytes()
}

func TestUpdateConsumesOnlyVerifiedPublicationPin(t *testing.T) {
	for _, kind := range []string{"valid", "missing-pin", "bad-component", "bad-checksum"} {
		t.Run(kind, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_CACHE", filepath.Join(t.TempDir(), "cache"))
			archive := updateArchive(t)
			sum := sha256.Sum256(archive)
			checksum := hex.EncodeToString(sum[:])
			if kind == "bad-checksum" {
				checksum = strings.Repeat("0", 64)
			}
			f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
				if kind != "missing-pin" {
					var data map[string]json.RawMessage
					if err := json.Unmarshal(doc["data"], &data); err != nil {
						t.Fatal(err)
					}
					data["cli"] = publicationJSON(t, map[string]any{"latest": "9.9.9", "sha256": map[string]string{runtime.GOOS + "/" + runtime.GOARCH: checksum}})
					doc["data"] = publicationJSON(t, data)
				}
			})
			if kind == "bad-component" {
				f.object = []byte(`{"unverified":true}`)
			}
			srv, _ := publicationServer(t, &f)
			t.Setenv("MODELPLAN_BASE", srv.URL)
			exe := filepath.Join(t.TempDir(), "modelplan")
			if err := os.WriteFile(exe, []byte("previous CLI fixture"), 0700); err != nil {
				t.Fatal(err)
			}
			oldExecutable, oldFetch := updateExecutable, fetchCLIUpdate
			t.Cleanup(func() { updateExecutable, fetchCLIUpdate = oldExecutable, oldFetch })
			updateExecutable = func() (string, error) { return exe, nil }
			calls := 0
			fetchCLIUpdate = func(context.Context, string) (io.ReadCloser, error) {
				calls++
				return io.NopCloser(bytes.NewReader(archive)), nil
			}
			var out, stderr bytes.Buffer
			code := run([]string{"update", "--json"}, nil, &out, &stderr)
			b, err := os.ReadFile(exe)
			if err != nil {
				t.Fatal(err)
			}
			if kind == "valid" {
				if code != 0 || !json.Valid(out.Bytes()) || calls != 1 || string(b) != "verified CLI update fixture" {
					t.Fatalf("update: exit=%d calls=%d out=%s stderr=%s binary=%q", code, calls, out.String(), stderr.String(), b)
				}
			} else {
				wantCalls := 0
				if kind == "bad-checksum" {
					wantCalls = 1
				}
				if code == 0 || calls != wantCalls || string(b) != "previous CLI fixture" {
					t.Fatalf("invalid update changed executable: exit=%d calls=%d stderr=%s binary=%q", code, calls, stderr.String(), b)
				}
			}
		})
	}
}

func TestManagedUpdateIsRefusedBeforeCacheOrNetwork(t *testing.T) {
	isolateHome(t)
	cache := filepath.Join(t.TempDir(), "absent-cache")
	t.Setenv("MODELPLAN_CACHE", cache)
	old := updateExecutable
	t.Cleanup(func() { updateExecutable = old })
	updateExecutable = func() (string, error) {
		return filepath.Join(os.Getenv("HOME"), "ModelPlan.app/Contents/MacOS/modelplan"), nil
	}
	var out, stderr bytes.Buffer
	if code := run([]string{"update"}, nil, &out, &stderr); code != exitErr || !strings.Contains(stderr.String(), "managed") {
		t.Fatalf("managed update: exit=%d stderr=%s", code, stderr.String())
	}
	if _, err := os.Stat(cache); !os.IsNotExist(err) {
		t.Fatalf("managed update touched cache: %v", err)
	}
}
