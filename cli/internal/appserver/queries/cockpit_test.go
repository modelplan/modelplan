// SPDX-License-Identifier: MIT
package queries

import (
	"context"
	"encoding/json"
	"errors"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appcontract"
	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

type cockpitState struct {
	historyState
	scopes []string
}

func (s *cockpitState) Get(ctx context.Context) (appserver.View, error) {
	v, e := s.historyState.Get(ctx)
	v.Scopes = append([]string{}, s.scopes...)
	return v, e
}

type cockpitFixture struct {
	admission             CockpitAdmission
	data                  wire.CockpitData
	reads                 int
	afterAdmit, afterRead func()
	err                   error
}

func (f *cockpitFixture) AdmitCockpit(context.Context, appserver.Stamp) (CockpitAdmission, error) {
	if f.afterAdmit != nil {
		f.afterAdmit()
	}
	return f.admission, f.err
}
func (f *cockpitFixture) ReadCockpit(context.Context, CockpitAdmission) (wire.CockpitData, error) {
	f.reads++
	if f.afterRead != nil {
		f.afterRead()
	}
	return f.data, nil
}
func setupCockpit(t *testing.T) (appserver.Handler, *cockpitState, *cockpitFixture) {
	t.Helper()
	stamp := appserver.Stamp{Epoch: "epoch-one", Generation: 41}
	state := &cockpitState{historyState: historyState{stamp: stamp}, scopes: []string{"cursor.local_history", "gemini.local_history"}}
	fixture := &cockpitFixture{admission: CockpitAdmission{Stamp: stamp, Scopes: append([]string{}, state.scopes...)}, data: wire.CockpitData{Projection: wire.Project(rows.Build(rows.Input{})), Subscriptions: []wire.CockpitSubscription{}}}
	h, err := CockpitHandler(CockpitConfig{State: state, Source: fixture})
	if err != nil {
		t.Fatal(err)
	}
	return h, state, fixture
}
func TestCockpitFenceAndAdmission(t *testing.T) {
	for _, tc := range []string{"late-revoke", "late-new-epoch", "stale-admission", "missing-scope", "duplicate-scope", "empty-scope", "denied"} {
		t.Run(tc, func(t *testing.T) {
			h, state, source := setupCockpit(t)
			expected := wire.CodeConsentRejected
			switch tc {
			case "late-revoke":
				source.afterRead = func() { state.set(appserver.Stamp{Epoch: "epoch-one", Generation: 42}) }
				expected = wire.CodeConsentChanged
			case "late-new-epoch":
				source.afterRead = func() { state.set(appserver.Stamp{Epoch: "epoch-two", Generation: 41}) }
				expected = wire.CodeConsentChanged
			case "stale-admission":
				source.admission.Stamp.Generation--
				expected = wire.CodeConsentChanged
			case "missing-scope":
				source.admission.Scopes = source.admission.Scopes[:1]
			case "duplicate-scope":
				source.admission.Scopes = append(source.admission.Scopes, source.admission.Scopes[0])
			case "empty-scope":
				source.admission.Scopes = nil
			case "denied":
				source.err = protocol(wire.CodeConsentRejected)
			}
			reply, err := h.Handle(context.Background(), json.RawMessage(`{}`), appserver.Stamp{Epoch: "epoch-one", Generation: 41})
			expectCode(t, reply, err, expected)
			if tc != "late-revoke" && tc != "late-new-epoch" && source.reads != 0 {
				t.Fatal("unadmitted cockpit read")
			}
		})
	}
}
func TestCockpitStrictInputCancellationAndWire(t *testing.T) {
	for _, raw := range []string{`null`, `[]`, `{"tool":"cursor"}`, `{"path":"private-canary"}`, `{} {}`} {
		h, state, source := setupCockpit(t)
		reply, err := h.Handle(context.Background(), json.RawMessage(raw), state.stamp)
		expectCode(t, reply, err, wire.CodeInvalidParams)
		if source.reads != 0 {
			t.Fatal("invalid input reached cockpit")
		}
	}
	h, state, source := setupCockpit(t)
	ctx, cancel := context.WithCancel(context.Background())
	source.afterAdmit = cancel
	reply, err := h.Handle(ctx, json.RawMessage(`{}`), state.stamp)
	if reply.Data != nil || !errors.Is(err, context.Canceled) || source.reads != 0 {
		t.Fatal("cancelled cockpit read")
	}
	h, state, _ = setupCockpit(t)
	reply, err = h.Handle(context.Background(), json.RawMessage(`{}`), state.stamp)
	if err != nil {
		t.Fatal(err)
	}
	if !h.Query || !h.Private || h.Capability != "cockpit" || len(reply.Scopes) != 2 {
		t.Fatal("missing sensitive query context")
	}
	encoded, err := json.Marshal(wire.Success[any]{JSONRPC: wire.JSONRPC, ID: wire.ID(`1`), Result: wire.Envelope[any]{SessionID: "synthetic", StoreEpoch: reply.Stamp.Epoch, ConsentGeneration: reply.Stamp.Generation, Scopes: reply.Scopes, Data: reply.Data}})
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
	var decoded wire.Success[wire.CockpitData]
	if json.Unmarshal(encoded, &decoded) != nil || decoded.Result.Data.Subscriptions == nil {
		t.Fatal("typed cockpit consumer failed")
	}
}
