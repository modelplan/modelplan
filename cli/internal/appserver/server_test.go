// SPDX-License-Identifier: MIT
package appserver

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

const testScope = "claude.account_usage.saved_login"

// memoryBackend is a test double at U3's backend seam. Its receipts do not prove
// shared-store durability or the real U2 migration/admission implementation.
type memoryBackend struct {
	mu        sync.Mutex
	view      View
	changed   chan struct{}
	committed chan struct{}
	accepted  int
	receipts  map[string]GrantResult
}

func newMemoryBackend() *memoryBackend {
	choice := wire.KeychainAllow
	b := &memoryBackend{changed: make(chan struct{}, 1), committed: make(chan struct{}, 1), receipts: map[string]GrantResult{}}
	b.view = View{Stamp: Stamp{Epoch: "epoch-test", Generation: 1}, Projection: rows.Build(rows.Input{Now: time.Now(), ConsentGeneration: 1, Catalogue: []rows.CatalogueEntry{{ToolID: "claude", Detected: true, ReaderExists: true}}, Consents: []rows.ConsentRecord{{ToolID: "claude", State: rows.ConsentAllowed, Generation: 1}}}), Scopes: []string{testScope}, Consent: wire.ConsentFacts{Scopes: []wire.ConsentScope{{Scope: testScope, Tool: "claude", Route: rows.RouteSavedLoginAPI, State: wire.ConsentAllowed, Keychain: &choice}}}, Diagnostics: []wire.ScopeDiag{}, Health: wire.Health{State: wire.HealthReady, Code: "ok"}}
	return b
}
func (b *memoryBackend) Get(ctx context.Context) (View, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.view, ctx.Err()
}
func (b *memoryBackend) Publish(ctx context.Context, stamp Stamp, write func() error) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if stamp != b.view.Stamp {
		return ProtocolError{wire.CodeConsentChanged}
	}
	return write()
}
func (b *memoryBackend) Changes(context.Context) <-chan struct{} { return b.changed }
func (b *memoryBackend) Grant(ctx context.Context, p wire.ConsentGrantParams) (GrantResult, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if r, ok := b.receipts[p.RequestID]; ok {
		return r, nil
	}
	if p.ExpectStoreEpoch != b.view.Stamp.Epoch || p.ExpectGeneration != b.view.Stamp.Generation {
		return GrantResult{}, ProtocolError{wire.CodeConsentStale}
	}
	b.view.Stamp.Generation++
	gen := b.view.Stamp.Generation
	b.view.Projection.ConsentGeneration = gen
	r := GrantResult{Stamp: b.view.Stamp, Receipt: wire.ConsentReceipt{RequestID: p.RequestID, Committed: true, CommittedGeneration: &gen, Code: wire.ReceiptOK}}
	if len(p.Deny) > 0 || len(p.Forget) > 0 {
		b.view.Consent = wire.ConsentFacts{Scopes: []wire.ConsentScope{{Scope: testScope, Tool: "claude", Route: rows.RouteSavedLoginAPI, State: wire.ConsentDenied}}}
		b.view.Projection = rows.Build(rows.Input{Now: time.Now(), ConsentGeneration: gen, ReadersOff: true})
		b.view.Health = wire.Health{State: wire.HealthDegraded, Code: "revoked"}
	}
	for scope, choice := range p.Keychain {
		if choice == wire.KeychainAllow {
			r.Credentials = append(r.Credentials, CredentialNeed{Provider: "claude", Scope: scope, Interactive: true})
		}
	}
	b.receipts[p.RequestID] = r
	select {
	case b.changed <- struct{}{}:
	default:
	}
	select {
	case b.committed <- struct{}{}:
	default:
	}
	return r, nil
}
func (b *memoryBackend) AcceptCredential(ctx context.Context, stamp Stamp, need CredentialNeed, result wire.CredentialResult) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	if stamp != b.view.Stamp {
		return ProtocolError{wire.CodeCredentialRejected}
	}
	if result.Outcome == wire.OutcomeOK {
		b.accepted++
	}
	return ctx.Err()
}

