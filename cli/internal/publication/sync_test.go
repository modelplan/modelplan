package publication

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/store"
)

func hashOf(b []byte) string { h := sha256.Sum256(b); return hex.EncodeToString(h[:]) }

type fakeServer struct {
	pointer, manifest []byte
	objects           map[string][]byte
	etag              string
	hits              map[string]int
}

func publish(f *fakeServer, label string, ability float64, corrupt bool) string {
	client := []byte(`{"schemaVersion":1,"kind":"client","dependencies":{"models":"` + strings.Repeat("a", 64) + `","registry":"` + strings.Repeat("a", 64) + `","rules":"` + strings.Repeat("a", 64) + `","calendar":"` + strings.Repeat("a", 64) + `"},"evidence":[],"data":{"units":{"ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"},"models":[{"id":"m1","name":"Claude Opus 9","developerId":"anthropic","recommended":"medium","harnessIds":{"claude-code":["claude-opus-9"],"api":[],"codex":[]},"efforts":[{"effort":"medium","label":"Med","ability":` + jsonNum(ability) + `,"cost":2,"time":null}]}],"lineups":[],"resets":[],"windows":[]}}`)
	h := hashOf(client)
	stored := append([]byte(nil), client...)
	if corrupt {
		stored[len(stored)-2] = ' '
	}
	f.objects[h] = stored
	refs := map[string]component{}
	for _, name := range []string{"methods", "registry", "models", "plans", "rules", "news", "calendar"} {
		refs[name] = component{1, strings.Repeat("a", 64), 2}
	}
	refs["client"] = component{1, h, int64(len(client))}
	refsBody := []byte("{")
	for i, name := range []string{"methods", "registry", "models", "plans", "rules", "news", "calendar", "client"} {
		if i > 0 {
			refsBody = append(refsBody, ',')
		}
		key, _ := json.Marshal(name)
		refsBody = append(refsBody, key...)
		refsBody = append(refsBody, ':')
		refsBody = append(refsBody, orderedJSON(refs[name])...)
	}
	refsBody = append(refsBody, '}')
	cv, _ := json.Marshal(label)
	core := orderedJSON(identityCore{json.RawMessage("1"), cv, json.RawMessage(`{"index":"unified-v03-estimator-0.1.0-internal","recommendation":"balanced-coding-absolute-v4"}`), refsBody})
	id := sum(core)[:24]
	f.manifest = append(core[:len(core)-1], []byte(`,"publicationId":"`+id+`","publishedAt":"2026-10-11T00:00:00Z"}`)...)
	f.pointer = canonical(map[string]any{"schemaVersion": 1, "publicationId": id, "manifestHash": hashOf(f.manifest)})
	f.etag = `W/"` + hashOf(f.pointer) + `"`
	return id
}

func jsonNum(v float64) string { b, _ := json.Marshal(v); return string(b) }

func (f *fakeServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.hits[r.URL.Path]++
	switch {
	case r.URL.Path == "/publications/current.json":
		if r.Header.Get("If-None-Match") == f.etag {
			w.WriteHeader(http.StatusNotModified)
			return
		}
		w.Header().Set("ETag", f.etag)
		w.Write(f.pointer)
	case strings.HasSuffix(r.URL.Path, "/manifest.json"):
		w.Write(f.manifest)
	case strings.HasPrefix(r.URL.Path, "/publications/objects/"):
		h := strings.TrimSuffix(strings.TrimPrefix(r.URL.Path, "/publications/objects/"), ".json")
		w.Write(f.objects[h])
	default:
		http.NotFound(w, r)
	}
}

