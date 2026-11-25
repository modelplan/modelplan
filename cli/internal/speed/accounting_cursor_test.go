// SPDX-License-Identifier: MIT
package speed

import (
	"bytes"
	"os"
	"path/filepath"
	"reflect"
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
