// SPDX-License-Identifier: MIT
package quota

import (
	"encoding/json"
	"os"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/idlework"
)

// The app-server's 30-second observation binds what it records to the accounts in ModelPlan's
// own account caches (observed/codex-account.json and observed/claude-code.json). Reading and
// decoding both files on every idle pass is content work on unchanged input (D397,
// macrevb-1222-3), so their binding fields are kept by file metadata: an unchanged file is
// statted, never opened again. Only the subscription reference and the fields that decide
// whether it holds are kept, in memory. A missing, replaced, resized or retouched file is read
// again; a file stamped within racyWindow of its read is read again too, because a write in the
// same timestamp tick would leave its metadata as it was.
type cacheMemoEntry struct {
	info  os.FileInfo
	racy  bool
	value any
}

var cacheMemo struct {
	sync.Mutex
	m map[string]cacheMemoEntry
}

const cacheMemoRacy = 2 * time.Second

// memoCacheFile returns decode's result for the regular file at path (at most limit bytes),
// reading and decoding it only when its metadata moved. ok is false when there is no usable file.
func memoCacheFile(path string, limit int64, decode func([]byte) (any, bool)) (any, bool) {
	info, err := os.Lstat(path)
	if err != nil || !info.Mode().IsRegular() || info.Size() > limit {
		cacheMemo.Lock()
		delete(cacheMemo.m, path)
		cacheMemo.Unlock()
		return nil, false
	}
	cacheMemo.Lock()
	e, hit := cacheMemo.m[path]
	cacheMemo.Unlock()
	if hit && !e.racy && os.SameFile(e.info, info) && e.info.Size() == info.Size() && e.info.ModTime().Equal(info.ModTime()) {
		return e.value, e.value != nil
	}
	b, err := idlework.ReadFile(path)
	if err != nil || int64(len(b)) > limit {
		return nil, false
	}
	idlework.Decode()
	value, ok := decode(b)
	if !ok {
		value = nil
	}
	since := time.Since(info.ModTime())
	cacheMemo.Lock()
	if cacheMemo.m == nil {
		cacheMemo.m = map[string]cacheMemoEntry{}
	}
	cacheMemo.m[path] = cacheMemoEntry{info: info, racy: since < cacheMemoRacy && since > -cacheMemoRacy, value: value}
	cacheMemo.Unlock()
	return value, ok
}

// forgetCacheMemo drops every remembered cache file (tests).
func forgetCacheMemo() {
	cacheMemo.Lock()
	cacheMemo.m = nil
	cacheMemo.Unlock()
}

type codexBinding struct {
	status   string
	observed time.Time
	ref      string
}

func codexAccountBinding(cache string) (codexBinding, bool) {
	if cache == "" {
		return codexBinding{}, false
	}
	v, ok := memoCacheFile(accountPath(cache), 256<<10, func(b []byte) (any, bool) {
		var s accountSnap
		if json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 {
			return nil, false
		}
		return codexBinding{status: s.Status, observed: s.ObservedAt, ref: s.SubscriptionRef}, true
	})
	if !ok {
		return codexBinding{}, false
	}
	return v.(codexBinding), true
}

func claudeSnapshotRef(cache string) string {
	v, ok := memoCacheFile(snapshotPath(cache), 64<<10, func(b []byte) (any, bool) {
		var s ccSnapshot
		if json.Unmarshal(b, &s) != nil || s.Identity == nil {
			return nil, false
		}
		return s.Identity.Ref, true
	})
	if !ok {
		return ""
	}
	return v.(string)
}
