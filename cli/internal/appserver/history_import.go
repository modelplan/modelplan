// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"sync"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// ImportEngine is what the history-import methods need from the engine; the command wires the
// real one (speed.Import under the consent fence) and tests wire a synthetic one. Run reads
// logs and may take minutes: it must stop when ctx is cancelled and write nothing then.
type ImportEngine interface {
	Run(ctx context.Context, days int, firstRun bool, progress func(done, total int)) ([]wire.HistoryImportSource, error)
	// State is read-only: it never touches the logs.
	State() wire.HistoryImportStatus
	Remove() error
}

// ImportController runs at most one import in the background and reports it. A run is not tied
// to the request that started it, so Settings can poll history/import_status and cancel it.
type ImportController struct {
	engine ImportEngine
	mu     sync.Mutex
	phase  wire.HistoryImportPhase
	days   int
	done   int
	total  int
	last   []wire.HistoryImportSource
	cancel context.CancelFunc
	wg     sync.WaitGroup
}

func NewImportController(e ImportEngine) *ImportController {
	return &ImportController{engine: e, phase: wire.ImportIdle}
}

// Close cancels a running import and waits for it.
func (c *ImportController) Close() {
	c.mu.Lock()
	cancel := c.cancel
	c.mu.Unlock()
	if cancel != nil {
		cancel()
	}
	c.wg.Wait()
}

func (c *ImportController) status() wire.HistoryImportStatus {
	st := c.engine.State()
	c.mu.Lock()
	defer c.mu.Unlock()
	st.SchemaVersion, st.Phase, st.Days, st.FilesDone, st.FilesTotal = 1, c.phase, c.days, c.done, c.total
	st.Sources = append([]wire.HistoryImportSource{}, c.last...)
	if st.Coverage == nil {
		st.Coverage = []wire.HistoryImportCoverage{}
	}
	return st
}

func (c *ImportController) start(p wire.HistoryImportStartParams) error {
	c.mu.Lock()
	if c.phase == wire.ImportRunning {
		c.mu.Unlock()
		return ProtocolError{wire.CodeBusy}
	}
	ctx, cancel := context.WithCancel(context.Background())
	c.phase, c.days, c.done, c.total, c.last, c.cancel = wire.ImportRunning, p.Days, 0, 0, nil, cancel
	c.wg.Add(1)
	c.mu.Unlock()
	go func() {
		defer c.wg.Done()
		defer cancel()
		res, err := c.engine.Run(ctx, p.Days, p.FirstRun, func(done, total int) {
			c.mu.Lock()
			c.done, c.total = done, total
			c.mu.Unlock()
		})
		c.mu.Lock()
		defer c.mu.Unlock()
		switch {
		case ctx.Err() != nil:
			c.phase = wire.ImportCancelled
		case err != nil:
			c.phase = wire.ImportFailed
		default:
			c.phase, c.last = wire.ImportDone, res
		}
	}()
	return nil
}

// HistoryImportHandlers: history/import_start answers at once with the running status;
// history/import_status polls it (read-only); history/import_cancel stops a running import
// without writing; history/import_remove deletes exactly the imported history.
func HistoryImportHandlers(c *ImportController) map[string]Handler {
	const capability = "history_import_v1"
	reply := func(stamp Stamp) (Reply, error) { return Reply{Stamp: stamp, Data: c.status()}, nil }
	return map[string]Handler{
		"history/import_start": {Capability: capability, Handle: func(_ context.Context, raw json.RawMessage, stamp Stamp) (Reply, error) {
			p, err := params[wire.HistoryImportStartParams](raw)
			if err != nil || p.Days < 1 || p.Days > 371 {
				return Reply{}, ProtocolError{wire.CodeInvalidParams}
			}
			if err := c.start(p); err != nil {
				return Reply{}, err
			}
			return reply(stamp)
		}},
		"history/import_status": {Capability: capability, Query: true, Handle: func(_ context.Context, raw json.RawMessage, stamp Stamp) (Reply, error) {
			if _, err := params[wire.Empty](raw); err != nil {
				return Reply{}, ProtocolError{wire.CodeInvalidParams}
			}
			return reply(stamp)
		}},
		"history/import_cancel": {Capability: capability, Handle: func(_ context.Context, raw json.RawMessage, stamp Stamp) (Reply, error) {
			if _, err := params[wire.Empty](raw); err != nil {
				return Reply{}, ProtocolError{wire.CodeInvalidParams}
			}
			c.mu.Lock()
			cancel := c.cancel
			running := c.phase == wire.ImportRunning
			c.mu.Unlock()
			if running && cancel != nil {
				cancel()
				c.wg.Wait() // the run has stopped and written nothing when this answers
			}
			return reply(stamp)
		}},
		"history/import_remove": {Capability: capability, Handle: func(_ context.Context, raw json.RawMessage, stamp Stamp) (Reply, error) {
			if _, err := params[wire.Empty](raw); err != nil {
				return Reply{}, ProtocolError{wire.CodeInvalidParams}
			}
			c.mu.Lock()
			running := c.phase == wire.ImportRunning
			c.mu.Unlock()
			if running {
				return Reply{}, ProtocolError{wire.CodeBusy}
			}
			if err := c.engine.Remove(); err != nil {
				return Reply{}, ProtocolError{wire.CodeInternal}
			}
			c.mu.Lock()
			c.phase, c.last, c.done, c.total = wire.ImportIdle, nil, 0, 0
			c.mu.Unlock()
			r, _ := reply(stamp)
			r.Receipt = true
			return r, nil
		}},
	}
}
