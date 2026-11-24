// SPDX-License-Identifier: MIT

// Package idlework counts the engine's local work on the paths that run while
// the app is idle: history discovery, content reads and decodes, and view
// builds. The counts are process-wide aggregates with no paths, names or
// contents, so they carry nothing private. The idle-energy gates (D397) read
// them to prove that unchanged inputs cost nothing, or a bounded amount that
// does not grow with the size of the user's history.
package idlework

import (
	"io"
	"os"
	"sync/atomic"
)

var walks, entries, opens, bytes, decodes, views atomic.Int64

// Counts is a snapshot of the counters.
type Counts struct {
	Walks   int64 // broad discovery walks started (one per history root walked)
	Entries int64 // directory entries enumerated by discovery
	Opens   int64 // history or ledger files opened for content
	Bytes   int64 // content bytes read from them
	Decodes int64 // ledger, log-tail or rollout decodes
	Views   int64 // engine view builds
}

// Walk records the start of a broad discovery walk over one history root.
func Walk() { walks.Add(1) }

// Entries records n enumerated directory entries.
func Entries(n int) { entries.Add(int64(n)) }

// Open records one content open.
func Open() { opens.Add(1) }

// Read records n content bytes read.
func Read(n int) { bytes.Add(int64(n)) }

// Decode records one decode of ledger or log content.
func Decode() { decodes.Add(1) }

// View records one engine view build.
func View() { views.Add(1) }

// Reader counts the bytes read through r.
func Reader(r io.Reader) io.Reader { return countingReader{r} }

type countingReader struct{ r io.Reader }

func (c countingReader) Read(p []byte) (int, error) {
	n, err := c.r.Read(p)
	bytes.Add(int64(n))
	return n, err
}

// ReadFile is os.ReadFile counted as one content open and the bytes it read.
func ReadFile(path string) ([]byte, error) {
	b, err := os.ReadFile(path)
	if err == nil {
		Open()
		Read(len(b))
	}
	return b, err
}

// Snapshot returns the current counts.
func Snapshot() Counts {
	return Counts{walks.Load(), entries.Load(), opens.Load(), bytes.Load(), decodes.Load(), views.Load()}
}

// Plus returns the sum of two counts.
func (c Counts) Plus(o Counts) Counts {
	return Counts{c.Walks + o.Walks, c.Entries + o.Entries, c.Opens + o.Opens,
		c.Bytes + o.Bytes, c.Decodes + o.Decodes, c.Views + o.Views}
}

// Since returns the work done since base.
func (c Counts) Since(base Counts) Counts {
	return Counts{c.Walks - base.Walks, c.Entries - base.Entries, c.Opens - base.Opens,
		c.Bytes - base.Bytes, c.Decodes - base.Decodes, c.Views - base.Views}
}
