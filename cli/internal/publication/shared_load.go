// SPDX-License-Identifier: MIT
package publication

import (
	"os"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// WP-17 (Fable perf plan 5.1 row 1): LoadShared is Load for the long-running engine, which read,
// hashed, verified and parsed the same cached publication up to nine times per view. The result
// is kept while the three files it came from (state, manifest, client object) keep their
// identity, size and modification time, and is read again after any change, removal or
// replacement. A file written less than sharedSettle before the load is never trusted to be
// unchanged (file times can be coarse). Nothing here touches the network.
//
// The returned digest is shared between callers: they must not modify it. Callers that may
// modify it, or that run once per process, use Load.
func LoadShared(s *store.Store) (*digest.Digest, store.State, error) {
	statePath := s.StatePath()
	stateStamp := stampFile(statePath)
	sharedMu.Lock()
	entry, ok := shared[s.Dir]
	sharedMu.Unlock()
	if ok && entry.state.same(stateStamp) && entry.manifest.same(stampFile(entry.manifestPath)) && entry.object.same(stampFile(entry.objectPath)) &&
		entry.settled() {
		return entry.d, entry.st, entry.err
	}
	readAt := time.Now()
	d, st, err := Load(s)
	next := sharedEntry{d: d, st: st, err: err, readAt: readAt, state: stateStamp}
	if st.PublicationID != "" {
		next.manifestPath = s.ManifestPath(st.PublicationID)
	}
	if st.ComponentHash != "" {
		next.objectPath = s.ObjectPath(st.ComponentHash)
	}
	next.manifest, next.object = stampFile(next.manifestPath), stampFile(next.objectPath)
	sharedMu.Lock()
	shared[s.Dir] = next
	sharedMu.Unlock()
	return d, st, err
}

const sharedSettle = time.Second

var (
	sharedMu sync.Mutex
	shared   = map[string]sharedEntry{}
)

type sharedEntry struct {
	d                        *digest.Digest
	st                       store.State
	err                      error
	readAt                   time.Time
	manifestPath, objectPath string
	state, manifest, object  fileStamp
}

func (e sharedEntry) settled() bool {
	for _, f := range []fileStamp{e.state, e.manifest, e.object} {
		if f.info != nil && e.readAt.Sub(f.info.ModTime()) < sharedSettle {
			return false
		}
	}
	return true
}

// fileStamp: a nil info is a path that is unset or does not exist.
type fileStamp struct{ info os.FileInfo }

func stampFile(path string) fileStamp {
	if path == "" {
		return fileStamp{}
	}
	info, err := os.Stat(path)
	if err != nil {
		return fileStamp{}
	}
	return fileStamp{info}
}

func (a fileStamp) same(b fileStamp) bool {
	if a.info == nil || b.info == nil {
		return a.info == nil && b.info == nil
	}
	return a.info.Size() == b.info.Size() && a.info.ModTime().Equal(b.info.ModTime()) && os.SameFile(a.info, b.info)
}
