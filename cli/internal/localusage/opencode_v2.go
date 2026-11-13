// SPDX-License-Identifier: MIT
package localusage

// C15 reads OpenCode 2's own SQLite projections. It is deliberately absent from
// HistoryProviders and production discovery/refresh: v1 does not enable C15.
// Schema evidence (not vendored code): anomalyco/opencode at 8b4d98c33a75,
// packages/core/src/session/sql.ts and packages/schema/src/session-message.ts.

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	_ "modernc.org/sqlite"
)

const openCodeTool = "opencode"
const openCodeBatch = 1000
const openCodeEntryLimit = 10000

// OpenCodeV2Session is last observed completed assistant state, never a claim
// about the foreground session. A variant name cannot establish effort or Fast.
type OpenCodeV2Session struct {
	SessionRef string    `json:"sessionRef"`
	Model      string    `json:"model,omitempty"`
	ObservedAt time.Time `json:"observedAt"`
}
type OpenCodeV2Result struct {
	HistoryResult
	Reason      string              `json:"reason,omitempty"`
	Sessions    []OpenCodeV2Session `json:"sessions"`
	RecordsRead int                 `json:"recordsRead"`
}
type openCodeEntry struct {
	SessionRef string    `json:"sessionRef"`
	Order      int64     `json:"order"`
	At         time.Time `json:"at"`
	Model      string    `json:"model,omitempty"`
	HistoryCounts
}
type openCodeMark struct {
	Updated int64 `json:"updated"`
	Row     int64 `json:"row"`
}
type openCodeState struct {
	SchemaVersion int                      `json:"schemaVersion"`
	Admission     *consent.CaptureStamp    `json:"admission,omitempty"`
	Availability  string                   `json:"availability"`
	Reason        string                   `json:"reason,omitempty"`
	SourceRef     string                   `json:"sourceRef"`
	Identity      string                   `json:"identity"`
	Signature     string                   `json:"signature"`
	Mark          openCodeMark             `json:"mark"`
	Entries       map[string]openCodeEntry `json:"entries"`
	// Bounded recovery stages a replacement before replacing the last good view.
	Working         map[string]openCodeEntry `json:"working,omitempty"`
	Recovering      bool                     `json:"recovering,omitempty"`
	Pending         bool                     `json:"pending,omitempty"`
	RowsRead        int                      `json:"rowsRead"`
	ProjectionBytes int64                    `json:"projectionBytes"`
}

// OpenCodeV2DB resolves only the documented database location, with no I/O.
// Invalid overrides fail closed. The caller must authorise the resulting path;
// the resolver never opens config, service discovery, auth files or a V1 store.
func OpenCodeV2DB(home string) string {
	if p := os.Getenv("OPENCODE_DB"); p != "" {
		if filepath.IsAbs(p) {
			return filepath.Clean(p)
		}
		return ""
	}
	root := os.Getenv("XDG_DATA_HOME")
	if root == "" {
		root = filepath.Join(home, ".local", "share")
	}
	if !filepath.IsAbs(root) {
		return ""
	}
	return filepath.Join(root, "opencode", "opencode.db")
}
func openCodeLoad(cache string, a HistoryAccess) openCodeState {
	var s openCodeState
	if !historyLoad(historyPath(cache, openCodeTool, a), &s, 8<<20) || s.SchemaVersion != 1 || len(s.Entries) > openCodeEntryLimit || len(s.Working) > openCodeEntryLimit || !historyCaptureAllowed(openCodeTool, a, s.Admission) {
		s = openCodeState{SchemaVersion: 1}
	}
	if s.Reason != "" {
		s.Reason = openCodeReason(errors.New(s.Reason))
	}
	if s.Entries == nil {
		s.Entries = map[string]openCodeEntry{}
	}
	return s
}
func openCodeView(s openCodeState, a HistoryAccess, now time.Time) OpenCodeV2Result {
	r := OpenCodeV2Result{HistoryResult: HistoryResult{Tool: openCodeTool, Measurement: "local-usage", Timezone: "UTC", Confidence: "exact", Beta: true, Freshness: "unknown", Rows: []HistoryRow{}, Unallocated: []HistoryRow{}}, Sessions: []OpenCodeV2Session{}}
	if blocked := historyAdmission(openCodeTool, a); blocked != "" {
		r.Availability = blocked
		r.NextStep = historyNext(openCodeTool, blocked)
		return r
	}
	r.Availability, r.Reason = s.Availability, s.Reason
	r.RecordsRead = s.RowsRead
	r.BytesRead = s.ProjectionBytes
	if r.Availability == "" {
		r.Availability = "stale"
	}
	by := map[string]*HistoryRow{}
	sessions := map[string]OpenCodeV2Session{}
	orders := map[string]int64{}
	for _, e := range s.Entries {
		if e.At.After(now) || e.At.Before(now.AddDate(0, 0, -35)) {
			continue
		}
		if e.At.After(r.ObservedAt) {
			r.ObservedAt = e.At
		}
		if old := sessions[e.SessionRef]; old.ObservedAt.Before(e.At) || old.ObservedAt.Equal(e.At) && e.Order > orders[e.SessionRef] {
			sessions[e.SessionRef] = OpenCodeV2Session{e.SessionRef, e.Model, e.At}
			orders[e.SessionRef] = e.Order
		}
		if !e.HistoryCounts.known() {
			continue
		}
		day := e.At.UTC().Format("2006-01-02")
		k := day + "\x00" + e.Model
		if row := by[k]; row != nil {
			row.HistoryCounts.add(e.HistoryCounts)
		} else {
			by[k] = &HistoryRow{Day: day, Model: e.Model, HistoryCounts: e.HistoryCounts}
		}
	}
	for _, row := range by {
		r.Rows = append(r.Rows, *row)
	}
	for _, s := range sessions {
		r.Sessions = append(r.Sessions, s)
	}
	sort.Slice(r.Rows, func(i, j int) bool {
		if r.Rows[i].Day != r.Rows[j].Day {
			return r.Rows[i].Day > r.Rows[j].Day
		}
		return r.Rows[i].Model < r.Rows[j].Model
	})
	sort.Slice(r.Sessions, func(i, j int) bool { return r.Sessions[i].SessionRef < r.Sessions[j].SessionRef })
	if !r.ObservedAt.IsZero() {
		r.Freshness = "fresh"
		if now.Sub(r.ObservedAt) > 24*time.Hour || r.Availability != "ok" {
			r.Freshness = "stale"
		}
	}
	r.NextStep = historyNext(openCodeTool, r.Availability)
	return r
}