func TestSyncVerifySwitchAndKeepLastGood(t *testing.T) {
	f := &fakeServer{objects: map[string][]byte{}, hits: map[string]int{}}
	first := publish(f, "first", 50, false)
	srv := httptest.NewServer(f)
	defer srv.Close()

	t.Setenv("MODELPLAN_CACHE", t.TempDir())
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	c, err := New(srv.URL, st, "test")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Date(2026, 10, 11, 0, 0, 0, 0, time.UTC)
	c.Now = func() time.Time { return now }
	ctx := context.Background()

	if _, _, err := Load(st); err != ErrNoData {
		t.Fatalf("empty cache: %v", err)
	}
	res, err := c.Sync(ctx, false)
	if err != nil || !res.Switched {
		t.Fatalf("first sync: %+v %v", res, err)
	}
	d, _, err := Load(st)
	if err != nil || *d.Model("m1").Rec().Ability != 50 {
		t.Fatalf("load: %v", err)
	}

	// within the check interval: no request at all
	if res, _ := c.Sync(ctx, false); !res.Skipped || f.hits["/publications/current.json"] != 1 {
		t.Fatalf("expected skip, got %+v hits=%v", res, f.hits)
	}
	// forced: conditional request answers 304
	if res, err := c.Sync(ctx, true); err != nil || !res.NotModified {
		t.Fatalf("expected 304, got %+v %v", res, err)
	}

	// a new publication whose object fails verification must not replace the cache
	publish(f, "bbbbbbbbbbbbbbbbbbbbbbbb", 60, true)
	if _, err := c.Sync(ctx, true); err == nil {
		t.Fatal("corrupt object accepted")
	}
	d, s, _ := Load(st)
	if s.PublicationID != first || *d.Model("m1").Rec().Ability != 50 || s.LastError == "" {
		t.Fatalf("last good not kept: %+v", s)
	}

	// a good one switches
	last := publish(f, "last", 70, false)
	if res, err := c.Sync(ctx, true); err != nil || !res.Switched {
		t.Fatalf("good sync: %+v %v", res, err)
	}
	d, s, _ = Load(st)
	if s.PublicationID != last || *d.Model("m1").Rec().Ability != 70 || s.LastError != "" {
		t.Fatalf("switch: %+v", s)
	}
	if m := d.Match("claude-code", "claude-opus-9"); m == nil || m.ID != "m1" {
		t.Fatal("reviewed harness identifier did not match")
	}
}

func jitterClient(t *testing.T) (*Client, *fakeServer) {
	t.Helper()
	f := &fakeServer{objects: map[string][]byte{}, hits: map[string]int{}}
	publish(f, "jitter", 50, false)
	srv := httptest.NewServer(f)
	t.Cleanup(srv.Close)
	t.Setenv("MODELPLAN_CACHE", t.TempDir())
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	c, err := New(srv.URL, st, "test")
	if err != nil {
		t.Fatal(err)
	}
	return c, f
}

func TestSyncJitterBoundsAndPersistedInterval(t *testing.T) {
	for _, delay := range []time.Duration{0, 30 * time.Second, time.Minute} {
		t.Run(delay.String(), func(t *testing.T) {
			c, f := jitterClient(t)
			now := time.Date(2026, 10, 26, 0, 0, 0, 0, time.UTC)
			c.Now = func() time.Time { return now }
			c.Jitter = func() time.Duration { return delay }
			waits := 0
			c.wait = func(context.Context, time.Duration) error {
				t.Fatal("first check waited")
				return nil
			}
			if res, err := c.Sync(context.Background(), false); err != nil || !res.Switched {
				t.Fatalf("first check: %+v %v", res, err)
			}
			state, err := c.Store.State()
			if err != nil || !state.NextCheckAt.Equal(now.Add(MinCheckInterval+delay)) {
				t.Fatalf("next check: %+v %v", state, err)
			}

			// Reopen the client to prove the interval survives separate CLI invocations.
			c, err = New(c.Base, c.Store, "test")
			if err != nil {
				t.Fatal(err)
			}
			c.Now = func() time.Time { return now }
			// The pre-request delay and the following interval use independent draws.
			draws := 0
			c.Jitter = func() time.Duration {
				draws++
				if draws == 1 {
					return delay
				}
				return time.Minute - delay
			}
			c.wait = func(_ context.Context, got time.Duration) error {
				waits++
				if got != delay || f.hits["/publications/current.json"] != 1 {
					t.Fatalf("delay=%v, pointer hits=%v", got, f.hits)
				}
				now = now.Add(got)
				return nil
			}
			now = state.NextCheckAt.Add(-time.Nanosecond)
			if res, err := c.Sync(context.Background(), false); err != nil || !res.Skipped || draws != 0 {
				t.Fatalf("early check: %+v %v draws=%d", res, err, draws)
			}
			now = state.NextCheckAt
			if res, err := c.Sync(context.Background(), false); err != nil || !res.NotModified {
				t.Fatalf("due check/ETag 304: %+v %v", res, err)
			}
			state, err = c.Store.State()
			if err != nil || !state.CheckedAt.Equal(now) || !state.NextCheckAt.Equal(now.Add(MinCheckInterval+time.Minute-delay)) {
				t.Fatalf("rescheduled check: %+v %v", state, err)
			}
			wantWaits := 1
			if delay == 0 {
				wantWaits = 0
			}
			if waits != wantWaits || draws != 2 || f.hits["/publications/current.json"] != 2 {
				t.Fatalf("waits=%d draws=%d hits=%v", waits, draws, f.hits)
			}
		})
	}
}

