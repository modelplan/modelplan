// SPDX-License-Identifier: MIT
package speed

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

// pickLog returns the lines of the largest generated log under dir whose name has prefix.
func pickLog(t *testing.T, dir, prefix string) [][]byte {
	t.Helper()
	var best string
	var size int64
	filepath.WalkDir(dir, func(p string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() && filepath.Ext(p) == ".jsonl" && bytes.HasPrefix([]byte(d.Name()), []byte(prefix)) {
			if fi, _ := d.Info(); fi != nil && fi.Size() > size && fi.ModTime().After(fixtureNow.AddDate(0, 0, -25)) {
				best, size = p, fi.Size()
			}
		}
		return nil
	})
	b, err := os.ReadFile(best)
	if err != nil {
		t.Fatal(err)
	}
	return bytes.SplitAfter(bytes.TrimSuffix(b, []byte("\n")), []byte("\n"))
}

// The incremental live read records exactly what a full re-read records, step by step, while the
// logs grow, end in a torn line, are truncated, rewritten in place, rotated and set back in time.
func TestLiveAccountingIncrementalMatchesFullRead(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	gen := t.TempDir()
	genImportFixture(t, filepath.Join(gen, "claude"), filepath.Join(gen, "codex"), fixtureNow, 2, 11)
	logs := map[string][][]byte{
		"claude-code": pickLog(t, filepath.Join(gen, "claude"), ""),
		"codex":       pickLog(t, filepath.Join(gen, "codex"), "rollout-"),
	}
	dir := t.TempDir()
	inc, full := t.TempDir(), t.TempDir()
	for _, c := range []string{inc, full} {
		seedPerf(t, c, fixtureNow.AddDate(0, 0, -40))
	}
	now := fixtureNow
	join := func(ls [][]byte) []byte { return bytes.Join(ls, nil) }
	type step struct {
		name  string
		write func(path string, ls [][]byte)
	}
	put := func(path string, b []byte) {
		f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
		if err != nil {
			t.Fatal(err)
		}
		f.Write(b)
		f.Close()
	}
	appendB := func(path string, b []byte) {
		f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
		if err != nil {
			t.Fatal(err)
		}
		f.Write(b)
		f.Close()
	}
	n := func(ls [][]byte, frac float64) int { return int(float64(len(ls)) * frac) }
	steps := []step{
		{"start", func(p string, ls [][]byte) { put(p, join(ls[:n(ls, .3)])) }},
		{"append", func(p string, ls [][]byte) { appendB(p, join(ls[n(ls, .3):n(ls, .4)])) }},
		{"torn line", func(p string, ls [][]byte) {
			l := ls[n(ls, .4)]
			appendB(p, l[:len(l)/2])
		}},
		{"torn line completed", func(p string, ls [][]byte) {
			l := ls[n(ls, .4)]
			appendB(p, append(append([]byte{}, l[len(l)/2:]...), join(ls[n(ls, .4)+1:n(ls, .55)])...))
		}},
		{"unchanged", func(string, [][]byte) {}},
		{"truncated", func(p string, ls [][]byte) { os.Truncate(p, int64(len(join(ls[:n(ls, .1)])))) }},
		{"regrown", func(p string, ls [][]byte) { appendB(p, join(ls[n(ls, .1):n(ls, .6)])) }},
		{"rewritten in place, longer", func(p string, ls [][]byte) {
			b := join(ls[:n(ls, .7)])
			b = bytes.Replace(b, []byte(`"output_tokens":`), []byte(`"output_tokens":9`), 1)
			f, _ := os.OpenFile(p, os.O_WRONLY, 0)
			f.WriteAt(b, 0)
			f.Close()
		}},
		{"rotated", func(p string, ls [][]byte) {
			tmp := p + ".new"
			put(tmp, join(ls[n(ls, .2):n(ls, .5)]))
			os.Rename(tmp, p)
		}},
		{"append after rotation", func(p string, ls [][]byte) { appendB(p, join(ls[n(ls, .5):n(ls, .8)])) }},
		{"time set back", func(p string, ls [][]byte) {
			appendB(p, join(ls[n(ls, .8):n(ls, .85)]))
			old := now.Add(-48 * time.Hour)
			os.Chtimes(p, old, old)
		}},
		{"rest", func(p string, ls [][]byte) { appendB(p, join(ls[n(ls, .85):])) }},
	}
	liveReads.full.Store(0)
	liveReads.resumed.Store(0)
	for i, s := range steps {
		now = now.Add(time.Minute)
		for source, ls := range logs {
			path := filepath.Join(dir, source+".jsonl")
			s.write(path, ls)
			if s.name != "time set back" {
				os.Chtimes(path, now, now)
			}
			if err := observeAccounting(inc, source, []string{path}, now); err != nil {
				t.Fatal(err)
			}
			liveIncremental = false
			err := observeAccounting(full, source, []string{path}, now)
			liveIncremental = true
			if err != nil {
				t.Fatal(err)
			}
		}
		a, okA := loadAccounting(inc)
		b, okB := loadAccounting(full)
		if !okA || !okB || len(b.Files) == 0 {
			t.Fatalf("step %d %s: ledgers %v %v %d", i, s.name, okA, okB, len(b.Files))
		}
		if !reflect.DeepEqual(a, b) {
			t.Fatalf("step %d %s: incremental ledger differs from a full re-read", i, s.name)
		}
	}
	if liveReads.resumed.Load() < 6 || liveReads.full.Load() < 6 {
		t.Fatalf("resumed %d, full %d: the steps did not exercise both paths", liveReads.resumed.Load(), liveReads.full.Load())
	}
}

