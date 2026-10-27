package quota

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

func TestAmpMoneyPools(t *testing.T) {
	isolateHome(t)
	raw := []byte("signed in: private-email-canary\n\x1b[32mAmp Free: **$17.59/$20.00** remaining (+$0.83/hour)\x1b[0m\nIndividual: $10.01 remaining\n")
	pools, ok := parseAmpUsage(raw)
	if !ok || len(pools) != 2 || pools[0].Kind != "free" || pools[0].Remaining != 17.59 || *pools[0].Limit != 20 || pools[1].Kind != "paid" || pools[1].Limit != nil {
		t.Fatal(pools, ok)
	}
	for _, raw := range []string{"", `Free: $30/$20 remaining`, `Free: $1.001 remaining`, `unknown-company: $10 remaining`, `Free: $1 remaining` + "\n" + `Free: $2 remaining`, strings.Repeat("x", 65<<10)} {
		if _, ok := parseAmpUsage([]byte(raw)); ok {
			t.Fatal(raw[:min(len(raw), 100)])
		}
	}
	zero, ok := parseAmpUsage([]byte("Free: $0/$20 remaining\nPaid: $0 remaining"))
	if !ok || zero[0].Remaining != 0 || zero[1].Limit != nil {
		t.Fatal(zero)
	}
}
func TestAmpAdmissionAuditAndCache(t *testing.T) {
	isolateHome(t)
	fakeAmpArtifact(t)
	bin := filepath.Join(t.TempDir(), "amp")
	body := []byte("\x7fELFsynthetic-test-only")
	_ = os.WriteFile(bin, body, 0700)
	sum := sha256.Sum256(body)
	t.Setenv("MODELPLAN_AMP", bin)
	old := ampCommand
	t.Cleanup(func() { ampCommand = old })
	calls := 0
	fail := false
	ampCommand = func(context.Context, string) ([]byte, error) {
		calls++
		if fail {
			return nil, errors.New("private-error-canary")
		}
		return []byte("user: private-email-canary\nFree: $17/$20 remaining\nPaid: $5 remaining"), nil
	}
	cache := t.TempDir()
	ctx := context.Background()
	if r := RefreshAmp(ctx, cache, now); r.Availability != "consent_required" || calls != 0 {
		t.Fatal(r)
	}
	ctx = WithAmpAccess(ctx, AmpAccess{Allowed: true})
	if r := RefreshAmp(ctx, cache, now); r.Availability != "not_supported_yet" || calls != 0 {
		t.Fatal(r)
	}
	ctx = WithAmpAccess(context.Background(), AmpAccess{Allowed: true, AuditedSHA256: hex.EncodeToString(sum[:])})
	r := RefreshAmp(ctx, cache, now.Add(10*time.Minute))
	if r.Availability != "ok" || len(r.Pools) != 2 || !r.Beta || calls != 1 {
		t.Fatal(r, calls)
	}
	RefreshAmp(ctx, cache, now.Add(11*time.Minute))
	if calls != 1 {
		t.Fatal("cadence")
	}
	fail = true
	RefreshAmp(ctx, cache, now.Add(20*time.Minute))
	r = ReadAmpCache(ctx, cache, now.Add(21*time.Minute))
	if r.Freshness != "stale" || !r.ObservedAt.Equal(now.Add(10*time.Minute)) || len(r.Pools) != 2 {
		t.Fatal(r)
	}
	b, _ := os.ReadFile(ampPath(cache))
	out, _ := json.Marshal(r)
	for _, canary := range []string{"private-error-canary", "private-email-canary", bin} {
		if bytes.Contains(append(b, out...), []byte(canary)) {
			t.Fatal("private content persisted")
		}
	}
	prior := calls
	ReadAmpCache(ctx, cache, now.Add(24*time.Hour))
	if calls != prior {
		t.Fatal("cache-only invoked provider")
	}
	for _, mode := range []string{"off", "passive"} {
		t.Setenv("MODELPLAN_READERS", mode)
		RefreshAmp(ctx, cache, now.Add(time.Hour))
	}
	if calls != prior {
		t.Fatal("off/passive invoked provider")
	}
}
func TestAmpUnsupportedLoginAndWrapper(t *testing.T) {
	isolateHome(t)
	for _, state := range []string{"expired", "unsupported"} {
		ctx := WithAmpAccess(context.Background(), AmpAccess{Allowed: true, LoginState: state})
		r := RefreshAmp(ctx, t.TempDir(), now)
		if r.Availability != "expired_login" && r.Availability != "not_supported_yet" {
			t.Fatal(r)
		}
	}
	path := filepath.Join(t.TempDir(), "amp")
	body := []byte("#!/bin/sh\nexit 1\n")
	_ = os.WriteFile(path, body, 0700)
	sum := sha256.Sum256(body)
	if ampAuditedBinary(path, hex.EncodeToString(sum[:])) {
		t.Fatal("wrapper admitted without native binary audit")
	}
}
func TestAmpCommandNoInputUpdatesOrThread(t *testing.T) {
	isolateHome(t)
	path := filepath.Join(t.TempDir(), "amp")
	body := "#!/bin/sh\n[ \"$1\" = usage ] && [ \"$2\" = --no-color ] && [ \"$#\" = 2 ] || exit 2\n[ \"$AMP_SKIP_UPDATE_CHECK\" = 1 ] || exit 3\nif read line; then exit 4; fi\nprintf 'Paid: $10 remaining\\n'\n"
	if os.WriteFile(path, []byte(body), 0700) != nil {
		t.Fatal("write")
	}
	if runtime.GOOS != "linux" {
		t.Skip("immutable descriptor execution is Linux-only until audited")
	}
	file, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	ctx := context.WithValue(context.Background(), ampArtifactKey{}, file)
	out, err := runAmpUsage(ctx, path)
	if err != nil || !strings.Contains(string(out), "$10 remaining") {
		t.Fatal(err, string(out))
	}
}

