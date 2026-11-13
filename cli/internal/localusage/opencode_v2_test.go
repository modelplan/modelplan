// SPDX-License-Identifier: MIT
package localusage

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// Handwritten stores in fake homes only; no installed tool or real transcript.
func openCodeFixture(t *testing.T) (string, *sql.DB, HistoryAccess, string) {
	t.Helper()
	a := historyTestAccess(t)
	a.CaptureAllowed = func(*consent.CaptureStamp) bool { return true }
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("OPENCODE_DB", "")
	path := OpenCodeV2DB(os.Getenv("HOME"))
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	for _, q := range []string{
		`CREATE TABLE session_v2(id TEXT PRIMARY KEY,parent_id TEXT,fork_session_id TEXT,title TEXT,directory TEXT,model TEXT)`,
		`CREATE TABLE session_message(id TEXT PRIMARY KEY,session_id TEXT,type TEXT,seq INTEGER,time_created INTEGER,time_updated INTEGER,data TEXT)`,
		`CREATE TABLE session_part(message_id TEXT,data TEXT)`,
		`CREATE TABLE message(id TEXT,data TEXT)`,
		`INSERT INTO session_v2 VALUES('session-sensitive-canary',NULL,NULL,'title-sensitive-canary','/project-sensitive-canary','saved-model-canary')`,
		`INSERT INTO session_v2 VALUES('child','session-sensitive-canary',NULL,NULL,NULL,NULL)`,
		`INSERT INTO session_v2 VALUES('fork',NULL,'session-sensitive-canary',NULL,NULL,NULL)`,
		`INSERT INTO session_part VALUES('part','reply-thinking-tool-sensitive-canary')`,
		`INSERT INTO message VALUES('v1','v1-content-sensitive-canary')`,
	} {
		if _, err := db.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	return path, db, a, t.TempDir()
}
func openCodeJSON(model string, input any, completed bool) string {
	stamp := map[string]any{"created": testNow.Add(-2 * time.Minute).UnixMilli()}
	if completed {
		stamp["completed"] = testNow.Add(-time.Minute).UnixMilli()
	}
	row := map[string]any{"time": stamp, "model": map[string]any{"id": model, "variant": "high", "providerID": "account-sensitive-canary"}, "tokens": map[string]any{"input": input, "output": 0, "reasoning": 3, "cache": map[string]any{"read": 4, "write": 5}}, "cost": 999, "content": "reply-thinking-tool-sensitive-canary", "native": map[string]any{"access_token": "token-sensitive-canary"}}
	b, _ := json.Marshal(row)
	return string(b)
}
func openCodeInsert(t *testing.T, db *sql.DB, id, session, kind, data string, updated int64) {
	t.Helper()
	if _, err := db.Exec(`INSERT INTO session_message(id,session_id,type,seq,time_created,time_updated,data) VALUES(?,?,?,0,0,?,?)`, id, session, kind, updated, data); err != nil {
		t.Fatal(err)
	}
}
func openCodeInput(r OpenCodeV2Result) int64 {
	var n int64
	for _, row := range r.Rows {
		if row.Input != nil {
			n += *row.Input
		}
	}
	return n
}
func assertOpenCodePrivate(t *testing.T, cache string, r OpenCodeV2Result) {
	t.Helper()
	b, err := json.Marshal(r)
	if err != nil {
		t.Fatal(err)
	}
	if err := testenv.CheckReaderReasons(b); err != nil {
		t.Fatal(err)
	}
	if err := filepath.WalkDir(cache, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() {
			data, e := os.ReadFile(path)
			if e != nil {
				return e
			}
			if strings.HasSuffix(path, ".json") {
				if err := testenv.CheckReaderReasons(data); err != nil {
					return err
				}
			}
			b = append(b, data...)
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	for _, s := range []string{"session-sensitive-canary", "message-sensitive-canary", "title-sensitive-canary", "/project-sensitive-canary", "saved-model-canary", "account-sensitive-canary", "reply-thinking-tool-sensitive-canary", "token-sensitive-canary", "v1-content-sensitive-canary", os.Getenv("HOME")} {
		if bytes.Contains(b, []byte(s)) {
			t.Fatalf("private source data escaped: %s", s)
		}
	}
}
func TestOpenCodeV2SessionsAndUsage(t *testing.T) {
	path, db, a, cache := openCodeFixture(t)
	data := openCodeJSON("opencode-test", 10, true)
	openCodeInsert(t, db, "message-sensitive-canary", "session-sensitive-canary", "assistant", data, 1)
	openCodeInsert(t, db, "user", "session-sensitive-canary", "user", `not JSON content-sensitive-canary`, 2)
	openCodeInsert(t, db, "child", "child", "assistant", openCodeJSON("child-test", 999, true), 3)
	openCodeInsert(t, db, "fork", "fork", "assistant", openCodeJSON("fork-test", 999, true), 4)
	openCodeInsert(t, db, "orphan", "missing", "assistant", data, 5)
	before, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	r := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow)
	if r.Availability != "ok" || r.Reason != "" || !r.Beta || r.Measurement != "local-usage" || openCodeInput(r) != 10 || len(r.Sessions) != 1 {
		t.Fatalf("bad V2 projection: %+v", r)
	}
	row := r.Rows[0]
	if row.Model != "opencode-test" || row.Total != nil || row.Output == nil || *row.Output != 0 || *row.Reasoning != 3 || *row.CacheRead != 4 || *row.CacheWrite != 5 {
		t.Fatal("native counters changed or inferred", row)
	}
	if len(r.Sessions[0].SessionRef) != 64 || !r.Sessions[0].ObservedAt.Equal(testNow.Add(-time.Minute)) {
		t.Fatal("session identity or time changed")
	}
	after, _ := os.ReadFile(path)
	if !bytes.Equal(before, after) {
		t.Fatal("source database modified")
	}
	assertOpenCodePrivate(t, cache, r)
	r = RefreshOpenCodeV2(context.Background(), path, cache, a, testNow.Add(5*time.Minute))
	if s := openCodeLoad(cache, a); s.RowsRead != 0 {
		t.Fatal("unchanged database rescanned")
	}
	if err := os.Rename(path, path+".hidden"); err != nil {
		t.Fatal(err)
	}
	r = ReadOpenCodeV2Cache(cache, a, testNow.Add(6*time.Minute))
	if openCodeInput(r) != 10 {
		t.Fatal("cache query opened source")
	}
	r = RefreshOpenCodeV2(context.Background(), path, cache, a, testNow.Add(10*time.Minute))
	if r.Reason != "file_missing" || r.Availability != "not_detected" || openCodeInput(r) != 10 || r.Freshness != "stale" || !r.ObservedAt.Equal(testNow.Add(-time.Minute)) {
		t.Fatal("missing source lost last-good age", r)
	}
	assertOpenCodePrivate(t, cache, r)
}
func TestOpenCodeV2IncrementalCompletionAndCorrections(t *testing.T) {
	path, db, a, cache := openCodeFixture(t)
	openCodeInsert(t, db, "complete", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 10, true), 1)
	openCodeInsert(t, db, "running", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 20, false), 2)
	r := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow)
	if openCodeInput(r) != 10 {
		t.Fatal("running row counted")
	}
	for i, tc := range []struct {
		id      string
		count   int
		updated int64
		want    int64
	}{{"running", 20, 3, 30}, {"complete", 15, 4, 35}} {
		if _, err := db.Exec(`UPDATE session_message SET data=?,time_updated=? WHERE id=?`, openCodeJSON("opencode-test", tc.count, true), tc.updated, tc.id); err != nil {
			t.Fatal(err)
		}
		r = RefreshOpenCodeV2(context.Background(), path, cache, a, testNow.Add(time.Duration(i+1)*5*time.Minute))
		if openCodeInput(r) != tc.want {
			t.Fatal("updated counter missed or double-counted", r)
		}
	}
	openCodeInsert(t, db, "same-ms", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 5, true), 4)
	r = RefreshOpenCodeV2(context.Background(), path, cache, a, testNow.Add(15*time.Minute))
	if openCodeInput(r) != 40 {
		t.Fatal("same-ms row skipped", r)
	}
}
func TestOpenCodeV2BoundedRecoveryAndReplacement(t *testing.T) {
	path, db, a, cache := openCodeFixture(t)
	tx, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	for i := 1; i <= openCodeBatch+7; i++ {
		_, err = tx.Exec(`INSERT INTO session_message(id,session_id,type,time_updated,data) VALUES(?,'session-sensitive-canary','assistant',?,?)`, fmt.Sprint(i), i, openCodeJSON("opencode-test", 1, true))
		if err != nil {
			t.Fatal(err)
		}
	}
	if err = tx.Commit(); err != nil {
		t.Fatal(err)
	}
	r := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow)
	s := openCodeLoad(cache, a)
	if r.Availability != "partial" || !s.Pending || s.RowsRead != openCodeBatch || len(s.Working) != openCodeBatch || len(r.Rows) != 0 {
		t.Fatal("unbounded/incomplete recovery exposed as totals", r, s.RowsRead)
	}
	r = RefreshOpenCodeV2(context.Background(), path, cache, a, testNow.Add(10*time.Minute))
	if r.Availability != "ok" || openCodeInput(r) != openCodeBatch+7 {
		t.Fatal("recovery restart lost records", r)
	}
	if _, err = db.Exec(`DELETE FROM session_message`); err != nil {
		t.Fatal(err)
	}
	openCodeInsert(t, db, "replacement", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 7, true), 1)
	r = RefreshOpenCodeV2(context.Background(), path, cache, a, testNow.Add(15*time.Minute))
	if openCodeInput(r) != 7 {
		t.Fatal("replaced source retained old totals", r)
	}
	db.Close()
	if err = os.Rename(path, path+".old"); err != nil {
		t.Fatal(err)
	}
	raw, err := os.ReadFile(path + ".old")
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(path, raw, 0600); err != nil {
		t.Fatal(err)
	}
	r = RefreshOpenCodeV2(context.Background(), path, cache, a, testNow.Add(20*time.Minute))
	if openCodeInput(r) != 7 {
		t.Fatal("inode replacement miscounted", r)
	}
}
func TestReaderReasonOpenCodeV2Conformance(t *testing.T) {
	for _, tc := range []struct {
		name, want string
		mutate     func(*testing.T, string, *sql.DB)
	}{
		{"missing", "file_missing", func(t *testing.T, p string, db *sql.DB) {
			db.Close()
			if err := os.Remove(p); err != nil {
				t.Fatal(err)
			}
		}},
		{"directory", "file_unreadable", func(t *testing.T, p string, db *sql.DB) {
			db.Close()
			os.Remove(p)
			if err := os.Mkdir(p, 0700); err != nil {
				t.Fatal(err)
			}
		}},
		{"v1", "schema_changed", func(t *testing.T, p string, db *sql.DB) {
			if _, err := db.Exec(`DROP TABLE session_v2`); err != nil {
				t.Fatal(err)
			}
		}},
		{"schema", "schema_changed", func(t *testing.T, p string, db *sql.DB) {
			if _, err := db.Exec(`ALTER TABLE session_message RENAME COLUMN time_updated TO changed`); err != nil {
				t.Fatal(err)
			}
		}},
		{"malformed", "parse_error", func(t *testing.T, p string, db *sql.DB) {
			openCodeInsert(t, db, "bad", "session-sensitive-canary", "assistant", `broken token-sensitive-canary`, 2)
		}},
		{"nested-counter", "parse_error", func(t *testing.T, p string, db *sql.DB) {
			openCodeInsert(t, db, "bad", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", map[string]string{"content": "reply-thinking-tool-sensitive-canary"}, true), 2)
		}},
		{"negative", "parse_error", func(t *testing.T, p string, db *sql.DB) {
			openCodeInsert(t, db, "bad", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", -1, true), 2)
		}},
		{"fractional", "parse_error", func(t *testing.T, p string, db *sql.DB) {
			openCodeInsert(t, db, "bad", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 1.5, true), 2)
		}},
		{"symlink", "file_unreadable", func(t *testing.T, p string, db *sql.DB) {
			db.Close()
			if err := os.Rename(p, p+".target"); err != nil {
				t.Fatal(err)
			}
			if err := os.Symlink(p+".target", p); err != nil {
				t.Fatal(err)
			}
		}},
		{"wal-symlink", "file_unreadable", func(t *testing.T, p string, db *sql.DB) {
			if err := os.Symlink(p, p+"-wal"); err != nil {
				t.Fatal(err)
			}
		}},
		{"corrupt-db", "schema_changed", func(t *testing.T, p string, db *sql.DB) {
			db.Close()
			if err := os.WriteFile(p, []byte("not a sqlite database token-sensitive-canary"), 0600); err != nil {
				t.Fatal(err)
			}
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			path, db, a, cache := openCodeFixture(t)
			finish := testenv.CaptureReasonLogs(t)
			defer func() {
				if err := finish(); err != nil {
					t.Error(err)
				}
			}()
			tc.mutate(t, path, db)
			r := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow)
			if r.Reason != tc.want {
				t.Errorf("reason=%q want=%q", r.Reason, tc.want)
			}
			assertOpenCodePrivate(t, cache, r)
			retained := ReadOpenCodeV2Cache(cache, a, testNow.Add(time.Minute))
			if retained.Reason != r.Reason {
				t.Error("retained reason changed")
			}
			if !testenv.ReaderReasonCode(retained.Reason) {
				t.Error("reason outside fixed vocabulary")
			}
			assertOpenCodePrivate(t, cache, retained)
		})
	}
}
func TestOpenCodeV2AdmissionAndSharedGate(t *testing.T) {
	for _, state := range []string{"consent_required", "denied", "off", "privacy_blocked", "key-unavailable", "revoked"} {
		t.Run(state, func(t *testing.T) {
			path, db, a, cache := openCodeFixture(t)
			openCodeInsert(t, db, "message-sensitive-canary", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 10, true), 1)
			want := state
			switch state {
			case "consent_required":
				a.Allowed = false
			case "denied":
				a.Denied = true
			case "off":
				t.Setenv("MODELPLAN_READERS", "off")
			case "privacy_blocked":
				a.Privacy = "invalid"
			case "key-unavailable":
				a.Key = nil
				want = "privacy_blocked"
			case "revoked":
				a.StillValid = func() bool { return false }
				want = "consent_required"
			}
			r := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow)
			if r.Availability != want || len(r.Rows) != 0 {
				t.Fatal("admission bypass", r)
			}
			entries, err := os.ReadDir(cache)
			if err != nil || len(entries) != 0 {
				t.Fatal("blocked reader performed cache I/O")
			}
		})
	}
	path, db, a, cache := openCodeFixture(t)
	a.Privacy = "passive"
	openCodeInsert(t, db, "one", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 10, true), 1)
	r := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow)
	if openCodeInput(r) != 10 {
		t.Fatal("passive local read blocked")
	}
	other := a
	other.ProfileRef = strings.Repeat("b", 64)
	r = RefreshOpenCodeV2(context.Background(), path, cache, other, testNow.Add(time.Minute))
	if len(r.Rows) != 0 {
		t.Fatal("profile inherited another profile reading")
	}
	if _, err := os.Stat(historyPath(cache, openCodeTool, other)); !os.IsNotExist(err) {
		t.Fatal("shared five-minute floor bypassed by profile")
	}
	before, _ := os.ReadFile(historyPath(cache, openCodeTool, a))
	a.Publish = func(write func() error) error { return fmt.Errorf("revocation-sensitive-canary") }
	openCodeInsert(t, db, "two", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 10, true), 2)
	r = RefreshOpenCodeV2(context.Background(), path, cache, a, testNow.Add(5*time.Minute))
	after, _ := os.ReadFile(historyPath(cache, openCodeTool, a))
	if !bytes.Equal(before, after) || r.Reason != "file_unreadable" {
		t.Fatal("publication fence bypassed")
	}
	if err := ForgetHistoryProfile(cache, openCodeTool, a); err != nil {
		t.Fatal(err)
	}
	gate, _ := historyGatePaths(cache, openCodeTool)
	if _, err := os.Stat(gate); err != nil {
		t.Fatal("forget erased shared gate")
	}
	if r = ReadOpenCodeV2Cache(cache, a, testNow); len(r.Rows) != 0 {
		t.Fatal("forget kept derived rows")
	}
}
func TestOpenCodeV2HMACAndUnknowns(t *testing.T) {
	path, db, a, cache := openCodeFixture(t)
	openCodeInsert(t, db, "message-sensitive-canary", "session-sensitive-canary", "assistant", openCodeJSON("bad/account@example.invalid", nil, true), 1)
	r := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow)
	if r.Availability != "partial" || r.Rows[0].Model != "" || r.Rows[0].Input != nil || r.Rows[0].Total != nil {
		t.Fatal("unknown values inferred", r)
	}
	first := r.Sessions[0].SessionRef
	other := a
	other.ProfileRef = strings.Repeat("b", 64)
	r = RefreshOpenCodeV2(context.Background(), path, t.TempDir(), other, testNow)
	if r.Sessions[0].SessionRef == first {
		t.Fatal("profile HMAC isolation failed")
	}
	other = a
	other.Key = bytes.Repeat([]byte{9}, 32)
	r = RefreshOpenCodeV2(context.Background(), path, t.TempDir(), other, testNow)
	if r.Sessions[0].SessionRef == first {
		t.Fatal("installation HMAC isolation failed")
	}
	assertOpenCodePrivate(t, cache, r)
}
func TestOpenCodeV2NotEnabledInV1(t *testing.T) {
	testenv.IsolateHome(t)
	d, ok := consent.Definition(consent.ScopeOpenCodeV2LocalHistory)
	if !ok || d.DefaultCheck || d.Class != consent.Local {
		t.Fatal("V2 scope defaulted on")
	}
	s := consent.State{Tools: map[string]consent.Record{}}
	if s.AllowsScope(d.ID, consent.Automatic) || s.AllowsScope(d.ID, consent.Passive) {
		t.Fatal("new scope inherited defaults")
	}
	if err := consent.Set(&s, "opencode", true, "native:opencode", "native", testNow); err != nil {
		t.Fatal(err)
	}
	if s.AllowsScope(d.ID, consent.Automatic) {
		t.Fatal("legacy whole-tool grant enabled C15")
	}
	for _, tool := range HistoryProviders() {
		if tool == openCodeTool {
			t.Fatal("C15 registered in v1 production inventory")
		}
	}
	if productionHistoryRoot(os.Getenv("HOME"), openCodeTool) != "" {
		t.Fatal("v1 discovers C15")
	}
	root, access := ProductionHistoryAccess(os.Getenv("HOME"), openCodeTool, true)
	if root != "" || access.Allowed {
		t.Fatal("v1 admits C15")
	}
	t.Setenv("OPENCODE_DB", "relative.db")
	if OpenCodeV2DB(os.Getenv("HOME")) != "" {
		t.Fatal("relative override accepted")
	}
	custom := filepath.Join(os.Getenv("HOME"), "custom", "opencode-preview.db")
	t.Setenv("OPENCODE_DB", custom)
	if OpenCodeV2DB(os.Getenv("HOME")) != custom {
		t.Fatal("documented override ignored")
	}
}

