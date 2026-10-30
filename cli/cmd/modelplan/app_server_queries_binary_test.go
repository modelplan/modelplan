// SPDX-License-Identifier: MIT
package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/appcontract"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

type queryBinary struct {
	t             *testing.T
	cmd           *exec.Cmd
	in            io.WriteCloser
	frames        chan []byte
	done          chan error
	id            int
	notifications []json.RawMessage
}

func startQueryBinary(t *testing.T, binary string) *queryBinary {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	cmd := exec.CommandContext(ctx, binary, "app-server")
	in, err := cmd.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	out, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	stderr, err := os.CreateTemp(t.TempDir(), "stderr")
	if err != nil {
		t.Fatal(err)
	}
	cmd.Stderr = stderr
	p := &queryBinary{t: t, cmd: cmd, in: in, frames: make(chan []byte, 128), done: make(chan error, 1)}
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	go func() {
		scanner := bufio.NewScanner(out)
		scanner.Buffer(make([]byte, 4096), wire.MaxFrameBytes)
		for scanner.Scan() {
			select {
			case p.frames <- append([]byte(nil), scanner.Bytes()...):
			case <-ctx.Done():
				return
			}
		}
		close(p.frames)
	}()
	go func() { p.done <- cmd.Wait() }()
	t.Cleanup(func() {
		in.Close()
		select {
		case err := <-p.done:
			if err != nil {
				t.Errorf("app-server exit: %v", err)
			}
		case <-time.After(3 * time.Second):
			cmd.Process.Kill()
			<-p.done
			t.Error("app-server failed to stop")
		}
		cancel()
		b, _ := os.ReadFile(stderr.Name())
		stderr.Close()
		if len(b) != 0 {
			t.Errorf("unexpected app-server stderr: %s", b)
		}
	})
	p.call("initialize", map[string]any{"sessionId": "u3c-binary", "protocolVersion": "1.0", "appVersion": "test", "capabilities": []string{"rows", "consent", "history", "cockpit", "refresh", "publication"}})
	return p
}
func (p *queryBinary) call(method string, params any) map[string]json.RawMessage {
	p.t.Helper()
	p.id++
	body, err := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": p.id, "method": method, "params": params})
	if err != nil {
		p.t.Fatal(err)
	}
	if _, err := p.in.Write(append(body, '\n')); err != nil {
		p.t.Fatal(err)
	}
	timer := time.NewTimer(5 * time.Second)
	defer timer.Stop()
	for {
		select {
		case raw, ok := <-p.frames:
			if !ok {
				p.t.Fatal("app-server stdout closed")
			}
			var msg map[string]json.RawMessage
			if json.Unmarshal(raw, &msg) != nil {
				p.t.Fatal("invalid server frame")
			}
			var id int
			if json.Unmarshal(msg["id"], &id) == nil && id == p.id {
				return msg
			}
			p.notifications = append(p.notifications, raw)
		case <-timer.C:
			p.t.Fatalf("timed out waiting for %s", method)
		}
	}
}
func binaryQueryCode(t *testing.T, msg map[string]json.RawMessage) int {
	t.Helper()
	var failure wire.RPCError
	if err := json.Unmarshal(msg["error"], &failure); err != nil {
		t.Fatalf("expected protocol error, got result=%s", msg["result"])
	}
	return failure.Code
}
func TestU3cHistorySelectorsRealBinary(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-ldflags", "-X main.version=1.0.0", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, raw)
	}
	home := setupQueryHome(t)
	p := startQueryBinary(t, binary)
	control := map[string]any{"tool": "gemini", "kind": "tokens", "limit": 1}
	msg := p.call("history/query", control)
	if _, ok := msg["result"]; !ok {
		t.Fatalf("omitted selector control failed: %s", msg["error"])
	}
	if cockpit := p.call("cockpit/query", map[string]any{}); cockpit["result"] == nil {
		t.Fatalf("cockpit not registered in ordinary executable: %s", cockpit["error"])
	}
	for _, field := range []string{"ref", "cursor"} {
		for _, value := range []any{nil, true, false, 1, 1.5, []any{}, map[string]any{}} {
			t.Run(fmt.Sprintf("%s/%T/%v", field, value, value), func(t *testing.T) {
				params := map[string]any{"tool": "gemini", "kind": "tokens", "limit": 1, field: value}
				if got := binaryQueryCode(t, p.call("history/query", params)); got != wire.CodeInvalidParams {
					t.Fatalf("wrong error: %d", got)
				}
			})
		}
	}
	testRegisteredCockpitAndCursor(t, p, home)
}