func TestSyncNoDelayForCacheExplicitAndFirstChecks(t *testing.T) {
	c, f := jitterClient(t)
	now := time.Now()
	c.Now = func() time.Time { return now }
	c.Jitter = func() time.Duration { return time.Minute }
	c.wait = func(context.Context, time.Duration) error {
		t.Fatal("first, explicit or offline/cache read waited")
		return nil
	}
	if _, err := c.Sync(context.Background(), false); err != nil {
		t.Fatal(err)
	}
	now = now.Add(time.Hour)
	before, err := os.ReadFile(c.Store.Dir + "/state.json")
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := Load(c.Store); err != nil {
		t.Fatal(err)
	}
	after, err := os.ReadFile(c.Store.Dir + "/state.json")
	if err != nil || !bytes.Equal(before, after) || f.hits["/publications/current.json"] != 1 {
		t.Fatalf("offline/cache read changed state or used network: %v %v", err, f.hits)
	}
	c.NoCheckDelay = true
	if _, err := c.Sync(context.Background(), false); err != nil {
		t.Fatal(err)
	}
	c.NoCheckDelay = false
	if _, err := c.Sync(context.Background(), true); err != nil {
		t.Fatal(err)
	}
}

func TestCheckDelayDeadlineBudget(t *testing.T) {
	now := time.Now()
	for _, tc := range []struct {
		name      string
		remaining time.Duration
		timeout   time.Duration
		want      time.Duration
	}{
		{"ample budget", 2 * time.Minute, 20 * time.Second, time.Minute},
		{"capped", 75 * time.Second, 20 * time.Second, 15 * time.Second},
		{"foreground deadline", 30 * time.Second, 20 * time.Second, 0},
		{"first hook deadline", 3 * time.Second, 20 * time.Second, 0},
		{"exact request budget", time.Minute, 20 * time.Second, 0},
		{"expired", -time.Second, 20 * time.Second, 0},
		{"unbounded HTTP", 2 * time.Minute, 0, 0},
	} {
		t.Run(tc.name, func(t *testing.T) {
			c := &Client{HTTP: &http.Client{Timeout: tc.timeout}}
			ctx, cancel := context.WithDeadline(context.Background(), now.Add(tc.remaining))
			defer cancel()
			if got := c.checkDelay(ctx, time.Minute, now); got != tc.want {
				t.Fatalf("delay=%v want=%v", got, tc.want)
			}
		})
	}
	c := &Client{HTTP: &http.Client{Timeout: 20 * time.Second}}
	if got := c.checkDelay(context.Background(), time.Minute, now); got != time.Minute {
		t.Fatalf("no deadline: delay=%v", got)
	}
}

