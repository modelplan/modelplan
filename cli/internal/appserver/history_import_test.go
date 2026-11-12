// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

type fakeImport struct {
	started chan struct{}
	release chan struct{}
	removed bool
	rows    atomic.Int64 // written by the run, read by status replies
}

func (f *fakeImport) Run(ctx context.Context, days int, firstRun bool, progress func(int, int)) ([]wire.HistoryImportSource, error) {
	progress(0, 4)
	close(f.started)
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-f.release:
	}
	progress(4, 4)
	f.rows.Store(7)
	return []wire.HistoryImportSource{{Source: "claude-code", Status: wire.ImportSourceImported, Turns: 3}, {Source: "codex", Status: wire.ImportSourceNoConsent}}, nil
}
func (f *fakeImport) State() wire.HistoryImportStatus {
	rows := int(f.rows.Load())
	return wire.HistoryImportStatus{ImportedRows: rows, FirstRunDone: rows > 0, Coverage: []wire.HistoryImportCoverage{}}
}
func (f *fakeImport) Remove() error { f.removed = true; f.rows.Store(0); return nil }

func call(t *testing.T, h map[string]Handler, method, body string) (wire.HistoryImportStatus, error) {
	t.Helper()
	r, err := h[method].Handle(context.Background(), json.RawMessage(body), Stamp{})
	if err != nil {
		return wire.HistoryImportStatus{}, err
	}
	return r.Data.(wire.HistoryImportStatus), nil
}

