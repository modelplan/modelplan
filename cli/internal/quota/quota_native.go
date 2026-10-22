package quota

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

// Native quota readers: this client asks the vendor's own usage endpoint with an API key the user
// keeps in an environment variable, for the providers connections.json sets to native. The key is
// read from the environment at the moment of the request, sent only to the vendor's fixed host and
// never written, logged or cached. Hosts are compiled in; configuration picks a region, never a
// URL. Like CodexBar's bridge, a refresh runs in the background at most every 10 minutes and the
// sanitised reading is cached in <cache>/observed/native.json. Ported from CodexBar's providers
// (MIT, github.com/steipete/CodexBar); see each reader for the upstream revision.

const (
	NativeEvery      = 10 * time.Minute
	nativeRetryAfter = 30 * time.Minute
	nativeKeep       = 6 * time.Hour
	nativeTimeout    = 20 * time.Second
	nativeMaxBody    = 1 << 20
)

// nativeReader is one compiled reader: its regions (the first is the default), the default key
// variable and the fetch, which returns a cache entry (Status ok or error, never the key).
type nativeReader struct {
	Regions []string
	KeyEnv  string
	Fetch   func(ctx context.Context, c *http.Client, region, key string, now time.Time) codexbarEntry
}

// nativeReaders: the registry. A provider without one stays on CodexBar.
var nativeReaders = map[string]*nativeReader{
	"zai":        zaiReader,
	"opencodego": opencodegoReader,
}

// NativeReader: the provider has a native reader, with its regions and default key variable.
func NativeReader(provider string) (regions []string, keyEnv string, ok bool) {
	n := nativeReaders[provider]
	if n == nil {
		return nil, "", false
	}
	return n.Regions, n.KeyEnv, true
}

type nativeSnap struct {
	SchemaVersion int             `json:"schemaVersion"`
	ObservedAt    time.Time       `json:"observedAt"`
	Providers     []codexbarEntry `json:"providers"`
}

func nativePath(cache string) string { return filepath.Join(cache, "observed", "native.json") }

func loadNative(cache string) *nativeSnap {
	if cache == "" {
		return nil
	}
	b, status := readBounded(nativePath(cache), 256<<10)
	if status != "" {
		return nil
	}
	var s nativeSnap
	if json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 {
		return nil
	}
	return &s
}

// NativeDue: a native provider runs and its cached reading is missing or old enough.
func NativeDue(p Paths, now time.Time) bool {
	on := active(p, BackendNative)
	if len(on) == 0 || p.Cache == "" {
		return false
	}
	s := loadNative(p.Cache)
	if s == nil {
		return true
	}
	by := map[string]codexbarEntry{}
	for _, e := range s.Providers {
		by[e.Provider] = e
	}
	for _, x := range on {
		e, ok := by[x.Provider]
		wait := NativeEvery
		if ok && e.Status != "ok" {
			wait = nativeRetryAfter
		}
		if !ok || now.Sub(s.ObservedAt) >= wait {
			return true
		}
	}
	return false
}

// nativeClient: tests point it at a local server.
var nativeClient = &http.Client{Timeout: nativeTimeout}

