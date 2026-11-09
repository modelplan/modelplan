package quota

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"
)

const kiroSession = `{"sessionId":"s-1","modes":{"currentModeId":"kiro_default"},"models":{"currentModelId":"auto","availableModels":[{"modelId":"auto","name":"Auto"},{"modelId":"claude-sonnet-4.5","name":"Sonnet 4.5","description":"user@example.com"}]},"configOptions":[{"id":"model","options":[{"value":"claude-haiku-4.5"},{"value":"has space"},{"value":"a@b.c"}]},{"id":"mode","options":[{"value":"plan"}]}]}`

func kiroRead(t *testing.T, p Paths, now time.Time) *Account {
	t.Helper()
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "kiro", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	if err := RefreshNative(context.Background(), p, now); err != nil {
		t.Fatal(err)
	}
	r := Read(p, now)
	for i := range r.Accounts {
		if r.Accounts[i].Source == "native:kiro" {
			return &r.Accounts[i]
		}
	}
	t.Fatalf("no kiro account: %+v", r)
	return nil
}

func TestKiroReportedModelsOneThrowawaySession(t *testing.T) {
	isolateHome(t)
	bin, log := fakeKiroSession(t, kiroUsage, kiroSession)
	t.Setenv("MODELPLAN_KIRO", bin)
	p := nativePaths(t)
	now := time.Date(2026, 10, 31, 12, 0, 0, 0, time.UTC)
	a := kiroRead(t, p, now)
	if got := strings.Join(a.ReportedModels, ","); got != "auto,claude-haiku-4.5,claude-sonnet-4.5" {
		t.Fatalf("models = %q", got)
	}
	if len(a.Windows) != 2 {
		t.Fatalf("quota changed: %+v", a)
	}
	calls, _ := os.ReadFile(log)
	text := string(calls)
	if strings.Count(text, "session/new") != 1 || strings.Contains(text, "prompt") {
		t.Fatalf("calls = %s", text)
	}
	if strings.Contains(text, "getUsage\nsession") || !strings.Contains(text, "cwd: ") {
		t.Fatalf("calls = %s", text)
	}
	cwd := text[strings.Index(text, "cwd: ")+5:]
	cwd = strings.TrimSpace(strings.SplitN(cwd, "\n", 2)[0])
	if !strings.Contains(cwd, "modelplan-kiro-") {
		t.Errorf("session cwd %q is not the throwaway dir", cwd)
	}
	if _, err := os.Stat(cwd); err == nil {
		t.Errorf("throwaway dir %q was not removed", cwd)
	}
	// Within 24 h no second session; after 24 h one more.
	if err := RefreshNative(context.Background(), p, now.Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(log)
	if n := strings.Count(string(b), "session/new"); n != 1 {
		t.Fatalf("session/new after 1 h = %d", n)
	}
	if got := strings.Join(kiroReportedModels(context.Background(), p.Cache, now.Add(2*time.Hour)), ","); got != "auto,claude-haiku-4.5,claude-sonnet-4.5" {
		t.Fatalf("cached = %q", got)
	}
	_ = kiroReportedModels(context.Background(), p.Cache, now.Add(25*time.Hour))
	b, _ = os.ReadFile(log)
	if n := strings.Count(string(b), "session/new"); n != 2 {
		t.Fatalf("session/new after 25 h = %d", n)
	}
	cached, _ := os.ReadFile(kiroModelsPath(p.Cache))
	for _, bad := range []string{"s-1", "example.com", "Sonnet 4.5", "kiro_default"} {
		if strings.Contains(string(cached), bad) {
			t.Errorf("cache leaks %q: %s", bad, cached)
		}
	}
}

func TestKiroModelsTimeoutKeepsQuota(t *testing.T) {
	isolateHome(t)
	bin, _ := fakeKiro(t, kiroUsage) // never answers session/new
	t.Setenv("MODELPLAN_KIRO", bin)
	p := nativePaths(t)
	now := time.Date(2026, 10, 31, 12, 0, 0, 0, time.UTC)
	start := time.Now()
	a := kiroRead(t, p, now)
	if time.Since(start) > 5*time.Second {
		t.Errorf("took %v", time.Since(start))
	}
	if len(a.ReportedModels) != 0 || a.Plan != "KIRO PRO" || len(a.Windows) != 2 {
		t.Fatalf("account = %+v", a)
	}
	// The failed attempt still counts against the 24 h budget.
	if got := kiroReportedModels(context.Background(), p.Cache, now.Add(time.Hour)); got != nil {
		t.Fatalf("models = %v", got)
	}
}

func TestKiroModelsMalformedKeepsOldList(t *testing.T) {
	isolateHome(t)
	bin, _ := fakeKiroSession(t, kiroUsage, `"not an object"`)
	t.Setenv("MODELPLAN_KIRO", bin)
	p := nativePaths(t)
	now := time.Date(2026, 10, 31, 12, 0, 0, 0, time.UTC)
	if err := os.MkdirAll(p.Cache+"/observed", 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(kiroModelsPath(p.Cache), []byte(`{"attemptedAt":"2026-10-29T00:00:00Z","models":["auto"]}`), 0o600); err != nil {
		t.Fatal(err)
	}
	a := kiroRead(t, p, now)
	if strings.Join(a.ReportedModels, ",") != "auto" || len(a.Windows) != 2 {
		t.Fatalf("account = %+v", a)
	}
}

func TestParseKiroModelsHostile(t *testing.T) {
	for _, raw := range []string{``, `null`, `[]`, `{"models":{"availableModels":"x"}}`, `{"models":{"availableModels":[{"modelId":"../../etc"},{"modelId":"a b"}]}}`, `{"configOptions":[{"id":"mode","options":[{"value":"x"}]}]}`} {
		if got := parseKiroModels([]byte(raw)); got != nil {
			t.Errorf("%q -> %v", raw, got)
		}
	}
	if got := parseKiroModels([]byte(`{"models":{"availableModels":[{"modelId":"x"},{"modelId":"x"}]},"configOptions":[{"configId":"model","values":[{"value":"y"}]}]}`)); strings.Join(got, ",") != "x,y" {
		t.Errorf("got %v", got)
	}
}

func TestKiroModelsNoBinaryAndUsageFailure(t *testing.T) {
	isolateHome(t)
	bin, log := fakeKiroSession(t, `{"success":false,"message":"x"}`, kiroSession)
	t.Setenv("MODELPLAN_KIRO", bin)
	if e := collectKiro(context.Background(), nil, t.TempDir(), time.Now()); e.Status == "ok" || len(e.ReportedModels) != 0 {
		t.Fatalf("entry = %+v", e)
	}
	if b, _ := os.ReadFile(log); strings.Contains(string(b), "session/new") {
		t.Errorf("session opened after a failed usage read: %s", b)
	}
}
