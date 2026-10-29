// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestCodexHistoryAndRuntimeScopesAreIndependentWithPendingCleanup(t *testing.T) {
	for _, deny := range []string{consent.ScopeCodexLocalHistory, consent.ScopeCodexRuntimeUsage} {
		t.Run(deny, func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			t.Setenv("MODELPLAN_CODEX_ACCOUNT", "")
			t.Setenv("MODELPLAN_READERS", "")
			s, err := consent.EnsureStore(consent.Path())
			if err != nil {
				t.Fatal(err)
			}
			cache := t.TempDir()
			now := time.Now().UTC()
			p := ProductionPaths(cache, "1.0.0")
			hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) {
				return consent.Record{ReaderID: "native:codex", Backend: "native"}, nil
			}, Cleanup: func(scope string, forget bool) error { return EraseScope(p, scope, forget) }}
			request := consent.Grant{RequestID: "initial", ExpectStoreEpoch: s.StoreEpoch, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeCodexLocalHistory, consent.ScopeCodexRuntimeUsage}}
			if _, err := consent.ApplyGrant(consent.Path(), request, hooks); err != nil {
				t.Fatal(err)
			}
			percent := 25.0
			raw, _ := json.Marshal(map[string]any{"schemaVersion": 1, "status": "ok", "observedAt": now, "windows": []Window{{Kind: "five_hour", ObservedAt: now, UsedPercent: &percent}}, "admission": map[string]any{"storeEpoch": s.StoreEpoch, "generation": uint64(1), "scope": consent.ScopeCodexRuntimeUsage}})
			if err := os.MkdirAll(filepath.Dir(accountPath(cache)), 0700); err != nil {
				t.Fatal(err)
			}
			if err := writeAtomic(accountPath(cache), raw); err != nil {
				t.Fatal(err)
			}
			if r := ReadPermitted(ProductionPaths(cache, "1.0.0"), now); len(r.Accounts) != 1 {
				t.Fatal("initial runtime capture missing", r.Accounts)
			}
			unlock, err := consent.ReaderLock()
			if err != nil {
				t.Fatal(err)
			}
			request.RequestID = "deny"
			request.ExpectGeneration = 1
			request.Allow = nil
			request.Deny = []string{deny}
			receipt, err := consent.ApplyGrant(consent.Path(), request, hooks)
			unlock()
			if err != nil || receipt.Code != "cleanup_pending" {
				t.Fatal("pending cleanup not reproduced", receipt, err)
			}
			r := ReadPermitted(ProductionPaths(cache, "1.0.0"), now)
			want := 0
			if deny == consent.ScopeCodexLocalHistory {
				want = 1
			}
			if len(r.Accounts) != want {
				t.Fatalf("denying %s leaves %d runtime accounts, want %d", deny, len(r.Accounts), want)
			}
		})
	}
}

