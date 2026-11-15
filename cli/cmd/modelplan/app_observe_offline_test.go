// SPDX-License-Identifier: MIT
package main

import (
	"errors"
	"go/ast"
	"go/parser"
	"go/token"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/store"
)

// The only reader package calls the two background observers may reach. Each reads a session log
// or a file ModelPlan wrote; none opens a credential or a connection.
var observerQuotaCalls = map[string]bool{
	"Background": true, "ClaudeSubscription": true, "CodexHome": true, "CodexSubscription": true,
	"RecentRollouts": true, "ThreadOrigin": true, "ZCodeSubscription": true,
}

// Packages that reach a provider, a credential store or another process.
var observerForbidden = map[string]bool{
	"net/http": true, "os/exec": true,
	"github.com/modelplan/modelplan/cli/internal/keychain": true,
	"github.com/modelplan/modelplan/cli/internal/toolcli":  true,
}

// Every function reachable from observeForApp and appActivity in this package, across the files
// that define them, may call only the allowed reader functions. Readers themselves are out of reach.
func TestObserveForAppStaysOffReaders(t *testing.T) {
	fset := token.NewFileSet()
	files, err := filepath.Glob("*.go")
	if err != nil {
		t.Fatal(err)
	}
	decls := map[string]*ast.FuncDecl{}
	imports := map[*ast.FuncDecl]map[string]string{}
	for _, name := range files {
		if strings.HasSuffix(name, "_test.go") {
			continue
		}
		file, err := parser.ParseFile(fset, name, nil, 0)
		if err != nil {
			t.Fatal(err)
		}
		names := map[string]string{}
		for _, spec := range file.Imports {
			path, _ := strconv.Unquote(spec.Path.Value)
			local := filepath.Base(path)
			if spec.Name != nil {
				local = spec.Name.Name
			}
			names[local] = path
		}
		for _, decl := range file.Decls {
			if fn, ok := decl.(*ast.FuncDecl); ok && fn.Recv == nil {
				decls[fn.Name.Name] = fn
				imports[fn] = names
			}
		}
	}
	seen := map[string]bool{}
	var visit func(string)
	visit = func(name string) {
		fn := decls[name]
		if fn == nil || seen[name] {
			return
		}
		seen[name] = true
		ast.Inspect(fn, func(n ast.Node) bool {
			switch x := n.(type) {
			case *ast.Ident:
				visit(x.Name)
			case *ast.SelectorExpr:
				pkg, ok := x.X.(*ast.Ident)
				if !ok {
					return true
				}
				path := imports[fn][pkg.Name]
				if observerForbidden[path] {
					t.Errorf("%s uses %s.%s", name, pkg.Name, x.Sel.Name)
				}
				if strings.HasSuffix(path, "/internal/quota") && !observerQuotaCalls[x.Sel.Name] && x.Sel.Name != "Report" {
					t.Errorf("%s calls quota.%s, which is not on the cache-only list", name, x.Sel.Name)
				}
			}
			return true
		})
	}
	visit("observeForApp")
	visit("appActivity")
	if !seen["observeLiveLogs"] || !seen["observeAgents"] {
		t.Fatalf("the walk missed the observers: %v", seen)
	}
	raw, err := exec.Command("go", "list", "-deps", "../../internal/speed").CombinedOutput()
	if err != nil {
		t.Fatalf("go list: %v %s", err, raw)
	}
	for _, dep := range strings.Fields(string(raw)) {
		if observerForbidden[dep] && dep != "os/exec" {
			t.Errorf("internal/speed depends on %s", dep)
		}
		if strings.HasSuffix(dep, "/internal/quota") {
			t.Errorf("internal/speed depends on the readers")
		}
	}
}

type countingTransport struct{ calls atomic.Int32 }

func (c *countingTransport) RoundTrip(*http.Request) (*http.Response, error) {
	c.calls.Add(1)
	return nil, errors.New("no network in the observer")
}

// A run with every tool's login present and every credential command trapped.
func TestObserveForAppRunMakesNoRequestAndStartsNoCommand(t *testing.T) {
	home := setupQueryHome(t)
	for path, body := range map[string]string{
		".codex/auth.json":               `{"tokens":{"access_token":"canary"}}`,
		".claude/.credentials.json":      `{"claudeAiOauth":{"accessToken":"canary"}}`,
		".zcode/v2/provider_config.json": `{"schemaVersion":1}`,
	} {
		file := filepath.Join(home, path)
		if err := os.MkdirAll(filepath.Dir(file), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(file, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	bin, marker := t.TempDir(), filepath.Join(t.TempDir(), "started")
	for _, name := range []string{"security", "codex", "claude", "zcode", "gh"} {
		script := "#!/bin/sh\necho " + name + " >> " + marker + "\n"
		if err := os.WriteFile(filepath.Join(bin, name), []byte(script), 0o700); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", bin)
	transport := &countingTransport{}
	previous := http.DefaultTransport
	http.DefaultTransport = transport
	t.Cleanup(func() { http.DefaultTransport = previous })
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	observeForApp(st)(time.Now())
	if transport.calls.Load() != 0 {
		t.Fatalf("requests = %d", transport.calls.Load())
	}
	if raw, err := os.ReadFile(marker); err == nil {
		t.Fatalf("commands started: %s", raw)
	}
}
