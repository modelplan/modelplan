// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

func credentialRequestOf(t *testing.T, c *pipeClient) wire.Envelope[wire.CredentialRequest] {
	t.Helper()
	m := c.next(t, func(m map[string]json.RawMessage) bool { return string(m["method"]) == `"credentials/request"` })
	var request wire.Envelope[wire.CredentialRequest]
	if err := json.Unmarshal(m["params"], &request); err != nil {
		t.Fatal(err)
	}
	return request
}
func TestWaitableCredentialIsBackgroundAndConsumedOnce(t *testing.T) {
	backend := newMemoryBackend()
	c := startClient(t, Config{Backend: backend})
	c.initialize(t)
	done := make(chan credentialReply, 1)
	go func() {
		r, e := c.server.ReadCredential(context.Background(), CredentialNeed{Provider: "claude", Scope: testScope})
		done <- credentialReply{result: r, err: e}
	}()
	request := credentialRequestOf(t, c)
	if request.Data.Interactive || request.SessionID != "s-test" || request.StoreEpoch != "epoch-test" || request.ConsentGeneration != 1 {
		t.Fatal("operation context lost")
	}
	token := "U7-waitable-token-canary"
	result := wire.CredentialResult{OperationID: request.Data.OperationID, Outcome: wire.OutcomeOK, AccessToken: &token}
	c.send(t, 2, "credentials/result", result)
	if m := c.response(t, 2); m["error"] != nil {
		t.Fatal("matching result refused")
	}
	select {
	case r := <-done:
		if r.err != nil || r.result.AccessToken == nil || *r.result.AccessToken != token {
			t.Fatal("result not delivered")
		}
	case <-time.After(time.Second):
		t.Fatal("reader did not wake")
	}
	backend.mu.Lock()
	accepted := backend.accepted
	backend.mu.Unlock()
	if accepted != 0 {
		t.Fatal("background result started a second read")
	}
	c.send(t, 3, "credentials/result", result)
	if errorOf(t, c.response(t, 3)).Code != wire.CodeCredentialRejected {
		t.Fatal("duplicate accepted")
	}
}
func TestWaitableCredentialDeadlineAndCancellationRejectLateResults(t *testing.T) {
	for _, timeout := range []bool{false, true} {
		name := "cancel"
		if timeout {
			name = "timeout"
		}
		t.Run(name, func(t *testing.T) {
			c := startClient(t, Config{Backend: newMemoryBackend(), RequestTimeout: 150 * time.Millisecond})
			c.initialize(t)
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			done := make(chan credentialReply, 1)
			go func() {
				r, e := c.server.ReadCredential(ctx, CredentialNeed{Provider: "claude", Scope: testScope})
				done <- credentialReply{result: r, err: e}
			}()
			request := credentialRequestOf(t, c)
			if !timeout {
				cancel()
			}
			select {
			case r := <-done:
				if r.err == nil || r.result.AccessToken != nil {
					t.Fatal("closed operation returned token")
				}
			case <-time.After(time.Second):
				t.Fatal("unbounded wait")
			}
			token := "U7-late-token-canary"
			c.send(t, 2, "credentials/result", wire.CredentialResult{OperationID: request.Data.OperationID, Outcome: wire.OutcomeOK, AccessToken: &token})
			if errorOf(t, c.response(t, 2)).Code != wire.CodeCredentialRejected {
				t.Fatal("late callback accepted")
			}
		})
	}
}
func TestWaitableCredentialRejectsWrongOperationAndOldEpoch(t *testing.T) {
	backend := newMemoryBackend()
	c := startClient(t, Config{Backend: backend})
	c.initialize(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan credentialReply, 1)
	go func() {
		r, e := c.server.ReadCredential(ctx, CredentialNeed{Provider: "claude", Scope: testScope})
		done <- credentialReply{result: r, err: e}
	}()
	request := credentialRequestOf(t, c)
	token := "U7-mismatched-token-canary"
	result := wire.CredentialResult{OperationID: "wrong-operation", Outcome: wire.OutcomeOK, AccessToken: &token}
	c.send(t, 2, "credentials/result", result)
	if errorOf(t, c.response(t, 2)).Code != wire.CodeCredentialRejected {
		t.Fatal("wrong operation accepted")
	}
	backend.mu.Lock()
	backend.view.Stamp.Epoch = "another-epoch"
	backend.mu.Unlock()
	result.OperationID = request.Data.OperationID
	c.send(t, 3, "credentials/result", result)
	if errorOf(t, c.response(t, 3)).Code != wire.CodeCredentialRejected {
		t.Fatal("old epoch accepted at same generation")
	}
	cancel()
	select {
	case r := <-done:
		if r.err == nil || r.result.AccessToken != nil {
			t.Fatal("stale token delivered")
		}
	case <-time.After(time.Second):
		t.Fatal("waiter did not stop")
	}
}