func testRegisteredCockpitAndCursor(t *testing.T, p *queryBinary, home string) {
	t.Helper()
	now := time.Now().UTC().Add(-time.Second).Format(time.RFC3339Nano)
	file := filepath.Join(home, ".cursor", "token-usage", "usage.jsonl")
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		t.Fatal(err)
	}
	content := ""
	for i := range 2 {
		content += fmt.Sprintf(`{"event":"stop","ts":%q,"conversation_id":"synthetic-cursor","generation_id":"turn-%d","model":"cursor-model-%d","tokens_present":true,"input_tokens":10,"output_tokens":2,"total_tokens":%d}`+"\n", now, i, i, 12+i)
	}
	if err := os.WriteFile(file, []byte(content), 0600); err != nil {
		t.Fatal(err)
	}
	current := p.call("consent/get", map[string]any{})
	var facts wire.Envelope[wire.ConsentFacts]
	if json.Unmarshal(current["result"], &facts) != nil {
		t.Fatal("consent read failed")
	}
	grant := p.call("consent/grant", wire.ConsentGrantParams{RequestID: "u3c-cursor-local", ExpectStoreEpoch: facts.StoreEpoch, ExpectGeneration: facts.ConsentGeneration, TextVersion: consent.TextVersion, Allow: []string{consent.ScopeCursorLocalHistory}, Deny: []string{consent.ScopeCursorAccountUsageSavedLogin}})
	if _, ok := grant["error"]; ok {
		t.Fatalf("Cursor local grant rejected: %s", grant["error"])
	}
	scheduled := p.call("refresh/request", wire.RefreshRequestParams{Scopes: []string{consent.ScopeCursorLocalHistory}})
	if _, ok := scheduled["result"]; !ok {
		t.Fatalf("Cursor refresh unavailable: %s", scheduled["error"])
	}
	deadline := time.Now().Add(5 * time.Second)
	var page wire.Envelope[wire.HistoryPage]
	for {
		result := p.call("history/query", wire.HistoryQueryParams{Tool: "cursor", Kind: wire.HistoryTokens, Limit: 1})
		if json.Unmarshal(result["result"], &page) == nil && len(page.Data.Items) == 1 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatalf("registered Cursor producer unavailable: %s", result["error"])
		}
		time.Sleep(20 * time.Millisecond)
	}
	if len(page.Scopes) != 1 || page.Scopes[0] != consent.ScopeCursorLocalHistory || page.Data.NextCursor == "" || page.Data.Items[0].Tokens == nil {
		t.Fatal("Cursor typed page/context missing")
	}
	result := p.call("history/query", wire.HistoryQueryParams{Tool: "cursor", Kind: wire.HistoryTokens, Cursor: page.Data.NextCursor, Limit: 1})
	var next wire.Envelope[wire.HistoryPage]
	if json.Unmarshal(result["result"], &next) != nil || len(next.Data.Items) != 1 {
		t.Fatal("Cursor continuation failed")
	}
	beforeRows := p.call("rows/subscribe", map[string]any{})
	var before wire.Envelope[wire.RowsSnapshot]
	if json.Unmarshal(beforeRows["result"], &before) != nil {
		t.Fatal("rows baseline unavailable")
	}
	remote := p.call("refresh/request", wire.RefreshRequestParams{Scopes: []string{consent.ScopeCursorAccountUsageSavedLogin}})
	var blocked wire.Envelope[[]wire.RefreshScheduled]
	if json.Unmarshal(remote["result"], &blocked) != nil || len(blocked.Data) != 1 || blocked.Data[0].DisabledReason == nil {
		t.Fatalf("denied Cursor account scope admitted: %s", remote["result"])
	}
	retained := p.call("history/query", wire.HistoryQueryParams{Tool: "cursor", Kind: wire.HistoryTokens, Limit: 10})
	var kept wire.Envelope[wire.HistoryPage]
	if json.Unmarshal(retained["result"], &kept) != nil || len(kept.Data.Items) != 2 {
		t.Fatal("denied account refresh erased local Cursor history")
	}
	cockpit := p.call("cockpit/query", map[string]any{})
	var display wire.Envelope[wire.CockpitData]
	if json.Unmarshal(cockpit["result"], &display) != nil || display.Data.Subscriptions == nil || len(display.Scopes) == 0 {
		t.Fatalf("production cockpit not registered: %s", cockpit["error"])
	}
	encoded, err := json.Marshal(cockpit)
	if err != nil {
		t.Fatal(err)
	}
	validator, err := appcontract.NewValidator("../../..")
	if err != nil {
		t.Fatal(err)
	}
	if err := validator.Validate("app-server", encoded); err != nil {
		t.Fatal(err)
	}
	denied := p.call("cockpit/query", map[string]any{"path": "synthetic-secret"})
	if binaryQueryCode(t, denied) != wire.CodeInvalidParams {
		t.Fatal("cockpit accepts passthrough input")
	}
	afterRows := p.call("rows/subscribe", map[string]any{})
	var after wire.Envelope[wire.RowsSnapshot]
	if json.Unmarshal(afterRows["result"], &after) != nil {
		t.Fatal("rows readback failed")
	}
	beforeData, _ := json.Marshal(before.Data.Projection)
	afterData, _ := json.Marshal(after.Data.Projection)
	if !bytes.Equal(beforeData, afterData) {
		t.Fatal("cockpit query changed row projection")
	}
	factsReply := p.call("consent/get", map[string]any{})
	var currentFacts wire.Envelope[wire.ConsentFacts]
	if json.Unmarshal(factsReply["result"], &currentFacts) != nil {
		t.Fatal("consent readback failed")
	}
	for _, fact := range currentFacts.Data.Scopes {
		if fact.Scope == consent.ScopeCursorAccountUsageSavedLogin && (fact.Disabled != nil || fact.DefaultCheck || fact.State != wire.ConsentDenied) {
			t.Fatal("Cursor account denial or unchecked default lost")
		}
	}
}

