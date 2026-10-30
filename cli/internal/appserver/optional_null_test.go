// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"fmt"
	"reflect"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
)

func requireNullPolicy[T any](t *testing.T, policy wire.NullPolicy, names ...string) {
	t.Helper()
	for _, name := range names {
		field, ok := reflect.TypeFor[T]().FieldByName(name)
		if !ok || field.Tag.Get("null") != string(policy) {
			t.Fatalf("%s.%s must declare the consumer's %s rule", reflect.TypeFor[T]().Name(), name, policy)
		}
	}
}

func TestRequestNullPoliciesAtProductionDecoderAndDispatch(t *testing.T) {
	requireNullPolicy[wire.Request](t, wire.NullForbidden, "ID")
	requireNullPolicy[wire.Request](t, wire.NullDistinct, "Params")
	for _, tc := range []struct {
		raw    string
		reject bool
	}{
		{`{"jsonrpc":"2.0","method":"diagnostics/get"}`, false},
		{`{"jsonrpc":"2.0","id":null,"method":"diagnostics/get"}`, true},
	} {
		_, err := decodeRequest([]byte(tc.raw))
		if (err != nil) != tc.reject {
			t.Fatalf("ID declaration disagrees with decoder: %v", err)
		}
	}
	c := startClient(t, Config{Backend: newMemoryBackend()})
	c.initialize(t)
	// Raw params retain presence at decoding, even when a method rejects null.
	for i, params := range []json.RawMessage{nil, json.RawMessage(`null`)} {
		id := i + 2
		raw, err := json.Marshal(wire.Request{JSONRPC: wire.JSONRPC, ID: json.RawMessage(fmt.Sprint(id)), Method: "diagnostics/get", Params: params})
		if err != nil {
			t.Fatal(err)
		}
		request, err := decodeRequest(raw)
		if err != nil || string(request.Params) != string(params) {
			t.Fatal("params presence lost at decoding")
		}
		if _, err := c.in.Write(append(raw, '\n')); err != nil {
			t.Fatal(err)
		}
		reply := c.response(t, id)
		if i == 0 && reply["error"] != nil {
			t.Fatal("omitted params rejected by empty-params method")
		}
		if i == 1 && errorOf(t, reply).Code != wire.CodeInvalidParams {
			t.Fatal("explicit null params accepted by empty-params method")
		}
	}
}

func TestConsentOptionalNullsThroughGrantHandler(t *testing.T) {
	requireNullPolicy[wire.ConsentGrantParams](t, wire.NullCoalesced, "Forget", "Keychain")
	for _, extra := range []string{"", `,"forget":null`, `,"keychain":null`, `,"forget":null,"keychain":null`} {
		t.Run(extra, func(t *testing.T) {
			c := startClient(t, Config{Backend: newMemoryBackend()})
			c.initialize(t)
			c.send(t, 2, "consent/grant", json.RawMessage(`{"requestId":"null-audit","expectStoreEpoch":"epoch-test","expectGeneration":1,"consentTextVersion":2,"allow":[],"deny":[]`+extra+`}`))
			var result wire.Envelope[wire.ConsentReceipt]
			m := c.response(t, 2)
			if m["error"] != nil || json.Unmarshal(m["result"], &result) != nil || !result.Data.Committed {
				t.Fatal("optional null changed grant result")
			}
		})
	}
}

