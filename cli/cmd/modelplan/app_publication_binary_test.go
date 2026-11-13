// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/store"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// appPublicationHost is the public publication host a fresh install reaches. Requests can be
// held, so a test can read the state before the data arrives, and it records what was sent.
type appPublicationHost struct {
	t       *testing.T
	f       publicationFixture
	release chan struct{}
	mu      sync.Mutex
	hits    []string
}

func newAppPublicationHost(t *testing.T, f publicationFixture, held bool) (*appPublicationHost, *httptest.Server) {
	t.Helper()
	h := &appPublicationHost{t: t, f: f, release: make(chan struct{})}
	if !held {
		close(h.release)
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h.mu.Lock()
		h.hits = append(h.hits, r.Method+" "+r.URL.Path)
		h.mu.Unlock()
		if r.Method != http.MethodGet || r.ContentLength > 0 || r.URL.RawQuery != "" || r.Header.Get("Authorization") != "" || r.Header.Get("Cookie") != "" {
			t.Errorf("publication request carries more than a public read: %s %s", r.Method, r.URL)
		}
		select {
		case <-h.release:
		case <-r.Context().Done():
			return
		}
		switch r.URL.Path {
		case "/publications/current.json":
			_, _ = w.Write(f.pointer)
		case "/publications/releases/" + f.id + "/manifest.json":
			_, _ = w.Write(f.manifest)
		case "/publications/objects/" + f.objectHash + ".json":
			_, _ = w.Write(f.object)
		default:
			t.Errorf("unexpected request %s", r.URL.Path)
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(srv.Close)
	return h, srv
}

func (h *appPublicationHost) requests() []string {
	h.mu.Lock()
	defer h.mu.Unlock()
	return append([]string(nil), h.hits...)
}

// freshAppHome has no cache, no consent record and no plugin: only the app was installed.
func freshAppHome(t *testing.T) (home, cache string) {
	t.Helper()
	testenv.IsolateHome(t)
	home = os.Getenv("HOME")
	cache = filepath.Join(home, "cache")
	t.Setenv("MODELPLAN_CODEX", filepath.Join(home, "no-real-codex"))
	for name, value := range map[string]string{"MODELPLAN_CACHE": cache, "MODELPLAN_HISTORY": "", "MODELPLAN_READERS": "", "MODELPLAN_GEMINI": "", "MODELPLAN_GEMINI_HOME": "", "MODELPLAN_CODEX_ACCOUNT": "off", "MODELPLAN_CODEXBAR": "off"} {
		t.Setenv(name, value)
	}
	return home, cache
}

// seedAppCodexReading gives the cockpit a current subscription to answer for. The publication
// state stays absent.
func seedAppCodexReading(t *testing.T, home string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Join(home, ".codex"), 0700); err != nil {
		t.Fatal(err)
	}
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC().Truncate(time.Second)
	reading := map[string]any{"schemaVersion": 1, "status": "ok", "observedAt": now, "admission": state.CaptureStamp(consent.ScopeCodexRuntimeUsage), "windows": []any{map[string]any{"kind": "weekly", "usedPercent": 25, "remainingPercent": 75, "windowMinutes": 10080, "resetsAt": now.Add(time.Hour), "observedAt": now}}}
	path := filepath.Join(home, "cache", "observed", "codex-account.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, publicationJSON(t, reading), 0600); err != nil {
		t.Fatal(err)
	}
}

func buildAppBinary(t *testing.T) string {
	t.Helper()
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, raw)
	}
	return binary
}

func waitForAppPublication(t *testing.T, p *queryBinary, within time.Duration) map[string]json.RawMessage {
	t.Helper()
	deadline := time.Now().Add(within)
	for {
		reply := p.call("publication/get", map[string]any{})
		if _, failed := reply["error"]; !failed {
			return reply
		}
		if time.Now().After(deadline) {
			t.Fatalf("no publication %s after start: %s", within, reply["error"])
		}
		time.Sleep(50 * time.Millisecond)
	}
}

// The walkthrough's publication-fresh-profile finding through the real command: nothing but the
// app is installed, no consent has been given, and the publication still arrives by itself.
func TestAppServerFreshHomeFetchesPublicationWithoutConsent(t *testing.T) {
	_, cache := freshAppHome(t)
	f := newPublicationFixture(t, nil)
	host, srv := newAppPublicationHost(t, f, false)
	t.Setenv("MODELPLAN_BASE", srv.URL)
	p := startQueryBinaryCaps(t, buildAppBinary(t), []string{"rows", "consent", "publication"})

	reply := waitForAppPublication(t, p, 10*time.Second)
	if !strings.Contains(string(reply["result"]), f.id) {
		t.Fatalf("publication: %s", reply["result"])
	}
	st, err := (&store.Store{Dir: cache}).State()
	if err != nil || st.PublicationID != f.id || st.LastError != "" {
		t.Fatalf("state.json: %+v %v", st, err)
	}
	facts := p.call("consent/get", map[string]any{})
	var consentFacts wire.Envelope[wire.ConsentFacts]
	if err := json.Unmarshal(facts["result"], &consentFacts); err != nil {
		t.Fatal(err)
	}
	for _, scope := range consentFacts.Data.Scopes {
		if scope.State == wire.ConsentState("allowed") {
			t.Fatalf("publication sync needed a grant: %+v", scope)
		}
	}
	for _, request := range host.requests() {
		if !strings.HasPrefix(request, "GET /publications/") {
			t.Fatalf("request outside the publication: %s", request)
		}
	}
}

