// SPDX-License-Identifier: MIT
// Test-only pipe faults around the ordinary executable. Never imported by the client.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type plan struct {
	Binary string `json:"binary"`
	Mode   string `json:"mode"`
}
type proxy struct {
	mu            sync.Mutex
	out           sync.Mutex
	plan          plan
	methods       map[string]string
	session       string
	triggered     bool
	paused        bool
	held          map[string]any
	receipt       map[string]any
	credential    map[string]any
	scope         string
	sawCredential bool
}

func object(v any) map[string]any { m, _ := v.(map[string]any); return m }
func (p *proxy) send(m map[string]any) {
	p.out.Lock()
	defer p.out.Unlock()
	b, _ := json.Marshal(m)
	_, _ = os.Stdout.Write(append(b, '\n'))
}
func (p *proxy) trace(method string, token bool) {
	f, e := os.OpenFile(filepath.Join(os.Getenv("HOME"), "proxy.trace"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if e != nil {
		return
	}
	defer f.Close()
	b, _ := json.Marshal(map[string]any{"method": method, "tokenInCredentialResult": token})
	_, _ = f.Write(append(b, '\n'))
}
func clone(v map[string]any) map[string]any {
	b, _ := json.Marshal(v)
	var r map[string]any
	_ = json.Unmarshal(b, &r)
	return r
}
func (p *proxy) tighten(receipt map[string]any) {
	e := object(receipt["result"])
	body := map[string]any{"requestId": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee", "expectStoreEpoch": e["storeEpoch"], "expectGeneration": e["consentGeneration"], "consentTextVersion": 2, "allow": []string{}, "deny": []string{p.scope}}
	b, _ := json.Marshal(body)
	c := exec.Command(p.plan.Binary, "consent", "grant", "--json")
	c.Stdin = bytes.NewReader(b)
	c.Stdout = io.Discard
	c.Stderr = io.Discard
	_ = c.Run()
}
func (p *proxy) release(file string, message map[string]any) {
	go func() {
		end := time.Now().Add(10 * time.Second)
		for time.Now().Before(end) {
			if _, e := os.Stat(filepath.Join(os.Getenv("HOME"), file)); e == nil {
				p.send(message)
				return
			}
			time.Sleep(5 * time.Millisecond)
		}
	}()
}
func main() {
	if len(os.Args) < 2 || os.Args[1] != "app-server" {
		os.Exit(2)
	}
	raw, e := os.ReadFile(filepath.Join(os.Getenv("HOME"), ".engine-client-proxy.json"))
	if e != nil {
		os.Exit(3)
	}
	p := &proxy{methods: map[string]string{}}
	if json.Unmarshal(raw, &p.plan) != nil {
		os.Exit(4)
	}
	args := append([]string{"app-server"}, os.Args[2:]...)
	child := exec.Command(p.plan.Binary, args...)
	child.Stderr = io.Discard
	input, e := child.StdinPipe()
	if e != nil {
		os.Exit(5)
	}
	output, e := child.StdoutPipe()
	if e != nil {
		os.Exit(6)
	}
	if child.Start() != nil {
		os.Exit(7)
	}
	defer func() { _ = child.Process.Kill(); _ = child.Wait() }()
	go func() {
		scan := bufio.NewScanner(os.Stdin)
		scan.Buffer(make([]byte, 16384), 8<<20)
		for scan.Scan() {
			var m map[string]any
			if json.Unmarshal(scan.Bytes(), &m) != nil {
				return
			}
			method, _ := m["method"].(string)
			params := object(m["params"])
			token := false
			if method == "credentials/result" {
				_, token = params["accessToken"]
				// Canary transport proof only: prevent a synthetic success token from
				// reaching a live vendor. The ordinary Go child records a typed not_found.
				params["outcome"] = "not_found"
				delete(params, "accessToken")
				delete(params, "expiresAt")
			}
			p.trace(method, token)
			p.mu.Lock()
			id, _ := m["id"].(string)
			p.methods[id] = method
			if method == "initialize" {
				p.session, _ = params["sessionId"].(string)
				if p.plan.Mode == "major-mismatch" {
					params["protocolVersion"] = "2.0"
				}
				if p.plan.Mode == "no-agent" {
					caps, _ := params["capabilities"].([]any)
					params["capabilities"] = append(caps, "credentials")
				}
			}
			if method == "consent/grant" {
				if allow, ok := params["allow"].([]any); ok && len(allow) > 0 {
					p.scope, _ = allow[0].(string)
				}
			}
			if p.plan.Mode == "hold" && method == "diagnostics/get" {
				p.paused = true
			}
			var late map[string]any
			if p.plan.Mode == "late-error" && method == "$/cancel" && p.held != nil {
				late = p.held
				p.held = nil
			}
			p.mu.Unlock()
			b, _ := json.Marshal(m)
			if _, e := input.Write(append(b, '\n')); e != nil {
				return
			}
			if late != nil {
				p.send(late)
			}
		}
		_ = input.Close()
	}()
	scan := bufio.NewScanner(output)
	scan.Buffer(make([]byte, 16384), 8<<20)
	for scan.Scan() {
		var m map[string]any
		if json.Unmarshal(scan.Bytes(), &m) != nil {
			continue
		}
		p.mu.Lock()
		id, _ := m["id"].(string)
		method := p.methods[id]
		if p.paused {
			p.mu.Unlock()
			continue
		}
		notification, _ := m["method"].(string)
		if (p.plan.Mode == "initialize-error-once" || p.plan.Mode == "initialize-unavailable-once") && method == "initialize" {
			// Keep the ordinary Go child and proxy alive after the injected
			// failure. Only the first supervised launch fails; its successor
			// performs the unmodified real handshake.
			marker, err := os.OpenFile(filepath.Join(os.Getenv("HOME"), "initialize-error-used"), os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
			if err == nil {
				_ = marker.Close()
				env := object(m["result"])
				failure := map[string]any{"jsonrpc": "2.0", "id": m["id"], "error": map[string]any{"code": -32603, "message": "internal_error", "data": map[string]any{"sessionId": env["sessionId"], "storeEpoch": env["storeEpoch"], "consentGeneration": env["consentGeneration"]}}}
				if p.plan.Mode == "initialize-unavailable-once" {
					env["storeEpoch"] = "unavailable"
					failure = m
				}
				p.mu.Unlock()
				p.trace("initialize-error-held", false)
				p.release("release-initialize-error", failure)
				continue
			}
		}
		if p.plan.Mode == "oversized" && !p.triggered {
			p.triggered = true
			p.mu.Unlock()
			p.out.Lock()
			_, _ = os.Stdout.Write([]byte(strings.Repeat("x", 8<<20)))
			p.out.Unlock()
			continue
		}
		if p.plan.Mode == "probe-fails" && p.triggered && method == "consent/get" {
			p.mu.Unlock()
			continue
		}
		if p.plan.Mode == "probe-fails" && method == "diagnostics/get" && !p.triggered {
			p.triggered = true
			object(m["result"])["storeEpoch"] = "00000000000000000000000000000001"
			p.mu.Unlock()
			p.send(m)
			continue
		}
		if (p.plan.Mode == "higher-error" && method == "diagnostics/get") || (p.plan.Mode == "late-error" && method == "history/query") {
			env := object(m["result"])
			if env == nil {
				env = object(object(m["error"])["data"])
			}
			g, _ := env["consentGeneration"].(float64)
			m = map[string]any{"jsonrpc": "2.0", "id": m["id"], "error": map[string]any{"code": -32023, "message": "consent_changed", "data": map[string]any{"sessionId": env["sessionId"], "storeEpoch": env["storeEpoch"], "consentGeneration": g + 1}}}
			if p.plan.Mode == "late-error" {
				p.held = m
				p.mu.Unlock()
				continue
			}
		}
		if p.plan.Mode == "wrong-session-sequence" && method == "rows/subscribe" && m["result"] != nil && !p.triggered {
			p.triggered = true
			p.mu.Unlock()
			wrong := clone(m)
			env := object(wrong["result"])
			env["sessionId"] = "s-old-child"
			env["storeEpoch"] = "11111111111111111111111111111111"
			env["consentGeneration"] = 999999
			object(env["data"])["sequence"] = 999999
			p.send(map[string]any{"jsonrpc": "2.0", "method": "rows/changed", "params": env})
			p.send(m)
			duplicate := clone(m)
			env = object(duplicate["result"])
			p.send(map[string]any{"jsonrpc": "2.0", "method": "rows/changed", "params": env})
			object(env["data"])["sequence"] = 0
			p.send(map[string]any{"jsonrpc": "2.0", "method": "rows/changed", "params": env})
			continue
		}
		if p.plan.Mode == "duplicate-credential" && notification == "credentials/request" {
			p.mu.Unlock()
			p.send(m)
			p.send(clone(m))
			continue
		}
		if p.plan.Mode == "history-malformed" && method == "history/query" {
			env := object(m["result"])
			if env == nil {
				env = clone(object(object(m["error"])["data"]))
			}
			env["scopes"] = []string{"codex.local_history"}
			env["data"] = map[string]any{"items": nil}
			m = map[string]any{"jsonrpc": "2.0", "id": m["id"], "result": env}
		}
		if p.plan.Mode == "receipt-malformed" && method == "consent/grant" && m["result"] != nil {
			delete(object(object(m["result"])["data"]), "committedGeneration")
		}
		if p.plan.Mode == "receipt-old-epoch" && method == "consent/grant" && m["result"] != nil {
			object(m["result"])["storeEpoch"] = "00000000000000000000000000000001"
		}
		if p.plan.Mode == "receipt-first" && notification == "credentials/request" {
			p.mu.Unlock()
			p.release("release-credential", m)
			continue
		}
		if (p.plan.Mode == "credential-first" || p.plan.Mode == "historic") && method == "consent/grant" && m["result"] != nil && !p.triggered {
			p.triggered = true
			p.receipt = m
			release := p.plan.Mode == "credential-first" && p.sawCredential
			if release {
				p.receipt = nil
			}
			p.mu.Unlock()
			if release {
				p.release("release-receipt", m)
			}
			if p.plan.Mode == "historic" {
				p.tighten(m)
			}
			continue
		}
		if p.plan.Mode == "receipt-first" && notification == "credentials/request" && p.receipt == nil {
			p.credential = m
			p.mu.Unlock()
			continue
		}
		var after map[string]any
		if p.plan.Mode == "receipt-first" && method == "consent/grant" && m["result"] != nil {
			p.receipt = m
			after = p.credential
			p.credential = nil
		}
		if p.plan.Mode == "credential-first" && notification == "credentials/request" {
			p.sawCredential = true
			receipt := p.receipt
			p.receipt = nil
			p.mu.Unlock()
			p.send(m)
			if receipt != nil {
				p.release("release-receipt", receipt)
			}
			continue
		}
		if p.plan.Mode == "historic" && notification == "consent/changed" && p.receipt != nil {
			old := object(p.receipt["result"])["consentGeneration"].(float64)
			cur := object(m["params"])["consentGeneration"].(float64)
			if cur > old {
				after = p.receipt
				p.receipt = nil
			}
		}
		p.mu.Unlock()
		p.send(m)
		if after != nil {
			p.send(after)
		}
	}
}
