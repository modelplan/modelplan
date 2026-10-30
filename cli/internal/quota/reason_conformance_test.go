// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/testenv"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type reasonArtifact struct {
	writer string
	value  any
}

// Validate actual fields/returned errors, not a copy supplied by the fixture.
// No secret substring, including the historical canaries, affects acceptance.
func readerReasonViolation(a reasonArtifact) error {
	if err := testenv.CheckReaderReasons(a.value); err != nil {
		return fmt.Errorf("%s: %w", a.writer, err)
	}
	return nil
}
func captureReaderReasonLogs(t *testing.T) func() {
	check := testenv.CaptureReasonLogs(t)
	return func() {
		if err := check(); err != nil {
			t.Error(err)
		}
	}
}
func readerFailureSource(t *testing.T, r Report, id string) SourceStatus {
	t.Helper()
	for _, source := range r.Sources {
		if source.Source == "native:"+id {
			return source
		}
	}
	t.Fatal("reader failure source missing", id)
	return SourceStatus{}
}

func TestReaderReasonGuardRejectsMinimalBadWriters(t *testing.T) {
	for _, canary := range runtimeErrorCanaries {
		raw := errors.New(canary)
		for _, bad := range []reasonArtifact{
			{writer: "persisted reason", value: SourceStatus{Reason: raw.Error()}},
			{writer: "non-code without canary", value: SourceStatus{Reason: "arbitrary vendor prose"}},
			{writer: "retained error", value: raw},
			{writer: "log line", value: fmt.Sprintf("reader: %v", raw)},
			{writer: "JSON", value: []byte(fmt.Sprintf(`{"error":%q}`, canary))},
		} {
			if readerReasonViolation(bad) == nil {
				t.Fatal("guard accepted minimal bad writer", bad.writer)
			}
		}
	}
}
func TestReaderReasonWriterConformance(t *testing.T) {
	writers := map[string]func(*testing.T, string) []reasonArtifact{
		"vendor-zai": func(t *testing.T, text string) []reasonArtifact {
			e := parseZai(zaiResponse{Msg: text}, acctNow)
			return []reasonArtifact{{writer: "Z.ai returned entry", value: e}}
		},
		"vendor-codexbar": func(t *testing.T, text string) []reasonArtifact {
			raw, _ := json.Marshal([]any{map[string]any{"provider": "kiro", "error": map[string]any{"message": text}}})
			e := parseCodexBar(raw, "kiro", os.Getenv("HOME"), acctNow)
			cache := t.TempDir()
			s := &codexbarSnap{SchemaVersion: 1, ObservedAt: acctNow, Status: "ok", Providers: []codexbarEntry{e}}
			if err := saveCodexBar(cache, s); err != nil {
				t.Fatal(err)
			}
			b, err := os.ReadFile(codexbarPath(cache))
			if err != nil {
				t.Fatal(err)
			}
			return []reasonArtifact{{writer: "CodexBar returned entry", value: e}, {writer: "CodexBar retained errors", value: b}}
		},
		"retained-codexbar": func(t *testing.T, text string) []reasonArtifact {
			p := cbPaths(t, "kiro")
			var artifacts []reasonArtifact
			for _, status := range []string{"ok", "error"} {
				snapshot := &codexbarSnap{SchemaVersion: 1, ObservedAt: acctNow, Status: status, Error: text, Providers: []codexbarEntry{{Provider: "kiro", Status: "error", ObservedAt: acctNow, Error: text, ErrorCode: text}}}
				if err := saveCodexBar(p.Cache, snapshot); err != nil {
					t.Fatal(err)
				}
				report := Report{}
				applyCodexBar(&report, p, acctNow)
				if len(report.Sources) != 1 {
					t.Fatal("retained CodexBar error was not projected")
				}
				artifacts = append(artifacts, reasonArtifact{writer: "CodexBar retained " + status + " JSON", value: report})
			}
			return artifacts
		},
		"retained-fetch": func(t *testing.T, text string) []reasonArtifact {
			cache := t.TempDir()
			path := codexbarFetchMark(cache)
			if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(path, []byte(CodexBarVersion+" failed: download failed: "+text+"\n"), 0600); err != nil {
				t.Fatal(err)
			}
			return []reasonArtifact{{writer: "retained fetch result", value: testenv.FetchReason(CodexBarFetchResult(cache))}}
		},
		"download-codexbar": func(t *testing.T, text string) []reasonArtifact {
			cache := t.TempDir()
			_, err := FetchCodexBar(context.Background(), cache, "https://"+text+"/%zz")
			if err == nil {
				t.Fatal("invalid URL unexpectedly fetched")
			}
			return []reasonArtifact{{writer: "fetch returned error", value: err}, {writer: "fetch retained mark", value: testenv.FetchReason(CodexBarFetchResult(cache))}, {writer: "fetch log", value: fmt.Sprint(err)}}
		},
		"connections-read": func(t *testing.T, text string) []reasonArtifact {
			p := nativePaths(t)
			p.ConnectionsFile = filepath.Join(t.TempDir(), text, "connections.json")
			if err := os.MkdirAll(p.ConnectionsFile, 0700); err != nil {
				t.Fatal(err)
			}
			r := Report{}
			applyNative(&r, p, acctNow)
			if len(r.Sources) == 0 {
				t.Fatal("missing connections failure")
			}
			return []reasonArtifact{{writer: "connections JSON", value: r}}
		},
	}
	for name, writer := range writers {
		for index, canary := range append(append([]string{}, runtimeErrorCanaries...), "arbitrary vendor prose") {
			t.Run(fmt.Sprintf("%s/%d", name, index), func(t *testing.T) {
				isolateHome(t)
				defer captureReaderReasonLogs(t)()
				for _, artifact := range writer(t, canary) {
					if err := readerReasonViolation(artifact); err != nil {
						t.Error(err)
					}
				}
			})
		}
	}
}

