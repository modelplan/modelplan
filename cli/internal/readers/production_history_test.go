// SPDX-License-Identifier: MIT
package readers_test

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/localusage"
)

// The production local history entry point shares the home and tool consent
// with the disabled remote reader; a remote policy gate must not erase it.
func TestProductionPOSTGateKeepsGeminiLocalHistory(t *testing.T) {
	now := time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC)
	paths := postProductionPaths(t, "gemini", now)
	home := os.Getenv("HOME")
	file := filepath.Join(home, ".gemini", "tmp", "synthetic-project", "chats", "session-synthetic.json")
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		t.Fatal(err)
	}
	body := `{"sessionId":"synthetic-session","projectHash":"synthetic-project","messages":[{"id":"synthetic-message","type":"gemini","timestamp":"2026-10-29T10:00:00Z","model":"gemini-test","tokens":{"input":10,"output":2,"total":12}}]}`
	if err := os.WriteFile(file, []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	result := localusage.ProductionHistory(home, paths.Cache, "gemini", false, now)
	if result.Availability != "ok" || len(result.Rows) != 1 || result.Rows[0].Total == nil || *result.Rows[0].Total != 12 {
		t.Fatalf("production local history lost: %+v", result)
	}
}