// ReadOpenCodeV2Cache is the read-only query seam. It never stats or opens the
// OpenCode store, creates a key, advances a watermark or reserves a read.
func ReadOpenCodeV2Cache(cache string, a HistoryAccess, now time.Time) OpenCodeV2Result {
	if historyAdmission(openCodeTool, a) != "" {
		return openCodeView(openCodeState{}, a, now)
	}
	r := openCodeView(openCodeLoad(cache, a), a, now)
	path, _ := historyGatePaths(cache, openCodeTool)
	var g historyGate
	historyLoad(path, &g, 4096)
	r.NextAttemptAt = g.Next
	return r
}

// openCodeSource validates every source component and SQLite sidecar before
// opening the database. Unchanged generations need zero SQL/content reads.
func openCodeSource(path string, key []byte) (identity, signature string, err error) {
	if !filepath.IsAbs(path) {
		return "", "", errors.New("file_unreadable")
	}
	var parts []string
	for i, p := range []string{path, path + "-wal", path + "-shm", path + "-journal"} {
		if err := safePath(p, false); err != nil {
			if i > 0 && os.IsNotExist(err) {
				continue
			}
			return "", "", err
		}
		f, err := os.Lstat(p)
		if err != nil {
			if i > 0 && os.IsNotExist(err) {
				continue
			}
			return "", "", err
		}
		if !f.Mode().IsRegular() {
			return "", "", errors.New("file_unreadable")
		}
		id, change := historyMetadata(f, key)
		if id == "" || change == "" {
			return "", "", errors.New("schema_changed")
		}
		if i == 0 {
			identity = id
		}
		parts = append(parts, fmt.Sprint(i)+":"+id+":"+change)
	}
	return identity, historyHash(key, "opencode-v2/source-generation", strings.Join(parts, "\x00")), nil
}

// Fixed errors only: driver text can contain SQL, paths and arbitrary values.
func openCodeReason(err error) string {
	if err == nil {
		return ""
	}
	if errors.Is(err, os.ErrNotExist) {
		return "file_missing"
	}
	if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
		return "timeout"
	}
	switch err.Error() {
	case "schema_changed", "parse_error", "file_unreadable", "file_missing", "timeout":
		return err.Error()
	}
	return "file_unreadable"
}