type pipeClient struct {
	validate func(map[string]json.RawMessage) error
	pending  []map[string]json.RawMessage
	in       *os.File
	out      *os.File
	messages chan map[string]json.RawMessage
	done     chan struct{}
	server   *Server
}

func startClient(t *testing.T, config Config) *pipeClient {
	t.Helper()
	inR, inW, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	outR, outW, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	server := New(config)
	client := &pipeClient{in: inW, out: outR, done: make(chan struct{}), server: server}
	go func() { _ = server.Serve(context.Background(), inR, outW); close(client.done) }()
	t.Cleanup(func() {
		_ = inW.Close()
		_ = outR.Close()
		select {
		case <-client.done:
		case <-time.After(2 * time.Second):
			t.Error("server did not close on EOF")
		}
	})
	return client
}
func (c *pipeClient) readMessages() {
	c.messages = make(chan map[string]json.RawMessage, 64)
	go func() {
		defer close(c.messages)
		scanner := bufio.NewScanner(c.out)
		scanner.Buffer(make([]byte, 4096), wire.MaxFrameBytes)
		for scanner.Scan() {
			var m map[string]json.RawMessage
			if json.Unmarshal(scanner.Bytes(), &m) == nil {
				c.messages <- m
			}
		}
	}()
}
func (c *pipeClient) send(t *testing.T, id int, method string, p any) {
	t.Helper()
	raw, err := json.Marshal(p)
	if err != nil {
		t.Fatal(err)
	}
	r := wire.Request{JSONRPC: wire.JSONRPC, ID: json.RawMessage(fmt.Sprint(id)), Method: method, Params: raw}
	b, _ := json.Marshal(r)
	if _, err := c.in.Write(append(b, '\n')); err != nil {
		t.Fatal(err)
	}
}
func (c *pipeClient) next(t *testing.T, predicate func(map[string]json.RawMessage) bool) map[string]json.RawMessage {
	t.Helper()
	for i, m := range c.pending {
		if predicate(m) {
			c.pending = append(c.pending[:i], c.pending[i+1:]...)
			return m
		}
	}
	timeout := time.NewTimer(3 * time.Second)
	defer timeout.Stop()
	for {
		select {
		case m, ok := <-c.messages:
			if !ok {
				t.Fatal("server closed before expected response")
			}
			if c.validate != nil {
				if err := c.validate(m); err != nil {
					t.Fatalf("real wire message violates generated schema: %v", err)
				}
			}
			if predicate(m) {
				return m
			}
			c.pending = append(c.pending, m)
		case <-timeout.C:
			t.Fatal("timed out waiting for message")
		}
	}
}
func (c *pipeClient) response(t *testing.T, id int) map[string]json.RawMessage {
	return c.next(t, func(m map[string]json.RawMessage) bool { return string(m["id"]) == fmt.Sprint(id) })
}
func (c *pipeClient) initialize(t *testing.T) {
	t.Helper()
	c.readMessages()
	c.send(t, 1, "initialize", wire.InitializeParams{SessionID: "s-test", ProtocolVersion: wire.ProtocolVersion, AppVersion: "test", Capabilities: []string{"rows", "consent", "credentials", "diagnostics"}})
	m := c.response(t, 1)
	if m["error"] != nil {
		t.Fatalf("initialize: %s", m["error"])
	}
	c.next(t, func(m map[string]json.RawMessage) bool { return string(m["method"]) == `"engine/health"` })
}
func errorOf(t *testing.T, m map[string]json.RawMessage) wire.RPCError {
	t.Helper()
	var e wire.RPCError
	if err := json.Unmarshal(m["error"], &e); err != nil {
		t.Fatal(err)
	}
	return e
}
func deny(id string, gen uint64) wire.ConsentGrantParams {
	return wire.ConsentGrantParams{RequestID: id, ExpectStoreEpoch: "epoch-test", ExpectGeneration: gen, TextVersion: 2, Allow: []string{}, Deny: []string{testScope}}
}

