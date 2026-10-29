// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func assertReaderCode(t *testing.T, p Paths, at time.Time, id, want string) {
	t.Helper()
	r := diagnosticRow(t, ReaderDiagnostics(p, at), id)
	if r.State != "unavailable:reader_error:"+want {
		t.Fatalf("%s: want %s, got %+v", id, want, r)
	}
	report := ReadPermitted(p, at)
	for _, s := range report.Sources {
		if s.Source == "native:"+id {
			if s.ErrorCode != want {
				t.Fatalf("source code lost: %+v", s)
			}
			return
		}
	}
	t.Fatal("native source missing", id)
}

func TestNativeManagedReaderErrorCodes(t *testing.T) {
	for id, setup := range productionManagedTests {
		for _, code := range []string{"file_missing", "file_unreadable", "parse_error", "http_401", "http_403", "http_429", "http_5xx", "network", "timeout", "schema_changed", "other", "unsupported_login", "response_parse_error"} {
			t.Run(id+"/"+code, func(t *testing.T) {
				at, _ := setup(t)
				t.Setenv("MODELPLAN_HISTORY", "off")
				productionConsent(t, id, true)
				cache := t.TempDir()
				paths := func() Paths { return ProductionPaths(cache, "1.0.0") }
				p := paths()
				g, ok := p.ReaderAccessGrant(id)
				if !ok || len(g.Profiles) != 1 {
					t.Fatal("production profile missing")
				}
				names := map[string]string{"claude": ".credentials.json", "cursor": "state.vscdb", "gemini": "oauth_creds.json", "grok": "auth.json", "kimi": "credentials/kimi-code.json"}
				file := filepath.Join(g.Profiles[0].Root, names[id])
				if g.Profiles[0].AccountFile != "" && id == "grok" {
					file = g.Profiles[0].AccountFile
				}
				switch code {
				case "file_missing", "file_unreadable", "parse_error", "unsupported_login":
					if err := os.Remove(file); err != nil {
						t.Fatal(err)
					}
					if code == "file_unreadable" {
						if err := os.Mkdir(file, 0700); err != nil {
							t.Fatal(err)
						}
					}
					if code == "parse_error" || code == "unsupported_login" {
						body := []byte("synthetic invalid JSON")
						if code == "unsupported_login" {
							body = []byte(`{}`)
						}
						if id == "cursor" && code == "unsupported_login" {
							cursorDB(t, "synthetic-unsupported-token", false)
						} else if err := os.WriteFile(file, body, 0600); err != nil {
							t.Fatal(err)
						}
					}
				default:
					old := nativeClient
					t.Cleanup(func() { nativeClient = old })
					nativeClient = &http.Client{Transport: productionTransport(func(*http.Request) (*http.Response, error) {
						if code == "network" {
							return nil, errors.New("synthetic.person@example.invalid /Users/private token")
						}
						if code == "timeout" {
							return nil, context.DeadlineExceeded
						}
						status := map[string]int{"http_401": 401, "http_403": 403, "http_429": 429, "http_5xx": 503, "other": 418}[code]
						if status == 0 {
							status = 200
						}
						return &http.Response{StatusCode: status, Header: http.Header{}, Body: io.NopCloser(strings.NewReader(func() string {
							if code == "response_parse_error" {
								return "synthetic invalid response"
							}
							return `{}`
						}()))}, nil
					})}
				}
				if err := RefreshNative(context.Background(), p, at); err != nil {
					t.Fatal(err)
				}
				want := code
				if code == "response_parse_error" {
					want = "parse_error"
				}
				assertReaderCode(t, paths(), at, id, want)
				// Reloading and an early foreground request preserve the same provenance.
				if err := RefreshReaderDiagnostics(context.Background(), paths(), at.Add(time.Minute)); err != nil {
					t.Fatal(err)
				}
				assertReaderCode(t, paths(), at.Add(time.Minute), id, want)
			})
		}
	}
}

func TestNativeLegacyHTTPReaderErrorCodes(t *testing.T) {
	for _, id := range []string{"zai", "opencodego", "minimax"} {
		for _, code := range []string{"http_401", "http_403", "http_429", "http_5xx", "network", "timeout", "parse_error", "schema_changed", "other"} {
			t.Run(id+"/"+code, func(t *testing.T) {
				isolateHome(t)
				t.Setenv("MODELPLAN_READERS", "")
				t.Setenv("MODELPLAN_NATIVE", "")
				t.Setenv("MODELPLAN_HISTORY", "off")
				at, _ := productionLegacyTests[id](t)
				productionConsent(t, id, true)
				cache := t.TempDir()
				paths := func() Paths { return ProductionPaths(cache, "1.0.0") }
				old := nativeClient
				t.Cleanup(func() { nativeClient = old })
				nativeClient = &http.Client{Transport: productionTransport(func(*http.Request) (*http.Response, error) {
					if code == "network" {
						return nil, errors.New("synthetic secret")
					}
					if code == "timeout" {
						return nil, context.DeadlineExceeded
					}
					status := map[string]int{"http_401": 401, "http_403": 403, "http_429": 429, "http_5xx": 500, "other": 418}[code]
					if status == 0 {
						status = 200
					}
					body := `{}`
					if code == "parse_error" {
						body = "not JSON synthetic secret"
					}
					return &http.Response{StatusCode: status, Header: http.Header{}, Body: io.NopCloser(strings.NewReader(body))}, nil
				})}
				if err := RefreshNative(context.Background(), paths(), at); err != nil {
					t.Fatal(err)
				}
				assertReaderCode(t, paths(), at, id, code)
			})
		}
	}
}

