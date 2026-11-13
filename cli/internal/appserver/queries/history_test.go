// SPDX-License-Identifier: MIT
package queries

import (
	"context"
	"encoding/json"
	"errors"
	"path/filepath"
	"reflect"
	"runtime"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appcontract"
	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

type historyState struct {
	appserver.UnavailableBackend
	mu    sync.Mutex
	stamp appserver.Stamp
}

func (s *historyState) Get(ctx context.Context) (appserver.View, error) {
	if err := ctx.Err(); err != nil {
		return appserver.View{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return appserver.View{Stamp: s.stamp}, nil
}
func (s *historyState) set(stamp appserver.Stamp) { s.mu.Lock(); defer s.mu.Unlock(); s.stamp = stamp }

type historyFixture struct {
	admission  HistoryAdmission
	read       int
	positions  []string
	params     []wire.HistoryQueryParams
	batch      HistoryBatch
	deny       bool
	afterRead  func()
	afterAdmit func()
}

func (f *historyFixture) AdmitHistory(_ context.Context, _ appserver.Stamp, _ wire.HistoryQueryParams) (HistoryAdmission, error) {
	if f.deny {
		return HistoryAdmission{}, protocol(wire.CodeConsentRejected)
	}
	if f.afterAdmit != nil {
		f.afterAdmit()
	}
	return f.admission, nil
}
func (f *historyFixture) ReadHistory(_ context.Context, _ HistoryAdmission, p wire.HistoryQueryParams, position string) (HistoryBatch, error) {
	f.read++
	f.positions = append(f.positions, position)
	f.params = append(f.params, p)
	if f.afterRead != nil {
		f.afterRead()
	}
	return f.batch, nil
}

type sessionKey struct{}

func setupHistory(t *testing.T) (appserver.Handler, *historyState, *historyFixture, context.Context, wire.HistoryQueryParams) {
	t.Helper()
	stamp := appserver.Stamp{Epoch: "epoch-one", Generation: 41}
	state := &historyState{stamp: stamp}
	source := &historyFixture{admission: HistoryAdmission{Stamp: stamp, Scopes: []string{"claude.local_history"}, AccountLocator: "0123456789abcdef"}, batch: HistoryBatch{Items: []wire.HistoryItem{{At: time.Date(2026, 10, 29, 10, 0, 0, 0, time.UTC)}}, Next: "position-two"}}
	handler, err := HistoryHandler(HistoryConfig{State: state, Source: source, Session: func(ctx context.Context) string { session, _ := ctx.Value(sessionKey{}).(string); return session }})
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.WithValue(context.Background(), sessionKey{}, "session-one")
	p := wire.HistoryQueryParams{Tool: "claude", Kind: wire.HistoryTokens, Ref: source.admission.AccountLocator, Limit: 2}
	return handler, state, source, ctx, p
}
func query(t *testing.T, h appserver.Handler, ctx context.Context, p wire.HistoryQueryParams, stamp appserver.Stamp) (appserver.Reply, error) {
	t.Helper()
	raw, err := json.Marshal(p)
	if err != nil {
		t.Fatal(err)
	}
	return h.Handle(ctx, raw, stamp)
}
func expectCode(t *testing.T, reply appserver.Reply, err error, code int) {
	t.Helper()
	var p appserver.ProtocolError
	if reply.Data != nil || !errors.As(err, &p) || p.Code != code {
		t.Fatalf("got data %T, error %v; want %d", reply.Data, err, code)
	}
}

// Qualified consumer: actual handler data is encoded as a wire success, validated
// by the generated schema, and decoded through the concrete HistoryPage DTO.
func TestHistoryQualifiedWireConsumerAndCursorContinuation(t *testing.T) {
	h, state, source, ctx, p := setupHistory(t)
	if !h.Private || !h.Query || h.Capability != "history" {
		t.Fatal("missing private-query admission")
	}
	reply, err := query(t, h, ctx, p, state.stamp)
	if err != nil {
		t.Fatal(err)
	}
	message := wire.Success[any]{JSONRPC: wire.JSONRPC, ID: wire.ID(`1`), Result: wire.Envelope[any]{SessionID: "session-one", StoreEpoch: reply.Stamp.Epoch, ConsentGeneration: reply.Stamp.Generation, Scopes: reply.Scopes, Data: reply.Data}}
	encoded, err := json.Marshal(message)
	if err != nil {
		t.Fatal(err)
	}
	_, file, _, _ := runtime.Caller(0)
	validator, err := appcontract.NewValidator(filepath.Clean(filepath.Join(filepath.Dir(file), "../../../..")))
	if err != nil {
		t.Fatal(err)
	}
	if err := validator.Validate("app-server", encoded); err != nil {
		t.Fatal(err)
	}
	var decoded wire.Success[wire.HistoryPage]
	if err := json.Unmarshal(encoded, &decoded); err != nil {
		t.Fatal(err)
	}
	if len(decoded.Result.Data.Items) != 1 || decoded.Result.Data.Items[0].Model != nil || decoded.Result.Data.NextCursor == "" || decoded.Result.ConsentGeneration != 41 {
		t.Fatal("wire context or nullable fields lost")
	}
	p.Cursor = decoded.Result.Data.NextCursor
	if _, err := query(t, h, ctx, p, state.stamp); err != nil {
		t.Fatal(err)
	}
	if source.read != 2 || source.positions[0] != "" || source.positions[1] != "position-two" || source.params[1].Cursor != "" {
		t.Fatal("storage did not receive authenticated position", source.positions)
	}
}

// Red line: private items never return after a revoke or a store reset during
// reading. The missing post-read fence is the failing example.
func TestHistoryRedLineLateReadAfterConsentChange(t *testing.T) {
	for _, stamp := range []appserver.Stamp{{Epoch: "epoch-one", Generation: 42}, {Epoch: "epoch-two", Generation: 41}} {
		h, state, source, ctx, p := setupHistory(t)
		before := state.stamp
		source.afterRead = func() { state.set(stamp) }
		reply, err := query(t, h, ctx, p, before)
		expectCode(t, reply, err, wire.CodeConsentChanged)
		if source.read != 1 {
			t.Fatal("read fixture did not reach the race seam")
		}
	}
}

func TestHistoryDeniedOrStaleAdmissionNeverReads(t *testing.T) {
	for _, mode := range []string{"denied", "request-stamp", "admission-stamp", "account", "scopes"} {
		t.Run(mode, func(t *testing.T) {
			h, state, source, ctx, p := setupHistory(t)
			stamp := state.stamp
			want := wire.CodeConsentRejected
			switch mode {
			case "denied":
				source.deny = true
			case "request-stamp":
				stamp.Generation++
				want = wire.CodeConsentChanged
			case "admission-stamp":
				source.admission.Stamp.Generation++
				want = wire.CodeConsentChanged
			case "account":
				source.admission.AccountLocator = "fedcba9876543210"
			case "scopes":
				source.admission.Scopes = nil
			}
			reply, err := query(t, h, ctx, p, stamp)
			expectCode(t, reply, err, want)
			if source.read != 0 {
				t.Fatal("private read before valid admission")
			}
		})
	}
}

func TestHistoryForeignOrOldCursorNeverReads(t *testing.T) {
	for _, mode := range []string{"session", "generation", "epoch", "account", "scope", "tool", "kind", "forged"} {
		t.Run(mode, func(t *testing.T) {
			h, state, source, ctx, p := setupHistory(t)
			first, err := query(t, h, ctx, p, state.stamp)
			if err != nil {
				t.Fatal(err)
			}
			p.Cursor = first.Data.(wire.HistoryPage).NextCursor
			switch mode {
			case "session":
				ctx = context.WithValue(ctx, sessionKey{}, "session-two")
			case "generation":
				state.stamp.Generation++
				source.admission.Stamp = state.stamp
			case "epoch":
				state.stamp.Epoch = "epoch-two"
				source.admission.Stamp = state.stamp
			case "account":
				p.Ref = "fedcba9876543210"
				source.admission.AccountLocator = p.Ref
			case "scope":
				source.admission.Scopes = []string{"claude.account_usage.saved_login"}
			case "tool":
				p.Tool = "codex"
			case "kind":
				p.Kind = wire.HistorySessions
			case "forged":
				p.Cursor = "c1.invalid"
			}
			reply, err := query(t, h, ctx, p, state.stamp)
			expectCode(t, reply, err, wire.CodeCursorStale)
			if source.read != 1 {
				t.Fatal("stale cursor reached storage")
			}
		})
	}
}

func TestHistoryParamsBoundsAndCancellation(t *testing.T) {
	for _, raw := range []string{`null`, `[]`, `{}`, `{"tool":"claude","kind":"tokens","limit":0}`, `{"tool":"claude","kind":"tokens","limit":501}`, `{"tool":"../private","kind":"tokens","limit":1}`, `{"tool":"claude","kind":"unknown","limit":1}`, `{"tool":"claude","kind":"tokens","limit":1,"ref":"raw-account"}`, `{"tool":"claude","kind":"tokens","limit":1,"accessToken":"synthetic-canary"}`} {
		h, state, source, ctx, _ := setupHistory(t)
		reply, err := h.Handle(ctx, json.RawMessage(raw), state.stamp)
		expectCode(t, reply, err, wire.CodeInvalidParams)
		if source.read != 0 {
			t.Fatal("invalid params reached storage")
		}
	}
	h, state, source, ctx, p := setupHistory(t)
	canceled, cancel := context.WithCancel(ctx)
	cancel()
	reply, err := query(t, h, canceled, p, state.stamp)
	if reply.Data != nil || !errors.Is(err, context.Canceled) || source.read != 0 {
		t.Fatal("canceled query read private data")
	}
}

func TestHistoryCanceledDuringAdmissionNeverReads(t *testing.T) {
	h, state, source, ctx, p := setupHistory(t)
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	source.afterAdmit = cancel
	reply, err := query(t, h, ctx, p, state.stamp)
	if reply.Data != nil || !errors.Is(err, context.Canceled) || source.read != 0 {
		t.Fatalf("cancellation after admission reached storage: reads=%d, error=%v", source.read, err)
	}
}

func requireHistorySelectorNullPolicy(t *testing.T) {
	t.Helper()
	for _, name := range []string{"Ref", "Cursor"} {
		field, ok := reflect.TypeFor[wire.HistoryQueryParams]().FieldByName(name)
		if !ok || field.Tag.Get("null") != string(wire.NullForbidden) {
			t.Fatalf("%s must declare the handler's forbidden-null rule", name)
		}
	}
}

func TestHistoryRejectsNullOptionalSelectors(t *testing.T) {
	requireHistorySelectorNullPolicy(t)
	for _, selector := range []string{`"ref":null`, `"cursor":null`, `"ref": null,"cursor":null`} {
		t.Run(selector, func(t *testing.T) {
			h, state, source, ctx, _ := setupHistory(t)
			source.afterAdmit = func() { t.Error("null selector reached admission") }
			reply, err := h.Handle(ctx, json.RawMessage(`{"tool":"claude","kind":"tokens","limit":1,`+selector+`}`), state.stamp)
			expectCode(t, reply, err, wire.CodeInvalidParams)
			if source.read != 0 {
				t.Fatal("null selector reached history storage")
			}
		})
	}
}

func TestHistoryAllowsOmittedOptionalSelectors(t *testing.T) {
	requireHistorySelectorNullPolicy(t)
	for _, selectors := range []string{"", `,"ref":"","cursor":""`} {
		h, state, source, ctx, _ := setupHistory(t)
		reply, err := h.Handle(ctx, json.RawMessage(`{"tool":"claude","kind":"tokens","limit":1`+selectors+`}`), state.stamp)
		if err != nil || reply.Data == nil || source.read != 1 {
			t.Fatalf("valid optional selectors rejected: %v", err)
		}
	}
}
