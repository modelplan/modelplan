// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

// OpenCode Go, third source: OpenCode's own saved login (owner decision D90). Read only, once per
// refresh, never written, never refreshed. v2 keeps credentials in the CLI's SQLite database (table
// credential); older installs keep an "opencode-go" entry in auth.json. The rules follow
// CodexBar's OpenCodeGoLocalUsageReader (MIT): honour XDG_DATA_HOME (absolute only) and
// OPENCODE_DB, take the active opencode-go row (else opencode), refuse two active rows for the same
// integration, accept a key or an unexpired OAuth access token. The token only goes to the
// compiled opencode.ai host, like any other OpenCode Go key.

func opencodeDataDir() string {
	if x := os.Getenv("XDG_DATA_HOME"); filepath.IsAbs(x) {
		return filepath.Join(x, "opencode")
	}
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return ""
	}
	return filepath.Join(home, ".local", "share", "opencode")
}

func opencodeDBPath(dir string) string {
	name := os.Getenv("OPENCODE_DB")
	switch {
	case name == ":memory:":
		return ""
	case name == "":
		return filepath.Join(dir, "opencode.db")
	case filepath.IsAbs(name):
		return name
	}
	return filepath.Join(dir, name)
}

// OpenCodeLoginPresent is a cheap check for the login files; it reads no content.
func OpenCodeLoginPresent() bool {
	dir := opencodeDataDir()
	if dir == "" {
		return false
	}
	for _, p := range []string{opencodeDBPath(dir), filepath.Join(dir, "auth.json")} {
		if p == "" {
			continue
		}
		if fi, err := os.Lstat(p); err == nil && fi.Mode().IsRegular() {
			return true
		}
	}
	return false
}

func opencodeToken(v string) (string, bool) {
	if !validManualKey(v) {
		return "", false
	}
	return v, true
}

// opencodeLoginKey returns OpenCode's saved key or token. A missing login is code "no_key"; a login
// that is there but unusable is "unsupported_login".
func opencodeLoginKey(ctx context.Context, now time.Time) (string, string) {
	dir := opencodeDataDir()
	if dir == "" {
		return "", "no_key"
	}
	if path := opencodeDBPath(dir); path != "" {
		if fi, err := os.Lstat(path); err == nil {
			if !fi.Mode().IsRegular() {
				return "", "unsupported_login"
			}
			key, found, code := opencodeDBKey(ctx, path, now)
			if code != "" {
				return "", code
			}
			if found {
				return key, ""
			}
		}
	}
	return opencodeAuthFileKey(filepath.Join(dir, "auth.json"))
}

