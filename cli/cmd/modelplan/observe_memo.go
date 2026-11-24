// SPDX-License-Identifier: MIT
package main

import (
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/logindex"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// observeIndex is what the app-server's 30-second observation pass keeps between passes: the
// shared history inventory and the memo of each observer's last clean pass. The zero value
// discovers afresh and remembers nothing (one-shot commands).
type observeIndex struct {
	inventory *logindex.Inventory
	fence     consent.Fence
	memo      *observeMemo
}

func (x observeIndex) activeLogs(claude, codex string, now time.Time) []speed.LiveLog {
	if x.inventory == nil {
		return speed.ActiveLogs(claude, codex, now)
	}
	return speed.ActiveLogsIn(x.inventory, x.fence, claude, codex, now)
}

// observeSettle: an observer is skipped only once its logs have been quiet this long, past
// the 30 s after which the parsers close an unfinished turn, so a skipped pass can never be
// the one that would have finished it.
const observeSettle = 2 * time.Minute

// observeMemoTTL bounds a skip: an unchanged pass still runs this often, so anything that
// becomes due by the clock alone (a response dated ahead of it) is recorded within the TTL.
const observeMemoTTL = 10 * time.Minute

// observeMemo skips an observer whose session logs and ModelPlan ledgers carry exactly the
// metadata its last clean pass left, under the same consent fence, day and settings: that
// pass already consumed every complete line, so running it again would decode the ledgers and
// change nothing (D397, energy plan item 2). It keeps metadata only, never content. A stamp
// only skips work; consent is checked before the memo, and a new fence never matches.
type observeMemo struct {
	mu   sync.Mutex
	last map[string]observeKey
}

type observeKey struct {
	fence   consent.Fence
	day     string
	labels  bool
	ref     string
	inputs  []fileMeta
	ledgers []fileMeta
	at      time.Time
}

type fileMeta struct {
	path string
	info os.FileInfo // nil when missing
}

// skipUnchanged calls pass unless the memo shows nothing it reads has changed since the last clean pass.
func (m *observeMemo) skipUnchanged(name, cache string, fence consent.Fence, labels bool, ref string, inputs []string, settle time.Duration, now time.Time, pass func() appserver.ObserveOutcome) appserver.ObserveOutcome {
	if m == nil {
		return pass()
	}
	key := observeKey{fence: fence, day: now.Local().Format("2006-01-02") + "/" + now.UTC().Format("2006-01-02"), labels: labels, ref: ref,
		inputs: statFiles(inputs), ledgers: statFiles(observeLedgers(cache)), at: now}
	m.mu.Lock()
	last, ok := m.last[name]
	m.mu.Unlock()
	if ok && !now.Before(last.at) && now.Sub(last.at) < observeMemoTTL && last.matches(key) {
		return appserver.ObserveRan
	}
	outcome := pass()
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.last == nil {
		m.last = map[string]observeKey{}
	}
	delete(m.last, name)
	if outcome == appserver.ObserveRan && settled(key.inputs, now, settle) {
		key.ledgers = statFiles(observeLedgers(cache)) // as this pass left them
		m.last[name] = key
	}
	return outcome
}

func (k observeKey) matches(o observeKey) bool {
	return k.fence == o.fence && k.day == o.day && k.labels == o.labels && k.ref == o.ref &&
		sameFiles(k.inputs, o.inputs) && sameFiles(k.ledgers, o.ledgers)
}

// observeLedgers are the files the observers read and write besides the session logs.
func observeLedgers(cache string) []string {
	return []string{speed.Path(cache), speed.PerfPath(cache), filepath.Join(cache, "observed", "accounting.json.gz"),
		speed.ClearedPath(cache), speed.LongPath(cache), speed.ImportPath(cache), filepath.Join(cache, "observed", "project-key")}
}

func statFiles(paths []string) []fileMeta {
	out := make([]fileMeta, len(paths))
	for i, p := range paths {
		out[i].path = p
		if info, err := os.Stat(p); err == nil {
			out[i].info = info
		}
	}
	return out
}

func sameFiles(a, b []fileMeta) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		x, y := a[i].info, b[i].info
		if a[i].path != b[i].path || (x == nil) != (y == nil) {
			return false
		}
		if x != nil && (!os.SameFile(x, y) || x.Size() != y.Size() || !x.ModTime().Equal(y.ModTime())) {
			return false
		}
	}
	return true
}

// settled: every input exists and has been quiet for settle.
func settled(inputs []fileMeta, now time.Time, settle time.Duration) bool {
	for _, f := range inputs {
		if f.info == nil || now.Sub(f.info.ModTime()) < settle {
			return false
		}
	}
	return true
}
