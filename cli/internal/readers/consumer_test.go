// SPDX-License-Identifier: MIT
package readers_test

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/readers"
	"github.com/modelplan/modelplan/cli/internal/readers/readertest"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// Qualified consumer: the existing dispatcher and decoder run unchanged with
// the new transport supplied by this interface-stage harness. Production
// admission wiring is a separate stage; this test does not claim it is enabled.
func runMiniMax(t *testing.T, transport http.RoundTripper, region string) string {
	t.Helper()
	testenv.IsolateHome(t)
	for _, env := range []string{"MODELPLAN_READERS", "MODELPLAN_NATIVE", "MODELPLAN_IDENTITY"} {
		t.Setenv(env, "")
	}
	t.Setenv("MINIMAX_CODING_API_KEY", "synthetic-minimax-key")
	old := http.DefaultTransport
	http.DefaultTransport = transport
	defer func() { http.DefaultTransport = old }()
	root := t.TempDir()
	paths := quota.Paths{Cache: filepath.Join(root, "cache"), ConnectionsFile: filepath.Join(root, "connections.json"), CodexBarFile: filepath.Join(root, "codexbar.json")}
	if err := quota.SetConnection(paths.ConnectionsFile, quota.QuotaSource{Provider: "minimax", Backend: quota.BackendNative, Enabled: true, Region: region}); err != nil {
		t.Fatal(err)
	}
	if err := quota.RefreshNative(context.Background(), paths, time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC)); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(paths.Cache, "observed", "native.json"))
	if err != nil {
		t.Fatal(err)
	}
	var result struct {
		Providers []struct {
			Status string `json:"status"`
		} `json:"providers"`
	}
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatal(err)
	}
	if len(result.Providers) != 1 {
		t.Fatalf("unexpected dispatcher result: %s", data)
	}
	return result.Providers[0].Status
}

// Red line: a real MiniMax collection must not send the legacy request after
// 401/403. The baseline dispatcher without the guard is the failing example.
func TestAdmissionMiniMaxRealConsumerStopsAfterRejection(t *testing.T) {
	for region, host := range map[string]string{"international": "api.minimax.io", "china": "api.minimaxi.com"} {
		for _, status := range []int{401, 403} {
			t.Run(fmt.Sprintf("%s/%d", region, status), func(t *testing.T) {
				record := readertest.NewTransport(readertest.Response{StatusCode: status}, readertest.Response{StatusCode: 200, Body: `{"model_remains":[{"model_name":"general","current_interval_remaining_percent":76}]}`})
				result := runMiniMax(t, readers.NewReadTransport(consent.ScopeMiniMaxAccountUsageAPIKey, record), region)
				want := []readertest.Request{{Method: "GET", Host: host, Path: "/v1/token_plan/remains"}}
				if err := checkRequests(record.Requests(), want); err != nil {
					t.Fatal(err)
				}
				if result != "error" {
					t.Fatalf("rejection became successful quota: %s", result)
				}
			})
		}
	}
}

// The actual decoder still accepts a valid quota capture through the guard.
func TestAdmissionMiniMaxRealConsumerAcceptsQuota(t *testing.T) {
	record := readertest.NewTransport(readertest.Response{StatusCode: 200, Body: `{"model_remains":[{"model_name":"general","current_interval_remaining_percent":76}]}`})
	if result := runMiniMax(t, readers.NewReadTransport(consent.ScopeMiniMaxAccountUsageAPIKey, record), "international"); result != "ok" {
		t.Fatalf("valid capture rejected: %s", result)
	}
	if err := checkRequests(record.Requests(), []readertest.Request{{Method: "GET", Host: "api.minimax.io", Path: "/v1/token_plan/remains"}}); err != nil {
		t.Fatal(err)
	}
}
