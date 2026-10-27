package quota

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestCopilotAdmissionBeforeIO(t *testing.T) {
	isolateHome(t)
	bin, log := fakeCopilot(t)
	t.Setenv("MODELPLAN_COPILOT", bin)
	for _, mode := range []string{"off", "passive", "unknown"} {
		t.Setenv("MODELPLAN_READERS", mode)
		e := collectCopilot(context.Background(), nil, t.TempDir(), now)
		if e.Status != "error" {
			t.Fatal(e)
		}
	}
	t.Setenv("MODELPLAN_READERS", "")
	for _, access := range []CopilotAccess{{}, {Allowed: true, Denied: true}, {Allowed: true, LoginGeneration: "raw-account-canary"}} {
		ctx := WithCopilotAccess(context.Background(), access)
		e := collectCopilot(ctx, nil, t.TempDir(), now)
		if e.Status != "error" {
			t.Fatal(e)
		}
	}
	if _, err := os.Stat(log); !os.IsNotExist(err) {
		t.Fatal("spawn before admission")
	}
}
func TestCopilotAttemptGateAndLastGood(t *testing.T) {
	isolateHome(t)
	bin, log := fakeCopilot(t)
	t.Setenv("MODELPLAN_COPILOT", bin)
	cache := t.TempDir()
	ctx := context.Background()
	if e := collectCopilot(ctx, nil, cache, now); e.Status != "ok" {
		t.Fatal(e)
	}
	before, _ := os.ReadFile(log)
	for _, at := range []time.Time{now.Add(time.Minute), now.Add(-time.Hour), now.Add(5 * time.Minute)} {
		collectCopilot(ctx, nil, cache, at)
	}
	after, _ := os.ReadFile(log)
	if !bytes.Equal(before, after) {
		t.Fatal("floor or success cadence bypassed")
	}
	// A failed read keeps the original capture time, also after restart.
	t.Setenv("MODELPLAN_COPILOT", filepath.Join(t.TempDir(), "missing"))
	e := collectCopilot(ctx, nil, cache, now.Add(10*time.Minute))
	if e.Status != "error" || !e.ObservedAt.Equal(now) {
		t.Fatal(e)
	}
	r := ReadCopilotCache(ctx, cache, now.Add(11*time.Minute))
	if !r.Beta || r.Availability != "not_detected" || r.Freshness != "stale" || r.Reading == nil || !r.ObservedAt.Equal(now) {
		t.Fatal(r)
	}
	state := loadCopilotState(cache)
	if !state.NextAt.Equal(now.Add(20 * time.Minute)) {
		t.Fatal(state)
	}
	// Retry doesn't reset the gate, and a wall clock rollback waits conservatively.
	collectCopilot(ctx, nil, cache, now.Add(19*time.Minute))
	if s := loadCopilotState(cache); !s.AttemptAt.Equal(state.AttemptAt) {
		t.Fatal(s)
	}
	reset := time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC)
	r = ReadCopilotCache(ctx, cache, reset)
	if len(r.Reading.Windows) != 1 || r.Reading.Windows[0].Limit != "chat" {
		t.Fatal(r)
	}
	b, _ := os.ReadFile(copilotStatePath(cache))
	for _, canary := range []string{bin, log, "session.", "raw-account-canary"} {
		if bytes.Contains(b, []byte(canary)) {
			t.Fatal("private content persisted")
		}
	}
}
func TestCopilotAuthBeforeQuota(t *testing.T) {
	isolateHome(t)
	for _, auth := range []string{`{"isAuthenticated":false}`, `{"isAuthenticated":true,"authType":"api-key"}`, `{"isAuthenticated":true,"authType":"gh-cli"}`, `{"isAuthenticated":true,"authType":"token"}`} {
		raw := copilotFrame(`{"id":1,"result":{"protocolVersion":3}}`) + copilotFrame(`{"id":3,"result":`+auth+`}`)
		var calls bytes.Buffer
		_, err := copilotQuotaRPC(strings.NewReader(raw), &calls)
		if err == nil || strings.Contains(calls.String(), "account.getQuota") {
			t.Fatal(err, calls.String())
		}
	}
}
func TestCopilotEnvironmentAndAuthHold(t *testing.T) {
	isolateHome(t)
	env := copilotEnvironment([]string{"GH_TOKEN=secret-canary", "COPILOT_SDK_AUTH_TOKEN=secret-canary", "HTTPS_PROXY=http://proxy", "COPILOT_HOME=/synthetic"})
	if len(env) != 2 || strings.Contains(strings.Join(env, " "), "secret-canary") {
		t.Fatal(env)
	}
	cache := t.TempDir()
	s := copilotState{SchemaVersion: 1, Availability: "expired_login", AttemptAt: now, NextAt: now.Add(10 * time.Minute), LoginGeneration: strings.Repeat("a", 64)}
	if !saveCopilotState(cache, s) {
		t.Fatal("save")
	}
	bin, log := fakeCopilot(t)
	t.Setenv("MODELPLAN_COPILOT", bin)
	ctx := WithCopilotAccess(context.Background(), CopilotAccess{Allowed: true, LoginGeneration: strings.Repeat("a", 64)})
	collectCopilot(ctx, nil, cache, now.Add(time.Hour))
	if _, err := os.Stat(log); !os.IsNotExist(err) {
		t.Fatal("expired login retried without tool change")
	}
	ctx = WithCopilotAccess(context.Background(), CopilotAccess{Allowed: true, LoginGeneration: strings.Repeat("b", 64)})
	if e := collectCopilot(ctx, nil, cache, now.Add(time.Hour)); e.Status != "ok" {
		t.Fatal(e)
	}
}
func TestCopilotCacheOnlyAndBackoff(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	ctx := context.Background()
	t.Setenv("MODELPLAN_COPILOT", filepath.Join(t.TempDir(), "missing"))
	at := now
	for _, wait := range []time.Duration{10 * time.Minute, 20 * time.Minute, 40 * time.Minute, time.Hour} {
		collectCopilot(ctx, nil, cache, at)
		s := loadCopilotState(cache)
		if s.NextAt.Sub(at) != wait {
			t.Fatal(s)
		}
		at = s.NextAt
	}
	before, _ := os.ReadFile(copilotStatePath(cache))
	for i := 0; i < 3; i++ {
		r := ReadCopilotCache(ctx, cache, at)
		if !r.Beta {
			t.Fatal(r)
		}
		_, _ = json.Marshal(r)
	}
	after, _ := os.ReadFile(copilotStatePath(cache))
	if !bytes.Equal(before, after) {
		t.Fatal("cache read mutated provider state")
	}
}

