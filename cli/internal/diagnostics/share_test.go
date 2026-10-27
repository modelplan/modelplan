package diagnostics

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func put(t *testing.T, dir, name, body string) {
	t.Helper()
	p := filepath.Join(dir, name)
	if err := os.MkdirAll(filepath.Dir(p), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
}

func TestShareOnlyEmitsAllowlistedSourcesAndStatuses(t *testing.T) {
	t.Setenv("MODELPLAN_READERS", "passive")
	dir := t.TempDir()
	put(t, dir, "state.json", `{"publicationId":"private-value","base":"https://u:secret@example.invalid","lastError":"/Users/private/token"}`)
	put(t, dir, "observed/claude-code.json", `{"schemaVersion":1,"sessionKey":"secret","windows":[{"usedPercent":42}],"harness":{"model":"private-model"}}`)
	put(t, dir, "observed/native.json", `{"schemaVersion":1,"providers":[{"provider":"cursor","status":"error","error":"bearer secret /Users/private","subscriptionRef":"private-id"},{"provider":"zai","status":"secret"},{"provider":"private-provider","status":"ok"}]}`)
	put(t, dir, "observed/codexbar.json", `{"schemaVersion":9,"secret":"do not share"}`)
	r := Collect(dir, "0.5.40")
	b, err := json.Marshal(r)
	if err != nil {
		t.Fatal(err)
	}
	for _, private := range []string{"secret", "private", "42", "usedPercent", "sessionKey", dir, "https://"} {
		if strings.Contains(string(b), private) {
			t.Fatalf("private value %q in share report: %s", private, b)
		}
	}
	want := map[string]string{"claude-code": "cached", "codex-account": "missing", "native": "cached", "native:cursor": "error", "native:zai": "unknown", "codexbar": "unsupported_schema"}
	if len(r.Sources) != len(want) || r.Publication.Status != "cached" || r.ReaderMode != "passive" {
		t.Fatalf("unexpected report: %+v", r)
	}
	for _, source := range r.Sources {
		if source.Status != want[source.Source] {
			t.Fatalf("unexpected source/status: %+v", source)
		}
	}
}

func TestShareKeepsDistinctAccountStatesWithoutIdentities(t *testing.T) {
	dir := t.TempDir()
	put(t, dir, "observed/codex-account.json", `{"schemaVersion":1,"status":"expired_login","error":"private account"}`)
	put(t, dir, "observed/native.json", `{"schemaVersion":1,"providers":[{"provider":"cursor","status":"denied","alias":"work"},{"provider":"cursor","status":"expired_login","alias":"personal"},{"provider":"cursor","status":"denied","alias":"another"},{"provider":"zai","status":"pay_as_you_go"}]}`)
	var states []string
	for _, source := range Collect(dir, "0.5.40").Sources {
		if source.Source == "codex-account" && source.Status != "expired_login" {
			t.Fatalf("lost source failure state: %+v", source)
		}
		if source.Source == "native:cursor" {
			states = append(states, source.Status)
		}
	}
	if strings.Join(states, ",") != "denied,expired_login" {
		t.Fatalf("lost distinct account states: %v", states)
	}
	t.Setenv("MODELPLAN_READERS", "/private/untrusted")
	if Collect(dir, "0.5.40").ReaderMode != "unknown" {
		t.Fatal("arbitrary reader mode was not sanitised")
	}
}

func TestShareRejectsUnsafeOversizedAndInvalidCacheFiles(t *testing.T) {
	for _, tc := range []struct{ name, body, want string }{
		{"malformed", `{"secret":`, "invalid"},
		{"oversized", strings.Repeat("x", maxCacheBytes+1), "too_large"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			put(t, dir, "state.json", tc.body)
			if got := Collect(dir, "path/secret"); got.Publication.Status != tc.want || got.Version != "unknown" {
				t.Fatalf("unexpected report: %+v", got)
			}
		})
	}
	t.Run("symlink", func(t *testing.T) {
		dir := t.TempDir()
		secret := filepath.Join(t.TempDir(), "credential")
		if err := os.WriteFile(secret, []byte("private credential"), 0600); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(secret, filepath.Join(dir, "state.json")); err != nil {
			t.Skip(err)
		}
		if got := Collect(dir, "0.5.40"); got.Publication.Status != "unsafe_path" {
			t.Fatalf("followed cache symlink: %+v", got)
		}
	})
}