func waitPhase(t *testing.T, h map[string]Handler, want wire.HistoryImportPhase) wire.HistoryImportStatus {
	t.Helper()
	for i := 0; i < 400; i++ {
		st, _ := call(t, h, "history/import_status", `{}`)
		if st.Phase == want {
			return st
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("never reached %s", want)
	return wire.HistoryImportStatus{}
}

func TestHistoryImportStartProgressDoneAndRemove(t *testing.T) {
	f := &fakeImport{started: make(chan struct{}), release: make(chan struct{})}
	c := NewImportController(f)
	defer c.Close()
	h := HistoryImportHandlers(c)
	if st, _ := call(t, h, "history/import_status", `{}`); st.Phase != wire.ImportIdle || st.SchemaVersion != 1 {
		t.Fatalf("%+v", st)
	}
	st, err := call(t, h, "history/import_start", `{"days":30,"firstRun":false}`)
	if err != nil || st.Phase != wire.ImportRunning || st.Days != 30 {
		t.Fatalf("%+v %v", st, err)
	}
	<-f.started
	if _, err := call(t, h, "history/import_start", `{"days":30,"firstRun":false}`); !errors.Is(err, ProtocolError{wire.CodeBusy}) {
		t.Fatalf("second start while running: %v", err)
	}
	if _, err := call(t, h, "history/import_remove", `{}`); !errors.Is(err, ProtocolError{wire.CodeBusy}) {
		t.Fatalf("remove while running: %v", err)
	}
	close(f.release)
	st = waitPhase(t, h, wire.ImportDone)
	if st.FilesDone != 4 || st.FilesTotal != 4 || len(st.Sources) != 2 || st.Sources[1].Status != wire.ImportSourceNoConsent || st.ImportedRows != 7 {
		t.Fatalf("%+v", st)
	}
	if st, err = call(t, h, "history/import_remove", `{}`); err != nil || !f.removed || st.ImportedRows != 0 || st.Phase != wire.ImportIdle {
		t.Fatalf("%+v %v", st, err)
	}
}

func TestHistoryImportCancelWritesNothing(t *testing.T) {
	f := &fakeImport{started: make(chan struct{}), release: make(chan struct{})}
	c := NewImportController(f)
	h := HistoryImportHandlers(c)
	call(t, h, "history/import_start", `{"days":7,"firstRun":true}`)
	<-f.started
	st, err := call(t, h, "history/import_cancel", `{}`)
	if err != nil || st.Phase != wire.ImportCancelled || f.rows.Load() != 0 {
		t.Fatalf("%+v %v", st, err)
	}
	// cancel with nothing running is harmless
	if _, err := call(t, h, "history/import_cancel", `{}`); err != nil {
		t.Fatal(err)
	}
}

func TestHistoryImportRejectsBadParams(t *testing.T) {
	c := NewImportController(&fakeImport{})
	h := HistoryImportHandlers(c)
	for _, body := range []string{`{}`, `{"days":0,"firstRun":false}`, `{"days":372,"firstRun":false}`, `{"days":30,"firstRun":false,"path":"/x"}`, `[]`} {
		if _, err := call(t, h, "history/import_start", body); !errors.Is(err, ProtocolError{wire.CodeInvalidParams}) {
			t.Fatalf("%s: %v", body, err)
		}
	}
	if _, err := call(t, h, "history/import_status", `{"x":1}`); !errors.Is(err, ProtocolError{wire.CodeInvalidParams}) {
		t.Fatal(err)
	}
}

// fastImport finishes its run at once; State waits until the controller has settled the run, so
// the start reply is built after the worker set done (the legal ordering in macrev2-856-1).
type fastImport struct {
	c     *ImportController
	turns int
}

func (f *fastImport) Run(context.Context, int, bool, func(int, int)) ([]wire.HistoryImportSource, error) {
	f.turns++
	return []wire.HistoryImportSource{{Source: "codex", Status: wire.ImportSourceImported, Turns: f.turns}}, nil
}
func (f *fastImport) State() wire.HistoryImportStatus {
	for i := 0; i < 400; i++ {
		f.c.mu.Lock()
		settled := f.c.phase != wire.ImportRunning
		f.c.mu.Unlock()
		if settled {
			break
		}
		time.Sleep(time.Millisecond)
	}
	// Same rows and coverage for every run: only the imported values change.
	return wire.HistoryImportStatus{ImportedRows: 1, Coverage: []wire.HistoryImportCoverage{{Source: "codex", From: "2026-11-08", Through: "2026-11-08", Rows: 1}}}
}
func (f *fastImport) Remove() error { return nil }

// Every operation that can change imported history gets a new revision, also when the start
// reply is already done and running is never observed; status polls repeat it.
func TestHistoryImportRevisionIdentifiesEachCompletion(t *testing.T) {
	f := &fastImport{}
	c := NewImportController(f)
	f.c = c
	defer c.Close()
	h := HistoryImportHandlers(c)
	rev := func(st wire.HistoryImportStatus) int {
		t.Helper()
		if st.Revision == nil {
			t.Fatalf("no revision: %+v", st)
		}
		return *st.Revision
	}
	st, err := call(t, h, "history/import_status", `{}`)
	if err != nil || rev(st) != 0 {
		t.Fatalf("%+v %v", st, err)
	}
	first, err := call(t, h, "history/import_start", `{"days":30,"firstRun":false}`)
	if err != nil || first.Phase != wire.ImportDone || rev(first) != 1 {
		t.Fatalf("fast start reply: %+v %v", first, err)
	}
	if st, _ := call(t, h, "history/import_status", `{}`); rev(st) != 1 {
		t.Fatalf("poll of the same completion: %+v", st)
	}
	second, err := call(t, h, "history/import_start", `{"days":30,"firstRun":false}`)
	if err != nil || second.Phase != wire.ImportDone || rev(second) != 2 {
		t.Fatalf("second fast start reply: %+v %v", second, err)
	}
	if second.ImportedRows != first.ImportedRows || len(second.Coverage) != 1 || second.Coverage[0] != first.Coverage[0] {
		t.Fatalf("summary should be identical: %+v vs %+v", first, second)
	}
	if st, err := call(t, h, "history/import_remove", `{}`); err != nil || st.Phase != wire.ImportIdle || rev(st) != 3 {
		t.Fatalf("remove: %+v %v", st, err)
	}
}

func TestHistoryImportCancelAdvancesRevision(t *testing.T) {
	f := &fakeImport{started: make(chan struct{}), release: make(chan struct{})}
	c := NewImportController(f)
	h := HistoryImportHandlers(c)
	if st, _ := call(t, h, "history/import_start", `{"days":7,"firstRun":true}`); st.Revision == nil || *st.Revision != 0 {
		t.Fatalf("running start reply: %+v", st)
	}
	<-f.started
	if st, err := call(t, h, "history/import_cancel", `{}`); err != nil || st.Phase != wire.ImportCancelled || st.Revision == nil || *st.Revision != 1 {
		t.Fatalf("%+v %v", st, err)
	}
}