func TestHandshakeRowsGenerationAndEOF(t *testing.T) {
	backend := newMemoryBackend()
	c := startClient(t, Config{Backend: backend})
	c.readMessages()
	c.send(t, 2, "rows/subscribe", wire.Empty{})
	if e := errorOf(t, c.response(t, 2)); e.Code != wire.CodeNotInitialized {
		t.Fatal(e)
	}
	c.send(t, 1, "initialize", wire.InitializeParams{SessionID: "s-test", ProtocolVersion: "1.7", AppVersion: "test", Capabilities: []string{"rows", "future"}})
	m := c.response(t, 1)
	var init wire.Envelope[wire.InitializeResult]
	_ = json.Unmarshal(m["result"], &init)
	if init.SessionID != "s-test" || init.StoreEpoch != "epoch-test" || len(init.Data.Capabilities) != 4 {
		t.Fatalf("bad handshake: %+v", init)
	}
	c.send(t, 3, "rows/subscribe", wire.Empty{})
	m = c.response(t, 3)
	var first wire.Envelope[wire.RowsSnapshot]
	_ = json.Unmarshal(m["result"], &first)
	if len(first.Data.Projection.Rows) != 1 || first.Data.Projection.Rows[0].ID != "claude" {
		t.Fatal("row membership changed")
	}
	c.send(t, 4, "consent/grant", deny("r-revoke", 1))
	m = c.response(t, 4)
	var receipt wire.Envelope[wire.ConsentReceipt]
	_ = json.Unmarshal(m["result"], &receipt)
	if !receipt.Data.Committed || receipt.ConsentGeneration != 2 {
		t.Fatal("commit receipt missing")
	}
	m = c.next(t, func(m map[string]json.RawMessage) bool { return string(m["method"]) == `"rows/changed"` })
	var changed wire.Envelope[wire.RowsSnapshot]
	_ = json.Unmarshal(m["params"], &changed)
	if changed.ConsentGeneration != 2 || changed.Data.Sequence <= first.Data.Sequence || len(changed.Data.Projection.Rows) != 0 || changed.Data.Projection.RowsSummary.State != rows.SummaryStateReadersOff {
		t.Fatal("revoke did not replace rows")
	}
	c.send(t, 5, "shutdown", wire.Empty{})
	if m := c.response(t, 5); m["error"] != nil {
		t.Fatal("shutdown failed")
	}
	select {
	case <-c.done:
	case <-time.After(time.Second):
		t.Fatal("shutdown did not exit")
	}
}

func TestProtocolMismatchAndMalformedFramesExit(t *testing.T) {
	t.Run("major mismatch", func(t *testing.T) {
		c := startClient(t, Config{})
		c.readMessages()
		c.send(t, 1, "initialize", wire.InitializeParams{SessionID: "s", ProtocolVersion: "2.0", AppVersion: "test", Capabilities: []string{}})
		if e := errorOf(t, c.response(t, 1)); e.Code != wire.CodeProtocolMismatch {
			t.Fatal(e)
		}
		select {
		case <-c.done:
		case <-time.After(time.Second):
			t.Fatal("mismatch session stayed alive")
		}
	})
	for _, frame := range []string{"[]\n", "{\"jsonrpc\":\"2.0\",\"method\":\"a\",\"method\":\"b\"}\n", string([]byte{0xff, '\n'})} {
		t.Run("invalid frame", func(t *testing.T) {
			c := startClient(t, Config{})
			_, _ = io.WriteString(c.in, frame)
			select {
			case <-c.done:
			case <-time.After(time.Second):
				t.Fatal("bad frame did not end session")
			}
		})
	}
	t.Run("unterminated oversized", func(t *testing.T) {
		c := startClient(t, Config{})
		writeDone := make(chan struct{})
		go func() { defer close(writeDone); _, _ = io.WriteString(c.in, strings.Repeat("x", wire.MaxFrameBytes+1)) }()
		select {
		case <-c.done:
		case <-time.After(time.Second):
			t.Fatal("unterminated frame waited for newline")
		}
		<-writeDone
	})
}

