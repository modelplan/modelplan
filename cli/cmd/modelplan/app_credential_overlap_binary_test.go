// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func pendingCredentialRequests(t *testing.T, p *queryBinary) []wire.CredentialRequest {
	t.Helper()
	p.call("diagnostics/get", map[string]any{}) // a round trip collects what arrived before it
	var out []wire.CredentialRequest
	for _, raw := range p.notifications {
		var m struct {
			Method string `json:"method"`
			Params struct {
				Data wire.CredentialRequest `json:"data"`
			} `json:"params"`
		}
		if json.Unmarshal(raw, &m) == nil && m.Method == "credentials/request" {
			out = append(out, m.Params.Data)
		}
	}
	return out
}

// One Keychain grant is one credential read. The explicit operation leaves the operation table
// when its result arrives, but its read has not finished; a background refresh must not take
// that moment for a second, silent read of the same provider. The overlap needs a scheduler
// wake-up beside the grant, so several sessions run. No token is sent: nothing reaches a vendor.
func TestGrantCredentialReadIsNotOverlappedByBackgroundRead(t *testing.T) {
	testenv.IsolateHome(t)
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, raw)
	}
	for round := range 8 {
		t.Run(strconv.Itoa(round), func(t *testing.T) { testGrantCredentialRead(t, binary) })
	}
}

func testGrantCredentialRead(t *testing.T, binary string) {
	t.Helper()
	p, first := startGrantCredentialRead(t, binary)
	if reply := p.call("credentials/result", wire.CredentialResult{OperationID: first.OperationID, Outcome: wire.OutcomeNotFound}); reply["error"] != nil {
		t.Fatalf("the grant's read failed: %s; credential requests: %+v", reply["error"], pendingCredentialRequests(t, p))
	}
	time.Sleep(300 * time.Millisecond)
	if got := pendingCredentialRequests(t, p); len(got) != 1 {
		t.Fatalf("one grant made %d credential requests: %+v", len(got), got)
	}
}

// startGrantCredentialRead gives a fresh home the Keychain grant and returns its interactive request.
func startGrantCredentialRead(t *testing.T, binary string) (*queryBinary, wire.CredentialRequest) {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, ".cache"))
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	t.Setenv("MODELPLAN_CACHE", filepath.Join(home, "cache"))
	t.Setenv("MODELPLAN_CODEX", filepath.Join(home, "no-real-codex"))
	if err := os.MkdirAll(filepath.Join(home, ".claude"), 0700); err != nil {
		t.Fatal(err)
	}
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	p := startQueryBinaryCaps(t, binary, []string{"rows", "consent", "diagnostics", "refresh", "credentials"})
	if reply := p.call("rows/subscribe", map[string]any{}); reply["error"] != nil {
		t.Fatalf("rows/subscribe: %s", reply["error"])
	}
	var facts wire.Envelope[wire.ConsentFacts]
	if err := json.Unmarshal(p.call("consent/get", map[string]any{})["result"], &facts); err != nil {
		t.Fatal(err)
	}
	grant := p.call("consent/grant", wire.ConsentGrantParams{RequestID: "overlap-grant", ExpectStoreEpoch: facts.StoreEpoch, ExpectGeneration: facts.ConsentGeneration, TextVersion: consent.TextVersion, Allow: []string{consent.ScopeClaudeAccountUsageSavedLogin}, Deny: []string{}, Keychain: map[string]wire.KeychainChoice{consent.ScopeClaudeAccountUsageSavedLogin: wire.KeychainAllow}})
	if grant["error"] != nil {
		t.Fatalf("grant: %s", grant["error"])
	}
	deadline := time.Now().Add(5 * time.Second)
	for {
		requests := pendingCredentialRequests(t, p)
		if len(requests) > 0 {
			if !requests[0].Interactive {
				t.Fatalf("first request: %+v", requests[0])
			}
			return p, requests[0]
		}
		if time.Now().After(deadline) {
			t.Fatal("no interactive credential request")
		}
		time.Sleep(5 * time.Millisecond)
	}
}

// A failed grant read does not close the door on a refresh the user asks for: the background read
// the refresh needs still happens, promptly, as a non-interactive operation.
func TestRequestedRefreshAfterGrantReadStillReads(t *testing.T) {
	testenv.IsolateHome(t)
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, raw)
	}
	p, first := startGrantCredentialRead(t, binary)
	if reply := p.call("credentials/result", wire.CredentialResult{OperationID: first.OperationID, Outcome: wire.OutcomeInteractionRequired}); reply["error"] != nil {
		t.Fatalf("result: %s", reply["error"])
	}
	reply := p.call("refresh/request", wire.RefreshRequestParams{Scopes: []string{consent.ScopeClaudeAccountUsageSavedLogin}})
	var scheduled wire.Envelope[[]wire.RefreshScheduled]
	if err := json.Unmarshal(reply["result"], &scheduled); err != nil || len(scheduled.Data) != 1 || scheduled.Data[0].DisabledReason != nil {
		t.Fatalf("refresh: %s %s %v", reply["result"], reply["error"], err)
	}
	deadline := time.Now().Add(3 * time.Second)
	for {
		got := pendingCredentialRequests(t, p)
		if len(got) == 2 {
			if got[1].Interactive {
				t.Fatalf("background request: %+v", got[1])
			}
			p.call("credentials/result", wire.CredentialResult{OperationID: got[1].OperationID, Outcome: wire.OutcomeNotFound})
			return
		}
		if time.Now().After(deadline) {
			t.Fatalf("no read after the requested refresh: %+v", got)
		}
		time.Sleep(20 * time.Millisecond)
	}
}
