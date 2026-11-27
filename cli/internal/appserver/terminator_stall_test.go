// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// terminatorStall is a consumer that, once armed, takes a private frame's body and then
// stops reading, so only the terminating newline blocks (#1262 macrevb-1262-1). With
// bodyDelay the body itself is first held past commitTimeout, so the newline is written
// through the second commit after the lock was released.
type terminatorStall struct {
	mu        sync.Mutex
	written   []byte
	armed     bool
	bodyDelay time.Duration
	stalled   chan struct{}
	closed    chan struct{}
	stallOnce sync.Once
	closeOnce sync.Once
}

func (w *terminatorStall) Write(p []byte) (int, error) {
	w.mu.Lock()
	armed := w.armed
	w.mu.Unlock()
	select {
	case <-w.closed:
		return 0, io.ErrClosedPipe
	default:
	}
	if armed && string(p) == "\n" {
		w.stallOnce.Do(func() { close(w.stalled) })
		<-w.closed
		return 0, io.ErrClosedPipe
	}
	if armed && len(p) > 0 && p[len(p)-1] != '\n' && w.bodyDelay > 0 {
		select {
		case <-time.After(w.bodyDelay):
		case <-w.closed:
			return 0, io.ErrClosedPipe
		}
	}
	w.mu.Lock()
	w.written = append(w.written, p...)
	w.mu.Unlock()
	return len(p), nil
}
func (w *terminatorStall) Close() error { w.closeOnce.Do(func() { close(w.closed) }); return nil }
func (w *terminatorStall) arm()         { w.mu.Lock(); w.armed = true; w.mu.Unlock() }
func (w *terminatorStall) output() string {
	w.mu.Lock()
	defer w.mu.Unlock()
	return string(w.written)
}

// Invariant: a consent change never waits behind a frame write. A Deny sent on the same
// session while only a private frame's newline is stalled (under the consent lock) becomes
// durable before the session ends, its receipt replays, and the stalled frame never
// completes. Covers the initial commit and the second commit after a slow body.
func TestDenyBehindStalledTerminatorIsDurableBeforeSessionEnds(t *testing.T) {
	for _, slowBody := range []bool{false, true} {
		t.Run(fmt.Sprintf("slowBody=%v", slowBody), func(t *testing.T) {
			testenv.IsolateHome(t)
			t.Setenv("MODELPLAN_READERS", "")
			cache := t.TempDir()
			if _, err := consent.EnsureStore(consent.Path()); err != nil {
				t.Fatal(err)
			}
			b, err := NewSharedBackend(SharedConfig{
				Detect: func() detect.Report {
					return detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: "zai", Preferred: "native", ReaderID: "native:zai"}, Detected: true}}}
				},
				Paths: func(a consent.Admission) quota.Paths {
					return quota.ProductionPathsWithAdmission(cache, "1.0.0", a)
				},
				Cleanup: func(string, bool, consent.EraseGuard) error { return nil },
			})
			if err != nil {
				t.Fatal(err)
			}
			state := consent.Capture().State()
			if _, err := b.Grant(context.Background(), wire.ConsentGrantParams{RequestID: "allow", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation,
				TextVersion: consent.TextVersion, Allow: []string{consent.ScopeZaiLocalHistory}, Deny: []string{}}); err != nil {
				t.Fatal(err)
			}

			w := &terminatorStall{stalled: make(chan struct{}), closed: make(chan struct{})}
			if slowBody {
				w.bodyDelay = commitTimeout + 200*time.Millisecond
			}
			inR, inW, err := os.Pipe()
			if err != nil {
				t.Fatal(err)
			}
			defer inW.Close()
			served := make(chan error, 1)
			go func() { served <- New(Config{Backend: b}).Serve(context.Background(), inR, w) }()
			send := func(id int, method string, p any) {
				t.Helper()
				raw, _ := json.Marshal(p)
				line, _ := json.Marshal(wire.Request{JSONRPC: wire.JSONRPC, ID: json.RawMessage(fmt.Sprint(id)), Method: method, Params: raw})
				if _, err := inW.Write(append(line, '\n')); err != nil {
					t.Fatal(err)
				}
			}
			send(1, "initialize", wire.InitializeParams{SessionID: "s-stall", ProtocolVersion: wire.ProtocolVersion, AppVersion: "test", Capabilities: []string{"rows", "consent"}})
			deadline := time.Now().Add(5 * time.Second)
			for !strings.Contains(w.output(), `"id":1,`) {
				if time.Now().After(deadline) {
					t.Fatalf("no initialize response: %q", w.output())
				}
				time.Sleep(5 * time.Millisecond)
			}

			w.arm()
			send(2, "rows/subscribe", wire.Empty{})
			select {
			case <-w.stalled:
			case <-time.After(5 * time.Second):
				t.Fatalf("the private frame's newline never stalled: %q", w.output())
			}
			before := consent.Capture().State()
			deny := wire.ConsentGrantParams{RequestID: "deny-behind-terminator", ExpectStoreEpoch: before.StoreEpoch, ExpectGeneration: before.Generation,
				TextVersion: consent.TextVersion, Allow: []string{}, Deny: []string{consent.ScopeZaiLocalHistory}}
			send(3, "consent/grant", deny)

			select {
			case err := <-served:
				if err != nil {
					t.Fatalf("serve: %v", err)
				}
			case <-time.After(10 * time.Second):
				t.Fatal("the session did not end after its terminator stalled")
			}
			// Serve has returned: the process would exit now. The Deny must already be durable.
			after := consent.Capture().State()
			if after.Generation <= before.Generation || after.AllowsScope(consent.ScopeZaiLocalHistory, consent.Automatic) {
				t.Fatalf("the Deny was not durable when the session ended: generation %d -> %d", before.Generation, after.Generation)
			}
			// The stalled private frame never completed.
			out := w.output()
			if i := strings.LastIndex(out, `"id":2,`); i < 0 || strings.Contains(out[i:], "\n") {
				t.Fatalf("the stalled private frame was completed or never started: %q", out)
			}
			// The receipt replays (as after a reconnect) without a second commit.
			replay, err := b.Grant(context.Background(), deny)
			if err != nil || !replay.Receipt.Committed || replay.Receipt.CommittedGeneration == nil || *replay.Receipt.CommittedGeneration != after.Generation {
				t.Fatalf("receipt replay: %+v %v", replay.Receipt, err)
			}
			if again := consent.Capture().State(); again.Generation != after.Generation {
				t.Fatalf("replay committed again: generation %d -> %d", after.Generation, again.Generation)
			}
		})
	}
}