// RefreshOpenCodeV2 requires explicit access and a caller-selected database.
// It never launches OpenCode, uses a socket/network, or opens credentials. All
// profiles share the existing five-minute attempt floor and error backoff.
func RefreshOpenCodeV2(ctx context.Context, path, cache string, a HistoryAccess, now time.Time) OpenCodeV2Result {
	if historyAdmission(openCodeTool, a) != "" || cache == "" {
		return ReadOpenCodeV2Cache(cache, a, now)
	}
	stamp := a.Admission
	if stamp == nil {
		state, _ := consent.Current()
		stamp = state.CaptureStamp(consent.ScopeOpenCodeV2LocalHistory)
	}
	if ctx.Err() != nil {
		r := ReadOpenCodeV2Cache(cache, a, now)
		r.Availability = "stale"
		r.Reason = "timeout"
		r.Freshness = "stale"
		return r
	}
	gatePath, lockPath := historyGatePaths(cache, openCodeTool)
	if os.MkdirAll(filepath.Dir(lockPath), 0700) != nil {
		return ReadOpenCodeV2Cache(cache, a, now)
	}
	// The two-second source deadline bounds ownership; recover abandoned locks
	// only after the same conservative minute used by the shared history seam.
	if info, err := os.Stat(lockPath); err == nil && time.Since(info.ModTime()) > time.Minute {
		_ = os.Remove(lockPath)
	}
	lock, err := os.OpenFile(lockPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return ReadOpenCodeV2Cache(cache, a, now)
	}
	lock.Close()
	defer os.Remove(lockPath)
	g := historyGate{SchemaVersion: 1}
	if _, err := os.Lstat(gatePath); err == nil {
		if !historyLoad(gatePath, &g, 4096) || g.SchemaVersion != 1 {
			r := ReadOpenCodeV2Cache(cache, a, now)
			r.Availability = "not_supported_yet"
			r.Reason = "schema_changed"
			return r
		}
	} else if !os.IsNotExist(err) {
		return ReadOpenCodeV2Cache(cache, a, now)
	}
	if now.Before(g.Next) || now.Before(g.At.Add(5*time.Minute)) {
		return ReadOpenCodeV2Cache(cache, a, now)
	}
	g.At = now.UTC()
	g.Next = now.Add(5 * time.Minute).UTC()
	if !historySave(gatePath, g) {
		return ReadOpenCodeV2Cache(cache, a, now)
	}
	s := openCodeLoad(cache, a)
	s.RowsRead = 0
	s.ProjectionBytes = 0
	// A failed batch must not publish its partial mutation or cursor.
	batch := s
	batch.Entries = cloneOpenCodeEntries(s.Entries, now)
	batch.Working = cloneOpenCodeEntries(s.Working, now)
	deadline, cancel := context.WithTimeout(ctx, 2*time.Second)
	err = openCodeRead(deadline, path, a, &batch, now)
	cancel()
	if err == nil {
		s = batch
		s.Reason = ""
	} else {
		s.Reason = openCodeReason(err)
		s.Availability = "denied"
		if s.Reason == "file_missing" {
			s.Availability = "not_detected"
		}
		if s.Reason == "schema_changed" || s.Reason == "parse_error" {
			s.Availability = "not_supported_yet"
		}
		if s.Reason == "timeout" {
			s.Availability = "stale"
		}
	}
	if ctx.Err() != nil || historyAdmission(openCodeTool, a) != "" {
		return ReadOpenCodeV2Cache(cache, a, now)
	}
	if s.Availability == "ok" {
		g.Failures = 0
	} else {
		g.Failures = min(g.Failures+1, 4)
		wait := time.Duration(10*(1<<(g.Failures-1))) * time.Minute
		if g.Failures == 4 {
			wait = time.Hour
		}
		g.Next = now.Add(wait).UTC()
	}
	s.Admission = stamp
	save := func() error {
		if !historySave(historyPath(cache, openCodeTool, a), s) {
			return errors.New("file_unreadable")
		}
		if !historySave(gatePath, g) {
			return errors.New("file_unreadable")
		}
		return nil
	}
	if a.Publish != nil {
		err = a.Publish(save)
	} else {
		err = save()
	}
	if err != nil {
		r := ReadOpenCodeV2Cache(cache, a, now)
		r.Availability = "stale"
		r.Freshness = "stale"
		r.Reason = "file_unreadable"
		return r
	}
	return ReadOpenCodeV2Cache(cache, a, now)
}
func cloneOpenCodeEntries(in map[string]openCodeEntry, now time.Time) map[string]openCodeEntry {
	out := map[string]openCodeEntry{}
	for k, v := range in {
		if !v.At.Before(now.AddDate(0, 0, -35)) {
			out[k] = v
		}
	}
	return out
}