func TestOpenCodeV2WALAndReadOnlyConnection(t *testing.T) {
	path, db, a, cache := openCodeFixture(t)
	if _, err := db.Exec(`PRAGMA journal_mode=WAL`); err != nil {
		t.Fatal(err)
	}
	openCodeInsert(t, db, "wal-row", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 10, true), 1)
	beforeDB, _ := os.ReadFile(path)
	beforeWAL, err := os.ReadFile(path + "-wal")
	if err != nil {
		t.Fatal(err)
	}
	r := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow)
	if r.Availability != "ok" || openCodeInput(r) != 10 || r.RecordsRead != 1 || r.BytesRead <= 0 {
		t.Fatal("WAL-only commit not observed", r)
	}
	afterDB, _ := os.ReadFile(path)
	afterWAL, _ := os.ReadFile(path + "-wal")
	if !bytes.Equal(beforeDB, afterDB) || !bytes.Equal(beforeWAL, afterWAL) {
		t.Fatal("source database/WAL modified")
	}
	ro, err := openCodeDatabase(path)
	if err != nil {
		t.Fatal(err)
	}
	defer ro.Close()
	if _, err = ro.Exec(`INSERT INTO message VALUES('write','forbidden')`); err == nil {
		t.Fatal("production reader connection allowed writes")
	}
	// Only a WAL commit changes: the main database remains the same generation.
	openCodeInsert(t, db, "wal-row-2", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 3, true), 2)
	r = RefreshOpenCodeV2(context.Background(), path, cache, a, testNow.Add(5*time.Minute))
	if openCodeInput(r) != 13 {
		t.Fatal("WAL update skipped", r)
	}
}

