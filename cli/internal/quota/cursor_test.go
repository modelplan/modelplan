package quota

import (
	"context"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

var cursorNow = time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)

func syntheticCursorToken(user string, expires time.Time) string {
	b, _ := json.Marshal(map[string]any{"sub": "auth|" + user, "exp": expires.Unix(), "email": "synthetic-private@example.invalid"})
	return "e30." + base64.RawURLEncoding.EncodeToString(b) + ".syntheticSignature"
}
func cursorDB(t *testing.T, token string, wal bool) *sql.DB {
	t.Helper()
	home, _ := os.UserHomeDir()
	path := CursorReadPath(home)
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if wal {
		if _, err = db.Exec("PRAGMA journal_mode=WAL"); err != nil {
			t.Fatal(err)
		}
	}
	if _, err = db.Exec(`CREATE TABLE IF NOT EXISTS ItemTable (key TEXT PRIMARY KEY, value)`); err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec(`INSERT OR REPLACE INTO ItemTable VALUES ('cursorAuth/accessToken',?)`, token); err != nil {
		t.Fatal(err)
	}
	if !wal {
		db.Close()
	}
	return db
}
func TestCursorReadOnlyAuthFormats(t *testing.T) {
	isolateHome(t)
	token := syntheticCursorToken("synthetic-account", cursorNow.Add(time.Hour))
	cursorDB(t, token, false)
	home, _ := os.UserHomeDir()
	path := CursorReadPath(home)
	before, _ := os.ReadFile(path)
	got, err := readCursorSession(context.Background(), cursorNow)
	if err != nil || got.token != token || got.user != "synthetic-account" {
		t.Fatal("synthetic sign-in not decoded", err)
	}
	after, _ := os.ReadFile(path)
	if !reflect.DeepEqual(before, after) {
		t.Fatal("database rewritten")
	}
	for _, suffix := range []string{"-wal", "-shm"} {
		if _, err := os.Stat(path + suffix); !os.IsNotExist(err) {
			t.Fatal("sidecar created", suffix)
		}
	}
	for _, bad := range []string{"opaque:synthetic", syntheticCursorToken("bad;cookie", cursorNow.Add(time.Hour)), syntheticCursorToken("expired", cursorNow), "bad.?.bad"} {
		cursorDB(t, bad, false)
		if _, err := readCursorSession(context.Background(), cursorNow); err == nil || strings.Contains(err.Error(), bad) {
			t.Fatal("unsafe auth accepted or disclosed")
		}
	}
	db := cursorDB(t, token, true)
	before, _ = os.ReadFile(path + "-wal")
	if _, err := readCursorSession(context.Background(), cursorNow); err != nil {
		t.Fatal(err)
	}
	after, _ = os.ReadFile(path + "-wal")
	if !reflect.DeepEqual(before, after) {
		t.Fatal("WAL rewritten")
	}
	// BLOB ASCII UTF-16LE regression: an unrelated auth field must not be read.
	b := make([]byte, len(token)*2)
	for i := range token {
		b[i*2] = token[i]
	}
	if _, err := db.Exec(`UPDATE ItemTable SET value=? WHERE key='cursorAuth/accessToken'`, b); err != nil {
		t.Fatal(err)
	}
	if got, err := readCursorSession(context.Background(), cursorNow); err != nil || got.token != token {
		t.Fatal("UTF16 BLOB failed", err)
	}
}

