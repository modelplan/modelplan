// SPDX-License-Identifier: MIT
// Package u14fixture is synthetic test tooling linked only through a Go build
// overlay. It is not a U2 store, admission implementation, or release backend.
package u14fixture

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

const scope = "codex.runtime_usage"
const epoch = "u14-fixture-epoch"
const ConfigFile = ".u14-engine-fixture.json"
const StateFile = ".u14-engine-state.json"
const EventsFile = ".u14-engine-events.jsonl"

type Input struct {
	Model string `json:"modelMode"`
	Empty string `json:"emptyState"`
}
type savedReceipt struct {
	Hash   string                `json:"hash"`
	Result appserver.GrantResult `json:"result"`
}
type state struct {
	Version    int                     `json:"version"`
	Generation uint64                  `json:"generation"`
	Denied     bool                    `json:"denied"`
	Receipts   map[string]savedReceipt `json:"receipts"`
}
type fixture struct {
	mu        sync.Mutex
	home      string
	input     Input
	changed   chan struct{}
	transport *recordingTransport
}

// Config retains production framing/queues/timeouts. Invalid fixture setup
// fails closed; callers must pass a builder-created synthetic HOME.
func Config(version string) appserver.Config {
	home := os.Getenv("HOME")
	fallback := appserver.Config{Version: version, Backend: appserver.UnavailableBackend{}}
	if home == "" {
		return fallback
	}
	if marker, err := os.ReadFile(filepath.Join(home, ".u14-baseline.json")); err != nil || !bytes.Contains(marker, []byte(`"shapeSha256"`)) {
		return fallback
	}
	raw, err := os.ReadFile(filepath.Join(home, ConfigFile))
	if err != nil {
		return fallback
	}
	var input Input
	if json.Unmarshal(raw, &input) != nil {
		return fallback
	}
	switch input.Model {
	case "omitted", "null", "reported", "corrupt":
	default:
		return fallback
	}
	switch input.Empty {
	case "", "readers_off", "pending", "no_consent", "empty":
	default:
		return fallback
	}
	f := &fixture{home: home, input: input, changed: make(chan struct{}, 1)}
	f.transport = &recordingTransport{fixture: f}
	return appserver.Config{Version: version, Backend: f, Handlers: map[string]appserver.Handler{
		"history/query": {Capability: "history", Query: true, Private: true, Handle: f.history},
	}}
}
func (f *fixture) Capabilities() []string {
	return []string{"rows", "consent", "diagnostics", "history", "u14_fixture"}
}
func (f *fixture) Changes(context.Context) <-chan struct{} { return f.changed }
func (f *fixture) load() (state, error) {
	raw, err := os.ReadFile(filepath.Join(f.home, StateFile))
	if errors.Is(err, os.ErrNotExist) {
		return state{Version: 1, Generation: 1, Receipts: map[string]savedReceipt{}}, nil
	}
	if err != nil {
		return state{}, err
	}
	var s state
	if json.Unmarshal(raw, &s) != nil || s.Version != 1 || s.Generation < 1 || s.Receipts == nil {
		return state{}, errors.New("fixture state invalid")
	}
	return s, nil
}
func (f *fixture) event(code string) error {
	// Codes are fixed by the fixture, never copied from provider data.
	file, err := os.OpenFile(filepath.Join(f.home, EventsFile), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
	if err != nil {
		return err
	}
	defer file.Close()
	b, _ := json.Marshal(map[string]string{"event": code})
	_, err = file.Write(append(b, '\n'))
	return err
}
func (f *fixture) view(s state) appserver.View {
	detected := false
	if info, err := os.Stat(filepath.Join(f.home, "bin/codex")); err == nil && !info.IsDir() {
		detected = true
	}
	consent := rows.ConsentAllowed
	fact := wire.ConsentAllowed
	if s.Denied || f.input.Empty == "no_consent" {
		consent = rows.ConsentDenied
		fact = wire.ConsentDenied
	}
	input := rows.Input{Now: time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC), ConsentGeneration: s.Generation,
		Catalogue: []rows.CatalogueEntry{{ToolID: "codex", Detected: detected, ReaderExists: true}},
		Consents:  []rows.ConsentRecord{{ToolID: "codex", State: consent, Generation: s.Generation}},
	}
	switch f.input.Empty {
	case "readers_off":
		input.ReadersOff = true
	case "pending":
		input.ConsentChanged = true
	case "empty":
		// An allowed detected tool with no readings/actions has summary=empty.
	}
	if !s.Denied && f.input.Empty == "" {
		input.DeclaredPlanIDs = []string{"synthetic-team"}
	}
	projection := rows.Build(input)
	health := wire.Health{State: wire.HealthReady, Code: "u14_fixture"}
	if s.Denied {
		health = wire.Health{State: wire.HealthDegraded, Code: "synthetic_revoked"}
	}
	return appserver.View{Stamp: appserver.Stamp{Epoch: epoch, Generation: s.Generation}, Projection: projection,
		Scopes: []string{scope}, Consent: wire.ConsentFacts{Scopes: []wire.ConsentScope{{Scope: scope, Tool: "codex", Route: rows.RouteRuntimeRPC, State: fact, Detected: detected}}},
		Diagnostics: []wire.ScopeDiag{}, Health: health}
}
func (f *fixture) Get(ctx context.Context) (appserver.View, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if err := ctx.Err(); err != nil {
		return appserver.View{}, err
	}
	s, err := f.load()
	if err != nil {
		return appserver.View{}, err
	}
	if s.Denied {
		if err := f.event("health-observed"); err != nil {
			return appserver.View{}, err
		}
	}
	return f.view(s), nil
}
func (f *fixture) Publish(ctx context.Context, stamp appserver.Stamp, enqueue func() error) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if err := ctx.Err(); err != nil {
		return err
	}
	s, err := f.load()
	if err != nil {
		return err
	}
	if stamp != (appserver.Stamp{Epoch: epoch, Generation: s.Generation}) {
		return appserver.ProtocolError{Code: wire.CodeConsentChanged}
	}
	return enqueue()
}
func (f *fixture) Grant(ctx context.Context, p wire.ConsentGrantParams) (appserver.GrantResult, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if err := ctx.Err(); err != nil {
		return appserver.GrantResult{}, err
	}
	s, err := f.load()
	if err != nil {
		return appserver.GrantResult{}, err
	}
	payload, _ := json.Marshal(p)
	hash := sha256.Sum256(payload)
	hashString := hex.EncodeToString(hash[:])
	if prior, ok := s.Receipts[p.RequestID]; ok {
		if prior.Hash != hashString {
			return appserver.GrantResult{}, appserver.ProtocolError{Code: wire.CodeRequestMismatch}
		}
		_ = f.event("receipt-replayed")
		return prior.Result, nil
	}
	if p.ExpectStoreEpoch != epoch || p.ExpectGeneration != s.Generation {
		return appserver.GrantResult{}, appserver.ProtocolError{Code: wire.CodeConsentStale}
	}
	if len(p.Allow) > 0 || len(p.Keychain) > 0 || len(p.Deny)+len(p.Forget) == 0 {
		return appserver.GrantResult{}, appserver.ProtocolError{Code: wire.CodeConsentRejected}
	}
	for _, id := range append(p.Deny, p.Forget...) {
		if id != scope {
			return appserver.GrantResult{}, appserver.ProtocolError{Code: wire.CodeConsentRejected}
		}
	}
	s.Generation++
	s.Denied = true
	gen := s.Generation
	result := appserver.GrantResult{Stamp: appserver.Stamp{Epoch: epoch, Generation: gen}, Receipt: wire.ConsentReceipt{RequestID: p.RequestID, Committed: true, CommittedGeneration: &gen, Code: wire.ReceiptOK}}
	s.Receipts[p.RequestID] = savedReceipt{Hash: hashString, Result: result}
	data, _ := json.Marshal(s)
	file, err := os.CreateTemp(f.home, ".u14-state-*")
	if err != nil {
		return appserver.GrantResult{}, err
	}
	tmp := file.Name()
	defer os.Remove(tmp)
	if _, err = file.Write(data); err == nil {
		err = file.Sync()
	}
	closeErr := file.Close()
	if err == nil {
		err = closeErr
	}
	if err == nil {
		err = os.Rename(tmp, filepath.Join(f.home, StateFile))
	}
	if err != nil {
		return appserver.GrantResult{}, err
	}
	if err = f.event("revoke-committed"); err != nil {
		return result, err
	}
	if err = f.event("health-degraded"); err != nil {
		return result, err
	}
	select {
	case f.changed <- struct{}{}:
	default:
	}
	return result, nil
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
func (f *fixture) history(ctx context.Context, raw json.RawMessage, stamp appserver.Stamp) (appserver.Reply, error) {
	var p wire.HistoryQueryParams
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&p) != nil || p.Kind != wire.HistoryTokens || p.Tool != "codex" || p.Limit < 1 || p.Limit > 500 {
		return appserver.Reply{}, appserver.ProtocolError{Code: wire.CodeInvalidParams}
	}
	client := http.Client{Transport: f.transport}
	req, err := http.NewRequestWithContext(ctx, "GET", "https://provider.invalid/history", nil)
	if err != nil {
		return appserver.Reply{}, err
	}
	response, err := client.Do(req)
	if err != nil {
		return appserver.Reply{}, err
	}
	defer response.Body.Close()
	var page wire.HistoryPage
	if json.NewDecoder(response.Body).Decode(&page) != nil {
		return appserver.Reply{}, appserver.ProtocolError{Code: wire.CodeHistoryUnavailable}
	}
	if p.Ref == "pressure-first" || p.Ref == "pressure-second" {
		model := "synthetic-" + strings.Repeat("x", 256<<10)
		page.Items[0].Model = &model
	}
	f.mu.Lock()
	err = f.event("query-completed")
	f.mu.Unlock()
	if err != nil {
		return appserver.Reply{}, err
	}
	return appserver.Reply{Stamp: stamp, Scopes: []string{scope}, Data: page}, nil
}
