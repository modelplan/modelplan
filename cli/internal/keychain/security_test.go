package keychain

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestSecuritySuccessUsesFixedItemAndDeadline(t *testing.T) {
	calls := 0
	r := Reader{Cache: t.TempDir(), Execute: func(ctx context.Context, bin string, args ...string) (ProcessResult, error) {
		calls++
		if bin != "/usr/bin/security" || strings.Join(args, " ") != "find-generic-password -s Claude Code-credentials -w" {
			t.Fatal("unexpected command")
		}
		deadline, ok := ctx.Deadline()
		if !ok || time.Until(deadline) > BackgroundTimeout {
			t.Fatal("background deadline missing")
		}
		return ProcessResult{Output: []byte("synthetic-secret\n")}, nil
	}}
	p := Policy{Allowed: true, PriorGrant: true, ProfileRef: strings.Repeat("a", 64)}
	if v := r.ClaudeCredentials(context.Background(), p); v.State != "ok" || string(v.Value) != "synthetic-secret" {
		t.Fatal("fast success failed")
	}
	if calls != 1 {
		t.Fatal(calls)
	}
	assertNoSecret(t, r.Cache)
}

func TestSecurityTimeoutKillsProcessAndSuspendsBackground(t *testing.T) {
	calls := 0
	r := Reader{Cache: t.TempDir(), Execute: func(ctx context.Context, _ string, _ ...string) (ProcessResult, error) {
		calls++
		cmd := exec.CommandContext(ctx, os.Args[0], "-test.run=^TestSecuritySyntheticChild$")
		cmd.Env = append(os.Environ(), "MODELPLAN_TEST_KEYCHAIN_CHILD=1")
		err := cmd.Run()
		if cmd.ProcessState == nil || !cmd.ProcessState.Exited() && ctx.Err() == nil {
			t.Fatal("child not reaped")
		}
		return ProcessResult{ExitCode: cmd.ProcessState.ExitCode()}, err
	}}
	p := Policy{Allowed: true, PriorGrant: true, ProfileRef: strings.Repeat("b", 64)}
	start := time.Now()
	v := r.ClaudeCredentials(context.Background(), p)
	if v.State != ConfirmationNeeded || v.NextStep != "Allow in Settings" || len(v.Value) != 0 {
		t.Fatalf("result=%+v", v)
	}
	if time.Since(start) > 5*time.Second {
		t.Fatal("background prompt did not time out")
	}
	if v = r.ClaudeCredentials(context.Background(), p); v.State != ConfirmationNeeded || calls != 1 {
		t.Fatal("background re-prompted")
	}
	assertNoSecret(t, r.Cache)
}

func TestSecuritySyntheticChild(t *testing.T) {
	if os.Getenv("MODELPLAN_TEST_KEYCHAIN_CHILD") != "1" {
		return
	}
	time.Sleep(time.Minute)
	os.Exit(0)
}

func TestSecurityDenyPersistsUntilExplicitAction(t *testing.T) {
	for _, code := range []int{128, 51, 36} {
		t.Run(strings.Repeat("x", code%10+1), func(t *testing.T) {
			calls := 0
			cache := t.TempDir()
			r := Reader{Cache: cache, Execute: func(context.Context, string, ...string) (ProcessResult, error) {
				calls++
				return ProcessResult{ExitCode: code, Output: []byte("synthetic-secret")}, errors.New("secret-error-must-not-escape")
			}}
			p := Policy{Allowed: true, PriorGrant: true, ProfileRef: strings.Repeat("c", 64)}
			if v := r.ClaudeCredentials(context.Background(), p); v.State != Denied || v.NextStep != "Allow in Settings" {
				t.Fatal("deny not recorded")
			}
			r = Reader{Cache: cache, Execute: func(ctx context.Context, _ string, _ ...string) (ProcessResult, error) {
				calls++
				deadline, _ := ctx.Deadline()
				if time.Until(deadline) < 20*time.Second {
					t.Fatal("interactive action kept background timeout")
				}
				return ProcessResult{Output: []byte("synthetic-secret")}, nil
			}}
			if v := r.ClaudeCredentials(context.Background(), p); v.State != Denied || calls != 1 {
				t.Fatal("persisted deny re-prompted")
			}
			p.ProfileRef = strings.Repeat("e", 64)
			if v := r.ClaudeCredentials(context.Background(), p); v.State != Denied || calls != 1 {
				t.Fatal("profile change bypassed provider Deny")
			}
			p.Interactive = true
			if v := r.ClaudeCredentials(context.Background(), p); v.State != "ok" || calls != 2 {
				t.Fatal("explicit action did not recover")
			}
			assertNoSecret(t, cache)
		})
	}
}

func TestSecurityRequiresConsentAndPriorGrant(t *testing.T) {
	calls := 0
	r := Reader{Cache: t.TempDir(), Execute: func(context.Context, string, ...string) (ProcessResult, error) { calls++; return ProcessResult{}, nil }}
	p := Policy{ProfileRef: strings.Repeat("d", 64)}
	if r.ClaudeCredentials(context.Background(), p).State != "consent-required" {
		t.Fatal("consent bypassed")
	}
	p.Allowed = true
	if r.ClaudeCredentials(context.Background(), p).State != ConfirmationNeeded || calls != 0 {
		t.Fatal("background prompted without prior grant")
	}
}

func TestSecurityResultCannotExposeSecretInDiagnostics(t *testing.T) {
	r := Result{Value: []byte("synthetic-secret"), State: "ok"}
	b, err := json.Marshal(r)
	if err != nil {
		t.Fatal(err)
	}
	for _, value := range []string{string(b), fmt.Sprintf("%v", r), fmt.Sprintf("%+v", r), fmt.Sprintf("%#v", r)} {
		if strings.Contains(value, "synthetic-secret") || strings.Contains(value, "c3ludGhldGljLXNlY3JldA") {
			t.Fatal("secret exposed in diagnostic formatting")
		}
	}
}

func assertNoSecret(t *testing.T, root string) {
	t.Helper()
	err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if strings.Contains(string(b), "synthetic-secret") || strings.Contains(string(b), "secret-error") {
			t.Fatal("secret persisted")
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}
