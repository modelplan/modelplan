// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/localusage"
)

// MACREV2's reproducer: the independently due local projection must never turn
// a background sweep into an early legacy quota request or process launch.
func TestDoctorReadersLegacyBudgetSharedWithSessionSweeps(t *testing.T) {
	for _, id := range []string{"opencodego", "minimax", "zai", "kiro"} {
		for _, doctorFirst := range []bool{true, false} {
			order := "ordinary_then_doctor"
			if doctorFirst {
				order = "doctor_then_ordinary"
			}
			t.Run(id+"/"+order, func(t *testing.T) {
				_ = claudeTestPaths(t)
				t.Setenv("MODELPLAN_HISTORY", "")
				t.Setenv("CLAUDE_CODE_SESSION_ID", "session-main")
				status, requests := 200, []string{}
				claudeTestServer(t, &status, &requests)
				at, hits := productionLegacyTests[id](t)
				root := os.Getenv("CLAUDE_CONFIG_DIR")
				file := filepath.Join(root, "projects", "p", "session-main.jsonl")
				batch := sessionBatch("session-main", "cli", at.Add(-time.Minute), "claude-opus-5-5")
				writeClaudeSession(t, file, batch.Records...)
				productionConsent(t, "claude", true)
				productionConsent(t, id, true)
				cache := t.TempDir()
				paths := func() Paths { return ProductionPaths(cache, "1.0.0") }
				first, second := RefreshNative, RefreshReaderDiagnostics
				if doctorFirst {
					first, second = second, first
				}
				if err := first(context.Background(), paths(), at); err != nil {
					t.Fatal(err)
				}
				called := hits()
				if called == 0 {
					t.Fatal("fixture did not perform the initial legacy read")
				}
				next, err := loadReaderAttempt(cache, id)
				if err != nil || !next.Equal(at.Add(NativeEvery)) {
					t.Fatal("legacy interval was not persisted", next, err)
				}
				later := at.Add(time.Minute)
				p := paths() // Reconstruct admission and reload persisted budgets as a new caller.
				if p.ClaudeSessionAccess == nil || !claudeSessionsDue(p, later) || !NativeDue(p, later) {
					t.Fatal("passive session cadence was throttled")
				}
				prior := localusage.ReadProjectionCache(cache, "claude", *p.ClaudeSessionAccess, later)
				if err := second(context.Background(), p, later); err != nil {
					t.Fatal(err)
				}
				if hits() != called {
					t.Fatal("cross-dispatch sweep bypassed the legacy floor", called, hits())
				}
				// An ordinary sweep still advances the projection at its independent cadence.
				if !doctorFirst {
					if err := RefreshNative(context.Background(), paths(), later); err != nil {
						t.Fatal(err)
					}
				}
				p = paths()
				after := localusage.ReadProjectionCache(cache, "claude", *p.ClaudeSessionAccess, later)
				if !after.NextAttemptAt.After(prior.NextAttemptAt) || after.NextAttemptAt.After(later.Add(time.Minute)) {
					t.Fatal("ordinary session cadence changed", prior.NextAttemptAt, after.NextAttemptAt)
				}
				if hits() != called {
					t.Fatal("session refresh repeated legacy I/O")
				}
				// Losing the aggregate capture must not lose the provider reservation.
				if err := os.Remove(nativePath(cache)); err != nil {
					t.Fatal(err)
				}
				p = paths()
				p.ClaudeSessionAccess = nil
				if NativeDue(p, later) {
					t.Fatal("missing aggregate bypassed persisted floor")
				}
				if err := RefreshNative(context.Background(), paths(), at.Add(9*time.Minute)); err != nil {
					t.Fatal(err)
				}
				if hits() != called {
					t.Fatal("restart/cache loss bypassed the existing interval")
				}
				if err := RefreshReaderDiagnostics(context.Background(), paths(), at.Add(NativeEvery)); err != nil {
					t.Fatal(err)
				}
				if hits() != 2*called {
					t.Fatal("legacy read did not resume at its original interval", called, hits())
				}
			})
		}
	}
}