func TestSyncShortDeadlineSkipsDelay(t *testing.T) {
	c, _ := jitterClient(t)
	c.Jitter = func() time.Duration { return time.Minute }
	c.wait = func(context.Context, time.Duration) error {
		t.Fatal("short deadline waited")
		return nil
	}
	if _, err := c.Sync(context.Background(), false); err != nil {
		t.Fatal(err)
	}
	c.Now = func() time.Time { return time.Now().Add(time.Hour) }
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if res, err := c.Sync(ctx, false); err != nil || !res.NotModified {
		t.Fatalf("short deadline check: %+v %v", res, err)
	}
}

func TestSyncLegacyCacheAndCanceledDelay(t *testing.T) {
	c, f := jitterClient(t)
	c.Jitter = func() time.Duration { return time.Minute }
	if _, err := c.Sync(context.Background(), false); err != nil {
		t.Fatal(err)
	}
	state, err := c.Store.State()
	if err != nil {
		t.Fatal(err)
	}
	state.NextCheckAt = time.Time{} // older clients did not persist a jittered interval
	if err := c.Store.SaveState(state); err != nil {
		t.Fatal(err)
	}
	now := state.CheckedAt.Add(MinCheckInterval - time.Nanosecond)
	c.Now = func() time.Time { return now }
	if res, err := c.Sync(context.Background(), false); err != nil || !res.Skipped {
		t.Fatalf("legacy interval: %+v %v", res, err)
	}
	now = now.Add(time.Nanosecond)
	c.wait = func(_ context.Context, delay time.Duration) error {
		if delay != time.Minute {
			t.Fatalf("delay=%v", delay)
		}
		return context.Canceled
	}
	if _, err := c.Sync(context.Background(), false); !errors.Is(err, context.Canceled) {
		t.Fatalf("canceled delay: %v", err)
	}
	after, err := c.Store.State()
	if err != nil || after != state || f.hits["/publications/current.json"] != 1 {
		t.Fatalf("canceled delay changed state or used network: %+v %v %v", after, err, f.hits)
	}
}

func TestWaitForCheckCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := waitForCheck(ctx, time.Minute); !errors.Is(err, context.Canceled) {
		t.Fatalf("wait did not honor cancellation: %v", err)
	}
}

func TestRejectsPlainHTTPExceptLocalhost(t *testing.T) {
	st := &store.Store{Dir: t.TempDir()}
	if _, err := New("http://example.com", st, "t"); err == nil {
		t.Fatal("plain http accepted")
	}
	if _, err := New("http://127.0.0.1:3031", st, "t"); err != nil {
		t.Fatal(err)
	}
}

func TestDependencyAndIdentityVerification(t *testing.T) {
	f := &fakeServer{objects: map[string][]byte{}, hits: map[string]int{}}
	publish(f, "fixture", 50, false)
	var m manifest
	_ = json.Unmarshal(f.manifest, &m)
	ob := f.objects[m.Components["client"].Hash]
	if err := verify(m, ob); err != nil {
		t.Fatal(err)
	}
	bad := m
	bad.PublicationID = strings.Repeat("0", 24)
	if err := verify(bad, ob); err == nil {
		t.Fatal("wrong graph identity accepted")
	}
	var c map[string]any
	_ = json.Unmarshal(ob, &c)
	c["dependencies"].(map[string]any)["models"] = strings.Repeat("b", 64)
	changed := canonical(c)
	refs := map[string]component{}
	for k, v := range m.Components {
		refs[k] = v
	}
	refs["client"] = component{1, hashOf(changed), int64(len(changed))}
	bad = m
	bad.Components = refs
	bad.identityCore = canonical(map[string]any{"schemaVersion": bad.SchemaVersion, "comparisonVersion": bad.ComparisonVersion, "methods": bad.Methods, "components": refs})
	bad.PublicationID = sum(bad.identityCore)[:24]
	if err := verify(bad, changed); err == nil {
		t.Fatal("dependency mismatch accepted")
	}
}

