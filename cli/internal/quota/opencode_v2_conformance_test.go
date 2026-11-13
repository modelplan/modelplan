// SPDX-License-Identifier: MIT
package quota

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// This external caller fixture belongs to the existing uncached conformance
// entrypoint. The detailed V2 adapter/recovery fixtures live in localusage.
func TestReaderReasonOpenCodeV2LocalStore(t *testing.T) {
	for _, tc := range []struct{ name, want string }{
		{"missing", "file_missing"},
		{"directory", "file_unreadable"},
		{"v1-schema", "schema_changed"},
		{"malformed-projection", "parse_error"},
		{"canceled", "timeout"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			testenv.IsolateHome(t)
			t.Setenv("MODELPLAN_READERS", "")
			t.Setenv("MODELPLAN_HISTORY", "")
			path := filepath.Join(os.Getenv("HOME"), "opencode.db")
			cache := t.TempDir()
			access := localusage.HistoryAccess{Allowed: true, Privacy: "passive", Key: bytes.Repeat([]byte{7}, 32), ProfileRef: strings.Repeat("a", 64), CaptureAllowed: func(*consent.CaptureStamp) bool { return true }}
			now := time.Date(2026, 10, 30, 12, 0, 0, 0, time.UTC)
			if tc.name == "directory" {
				if err := os.Mkdir(path, 0700); err != nil {
					t.Fatal(err)
				}
			}
			if tc.name == "v1-schema" || tc.name == "malformed-projection" {
				db, err := sql.Open("sqlite", path)
				if err != nil {
					t.Fatal(err)
				}
				if tc.name == "v1-schema" {
					_, err = db.Exec(`CREATE TABLE message(id TEXT,data TEXT)`)
				} else {
					_, err = db.Exec(`CREATE TABLE session_v2(id TEXT,parent_id TEXT,fork_session_id TEXT);
     CREATE TABLE session_message(id TEXT,session_id TEXT,type TEXT,time_updated INTEGER,data TEXT);
     INSERT INTO session_v2 VALUES('session-private-canary',NULL,NULL);
     INSERT INTO session_message VALUES('message-private-canary','session-private-canary','assistant',1,'arbitrary private error canary');`)
				}
				db.Close()
				if err != nil {
					t.Fatal(err)
				}
			}
			ctx := context.Background()
			if tc.name == "canceled" {
				var cancel context.CancelFunc
				ctx, cancel = context.WithCancel(ctx)
				cancel()
			}
			finish := testenv.CaptureReasonLogs(t)
			defer func() {
				if err := finish(); err != nil {
					t.Error(err)
				}
			}()
			result := localusage.RefreshOpenCodeV2(ctx, path, cache, access, now)
			if result.Reason != tc.want {
				t.Errorf("reason=%q want=%q", result.Reason, tc.want)
			}
			if err := testenv.CheckReaderReasons(result); err != nil {
				t.Fatal(err)
			}
			retained := localusage.ReadOpenCodeV2Cache(cache, access, now.Add(time.Minute))
			if tc.name != "canceled" && retained.Reason != tc.want {
				t.Errorf("retained reason=%q want=%q", retained.Reason, tc.want)
			}
			if err := testenv.CheckReaderReasons(retained); err != nil {
				t.Fatal(err)
			}
			public, _ := json.Marshal(result)
			if err := filepath.WalkDir(cache, func(path string, d os.DirEntry, err error) error {
				if err != nil {
					return err
				}
				if d.IsDir() {
					return nil
				}
				data, err := os.ReadFile(path)
				if err != nil {
					return err
				}
				if strings.HasSuffix(path, ".json") {
					if err := testenv.CheckReaderReasons(data); err != nil {
						return err
					}
				}
				public = append(public, data...)
				return nil
			}); err != nil {
				t.Fatal(err)
			}
			for _, canary := range []string{"session-private-canary", "message-private-canary", "arbitrary private error canary", os.Getenv("HOME")} {
				if bytes.Contains(public, []byte(canary)) {
					t.Fatal("private data escaped the external reader seam")
				}
			}
		})
	}
}