// Erasing a tool's history and withdrawing its grant drop its remembered parsers.
func TestLiveCursorsForgottenOnErase(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, fixtureNow.AddDate(0, 0, -1))
	path := filepath.Join(dir, "s.jsonl")
	os.WriteFile(path, []byte(`{"type":"assistant","timestamp":"2026-11-20T11:00:00Z","message":{"id":"msg_1","model":"m","usage":{"input_tokens":1,"output_tokens":2}}}`+"\n"), 0o600)
	if err := observeAccounting(cache, "claude-code", []string{path}, fixtureNow); err != nil {
		t.Fatal(err)
	}
	has := func() bool {
		liveCursors.Lock()
		defer liveCursors.Unlock()
		_, ok := liveCursors.m[liveCursorKey(cache, "claude-code", path)]
		return ok
	}
	if !has() {
		t.Fatal("no cursor after a read")
	}
	if err := ForgetAccountingLocked(cache, "claude"); err != nil {
		t.Fatal(err)
	}
	if has() {
		t.Fatal("cursor kept after the history was erased")
	}
}

// BenchmarkLiveObserveSteady: the engine's steady refresh. An active 30 MB Claude Code transcript and
// a 20 MB Codex rollout grow by one small turn between observations; each op is one minute at two
// observations per minute (the 30 s live cadence). Sub-benchmarks: main (whole-line decoding, full
// re-reads), full (reduced lines, full re-reads) and incremental (reduced lines, live cursor).
func BenchmarkLiveObserveSteady(b *testing.B) {
	old := time.Local
	time.Local = time.UTC
	defer func() { time.Local = old }()
	grantLocalHistory(b)
	gen := b.TempDir()
	genImportFixture(b, filepath.Join(gen, "claude"), filepath.Join(gen, "codex"), fixtureNow, 12, 3)
	collect := func(dir, prefix string) [][]byte {
		var all [][]byte
		filepath.WalkDir(dir, func(p string, d os.DirEntry, err error) error {
			if err == nil && !d.IsDir() && bytes.HasPrefix([]byte(d.Name()), []byte(prefix)) {
				raw, _ := os.ReadFile(p)
				all = append(all, bytes.SplitAfter(bytes.TrimSuffix(raw, []byte("\n")), []byte("\n"))...)
			}
			return nil
		})
		return all
	}
	for _, mode := range []struct {
		name        string
		inc, reduce bool
	}{{"main", false, false}, {"full", false, true}, {"incremental", true, true}} {
		b.Run(mode.name, func(b *testing.B) {
			liveIncremental, reduceClaudeLines = mode.inc, mode.reduce
			defer func() { liveIncremental, reduceClaudeLines = true, true }()
			dir, cache := b.TempDir(), b.TempDir()
			seedPerf(b, cache, fixtureNow.AddDate(0, 0, -40))
			type log struct {
				path  string
				lines [][]byte
				next  int
			}
			var logs []*log
			for _, src := range []struct {
				name, dir, prefix string
				size              int
			}{{"claude.jsonl", "claude", "", 30 << 20}, {"rollout-live.jsonl", "codex", "rollout-", 20 << 20}} {
				lines := collect(filepath.Join(gen, src.dir), src.prefix)
				var buf bytes.Buffer
				i := 0
				for ; i < len(lines) && buf.Len() < src.size; i++ {
					buf.Write(lines[i])
				}
				l := &log{path: filepath.Join(dir, src.name), lines: lines, next: i}
				os.WriteFile(l.path, buf.Bytes(), 0o600)
				logs = append(logs, l)
			}
			now := fixtureNow
			tick := func() {
				for _, l := range logs { // one small turn: about 10 KB
					var add bytes.Buffer
					for add.Len() < 10<<10 {
						add.Write(l.lines[l.next%len(l.lines)])
						l.next++
					}
					f, _ := os.OpenFile(l.path, os.O_WRONLY|os.O_APPEND, 0)
					f.Write(add.Bytes())
					f.Close()
				}
				now = now.Add(30 * time.Second)
				if err := observeAccounting(cache, "claude-code", []string{logs[0].path}, now); err != nil {
					b.Fatal(err)
				}
				if err := observeAccounting(cache, "codex", []string{logs[1].path}, now); err != nil {
					b.Fatal(err)
				}
			}
			tick() // the first read after launch is a full read either way
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				tick()
				tick()
			}
		})
	}
}

