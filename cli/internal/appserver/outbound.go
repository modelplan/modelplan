// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

type message struct {
	bytes   []byte
	stamp   Stamp
	private bool
	after   func()
	stale   func(error)
}

type outbound struct {
	mu           sync.Mutex
	control      []message
	data         []message
	latest       *message
	controlBytes int
	reserved     int
	wake         chan struct{}
	ctx          context.Context
	stop         context.CancelFunc
	writer       io.WriteCloser
	timeout      time.Duration
	current      func(Stamp) error
	commit       func(Stamp, func() error) error
	// One pump goroutine per session performs the blocking writes, so the run loop can stop
	// waiting for a write (and release the consent lock) without closing the pipe.
	chunks chan []byte
	wrote  chan bool
}

// commit, when set, runs its write under the authoritative consent fence. A private frame
// is written whole (body and newline) inside it when the consumer keeps up: the fence is
// checked and every byte is written while the publication lock is held, so a consent change
// that lands after admission makes the frame stale before its first byte; it is dropped
// through m.stale and the session continues (sampling 11-25, #1217 P2).
//
// commitTimeout bounds how long a private frame's write may hold the consent lock. A consent
// change must never wait behind a stalled consumer (#1262 macrevb-1262-1): if the body has not
// been taken within this bound, the lock is released and the body finishes outside it under
// the normal write timeout. Its newline is then written only through a second commit, so a
// revoke committed meanwhile can never let that frame complete (review 11-24 #1): the session
// ends and the client drops the partial line. That fallback is reached only by a consumer that
// stalls past this bound mid-frame.
const commitTimeout = 500 * time.Millisecond

func newOutbound(ctx context.Context, stop context.CancelFunc, w io.WriteCloser, timeout time.Duration, current func(Stamp) error) *outbound {
	return &outbound{ctx: ctx, stop: stop, writer: w, timeout: timeout, wake: make(chan struct{}, 1), current: current}
}
func (o *outbound) signal() {
	select {
	case o.wake <- struct{}{}:
	default:
	}
}
func (o *outbound) reserve() bool {
	o.mu.Lock()
	defer o.mu.Unlock()
	// One of the 64 data slots is reserved for the coalesced rows snapshot.
	if len(o.data)+o.reserved >= wire.MaxDataMessages-1 {
		return false
	}
	o.reserved++
	return true
}
func (o *outbound) release() { o.mu.Lock(); o.reserved--; o.mu.Unlock() }
func encode(value any, stamp Stamp, private bool) (message, error) {
	b, err := json.Marshal(value)
	if err != nil || len(b)+1 > wire.MaxFrameBytes {
		return message{}, errFrame
	}
	return message{bytes: append(b, '\n'), stamp: stamp, private: private}, nil
}
func (o *outbound) controlMessage(value any) bool { return o.controlThen(value, nil) }
func (o *outbound) controlThen(value any, after func()) bool {
	m, err := encode(value, Stamp{}, false)
	if err != nil {
		o.stop()
		return false
	}
	o.mu.Lock()
	if len(o.control) >= wire.MaxControlMessages || o.controlBytes+len(m.bytes) > wire.MaxControlBytes {
		o.mu.Unlock()
		o.stop()
		return false
	}
	m.after = after
	o.control = append(o.control, m)
	o.controlBytes += len(m.bytes)
	o.mu.Unlock()
	o.signal()
	return true
}
func (o *outbound) dataMessage(value any, stamp Stamp, private bool, stale func(error)) bool {
	m, err := encode(value, stamp, private)
	m.stale = stale
	o.mu.Lock()
	o.reserved--
	if err == nil {
		o.data = append(o.data, m)
	}
	o.mu.Unlock()
	if err != nil {
		o.stop()
		return false
	}
	o.signal()
	return true
}
func (o *outbound) rowsMessage(value any, stamp Stamp, stale func(error)) {
	m, err := encode(value, stamp, true)
	if err != nil {
		o.stop()
		return
	}
	m.stale = stale
	o.mu.Lock()
	o.latest = &m
	o.mu.Unlock()
	o.signal()
}
func (o *outbound) next() (message, bool) {
	o.mu.Lock()
	defer o.mu.Unlock()
	if len(o.control) > 0 {
		m := o.control[0]
		o.control[0] = message{}
		o.control = o.control[1:]
		o.controlBytes -= len(m.bytes)
		return m, true
	}
	if len(o.data) > 0 {
		m := o.data[0]
		o.data[0] = message{}
		o.data = o.data[1:]
		return m, true
	}
	if o.latest != nil {
		m := *o.latest
		o.latest = nil
		return m, true
	}
	return message{}, false
}
func (o *outbound) run(done chan<- struct{}) {
	defer close(done)
	o.chunks, o.wrote = make(chan []byte), make(chan bool, 1)
	go o.pump()
	defer close(o.chunks)
	for {
		if o.ctx.Err() != nil {
			return
		}
		m, ok := o.next()
		if !ok {
			select {
			case <-o.ctx.Done():
				return
			case <-o.wake:
				continue
			}
		}
		if m.private {
			if err := o.current(m.stamp); err != nil {
				if m.stale != nil {
					m.stale(err)
				}
				continue
			}
		}
		if m.private && o.commit != nil && len(m.bytes) > 0 {
			if !o.writeFenced(m) {
				return
			}
		} else if !o.bounded(time.Now().Add(o.timeout), m.bytes) {
			return
		}
		if m.after != nil {
			m.after()
		}
	}
}