// Every registered native HTTP reader must keep the production transport,
// dispatcher, retained cache and read-back projection in this table. Adding a
// reader without an error fixture is a failure, not an implicit exemption.
func TestReaderReasonRegisteredHTTPConformance(t *testing.T) {
	runtimeCases := map[string]bool{"kiro": true, "copilot": true, "antigravity": true}
	for id := range nativeReaders {
		if runtimeCases[id] {
			continue
		} // Separate actual-runtime tables below/in runtime_error_output_test.go.
		setup := productionManagedTests[id]
		if setup == nil {
			setup = productionLegacyTests[id]
		}
		if setup == nil {
			t.Fatalf("registered reader %s has no reason conformance fixture", id)
		}
		for _, mode := range []string{"transport-error", "vendor-body-403", "vendor-body-200"} {
			t.Run(id+"/"+mode, func(t *testing.T) {
				isolateHome(t)
				defer captureReaderReasonLogs(t)()
				t.Setenv("MODELPLAN_HISTORY", "off")
				at, _ := setup(t)
				productionConsent(t, id, true)
				text := strings.Join(runtimeErrorCanaries, " | ")
				previous := nativeClient
				t.Cleanup(func() { nativeClient = previous })
				nativeClient = &http.Client{Transport: productionTransport(func(*http.Request) (*http.Response, error) {
					if mode == "transport-error" {
						return nil, errors.New(text)
					}
					body, _ := json.Marshal(map[string]any{"success": false, "message": text, "msg": text, "error": map[string]any{"message": text}})
					status := 403
					if mode == "vendor-body-200" {
						status = 200
					}
					return &http.Response{StatusCode: status, Header: http.Header{}, Body: io.NopCloser(strings.NewReader(string(body)))}, nil
				})}
				cache := t.TempDir()
				p := ProductionPaths(cache, "1.0.0")
				if err := RefreshNative(context.Background(), p, at); err != nil {
					t.Fatal(err)
				}
				report := ReadPermitted(p, at)
				found := false
				for _, source := range report.Sources {
					if source.Source == "native:"+id {
						found = true
						if source.ErrorCode == "" || source.ErrorCode != ReaderErrorCode(source.ErrorCode) || source.Reason != source.ErrorCode {
							t.Error("failure lost fixed reason code")
						}
					}
				}
				if !found {
					t.Fatal("reader failure was not projected")
				}
				if err := RefreshNative(context.Background(), p, at.Add(time.Minute)); err != nil {
					t.Fatal(err)
				}
				assertRuntimeCacheSafe(t, cache)
				for _, artifact := range []reasonArtifact{{writer: "report JSON", value: readerFailureSource(t, report, id)}, {writer: "retained report JSON", value: readerFailureSource(t, ReadPermitted(p, at.Add(time.Minute)), id)}, {writer: "diagnostics JSON", value: ReaderDiagnostics(p, at)}} {
					if err := readerReasonViolation(artifact); err != nil {
						t.Error(err)
					}
				}
			})
		}
	}
}

func TestReaderReasonRuntimeConformance(t *testing.T) {
	fixtures := map[string]func(*testing.T, string){
		"kiro": func(t *testing.T, text string) {
			t.Setenv("MODELPLAN_KIRO", runtimeErrorChild(t, 2, false, text, kiroUsage))
		},
		"copilot": func(t *testing.T, text string) {
			bin, _ := fakeCopilot(t)
			t.Setenv("MODELPLAN_COPILOT", bin)
			t.Setenv("MODELPLAN_TEST_COPILOT_ERROR_MESSAGE", text)
		},
		"antigravity": func(t *testing.T, text string) {
			previous := antigravityCommand
			t.Cleanup(func() { antigravityCommand = previous })
			antigravityCommand = func(context.Context, string, ...string) ([]byte, error) { return nil, errors.New(text) }
		},
	}
	for id, setup := range fixtures {
		if nativeReaders[id] == nil {
			t.Fatal("runtime fixture no longer names a registered reader", id)
		}
		for index, canary := range append(append([]string{}, runtimeErrorCanaries...), "arbitrary vendor prose") {
			t.Run(fmt.Sprintf("%s/%d", id, index), func(t *testing.T) {
				isolateHome(t)
				defer captureReaderReasonLogs(t)()
				t.Setenv("MODELPLAN_HISTORY", "off")
				setup(t, canary)
				productionConsent(t, id, true)
				n := nativeReaders[id]
				e := n.Fetch(context.Background(), nativeClient, "local", "", acctNow)
				if e.Status == "ok" || e.ErrorCode == "" || ReaderErrorCode(e.ErrorCode) != e.ErrorCode {
					t.Fatal("runtime did not return a coded failure")
				}
				// Fixed transient remedies are not persisted; inspect the actual
				// dispatcher's retained error/code fields below.

				cache := t.TempDir()
				p := ProductionPaths(cache, "1.0.0")
				if err := RefreshNative(context.Background(), p, acctNow); err != nil {
					t.Fatal(err)
				}
				assertRuntimeCacheSafe(t, cache)
				for _, artifact := range []reasonArtifact{
					{writer: "runtime report JSON", value: readerFailureSource(t, ReadPermitted(p, acctNow), id)},
					{writer: "runtime diagnostics JSON", value: ReaderDiagnostics(p, acctNow)},
				} {
					if err := readerReasonViolation(artifact); err != nil {
						t.Error(err)
					}
				}
			})
		}
	}
}