// usageLines: n Claude Code usage rows of about 600 bytes each, model m for row i when pick(i).
func usageLines(n int, model func(i int) string) []byte {
	var b bytes.Buffer
	for i := 0; i < n; i++ {
		fmt.Fprintf(&b, `{"type":"assistant","timestamp":"2026-11-20T10:%02d:%02dZ","sessionId":"s","requestId":"req_%d","message":{"id":"msg_%d","model":%q,"content":[{"type":"text","text":"%s"}],"usage":{"input_tokens":%d,"output_tokens":%d}}}`+"\n", i/60%60, i%60, i, i, model(i), strings.Repeat("x", 400), 10+i, 20+i)
	}
	return b.Bytes()
}

// observeBoth runs one observation with the live cursor and one full read, each into its own
// cache, and fails when their ledgers differ.
func observeBoth(t *testing.T, inc, full, path string, now time.Time, step string) {
	t.Helper()
	if err := observeAccounting(inc, "claude-code", []string{path}, now); err != nil {
		t.Fatal(err)
	}
	liveIncremental = false
	err := observeAccounting(full, "claude-code", []string{path}, now)
	liveIncremental = true
	if err != nil {
		t.Fatal(err)
	}
	a, _ := loadAccounting(inc)
	b, _ := loadAccounting(full)
	if len(b.Files) == 0 || !reflect.DeepEqual(a, b) {
		t.Fatalf("%s: incremental ledger differs from a full read", step)
	}
}

// macrevc-1255-1 (a): truncated and regrown on the same inode past the cursor, with the first and
// last KB before the cursor kept and a usage row in the middle changed.
func TestLiveCursorTruncateRegrowKeepingEdges(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	inc, full, dir := t.TempDir(), t.TempDir(), t.TempDir()
	for _, c := range []string{inc, full} {
		seedPerf(t, c, fixtureNow.AddDate(0, 0, -40))
	}
	path := filepath.Join(dir, "s.jsonl")
	old := usageLines(40, func(int) string { return "old" })
	os.WriteFile(path, old, 0o600)
	now := fixtureNow
	os.Chtimes(path, now, now)
	observeBoth(t, inc, full, path, now, "first read")
	// Same length, same first and last KB, row 20 now says "new"; then more rows appended.
	regrown := usageLines(40, func(i int) string {
		if i == 20 {
			return "new"
		}
		return "old"
	})
	if len(regrown) != len(old) || !bytes.Equal(regrown[:1024], old[:1024]) || !bytes.Equal(regrown[len(old)-1024:], old[len(old)-1024:]) {
		t.Fatal("fixture does not keep the edges")
	}
	regrown = append(regrown, usageLines(45, func(int) string { return "old" })[len(old):]...)
	f, _ := os.OpenFile(path, os.O_WRONLY|os.O_TRUNC, 0) // same inode
	f.Write(regrown)
	f.Close()
	now = now.Add(time.Minute)
	os.Chtimes(path, now, now)
	observeBoth(t, inc, full, path, now, "truncated and regrown")
}

// macrevc-1255-1 (b): the file is rewritten in the middle after the cursor was checked and before
// the appended bytes are parsed. The next observation must settle on a full read.
func TestLiveCursorRewriteDuringRead(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	inc, full, dir := t.TempDir(), t.TempDir(), t.TempDir()
	for _, c := range []string{inc, full} {
		seedPerf(t, c, fixtureNow.AddDate(0, 0, -40))
	}
	path := filepath.Join(dir, "s.jsonl")
	os.WriteFile(path, usageLines(40, func(int) string { return "old" }), 0o600)
	now := fixtureNow
	os.Chtimes(path, now, now)
	observeBoth(t, inc, full, path, now, "first read")
	os.WriteFile(path, usageLines(45, func(int) string { return "old" }), 0o600) // appended
	now = now.Add(time.Minute)
	os.Chtimes(path, now, now)
	rewritten := usageLines(45, func(i int) string {
		if i == 20 {
			return "new"
		}
		return "old"
	})
	liveAfterCheck = func(p string) {
		liveAfterCheck = nil
		f, _ := os.OpenFile(p, os.O_WRONLY, 0)
		f.WriteAt(rewritten, 0)
		f.Close()
		later := now.Add(30 * time.Second)
		os.Chtimes(p, later, later)
	}
	defer func() { liveAfterCheck = nil }()
	if err := observeAccounting(inc, "claude-code", []string{path}, now); err != nil {
		t.Fatal(err)
	}
	// The racing pass read whatever it read; the next one must match a full read of the file.
	now = now.Add(time.Minute)
	observeBoth(t, inc, full, path, now, "after the rewrite")
}
