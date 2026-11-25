// SPDX-License-Identifier: MIT
package quota

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/idlework"
	"github.com/modelplan/modelplan/cli/internal/logindex"
)

// staticHistory writes days x perDay rollouts under home/sessions, the newest day ending at
// last, every file and directory last changed long before start.
func staticHistory(t testing.TB, home string, days, perDay int, last time.Time) (newestDay string) {
	t.Helper()
	old := last.Add(-30 * 24 * time.Hour)
	for d := 0; d < days; d++ {
		at := last.Add(-time.Duration(days-1-d) * 24 * time.Hour)
		dir := filepath.Join(home, "sessions", at.Format("2006"), at.Format("01"), at.Format("02"))
		if err := os.MkdirAll(dir, 0o700); err != nil {
			t.Fatal(err)
		}
		for r := 0; r < perDay; r++ {
			p := filepath.Join(dir, fmt.Sprintf("rollout-%s-%04d-thread%d-%d.jsonl", at.Format("2006-01-02T15-04-05"), r, d, r))
			if err := os.WriteFile(p, []byte("{}\n"), 0o600); err != nil {
				t.Fatal(err)
			}
			mod := at.Add(time.Duration(r) * time.Second)
			os.Chtimes(p, mod, mod)
		}
		newestDay = dir
	}
	_ = filepath.WalkDir(filepath.Join(home, "sessions"), func(p string, d os.DirEntry, err error) error {
		if err == nil && d.IsDir() {
			defer os.Chtimes(p, old, old)
		}
		return nil
	})
	return newestDay
}

// idleTicks runs the watcher's one-second selection n times from start and returns the bytes
// allocated by ticks 1-5 (between the warm-up and the first hot check) and the entries copied
// out of the inventory over all n ticks.
func idleTicks(t *testing.T, days, perDay, n int, thread string) (tickBytes uint64, copied int64) {
	t.Helper()
	home := t.TempDir()
	start := time.Date(2026, 11, 20, 12, 0, 0, 0, time.UTC)
	staticHistory(t, home, days, perDay, start.Add(-48*time.Hour))
	var index CodexRolloutIndex
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	if files, _ := index.recent(home, thread, fence, start); len(files) == 0 {
		t.Fatal("warm-up selected nothing")
	}
	var a, b runtime.MemStats
	runtime.GC()
	runtime.ReadMemStats(&a)
	for i := 1; i <= 5; i++ {
		index.recent(home, thread, fence, start.Add(time.Duration(i)*time.Second))
	}
	runtime.ReadMemStats(&b)
	before := idlework.CopiedCount()
	for i := 6; i <= n; i++ {
		index.recent(home, thread, fence, start.Add(time.Duration(i)*time.Second))
	}
	return (b.TotalAlloc - a.TotalAlloc) / 5, idlework.CopiedCount() - before
}

// #1222 sampling P2: an idle watcher tick costs the same with 20 or 400 rollouts a day, and no
// idle tick copies the inventory, across hot checks and the cold reconciliation.
func TestIdleRolloutSelectionIndependentOfHistorySize(t *testing.T) {
	for _, thread := range []string{"", "thread3-1"} {
		small, copiedSmall := idleTicks(t, 30, 20, 70, thread)
		large, copiedLarge := idleTicks(t, 30, 400, 70, thread)
		if copiedSmall != 0 || copiedLarge != 0 {
			t.Fatalf("thread %q: idle ticks copied %d / %d inventory entries, want 0", thread, copiedSmall, copiedLarge)
		}
		if large > small+small/2+1024 {
			t.Fatalf("thread %q: an idle tick allocates %d bytes with 12,000 rollouts and %d with 600", thread, large, small)
		}
	}
}

// The cached selection is the selection: after a change the next tick reflects it.
func TestIdleRolloutSelectionFollowsChanges(t *testing.T) {
	home := t.TempDir()
	start := time.Date(2026, 11, 20, 12, 0, 0, 0, time.UTC)
	newest := staticHistory(t, home, 5, 4, start.Add(-48*time.Hour))
	var index CodexRolloutIndex
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	now := start
	check := func(step string) {
		t.Helper()
		got, own := index.recent(home, "thread1-2", fence, now)
		want, wantOwn := selectRollouts(&logindex.Inventory{}, fence, home, "thread1-2", codexFiles, now)
		want = ConfinedRollouts(home, want)
		if fmt.Sprint(got) != fmt.Sprint(want) || own != wantOwn {
			t.Fatalf("%s: cached %v %q, fresh %v %q", step, got, own, want, wantOwn)
		}
	}
	check("warm")
	// A new rollout in the newest day appears within the hot interval.
	p := filepath.Join(newest, "rollout-2026-11-18T12-00-00-new.jsonl")
	os.WriteFile(p, []byte("{}\n"), 0o600)
	now = now.Add(logindex.HotInterval + time.Second)
	check("new rollout")
	// An old rollout is resumed: found by the cold reconciliation.
	old := filepath.Join(home, "sessions", "2026", "11", "14")
	es, _ := os.ReadDir(old)
	resumed := filepath.Join(old, es[0].Name())
	f, _ := os.OpenFile(resumed, os.O_APPEND|os.O_WRONLY, 0)
	f.WriteString("{}\n")
	f.Close()
	os.Chtimes(resumed, now, now)
	now = now.Add(logindex.ColdInterval + time.Second)
	check("resumed")
	// A new fence starts over.
	fence.Generation++
	now = now.Add(time.Second)
	check("new fence")
}

