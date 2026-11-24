// SPDX-License-Identifier: MIT
package speed

import (
	"os"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// PerfReadMemo reuses the engine's decoded ledger and response rollup while
// the ledgers and clear watermark have the same file identity, size and
// modification time. Writers replace them atomically. Each result is filtered
// under current admission.
type PerfReadMemo struct {
	mu     sync.Mutex
	cache  string
	fence  consent.Fence
	mode   string
	files  [3]os.FileInfo
	ledger PerfLedger
	valid  bool
}

func (m *PerfReadMemo) Read(cache string, admission consent.Admission, now time.Time) PerfView {
	m.mu.Lock()
	defer m.mu.Unlock()
	if cache == "" || Off() || admission.Mode() == consent.Off {
		m.valid = false
		m.ledger = PerfLedger{}
		return PerfView{}
	}
	paths := [3]string{PerfPath(cache), accountingPath(cache), ClearedPath(cache)}
	files, cacheable := perfFileInfo(paths)
	ledger, ok := m.ledger, m.valid
	if !ok || !cacheable || m.cache != cache || m.fence != admission.Fence() ||
		m.mode != admission.Mode() || !samePerfFiles(m.files, files) {
		m.valid = false
		m.ledger = PerfLedger{}
		ledger, ok = LoadPerf(cache)
		// The engine's Today projection only needs these aggregates and rows.
		// Keep no ledger cursors, project maps or file enumeration state.
		ledger = PerfLedger{SchemaVersion: ledger.SchemaVersion, Since: ledger.Since,
			Rows: ledger.Rows, UsageRows: ledger.UsageRows, Live: ledger.Live, Sessions: ledger.Sessions}
		if after, complete := perfFileInfo(paths); ok && cacheable && complete && samePerfFiles(files, after) {
			m.cache, m.fence, m.mode = cache, admission.Fence(), admission.Mode()
			m.files, m.ledger, m.valid = files, ledger, true
		}
	}
	return (PerfView{Ledger: ledger, OK: ok, Recording: true, Now: now}).Admitted(admission)
}

func perfFileInfo(paths [3]string) (files [3]os.FileInfo, cacheable bool) {
	for i, path := range paths {
		info, err := os.Stat(path)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil || !info.Mode().IsRegular() {
			return files, false
		}
		files[i] = info
	}
	return files, true
}

func samePerfFiles(a, b [3]os.FileInfo) bool {
	for i, prior := range a {
		current := b[i]
		if prior == nil && current == nil {
			continue
		}
		if prior == nil || current == nil || !os.SameFile(prior, current) ||
			prior.Size() != current.Size() || !prior.ModTime().Equal(current.ModTime()) || prior.Mode() != current.Mode() {
			return false
		}
	}
	return true
}