func TestQueryCapsCancellationAndControlPriority(t *testing.T) {
	backend := newMemoryBackend()
	started := make(chan struct{}, 16)
	wait := func(ctx context.Context, _ json.RawMessage, stamp Stamp) (Reply, error) {
		started <- struct{}{}
		<-ctx.Done()
		return Reply{}, ctx.Err()
	}
	c := startClient(t, Config{Backend: backend, Handlers: map[string]Handler{"history/query": {Query: true, Private: true, Handle: wait}}, RequestTimeout: time.Second})
	c.initialize(t)
	c.send(t, 10, "history/query", wire.Empty{})
	c.send(t, 11, "history/query", wire.Empty{})
	<-started
	<-started
	c.send(t, 12, "history/query", wire.Empty{})
	if e := errorOf(t, c.response(t, 12)); e.Code != wire.CodeBusy {
		t.Fatal(e)
	}
	c.send(t, 13, "consent/grant", deny("tighten", 1))
	if m := c.response(t, 13); m["error"] != nil {
		t.Fatal("revoke blocked behind queries")
	}
	cancel := wire.Request{JSONRPC: wire.JSONRPC, Method: "$/cancel", Params: json.RawMessage(`{"id":10}`)}
	b, _ := json.Marshal(cancel)
	_, _ = c.in.Write(append(b, '\n'))
	if e := errorOf(t, c.response(t, 10)); e.Code != wire.CodeCanceled {
		t.Fatal(e)
	}
}

func TestLateCredentialRejectedAndNoTokenExposure(t *testing.T) {
	backend := newMemoryBackend()
	c := startClient(t, Config{Backend: backend})
	c.initialize(t)
	if _, err := c.server.RequestCredential(CredentialNeed{Provider: "claude", Scope: testScope, Interactive: true}); err == nil {
		t.Fatal("background entry admitted foreground prompt")
	}
	op, err := c.server.RequestCredential(CredentialNeed{Provider: "claude", Scope: testScope})
	if err != nil {
		t.Fatal(err)
	}
	m := c.next(t, func(m map[string]json.RawMessage) bool { return string(m["method"]) == `"credentials/request"` })
	var request wire.Envelope[wire.CredentialRequest]
	_ = json.Unmarshal(m["params"], &request)
	if request.Data.Interactive || request.Data.OperationID != op {
		t.Fatal("background operation may prompt")
	}
	if _, err := c.server.RequestCredential(CredentialNeed{Provider: "claude", Scope: testScope}); err == nil {
		t.Fatal("per-provider credential cap ignored")
	}
	c.send(t, 5, "consent/grant", deny("revoke-credential", 1))
	c.response(t, 5)
	token := "token-canary-must-never-be-echoed"
	c.send(t, 6, "credentials/result", wire.CredentialResult{OperationID: op, Outcome: wire.OutcomeOK, AccessToken: &token})
	m = c.response(t, 6)
	if e := errorOf(t, m); e.Code != wire.CodeCredentialRejected {
		t.Fatal(e)
	}
	b, _ := json.Marshal(m)
	if strings.Contains(string(b), token) {
		t.Fatal("token echoed")
	}
	backend.mu.Lock()
	accepted := backend.accepted
	backend.mu.Unlock()
	if accepted != 0 {
		t.Fatal("late credential used")
	}
	c.send(t, 7, "diagnostics/get", wire.Empty{})
	b, _ = json.Marshal(c.response(t, 7))
	if strings.Contains(string(b), token) {
		t.Fatal("token in diagnostics")
	}
}

