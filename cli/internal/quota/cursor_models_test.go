package quota

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func grantCursorModels(t *testing.T) {
	t.Helper()
	initial, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	grant := consent.Grant{RequestID: "d102-synthetic", ExpectStoreEpoch: initial.StoreEpoch, ExpectGeneration: initial.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeCursorRuntimeModels}, Deny: []string{}}
	if _, err := consent.ApplyGrant(consent.Path(), grant, consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) {
		return consent.Record{ReaderID: "native:cursor", Backend: "native"}, nil
	}, Cleanup: func(string, bool) error { return nil }}); err != nil {
		t.Fatal(err)
	}
}

// fakeCursorAgent writes a script that logs its argv, environment keys and working directory, then runs body.
func fakeCursorAgent(t *testing.T, body string) (bin, log string) {
	old := cursorModelsTimeout
	cursorModelsTimeout = 500 * time.Millisecond
	t.Cleanup(func() { cursorModelsTimeout = old })
	dir := t.TempDir()
	bin, log = filepath.Join(dir, "cursor-agent"), filepath.Join(dir, "calls")
	script := "#!/bin/sh\necho \"args: $*\" >> \"" + log + "\"\nenv | cut -d= -f1 | sort | tr '\\n' ' ' >> \"" + log + "\"\n" + body + "\n"
	if err := os.WriteFile(bin, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_CURSOR_AGENT", bin)
	return bin, log
}

const cursorModelsOut = "\x1b[2mLoading models…\x1b[0m\nAvailable models\n\nauto - Auto (current)\ncomposer-1 - Composer 1\nsonnet-4.5-thinking - Claude 4.5 Sonnet (thinking)\ngpt-5\nTip: use --model <id> to select\n"

func TestCursorModelsOffByDefaultStartsNothing(t *testing.T) {
	isolateHome(t)
	_, log := fakeCursorAgent(t, "printf '%s' '"+cursorModelsOut+"'")
	p := nativePaths(t)
	if got := cursorReportedModels(context.Background(), p, "acct", time.Now()); got != nil {
		t.Fatalf("models = %v", got)
	}
	if _, err := os.Stat(log); err == nil {
		t.Fatal("cursor-agent was started without consent")
	}
	if _, err := os.Stat(cursorModelsPath(p.Cache)); err == nil {
		t.Fatal("cache written without consent")
	}
}

func TestCursorModelsOptInReadsIdsOnlyAndCaches(t *testing.T) {
	isolateHome(t)
	t.Setenv("CURSOR_API_KEY", "secret-token")
	_, log := fakeCursorAgent(t, "printf '%s' '"+cursorModelsOut+"'")
	grantCursorModels(t)
	p := nativePaths(t)
	now := time.Date(2026, 11, 9, 12, 0, 0, 0, time.UTC)
	got := strings.Join(cursorReportedModels(context.Background(), p, "acct", now), ",")
	if got != "auto,composer-1,gpt-5,sonnet-4.5-thinking" {
		t.Fatalf("models = %q", got)
	}
	b, _ := os.ReadFile(log)
	text := string(b)
	if !strings.HasPrefix(text, "args: models\n") {
		t.Fatalf("argv = %q", text)
	}
	if strings.Contains(text, "CURSOR_API_KEY") {
		t.Errorf("environment was not minimised: %s", text)
	}
	// Fresh cache: no second process; manual-looking repeat inside 24 h too.
	_ = cursorReportedModels(context.Background(), p, "acct", now.Add(23*time.Hour))
	b, _ = os.ReadFile(log)
	if n := strings.Count(string(b), "args: models"); n != 1 {
		t.Fatalf("runs within 24 h = %d", n)
	}
	// A different sign-in never sees the old list and triggers a read.
	_ = cursorReportedModels(context.Background(), p, "other", now.Add(time.Hour))
	b, _ = os.ReadFile(log)
	if n := strings.Count(string(b), "args: models"); n != 2 {
		t.Fatalf("runs after sign-in change = %d", n)
	}
	_ = cursorReportedModels(context.Background(), p, "other", now.Add(26*time.Hour))
	b, _ = os.ReadFile(log)
	if n := strings.Count(string(b), "args: models"); n != 3 {
		t.Fatalf("runs after 24 h = %d", n)
	}
	cached, _ := os.ReadFile(cursorModelsPath(p.Cache))
	for _, bad := range []string{"Claude 4.5", "Composer 1", "Tip", "secret-token"} {
		if strings.Contains(string(cached), bad) {
			t.Errorf("cache leaks %q: %s", bad, cached)
		}
	}
}

func TestCursorModelsFailuresKeepOldList(t *testing.T) {
	grantedRun := func(t *testing.T, body string) []string {
		isolateHome(t)
		fakeCursorAgent(t, body)
		grantCursorModels(t)
		p := nativePaths(t)
		_ = os.MkdirAll(filepath.Dir(cursorModelsPath(p.Cache)), 0o700)
		_ = os.WriteFile(cursorModelsPath(p.Cache), []byte(`{"attemptedAt":"2026-11-01T00:00:00Z","accountKey":"acct","models":["auto"]}`), 0o600)
		start := time.Now()
		got := cursorReportedModels(context.Background(), p, "acct", time.Date(2026, 11, 9, 0, 0, 0, 0, time.UTC))
		if time.Since(start) > 5*time.Second {
			t.Errorf("took %v", time.Since(start))
		}
		return got
	}
	for name, body := range map[string]string{
		"timeout":   "sleep 30",
		"malformed": "printf '\\000\\001{{{ <html>error</html>'",
		"exit":      "echo 'auto - Auto'; exit 3",
		"oversize":  "head -c 200000 /dev/zero | tr '\\0' 'a'",
	} {
		t.Run(name, func(t *testing.T) {
			if got := strings.Join(grantedRun(t, body), ","); got != "auto" {
				t.Fatalf("models = %q", got)
			}
		})
	}
}

func TestCursorModelsBinaryMissingOrRelative(t *testing.T) {
	isolateHome(t)
	grantCursorModels(t)
	p := nativePaths(t)
	t.Setenv("MODELPLAN_CURSOR_AGENT", "cursor-agent") // relative: refused
	if got := cursorReportedModels(context.Background(), p, "acct", time.Now()); got != nil {
		t.Fatalf("models = %v", got)
	}
	t.Setenv("MODELPLAN_CURSOR_AGENT", filepath.Join(t.TempDir(), "absent"))
	if got := cursorReportedModels(context.Background(), p, "acct", time.Now().Add(48*time.Hour)); got != nil {
		t.Fatalf("models = %v", got)
	}
}

func TestParseCursorModelsStrict(t *testing.T) {
	cases := map[string]string{
		"":                                     "",
		"auto\nauto\nGPT-5\nbad id\n$(rm -rf)": "auto",
		"auto - Auto\n* composer-1 - x\nuser@example.com": "auto,composer-1",
		`["a","b",{"id":"c"}]`:                            "a,b,c",
		`{"models":[{"id":"x"}]}`:                         "x",
		`{"error":"nope"}`:                                "",
		"../etc/passwd\nx/y":                              "",
	}
	for in, want := range cases {
		if got := strings.Join(parseCursorModels([]byte(in)), ","); got != want {
			t.Errorf("%q -> %q, want %q", in, got, want)
		}
	}
}
