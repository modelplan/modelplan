package quota

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
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
// variable ("" for a reader that asks the agent's own CLI, which keeps the sign-in) and the fetch,
// which returns a cache entry (Status ok or error, never the key).
type nativeReader struct {
	Name     string
	Regions  []string
	KeyEnv   string
	Collect  func(ctx context.Context, c *http.Client, cache string, now time.Time) codexbarEntry
	Fetch    func(ctx context.Context, c *http.Client, region, key string, now time.Time) codexbarEntry
	Managed  func(context.Context, *http.Client, readerContext) readerOutcome
	Profiles func() []ReaderProfile
}

// nativeReaders: the registry. A provider without one stays on CodexBar.
var nativeReaders = map[string]*nativeReader{
	"antigravity": antigravityReader,
	"claude":      claudeAccountReader,
	"zai":         zaiReader,
	"kimi":        kimiReader,
	"cursor":      cursorReader,
	"minimax":     minimaxReader,
	"opencodego":  opencodegoReader,
	"kiro":        kiroReader,
	"copilot":     copilotReader,
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
	for provider, n := range nativeReaders {
		if n.Managed != nil && managedDue(p, provider, now) {
			return true
		}
	}
	on := active(p, BackendNative)
	legacy := on[:0]
	for _, x := range on {
		if nativeReaders[x.Provider].Managed == nil {
			legacy = append(legacy, x)
		}
	}
	on = legacy
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
		if nativeReaders[x.Provider].Managed != nil {
			continue
		}
		e, ok := by[x.Provider]
		wait := NativeEvery
		if ok && e.Status != "ok" {
			wait = nativeRetryAfter
		}
		if !ok || (x.Provider == "cursor" && e.CursorState != cursorState()) || (x.Provider == "minimax" && (e.Region != x.Region || e.KeyEnv != x.KeyEnv || (!IdentityOff() && !minimaxCacheMatches(p.Cache, x, e)))) || (x.Provider == "kimi" && !kimiCacheMatches(p.Cache, x, e)) || now.Sub(s.ObservedAt) >= wait {
			return true
		}
	}
	return false
}

// nativeClient: tests point it at a local server.
var nativeClient = &http.Client{Timeout: nativeTimeout}

// RefreshNative asks each native provider once and caches the sanitised readings. One at a time.
func RefreshNative(ctx context.Context, p Paths, now time.Time) error {
	admission, err := consent.ReaderLockContext(ctx)
	if err != nil {
		return err
	}
	defer admission()
	state, err := consent.Load(consent.Path())
	if err != nil {
		return err
	}
	on := active(p, BackendNative)
	legacy := on[:0]
	for _, x := range on {
		if nativeReaders[x.Provider].Managed == nil {
			legacy = append(legacy, x)
		}
	}
	on = legacy
	managed := []string{}
	for provider, n := range nativeReaders {
		if n.Managed != nil {
			if _, allowed := readerAllowed(p, provider); allowed {
				managed = append(managed, provider)
			}
		}
	}
	if len(on) == 0 && len(managed) == 0 {
		return errors.New("no native provider is on")
	}
	unlock, ok := lockFile(filepath.Join(p.Cache, "observed", "native.lock"), now, time.Duration(len(on)+len(managed)+1)*nativeTimeout)
	if !ok {
		return errors.New("another refresh is running")
	}
	defer unlock()
	sort.Strings(managed)
	for _, provider := range managed {
		if err := refreshManaged(ctx, p, provider, now); err != nil {
			return err
		}
	}
	if len(on) == 0 {
		return nil
	}
	home, _ := os.UserHomeDir()
	s := &nativeSnap{SchemaVersion: 1, ObservedAt: now.UTC(), Providers: []codexbarEntry{}}
	for _, x := range on {
		if !consent.CurrentGeneration(state.Generation) {
			return errors.New("consent changed; refresh stopped")
		}
		key := os.Getenv(x.KeyEnv)
		var e codexbarEntry
		n := nativeReaders[x.Provider]
		if n.Managed != nil {
			continue
		}
		if n.Collect != nil {
			e = n.Collect(ctx, nativeClient, p.Cache, now)
		} else {
			e = n.Fetch(ctx, nativeClient, x.Region, key, now)
		}
		e.Provider, e.Source = x.Provider, "api"
		if x.Provider == "kimi" || x.Provider == "minimax" {
			e.Region, e.KeyEnv = x.Region, x.KeyEnv
		}
		if x.Provider == "copilot" {
			e.Source = "runtime"
		}
		if e.Status == "ok" && key != "" && !IdentityOff() {
			e.SubscriptionRef = assignSubscription(p.Cache, nativeIdentityBasis(x), key, now) // a key is one subscription
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
	return consent.Publish(state.Generation, func() error { return writeAtomic(nativePath(p.Cache), append(b, '\n')) })
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
	for provider, n := range nativeReaders {
		if n.Managed != nil {
			applyManaged(r, p, provider, now)
		}
	}
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
		if n := nativeReaders[x.Provider]; n != nil && n.Managed != nil {
			continue
		}
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
		case x.Blocked == "no-key" && (!ok || x.Provider == "kimi" || x.Provider == "minimax"):
			st.Status, st.Reason = "missing", x.KeyEnv+" is not set where modelplan runs"
		case x.Provider == "kimi" && ok && !kimiCacheMatches(p.Cache, x, e):
			st.Status, st.Reason = "missing", "the selected Kimi key or region changed; refresh required"
		case x.Provider == "cursor" && ok && (e.CursorState == "" || e.CursorState != cursorState()):
			st.Status, st.Reason = "missing", "Cursor sign-in state changed or is unavailable; refresh required"
		case x.Provider == "minimax" && ok && !minimaxCacheMatches(p.Cache, x, e):
			st.Status, st.Reason = "missing", "MiniMax key, region or identity setting changed; refresh required"
		case !ok:
			st.Status, st.Reason = "missing", "not read yet"
		case x.Provider == "kimi" && now.Sub(e.ObservedAt) > staleAfter:
			st.Status, st.Reason = "stale", "Kimi reading older than 60 minutes"
		case now.Sub(e.ObservedAt) > nativeKeep || e.ObservedAt.After(now.Add(5*time.Minute)):
			st.Status, st.Reason = "stale", "last reading older than 6 hours"
		case e.Status != "ok":
			st.Status, st.Reason = "unavailable", e.Error
		case len(e.Windows) == 0:
			st.Status, st.Reason = "empty", "no usage windows"
		default:
			st.Status = "ok"
			windows := append([]Window(nil), e.Windows...)
			basis := "api-key"
			if x.Provider == "cursor" {
				basis = "cursor-auth"
			}
			r.Accounts = append(r.Accounts, Account{Source: st.Source, Plan: e.Plan, ObservedAt: e.ObservedAt, Windows: windows, Via: "native", Subscription: e.binding(basis)})
		}
		r.Sources = append(r.Sources, st)
	}
}

func nativeIdentityBasis(x Selection) string {
	if x.Provider == "kimi" || x.Provider == "minimax" {
		return "api-key:" + x.Provider + ":" + x.Region
	}
	return "api-key:" + x.Provider
}
func kimiCacheMatches(cache string, x Selection, e codexbarEntry) bool {
	if e.Region != x.Region || e.KeyEnv != x.KeyEnv {
		return false
	}
	if e.Status != "ok" || IdentityOff() {
		return true
	}
	ref := lookupSubscription(cache, nativeIdentityBasis(x), os.Getenv(x.KeyEnv))
	return ref != "" && ref == e.SubscriptionRef
}
