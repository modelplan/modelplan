package main

import (
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

type pausedStatuslineInput struct {
	once             sync.Once
	started, release chan struct{}
	reader           io.Reader
}

func (p *pausedStatuslineInput) Read(b []byte) (int, error) {
	p.once.Do(func() { close(p.started); <-p.release })
	return p.reader.Read(b)
}

func TestStatuslineAndForgetShareWriterAdmission(t *testing.T) {
	home := consentFixtureHome(t)
	input := `{"model":{"id":"claude-fixture"},"rate_limits":{"five_hour":{"used_percentage":25,"resets_at":2000000000}}}`
	p := &pausedStatuslineInput{started: make(chan struct{}), release: make(chan struct{}), reader: strings.NewReader(input)}
	defer func() {
		select {
		case <-p.release:
		default:
			close(p.release)
		}
	}()
	done := make(chan int, 1)
	go func() { done <- run([]string{"statusline", "--record-only", "--offline"}, p, io.Discard, io.Discard) }()
	select {
	case <-p.started:
	case <-time.After(5 * time.Second):
		t.Fatal("statusline did not enter")
	}
	if code, _, _ := consentRun([]string{"disconnect", "claude", "--json"}, ""); code != 0 {
		t.Fatal("cleanup failed before the paused input was admitted")
	}
	close(p.release)
	if code := <-done; code != 0 {
		t.Fatal(code)
	}
	if code, out, errOut := consentRun([]string{"disconnect", "claude", "--json"}, ""); code != 0 {
		t.Fatal(code, out, errOut)
	}
	if code := run([]string{"statusline", "--record-only", "--offline"}, strings.NewReader(input), io.Discard, io.Discard); code != 0 {
		t.Fatal(code)
	}
	if _, err := os.Stat(filepath.Join(home, "modelplan-cache/observed/claude-code.json")); !os.IsNotExist(err) {
		t.Fatal("revoked snapshot repopulated cache")
	}
}

func TestQueuedReportWriteCannotRepopulateAfterForget(t *testing.T) {
	consentFixtureHome(t)
	st, err := store.Locate()
	if err != nil {
		t.Fatal(err)
	}
	old := quota.ReadPermitted(quotaPaths(st), time.Now())
	if code, out, errOut := consentRun([]string{"disconnect", "claude", "--json"}, ""); code != 0 {
		t.Fatal(code, out, errOut)
	}
	reportWrite(old, func() error { t.Fatal("stale queued report was allowed to write after Forget"); return nil })
}