func TestOpenCodeV2BackoffCancellationAndExpiry(t *testing.T) {
	path, db, a, cache := openCodeFixture(t)
	openCodeInsert(t, db, "one", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 10, true), 1)
	good := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow)
	openCodeInsert(t, db, "malformed", "session-sensitive-canary", "assistant", `broken private error text`, 2)
	failed := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow.Add(5*time.Minute))
	if failed.Reason != "parse_error" || openCodeInput(failed) != 10 || !failed.ObservedAt.Equal(good.ObservedAt) || failed.Freshness != "stale" {
		t.Fatal("parse error erased last-good reading", failed)
	}
	if !failed.NextAttemptAt.Equal(testNow.Add(15 * time.Minute)) {
		t.Fatal("failure backoff missing", failed.NextAttemptAt)
	}
	// Removing bad data cannot bypass the persisted floor or clock rollback.
	if _, err := db.Exec(`DELETE FROM session_message WHERE id='malformed'`); err != nil {
		t.Fatal(err)
	}
	for _, at := range []time.Time{testNow.Add(6 * time.Minute), testNow.Add(-time.Hour)} {
		r := RefreshOpenCodeV2(context.Background(), path, cache, a, at)
		if r.Reason != "parse_error" {
			t.Fatal("reservation bypassed", r)
		}
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if r := RefreshOpenCodeV2(ctx, path, cache, a, testNow.Add(time.Hour)); r.Reason != "timeout" {
		t.Fatal("canceled read not reported", r)
	}
	// A caller revoking during the transaction may reserve but cannot publish.
	calls := 0
	a.StillValid = func() bool { calls++; return calls == 1 }
	before, _ := os.ReadFile(historyPath(cache, openCodeTool, a))
	r := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow.Add(time.Hour))
	after, _ := os.ReadFile(historyPath(cache, openCodeTool, a))
	if r.Availability != "consent_required" || !bytes.Equal(before, after) {
		t.Fatal("revoked transaction published", r)
	}
	a.StillValid = nil
	if r := ReadOpenCodeV2Cache(cache, a, testNow.AddDate(0, 0, 36)); len(r.Rows) != 0 || len(r.Sessions) != 0 {
		t.Fatal("expired history retained")
	}
}