// #1222 sampling P3: the spawn hook's thread lookup lists at most the 62 newest day directories,
// as before #1222, and finds what the inventory-wide lookup finds within them.
func TestFindThreadBoundedTo62Days(t *testing.T) {
	home := t.TempDir()
	last := time.Date(2026, 11, 20, 0, 0, 0, 0, time.UTC)
	staticHistory(t, home, 200, 3, last)
	root := filepath.Join(home, "sessions")
	all := (&logindex.Inventory{}).Files(consent.Fence{}, []logindex.Root{{Dir: root, Source: "codex"}}, last, last)
	for _, c := range []struct {
		thread string
		found  bool
	}{{"thread199-2", true}, {"thread138-0", true}, {"thread137-1", false}, {"thread0-0", false}, {"nothere", false}} {
		before := idlework.Snapshot()
		got := findThread(root, c.thread)
		spent := idlework.Snapshot().Since(before)
		if want := findThreadIn(all, c.thread); got != want || (got != "") != c.found {
			t.Fatalf("%s: bounded %q, inventory-wide %q, want found=%v", c.thread, got, want, c.found)
		}
		// 62 day directories of 3 rollouts, plus the year and month listings (a full scan of the
		// 200-day history lists about 820).
		if spent.Entries > 62*3+8*31+20 {
			t.Fatalf("%s: listed %d entries for a 200-day history", c.thread, spent.Entries)
		}
	}
}

// BenchmarkIdleRolloutMinute: one simulated idle minute of the watcher's one-second Codex
// selection over a static 20,000-rollout history. "uncached" is the selection as it ran before
// (the inventory copied, matched and sorted every tick); "cached" is CodexRolloutIndex now.
func BenchmarkIdleRolloutMinute(b *testing.B) {
	home := b.TempDir()
	start := time.Date(2026, 11, 20, 12, 0, 0, 0, time.UTC)
	staticHistory(b, home, 100, 200, start.Add(-48*time.Hour))
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	for _, mode := range []string{"uncached", "cached"} {
		b.Run(mode, func(b *testing.B) {
			var index CodexRolloutIndex
			index.recent(home, "", fence, start)
			now := start
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				for s := 0; s < 60; s++ {
					now = now.Add(time.Second)
					if mode == "cached" {
						index.recent(home, "", fence, now)
					} else {
						files, _ := selectRollouts(index.inventory(), fence, home, "", codexFiles, now)
						ConfinedRollouts(home, files)
					}
				}
			}
		})
	}
}

// macrev2-1261-2: withdrawing Codex forgets the cached selection, its rollout paths and the own
// thread's path, through the normal withdrawal path (RecentCodexRollouts under an admission that
// no longer allows Codex) and through clear itself.
func TestCodexWithdrawalForgetsSelection(t *testing.T) {
	home := t.TempDir()
	start := time.Date(2026, 11, 20, 12, 0, 0, 0, time.UTC)
	staticHistory(t, home, 3, 4, start.Add(-48*time.Hour))
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	for _, how := range []string{"admission", "clear"} {
		var index CodexRolloutIndex
		if _, own := index.recent(home, "thread1-2", fence, start); own == "" {
			t.Fatal("warm-up found no own thread")
		}
		if index.cache.gen == 0 || len(index.cache.files) == 0 {
			t.Fatal("warm-up cached nothing")
		}
		switch how {
		case "admission":
			state := consent.Empty()
			state.Tools["codex"] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
			denied := consent.NewAdmission(state, consent.Automatic)
			if denied.Allows("codex", consent.Local) {
				t.Fatal("the test admission still allows Codex")
			}
			files, own := Paths{CodexHome: home, CodexThread: "thread1-2", CodexIndex: &index, Admission: &denied}.RecentCodexRollouts()
			if len(files) != 0 || own != "" {
				t.Fatalf("withdrawn Codex still selected %v %q", files, own)
			}
		case "clear":
			index.clear(home, consent.Fence{StoreEpoch: "test", Generation: 2})
		}
		if fmt.Sprint(index.cache) != fmt.Sprint(rolloutSelection{}) {
			t.Fatalf("%s: withdrawn selection kept: %+v", how, index.cache)
		}
	}
}

