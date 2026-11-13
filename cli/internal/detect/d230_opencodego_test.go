// SPDX-License-Identifier: MIT
package detect

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// D230 (owner 2026-11-13): OpenCode installed is not an OpenCode Go subscription. The subscription is
// found from an "opencode-go" entry in OpenCode's own key store, by existence only. Synthetic homes;
// the secret below must never reach the report.
const d230Secret = "sk-synthetic-opencode-go-SECRET-never-read"

func d230Home(t *testing.T) string {
	t.Helper()
	home := t.TempDir()
	if err := os.MkdirAll(filepath.Join(home, ".config", "opencode"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(home, ".local", "share", "opencode"), 0o700); err != nil {
		t.Fatal(err)
	}
	return home
}

func d230Tool(t *testing.T, e Env) Tool {
	t.Helper()
	r := Run(Fallback(), e, "1.0.0", "built-in")
	b, _ := json.Marshal(r)
	if bytes.Contains(b, []byte(d230Secret)) || bytes.Contains(b, []byte("SECRET")) {
		t.Fatal("the key value reached the detection report")
	}
	for _, tool := range r.Tools {
		if tool.ProviderID == "opencodego" {
			return tool
		}
	}
	t.Fatal("no OpenCode detector")
	return Tool{}
}

func d230DB(t *testing.T, home, integration string, active int) {
	t.Helper()
	path := filepath.Join(home, ".local", "share", "opencode", "opencode.db")
	u := url.URL{Scheme: "file", Path: path}
	db, err := sql.Open("sqlite", u.String())
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	for _, q := range []string{`CREATE TABLE IF NOT EXISTS credential (integration_id TEXT, active INTEGER, value TEXT)`} {
		if _, err := db.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := db.Exec(`INSERT INTO credential VALUES (?, ?, ?)`, integration, active, d230Secret); err != nil {
		t.Fatal(err)
	}
}

func d230Auth(t *testing.T, home, body string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(home, ".local", "share", "opencode", "auth.json"), []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestD230OpenCodeGoSubscriptionIsFoundByEntryExistenceOnly(t *testing.T) {
	cases := []struct {
		name  string
		setup func(t *testing.T, home string, e *Env)
		want  string
	}{
		{"OpenCode only", func(*testing.T, string, *Env) {}, SubscriptionNotFound},
		{"auth.json opencode-go entry", func(t *testing.T, h string, _ *Env) {
			d230Auth(t, h, `{"anthropic":{"type":"api","key":"x"},"opencode-go":{"type":"api","key":"`+d230Secret+`"}}`)
		}, SubscriptionFound},
		{"auth.json other provider whose value names opencode-go", func(t *testing.T, h string, _ *Env) {
			d230Auth(t, h, `{"openrouter":{"type":"api","key":"opencode-go","note":{"opencode-go":1}},"x":["opencode-go"]}`)
		}, SubscriptionNotFound},
		{"database active row", func(t *testing.T, h string, _ *Env) { d230DB(t, h, "opencode-go", 1) }, SubscriptionFound},
		{"database inactive row", func(t *testing.T, h string, _ *Env) { d230DB(t, h, "opencode-go", 0) }, SubscriptionNotFound},
		{"database other integration", func(t *testing.T, h string, _ *Env) { d230DB(t, h, "anthropic", 1) }, SubscriptionNotFound},
		{"OPENCODE_API_KEY set", func(_ *testing.T, _ string, e *Env) { e.OpenCodeKeySet = true }, SubscriptionFound},
		{"XDG_DATA_HOME store", func(t *testing.T, h string, e *Env) {
			e.DataHome = filepath.Join(h, "xdg")
			if err := os.MkdirAll(filepath.Join(e.DataHome, "opencode"), 0o700); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(filepath.Join(e.DataHome, "opencode", "auth.json"), []byte(`{"opencode-go":{"key":"`+d230Secret+`"}}`), 0o600); err != nil {
				t.Fatal(err)
			}
		}, SubscriptionFound},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			home := d230Home(t)
			e := Env{Home: home, Path: t.TempDir(), OS: "darwin"}
			tc.setup(t, home, &e)
			tool := d230Tool(t, e)
			if !tool.Detected {
				t.Fatal("OpenCode itself must stay detected (its local history is readable)")
			}
			if tool.Subscription != tc.want {
				t.Fatalf("subscription %q, want %q", tool.Subscription, tc.want)
			}
			undetected := strings.Join(tool.UndetectedScopes(), ",")
			if (tc.want == SubscriptionNotFound) != (undetected == OpenCodeGoScope) {
				t.Fatalf("undetected scopes %q", undetected)
			}
		})
	}
	// Not installed: no subscription check runs at all.
	if tool := d230Tool(t, Env{Home: t.TempDir(), Path: t.TempDir(), OS: "darwin"}); tool.Subscription != "" || tool.UndetectedScopes() != nil {
		t.Fatalf("checked an absent tool: %+v", tool)
	}
}

// The key-only scan hands out key names and nothing else: every visited slice is a top-level key,
// and no value byte (the secret) is ever passed to the caller.
func TestD230AuthScanVisitsKeysOnlyNeverValues(t *testing.T) {
	body := []byte(` {"a\"b": {"key": "` + d230Secret + `", "n": [1, {"opencode-go": "` + d230Secret + `"}]}, "opencode-go" : {"key":"` + d230Secret + `"}, "z": "` + d230Secret + `", "num": 12.5, "t": true}`)
	var keys []string
	topLevelKeys(body, func(k []byte) {
		if bytes.Contains(k, []byte("SECRET")) {
			t.Fatalf("a value reached the visitor: %q", k)
		}
		keys = append(keys, string(k))
	})
	if strings.Join(keys, "|") != `a\"b|opencode-go|z|num|t` {
		t.Fatalf("keys %q", keys)
	}
	// Truncated or malformed stores never count as an entry.
	for _, bad := range []string{``, `[]`, `{"opencode-go"`, `{"opencode-go":`, `{"opencode-go":{"key":"x"`, `"opencode-go"`} {
		topLevelKeys([]byte(bad), func(k []byte) {
			if string(k) == "opencode-go" {
				t.Fatalf("malformed %q counted", bad)
			}
		})
	}
	// An oversized file is not read at all.
	dir := t.TempDir()
	big := filepath.Join(dir, "auth.json")
	if err := os.WriteFile(big, append([]byte(`{"opencode-go":{"key":"x"},"pad":"`), append(bytes.Repeat([]byte("a"), 70<<10), '"', '}')...), 0o600); err != nil {
		t.Fatal(err)
	}
	if authFileHasKey(big, "opencode-go") {
		t.Fatal("an oversized key store was scanned")
	}
}
