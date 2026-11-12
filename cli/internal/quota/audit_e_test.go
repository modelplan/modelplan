package quota

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

// Audit E finding 6: "usage" is both a percentage alias and a counter alias. With a limit beside it,
// it is a counter: 120 of 1000 is 12%, not a clamped 100%.
func TestAuditEOpenCodeGoUsageCounterIsNotAPercentage(t *testing.T) {
	isolateHome(t)
	for body, want := range map[string]float64{
		`{"usage":{"rolling":{"usage":120,"limit":1000}}}`:                   12,
		`{"usage":{"rolling":{"usage":30,"limit":120}}}`:                     25,
		`{"usage":{"rolling":{"usage":42}}}`:                                 42, // bare usage stays a percentage
		`{"usage":{"rolling":{"usagePercent":7,"usage":120,"limit":1000}}}`: 7,  // explicit percentage wins
	} {
		var r map[string]any
		if err := json.Unmarshal([]byte(body), &r); err != nil {
			t.Fatal(err)
		}
		e := parseOpenCodeGo(r, zaiNow)
		if e.Status != "ok" || len(e.Windows) != 1 || *e.Windows[0].UsedPercent != want {
			t.Errorf("%s: want %v%%, got %+v", body, want, e)
		}
	}
}

// Audit E finding 7: MiniMax body status 1004 on both endpoints is a rejected key, not a format change.
func TestAuditEMiniMaxAuthRejectionIsHTTP401(t *testing.T) {
	isolateHome(t)
	hits := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits++
		w.Write([]byte(`{"base_resp":{"status_code":1004}}`))
	}))
	defer srv.Close()
	e := fetchMiniMax(context.Background(), readerFixtureClient(t, srv, "api.minimax.io"), "international", "synthetic-key", minimaxNow)
	if hits != 2 || e.Status != "error" || e.ErrorCode != "http_401" {
		t.Fatalf("hits=%d entry=%+v", hits, e)
	}
	if mapped, _ := rows.MapSignal(rows.SignalError, e.ErrorCode); mapped.Code != rows.CodeHTTP401 {
		t.Errorf("row = %+v", mapped)
	}
	// Other vendor codes keep their compatibility meaning.
	if e, _ := parseMiniMax([]byte(`{"base_resp":{"status_code":1002}}`), minimaxNow); e.ErrorCode != "schema_changed" {
		t.Errorf("1002 = %+v", e)
	}
}

// Audit E finding 8: a signed-out Kiro is "Not signed in", not an unsupported saved sign-in.
func TestAuditEKiroSignedOutIsNotSignedIn(t *testing.T) {
	isolateHome(t)
	e := parseKiro(json.RawMessage(`{"success":false,"message":"User is not authenticated"}`), zaiNow)
	if e.Status != "error" || e.ErrorCode != "not_signed_in" {
		t.Fatalf("entry = %+v", e)
	}
	mapped, _ := rows.MapSignal(rows.SignalError, e.ErrorCode)
	if mapped.Code != rows.CodeNotSignedIn || mapped.Text.EN != "Not signed in" || mapped.Action != rows.ActionNone {
		t.Errorf("row = %+v", mapped)
	}
}
