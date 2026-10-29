// SPDX-License-Identifier: MIT
// Package u14fixture supplies recording providers through a test build overlay.
// Consent, receipts, epochs, rows and publication fences always use production.
package u14fixture

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
)

const scope = "codex.local_history"
const ConfigFile = ".u14-engine-fixture.json"
const EventsFile = ".u14-engine-events.jsonl"

type Input struct {
	Empty    string `json:"emptyState"`
	Model    string `json:"modelMode"`
	Pressure bool   `json:"pressure"`
	Block    bool   `json:"block"`
}
type fixture struct {
	mu        sync.Mutex
	home      string
	input     Input
	backend   appserver.Backend
	fallback  queries.HistorySource
	transport *recordingTransport
	valid     bool
}

// NewHistorySource cannot replace Backend: it only supplies fake provider data
// to the production query handler, which applies the real shared publish fence.
func NewHistorySource(backend appserver.Backend, fallback queries.HistorySource) queries.HistorySource {
	f := &fixture{home: os.Getenv("HOME"), backend: backend, fallback: fallback}
	marker, err := os.ReadFile(filepath.Join(f.home, ".u14-baseline.json"))
	if err != nil || !bytes.Contains(marker, []byte(`"shapeSha256"`)) {
		return f
	}
	raw, err := os.ReadFile(filepath.Join(f.home, ConfigFile))
	if err != nil || json.Unmarshal(raw, &f.input) != nil {
		return f
	}
	switch f.input.Model {
	case "omitted", "null", "reported", "corrupt":
		f.valid = true
	}
	f.transport = &recordingTransport{fixture: f}
	return f
}
func (f *fixture) event(code string) error {
	file, err := os.OpenFile(filepath.Join(f.home, EventsFile), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
	if err != nil {
		return err
	}
	defer file.Close()
	raw, _ := json.Marshal(map[string]string{"event": code})
	_, err = file.Write(append(raw, '\n'))
	return err
}
func (f *fixture) AdmitHistory(ctx context.Context, stamp appserver.Stamp, p wire.HistoryQueryParams) (queries.HistoryAdmission, error) {
	f.mu.Lock()
	err := f.event("history-admission")
	f.mu.Unlock()
	if err != nil {
		return queries.HistoryAdmission{}, err
	}

	if p.Tool != "codex" && f.fallback != nil {
		return f.fallback.AdmitHistory(ctx, stamp, p)
	}
	if !f.valid || f.backend == nil {
		return queries.HistoryAdmission{}, appserver.ProtocolError{Code: wire.CodeHistoryUnavailable}
	}
	view, err := f.backend.Get(ctx)
	if err != nil {
		return queries.HistoryAdmission{}, err
	}
	if view.Stamp != stamp {
		return queries.HistoryAdmission{}, appserver.ProtocolError{Code: wire.CodeConsentChanged}
	}
	allowed := false
	for _, id := range view.Scopes {
		if id == scope {
			allowed = true
		}
	}
	if !allowed || p.Tool != "codex" || p.Ref != "" {
		return queries.HistoryAdmission{}, appserver.ProtocolError{Code: wire.CodeConsentRejected}
	}
	if p.Kind != wire.HistoryTokens {
		return queries.HistoryAdmission{}, appserver.ProtocolError{Code: wire.CodeHistoryUnavailable}
	}
	return queries.HistoryAdmission{Stamp: stamp, Scopes: []string{scope}}, nil
}
func (f *fixture) ReadHistory(ctx context.Context, admission queries.HistoryAdmission, p wire.HistoryQueryParams, position string) (queries.HistoryBatch, error) {
	if p.Tool != "codex" && f.fallback != nil {
		return f.fallback.ReadHistory(ctx, admission, p, position)
	}
	if f.input.Block {
		f.mu.Lock()
		_ = f.event("query-started")
		f.mu.Unlock()
		for {
			if _, err := os.Stat(filepath.Join(f.home, ".u14-release")); err == nil {
				break
			}
			select {
			case <-ctx.Done():
				return queries.HistoryBatch{}, ctx.Err()
			case <-time.After(10 * time.Millisecond):
			}
		}
	}
	if !f.valid || admission.Stamp.Epoch == "" {
		return queries.HistoryBatch{}, appserver.ProtocolError{Code: wire.CodeHistoryUnavailable}
	}
	if position != "" && position != "second" {
		return queries.HistoryBatch{}, appserver.ProtocolError{Code: wire.CodeCursorStale}
	}
	client := http.Client{Transport: f.transport}
	req, err := http.NewRequestWithContext(ctx, "GET", "https://provider.invalid/history", nil)
	if err != nil {
		return queries.HistoryBatch{}, err
	}
	response, err := client.Do(req)
	if err != nil {
		return queries.HistoryBatch{}, err
	}
	defer response.Body.Close()
	var page wire.HistoryPage
	if json.NewDecoder(response.Body).Decode(&page) != nil {
		return queries.HistoryBatch{}, appserver.ProtocolError{Code: wire.CodeHistoryUnavailable}
	}
	if f.input.Pressure {
		model := "synthetic-" + strings.Repeat("x", 256<<10)
		page.Items[0].Model = &model
	}
	f.mu.Lock()
	err = f.event("query-completed")
	f.mu.Unlock()
	if err != nil {
		return queries.HistoryBatch{}, err
	}
	next := ""
	if position == "" {
		next = "second"
	}
	return queries.HistoryBatch{Items: page.Items, Next: next}, nil
}

// recordingTransport never opens a socket, resolves a host, reads credentials,
// redirects, or forwards a request. Its fixed endpoint is a synthetic provider.
type recordingTransport struct{ fixture *fixture }

func (r *recordingTransport) RoundTrip(request *http.Request) (*http.Response, error) {
	if request.Method != "GET" || request.URL.Scheme != "https" || request.URL.Host != "provider.invalid" || request.URL.Path != "/history" || request.URL.RawQuery != "" {
		return nil, errors.New("fixture destination refused")
	}
	r.fixture.mu.Lock()
	defer r.fixture.mu.Unlock()
	if err := r.fixture.event("provider-history-get"); err != nil {
		return nil, err
	}
	item := map[string]any{"at": "2026-10-29T12:00:00Z", "tokens": int64(8), "window": nil, "value": nil}
	switch r.fixture.input.Model {
	case "null":
		item["model"] = nil
	case "reported":
		item["model"] = "synthetic-reader-model"
	case "corrupt":
		item["model"] = map[string]bool{"synthetic-invalid": true}
	}
	data, _ := json.Marshal(map[string]any{"items": []any{item}})
	return &http.Response{StatusCode: 200, Header: make(http.Header), Body: io.NopCloser(bytes.NewReader(data)), Request: request}, nil
}

// WrapDetection injects repeated consent churn only for the pending-state fault
// scenario. It uses real transactions; every third build leaves the fallback's
// captured fence stable. Ordinary binaries do not link this provider helper.
func WrapDetection(base func() detect.Report) func() detect.Report {
	home := os.Getenv("HOME")
	var input Input
	raw, err := os.ReadFile(filepath.Join(home, ConfigFile))
	if err != nil || json.Unmarshal(raw, &input) != nil || input.Empty != "pending" {
		return base
	}
	var mu sync.Mutex
	n := 0
	return func() detect.Report {
		mu.Lock()
		defer mu.Unlock()
		n++
		if n%3 != 0 {
			state, err := consent.Load(consent.Path())
			if err == nil {
				_, _ = consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: fmt.Sprintf("u14-churn-%d", n), ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation, ConsentTextVersion: consent.TextVersion, Deny: []string{consent.ScopeQwenLocalHistory}}, consent.GrantHooks{})
			}
		}
		return base()
	}
}