func TestCursorSchemasAndUnknowns(t *testing.T) {
	summary := []byte(`{"membershipType":"pro","billingCycleEnd":"2026-11-01T00:00:00Z","individualUsage":{"plan":{"used":250,"limit":1000,"totalPercentUsed":25,"autoPercentUsed":12,"apiPercentUsed":30},"onDemand":{"used":130}}}`)
	monthly := []byte(`{"isMerged":false,"planInfo":{"includedUsagePeriod":"INCLUDED_USAGE_PERIOD_MONTHLY"}}`)
	e := parseCursor(summary, monthly, nil, []byte(`{"gpt-4":{"numRequestsTotal":20,"maxRequestUsage":100}}`), cursorNow)
	if e.Status != "ok" || len(e.Windows) != 5 || *e.Windows[0].UsedUSD != 2.5 || *e.Windows[3].Requests.Used != 20 || *e.Windows[3].UsedPercent != 20 || *e.Windows[4].UsedUSD != 1.3 || e.Windows[4].UsedPercent != nil {
		t.Fatalf("monthly: %+v", e)
	}
	weekly := []byte(`{"isMerged":true,"planInfo":{"planName":"premium","includedUsagePeriod":"INCLUDED_USAGE_PERIOD_WEEKLY","includedUsageResetsAt":"1793448000000"}}`)
	e = parseCursor(summary, weekly, []byte(`{"planUsage":{"totalPercentUsed":"41"}}`), nil, cursorNow)
	if len(e.Windows) != 2 || e.Windows[0].Kind != "weekly" || *e.Windows[0].UsedPercent != 41 || e.Windows[0].ResetsAt == nil {
		t.Fatalf("weekly: %+v", e)
	}
	for _, raw := range []string{`{}`, `{"planUsage":{}}`, `{"enabled":false,"planUsage":{"totalPercentUsed":0}}`, `{"planUsage":{"totalPercentUsed":-1}}`, `{"planUsage":{"totalPercentUsed":"NaN"}}`} {
		e = parseCursor(summary, weekly, []byte(raw), nil, cursorNow)
		if len(e.Windows) != 2 || e.Windows[0].UsedPercent != nil {
			t.Fatal("missing weekly value fell back to monthly", raw)
		}
	}
	e = parseCursor([]byte(`{"individualUsage":{"plan":{"limit":1000},"onDemand":{}}}`), monthly, nil, nil, cursorNow)
	for _, w := range e.Windows {
		if w.UsedPercent != nil || w.UsedUSD != nil {
			t.Fatal("unknown converted to zero")
		}
	}
	e = parseCursor(summary, nil, nil, nil, cursorNow)
	if len(e.Windows) != 1 || e.Windows[0].Kind != "spend" {
		t.Fatal("unclassified plan used monthly data")
	}
	e = parseCursor([]byte(strings.ReplaceAll(string(summary), "2026-11-01", "2026-10-01")), monthly, nil, nil, cursorNow)
	for _, w := range e.Windows {
		if w.UsedUSD != nil || w.UsedPercent != nil || w.Requests != nil {
			t.Fatal("expired quota remained known")
		}
	}
}

func TestCursorOmittedPlanFlagRequiresExplicitPeriod(t *testing.T) {
	for _, tc := range []struct {
		raw           string
		known, weekly bool
	}{
		{`{"planInfo":{"includedUsagePeriod":"INCLUDED_USAGE_PERIOD_MONTHLY"}}`, true, false},
		{`{"planInfo":{"includedUsagePeriod":"INCLUDED_USAGE_PERIOD_WEEKLY"}}`, true, true},
		{`{}`, false, false}, {`{"planInfo":{}}`, false, false},
		{`{"planInfo":{"includedUsagePeriod":"NEW_UNKNOWN_PERIOD"}}`, false, false},
		{`{"isMerged":false,"planInfo":{"includedUsagePeriod":"INCLUDED_USAGE_PERIOD_WEEKLY"}}`, false, false},
	} {
		got := cursorMerged([]byte(tc.raw))
		if (got != nil) != tc.known || (got != nil && *got != tc.weekly) {
			t.Fatal("plan classified without evidence", tc.raw)
		}
	}
	summary := []byte(`{"individualUsage":{"plan":{"totalPercentUsed":37}}}`)
	plan := []byte(`{"planInfo":{"includedUsagePeriod":"INCLUDED_USAGE_PERIOD_MONTHLY"}}`)
	e := parseCursor(summary, plan, nil, nil, cursorNow)
	if len(e.Windows) != 1 || e.Windows[0].Kind != "monthly" || *e.Windows[0].UsedPercent != 37 {
		t.Fatal("omitted false lost monthly usage")
	}
}