func setupQueryHome(t *testing.T) string {
	t.Helper()
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	cache := filepath.Join(home, "cache")
	for name, value := range map[string]string{"MODELPLAN_CACHE": cache, "MODELPLAN_HISTORY": "", "MODELPLAN_READERS": "", "MODELPLAN_GEMINI": "", "MODELPLAN_GEMINI_HOME": "", "MODELPLAN_CODEX_ACCOUNT": "off", "MODELPLAN_CODEXBAR": "off"} {
		t.Setenv(name, value)
	}
	now := time.Now().UTC()
	file := filepath.Join(home, ".gemini", "tmp", "synthetic", "chats", "session-synthetic.json")
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		t.Fatal(err)
	}
	fixture, _ := json.Marshal(map[string]any{"messages": []any{map[string]any{"id": "synthetic", "type": "gemini", "timestamp": now, "model": "synthetic-model", "tokens": map[string]int{"input": 10, "output": 2, "total": 12}}}})
	if err := os.WriteFile(file, fixture, 0600); err != nil {
		t.Fatal(err)
	}
	if err := localusage.SetGemini(home, true); err != nil {
		t.Fatal(err)
	}
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "gemini", true, "native:gemini", "native", now) }); err != nil {
		t.Fatal(err)
	}
	if result := localusage.RefreshProductionHistory(context.Background(), home, cache, "gemini", now); result.Availability != "ok" {
		t.Fatal(result)
	}
	// Synthetic legacy input: an older writer granted account usage, which still
	// must not grant the independent local path. The local grant test explicitly
	// denies this account scope while preserving its numeric history.
	if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "cursor", true, "native:cursor", "native", now) }); err != nil {
		t.Fatal(err)
	}
	return home
}

