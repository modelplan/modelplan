package detect

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const fixture = `{"detectorSchemaVersion":1,"detectorRevision":3,"detectors":[{"providerId":"claude","displayName":"Claude Code","readerId":"native:claude-code","preferred":"native","codexbar":{"audited":false},"minCli":"0.1.0","beta":true,"detectionStatus":"signals","signals":[{"type":"path","value":".claude"}]}]}`

func catalogue(t *testing.T, signals string) *Catalogue {
	t.Helper()
	c, err := ParseData([]byte(strings.Replace(fixture, `[{"type":"path","value":".claude"}]`, signals, 1)))
	if err != nil {
		t.Fatal(err)
	}
	return c
}
func TestPresenceOnlyAndUnknownSignals(t *testing.T) {
	home := t.TempDir()
	bin := filepath.Join(home, "bin")
	os.MkdirAll(bin, 0700)
	// This executable must never run, and the credential-like file cannot be read.
	marker := filepath.Join(home, "executed")
	os.WriteFile(filepath.Join(bin, "synthetic-cli"), []byte("#!/bin/sh\ntouch "+marker+"\nexit 1\n"), 0700)
	os.Mkdir(filepath.Join(home, ".claude"), 0700)
	os.WriteFile(filepath.Join(home, ".claude", ".credentials.json"), []byte("synthetic secret"), 0000)
	e := Env{Home: home, Path: bin, OS: "darwin"}
	for _, signals := range []string{`[{"type":"path","value":".claude/.credentials.json"}]`, `[{"type":"command","name":"synthetic-cli"}]`, `[{"type":"future","payload":{"any":true}},{"type":"path","value":".claude"}]`} {
		r := Run(catalogue(t, signals), e, "0.6.0", "fixture")
		if !r.Tools[0].Detected {
			t.Fatalf("not detected: %+v", r)
		}
		b, _ := json.Marshal(r)
		if strings.Contains(string(b), home) || strings.Contains(string(b), "synthetic secret") {
			t.Fatal("private evidence leaked")
		}
	}
	if _, err := os.Stat(marker); !os.IsNotExist(err) {
		t.Fatal("executed tool")
	}
	for _, signals := range []string{`[{"type":"future","payload":{"any":true}}]`, `[{"type":"keychainItem","rule":"future-rule","name":{"future":true}}]`} {
		r := Run(catalogue(t, signals), e, "0.6.0", "fixture")
		if r.Tools[0].Detected || r.Tools[0].Status != "not-detected" {
			t.Fatal(r)
		}
	}
}
func TestPathRejectionAndSymlinkEscape(t *testing.T) {
	for _, path := range []string{"/etc/passwd", ".claude/../.ssh", ".claude/$TOKEN", ".claude/*", ".ssh/id_rsa", ".config/../.ssh", ".claude\\secret"} {
		b, _ := json.Marshal(path)
		_, err := ParseData([]byte(strings.Replace(fixture, `".claude"`, string(b), 1)))
		if err == nil {
			t.Errorf("accepted %s", path)
		}
	}
	home, outside := t.TempDir(), t.TempDir()
	os.Symlink(outside, filepath.Join(home, ".claude"))
	r := Run(catalogue(t, `[{"type":"path","value":".claude"}]`), Env{Home: home}, "1.0.0", "test")
	if r.Tools[0].Detected || r.Tools[0].Status != "unknown" {
		t.Fatal(r)
	}
}
func TestSilentAdaptersAndMinimumVersion(t *testing.T) {
	c := catalogue(t, `[{"type":"keychainItem","rule":"claude-config-dir"},{"type":"bundleId","value":"com.test.App"}]`)
	e := Env{Home: t.TempDir(), OS: "darwin"}
	if r := Run(c, e, "1.0.0", "test"); r.Tools[0].Status != "unknown" {
		t.Fatal(r)
	}
	calls := 0
	e.KeychainPresent = func(s Signal) string {
		calls++
		if s.Rule != "claude-config-dir" {
			t.Fatal(s)
		}
		return "unknown"
	}
	e.BundlePresent = func(id string) string { calls++; return "present" }
	if r := Run(c, e, "0.0.1", "test"); r.Tools[0].Status != "update-required" || calls != 0 {
		t.Fatal(r, calls)
	}
	if r := Run(c, e, "1.0.0", "test"); !r.Tools[0].Detected || calls != 2 {
		t.Fatal(r, calls)
	}
}
func TestCatalogueBoundsAndNoFalseDefault(t *testing.T) {
	for _, b := range []string{strings.Replace(fixture, `"native"`, `"shell"`, 1), strings.Replace(fixture, `"detectorRevision":3`, `"detectorRevision":0`, 1), strings.Replace(fixture, `"minCli":"0.1.0"`, `"minCli":"latest"`, 1), strings.Replace(fixture, `"name":"claude"`, `"name":"claude"`, 0) + "garbage"} {
		if _, err := ParseData([]byte(b)); err == nil {
			t.Fatal("accepted invalid catalogue")
		}
	}
	c := catalogue(t, `[{"type":"future"}]`)
	for _, count := range []int{17, 513} {
		oversized := *c
		if count == 17 {
			oversized.Detectors = append([]Entry(nil), c.Detectors...)
			oversized.Detectors[0].Signals = make([]json.RawMessage, count)
			for i := range oversized.Detectors[0].Signals {
				oversized.Detectors[0].Signals[i] = json.RawMessage(`{"type":"future"}`)
			}
		} else {
			oversized.Detectors = make([]Entry, count)
		}
		b, _ := json.Marshal(oversized)
		if _, err := ParseData(b); err == nil {
			t.Fatalf("accepted %d signals/entries", count)
		}
	}
	large := strings.Replace(fixture, `".claude"`, `".claude/`+strings.Repeat("x", 256<<10)+`"`, 1)
	if _, err := ParseData([]byte(large)); err == nil {
		t.Fatal("accepted oversized catalogue")
	}
	c.Detectors = append(c.Detectors, c.Detectors[0])
	b, _ := json.Marshal(c)
	if _, err := ParseData(b); err == nil {
		t.Fatal("duplicate IDs accepted")
	}
	c = Fallback()
	for i := range c.Detectors {
		c.Detectors[i].Signals = []json.RawMessage{json.RawMessage(`{"type":"future"}`)}
	}
	r := Run(c, Env{Home: t.TempDir()}, "1.0.0", "test")
	for _, tool := range r.Tools {
		if tool.Detected {
			t.Fatal("false default", tool)
		}
	}
	for _, v := range []struct {
		current, minimum string
		want             bool
	}{{"1.10.0", "1.9.0", true}, {"1.0.0-dev", "1.0.0", false}, {"1.0.0+build", "1.0.0", true}, {"0.9.0", "1.0.0", false}} {
		if Compatible(v.current, v.minimum) != v.want {
			t.Fatal(v)
		}
	}
}
