// SPDX-License-Identifier: MIT
package readers_test

import (
	"errors"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/readers"
	"github.com/modelplan/modelplan/cli/internal/readers/readertest"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func send(c *http.Client, method, endpoint string) error {
	req, err := http.NewRequest(method, endpoint, nil)
	if err != nil {
		return err
	}
	resp, err := c.Do(req)
	if resp != nil {
		resp.Body.Close()
	}
	return err
}

func checkRequests(got, want []readertest.Request) error {
	if len(got) == 0 && len(want) == 0 {
		return nil
	}
	if !reflect.DeepEqual(got, want) {
		return fmt.Errorf("outbound requests: got %+v, want %+v", got, want)
	}
	return nil
}

// Red line: unapproved POST account-usage scopes emit zero remote calls, even
// with consent. Failing example: the old saved-login path posts to plan/quota.
func TestAdmissionRedLineUnapprovedPOSTMakesZeroRemoteCalls(t *testing.T) {
	for _, tc := range []struct {
		name, scope string
		endpoints   []string
	}{
		{"gemini-code-assist", consent.ScopeGeminiAccountUsageSavedLogin, []string{"https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist", "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"}},
		{"cursor-plan-and-period", consent.ScopeCursorAccountUsageSavedLogin, []string{"https://cursor.com/api/dashboard/get-plan-info", "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage"}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if !errors.Is(readers.CheckAdmission(tc.scope), readers.ErrPolicyPending) {
				t.Fatal("POST scope admitted")
			}
			record := readertest.NewTransport()
			client := &http.Client{Transport: readers.NewReadTransport(tc.scope, record)}
			for _, endpoint := range tc.endpoints {
				for _, method := range []string{http.MethodPost, http.MethodGet} {
					if err := send(client, method, endpoint); !errors.Is(err, readers.ErrPolicyPending) {
						t.Fatalf("expected policy_pending: %v", err)
					}
				}
			}
			if err := checkRequests(record.Requests(), nil); err != nil {
				t.Fatal(err)
			}
			// Negative control: the same requests without admission trip the oracle.
			legacy := readertest.NewTransport(readertest.Response{StatusCode: 200}, readertest.Response{StatusCode: 200})
			for _, endpoint := range tc.endpoints {
				if err := send(&http.Client{Transport: legacy}, http.MethodPost, endpoint); err != nil {
					t.Fatal(err)
				}
			}
			if err := checkRequests(legacy.Requests(), nil); err == nil {
				t.Fatal("failing example escaped recording")
			}
		})
	}
}

// Red line: no further request for a scope after HTTP 401/403. Failing example:
// MiniMax retries its legacy endpoint, even if that endpoint could succeed.
func TestAdmissionRedLineMiniMaxStopsOn401Or403(t *testing.T) {
	for _, host := range []string{"api.minimax.io", "api.minimaxi.com"} {
		for _, status := range []int{401, 403} {
			t.Run(fmt.Sprintf("%s/%d", host, status), func(t *testing.T) {
				responses := []readertest.Response{{StatusCode: status}, {StatusCode: 200, Body: `{}`}}
				record := readertest.NewTransport(responses...)
				client := &http.Client{Transport: readers.NewReadTransport(consent.ScopeMiniMaxAccountUsageAPIKey, record)}
				current, legacy := "https://"+host+"/v1/token_plan/remains", "https://"+host+"/v1/api/openplatform/coding_plan/remains"
				if err := send(client, http.MethodGet, current); err != nil {
					t.Fatal(err)
				}
				for _, endpoint := range []string{legacy, current} {
					if err := send(client, http.MethodGet, endpoint); !errors.Is(err, readers.ErrAuthorizationStopped) {
						t.Fatalf("retry admitted: %v", err)
					}
				}
				want := []readertest.Request{{Method: "GET", Host: host, Path: "/v1/token_plan/remains"}}
				if err := checkRequests(record.Requests(), want); err != nil {
					t.Fatal(err)
				}
				unguarded := readertest.NewTransport(responses...)
				for _, endpoint := range []string{current, legacy} {
					if err := send(&http.Client{Transport: unguarded}, http.MethodGet, endpoint); err != nil {
						t.Fatal(err)
					}
				}
				if err := checkRequests(unguarded.Requests(), want); err == nil {
					t.Fatal("legacy retry escaped recording")
				}
			})
		}
	}
}

// Admission is per path: blocking a tool's POST scope must preserve its local
// history scope. Failing example: a vendor-wide deny rejects local history too.
func TestAdmissionLocalHistorySurvivesRemotePOSTGate(t *testing.T) {
	for _, tc := range []struct{ local, remote string }{
		{consent.ScopeGeminiLocalHistory, consent.ScopeGeminiAccountUsageSavedLogin},
		{consent.ScopeCursorLocalHistory, consent.ScopeCursorAccountUsageSavedLogin},
	} {
		if err := readers.CheckAdmission(tc.remote); !errors.Is(err, readers.ErrPolicyPending) {
			t.Fatal(err)
		}
		if err := readers.CheckAdmission(tc.local); err != nil {
			t.Fatalf("local history blocked: %v", err)
		}
		// A local grant must never become an HTTP capability.
		record := readertest.NewTransport()
		if err := send(&http.Client{Transport: readers.NewReadTransport(tc.local, record)}, "GET", "https://api.minimax.io/v1/token_plan/remains"); !errors.Is(err, readers.ErrRequestNotAllowed) {
			t.Fatal(err)
		}
		if err := checkRequests(record.Requests(), nil); err != nil {
			t.Fatal(err)
		}
	}
	// Exercise the existing Gemini decoder through its opt-in local history path.
	// Cursor has a stable local scope but no count adapter on this source base.
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	for _, env := range []string{"MODELPLAN_READERS", "MODELPLAN_GEMINI", "MODELPLAN_HISTORY", "MODELPLAN_GEMINI_HOME"} {
		t.Setenv(env, "")
	}
	if err := localusage.SetGemini(home, true); err != nil {
		t.Fatal(err)
	}
	file := filepath.Join(home, ".gemini", "tmp", "synthetic-project", "chats", "session-synthetic.json")
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		t.Fatal(err)
	}
	body := `{"sessionId":"synthetic-session","projectHash":"synthetic-project","messages":[{"id":"synthetic-message","type":"gemini","timestamp":"2026-10-29T10:00:00Z","model":"gemini-test","tokens":{"input":10,"output":2,"total":12}}]}`
	if err := os.WriteFile(file, []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	now := time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC)
	read := func(admit func(string) error) (localusage.Report, error) {
		if err := admit(consent.ScopeGeminiLocalHistory); err != nil {
			return localusage.Report{}, err
		}
		return localusage.ReadGemini(home, now), nil
	}
	result, err := read(readers.CheckAdmission)
	if err != nil || result.Status != "ok" || len(result.Rows) != 1 || result.Rows[0].Total == nil || *result.Rows[0].Total != 12 {
		t.Fatalf("local history lost: %+v, %v", result, err)
	}
	// Negative control: a tool-wide POST deny drops the same seeded history.
	result, err = read(func(string) error { return readers.ErrPolicyPending })
	if err == nil || len(result.Rows) != 0 {
		t.Fatal("vendor-wide failing example did not lose history")
	}
}