// RefreshNative asks each native provider once and caches the sanitised readings. One at a time.
func RefreshNative(ctx context.Context, p Paths, now time.Time) error {
	on := active(p, BackendNative)
	if len(on) == 0 {
		return errors.New("no native provider is on")
	}
	unlock, ok := lockFile(filepath.Join(p.Cache, "observed", "native.lock"), now, time.Duration(len(on)+1)*nativeTimeout)
	if !ok {
		return errors.New("another refresh is running")
	}
	defer unlock()
	home, _ := os.UserHomeDir()
	s := &nativeSnap{SchemaVersion: 1, ObservedAt: now.UTC(), Providers: []codexbarEntry{}}
	for _, x := range on {
		key := os.Getenv(x.KeyEnv)
		e := nativeReaders[x.Provider].Fetch(ctx, nativeClient, x.Region, key, now)
		e.Provider, e.Source = x.Provider, "api"
		if e.Status == "ok" && !IdentityOff() {
			e.SubscriptionRef = assignSubscription(p.Cache, "api-key:"+x.Provider, key, now) // a key is one subscription
		}
		if e.Error != "" {
			e.Error = clean(e.Error, home)
		}
		s.Providers = append(s.Providers, e)
	}
	b, _ := json.MarshalIndent(s, "", "  ")
	if err := os.MkdirAll(filepath.Dir(nativePath(p.Cache)), 0o700); err != nil {
		return err
	}
	return writeAtomic(nativePath(p.Cache), append(b, '\n'))
}

// getJSON: one GET with the key as a bearer token, bounded, decoded into v. The error names the
// HTTP status, never the key or the body.
func getJSON(ctx context.Context, c *http.Client, url, key string, v any) error {
	ctx, cancel := context.WithTimeout(ctx, nativeTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return errors.New("bad request")
	}
	req.Header.Set("Authorization", "Bearer "+key)
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "modelplan")
	resp, err := c.Do(req)
	if err != nil {
		if ctx.Err() != nil {
			return errors.New("timed out")
		}
		return errors.New("request failed")
	}
	defer resp.Body.Close()
	switch {
	case resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden:
		return errors.New("the API key was rejected (HTTP " + strconv.Itoa(resp.StatusCode) + ")")
	case resp.StatusCode != http.StatusOK:
		return errors.New("HTTP " + strconv.Itoa(resp.StatusCode))
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, nativeMaxBody+1))
	if err != nil || len(b) > nativeMaxBody {
		return errors.New("response too large or cut off")
	}
	if json.Unmarshal(b, v) != nil {
		return errors.New("unreadable response")
	}
	return nil
}

// applyNative adds one account per native provider with a recent usable reading, and one source
// status per native provider saying what was read or why not.
func applyNative(r *Report, p Paths, now time.Time) {
	ss, err := Selections(p)
	if err != nil {
		r.Sources = append(r.Sources, SourceStatus{Source: "connections", Status: "invalid", Reason: short(err.Error())})
		return
	}
	s := loadNative(p.Cache)
	by := map[string]codexbarEntry{}
	if s != nil {
		for _, e := range s.Providers {
			by[e.Provider] = e
		}
	}
	for _, x := range ss {
		if x.Backend != BackendNative {
			continue
		}
		st := SourceStatus{Source: "native:" + x.Provider}
		e, ok := by[x.Provider]
		switch {
		case x.Blocked == "no-native-reader":
			st.Status, st.Reason = "unsupported_schema", "no native reader for "+x.Provider+"; set its backend to codexbar-compat"
		case x.Blocked == "native-off":
			st.Status, st.Reason = "missing", "native readers are off (MODELPLAN_NATIVE)"
		case x.Blocked == "no-key" && !ok:
			st.Status, st.Reason = "missing", x.KeyEnv+" is not set where modelplan runs"
		case !ok:
			st.Status, st.Reason = "missing", "not read yet"
		case now.Sub(e.ObservedAt) > nativeKeep || e.ObservedAt.After(now.Add(5*time.Minute)):
			st.Status, st.Reason = "stale", "last reading older than 6 hours"
		case e.Status != "ok":
			st.Status, st.Reason = "unavailable", e.Error
		case len(e.Windows) == 0:
			st.Status, st.Reason = "empty", "no usage windows"
		default:
			st.Status = "ok"
			r.Accounts = append(r.Accounts, Account{Source: st.Source, Plan: e.Plan, ObservedAt: e.ObservedAt, Windows: append([]Window(nil), e.Windows...), Via: "native", Subscription: e.binding("api-key")})
		}
		r.Sources = append(r.Sources, st)
	}
}