// Build the same executable/constructor with only a deterministic barrier after
// the production source has read. The shared backend, source values, admission,
// serialization and process transport are unchanged; no runtime test flag ships.
func buildDelayedQueryBinary(t *testing.T) string {
	t.Helper()
	root, err := filepath.Abs("../../..")
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	replacements := map[string]string{}
	for _, kind := range []string{"history", "cockpit"} {
		path := filepath.Join(root, "cli/cmd/modelplan/app_server_"+kind+".go")
		source, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		target := "return batch, nil"
		if kind == "cockpit" {
			target = "return data, nil"
		}
		if bytes.Count(source, []byte(target)) != 1 {
			t.Fatal("query barrier source seam changed")
		}
		patched := bytes.Replace(source, []byte(target), []byte("queryTestBarrier(ctx, "+fmt.Sprintf("%q", kind)+"); "+target), 1)
		for _, method := range []string{"Admit", "Read"} {
			expression := regexp.MustCompile(`(func \(s shared` + strings.Title(kind) + `\) ` + method + strings.Title(kind) + `[^\{]+\{)`)
			if len(expression.FindAll(patched, -1)) != 1 {
				t.Fatal("observation source seam changed")
			}
			patched = expression.ReplaceAll(patched, []byte("${1}queryTestObserve("+fmt.Sprintf("%q,%q", kind, strings.ToLower(method))+");"))
		}
		output := filepath.Join(dir, kind+".go")
		if err := os.WriteFile(output, patched, 0600); err != nil {
			t.Fatal(err)
		}
		replacements[path] = output
	}
	barrier := `package main
import("context";"os";"path/filepath";"time")
func queryTestObserve(kind,phase string){
 root:=os.Getenv("HOME")
 if _,err:=os.Stat(filepath.Join(root,kind+".observe"));err==nil{_=os.WriteFile(filepath.Join(root,kind+"."+phase),nil,0600)}
}
func queryTestBarrier(ctx context.Context,kind string){
 root:=os.Getenv("HOME")
 if _,err:=os.Stat(filepath.Join(root,kind+".armed"));err!=nil{return}
 _=os.WriteFile(filepath.Join(root,kind+".entered"),[]byte("ready"),0600)
 timer:=time.NewTicker(5*time.Millisecond);defer timer.Stop()
 for{if _,err:=os.Stat(filepath.Join(root,kind+".release"));err==nil{return};select{case <-ctx.Done():return;case <-timer.C:}}
}`
	helper := filepath.Join(dir, "barrier.go")
	if err := os.WriteFile(helper, []byte(barrier), 0600); err != nil {
		t.Fatal(err)
	}
	replacements[filepath.Join(root, "cli/cmd/modelplan/u3c_query_barrier.go")] = helper
	overlay, _ := json.Marshal(map[string]any{"Replace": replacements})
	overlayPath := filepath.Join(dir, "overlay.json")
	if err := os.WriteFile(overlayPath, overlay, 0600); err != nil {
		t.Fatal(err)
	}
	binary := filepath.Join(dir, "modelplan-delayed")
	if raw, err := exec.Command("go", "build", "-overlay="+overlayPath, "-ldflags", "-X main.version=1.0.0", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build delayed executable: %v: %s", err, raw)
	}
	return binary
}
func TestU3cLateQueriesRealBinary(t *testing.T) {
	binary := buildDelayedQueryBinary(t)
	for _, kind := range []string{"history", "cockpit"} {
		for _, change := range []string{"revoke", "reset", "cancel"} {
			t.Run(kind+"/"+change, func(t *testing.T) {
				home := setupQueryHome(t)
				if err := os.WriteFile(filepath.Join(home, kind+".armed"), nil, 0600); err != nil {
					t.Fatal(err)
				}
				p := startQueryBinary(t, binary)
				result := make(chan map[string]json.RawMessage, 1)
				go func() {
					params := map[string]any{}
					if kind == "history" {
						params = map[string]any{"tool": "gemini", "kind": "tokens", "limit": 1}
					}
					result <- p.call(kind+"/query", params)
				}()
				deadline := time.Now().Add(3 * time.Second)
				for {
					if _, err := os.Stat(filepath.Join(home, kind+".entered")); err == nil {
						break
					}
					if time.Now().After(deadline) {
						t.Fatal("query did not reach production read barrier")
					}
					time.Sleep(5 * time.Millisecond)
				}
				state, err := consent.Load(consent.Path())
				if err != nil {
					t.Fatal(err)
				}
				if change == "cancel" {
					_, err := p.in.Write([]byte(`{"jsonrpc":"2.0","method":"$/cancel","params":{"id":2}}` + "\n"))
					if err != nil {
						t.Fatal(err)
					}
					select {
					case msg := <-result:
						if code := binaryQueryCode(t, msg); code != wire.CodeCanceled {
							t.Fatalf("cancelled query escaped: %d", code)
						}
					case <-time.After(5 * time.Second):
						t.Fatal("cancel did not complete")
					}
					rows := p.call("rows/subscribe", map[string]any{})
					if rows["result"] == nil {
						t.Fatal("cancel poisoned rows")
					}
					return
				}
				var cmd *exec.Cmd
				if change == "revoke" {
					request, _ := json.Marshal(consent.Grant{RequestID: "65200000-0000-4000-8000-000000000001", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{}, Deny: []string{consent.ScopeGeminiLocalHistory}})
					cmd = exec.Command(binary, "consent", "grant", "--json")
					cmd.Stdin = strings.NewReader(string(request))
				} else {
					cmd = exec.Command(binary, "consent", "reset", "confirmed", "--json")
				}
				if raw, err := cmd.CombinedOutput(); err != nil {
					t.Fatalf("external %s: %v: %s", change, err, raw)
				}
				if err := os.WriteFile(filepath.Join(home, kind+".release"), nil, 0600); err != nil {
					t.Fatal(err)
				}
				select {
				case msg := <-result:
					if code := binaryQueryCode(t, msg); code != wire.CodeConsentChanged {
						t.Fatalf("late %s value not fenced: %d", kind, code)
					}
				case <-time.After(5 * time.Second):
					t.Fatal("late query did not complete")
				}
				rows := p.call("rows/subscribe", map[string]any{})
				if _, ok := rows["result"]; !ok {
					t.Fatal("query failure poisoned rows")
				}
			})
		}
	}
}