func TestDoctorReadersLegacyCachedIntervalAndBackoff(t *testing.T) {
	for _, id := range []string{"opencodego", "minimax", "zai", "kiro"} {
		for _, fail := range []bool{false, true} {
			name := "success"
			if fail {
				name = "failure"
			}
			t.Run(id+"/"+name, func(t *testing.T) {
				isolateHome(t)
				t.Setenv("MODELPLAN_READERS", "")
				t.Setenv("MODELPLAN_NATIVE", "")
				t.Setenv("MODELPLAN_HISTORY", "off")
				at, hits := productionLegacyTests[id](t)
				if fail {
					if id == "kiro" {
						bin, log := fakeKiro(t, `{"success":false,"message":"synthetic rejection"}`)
						t.Setenv("MODELPLAN_KIRO", bin)
						hits = func() int { b, _ := os.ReadFile(log); return len(b) }
					} else {
						calls := 0
						old := nativeClient
						t.Cleanup(func() { nativeClient = old })
						nativeClient = &http.Client{Transport: productionTransport(func(*http.Request) (*http.Response, error) {
							calls++
							return &http.Response{StatusCode: 503, Header: http.Header{}, Body: io.NopCloser(strings.NewReader("synthetic failure"))}, nil
						})}
						hits = func() int { return calls }
					}
				}
				productionConsent(t, id, true)
				cache := t.TempDir()
				paths := func() Paths { return ProductionPaths(cache, "1.0.0") }
				if err := RefreshNative(context.Background(), paths(), at); err != nil {
					t.Fatal(err)
				}
				called := hits()
				if called == 0 {
					t.Fatal("no initial request/process")
				}
				interval := NativeEvery
				if fail {
					interval = nativeRetryAfter
				}
				next, err := loadReaderAttempt(cache, id)
				if err != nil || !next.Equal(at.Add(interval)) {
					t.Fatal("interval/backoff reservation missing", next, err)
				}
				// Simulate a capture from before reservations were introduced. Both paths
				// must honour its own timestamp, even if another sweep rewrites the envelope.
				if err := os.Remove(readerAttemptPath(cache, id)); err != nil {
					t.Fatal(err)
				}
				for _, elapsed := range []time.Duration{time.Minute, 5 * time.Minute, interval - time.Second} {
					if NativeDue(paths(), at.Add(elapsed)) {
						t.Fatal("cached interval/backoff was bypassed", elapsed)
					}
					if err := RefreshReaderDiagnostics(context.Background(), paths(), at.Add(elapsed)); err != nil {
						t.Fatal(err)
					}
					if err := RefreshNative(context.Background(), paths(), at.Add(elapsed)); err != nil {
						t.Fatal(err)
					}
					if hits() != called {
						t.Fatal("cached interval/backoff repeated I/O", elapsed)
					}
				}
				if !NativeDue(paths(), at.Add(interval)) {
					t.Fatal("unrelated sweeps postponed the original deadline")
				}
				if err := RefreshReaderDiagnostics(context.Background(), paths(), at.Add(interval)); err != nil {
					t.Fatal(err)
				}
				if hits() != 2*called {
					t.Fatal("reader did not resume at interval/backoff boundary", called, hits())
				}
			})
		}
	}
}

func TestDoctorReadersLegacyReservationWithoutCapture(t *testing.T) {
	for _, id := range []string{"opencodego", "minimax", "zai", "kiro"} {
		t.Run(id, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_READERS", "")
			t.Setenv("MODELPLAN_NATIVE", "")
			t.Setenv("MODELPLAN_HISTORY", "off")
			at, hits := productionLegacyTests[id](t)
			productionConsent(t, id, true)
			cache := t.TempDir()
			if err := reserveReaderAttempt(cache, id, at.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			paths := func() Paths { return ProductionPaths(cache, "1.0.0") }
			for _, refresh := range []func(context.Context, Paths, time.Time) error{RefreshNative, RefreshReaderDiagnostics} {
				if NativeDue(paths(), at.Add(4*time.Minute)) {
					t.Fatal("capture-free floor bypassed by scheduler")
				}
				if err := refresh(context.Background(), paths(), at.Add(4*time.Minute)); err != nil {
					t.Fatal(err)
				}
				if hits() != 0 {
					t.Fatal("capture-free floor bypassed by dispatcher")
				}
			}
			if !NativeDue(paths(), at.Add(5*time.Minute)) {
				t.Fatal("reader stayed blocked after floor")
			}
			if err := RefreshNative(context.Background(), paths(), at.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			if hits() == 0 {
				t.Fatal("reader did not resume after persisted floor")
			}
		})
	}
}
