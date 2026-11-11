// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

type fakeImport struct {
	started chan struct{}
	release chan struct{}
	removed bool
	rows    int
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
	f.rows = 7
	return []wire.HistoryImportSource{{Source: "claude-code", Status: wire.ImportSourceImported, Turns: 3}, {Source: "codex", Status: wire.ImportSourceNoConsent}}, nil
}
func (f *fakeImport) State() wire.HistoryImportStatus {
	return wire.HistoryImportStatus{ImportedRows: f.rows, FirstRunDone: f.rows > 0, Coverage: []wire.HistoryImportCoverage{}}
}
func (f *fakeImport) Remove() error { f.removed = true; f.rows = 0; return nil }

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
	if err != nil || st.Phase != wire.ImportCancelled || f.rows != 0 {
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
