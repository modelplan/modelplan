// SPDX-License-Identifier: MIT
package detect

import (
	"database/sql"
	"io"
	"net/url"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite" // pure Go; read-only, query-only open
)

// OpenCode Go subscription evidence (G3-105, owner decision D230, 2026-11-13). Finding OpenCode says
// nothing about an OpenCode Go subscription; an "opencode-go" entry in OpenCode's own key store does.
// This checks that the entry EXISTS and nothing else: the SQLite query selects no value column, and
// auth.json is scanned for its top-level key names only; every value byte is skipped, never copied,
// and the read buffer is zeroed before returning. Nothing is stored, logged or sent.

// OpenCodeGoScope is the account-usage path that only an OpenCode Go subscription can serve.
const OpenCodeGoScope = "opencodego.account_usage.api_key"

const (
	SubscriptionFound    = "found"
	SubscriptionNotFound = "not-found"
)

// UndetectedScopes lists the tool's paths whose own evidence is missing although the tool is
// detected (OpenCode installed, no OpenCode Go key): consent facts report them as not detected.
func (t Tool) UndetectedScopes() []string {
	if t.ProviderID == "opencodego" && t.Detected && t.Subscription == SubscriptionNotFound {
		return []string{OpenCodeGoScope}
	}
	return nil
}

func (e Env) openCodeDataDir() string {
	if filepath.IsAbs(e.DataHome) {
		return filepath.Join(e.DataHome, "opencode")
	}
	if e.Home == "" {
		return ""
	}
	return filepath.Join(e.Home, ".local", "share", "opencode")
}

// openCodeGoSubscription: an OPENCODE_API_KEY in the environment, an active opencode-go row in
// opencode.db's credential table, or an "opencode-go" entry in the legacy auth.json.
func (e Env) openCodeGoSubscription() string {
	if e.OpenCodeKeySet {
		return SubscriptionFound
	}
	dir := e.openCodeDataDir()
	if dir == "" {
		return SubscriptionNotFound
	}
	db := filepath.Join(dir, "opencode.db")
	switch {
	case e.OpenCodeDB == ":memory:":
		db = ""
	case filepath.IsAbs(e.OpenCodeDB):
		db = e.OpenCodeDB
	case e.OpenCodeDB != "":
		db = filepath.Join(dir, e.OpenCodeDB)
	}
	if db != "" && openCodeDBHasGoEntry(db) {
		return SubscriptionFound
	}
	if authFileHasKey(filepath.Join(dir, "auth.json"), "opencode-go") {
		return SubscriptionFound
	}
	return SubscriptionNotFound
}

// openCodeDBHasGoEntry asks only whether an active opencode-go credential row exists. The database is
// opened read-only and query-only (never immutable: OpenCode runs in WAL mode, and an immutable open
// ignores the WAL, so a committed credential still in the WAL of a running OpenCode would be missed).
// No checkpoint is run and no row of the source is changed.
func openCodeDBHasGoEntry(path string) bool {
	if fi, err := os.Lstat(path); err != nil || !fi.Mode().IsRegular() {
		return false
	}
	u := url.URL{Scheme: "file", Path: path, RawQuery: "mode=ro&_pragma=query_only(1)&_pragma=trusted_schema(0)&_pragma=busy_timeout(100)"}
	db, err := sql.Open("sqlite", u.String())
	if err != nil {
		return false
	}
	defer db.Close()
	var exists int
	err = db.QueryRow(`SELECT EXISTS(SELECT 1 FROM credential WHERE active = 1 AND integration_id = 'opencode-go')`).Scan(&exists)
	return err == nil && exists == 1
}

// authFileHasKey reads at most 64 KiB, reports whether the top-level object has the key, and zeroes
// the buffer before returning.
func authFileHasKey(path, key string) bool {
	fi, err := os.Lstat(path)
	if err != nil || !fi.Mode().IsRegular() || fi.Size() > 64<<10 {
		return false
	}
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	buf := make([]byte, 64<<10+1)
	n, _ := io.ReadFull(f, buf)
	defer clear(buf)
	if n > 64<<10 {
		return false
	}
	found := false
	topLevelKeys(buf[:n], func(k []byte) { found = found || string(k) == key })
	return found
}

// topLevelKeys calls visit with each key of the top-level JSON object. Values (strings, numbers,
// objects, arrays) are stepped over byte by byte and never copied or handed out. Malformed input
// stops the scan.
func topLevelKeys(b []byte, visit func([]byte)) {
	i := skipSpace(b, 0)
	if i >= len(b) || b[i] != '{' {
		return
	}
	i++
	for {
		i = skipSpace(b, i)
		if i < len(b) && b[i] == '}' {
			return
		}
		if i >= len(b) || b[i] != '"' {
			return
		}
		end, ok := stringEnd(b, i)
		if !ok {
			return
		}
		name := b[i+1 : end]
		i = skipSpace(b, end+1)
		if i >= len(b) || b[i] != ':' {
			return
		}
		if i, ok = skipValue(b, skipSpace(b, i+1)); !ok {
			return
		}
		visit(name) // only a key whose value was complete
		i = skipSpace(b, i)
		if i < len(b) && b[i] == ',' {
			i++
			continue
		}
		return
	}
}

func skipSpace(b []byte, i int) int {
	for i < len(b) && (b[i] == ' ' || b[i] == '\t' || b[i] == '\n' || b[i] == '\r') {
		i++
	}
	return i
}

// stringEnd returns the index of the closing quote of the string starting at b[i] == '"'.
func stringEnd(b []byte, i int) (int, bool) {
	for j := i + 1; j < len(b); j++ {
		switch b[j] {
		case '\\':
			j++
		case '"':
			return j, true
		}
	}
	return 0, false
}

// skipValue returns the index just past the value starting at b[i].
func skipValue(b []byte, i int) (int, bool) {
	if i >= len(b) {
		return 0, false
	}
	if b[i] == '"' {
		end, ok := stringEnd(b, i)
		return end + 1, ok
	}
	depth := 0
	for j := i; j < len(b); j++ {
		switch b[j] {
		case '"':
			end, ok := stringEnd(b, j)
			if !ok {
				return 0, false
			}
			j = end
		case '{', '[':
			depth++
		case '}', ']':
			if depth == 0 {
				return j, true
			}
			depth--
			if depth == 0 {
				return j + 1, true
			}
		case ',':
			if depth == 0 {
				return j, true
			}
		}
	}
	return len(b), depth == 0
}