// opencodeDBKey: found is false when the database has no credential table or no active row, so the
// caller may fall back to auth.json.
func opencodeDBKey(ctx context.Context, path string, now time.Time) (key string, found bool, code string) {
	// Never write into the other tool's directory (D90): with a WAL or shared-memory file present SQLite would update
	// them even in read-only mode, so the database and its sidecars are read from a private copy instead; without
	// sidecars the original is opened immutable.
	_, walErr := os.Stat(path + "-wal")
	_, shmErr := os.Stat(path + "-shm")
	query := "mode=ro&_pragma=query_only(1)&_pragma=busy_timeout(250)"
	if walErr == nil || shmErr == nil {
		copied, cleanup, err := snapshotSQLite(path)
		if err != nil {
			return "", false, "unsupported_login"
		}
		defer cleanup()
		path = copied
	} else {
		query += "&immutable=1"
	}
	u := url.URL{Scheme: "file", Path: filepath.ToSlash(path), RawQuery: query}
	db, err := sql.Open("sqlite", u.String())
	if err != nil {
		return "", false, "unsupported_login"
	}
	defer db.Close()
	db.SetMaxOpenConns(1)
	var one int
	if err := db.QueryRowContext(ctx, `SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'credential' LIMIT 1`).Scan(&one); err != nil {
		if err == sql.ErrNoRows {
			return "", false, ""
		}
		return "", false, "unsupported_login"
	}
	rows, err := db.QueryContext(ctx, `SELECT integration_id, value FROM credential WHERE active = 1 AND integration_id IN ('opencode-go', 'opencode') ORDER BY CASE integration_id WHEN 'opencode-go' THEN 0 ELSE 1 END LIMIT 2`)
	if err != nil {
		return "", false, "unsupported_login"
	}
	defer rows.Close()
	type row struct {
		id    string
		value []byte
	}
	var got []row
	for rows.Next() {
		var r row
		if rows.Scan(&r.id, &r.value) != nil || len(r.value) > 16<<10 {
			return "", false, "unsupported_login"
		}
		got = append(got, r)
	}
	if rows.Err() != nil {
		return "", false, "unsupported_login"
	}
	if len(got) == 0 {
		return "", false, ""
	}
	// Two active rows for the chosen integration are ambiguous: never pick an arbitrary account.
	if len(got) == 2 && got[0].id == got[1].id {
		return "", false, "unsupported_login"
	}
	var c struct {
		Type    string   `json:"type"`
		Key     string   `json:"key"`
		Access  string   `json:"access"`
		Expires *float64 `json:"expires"`
	}
	if json.Unmarshal(got[0].value, &c) != nil {
		return "", false, "unsupported_login"
	}
	switch c.Type {
	case "key":
		if t, ok := opencodeToken(c.Key); ok {
			return t, true, ""
		}
	case "oauth":
		if c.Expires != nil && *c.Expires >= 0 && *c.Expires/1000 > float64(now.Unix()) {
			if t, ok := opencodeToken(c.Access); ok {
				return t, true, ""
			}
		}
	}
	return "", false, "unsupported_login"
}

func opencodeAuthFileKey(path string) (string, string) {
	fi, err := os.Lstat(path)
	if err != nil {
		return "", "no_key"
	}
	if !fi.Mode().IsRegular() {
		return "", "unsupported_login"
	}
	b, status := readBounded(path, 256<<10)
	if status != "" {
		return "", "unsupported_login"
	}
	var entries map[string]json.RawMessage
	if json.Unmarshal(b, &entries) != nil {
		return "", "unsupported_login"
	}
	raw, ok := entries["opencode-go"]
	if !ok {
		return "", "no_key"
	}
	var e struct {
		Type string `json:"type"`
		Key  string `json:"key"`
	}
	if json.Unmarshal(raw, &e) != nil {
		return "", "unsupported_login"
	}
	if e.Type != "api" {
		return "", "no_key"
	}
	if t, ok := opencodeToken(strings.TrimSpace(e.Key)); ok {
		return t, ""
	}
	return "", "unsupported_login"
}

// snapshotSQLite copies a database and its -wal and -shm files (when present) into a private temporary directory and
// returns the copy's path. The originals are only read.
func snapshotSQLite(path string) (string, func(), error) {
	dir, err := os.MkdirTemp("", "modelplan-sqlite-")
	if err != nil {
		return "", func() {}, err
	}
	cleanup := func() { os.RemoveAll(dir) }
	for _, suffix := range []string{"", "-wal", "-shm"} {
		src, err := os.Open(path + suffix)
		if err != nil {
			if suffix != "" && errors.Is(err, os.ErrNotExist) {
				continue
			}
			cleanup()
			return "", func() {}, err
		}
		dst, err := os.OpenFile(filepath.Join(dir, "db"+suffix), os.O_CREATE|os.O_WRONLY|os.O_EXCL, 0o600)
		if err != nil {
			src.Close()
			cleanup()
			return "", func() {}, err
		}
		_, err = io.Copy(dst, io.LimitReader(src, 256<<20))
		src.Close()
		if cerr := dst.Close(); err == nil {
			err = cerr
		}
		if err != nil {
			cleanup()
			return "", func() {}, err
		}
	}
	return filepath.Join(dir, "db"), cleanup, nil
}