func TestSlowReaderEndsSessionAndReceiptReplays(t *testing.T) {
	backend := newMemoryBackend()
	completed := make(chan struct{}, 2)
	handler := func(_ context.Context, _ json.RawMessage, stamp Stamp) (Reply, error) {
		completed <- struct{}{}
		return Reply{Stamp: stamp, Scopes: []string{testScope}, Data: wire.HistoryPage{Items: []wire.HistoryItem{{At: time.Now(), Model: ptrString(strings.Repeat("synthetic", 32768))}}}}, nil
	}
	c := startClient(t, Config{Backend: backend, Handlers: map[string]Handler{"history/query": {Query: true, Private: true, Handle: handler}}, WriteTimeout: wire.WriteTimeout})
	// Read just the handshake and health, then stop draining the actual OS pipe.
	reader := bufio.NewReader(c.out)
	c.send(t, 1, "initialize", wire.InitializeParams{SessionID: "s-slow", ProtocolVersion: "1.0", AppVersion: "test", Capabilities: []string{"rows"}})
	for i := 0; i < 2; i++ {
		if _, err := reader.ReadBytes('\n'); err != nil {
			t.Fatal(err)
		}
	}
	c.send(t, 10, "history/query", wire.Empty{})
	c.send(t, 11, "history/query", wire.Empty{})
	<-completed
	<-completed
	// Establish that a large data frame has started before committing revoke;
	// otherwise the generation fence may discard both frames before any write.
	if _, err := reader.ReadByte(); err != nil {
		t.Fatal(err)
	}
	c.send(t, 12, "consent/grant", deny("lost-receipt", 1))
	select {
	case <-backend.committed:
	case <-time.After(time.Second):
		t.Fatal("revoke stalled behind data writer")
	}
	select {
	case <-c.done:
	case <-time.After(wire.WriteTimeout + 2*time.Second):
		t.Fatal("stuck writer exceeded bounded timeout")
	}
	backend.mu.Lock()
	health := backend.view.Health
	backend.mu.Unlock()
	if health.State != wire.HealthDegraded {
		t.Fatal("health change lost")
	}
	replay := startClient(t, Config{Backend: backend})
	replay.initialize(t)
	replay.send(t, 3, "consent/grant", deny("lost-receipt", 1))
	m := replay.response(t, 3)
	var result wire.Envelope[wire.ConsentReceipt]
	_ = json.Unmarshal(m["result"], &result)
	if !result.Data.Committed || *result.Data.CommittedGeneration != 2 {
		t.Fatal("receipt did not replay across session")
	}
}
func ptrString(s string) *string { return &s }

func TestSupervisionContractAndEnvironment(t *testing.T) {
	now := time.Now()
	crashes := []time.Time{}
	for i, want := range []time.Duration{time.Second, 2 * time.Second, 4 * time.Second, 8 * time.Second} {
		crashes = append(crashes, now.Add(-time.Duration(i)*time.Second))
		delay, ok := RestartDelay(crashes, now, false)
		if !ok || delay != want {
			t.Fatalf("restart %d = %v %v", i, delay, ok)
		}
	}
	crashes = append(crashes, now)
	if _, ok := RestartDelay(crashes, now, false); ok {
		t.Fatal("fifth crash did not stop")
	}
	if _, ok := RestartDelay(nil, now, true); ok {
		t.Fatal("protocol mismatch restarted")
	}
	filtered := ChildEnvironment([]string{"HOME=/synthetic", "PATH=/bin", "SECRET=canary", "KIMI_AUTH_TOKEN=canary", "KIMI_CODE_API_KEY=synthetic"})
	if strings.Contains(strings.Join(filtered, "\n"), "canary") || len(filtered) != 3 {
		t.Fatal("child environment not allow-listed")
	}
}

func TestErrorsAreSanitized(t *testing.T) {
	c := startClient(t, Config{Backend: newMemoryBackend(), Handlers: map[string]Handler{"test/error": {Handle: func(context.Context, json.RawMessage, Stamp) (Reply, error) {
		return Reply{}, errors.New("provider token-canary /private/user")
	}}}})
	c.initialize(t)
	c.send(t, 2, "test/error", wire.Empty{})
	m := c.response(t, 2)
	b, _ := json.Marshal(m)
	if strings.Contains(string(b), "canary") || strings.Contains(string(b), "/private") {
		t.Fatal("raw implementation error exported")
	}
	if errorOf(t, m).Code != wire.CodeInternal {
		t.Fatal("unexpected error classification")
	}
}

