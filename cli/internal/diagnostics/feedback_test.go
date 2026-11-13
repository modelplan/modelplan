// SPDX-License-Identifier: MIT
package diagnostics

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func TestFeedbackVersionsRejectFreeText(t *testing.T) {
	for input, want := range map[string]string{
		"v0.5.42-rc.1": "0.5.42-rc.1", "0.1.0-dev": "0.1.0-dev", "1.2.3": "1.2.3",
		"1.2.3-person@example.invalid": "unknown", "1.2.3-secret-token": "unknown", "/Users/private/1.2.3": "unknown", "1.2.3\n": "unknown",
	} {
		if got := safeVersion(input); got != want {
			t.Errorf("version validation got %q, want %q", got, want)
		}
	}
	for input, want := range map[string]string{"12": "12", "14.7.1": "14.7.1", "10.0.26100": "10.0.26100", "14.0-private": "unknown", "/home/private": "unknown"} {
		if got := safeOSVersion(input); got != want {
			t.Errorf("OS version validation got %q, want %q", got, want)
		}
	}
}
func TestFeedbackBundleVersionReadsOnlyBoundedRegularPlist(t *testing.T) {
	dir := t.TempDir()
	file := filepath.Join(dir, "Info.plist")
	body := `<?xml version="1.0"?><plist><dict><key>private</key><string>person@example.invalid</string><key>CFBundleShortVersionString</key><string>1.2.3</string></dict></plist>`
	if err := os.WriteFile(file, []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	if got := safeVersion(bundleVersionFile(file)); got != "1.2.3" {
		t.Fatal("app version not read")
	}
	if err := os.WriteFile(file, []byte(strings.Repeat("x", (64<<10)+1)), 0600); err != nil {
		t.Fatal(err)
	}
	if bundleVersionFile(file) != "" {
		t.Fatal("oversized plist read")
	}
	link := filepath.Join(dir, "link.plist")
	if err := os.Symlink(file, link); err != nil {
		t.Skip(err)
	}
	if bundleVersionFile(link) != "" {
		t.Fatal("followed plist symlink")
	}
}
func TestFeedbackRecentCodesAreBoundedAndConsentScoped(t *testing.T) {
	dir := t.TempDir()
	now := time.Date(2026, 10, 30, 12, 0, 0, 0, time.UTC)
	at := func(d time.Duration) string { return now.Add(d).Format(time.RFC3339) }
	data := map[string]any{"schemaVersion": 1, "providers": []any{
		map[string]any{"provider": "kiro", "status": "error", "errorCode": "http_403", "observedAt": at(-time.Minute)},
		map[string]any{"provider": "kiro", "status": "error", "errorCode": "arbitrary vendor prose", "observedAt": at(-2 * time.Minute)},
		map[string]any{"provider": "kiro", "status": "error", "errorCode": "network", "observedAt": at(-8 * 24 * time.Hour)},
		map[string]any{"provider": "kiro", "status": "error", "errorCode": "timeout", "observedAt": at(time.Hour)},
		map[string]any{"provider": "gemini", "status": "error", "errorCode": "http_401", "observedAt": at(-time.Minute)},
	}}
	b, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	put(t, dir, "observed/native.json", string(b))
	put(t, dir, "observed/readers/kiro.json", `{"schemaVersion":1,"entries":[{"lastFailure":{"code":"parse_error","at":"`+at(-3*time.Minute)+`"},"profileKey":"synthetic-secret"}]}`)
	got := recentErrorCodes(dir, []string{consent.ScopeKiroRuntimeUsage}, now)
	if !reflect.DeepEqual(got, []string{"http_403", "other", "parse_error"}) {
		t.Fatalf("unexpected recent codes: %v", got)
	}
	for _, code := range got {
		if quota.ReaderErrorCode(code) != code {
			t.Fatal("non-code returned")
		}
	}
	if got := recentErrorCodes(dir, nil, now); len(got) != 0 {
		t.Fatal("unconsented reader error was returned")
	}
}
func TestFeedbackOffAndCorruptConsentFailClosed(t *testing.T) {
	testenv.IsolateHome(t)
	dir := t.TempDir()
	t.Setenv("MODELPLAN_READERS", "off")
	r := CollectFeedback(dir, "0.5.42", "1.2.3", time.Now())
	if r.ReaderMode != consent.Off || len(r.EnabledScopes) != 0 || len(r.RecentErrors) != 0 {
		t.Fatal("off mode admitted a reader")
	}
	t.Setenv("MODELPLAN_READERS", "")
	if err := os.MkdirAll(filepath.Dir(consent.Path()), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(consent.Path(), []byte(`{"password":"SYNTHETIC_SECRET"}`), 0600); err != nil {
		t.Fatal(err)
	}
	r = CollectFeedback(dir, "0.5.42", "1.2.3", time.Now())
	if r.ReaderMode != "unknown" || len(r.EnabledScopes) != 0 || len(r.RecentErrors) != 0 {
		t.Fatal("invalid consent did not fail closed")
	}
}

func TestFeedbackExcludesScopesPendingCleanup(t *testing.T) {
	state := consent.Empty()
	state.Requests = map[string]consent.Receipt{"synthetic": {PendingForget: []string{consent.ScopeCodexRuntimeUsage, "kiro"}}}
	scopes := enabledScopes(state, consent.Automatic)
	for _, scope := range scopes {
		if scope == consent.ScopeCodexRuntimeUsage || strings.HasPrefix(scope, "kiro.") {
			t.Fatalf("scope pending cleanup was included: %s", scope)
		}
	}
}

func TestFeedbackRecentCodesCapAndDeduplicate(t *testing.T) {
	dir := t.TempDir()
	now := time.Now().UTC().Truncate(time.Second)
	codes := []string{"policy_pending", "file_missing", "file_unreadable", "parse_error", "schema_changed", "http_401", "http_403", "http_429", "http_5xx", "network"}
	providers := []any{}
	for i, code := range append([]string{"policy_pending"}, codes...) {
		providers = append(providers, map[string]any{"provider": "kiro", "status": "error", "errorCode": code, "observedAt": now.Add(-time.Duration(i) * time.Minute)})
	}
	b, err := json.Marshal(map[string]any{"schemaVersion": 1, "providers": providers})
	if err != nil {
		t.Fatal(err)
	}
	put(t, dir, "observed/native.json", string(b))
	got := recentErrorCodes(dir, []string{consent.ScopeKiroRuntimeUsage}, now)
	if !reflect.DeepEqual(got, codes[:8]) {
		t.Fatalf("unexpected bounded codes: %v", got)
	}
}
