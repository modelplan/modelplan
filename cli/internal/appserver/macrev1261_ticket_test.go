// SPDX-License-Identifier: MIT
package appserver

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/logindex"
	"github.com/modelplan/modelplan/cli/internal/profile"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// macrev2-1261-2 (round 4): the production watcher captures Allow, then pauses before it builds
// its paths; a denied view processes the withdrawal; the watcher resumes. It must return no
// rollout, leave the inventory empty and cache no path or own thread. A later grant reads again.
func TestMacrev1261WithdrawalBetweenAdmissionAndTicket(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv(profile.RootEnv, t.TempDir())
	t.Setenv("MODELPLAN_READERS", "")
	codexHome := t.TempDir()
	dir := filepath.Join(codexHome, "sessions", "2026", "11", "20")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 12; i++ {
		os.WriteFile(filepath.Join(dir, fmt.Sprintf("rollout-2026-11-20T10-00-00-thread%d.jsonl", i)), []byte("{}\n"), 0o600)
	}
	write := func(gen uint64, allowed bool) consent.Admission {
		s := consent.Empty()
		s.StoreEpoch, s.Generation = "0123456789abcdef0123456789abcdef", gen
		s.Tools["codex"] = consent.Record{Allowed: allowed, ConsentTextVersion: consent.TextVersion}
		b, _ := json.Marshal(s)
		os.MkdirAll(filepath.Dir(consent.Path()), 0o700)
		if err := os.WriteFile(consent.Path(), b, 0o600); err != nil {
			t.Fatal(err)
		}
		return consent.NewAdmission(s, consent.Automatic)
	}
	write(1, true)
	if !consent.Capture().Allows("codex", consent.Local) {
		t.Fatal("the synthetic store does not allow Codex")
	}
	inv := &logindex.Inventory{}
	index := &quota.CodexRolloutIndex{Inventory: inv, RequireTicket: true}
	paused := false
	b := &SharedBackend{config: SharedConfig{
		Detect: func() detect.Report { return detect.Report{} },
		Paths: func(a consent.Admission) quota.Paths {
			return quota.Paths{CodexHome: codexHome, Admission: &a, CodexIndex: index}
		},
		WatchPaths: func(a consent.Admission) quota.Paths {
			if !paused { // after the admission was captured, before the paths are built
				paused = true
				denied := write(2, false)
				quota.Paths{CodexHome: codexHome, CodexThread: "thread3", Admission: &denied, CodexIndex: index, CodexTicket: index.Ticket()}.RecentCodexRollouts()
			}
			return quota.Paths{CodexHome: codexHome, CodexThread: "thread3", Admission: &a, CodexIndex: index}
		},
		Ticket: index.Ticket,
	}}
	var w watchState
	b.pollWatch(&w, time.Now())
	if !paused {
		t.Fatal("the watcher did not reach its paths")
	}
	if len(w.codexStamps) != 0 {
		t.Fatalf("the resumed watcher returned %d rollouts", len(w.codexStamps))
	}
	if n := inv.Retained(); n != 0 {
		t.Fatalf("the inventory holds %d files after the withdrawal", n)
	}
	if paths, own, thread := index.Cached(); paths != 0 || own || thread {
		t.Fatalf("the selection cache holds %d paths, own %v, thread %v", paths, own, thread)
	}
	// A later grant is read by the next poll.
	write(3, true)
	w = watchState{}
	b.pollWatch(&w, time.Now())
	if len(w.codexStamps) == 0 {
		t.Fatal("a later grant read nothing")
	}
}