// The cockpit is told when the data arrives: an open cockpit reads no publication, then the
// rows event it already refreshes on brings the faders.
func TestAppServerCockpitFillsWhenPublicationArrives(t *testing.T) {
	home, _ := freshAppHome(t)
	seedAppCodexReading(t, home)
	f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		var data map[string]json.RawMessage
		if err := json.Unmarshal(doc["data"], &data); err != nil {
			t.Fatal(err)
		}
		data["models"] = publicationJSON(t, []any{map[string]any{"id": "openai-1", "name": "Synthetic openai-1", "developerId": "openai", "recommended": "medium", "harnessIds": map[string]any{}, "efforts": []any{map[string]any{"effort": "medium", "label": "Med", "ability": 50, "cost": 2, "time": nil}}}})
		data["lineups"] = json.RawMessage(`[]`)
		doc["data"] = publicationJSON(t, data)
	})
	host, srv := newAppPublicationHost(t, f, true)
	t.Setenv("MODELPLAN_BASE", srv.URL)
	p := startQueryBinaryCaps(t, buildAppBinary(t), []string{"rows", "cockpit", "cockpitDetailsV1"})
	if reply := p.call("rows/subscribe", map[string]any{}); reply["error"] != nil {
		t.Fatalf("rows/subscribe: %s", reply["error"])
	}
	query := func() *wire.CockpitPublication {
		t.Helper()
		reply := p.call("cockpit/query", map[string]any{})
		var envelope wire.Envelope[wire.CockpitData]
		if err := json.Unmarshal(reply["result"], &envelope); err != nil || envelope.Data.Details == nil {
			t.Fatalf("cockpit: %s %s %v", reply["result"], reply["error"], err)
		}
		return envelope.Data.Details.Publication
	}
	if got := query(); got != nil {
		t.Fatalf("publication before the host answered: %+v", got)
	}
	deadline := time.Now().Add(10 * time.Second)
	for len(host.requests()) == 0 {
		if time.Now().After(deadline) {
			t.Fatal("the app never asked for the publication")
		}
		time.Sleep(20 * time.Millisecond)
	}
	p.notifications = nil
	close(host.release)
	for !appRowsChanged(p) {
		if time.Now().After(deadline) {
			t.Fatal("no rows event after the publication arrived")
		}
		p.call("consent/get", map[string]any{}) // drains frames without touching the view
		time.Sleep(20 * time.Millisecond)
	}
	got := query()
	if got == nil || len(got.Models) != 1 || got.Models[0].ID != "openai-1" {
		t.Fatalf("cockpit after the rows event: %+v", got)
	}
}

func appRowsChanged(p *queryBinary) bool {
	for _, raw := range p.notifications {
		if strings.Contains(string(raw), `"rows/changed"`) {
			return true
		}
	}
	return false
}

// A host that cannot be reached leaves the engine answering, with the unavailable state, and
// reports nothing on the protocol's stderr (startQueryBinaryCaps fails the test if it does).
func TestAppServerUnreachableHostKeepsServing(t *testing.T) {
	home, cache := freshAppHome(t)
	seedAppCodexReading(t, home)
	t.Setenv("MODELPLAN_BASE", "http://127.0.0.1:1")
	p := startQueryBinaryCaps(t, buildAppBinary(t), []string{"rows", "cockpit", "cockpitDetailsV1", "publication"})
	deadline := time.Now().Add(10 * time.Second)
	for {
		st, err := (&store.Store{Dir: cache}).State()
		if err == nil && st.LastError != "" && !st.LastAttemptAt.IsZero() {
			break
		}
		if time.Now().After(deadline) {
			t.Fatalf("no recorded attempt: %+v %v", st, err)
		}
		time.Sleep(20 * time.Millisecond)
	}
	if reply := p.call("publication/get", map[string]any{}); reply["error"] == nil {
		t.Fatalf("publication without data: %s", reply["result"])
	}
	reply := p.call("cockpit/query", map[string]any{})
	var envelope wire.Envelope[wire.CockpitData]
	if err := json.Unmarshal(reply["result"], &envelope); err != nil || envelope.Data.Details == nil || envelope.Data.Details.Publication != nil {
		t.Fatalf("cockpit while unreachable: %s %s %v", reply["result"], reply["error"], err)
	}
}

// --offline never touches the network and --read-only never writes: neither fetches anything.
func TestAppServerOfflineAndReadOnlyFetchNothing(t *testing.T) {
	for _, flag := range []string{"--offline", "--read-only"} {
		t.Run(flag, func(t *testing.T) {
			_, cache := freshAppHome(t)
			if _, err := consent.EnsureStore(consent.Path()); err != nil { // --read-only needs a store
				t.Fatal(err)
			}
			host, srv := newAppPublicationHost(t, newPublicationFixture(t, nil), false)
			t.Setenv("MODELPLAN_BASE", srv.URL)
			p := startQueryBinaryCapsWithArgs(t, buildAppBinary(t), []string{"rows", "publication"}, flag)
			time.Sleep(500 * time.Millisecond)
			if reply := p.call("publication/get", map[string]any{}); reply["error"] == nil {
				t.Fatalf("publication: %s", reply["result"])
			}
			if got := host.requests(); len(got) != 0 {
				t.Fatalf("requests: %v", got)
			}
			if _, err := os.Stat(filepath.Join(cache, "state.json")); !os.IsNotExist(err) {
				t.Fatalf("state.json: %v", err)
			}
		})
	}
}