// errUnfinished: the body was not taken within commitTimeout; the lock is released.
var errUnfinished = errors.New("private frame body still being written")

// writeFenced writes one private frame. It reports false when the session has ended.
func (o *outbound) writeFenced(m message) bool {
	body, newline := m.bytes[:len(m.bytes)-1], m.bytes[len(m.bytes)-1:]
	deadline := time.Now().Add(o.timeout)
	started := false
	err := o.commit(m.stamp, func() error {
		started = true
		lockBound := time.Now().Add(commitTimeout)
		if lockBound.After(deadline) {
			lockBound = deadline
		}
		o.chunks <- body
		finished, ok := o.await(lockBound)
		if !finished {
			return errUnfinished
		}
		if !ok {
			return errFrame
		}
		o.chunks <- newline
		if finished, ok := o.await(lockBound); !finished || !ok {
			o.cut()
			return errFrame
		}
		return nil
	})
	switch {
	case err == nil:
		return true
	case !started:
		// The fence moved (or was busy) before any byte was written: nothing of the frame
		// reached the consumer, so drop it as stale and keep the session.
		if m.stale != nil {
			m.stale(err)
		}
		return true
	case !errors.Is(err, errUnfinished):
		o.end()
		return false
	}
	// A stalled consumer: finish the body outside the lock under the write timeout, then
	// terminate the frame only if its fence still holds.
	if finished, ok := o.await(deadline); !finished || !ok {
		o.end()
		return false
	}
	err = o.commit(m.stamp, func() error {
		o.chunks <- newline
		if finished, ok := o.await(time.Now().Add(commitTimeout)); !finished || !ok {
			o.cut()
			return errFrame
		}
		return nil
	})
	if err != nil {
		// The frame lost the fence after its first byte: end the session so the incomplete
		// line is discarded rather than completed after a revoke.
		o.end()
		return false
	}
	return true
}

// bounded writes b, ending the session if the consumer stalls past deadline.
func (o *outbound) bounded(deadline time.Time, b []byte) bool {
	o.chunks <- b
	if finished, ok := o.await(deadline); !finished || !ok {
		o.end()
		return false
	}
	return true
}

// await waits for the pump's pending write until deadline. finished is false when the write
// is still pending (deadline passed or the session ended).
func (o *outbound) await(deadline time.Time) (finished, ok bool) {
	timer := time.NewTimer(time.Until(deadline))
	defer timer.Stop()
	select {
	case ok := <-o.wrote:
		return true, ok
	case <-timer.C:
		return false, false
	case <-o.ctx.Done():
		return false, false
	}
}

// end stops the session and closes our pipe, which interrupts a blocked write. It is never
// called while the consent lock is held (inside o.commit): stopping the session there could
// end the process before a consent change waiting for that lock commits (#1262 macrevb-1262-1).
func (o *outbound) end() { o.stop(); _ = o.writer.Close() }

// cut closes our pipe without stopping the session. Inside o.commit it interrupts a stalled
// newline so the frame can never complete outside its fence; the caller ends the session once
// the lock is released.
func (o *outbound) cut() { _ = o.writer.Close() }

func (o *outbound) pump() {
	for b := range o.chunks {
		o.wrote <- o.write(b)
	}
}

func (o *outbound) write(b []byte) bool {
	for len(b) > 0 {
		n, err := o.writer.Write(b)
		if err != nil || n == 0 {
			return false
		}
		b = b[n:]
	}
	return true
}
