package quota

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

// Audit E finding 6: "usage" is both a percentage alias and a counter alias. With a limit beside it,
// it is a counter: 120 of 1000 is 12%, not a clamped 100%.
func TestAuditEOpenCodeGoUsageCounterIsNotAPercentage(t *testing.T) {
	isolateHome(t)
	for body, want := range map[string]float64{
		`{"usage":{"rolling":{"usage":120,"limit":1000}}}`:                  12,
		`{"usage":{"rolling":{"usage":30,"limit":120}}}`:                    25,
		`{"usage":{"rolling":{"usage":42}}}`:                                42, // bare usage stays a percentage
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

type auditERoundTrip struct {
	base   http.RoundTripper
	before func(*http.Request)
}

func (a auditERoundTrip) RoundTrip(r *http.Request) (*http.Response, error) {
	a.before(r)
	return a.base.RoundTrip(r)
}
func (auditERoundTrip) ReaderSingleAttempt() {}

// Audit E finding 1: an unrelated Cursor state write while the usage request is in flight changes
// the store fingerprint but not the saved sign-in, so the reading is kept. A real sign-in change
// during the request still discards it.
func TestAuditECursorUnrelatedStateWriteKeepsTheReading(t *testing.T) {
	for _, tc := range []struct {
		name string
		edit func(db *sql.DB) error
		ok   bool
	}{
		{"unrelated", func(db *sql.DB) error {
			_, err := db.Exec(`INSERT OR REPLACE INTO ItemTable VALUES ('workbench.panel.width', ?)`, strings.Repeat("x", 8192))
			return err
		}, true},
		{"credential", func(db *sql.DB) error {
			_, err := db.Exec(`INSERT OR REPLACE INTO ItemTable VALUES ('cursorAuth/accessToken', ?)`, syntheticCursorToken("synthetic-other-account", cursorNow.Add(72*time.Hour)))
			return err
		}, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			p, token := cursorAdmittedPaths(t)
			mode, paths := "ok", []string{}
			cursorPeriodServer(t, token, &mode, &paths)
			home, _ := os.UserHomeDir()
			c := *nativeClient
			c.Transport = auditERoundTrip{base: nativeClient.Transport, before: func(r *http.Request) {
				if !strings.HasSuffix(r.URL.Path, "GetCurrentPeriodUsage") {
					return
				}
				db, err := sql.Open("sqlite", CursorReadPath(home))
				if err != nil {
					t.Fatal(err)
				}
				defer db.Close()
				if err := tc.edit(db); err != nil {
					t.Fatal(err)
				}
			}}
			nativeClient = &c
			if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "cursor", Backend: BackendNative, Enabled: true}); err != nil {
				t.Fatal(err)
			}
			err := RefreshNative(context.Background(), p, cursorNow)
			if len(paths) != 2 {
				t.Fatal(paths, err)
			}
			s, _ := loadReaderState(p.Cache, "cursor")
			if len(s.Entries) != 1 {
				t.Fatalf("entries = %+v", s.Entries)
			}
			got := s.Entries[0].Status == "ok" && s.Entries[0].Account != nil
			if got != tc.ok {
				t.Fatalf("status %q account %v, want ok=%v", s.Entries[0].Status, s.Entries[0].Account != nil, tc.ok)
			}
		})
	}
}

// Audit E finding 2: Claude credentials replaced or removed while the usage request is in flight
// must not publish the old account's reading as current. Rewriting the same login keeps it.
func TestAuditEClaudeCredentialChangeDuringRequestDiscardsTheReading(t *testing.T) {
	for _, mode := range []string{"same", "replaced", "removed"} {
		t.Run(mode, func(t *testing.T) {
			p := claudeTestPaths(t)
			status, paths := 200, []string{}
			claudeTestServer(t, &status, &paths)
			if err := RefreshNative(context.Background(), p, claudeTestNow); err != nil {
				t.Fatal(err)
			}
			root := p.ReaderAccess.Grants["claude"].Profiles[0].Root
			armed := true
			c := *nativeClient
			c.Transport = auditERoundTrip{base: nativeClient.Transport, before: func(r *http.Request) {
				if !armed || r.URL.Path != "/api/oauth/usage" {
					return
				}
				armed = false
				switch mode {
				case "same":
					writeClaudeCredential(t, root, "synthetic-access-token", claudeTestNow.Add(48*time.Hour))
				case "replaced":
					writeClaudeCredential(t, root, "synthetic-B-access", claudeTestNow.Add(48*time.Hour))
				case "removed":
					if err := os.Remove(root + "/.credentials.json"); err != nil {
						t.Fatal(err)
					}
				}
			}}
			nativeClient = &c
			if err := RefreshNative(context.Background(), p, claudeTestNow.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			if armed {
				t.Fatal("usage request not made", paths)
			}
			s, _ := loadReaderState(p.Cache, "claude")
			r := Report{}
			applyManaged(&r, p, "claude", claudeTestNow.Add(6*time.Minute))
			fresh := s.Entries[0].Status == "ok" && s.Entries[0].Account != nil && s.Entries[0].Account.ObservedAt.Equal(claudeTestNow.Add(5*time.Minute))
			if mode == "same" {
				if !fresh || len(r.Accounts) != 1 {
					t.Fatalf("same login lost its reading: %+v", s.Entries[0])
				}
				return
			}
			if fresh || s.Entries[0].Account != nil || s.Entries[0].Metadata.CredentialKey != "" || len(r.Accounts) != 0 {
				t.Fatalf("old account's reading published after the login changed: %+v", s.Entries[0])
			}
		})
	}
}