var openCodeModel = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._-]{0,95}$`)

// SQL constructs a small header projection. Neither the complete data JSON nor
// content, parts, native/provider payloads, titles, paths or auth are selected.
const openCodeProjection = `m.rowid, m.time_updated,
 CASE WHEN length(m.id)<=200 THEN m.id END,
 CASE WHEN length(m.session_id)<=200 THEN m.session_id END,
 CASE WHEN json_valid(m.data) THEN json_object(
 'model',CASE WHEN json_type(m.data,'$.model.id')='text' AND length(json_extract(m.data,'$.model.id'))<=96 THEN json_extract(m.data,'$.model.id') END,
 'created',CASE WHEN json_type(m.data,'$.time.created')='integer' THEN json_extract(m.data,'$.time.created') WHEN json_type(m.data,'$.time.created') IS NULL OR json_type(m.data,'$.time.created')='null' THEN NULL ELSE 'invalid' END,
 'completed',CASE WHEN json_type(m.data,'$.time.completed')='integer' THEN json_extract(m.data,'$.time.completed') WHEN json_type(m.data,'$.time.completed') IS NULL OR json_type(m.data,'$.time.completed')='null' THEN NULL ELSE 'invalid' END,
 'input',CASE WHEN json_type(m.data,'$.tokens.input')='integer' THEN json_extract(m.data,'$.tokens.input') WHEN json_type(m.data,'$.tokens.input') IS NULL OR json_type(m.data,'$.tokens.input')='null' THEN NULL ELSE 'invalid' END,
 'output',CASE WHEN json_type(m.data,'$.tokens.output')='integer' THEN json_extract(m.data,'$.tokens.output') WHEN json_type(m.data,'$.tokens.output') IS NULL OR json_type(m.data,'$.tokens.output')='null' THEN NULL ELSE 'invalid' END,
 'reasoning',CASE WHEN json_type(m.data,'$.tokens.reasoning')='integer' THEN json_extract(m.data,'$.tokens.reasoning') WHEN json_type(m.data,'$.tokens.reasoning') IS NULL OR json_type(m.data,'$.tokens.reasoning')='null' THEN NULL ELSE 'invalid' END,
 'read',CASE WHEN json_type(m.data,'$.tokens.cache.read')='integer' THEN json_extract(m.data,'$.tokens.cache.read') WHEN json_type(m.data,'$.tokens.cache.read') IS NULL OR json_type(m.data,'$.tokens.cache.read')='null' THEN NULL ELSE 'invalid' END,
 'write',CASE WHEN json_type(m.data,'$.tokens.cache.write')='integer' THEN json_extract(m.data,'$.tokens.cache.write') WHEN json_type(m.data,'$.tokens.cache.write') IS NULL OR json_type(m.data,'$.tokens.cache.write')='null' THEN NULL ELSE 'invalid' END) END`

func openCodeSchema(ctx context.Context, tx *sql.Tx) error {
	for table, required := range map[string][]string{"session_v2": {"id", "parent_id", "fork_session_id"}, "session_message": {"id", "session_id", "type", "time_updated", "data"}} {
		var n int
		// A view could execute arbitrary SQL/projections; only native tables qualify.
		if tx.QueryRowContext(ctx, `SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?`, table).Scan(&n) != nil || n != 1 {
			return errors.New("schema_changed")
		}
		rows, err := tx.QueryContext(ctx, `SELECT name FROM pragma_table_info(?)`, table)
		if err != nil {
			return errors.New("schema_changed")
		}
		columns := map[string]bool{}
		for rows.Next() {
			var name string
			if rows.Scan(&name) != nil {
				rows.Close()
				return errors.New("schema_changed")
			}
			columns[name] = true
		}
		err = rows.Err()
		rows.Close()
		if err != nil {
			return err
		}
		for _, name := range required {
			if !columns[name] {
				return errors.New("schema_changed")
			}
		}
	}
	return nil
}
func openCodeDatabase(path string) (*sql.DB, error) {
	uri := url.URL{Scheme: "file", Path: path, RawQuery: "mode=ro&_pragma=query_only(1)&_pragma=trusted_schema(0)&_pragma=busy_timeout(100)"}
	db, err := sql.Open("sqlite", uri.String())
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	return db, nil
}

func openCodeRead(ctx context.Context, path string, a HistoryAccess, s *openCodeState, now time.Time) error {
	identity, signature, err := openCodeSource(path, a.Key)
	if err != nil {
		return err
	}
	source := historyHash(a.Key, "opencode-v2/source/"+a.ProfileRef, path)
	if signature == s.Signature && source == s.SourceRef && !s.Pending {
		s.RowsRead = 0
		s.ProjectionBytes = 0
		return nil
	}
	db, err := openCodeDatabase(path)
	if err != nil {
		return err
	}
	defer db.Close()
	tx, err := db.BeginTx(ctx, &sql.TxOptions{ReadOnly: true})
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err = openCodeSchema(ctx, tx); err != nil {
		return err
	}
	reset := source != s.SourceRef || identity != s.Identity
	if !reset && s.Mark.Row != 0 {
		var updated int64
		if err := tx.QueryRowContext(ctx, `SELECT time_updated FROM session_message WHERE rowid=?`, s.Mark.Row).Scan(&updated); err != nil || updated < s.Mark.Updated {
			reset = true
		}
	}
	if reset {
		s.Mark = openCodeMark{}
		s.Working = map[string]openCodeEntry{}
		s.Recovering = true
	}
	if !s.Recovering && !s.Pending {
		s.Working = cloneOpenCodeEntries(s.Entries, now)
	}
	start := s.Mark
	// Revisit the final timestamp after a complete batch: same-millisecond updates
	// replace their keyed entries rather than being lost or counted twice.
	if !s.Pending {
		start.Row = 0
	}
	rows, err := tx.QueryContext(ctx, `SELECT `+openCodeProjection+` FROM session_message m
 JOIN session_v2 s ON s.id=m.session_id
 WHERE m.type='assistant' AND s.parent_id IS NULL AND s.fork_session_id IS NULL
 AND (m.time_updated>? OR (m.time_updated=? AND m.rowid>?))
 ORDER BY m.time_updated,m.rowid LIMIT ?`, start.Updated, start.Updated, start.Row, openCodeBatch+1)
	if err != nil {
		return err
	}
	count := 0
	s.Pending = false
	for rows.Next() {
		if count == openCodeBatch {
			s.Pending = true
			break
		}
		var row, updated int64
		var id, session, header sql.NullString
		if err = rows.Scan(&row, &updated, &id, &session, &header); err != nil {
			rows.Close()
			return errors.New("parse_error")
		}
		count++
		s.ProjectionBytes += int64(len(id.String) + len(session.String) + len(header.String) + 16)
		if updated < 0 || updated > now.UnixMilli() || !id.Valid || id.String == "" || !session.Valid || session.String == "" || !header.Valid {
			rows.Close()
			return errors.New("parse_error")
		}
		key := historyHash(a.Key, "opencode-v2/message/"+a.ProfileRef, id.String)
		var r struct {
			Model                                 string
			Created, Completed                    *int64
			Input, Output, Reasoning, Read, Write *int64
		}
		if json.Unmarshal([]byte(header.String), &r) != nil {
			rows.Close()
			return errors.New("parse_error")
		}
		// Running or timestamp-less records never acquire a fabricated observation.
		// They do advance the update cursor; native time_updated brings completion back.
		if r.Completed != nil && *r.Completed > 0 {
			at := time.UnixMilli(*r.Completed).UTC()
			if r.Created == nil || *r.Created <= 0 || *r.Created > *r.Completed || at.After(now) {
				rows.Close()
				return errors.New("parse_error")
			}
			counts := HistoryCounts{Input: r.Input, Output: r.Output, Reasoning: r.Reasoning, CacheRead: r.Read, CacheWrite: r.Write}
			for _, n := range []*int64{r.Input, r.Output, r.Reasoning, r.Read, r.Write} {
				if n != nil && historyCount(n) == nil {
					rows.Close()
					return errors.New("parse_error")
				}
			}
			if !at.Before(now.AddDate(0, 0, -35)) {
				if _, exists := s.Working[key]; !exists && len(s.Working) >= openCodeEntryLimit {
					rows.Close()
					return errors.New("schema_changed")
				}
				model := r.Model
				if !openCodeModel.MatchString(model) {
					model = ""
				}
				s.Working[key] = openCodeEntry{Order: row, SessionRef: historyHash(a.Key, "opencode-v2/session/"+a.ProfileRef, session.String), At: at, Model: model, HistoryCounts: counts}
			}
		} else {
			delete(s.Working, key)
		}
		s.Mark = openCodeMark{Updated: updated, Row: row}
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	if err = tx.Commit(); err != nil {
		return err
	}
	afterIdentity, afterSignature, err := openCodeSource(path, a.Key)
	if err != nil {
		return err
	}
	if afterIdentity != identity {
		return errors.New("file_unreadable")
	}
	s.SourceRef, s.Identity, s.Signature = source, identity, signature
	s.RowsRead = count
	if afterSignature != signature {
		s.Pending = true
	}
	s.Availability = "partial"
	if !s.Pending {
		s.Entries = s.Working
		s.Working = nil
		s.Recovering = false
		s.Availability = "ok"
		for _, e := range s.Entries {
			if e.Model == "" {
				s.Availability = "partial"
				break
			}
		}
	}
	return nil
}
