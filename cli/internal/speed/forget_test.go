// SPDX-License-Identifier: MIT
package speed

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestForgetSourceIsAtomicAndKeepsOtherSources(t *testing.T) {
	cache := t.TempDir()
	if err := os.MkdirAll(filepath.Dir(PerfPath(cache)), 0700); err != nil { t.Fatal(err) }
	l := PerfLedger{SchemaVersion: 1, Since: time.Now(), Rows: []PerfRow{{Source:"codex"}, {Source:"claude-code"}}, Hourly: []Hourly{{Source:"codex"}, {Source:"claude-code"}}, Sessions: []PerfSession{{Source:"codex"}, {Source:"claude-code"}}, Live: []LiveRecord{{Source:"codex"}, {Source:"claude-code"}}, Files: map[string]Cursor{"opaque": {Offset: 10}}}
	original, err := json.Marshal(l)
	if err != nil { t.Fatal(err) }
	if err := os.WriteFile(PerfPath(cache), original, 0600); err != nil { t.Fatal(err) }
	if err := forgetSource(cache, "codex", func(string, []byte) error { return errors.New("simulated crash before rename") }); err == nil { t.Fatal("expected failure") }
	got, err := os.ReadFile(PerfPath(cache))
	if err != nil || !bytes.Equal(got, original) { t.Fatal("failed rewrite modified original", err) }
	if err := ForgetSource(cache, "codex"); err != nil { t.Fatal(err) }
	after, ok := LoadPerf(cache)
	if !ok || len(after.Rows) != 1 || after.Rows[0].Source != "claude-code" || len(after.Hourly) != 1 || after.Hourly[0].Source != "claude-code" || len(after.Sessions) != 1 || after.Sessions[0].Source != "claude-code" || len(after.Live) != 1 || after.Live[0].Source != "claude-code" || after.Files["opaque"].Offset != 10 { t.Fatalf("wrong cleanup: %#v", after) }
}