func TestNativeRuntimeReaderErrorCodes(t *testing.T) {
	for _, id := range []string{"kiro", "copilot", "antigravity"} {
		t.Run(id+"/runtime_missing", func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_READERS", "")
			t.Setenv("MODELPLAN_NATIVE", "")
			t.Setenv("MODELPLAN_HISTORY", "off")
			at, _ := productionLegacyTests[id](t)
			switch id {
			case "kiro":
				t.Setenv("MODELPLAN_KIRO", filepath.Join(t.TempDir(), "missing-runtime"))
			case "copilot":
				t.Setenv("MODELPLAN_COPILOT", filepath.Join(t.TempDir(), "missing-runtime"))
			case "antigravity":
				old := antigravityCommand
				t.Cleanup(func() { antigravityCommand = old })
				antigravityCommand = func(context.Context, string, ...string) ([]byte, error) {
					return nil, errors.New("synthetic private path")
				}
			}
			productionConsent(t, id, true)
			p := ProductionPaths(t.TempDir(), "1.0.0")
			if err := RefreshNative(context.Background(), p, at); err != nil {
				t.Fatal(err)
			}
			assertReaderCode(t, p, at, id, "runtime_missing")
		})
	}
	for _, id := range []string{"kiro", "copilot", "antigravity"} {
		t.Run(id+"/parse_error", func(t *testing.T) {
			var e codexbarEntry
			switch id {
			case "kiro":
				e = parseKiro(json.RawMessage("invalid synthetic JSON"), time.Now())
			case "copilot":
				e = parseCopilot(json.RawMessage("invalid synthetic JSON"), time.Now())
			case "antigravity":
				e = parseAntigravity([]byte("invalid synthetic JSON"), time.Now())
			}
			if e.ErrorCode != "parse_error" {
				t.Fatal(e)
			}
		})
	}
}

func TestReaderErrorCodesRejectUntrustedText(t *testing.T) {
	for _, hidden := range []string{"person@example.invalid", "acct_synthetic_314159", "/Users/Synthetic/private.json", `C:\Users\Synthetic\token`, strings.Repeat("ae", 32), "http_401\nsecret"} {
		if ReaderErrorCode(hidden) != "other" || nativeDiagnosticState("unavailable", hidden) != "unavailable:reader_error:other" {
			t.Fatal("untrusted code escaped")
		}
	}
}

func TestConfiguredZaiFileErrorCodes(t *testing.T) {
	for _, code := range []string{"file_missing", "file_unreadable", "parse_error"} {
		t.Run(code, func(t *testing.T) {
			isolateHome(t)
			file := filepath.Join(t.TempDir(), "settings.json")
			if code == "file_unreadable" {
				if err := os.Mkdir(file, 0700); err != nil {
					t.Fatal(err)
				}
			}
			if code == "parse_error" {
				if err := os.WriteFile(file, []byte("invalid synthetic JSON"), 0600); err != nil {
					t.Fatal(err)
				}
			}
			ctx := context.WithValue(context.Background(), zaiConfigSourceKey{}, ZaiConfigSource{Tool: "claude-code", SettingsPath: file, Region: "global"})
			e := fetchZaiConfig(ctx, nil, "", "", time.Now())
			if e.ErrorCode != code {
				t.Fatalf("want %s: %+v", code, e)
			}
		})
	}
}

func TestCursorAdmissionKeepsProfileAndCatalogueSafetyGates(t *testing.T) {
	for _, mode := range []string{"off", "passive", "native_off", "catalogue_off", "catalogue_helper", "catalogue_newer", "profile_symlink", "profile_file"} {
		t.Run(mode, func(t *testing.T) {
			_, _ = cursorAdmittedPaths(t)
			productionConsent(t, "cursor", true)
			cache := t.TempDir()
			switch mode {
			case "off", "passive":
				t.Setenv("MODELPLAN_READERS", mode)
			case "native_off":
				t.Setenv("MODELPLAN_NATIVE", "off")
			case "profile_symlink", "profile_file":
				root := cursorProfiles()[0].Root
				if err := os.RemoveAll(root); err != nil {
					t.Fatal(err)
				}
				if mode == "profile_symlink" {
					if err := os.Symlink(t.TempDir(), root); err != nil {
						t.Fatal(err)
					}
				} else {
					if err := os.WriteFile(root, []byte("synthetic"), 0600); err != nil {
						t.Fatal(err)
					}
				}
			default:
				route := detect.Entry{ProviderID: "cursor", ReaderID: "native:cursor", Preferred: "native", MinCLI: "0.0.0"}
				if mode == "catalogue_off" {
					route.Preferred = "off"
				}
				if mode == "catalogue_helper" {
					route.Preferred = "codexbar"
				}
				if mode == "catalogue_newer" {
					route.MinCLI = "999.0.0"
				}
				old := loadReaderCatalogue
				t.Cleanup(func() { loadReaderCatalogue = old })
				loadReaderCatalogue = func(string) *detect.Catalogue { return &detect.Catalogue{Detectors: []detect.Entry{route}} }
			}
			if _, ok := ProductionPaths(cache, "1.0.0").ReaderAccessGrant("cursor"); ok {
				t.Fatal("Cursor safety gate bypassed", mode)
			}
		})
	}
}

func TestKiroErrorCodesPreserveStartupBannerTolerance(t *testing.T) {
	isolateHome(t)
	bin, _ := fakeKiro(t, kiroUsage)
	body, err := os.ReadFile(bin)
	if err != nil {
		t.Fatal(err)
	}
	body = []byte(strings.Replace(string(body), "#!/bin/sh\n", "#!/bin/sh\necho 'synthetic startup banner'\n", 1))
	if err := os.WriteFile(bin, body, 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_KIRO", bin)
	e := fetchKiro(context.Background(), nil, "", "", time.Now())
	if e.Status != "ok" || e.ErrorCode != "" {
		t.Fatal(e)
	}
}
