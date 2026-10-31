// SPDX-License-Identifier: MIT
// Test-only pipe faults around the ordinary executable. Never imported by the client.
package main

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
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
	if len(os.Args) >= 2 && os.Args[1] == "seed-publication" {
		revision := "string"
		if len(os.Args) == 3 {
			revision = os.Args[2]
		}
		if len(os.Args) > 3 || (revision != "string" && revision != "null" && revision != "absent") {
			os.Exit(2)
		}
		if err := seedPublicCache(revision); err != nil {
			fmt.Fprintln(os.Stderr, "synthetic seed failed")
			os.Exit(9)
		}
		return
	}
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
			var lateCredential map[string]any
			if p.plan.Mode == "duplicate-credential" && method == "credentials/result" && !p.triggered {
				p.triggered = true
				lateCredential = clone(p.credential)
			}
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
			if lateCredential != nil {
				p.send(lateCredential)
				p.trace("duplicate-credential-replayed", false)
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
		if p.plan.Mode == "without-features" && method == "initialize" && m["result"] != nil {
			data := object(object(m["result"])["data"])
			original, _ := data["capabilities"].([]any)
			kept := []any{}
			for _, capability := range original {
				if capability != "cockpit" && capability != "publication" && capability != "plugin_install" {
					kept = append(kept, capability)
				}
			}
			data["capabilities"] = kept
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
		if p.plan.Mode == "rows-busy-once" && method == "rows/subscribe" && m["result"] != nil && !p.triggered {
			p.triggered = true
			env := object(m["result"])
			m = map[string]any{"jsonrpc": "2.0", "id": m["id"], "error": map[string]any{"code": -32013, "message": "busy", "data": map[string]any{"sessionId": env["sessionId"], "storeEpoch": env["storeEpoch"], "consentGeneration": env["consentGeneration"]}}}
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
			p.credential = clone(m)
			p.mu.Unlock()
			p.send(m)
			p.send(clone(m))
			continue
		}
		// Labeled faults hold or mutate only ordinary binary responses.
		if p.plan.Mode == "hold-features" && (method == "cockpit/query" || method == "history/query" || method == "publication/get" || method == "plugin/install") {
			p.mu.Unlock()
			p.trace("held-"+method, false)
			p.release("release-feature", m)
			continue
		}
		if strings.HasPrefix(p.plan.Mode, "cockpit-") && method == "cockpit/query" && m["result"] != nil {
			env := object(m["result"])
			switch p.plan.Mode {
			case "cockpit-malformed":
				env["data"] = map[string]any{"projection": nil, "subscriptions": []any{}}
			case "cockpit-higher":
				env["consentGeneration"] = env["consentGeneration"].(float64) + 1
			case "cockpit-foreign-epoch":
				env["storeEpoch"] = "00000000000000000000000000000001"
			case "cockpit-wrong-session":
				wrong := clone(m)
				object(wrong["result"])["sessionId"] = "s-retired"
				object(wrong["result"])["storeEpoch"] = "00000000000000000000000000000001"
				p.send(wrong)
			}
		}
		if strings.HasPrefix(p.plan.Mode, "plugin-") && method == "plugin/install" && m["result"] != nil {
			data := object(object(m["result"])["data"])
			switch p.plan.Mode {
			case "plugin-wrong-tool":
				data["tool"] = "claude-code"
			case "plugin-unknown-status":
				data["status"] = "maybe-installed"
			case "plugin-invalid-completed":
				data["status"] = "installed"
				data["completed"] = 0
			}
		}
		if p.plan.Mode == "publication-malformed" && method == "publication/get" && m["result"] != nil {
			object(object(m["result"])["data"])["models"] = "not-an-array"
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

// Handwritten synthetic public graph, verified by the ordinary loader. This
// test-only operation refuses non-test homes and never fetches public/live data.
func seedPublicCache(revision string) error {
	home := os.Getenv("HOME")
	if !strings.HasPrefix(filepath.Base(home), "engine-client-") {
		return fmt.Errorf("not a test home")
	}
	base, err := os.UserCacheDir()
	if err != nil {
		return err
	}
	cache := filepath.Join(base, "modelplan")
	hash := func(b []byte) string { return fmt.Sprintf("%x", sha256.Sum256(b)) }
	dependencies := map[string]string{}
	for _, n := range []string{"models", "registry", "rules", "calendar"} {
		dependencies[n] = strings.Repeat("a", 64)
	}
	data := map[string]any{
		"units": map[string]string{"ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"},
		"models": []any{map[string]any{"id": "synthetic-u4b", "developerId": "synthetic", "harnessIds": map[string]any{"codex": []string{"synthetic-u4b"}},
			"efforts": []any{map[string]any{"effort": "medium", "ability": nil, "cost": 1.25, "time": nil, "futurePublishedValue": uint64(9007199254740993)}}}},
		"lineups": []any{}, "speedTiers": []any{}, "resets": []any{}, "windows": []any{}, "selectionRevision": "synthetic-revision",
	}
	if revision == "null" {
		data["selectionRevision"] = nil
	}
	if revision == "absent" {
		delete(data, "selectionRevision")
	}
	object, _ := json.Marshal(map[string]any{"schemaVersion": 1, "kind": "client", "dependencies": dependencies, "data": data})
	type ref struct {
		SchemaVersion int    `json:"schemaVersion"`
		Hash          string `json:"hash"`
		Bytes         int    `json:"bytes"`
	}
	refs := map[string]ref{}
	for _, n := range []string{"methods", "registry", "models", "plans", "rules", "news", "calendar"} {
		refs[n] = ref{1, strings.Repeat("a", 64), 2}
	}
	refs["client"] = ref{1, hash(object), len(object)}
	core := struct {
		SchemaVersion     int               `json:"schemaVersion"`
		ComparisonVersion string            `json:"comparisonVersion"`
		Methods           map[string]string `json:"methods"`
		Components        map[string]ref    `json:"components"`
	}{
		1, "synthetic-u4b", map[string]string{"index": "unified-v03-estimator-0.1.0-internal", "recommendation": "balanced-coding-absolute-v4"}, refs}
	encoded, _ := json.Marshal(core)
	id := hash(encoded)[:24]
	manifest := []byte(strings.TrimSuffix(string(encoded), "}") + `,"publicationId":"` + id + `","publishedAt":"2020-01-01T00:00:00Z"}`)
	now := time.Now().UTC()
	state, _ := json.Marshal(map[string]any{"base": "http://127.0.0.1:1", "publicationId": id, "manifestHash": hash(manifest), "publishedAt": "2020-01-01T00:00:00Z", "component": "client", "componentHash": hash(object), "checkedAt": now, "nextCheckAt": now.Add(24 * time.Hour), "verifiedAt": now})
	for name, value := range map[string][]byte{"objects/" + hash(object) + ".json": object, "releases/" + id + "/manifest.json": manifest, "state.json": state} {
		path := filepath.Join(cache, name)
		if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			return err
		}
		if err := os.WriteFile(path, value, 0600); err != nil {
			return err
		}
	}
	return nil
}