// This injected constructor is used only with an injected non-executing command.
func fakeAmpArtifact(t *testing.T) {
	t.Helper()
	old := ampArtifact
	t.Cleanup(func() { ampArtifact = old })
	ampArtifact = func(path, want string) (*os.File, error) {
		b, err := os.ReadFile(path)
		if err != nil {
			return nil, err
		}
		sum := sha256.Sum256(b)
		if hex.EncodeToString(sum[:]) != want {
			return nil, errors.New("synthetic unaudited artifact")
		}
		return os.Open(path)
	}
}
func TestAmpCapturedGenerationDoesNotFollowAttempt(t *testing.T) {
	isolateHome(t)
	fakeAmpArtifact(t)
	bin := filepath.Join(t.TempDir(), "amp")
	body := []byte("synthetic-audited-file")
	_ = os.WriteFile(bin, body, 0700)
	sum := sha256.Sum256(body)
	t.Setenv("MODELPLAN_AMP", bin)
	old := ampCommand
	t.Cleanup(func() { ampCommand = old })
	calls := 0
	fail := false
	ampCommand = func(context.Context, string) ([]byte, error) {
		calls++
		if fail {
			return nil, errors.New("synthetic failure")
		}
		return []byte("Paid: $10 remaining"), nil
	}
	a := AmpAccess{Allowed: true, AuditedSHA256: hex.EncodeToString(sum[:]), LoginGeneration: strings.Repeat("a", 64)}
	b := a
	b.LoginGeneration = strings.Repeat("b", 64)
	ctxA := WithAmpAccess(context.Background(), a)
	ctxB := WithAmpAccess(context.Background(), b)
	cache := t.TempDir()
	r := RefreshAmp(ctxA, cache, now)
	if len(r.Pools) != 1 || calls != 1 {
		t.Fatal(r)
	}
	next := r.NextAttemptAt
	if r := ReadAmpCache(ctxB, cache, now.Add(time.Minute)); len(r.Pools) != 0 || !r.ObservedAt.IsZero() {
		t.Fatal("A balance exposed to B", r)
	}
	r = RefreshAmp(ctxB, cache, now.Add(time.Minute))
	if len(r.Pools) != 0 || calls != 1 || !r.NextAttemptAt.Equal(next) {
		t.Fatal("generation bypassed floor", r)
	}
	fail = true
	r = RefreshAmp(ctxB, cache, now.Add(10*time.Minute))
	if len(r.Pools) != 0 || !r.ObservedAt.IsZero() || calls != 2 {
		t.Fatal("failed B attempt rebound A balance", r)
	}
	s := loadAmp(cache)
	if s.GoodGeneration != a.LoginGeneration || s.LoginGeneration != b.LoginGeneration || !s.ObservedAt.Equal(now) {
		t.Fatal(s)
	}
	// A's failure remains an aged A reading, including if B never succeeded.
	r = ReadAmpCache(ctxA, cache, now.Add(10*time.Minute))
	if len(r.Pools) != 1 || !r.ObservedAt.Equal(now) || r.Freshness != "stale" {
		t.Fatal(r)
	}
}