func TestRequestCapStillAdmitsTightening(t *testing.T) {
	backend := newMemoryBackend()
	started := make(chan struct{}, wire.MaxRequests)
	c := startClient(t, Config{Backend: backend, RequestTimeout: 5 * time.Second, Handlers: map[string]Handler{"test/wait": {Handle: func(ctx context.Context, _ json.RawMessage, _ Stamp) (Reply, error) {
		started <- struct{}{}
		<-ctx.Done()
		return Reply{}, ctx.Err()
	}}}})
	c.initialize(t)
	for i := 0; i < wire.MaxRequests; i++ {
		c.send(t, 20+i, "test/wait", wire.Empty{})
	}
	for i := 0; i < wire.MaxRequests; i++ {
		<-started
	}
	c.send(t, 50, "test/wait", wire.Empty{})
	if errorOf(t, c.response(t, 50)).Code != wire.CodeBusy {
		t.Fatal("request cap ignored")
	}
	c.send(t, 51, "consent/grant", deny("revoke-at-cap", 1))
	if m := c.response(t, 51); m["error"] != nil {
		t.Fatal("tightening was busy at normal request cap")
	}
	_, _ = io.WriteString(c.in, "{\"jsonrpc\":\"2.0\",\"method\":\"$/cancel\",\"params\":{\"id\":20}}\n")
	if errorOf(t, c.response(t, 20)).Code != wire.CodeCanceled {
		t.Fatal("cancel did not produce terminal response")
	}
}

func TestLateQueryAndFailureDoNotChangeRows(t *testing.T) {
	backend := newMemoryBackend()
	started := make(chan struct{})
	release := make(chan struct{})
	c := startClient(t, Config{Backend: backend, Handlers: map[string]Handler{
		"history/query": {Query: true, Private: true, Handle: func(ctx context.Context, _ json.RawMessage, stamp Stamp) (Reply, error) {
			close(started)
			select {
			case <-release:
			case <-ctx.Done():
				return Reply{}, ctx.Err()
			}
			return Reply{Stamp: stamp, Scopes: []string{testScope}, Data: wire.HistoryPage{Items: []wire.HistoryItem{{At: time.Now(), Model: ptrString("private-query-canary")}}}}, nil
		}},
		"cockpit/query": {Query: true, Private: true, Handle: func(context.Context, json.RawMessage, Stamp) (Reply, error) {
			return Reply{}, ProtocolError{wire.CodeHistoryUnavailable}
		}},
	}})
	c.initialize(t)
	c.send(t, 2, "rows/subscribe", wire.Empty{})
	c.response(t, 2)
	c.send(t, 3, "history/query", wire.Empty{})
	<-started
	c.send(t, 4, "consent/grant", deny("revoke-query", 1))
	c.response(t, 4)
	close(release)
	response := c.response(t, 3)
	b, _ := json.Marshal(response)
	if errorOf(t, response).Code != wire.CodeConsentChanged || strings.Contains(string(b), "private-query-canary") {
		t.Fatal("late private query escaped fence")
	}
	c.send(t, 5, "cockpit/query", wire.Empty{})
	if errorOf(t, c.response(t, 5)).Code != wire.CodeHistoryUnavailable {
		t.Fatal("query error classification lost")
	}
	c.send(t, 6, "rows/subscribe", wire.Empty{})
	var snapshot wire.Envelope[wire.RowsSnapshot]
	response = c.response(t, 6)
	_ = json.Unmarshal(response["result"], &snapshot)
	if snapshot.ConsentGeneration != 2 || len(snapshot.Data.Projection.Rows) != 0 {
		t.Fatal("query failure mutated rows")
	}
}

type committedErrorBackend struct{ *memoryBackend }

