// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
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
}

// commit, when set, runs its write under the authoritative consent fence. A private
// frame's terminating newline is written only through it, so a revoke committed by
// another process while the frame body is being written can never let that frame
// complete (review 11-24 #1): the session closes and the client drops the partial line.
//
// commitTimeout bounds the one-byte newline written under the consent lock, so a stalled
// consumer can hold off a revoke for at most this long before the session is closed.
const commitTimeout = 200 * time.Millisecond

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
		fenced := m.private && o.commit != nil && len(m.bytes) > 0
		body := m.bytes
		if fenced {
			body = body[:len(body)-1]
		}
		// Closing our pipe interrupts a blocked write; no goroutine per write leaks.
		timer := time.AfterFunc(o.timeout, func() { o.stop(); _ = o.writer.Close() })
		wrote := o.write(body)
		timer.Stop()
		if !wrote {
			o.stop()
			return
		}
		if fenced {
			err := o.commit(m.stamp, func() error {
				bound := time.AfterFunc(commitTimeout, func() { o.stop(); _ = o.writer.Close() })
				defer bound.Stop()
				if !o.write([]byte{'\n'}) {
					return errFrame
				}
				return nil
			})
			if err != nil {
				// The frame lost the fence after its first byte: end the session so the
				// incomplete line is discarded rather than completed after a revoke.
				o.stop()
				_ = o.writer.Close()
				return
			}
		}
		if m.after != nil {
			m.after()
		}
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