func TestCompletedCapturesRequireFreshReadAfterRegrantOrReset(t *testing.T) {
	for _, lifecycle := range []string{"deny-regrant", "reset-regrant"} {
		for _, kind := range []string{"managed", "aggregate", "typed"} {
			t.Run(lifecycle+"/"+kind, func(t *testing.T) {
				t.Setenv("HOME", t.TempDir())
				t.Setenv("MODELPLAN_READERS", "")
				t.Setenv("MODELPLAN_NATIVE", "")
				t.Setenv("MODELPLAN_IDENTITY", "")
				provider, scope := "copilot", consent.ScopeCopilotRuntimeUsage
				if kind == "managed" {
					provider, scope = "claude", consent.ScopeClaudeAccountUsageSavedLogin
				}
				home := os.Getenv("HOME")
				if err := os.MkdirAll(filepath.Join(home, "."+provider), 0700); err != nil {
					t.Fatal(err)
				}
				state, err := consent.EnsureStore(consent.Path())
				if err != nil {
					t.Fatal(err)
				}
				cache := t.TempDir()
				now := time.Now().UTC()
				percent := 25.0
				hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) {
					return consent.Record{ReaderID: "native:" + provider, Backend: "native"}, nil
				}, Cleanup: func(id string, forget bool) error { return EraseScope(ProductionPaths(cache, "1.0.0"), id, forget) }}
				request := consent.Grant{RequestID: "initial", ExpectStoreEpoch: state.StoreEpoch, ConsentTextVersion: consent.TextVersion, Allow: []string{scope}}
				if _, err := consent.ApplyGrant(consent.Path(), request, hooks); err != nil {
					t.Fatal(err)
				}
				initial, _ := consent.Load(consent.Path())
				stamp := initial.CaptureStamp(scope)
				entry := codexbarEntry{Admission: stamp, Provider: provider, Status: "ok", ObservedAt: now, Windows: []Window{{Kind: "five_hour", ObservedAt: now, UsedPercent: &percent}}}
				p := ProductionPaths(cache, "1.0.0")
				if kind == "managed" {
					g := p.ReaderAccess.Grants[provider]
					profile := g.Profiles[0]
					s := &readerState{SchemaVersion: 1, Provider: provider, GrantKey: readerHash(cache, provider+":grant", g.Generation), NextAttemptAt: now.Add(time.Hour), Entries: []readerEntry{{Admission: stamp, ProfileKey: readerHash(cache, provider+":profile", profile.Root+"\x00"+profile.AccountFile), Status: "ok", Account: &Account{Source: provider, ObservedAt: now, Windows: entry.Windows}}}}
					if err := saveReaderState(cache, s); err != nil {
						t.Fatal(err)
					}
				} else {
					raw, _ := json.Marshal(nativeSnap{SchemaVersion: 1, Providers: []codexbarEntry{entry}})
					os.MkdirAll(filepath.Dir(nativePath(cache)), 0700)
					if err := writeAtomic(nativePath(cache), raw); err != nil {
						t.Fatal(err)
					}
				}
				if report := ReadPermitted(p, now); len(report.Accounts) != 1 {
					t.Fatal("valid initial capture missing", report.Accounts)
				}
				if err := reserveReaderAttempt(cache, provider, now.Add(time.Hour)); err != nil {
					t.Fatal(err)
				}
				if lifecycle == "deny-regrant" {
					unlock, err := consent.ReaderLock()
					if err != nil {
						t.Fatal(err)
					}
					request.RequestID = "deny"
					request.ExpectGeneration = initial.Generation
					request.Allow = nil
					request.Deny = []string{scope}
					receipt, err := consent.ApplyGrant(consent.Path(), request, hooks)
					unlock()
					if err != nil || receipt.Code != "cleanup_pending" {
						t.Fatal(receipt, err)
					}
				} else {
					if _, err := consent.Reset(consent.Path()); err != nil {
						t.Fatal(err)
					}
				}
				current, _ := consent.Load(consent.Path())
				request.RequestID = "regrant"
				request.ExpectStoreEpoch = current.StoreEpoch
				request.ExpectGeneration = current.Generation
				request.Allow = []string{scope}
				request.Deny = nil
				if _, err := consent.ApplyGrant(consent.Path(), request, hooks); err != nil {
					t.Fatal(err)
				}
				p = ProductionPaths(cache, "1.0.0")
				if report := ReadPermitted(p, now); len(report.Accounts) != 0 {
					t.Fatal("old completed capture resurrected", report.Accounts)
				}
				if readerAttemptDue(cache, provider, now.Add(10*time.Minute)) {
					t.Fatal("regrant/reset reset shared budget")
				}
				if kind == "typed" {
					ctx := productionReaderContext(context.Background(), p, provider)
					access, _ := copilotAdmission(ctx)
					// Attempt/login metadata may legitimately be rewritten during a budget-only
					// refresh. That must never renew the retained last-good capture's authority.
					s := copilotState{SchemaVersion: 1, Availability: "ok", LoginGeneration: access.LoginGeneration, GoodGeneration: access.LoginGeneration, Good: &entry, NextAt: now.Add(time.Hour)}
					if !saveCopilotState(cache, s) {
						t.Fatal("typed seed failed")
					}
					if result := ReadCopilotCache(ctx, cache, now); result.Reading != nil {
						t.Fatal("typed cache renewed old capture", result.Reading)
					}
				}
				if kind == "managed" {
					s, err := loadReaderState(cache, provider)
					if err != nil {
						t.Fatal(err)
					}
					g := p.ReaderAccess.Grants[provider]
					s.GrantKey = readerHash(cache, provider+":grant", g.Generation)
					if err := saveReaderState(cache, s); err != nil {
						t.Fatal(err)
					}
					in := rows.Input{Now: now}
					AppendManagedRows(&in, p)
					if len(in.Accounts) != 0 {
						t.Fatal("rows adapter requalified old capture", in.Accounts)
					}
					old := nativeReaders[provider].Managed
					t.Cleanup(func() { nativeReaders[provider].Managed = old })
					calls := 0
					nativeReaders[provider].Managed = func(_ context.Context, _ *http.Client, r readerContext) readerOutcome {
						calls++
						return readerOutcome{Entry: readerEntry{Status: "ok", Account: &Account{Source: provider, ObservedAt: r.Now, Windows: entry.Windows}}}
					}
					if err := RefreshNative(context.Background(), p, now); err != nil {
						t.Fatal(err)
					}
					if calls != 0 {
						t.Fatal("budget bypassed after grant", calls)
					}
					future := now.Add(2 * time.Hour)
					if err := RefreshNative(context.Background(), p, future); err != nil {
						t.Fatal(err)
					}
					if calls != 1 {
						t.Fatal("eligible fresh read missing", calls)
					}
					if result := ReadPermitted(p, future); len(result.Accounts) != 1 {
						t.Fatal("newly admitted capture rejected", result.Accounts)
					}
				}
			})
		}
	}
}