func TestU3cInvalidSelectorsNeverAdmitRealBinary(t *testing.T) {
	binary := buildDelayedQueryBinary(t)
	home := setupQueryHome(t)
	if err := os.WriteFile(filepath.Join(home, "history.observe"), nil, 0600); err != nil {
		t.Fatal(err)
	}
	p := startQueryBinary(t, binary)
	for _, field := range []string{"ref", "cursor"} {
		for _, value := range []any{nil, true, false, 1, 1.5, []any{}, map[string]any{}} {
			response := p.call("history/query", map[string]any{"tool": "gemini", "kind": "tokens", "limit": 1, field: value})
			if binaryQueryCode(t, response) != wire.CodeInvalidParams {
				t.Fatal("invalid selector accepted")
			}
		}
	}
	for _, phase := range []string{"admit", "read"} {
		if _, err := os.Stat(filepath.Join(home, "history."+phase)); !os.IsNotExist(err) {
			t.Fatal("invalid selectors touched history source")
		}
	}
	result := p.call("history/query", map[string]any{"tool": "gemini", "kind": "tokens", "limit": 1})
	if result["result"] == nil {
		t.Fatal("omitted selector control failed")
	}
	for _, phase := range []string{"admit", "read"} {
		if _, err := os.Stat(filepath.Join(home, "history."+phase)); err != nil {
			t.Fatal("observation negative control failed")
		}
	}
}
