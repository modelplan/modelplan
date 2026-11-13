//go:build darwin || linux

// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"syscall"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
)

func holdConsentLock(t *testing.T) func() {
	t.Helper()
	f, err := os.OpenFile(consent.Path()+".lock", os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		t.Fatal(err)
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		t.Fatal(err)
	}
	released := false
	release := func() {
		if !released {
			released = true
			_ = syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
			_ = f.Close()
		}
	}
	t.Cleanup(release)
	return release
}

func TestSharedPublishContentionAndFence(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	b := &SharedBackend{}
	stamp := stampOf(state.Fence())

	t.Run("release before bound", func(t *testing.T) {
		release := holdConsentLock(t)
		done := make(chan error, 1)
		writes := make(chan struct{}, 1)
		go func() {
			done <- b.Publish(context.Background(), stamp, func() error { writes <- struct{}{}; return nil })
		}()
		select {
		case err := <-done:
			t.Fatalf("publish returned while locked: %v", err)
		case <-time.After(50 * time.Millisecond):
		}
		release()
		if err := <-done; err != nil {
			t.Fatalf("publish after release: %v", err)
		}
		if len(writes) != 1 {
			t.Fatalf("writes = %d, want 1", len(writes))
		}
	})
	t.Run("busy after bound", func(t *testing.T) {
		release := holdConsentLock(t)
		defer release()
		start := time.Now()
		err := b.Publish(context.Background(), stamp, func() error { t.Error("published under held lock"); return nil })
		if got := errorCode(err); got != wire.CodeBusy {
			t.Fatalf("error = %v, code = %d, want busy", err, got)
		}
		if elapsed := time.Since(start); elapsed < 900*time.Millisecond || elapsed > 3*time.Second {
			t.Fatalf("unbounded wait: %v", elapsed)
		}
	})
	t.Run("cancel while locked", func(t *testing.T) {
		release := holdConsentLock(t)
		defer release()
		ctx, cancel := context.WithTimeout(context.Background(), 40*time.Millisecond)
		defer cancel()
		err := b.Publish(ctx, stamp, func() error { t.Error("published after cancellation"); return nil })
		if !errors.Is(err, context.DeadlineExceeded) || errorCode(err) != wire.CodeCanceled {
			t.Fatalf("cancellation lost: %v", err)
		}
	})
	t.Run("changed under lock", func(t *testing.T) {
		release := holdConsentLock(t)
		done := make(chan error, 1)
		go func() {
			done <- b.Publish(context.Background(), stamp, func() error { t.Error("stale result published"); return nil })
		}()
		select {
		case err := <-done:
			t.Fatalf("publish returned while locked: %v", err)
		case <-time.After(50 * time.Millisecond):
		}
		state.Generation++
		data, err := json.Marshal(state)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(consent.Path(), data, 0600); err != nil {
			t.Fatal(err)
		}
		release()
		if err := <-done; errorCode(err) != wire.CodeConsentChanged {
			t.Fatalf("changed fence: %v", err)
		}
	})
	t.Run("callback errors are not consent changes or retried", func(t *testing.T) {
		calls := 0
		sentinel := errors.New("synthetic callback failure")
		err := b.Publish(context.Background(), stampOf(state.Fence()), func() error { calls++; return sentinel })
		if !errors.Is(err, sentinel) || errorCode(err) != wire.CodeInternal || calls != 1 {
			t.Fatalf("error=%v code=%d calls=%d", err, errorCode(err), calls)
		}
	})
}

type firstBusyBackend struct {
	*memoryBackend
	busy bool
}

func (b *firstBusyBackend) Publish(ctx context.Context, stamp Stamp, write func() error) error {
	if b.busy {
		b.busy = false
		return ProtocolError{wire.CodeBusy}
	}
	return b.memoryBackend.Publish(ctx, stamp, write)
}

func TestRowsRefreshRetriesBusyPublicationAndFinalFence(t *testing.T) {
	backend := &firstBusyBackend{memoryBackend: newMemoryBackend(), busy: true}
	server := New(Config{Backend: backend})
	server.ctx, server.stop = context.WithCancel(context.Background())
	defer server.stop()
	server.out = newOutbound(server.ctx, server.stop, nil, time.Second, nil)
	server.initialized, server.subscribed = true, true
	server.session, server.view, server.sequence = "s-test", backend.view, 1
	backend.view.Health.Code = "changed"
	if err := server.refresh(context.Background()); errorCode(err) != wire.CodeBusy {
		t.Fatalf("first refresh: %v", err)
	}
	if !server.rowsPending {
		t.Fatal("busy update was not retained")
	}
	if err := server.refresh(context.Background()); err != nil {
		t.Fatalf("retry refresh: %v", err)
	}
	if server.rowsPending || server.out.latest == nil {
		t.Fatal("unchanged view did not retry pending rows")
	}
	pending := server.out.latest
	pending.stale(ProtocolError{wire.CodeBusy})
	if !server.rowsPending {
		t.Fatal("busy final fence did not retain rows")
	}
	if err := server.refresh(context.Background()); err != nil {
		t.Fatalf("retry final fence: %v", err)
	}
	if server.rowsPending || server.out.latest == nil {
		t.Fatal("final-fence retry did not publish rows")
	}
}