func TestCredentialSuccessOptionalNullsThroughHandler(t *testing.T) {
	requireNullPolicy[wire.CredentialResult](t, wire.NullForbidden, "AccessToken")
	requireNullPolicy[wire.CredentialResult](t, wire.NullCoalesced, "ExpiresAt")
	for _, extra := range []string{"", `,"expiresAt":null`} {
		c := startClient(t, Config{Backend: newMemoryBackend()})
		c.initialize(t)
		op, err := c.server.RequestCredential(CredentialNeed{Provider: "claude", Scope: testScope})
		if err != nil {
			t.Fatal(err)
		}
		c.next(t, func(m map[string]json.RawMessage) bool { return string(m["method"]) == `"credentials/request"` })
		operation, _ := json.Marshal(op)
		for i, token := range []string{"", `,"accessToken":null`} {
			c.send(t, i+2, "credentials/result", json.RawMessage(`{"operationId":`+string(operation)+`,"outcome":"ok"`+token+extra+`}`))
			if errorOf(t, c.response(t, i+2)).Code != wire.CodeCredentialRejected {
				t.Fatal("missing/null token must both fail authorization")
			}
		}
		c.send(t, 4, "credentials/result", json.RawMessage(`{"operationId":`+string(operation)+`,"outcome":"ok","accessToken":"synthetic-null-audit"`+extra+`}`))
		if c.response(t, 4)["error"] != nil {
			t.Fatal("missing/null success expiry changed result")
		}
	}
}

func TestRefreshOptionalNullThroughHandler(t *testing.T) {
	requireNullPolicy[wire.RefreshRequestParams](t, wire.NullCoalesced, "Scopes")
	backend, paths, _ := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Offline: true})
	defer s.Close()
	for _, raw := range []string{`{}`, `{"scopes":null}`} {
		reply, err := s.Handler().Handle(context.Background(), json.RawMessage(raw), backend.view.Stamp)
		if err != nil {
			t.Fatal(err)
		}
		items := reply.Data.([]wire.RefreshScheduled)
		if len(items) != 1 || items[0].Scope != consent.ScopeCodexRuntimeUsage || items[0].DisabledReason == nil || *items[0].DisabledReason != wire.RefreshOffline {
			t.Fatal("missing/null scopes did not select admitted defaults")
		}
	}
}

func TestPluginOptionalNullThroughHandler(t *testing.T) {
	requireNullPolicy[wire.PluginInstallParams](t, wire.NullCoalesced, "Offline")
	handler := PluginInstallHandler(true, false)
	var previous any
	for _, raw := range []string{`{"tool":"codex"}`, `{"tool":"codex","offline":null}`} {
		reply, err := handler.Handle(context.Background(), json.RawMessage(raw), Stamp{})
		if err != nil {
			t.Fatal(err)
		}
		if previous != nil && !reflect.DeepEqual(previous, reply.Data) {
			t.Fatal("missing/null offline changed installation plan")
		}
		previous = reply.Data
	}
}

func TestCredentialNonSuccessNullPresenceMatchesSwiftAndSchema(t *testing.T) {
	for _, outcome := range []wire.CredentialOutcome{wire.OutcomeCanceled, wire.OutcomeDenied, wire.OutcomeNotFound, wire.OutcomeInteractionRequired, wire.OutcomeTimeout, wire.OutcomeError} {
		for _, field := range []string{"accessToken", "expiresAt"} {
			t.Run(string(outcome)+"/"+field, func(t *testing.T) {
				c := startClient(t, Config{Backend: newMemoryBackend()})
				c.initialize(t)
				op, err := c.server.RequestCredential(CredentialNeed{Provider: "claude", Scope: testScope})
				if err != nil {
					t.Fatal(err)
				}
				c.next(t, func(m map[string]json.RawMessage) bool { return string(m["method"]) == `"credentials/request"` })
				p := map[string]any{"operationId": op, "outcome": outcome, field: nil}
				c.send(t, 2, "credentials/result", p)
				m := c.response(t, 2)
				if m["error"] == nil || errorOf(t, m).Code != wire.CodeCredentialRejected {
					t.Fatal("non-success null key accepted contrary to Swift/schema presence rule")
				}
				delete(p, field)
				c.send(t, 3, "credentials/result", p)
				if c.response(t, 3)["error"] != nil {
					t.Fatal("omitted key should succeed without null rejection consuming operation")
				}
			})
		}
	}
}
