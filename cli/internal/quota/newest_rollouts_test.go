// SPDX-License-Identifier: MIT
package quota

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// A resumed session lives in its start day's directory; when it is the most recently
// written log it must be found even behind a busier, newer day (audit C, P2).
func TestNewestRolloutsFindsResumedOlderSession(t *testing.T) {
	root := t.TempDir()
	base := time.Date(2026, 11, 11, 9, 0, 0, 0, time.UTC)
	write := func(day, name string, mod time.Time) string {
		dir := filepath.Join(root, "2026", "11", day)
		if err := os.MkdirAll(dir, 0o700); err != nil {
			t.Fatal(err)
		}
		p := filepath.Join(dir, name)
		if err := os.WriteFile(p, []byte("{}\n"), 0o600); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(p, mod, mod); err != nil {
			t.Fatal(err)
		}
		return p
	}
	for i := 0; i < 16; i++ {
		write("11", fmt.Sprintf("rollout-today-%02d.jsonl", i), base.Add(time.Duration(i)*time.Minute))
	}
	resumed := write("10", "rollout-yesterday.jsonl", base.Add(time.Hour))
	got := newestRollouts(root, 8)
	if len(got) != 8 || got[0] != resumed {
		t.Fatalf("resumed session not first: %v", got)
	}
}