func TestOpenCodeV2UnknownNewSessionFieldsDoNotInherit(t *testing.T) {
	path, db, a, cache := openCodeFixture(t)
	openCodeInsert(t, db, "one", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 10, true), 1)
	newer := fmt.Sprintf(`{"time":{"created":%d,"completed":%d},"modelID":"v1-field-must-not-win","content":"reply-thinking-tool-sensitive-canary"}`, testNow.Add(-time.Minute).UnixMilli(), testNow.UnixMilli())
	openCodeInsert(t, db, "two", "session-sensitive-canary", "assistant", newer, 2)
	r := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow)
	if len(r.Sessions) != 1 || r.Sessions[0].Model != "" || !r.Sessions[0].ObservedAt.Equal(testNow) || openCodeInput(r) != 10 {
		t.Fatal("old model or V1 field inherited", r)
	}
	// The complete missing-usage record preserves the prior measured usage, without
	// inventing a count for the newer assistant state.
	assertOpenCodePrivate(t, cache, r)
}

func TestOpenCodeV2ExplicitScopeAndCaptureRevocation(t *testing.T) {
	path, db, a, cache := openCodeFixture(t)
	initial, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	grant := consent.Grant{RequestID: "c15-synthetic-opt-in", ExpectStoreEpoch: initial.StoreEpoch, ExpectGeneration: initial.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeOpenCodeV2LocalHistory}, Deny: []string{}}
	if _, err = consent.ApplyGrant(consent.Path(), grant, consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) {
		return consent.Record{ReaderID: "native:opencode", Backend: "native"}, nil
	}, Cleanup: func(string, bool) error { return nil }}); err != nil {
		t.Fatal(err)
	}
	state, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	if !state.AllowsScope(consent.ScopeOpenCodeV2LocalHistory, consent.Passive) || state.AllowsScope(consent.ScopeOpenCodeV2LocalHistory, consent.Off) {
		t.Fatal("explicit local scope policy failed")
	}
	a.Admission = state.CaptureStamp(consent.ScopeOpenCodeV2LocalHistory)
	a.CaptureAllowed = func(stamp *consent.CaptureStamp) bool {
		return state.CaptureAllowed(stamp, consent.ScopeOpenCodeV2LocalHistory)
	}
	openCodeInsert(t, db, "one", "session-sensitive-canary", "assistant", openCodeJSON("opencode-test", 10, true), 1)
	r := RefreshOpenCodeV2(context.Background(), path, cache, a, testNow)
	if openCodeInput(r) != 10 {
		t.Fatal("explicit capture unavailable", r)
	}
	a.CaptureAllowed = func(*consent.CaptureStamp) bool { return false }
	if r = ReadOpenCodeV2Cache(cache, a, testNow); len(r.Rows) != 0 || len(r.Sessions) != 0 {
		t.Fatal("revoked capture remained visible")
	}
	if err = ForgetProductionHistory(cache, openCodeTool); err != nil {
		t.Fatal(err)
	}
	if _, err = os.Stat(historyPath(cache, openCodeTool, a)); !os.IsNotExist(err) {
		t.Fatal("production Forget missed C15")
	}
}
