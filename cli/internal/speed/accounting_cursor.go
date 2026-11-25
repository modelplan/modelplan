// SPDX-License-Identifier: MIT
package speed

import (
	"crypto/sha256"
	"errors"
	"io"
	"os"
	"sync"
	"sync/atomic"
	"time"
)

// The live accounting reader used to parse a changed transcript from its first byte on every
// observation, so an active 30 MB session cost a full parse per refresh. A live cursor keeps, in
// memory only, the parser as it stood after the last complete line it read, with the file's
// identity, and the next observation parses only the appended bytes. The parser only accumulates
// (its records depend on the lines before, never on what follows), so resuming yields exactly what
// a full re-read yields.
//
// The cursor is dropped, and the file read from its start, when:
//   - the file is another file now (inode/device), shorter than the cursor (truncation), or its
//     modification time went backwards;
//   - its first or last KB before the cursor no longer hashes the same (rewritten in place);
//   - the grant it was read under is not the grant in force, or the source's history is erased;
//   - a read fails part way.
//
// A same-size rewrite between the two hashed KBs is not seen, as the cursored history reader in
// localusage does not see it either; transcripts are append-only.
//
// Nothing of it is written to disk; a new engine process starts with full reads.
type liveCursor struct {
	info       os.FileInfo
	modified   time.Time
	offset     int64 // end of the last complete line parsed
	head, tail [sha256.Size]byte
	epoch      *GrantEpoch
	p          *accountingParser
	used       time.Time
}

// liveCursorMax bounds the files remembered; the least recently used goes first.
const liveCursorMax = 64

var liveCursors = struct {
	sync.Mutex
	m map[string]*liveCursor
}{m: map[string]*liveCursor{}}

// liveReads counts full and resumed reads (tests and the CPU benchmark read it).
var liveReads struct{ full, resumed atomic.Int64 }

// liveIncremental: tests turn it off to compare with full re-reads.
var liveIncremental = true

func liveCursorKey(cache, source, path string) string { return cache + "\x00" + source + "\x00" + path }

// forgetLiveCursors drops every remembered parser of a tool's sources (all when tool is "").
func forgetLiveCursors(tool string) {
	liveCursors.Lock()
	defer liveCursors.Unlock()
	for k, c := range liveCursors.m {
		if tool == "" || sourceTool(c.p.source) == tool {
			delete(liveCursors.m, k)
		}
	}
}

// hashRange hashes [from, to) of f; false when it cannot be read whole.
func hashRange(f *os.File, from, to int64) ([sha256.Size]byte, bool) {
	b := make([]byte, to-from)
	if _, err := f.ReadAt(b, from); err != nil && !(errors.Is(err, io.EOF) && len(b) == 0) {
		return [sha256.Size]byte{}, false
	}
	return sha256.Sum256(b), true
}

func cursorHashes(f *os.File, offset int64) (head, tail [sha256.Size]byte, ok bool) {
	head, ok1 := hashRange(f, 0, min(offset, 1024))
	tail, ok2 := hashRange(f, max(0, offset-1024), offset)
	return head, tail, ok1 && ok2
}

// readAccounting returns the accounting parser for path after every complete line of it, reading
// only what follows the remembered cursor when the file is still the one it was read from.
func readAccounting(admitted func() error, cache, source, path string, epoch *GrantEpoch, now time.Time) (*accountingParser, error) {
	fh, err := importOpen(path)
	if err != nil {
		return nil, err
	}
	defer fh.Close()
	fi, err := fh.Stat()
	if err != nil || !fi.Mode().IsRegular() {
		return nil, errors.New("not a regular file")
	}
	key := liveCursorKey(cache, source, path)
	liveCursors.Lock()
	c := liveCursors.m[key]
	delete(liveCursors.m, key) // taken: a failed read leaves no cursor behind
	liveCursors.Unlock()
	var p *accountingParser
	start := int64(0)
	if c != nil && liveIncremental && os.SameFile(c.info, fi) && fi.Size() >= c.offset && !fi.ModTime().Before(c.modified) && sameEpoch(c.epoch, epoch) {
		if head, tail, ok := cursorHashes(fh, c.offset); ok && head == c.head && tail == c.tail {
			p, start = c.p, c.offset
		}
	}
	if p == nil {
		p = newAccountingParser(source, fileKey(path))
		liveReads.full.Add(1)
	} else {
		liveReads.resumed.Add(1)
	}
	end, err := readLinesFrom(admitted, fh, start, p)
	if err != nil {
		return nil, err
	}
	if !liveIncremental {
		return p, nil
	}
	head, tail, ok := cursorHashes(fh, end)
	if !ok {
		return p, nil
	}
	liveCursors.Lock()
	defer liveCursors.Unlock()
	if len(liveCursors.m) >= liveCursorMax {
		var oldest string
		for k, o := range liveCursors.m {
			if oldest == "" || o.used.Before(liveCursors.m[oldest].used) {
				oldest = k
			}
		}
		delete(liveCursors.m, oldest)
	}
	liveCursors.m[key] = &liveCursor{info: fi, modified: fi.ModTime(), offset: end, head: head, tail: tail, epoch: epoch, p: p, used: now}
	return p, nil
}

// readLinesFrom feeds p the complete lines of fh from start (a line boundary) and returns the end
// of the last complete line. An unfinished last line is left for the next read, as readWhole
// leaves it; a line longer than maxLine is skipped.
func readLinesFrom(admitted func() error, fh *os.File, start int64, p parser) (int64, error) {
	if _, err := fh.Seek(start, io.SeekStart); err != nil {
		return 0, err
	}
	buf := wholeBufs.Get().(*wholeBuf)
	defer buf.put()
	buf.r.Reset(fh)
	r := buf.r
	off := start
	line := buf.line
	defer func() { buf.line = line }()
	for n := 0; ; n++ {
		if n%importCancelEvery == 0 {
			if err := admitted(); err != nil {
				return 0, err
			}
		}
		b, size, err := readLineInto(r, line)
		if b != nil {
			line = b
		}
		if err != nil {
			if errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) {
				return off, nil
			}
			return 0, err
		}
		if b != nil {
			p.line(off, off+size, b)
		}
		off += size
	}
}