func copilotNativeStatus(t *testing.T, p Paths, at time.Time) SourceStatus {
	t.Helper()
	for _, source := range Read(p, at).Sources {
		if source.Source == "native:copilot" {
			return source
		}
	}
	t.Fatal("native Copilot source missing")
	return SourceStatus{}
}
func TestCopilotNativeDispatchPublishesFailureAndPreservesHistory(t *testing.T) {
	for _, tc := range []struct{ state, auth string }{
		{"expired_login", `{"isAuthenticated":false}`},
		{"not_supported_yet", `{"isAuthenticated":true,"authType":"api-key"}`},
	} {
		t.Run(tc.state, func(t *testing.T) {
			isolateHome(t)
			bin, log := fakeCopilot(t)
			t.Setenv("MODELPLAN_COPILOT", bin)
			p := nativePaths(t)
			if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "copilot", Backend: BackendNative, Enabled: true}); err != nil {
				t.Fatal(err)
			}
			ctx := context.Background()
			if err := RefreshNative(ctx, p, now); err != nil {
				t.Fatal(err)
			}
			if st := copilotNativeStatus(t, p, now); st.Status != "ok" {
				t.Fatal(st)
			}
			t.Setenv("MODELPLAN_TEST_COPILOT_AUTH_STATUS", tc.auth)
			if err := RefreshNative(ctx, p, now.Add(10*time.Minute)); err != nil {
				t.Fatal(err)
			}
			st := copilotNativeStatus(t, p, now.Add(10*time.Minute))
			if st.Status != "unavailable" || st.Reason != copilotNext(tc.state) {
				t.Fatal(st)
			}
			for _, account := range Read(p, now.Add(10*time.Minute)).Accounts {
				if account.Source == "native:copilot" {
					t.Fatal("failed native source presented as a current account", account)
				}
			}
			// Both caches retain original-age historical numbers, while the dispatched
			// native entry's current status is an error. The rich cache projection makes
			// that separation explicit for the future CLIJIT status consumer.
			snap := loadNative(p.Cache)
			if len(snap.Providers) != 1 || snap.Providers[0].Status != "error" || !snap.Providers[0].ObservedAt.Equal(now) || len(snap.Providers[0].Windows) != 2 {
				t.Fatal(snap)
			}
			result := ReadCopilotCache(ctx, p.Cache, now.Add(10*time.Minute))
			if result.Availability != tc.state || result.Freshness != "stale" || result.Reading == nil || !result.ObservedAt.Equal(now) || len(result.Reading.Windows) != 2 {
				t.Fatal(result)
			}
			if good := loadCopilotState(p.Cache).Good; good == nil || good.Status != "ok" || !good.ObservedAt.Equal(now) {
				t.Fatal(good)
			}
			calls, _ := os.ReadFile(log)
			if bytes.Count(calls, []byte(`"method":"account.getQuota"`)) != 1 {
				t.Fatal("quota called for unsupported/expired auth")
			}
		})
	}
}
func TestCopilotCaptureGenerationIsNotAttemptGeneration(t *testing.T) {
	isolateHome(t)
	bin, log := fakeCopilot(t)
	t.Setenv("MODELPLAN_COPILOT", bin)
	p := nativePaths(t)
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "copilot", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	genA, genB := strings.Repeat("a", 64), strings.Repeat("b", 64)
	ctxA := WithCopilotAccess(context.Background(), CopilotAccess{Allowed: true, LoginGeneration: genA})
	ctxB := WithCopilotAccess(context.Background(), CopilotAccess{Allowed: true, LoginGeneration: genB})
	if err := RefreshNative(ctxA, p, now); err != nil {
		t.Fatal(err)
	}
	s := loadCopilotState(p.Cache)
	if s.GoodGeneration != genA {
		t.Fatal(s)
	}
	result := ReadCopilotCache(ctxB, p.Cache, now.Add(time.Minute))
	if result.Reading != nil || !result.ObservedAt.IsZero() || result.Availability != "stale" {
		t.Fatal("old-login numbers exposed by B cache read", result)
	}
	before, _ := os.ReadFile(log)
	if err := RefreshNative(ctxB, p, now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	after, _ := os.ReadFile(log)
	if !bytes.Equal(before, after) {
		t.Fatal("login generation change bypassed provider floor")
	}
	if st := copilotNativeStatus(t, p, now.Add(time.Minute)); st.Status != "unavailable" {
		t.Fatal(st)
	}
	if current := loadCopilotState(p.Cache); !current.AttemptAt.Equal(s.AttemptAt) || !current.NextAt.Equal(s.NextAt) {
		t.Fatal("generation switch reset gates")
	}
	t.Setenv("MODELPLAN_TEST_COPILOT_AUTH_STATUS", `{"isAuthenticated":false}`)
	if err := RefreshNative(ctxB, p, now.Add(10*time.Minute)); err != nil {
		t.Fatal(err)
	}
	current := loadCopilotState(p.Cache)
	if current.LoginGeneration != genB || current.GoodGeneration != genA || current.Good == nil || !current.Good.ObservedAt.Equal(now) {
		t.Fatal(current)
	}
	result = ReadCopilotCache(ctxB, p.Cache, now.Add(10*time.Minute))
	if result.Reading != nil || !result.ObservedAt.IsZero() || result.Availability != "expired_login" {
		t.Fatal("attempt generation rebound A quota to B or lost B's failure", result)
	}
	if st := copilotNativeStatus(t, p, now.Add(10*time.Minute)); st.Reason != copilotNext("expired_login") {
		t.Fatal(st)
	}
	snap := loadNative(p.Cache)
	if len(snap.Providers) != 1 || len(snap.Providers[0].Windows) != 0 || snap.Providers[0].Status != "error" {
		t.Fatal("A quota exposed in native B slot", snap)
	}
	// A remains a separately scoped historical reading; its age was not refreshed.
	result = ReadCopilotCache(ctxA, p.Cache, now.Add(10*time.Minute))
	if result.Reading == nil || !result.ObservedAt.Equal(now) || result.Freshness != "stale" {
		t.Fatal(result)
	}
}
func TestCopilotLegacyNativeRecoveryKeepsBackoff(t *testing.T) {
	isolateHome(t)
	bin, log := fakeCopilot(t)
	t.Setenv("MODELPLAN_COPILOT", bin)
	p := nativePaths(t)
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "copilot", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	// Use the actual native dispatch with no WithCopilotAccess override, as current
	// production callers do. Empty generations must never create an eternal hold.
	ctx := context.Background()
	if err := RefreshNative(ctx, p, now); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_TEST_COPILOT_AUTH_STATUS", `{"isAuthenticated":false}`)
	if err := RefreshNative(ctx, p, now.Add(10*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if st := copilotNativeStatus(t, p, now.Add(10*time.Minute)); st.Status != "unavailable" {
		t.Fatal(st)
	}
	if next := loadCopilotState(p.Cache).NextAt; !next.Equal(now.Add(20 * time.Minute)) {
		t.Fatal(next)
	}
	// The user signs in in Copilot. No credential file is inspected and no gate is
	// reset; only the next admitted runtime read can discover the recovery.
	t.Setenv("MODELPLAN_TEST_COPILOT_AUTH_STATUS", `{"isAuthenticated":true,"authType":"user"}`)
	before, _ := os.ReadFile(log)
	if err := RefreshNative(ctx, p, now.Add(19*time.Minute)); err != nil {
		t.Fatal(err)
	}
	after, _ := os.ReadFile(log)
	if !bytes.Equal(before, after) {
		t.Fatal("auth recovery bypassed backoff")
	}
	if err := RefreshNative(ctx, p, now.Add(20*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if st := copilotNativeStatus(t, p, now.Add(20*time.Minute)); st.Status != "ok" {
		t.Fatal(st)
	}
	s := loadCopilotState(p.Cache)
	if s.Good == nil || !s.Good.ObservedAt.Equal(now.Add(20*time.Minute)) || s.Availability != "ok" {
		t.Fatal(s)
	}
}
