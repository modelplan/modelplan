// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"sync"
	"sync/atomic"
	"time"
)

// WP-17 (Fable perf plan 5.1 row 1): every engine view read the tail of the 8 most recent
// Codex rollouts again (up to 4 MB each), five times at start and three times per cockpit
// query. A rollout whose identity (device and inode), size and modification time are the
// same as at its last read holds the same bytes, so its decoded events are kept and reused.
// Any change, a replacement (new inode), a removal, or Codex local history no longer being
// admitted drops the entry; the next read decodes the file again. File times can be coarse,
// so a file written less than rolloutSettle before it was read is never reused (the rule git
// uses for racily clean files): a same-size rewrite within one clock tick is read again too.

type rolloutMemoEntry struct {
	info   os.FileInfo // identity, size and time taken before the read
	readAt time.Time
	scan   rolloutScan
}

const rolloutSettle = time.Second

var (
	rolloutMemoMu sync.Mutex
	rolloutMemo   = map[string]rolloutMemoEntry{}
	// rolloutMemoGen counts Forgets (guarded by rolloutMemoMu). A read takes it as its fence
	// before its consent is evaluated and may memoize only while it is unchanged, so a scan that
	// was admitted before a Forget can never refill the memo after it (sampling 11-20 S1).
	rolloutMemoGen uint64
	// rolloutReads counts rollout files opened for decoding (tests and timing only).
	rolloutReads atomic.Int64
	// afterRolloutDecode runs between decoding a rollout and memoizing it (tests only).
	afterRolloutDecode = func(string) {}
)

func sameRolloutFile(a, b os.FileInfo) bool {
	return a.Size() == b.Size() && a.ModTime().Equal(b.ModTime()) && os.SameFile(a, b)
}

// codexRolloutFence is taken by a read before its consent is evaluated; see rolloutMemoGen.
func codexRolloutFence() uint64 {
	rolloutMemoMu.Lock()
	defer rolloutMemoMu.Unlock()
	return rolloutMemoGen
}

// codexRolloutEvents returns the decoded events of path, read again only when the file
// changed. The stat is taken before the read: a write during the read leaves a newer
// file than the recorded one, which the next call reads again. A read whose fence is older
// than the last Forget returns what it decoded but keeps nothing.
func codexRolloutEvents(path string, fence uint64) (rolloutScan, bool) {
	info, err := os.Stat(path)
	if err != nil || !info.Mode().IsRegular() {
		rolloutMemoMu.Lock()
		delete(rolloutMemo, path)
		rolloutMemoMu.Unlock()
		return rolloutScan{}, false
	}
	rolloutMemoMu.Lock()
	entry, ok := rolloutMemo[path]
	rolloutMemoMu.Unlock()
	if ok && sameRolloutFile(entry.info, info) && entry.readAt.Sub(info.ModTime()) >= rolloutSettle {
		return entry.scan, true
	}
	readAt := time.Now()
	scan, ok := readRolloutEvents(path)
	afterRolloutDecode(path)
	rolloutMemoMu.Lock()
	if ok && fence == rolloutMemoGen {
		rolloutMemo[path] = rolloutMemoEntry{info: info, readAt: readAt, scan: scan}
	} else {
		delete(rolloutMemo, path)
	}
	rolloutMemoMu.Unlock()
	return scan, ok
}

// keepCodexRollouts drops the entries of files the reader no longer looks at.
func keepCodexRollouts(files []string) {
	keep := make(map[string]bool, len(files))
	for _, f := range files {
		keep[f] = true
	}
	rolloutMemoMu.Lock()
	for path := range rolloutMemo {
		if !keep[path] {
			delete(rolloutMemo, path)
		}
	}
	rolloutMemoMu.Unlock()
}

// forgetCodexRollouts drops everything decoded from Codex rollouts.
func forgetCodexRollouts() {
	rolloutMemoMu.Lock()
	rolloutMemoGen++
	clear(rolloutMemo)
	rolloutMemoMu.Unlock()
}

func codexRolloutMemoSize() int {
	rolloutMemoMu.Lock()
	defer rolloutMemoMu.Unlock()
	return len(rolloutMemo)
}
