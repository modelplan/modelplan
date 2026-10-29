// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/keychain"
	"github.com/modelplan/modelplan/cli/internal/localusage"
)

func diagnosticRow(t *testing.T, rows []ReaderDiagnostic, id string) ReaderDiagnostic {
	t.Helper()
	for _, r := range rows {
		if r.Provider == id {
			return r
		}
	}
	t.Fatal("missing diagnostic", id)
	return ReaderDiagnostic{}
}

func TestDoctorReadersProductionInventoryAndBudgets(t *testing.T) {
	setups := map[string]func(*testing.T) (time.Time, func() int){}
	for id, setup := range productionManagedTests {
		setups[id] = setup
	}
	for id, setup := range productionLegacyTests {
		setups[id] = setup
	}
	for id := range nativeReaders {
		if setups[id] == nil {
			t.Fatal("no diagnostic fixture", id)
		}
	}
	for id, setup := range setups {
		t.Run(id, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_READERS", "")
			t.Setenv("MODELPLAN_NATIVE", "")
			t.Setenv("MODELPLAN_HISTORY", "off")
			at, hits := setup(t)
			cache := t.TempDir()
			paths := func() Paths { return ProductionPaths(cache, "1.0.0") }
			rows := ReaderDiagnostics(paths(), at)
			if len(rows) != len(nativeReaders)+len(localusage.HistoryProviders())+1 {
				t.Fatal("incomplete inventory", rows)
			}
			for _, tool := range localusage.HistoryProviders() {
				diagnosticRow(t, rows, tool+":history")
			}
			if diagnosticRow(t, rows, id).Admitted != "no" {
				t.Fatal("admitted before consent")
			}
			_ = RefreshReaderDiagnostics(context.Background(), paths(), at)
			if hits() != 0 {
				t.Fatal("read before consent")
			}
			productionConsent(t, id, true)
			if r := diagnosticRow(t, ReaderDiagnostics(paths(), at), id); r.Consent != "granted" || r.Admitted != "yes" {
				t.Fatal("lost production admission", r)
			}
			if err := RefreshReaderDiagnostics(context.Background(), paths(), at); err != nil {
				t.Fatal(err)
			}
			called := hits()
			if called == 0 {
				t.Fatal("no production read")
			}
			before := diagnosticFiles(t, cache)
			r := diagnosticRow(t, ReaderDiagnostics(paths(), at), id)
			if r.State != "ok" || r.Last != "0s" || r.Windows == 0 {
				t.Fatal("missing cache result", r)
			}
			if !reflect.DeepEqual(before, diagnosticFiles(t, cache)) || hits() != called {
				t.Fatal("cache report performed I/O")
			}
			if err := RefreshReaderDiagnostics(context.Background(), paths(), at.Add(4*time.Minute)); err != nil {
				t.Fatal(err)
			}
			if hits() != called {
				t.Fatal("refresh bypassed floor")
			}
			for _, mode := range []string{"off", "passive"} {
				if mode == "passive" && nativeReaders[id].KeyEnv != "" {
					continue
				}
				t.Setenv("MODELPLAN_READERS", mode)
				_ = RefreshReaderDiagnostics(context.Background(), paths(), at.Add(time.Hour))
				if hits() != called || diagnosticRow(t, ReaderDiagnostics(paths(), at), id).Admitted != "no" {
					t.Fatal("privacy restriction bypassed", mode)
				}
			}
			t.Setenv("MODELPLAN_READERS", "")
			productionConsent(t, id, false)
			_ = RefreshReaderDiagnostics(context.Background(), paths(), at.Add(time.Hour))
			r = diagnosticRow(t, ReaderDiagnostics(paths(), at), id)
			if hits() != called || r.Consent != "denied" || r.Admitted != "no" || r.Windows != 0 {
				t.Fatal("revoked reader exposed", r)
			}
		})
	}
}

