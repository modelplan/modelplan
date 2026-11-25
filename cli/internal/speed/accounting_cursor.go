// SPDX-License-Identifier: MIT
package speed

import (
	"bufio"
	"crypto/sha256"
	"errors"
	"hash"
	"io"
	"os"
	"sync"
	"sync/atomic"
	"time"
)

// The live accounting reader used to parse a changed transcript from its first byte on every
// observation, so an active 30 MB session cost a full parse per refresh. A live cursor keeps, in
// memory only, the parser as it stood after the last complete line it consumed, the offset of that
// line's end, and the SHA-256 of every byte before it (hashed as the bytes were parsed).
//
// Invariant: a resumed read yields exactly what a full read of the same bytes yields.
//   - The parser only accumulates: its state after bytes P then S equals its state after reading P
//     and continuing with S.
//   - A cursor is resumed only after the file's first offset bytes, read in the same sequential pass
//     that then parses the rest, hash to the stored digest: the prefix is the one the stored
//     parser consumed. Equality of SHA-256 over the whole prefix is the proof; no sampled bytes, size,
//     inode or mtime ever stand in for it (those only rule a cursor out early).
//   - Because verification and parsing are one pass over one descriptor, the bytes parsed after the
//     cursor are the bytes that followed the verified prefix in that pass, as a full read in the
//     same pass would have seen them; a write racing the pass changes what the next pass verifies.
//   - A cursor is kept only when the pass consumed whole lines that were all hashed, and the file's
//     size and mtime were the same before and after the pass (no write raced it).
//
// Nothing of it is written to disk; a new engine process starts with full reads.
type liveCursor struct {
	info     os.FileInfo
	modified time.Time
	offset   int64 // end of the last complete line parsed
	digest   [sha256.Size]byte
	epoch    *GrantEpoch
	p        *accountingParser
	used     time.Time
}

// liveCursorMax bounds the files remembered; the least recently used goes first.
const liveCursorMax = 64

var liveCursors = struct {
	sync.Mutex
	m map[string]*liveCursor
}{m: map[string]*liveCursor{}}

// liveReads counts full and resumed reads (tests and the CPU benchmark read it).
var liveReads struct{ full, resumed atomic.Int64 }

// liveAfterCheck: a test hook run after the cursor is checked and before parsing starts.
var liveAfterCheck func(path string)

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

// readAccounting returns the accounting parser for path after every complete line of it, resuming the
// remembered parser when the file still starts with the exact bytes it consumed.
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
	delete(liveCursors.m, key) // taken: a failed or racing read leaves no cursor behind
	liveCursors.Unlock()
	h := sha256.New()
	var p *accountingParser
	start := int64(0)
	if c != nil && liveIncremental && sameEpoch(c.epoch, epoch) && os.SameFile(c.info, fi) && fi.Size() >= c.offset && !fi.ModTime().Before(c.modified) {
		// Proof, not a sample: hash the whole prefix, from this descriptor, in this pass.
		n, err := io.CopyN(h, fh, c.offset)
		var sum [sha256.Size]byte
		h.Sum(sum[:0])
		if err == nil && n == c.offset && sum == c.digest {
			p, start = c.p, c.offset
		} else {
			h.Reset()
			if _, err := fh.Seek(0, io.SeekStart); err != nil {
				return nil, err
			}
		}
	}
	if liveAfterCheck != nil {
		liveAfterCheck(path)
	}
	if p == nil {
		p = newAccountingParser(source, fileKey(path))
		liveReads.full.Add(1)
	} else {
		liveReads.resumed.Add(1)
	}
	end, hashed, err := readLinesFrom(admitted, fh, start, p, h)
	if err != nil {
		return nil, err
	}
	after, err := fh.Stat()
	if !liveIncremental || !hashed || err != nil || after.Size() != fi.Size() || !after.ModTime().Equal(fi.ModTime()) {
		return p, nil // no cursor: the next read starts from the first byte
	}
	var digest [sha256.Size]byte
	h.Sum(digest[:0])
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
	liveCursors.m[key] = &liveCursor{info: fi, modified: fi.ModTime(), offset: end, digest: digest, epoch: epoch, p: p, used: now}
	return p, nil
}

// readLinesFrom feeds p the complete lines of fh from its current position (offset start, a line
// boundary) and returns the end of the last complete line. Every consumed byte goes into h, so h
// then covers exactly [0, end) when it covered [0, start) before; hashed is false when it holds more
// (an unfinished over-long last line). As readWhole, it leaves an unfinished last line for the next
// read and skips a line longer than maxLine.
func readLinesFrom(admitted func() error, fh *os.File, start int64, p parser, h hash.Hash) (end int64, hashed bool, err error) {
	buf := wholeBufs.Get().(*wholeBuf)
	defer buf.put()
	buf.r.Reset(fh)
	r := buf.r
	off := start
	line := buf.line[:0]
	defer func() { buf.line = line }()
	for n := 0; ; n++ {
		if n%importCancelEvery == 0 {
			if err := admitted(); err != nil {
				return 0, false, err
			}
		}
		line = line[:0]
		var size int64
		long := false
		for {
			chunk, err := r.ReadSlice('\n')
			if err != nil && !errors.Is(err, bufio.ErrBufferFull) {
				if errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) {
					return off, !long, nil // the unfinished line is neither parsed nor hashed
				}
				return 0, false, err
			}
			size += int64(len(chunk))
			if !long && size <= maxLine {
				line = append(line, chunk...)
			} else {
				if !long {
					h.Write(line)
					long = true
				}
				h.Write(chunk)
			}
			if err == nil {
				break
			}
		}
		if !long {
			h.Write(line)
			p.line(off, off+size, line)
		}
		off += size
	}
}