func TestStorageEnvelope(t *testing.T) {
	plain := bytes.Repeat([]byte("x"), 5000)
	var compressed bytes.Buffer
	w := gzip.NewWriter(&compressed)
	_, _ = w.Write(plain)
	_ = w.Close()
	body := append([]byte{'M', 'P', 'G', 'Z', '1', 0, 0, 0, 0, 0}, compressed.Bytes()...)
	binary.BigEndian.PutUint32(body[6:10], 5000)
	out, err := decodeStorage(body)
	if err != nil || !bytes.Equal(out, plain) {
		t.Fatal("compressed body failed", err)
	}
	body[len(body)-1] ^= 1
	if _, err := decodeStorage(body); err == nil {
		t.Fatal("corrupt gzip accepted")
	}
	binary.BigEndian.PutUint32(body[6:10], maxObjectBytes+1)
	if _, err := decodeStorage(body); err == nil {
		t.Fatal("oversized decoded body accepted")
	}
}

func TestRealProducerManifestIdentity(t *testing.T) {
	b, err := os.ReadFile("testdata/manifest-eight-components.json")
	if err != nil {
		t.Fatal(err)
	}
	var m manifest
	if err = json.Unmarshal(b, &m); err != nil {
		t.Fatal(err)
	}
	if got := manifestIdentity(m); got != m.PublicationID {
		t.Fatalf("producer identity mismatch: got %s want %s", got, m.PublicationID)
	}
}

func TestThinClientAcceptsCompactComponentsAndLazyExtras(t *testing.T) {
	f := &fakeServer{objects: map[string][]byte{}, hits: map[string]int{}}
	publish(f, "compact", 70, false)
	var m manifest
	if err := json.Unmarshal(f.manifest, &m); err != nil {
		t.Fatal(err)
	}
	for name, r := range m.Components {
		if name != "client" {
			r.SchemaVersion = 2
			r.Bytes = 2500000
			m.Components[name] = r
		}
	}
	m.Components["display"] = component{2, strings.Repeat("b", 64), 100000}
	m.Components["plan-value"] = component{2, strings.Repeat("c", 64), 1000000}
	// A kind this CLI does not read is accepted and never fetched.
	m.Components["calendar-week-zh"] = component{2, strings.Repeat("d", 64), 300000}
	refs := []byte("{")
	for i, name := range []string{"methods", "registry", "models", "plans", "rules", "news", "calendar", "client", "plan-value", "display", "calendar-week-zh"} {
		if i > 0 {
			refs = append(refs, ',')
		}
		key, _ := json.Marshal(name)
		refs = append(refs, key...)
		refs = append(refs, ':')
		refs = append(refs, orderedJSON(m.Components[name])...)
	}
	refs = append(refs, '}')
	core := orderedJSON(identityCore{json.RawMessage("1"), json.RawMessage(`"compact"`), json.RawMessage(`{"index":"unified-v03-estimator-0.1.0-internal","recommendation":"balanced-coding-absolute-v4"}`), refs})
	id := sum(core)[:24]
	f.manifest = append(core[:len(core)-1], []byte(`,"publicationId":"`+id+`","publishedAt":"2026-10-13T00:00:00Z"}`)...)
	f.pointer = canonical(map[string]any{"schemaVersion": 1, "publicationId": id, "manifestHash": hashOf(f.manifest)})
	srv := httptest.NewServer(f)
	defer srv.Close()
	t.Setenv("MODELPLAN_CACHE", t.TempDir())
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	client, err := New(srv.URL, st, "fixture")
	if err != nil {
		t.Fatal(err)
	}
	result, err := client.Sync(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if result.PublicationID != id {
		t.Fatalf("wrong publication: %+v", result)
	}
	if len(f.hits) != 3 {
		t.Fatalf("thin client fetched non-client components: %+v", f.hits)
	}
}