func (b committedErrorBackend) Grant(ctx context.Context, p wire.ConsentGrantParams) (GrantResult, error) {
	r, err := b.memoryBackend.Grant(ctx, p)
	if err != nil {
		return r, err
	}
	return r, context.Canceled
}
func TestCommittedReceiptSurvivesBackendCancellation(t *testing.T) {
	c := startClient(t, Config{Backend: committedErrorBackend{newMemoryBackend()}})
	c.initialize(t)
	c.send(t, 2, "consent/grant", deny("commit-before-cancel", 1))
	m := c.response(t, 2)
	if m["error"] != nil {
		t.Fatal("committed change returned error")
	}
	var result wire.Envelope[wire.ConsentReceipt]
	_ = json.Unmarshal(m["result"], &result)
	if !result.Data.Committed || result.Data.CommittedGeneration == nil || *result.Data.CommittedGeneration != 2 {
		t.Fatal("committed generation lost")
	}
}

func TestMatchingCredentialIsConsumedOnce(t *testing.T) {
	backend := newMemoryBackend()
	c := startClient(t, Config{Backend: backend})
	c.initialize(t)
	op, err := c.server.RequestCredential(CredentialNeed{Provider: "claude", Scope: testScope})
	if err != nil {
		t.Fatal(err)
	}
	c.next(t, func(m map[string]json.RawMessage) bool { return string(m["method"]) == `"credentials/request"` })
	token := "synthetic-valid-access-token"
	result := wire.CredentialResult{OperationID: op, Outcome: wire.OutcomeOK, AccessToken: &token}
	c.send(t, 2, "credentials/result", result)
	m := c.response(t, 2)
	if m["error"] != nil {
		t.Fatal("matching operation rejected")
	}
	b, _ := json.Marshal(m)
	if strings.Contains(string(b), token) {
		t.Fatal("token in acknowledgment")
	}
	c.send(t, 3, "credentials/result", result)
	if errorOf(t, c.response(t, 3)).Code != wire.CodeCredentialRejected {
		t.Fatal("credential operation reused")
	}
	backend.mu.Lock()
	accepted := backend.accepted
	backend.mu.Unlock()
	if accepted != 1 {
		t.Fatal("credential used more than once")
	}
}

func TestStringCancellationUsesDecodedID(t *testing.T) {
	started := make(chan struct{})
	c := startClient(t, Config{Backend: newMemoryBackend(), RequestTimeout: 5 * time.Second, Handlers: map[string]Handler{"test/wait": {Handle: func(ctx context.Context, _ json.RawMessage, _ Stamp) (Reply, error) {
		close(started)
		<-ctx.Done()
		return Reply{}, ctx.Err()
	}}}})
	c.initialize(t)
	_, _ = io.WriteString(c.in, "{\"jsonrpc\":\"2.0\",\"id\":\"thread\",\"method\":\"test/wait\",\"params\":{}}\n")
	<-started
	_, _ = io.WriteString(c.in, "{\"jsonrpc\":\"2.0\",\"method\":\"$/cancel\",\"params\":{\"id\":\"\\u0074hread\"}}\n")
	response := c.next(t, func(m map[string]json.RawMessage) bool { return string(m["id"]) == `"thread"` })
	if errorOf(t, response).Code != wire.CodeCanceled {
		t.Fatal("equivalent string ID was not canceled")
	}
}

func TestRequestDeadlineProducesTerminalResponse(t *testing.T) {
	c := startClient(t, Config{Backend: newMemoryBackend(), RequestTimeout: 20 * time.Millisecond, Handlers: map[string]Handler{"test/wait": {Handle: func(ctx context.Context, _ json.RawMessage, _ Stamp) (Reply, error) {
		<-ctx.Done()
		return Reply{}, ctx.Err()
	}}}})
	c.initialize(t)
	c.send(t, 2, "test/wait", wire.Empty{})
	if errorOf(t, c.response(t, 2)).Code != wire.CodeCanceled {
		t.Fatal("deadline left request without terminal response")
	}
}
