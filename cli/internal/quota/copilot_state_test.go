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
	if e.Status != "ok" || !e.ObservedAt.Equal(now) {
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
	s := copilotState{SchemaVersion: 1, Availability: "expired_login", AttemptAt: now, NextAt: now.Add(10 * time.Minute)}
	if !saveCopilotState(cache, s) {
		t.Fatal("save")
	}
	bin, log := fakeCopilot(t)
	t.Setenv("MODELPLAN_COPILOT", bin)
	collectCopilot(context.Background(), nil, cache, now.Add(time.Hour))
	if _, err := os.Stat(log); !os.IsNotExist(err) {
		t.Fatal("expired login retried without tool change")
	}
	ctx := WithCopilotAccess(context.Background(), CopilotAccess{Allowed: true, LoginGeneration: strings.Repeat("a", 64)})
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