func diagnosticFiles(t *testing.T, dir string) map[string]string {
	t.Helper()
	out := map[string]string{}
	err := filepath.WalkDir(dir, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !entry.IsDir() {
			b, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			out[path] = string(b)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func TestDoctorReadersIdentifiersNeverReachAnyField(t *testing.T) {
	for _, hidden := range []string{"synthetic.person@example.invalid", "acct_SYNTHETIC_83109", "org_SYNTHETIC_58236", "/Users/Synthetic Person/secret.json", `C:\Users\Synthetic\token.json`, strings.Repeat("ab32", 16), "Bearer synthetic-secret-token", "synthetic\nprovider\ttext"} {
		t.Run(hidden, func(t *testing.T) {
			_ = claudeTestPaths(t)
			cache := t.TempDir()
			productionConsent(t, "claude", true)
			productionConsent(t, "copilot", true)
			paths := func() Paths { return ProductionPaths(cache, "1.0.0") }
			at := claudeTestNow
			used := 83.125
			account := &Account{Source: hidden, Plan: hidden, Via: hidden, ObservedAt: at, Subscription: &Binding{Ref: hidden, Status: hidden, Basis: hidden}, Windows: []Window{{Kind: hidden, Limit: hidden, UnknownReason: hidden, UsedPercent: &used}}}
			for _, status := range []string{"ok", hidden} {
				s := &readerState{SchemaVersion: 1, Provider: "claude", GrantKey: hidden, Entries: []readerEntry{{ProfileKey: hidden, Status: status, ErrorCode: hidden, Notice: hidden, NextStep: hidden, Metadata: readerMetadata{CredentialKey: hidden, AccountKey: hidden, OrganizationKey: hidden, Plan: hidden, ScopeKey: hidden}, Account: account}}}
				if err := saveReaderState(cache, s); err != nil {
					t.Fatal(err)
				}
				state := loadCopilotState(cache)
				ctx := productionReaderContext(context.Background(), paths(), "copilot")
				access, _ := copilotAdmission(ctx)
				state.LoginGeneration = access.LoginGeneration
				state.GoodGeneration = access.LoginGeneration
				state.Availability = status
				state.Good = &codexbarEntry{Provider: hidden, Plan: hidden, Error: hidden, Status: status, ObservedAt: at, Windows: account.Windows}
				if !saveCopilotState(cache, state) {
					t.Fatal("save synthetic runtime cache")
				}
				rows := ReaderDiagnostics(paths(), at)
				b, _ := json.Marshal(rows)
				var wire []map[string]any
				if err := json.Unmarshal(b, &wire); err != nil {
					t.Fatal(err)
				}
				for _, row := range wire {
					if len(row) != 8 {
						t.Fatal("new output field needs privacy review", row)
					}
					for key, value := range row {
						switch key {
						case "provider":
							id := value.(string)
							if nativeReaders[id] == nil && id != "claude:session" {
								found := false
								for _, tool := range localusage.HistoryProviders() {
									if id == tool+":history" {
										found = true
									}
								}
								if !found {
									t.Fatal("noncompiled identifier", id)
								}
							}
						case "detected", "admitted":
							if value != "yes" && value != "no" {
								t.Fatal(row)
							}
						case "consent":
							if value != "none" && value != "granted" && value != "denied" {
								t.Fatal(row)
							}
						case "state":
							if !regexp.MustCompile(`^(ok|stale|not_supported_yet|unavailable:(denied|consent_required|privacy_blocked|not_detected|rate_limited|login_expired|confirmation_needed|partial|not_read|reader_error|no_key|update_required|catalogue_off|not_admitted|config_unavailable|cache_unavailable)(:(file_missing|file_unreadable|parse_error|schema_changed|http_401|http_403|http_429|http_5xx|network|timeout|runtime_missing|unsupported_login|other))?)$`).MatchString(value.(string)) {
								t.Fatal("unreviewed state", row)
							}
						case "last":
							if !regexp.MustCompile(`^(unknown|[0-9]+s)$`).MatchString(value.(string)) {
								t.Fatal(row)
							}
						case "windows":
							if value != float64(0) && value != float64(1) {
								t.Fatal("quota value leaked", row)
							}
						case "beta":
							if _, ok := value.(bool); !ok {
								t.Fatal(row)
							}
						default:
							t.Fatal("unreviewed field", key)
						}
					}
				}
				// JSON escapes whitespace and backslashes, so compare decoded strings too.
				for _, r := range rows {
					for _, v := range []string{r.Provider, r.Detected, r.Consent, r.Admitted, r.State, r.Last} {
						if strings.Contains(v, hidden) {
							t.Fatal("identifier leaked", hidden, string(b))
						}
					}
				}
				if strings.Contains(string(b), "83.125") {
					t.Fatal("quota numbers leaked")
				}
			}
		})
	}
}

func TestDoctorReadersStateAgesAndHistory(t *testing.T) {
	_ = claudeTestPaths(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	productionConsent(t, "claude", true)
	productionConsent(t, "amp", true)
	root := filepath.Join(os.Getenv("XDG_DATA_HOME"), "amp", "threads")
	if err := os.MkdirAll(root, 0700); err != nil {
		t.Fatal(err)
	}
	at := claudeTestNow
	body := `{"id":"synthetic","messages":[{"role":"assistant","messageId":1,"usage":{"model":"amp-test","timestamp":"` + at.Format(time.RFC3339) + `","inputTokens":87123,"outputTokens":2}}]}`
	file := filepath.Join(root, "T-synthetic.json")
	if err := os.WriteFile(file, []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	// The foreground sweep reads both the account and the history only through
	// production construction; deny all network with the injected local fixture.
	status, requests := 200, []string{}
	claudeTestServer(t, &status, &requests)
	if err := RefreshReaderDiagnostics(context.Background(), ProductionPaths(cache, "1.0.0"), at); err != nil {
		t.Fatal(err)
	}
	r := diagnosticRow(t, ReaderDiagnostics(ProductionPaths(cache, "1.0.0"), at), "amp:history")
	if r.Detected != "yes" || r.Admitted != "yes" || r.Consent != "granted" || r.State != "ok" || r.Windows != 0 || r.Last != "0s" {
		t.Fatal(r)
	}
	if err := os.WriteFile(file, []byte(`{"messages":[]}`), 0600); err != nil {
		t.Fatal(err)
	}
	_ = RefreshReaderDiagnostics(context.Background(), ProductionPaths(cache, "1.0.0"), at.Add(time.Minute))
	r = diagnosticRow(t, ReaderDiagnostics(ProductionPaths(cache, "1.0.0"), at.Add(time.Minute)), "amp:history")
	if r.State != "ok" || r.Last != "60s" {
		t.Fatal("history floor bypassed", r)
	}
	for _, tc := range []struct {
		status string
		age    time.Duration
		want   string
	}{{"ok", 2 * time.Hour, "stale"}, {"expired", time.Minute, "unavailable:login_expired"}, {"unsupported_schema", time.Minute, "not_supported_yet"}, {"keychain-confirmation-needed", time.Minute, "unavailable:confirmation_needed"}} {
		s, _ := loadReaderState(cache, "claude")
		s.Entries[0].Status = tc.status
		s.Entries[0].Account.ObservedAt = at.Add(-tc.age)
		if err := saveReaderState(cache, s); err != nil {
			t.Fatal(err)
		}
		r = diagnosticRow(t, ReaderDiagnostics(ProductionPaths(cache, "1.0.0"), at), "claude")
		if r.State != tc.want {
			t.Fatal(tc, r)
		}
	}
}

func TestDoctorReadersForegroundKeychainAndSharedDeny(t *testing.T) {
	_ = claudeTestPaths(t)
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	t.Setenv("MODELPLAN_HISTORY", "off")
	home, _ := os.UserHomeDir()
	if err := os.MkdirAll(filepath.Join(home, ".claude"), 0700); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	productionConsent(t, "claude", true)
	calls := 0
	old := claudeSecurity
	t.Cleanup(func() { claudeSecurity = old })
	claudeSecurity = func(ctx context.Context, bin string, args ...string) (keychain.ProcessResult, error) {
		calls++
		deadline, ok := ctx.Deadline()
		// Managed read's overall timeout caps interactive Keychain's 30s deadline.
		if bin != "/usr/bin/security" || !ok || time.Until(deadline) <= keychain.BackgroundTimeout {
			t.Fatal("not interactive", bin, deadline)
		}
		return keychain.ProcessResult{ExitCode: 128}, nil
	}
	p := ProductionPaths(cache, "1.0.0")
	_ = ReaderDiagnostics(p, claudeTestNow)
	if calls != 0 || p.ReaderAccess.Grants["claude"].Interactive {
		t.Fatal("cache read prompted or mutated policy")
	}
	if err := RefreshReaderDiagnostics(context.Background(), p, claudeTestNow); err != nil {
		t.Fatal(err)
	}
	row := diagnosticRow(t, ReaderDiagnostics(ProductionPaths(cache, "1.0.0"), claudeTestNow), "claude")
	if calls != 1 || row.State != "unavailable:denied" {
		t.Fatal(calls, row)
	}
	if err := consent.Deny(consent.Path(), "claude", "keychain"); err != nil {
		t.Fatal(err)
	}
	_ = RefreshReaderDiagnostics(context.Background(), ProductionPaths(cache, "1.0.0"), claudeTestNow.Add(time.Hour))
	if calls != 1 {
		t.Fatal("shared Deny prompted again")
	}
}

func TestDoctorReadersExplicitConsentWithoutKey(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "")
	t.Setenv("Z_AI_API_KEY", "")
	cache := t.TempDir()
	p := ProductionPaths(cache, "1.0.0")
	body := []byte(`{"schemaVersion":1,"quotaSources":[{"provider":"zai","backend":"native","enabled":true}]}`)
	if err := os.MkdirAll(filepath.Dir(p.ConnectionsFile), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p.ConnectionsFile, body, 0600); err != nil {
		t.Fatal(err)
	}
	row := diagnosticRow(t, ReaderDiagnostics(ProductionPaths(cache, "1.0.0"), claudeTestNow), "zai")
	if row.Consent != "granted" || row.Admitted != "no" || row.State != "unavailable:no_key" {
		t.Fatal(row)
	}
}