// macrev2-1261-3: a sessions root that is a symlink is not listed by the spawn hook's lookup.
func TestFindThreadSymlinkedRootListsNothing(t *testing.T) {
	home, elsewhere := t.TempDir(), t.TempDir()
	staticHistory(t, elsewhere, 2, 2, time.Date(2026, 11, 20, 0, 0, 0, 0, time.UTC))
	if err := os.Symlink(filepath.Join(elsewhere, "sessions"), filepath.Join(home, "sessions")); err != nil {
		t.Fatal(err)
	}
	before := idlework.Snapshot()
	if CodexBackgroundThread(home, "thread1-1") {
		t.Fatal("a thread behind a symlinked sessions root was accepted")
	}
	if got := findThread(filepath.Join(home, "sessions"), "thread1-1"); got != "" {
		t.Fatalf("found %q through a symlinked root", got)
	}
	if n := idlework.Snapshot().Since(before).Entries; n != 0 {
		t.Fatalf("listed %d entries through a symlinked sessions root", n)
	}
}

// macrev2-1261-2 (round 2): a watcher call that captured its admission while Codex was allowed and
// resumes after the withdrawal has been processed cannot rebuild the selection or the inventory:
// both stay clear without another denied call.
func TestMacrev1261WithdrawalCannotBeRepopulatedByOldSelection(t *testing.T) {
	home := t.TempDir()
	start := time.Date(2026, 11, 20, 12, 0, 0, 0, time.UTC)
	staticHistory(t, home, 3, 4, start.Add(-48*time.Hour))
	admission := func(gen uint64, allowed bool) consent.Admission {
		state := consent.Empty()
		state.StoreEpoch, state.Generation = "0123456789abcdef0123456789abcdef", gen
		state.Tools["codex"] = consent.Record{Allowed: allowed, ConsentTextVersion: consent.TextVersion}
		return consent.NewAdmission(state, consent.Automatic)
	}
	allowed, denied := admission(1, true), admission(2, false)
	if !allowed.Allows("codex", consent.Local) || denied.Allows("codex", consent.Local) {
		t.Fatal("test admissions do not allow and deny Codex")
	}
	inv := &logindex.Inventory{}
	index := CodexRolloutIndex{Inventory: inv, Clock: func() time.Time { return start }}
	old := Paths{CodexHome: home, CodexThread: "thread1-2", CodexIndex: &index, Admission: &allowed}
	if files, own := old.RecentCodexRollouts(); len(files) == 0 || own == "" {
		t.Fatalf("warm-up: %v %q", files, own)
	}
	// The withdrawal is processed by a denied call (the view or the watcher under the new consent).
	withdrawn := Paths{CodexHome: home, CodexThread: "thread1-2", CodexIndex: &index, Admission: &denied}
	if files, _ := withdrawn.RecentCodexRollouts(); len(files) != 0 {
		t.Fatalf("denied call selected %v", files)
	}
	// The paused watcher call resumes with the admission it captured before the withdrawal.
	files, own := old.RecentCodexRollouts()
	if len(files) != 0 || own != "" {
		t.Fatalf("resumed old call selected %d paths, own %q", len(files), own)
	}
	if index.cache.gen != 0 || len(index.cache.files) != 0 || index.cache.own != "" || index.cache.thread != "" || index.cache.home != "" {
		t.Fatalf("the selection was repopulated: %+v", index.cache)
	}
	if n := inv.Retained(); n != 0 {
		t.Fatalf("the inventory was repopulated with %d files", n)
	}
	// So does a direct selection under the retired fence, and the observation pass's reader.
	index.recent(home, "thread1-2", allowed.Fence(), start)
	if got := RecentRolloutsIn(inv, allowed.Fence(), home, 8, start); len(got) != 0 || inv.Retained() != 0 || index.cache.thread != "" {
		t.Fatalf("an old fence rebuilt the inventory or selection: %d paths, %d retained", len(got), inv.Retained())
	}
	// A new grant under a newer fence reads again.
	regranted := admission(3, true)
	again := Paths{CodexHome: home, CodexThread: "thread1-2", CodexIndex: &index, Admission: &regranted}
	if files, _ := again.RecentCodexRollouts(); len(files) == 0 {
		t.Fatal("a new grant read nothing")
	}
}
