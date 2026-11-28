package quota

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/keychain"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
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
	Budget   *nativeReadBudget
	// LoginFiles: the profile's sign-in files besides its AccountFile, stamped (never opened) so
	// a new sign-in can end a failure back-off (G3-103). They are not part of the profile key.
	LoginFiles func(ReaderProfile) []string
}

// Shared by saved-login and existing explicitly configured key routes. Callers
// hold native.lock while reserving/finishing; Due reads ModelPlan state only.
type nativeReadBudget struct {
	Due     func(string, time.Time) bool
	Reserve func(string, time.Time) error
	Finish  func(string, time.Time) error
}

func (n *nativeReader) budgetDue(cache string, now time.Time) bool {
	return n.Budget == nil || n.Budget.Due(cache, now)
}
func (n *nativeReader) reserveBudget(cache string, now time.Time) error {
	if n.Budget == nil {
		return nil
	}
	return n.Budget.Reserve(cache, now)
}
func (n *nativeReader) finishBudget(cache string, next time.Time) error {
	if n.Budget == nil {
		return nil
	}
	return n.Budget.Finish(cache, next)
}

func nativePrivacyAllows() bool {
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("MODELPLAN_READERS")))
	return mode == "" || mode == "automatic" || mode == "passive"
}

func legacyNativeReader(p Paths, provider string) bool {
	n := nativeReaders[provider]
	if n == nil {
		return true
	}
	if n.Managed == nil {
		return true
	}
	if n.Fetch == nil {
		return false
	}
	if p.ReaderAccess != nil {
		if _, exists := p.ReaderAccess.Grants[provider]; exists {
			return false
		}
	}
	return true
}

// nativeReaders: the registry. A provider without one stays on CodexBar.
var nativeReaders = map[string]*nativeReader{
	"antigravity": antigravityReader,
	"grok":        grokReader,
	"gemini":      geminiReader,
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

const zaiMembershipKey = "zaiMembership"

type nativeSnap struct {
	SchemaVersion int                              `json:"schemaVersion"`
	ObservedAt    time.Time                        `json:"observedAt"`
	Providers     []codexbarEntry                  `json:"providers"`
	ZaiMembership map[string]*consent.CaptureStamp `json:"zaiMembership,omitempty"`
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
	if !nativePrivacyAllows() {
		return false
	}
	if claudeSessionsDue(p, now) {
		return true
	}
	for provider, n := range nativeReaders {
		if n.Managed != nil && managedDue(p, provider, now) {
			return true
		}
	}
	on := active(p, BackendNative)
	legacy := on[:0]
	for _, x := range on {
		if legacyNativeReader(p, x.Provider) && nativeReaders[x.Provider].budgetDue(p.Cache, now) {
			legacy = append(legacy, x)
		}
	}
	on = legacy
	if len(on) == 0 || p.Cache == "" {
		return false
	}
	by := map[string]codexbarEntry{}
	if s := loadNative(p.Cache); s != nil {
		for _, e := range s.Providers {
			by[e.Provider] = e
		}
	}
	for _, x := range on {
		if legacyNativeDue(p.Cache, x.Provider, by[x.Provider], now) || x.Provider == "antigravity" && antigravityRetryDue(p) {
			return true
		}
	}
	return false
}

// nativeClient: tests point it at a local server.
var nativeClient = &http.Client{Timeout: nativeTimeout}

// RefreshNative asks each due native provider once and caches the sanitised readings. One at a time.
func RefreshNative(ctx context.Context, p Paths, now time.Time) error {
	return refreshNative(ctx, p, now, false)
}

// RefreshNativeProviders narrows the existing dispatcher to compiled provider
// IDs. It shares all normal locks, reservations, collectors and publication.
func RefreshNativeProviders(ctx context.Context, p Paths, now time.Time, providers []string) error {
	selected := map[string]bool{}
	for _, provider := range providers {
		selected[provider] = true
	}
	return refreshNativeSelected(ctx, p, now, false, selected)
}
func refreshNative(ctx context.Context, p Paths, now time.Time, diagnostic bool) error {
	return refreshNativeSelected(ctx, p, now, diagnostic, nil)
}
func refreshNativeSelected(ctx context.Context, p Paths, now time.Time, diagnostic bool, selected map[string]bool) error {
	if !nativePrivacyAllows() || ctx.Err() != nil {
		return errors.New("personal readers are suspended")
	}
	admission, err := consent.ReaderLockContext(ctx)
	if err != nil {
		return err
	}
	defer admission()
	state, err := consent.Load(consent.Path())
	if err != nil {
		return err
	}
	if p.Admission != nil && p.Admission.Fence() != state.Fence() {
		return errors.New("consent changed; refresh stopped")
	}
	// Classify the provider file only during a live, admitted read, under the
	// consent reader lock. Route discovery itself remains metadata-only.
	if g, ok := p.ReaderAccessGrant("zai"); ok && g.ConfigSource != nil && g.ConfigSource.Tool == "zcode" &&
		(selected == nil || selected["zai"]) && (g.StillValid == nil || g.StillValid()) {
		if zcodeProviderFileKeyless(g.ConfigSource.SettingsPath) {
			// Paths is passed by value but its grants map is shared with callers.
			// Reselect only this refresh; planners may be reading the original map.
			grants := make(map[string]ReaderGrant, len(p.ReaderAccess.Grants))
			for id, grant := range p.ReaderAccess.Grants {
				grants[id] = grant
			}
			p.ReaderAccess = &ReaderAccess{Grants: grants}
			home, _ := os.UserHomeDir()
			_, mode := consent.Current()
			applyZCodeLogin(&p, home, state, mode, glmSourceConfigured(p))
		}
	}
	if scope, _ := ctx.Value(refreshScopeKey{}).(string); scope != "" && !zaiScopeMatches(p, scope) {
		return errors.New("reader scope does not match selected route")
	}
	sessionRead := false
	if selected == nil && !diagnostic {
		sessionRead = refreshProductionClaudeSessions(ctx, p, now)
	} else if selected == nil && claudeSessionsDue(p, now) && diagnosticSessionDue(p, now) {
		if err := reserveReaderAttempt(p.Cache, "claude-session", now.Add(5*time.Minute)); err != nil {
			return err
		}
		sessionRead = refreshProductionClaudeSessions(ctx, p, now)
	}
	on := active(p, BackendNative)
	legacy := on[:0]
	for _, x := range on {
		if (selected == nil || selected[x.Provider]) && legacyNativeReader(p, x.Provider) {
			legacy = append(legacy, x)
		}
	}
	on = legacy
	managed := []string{}
	for provider, n := range nativeReaders {
		if (selected == nil || selected[provider]) && n.Managed != nil {
			if _, allowed := readerAllowed(p, provider); allowed {
				managed = append(managed, provider)
			}
		}
	}
	if len(on) == 0 && len(managed) == 0 {
		if sessionRead {
			return nil
		}
		return errors.New("no native provider is on")
	}
	unlock, ok := lockFile(filepath.Join(p.Cache, "observed", "native.lock"), now, time.Duration(len(on)+len(managed)+1)*nativeTimeout)
	if !ok {
		return fmt.Errorf("another refresh is running: %w", consent.ErrReaderBusy)
	}
	defer unlock()
	var refreshErr error
	sort.Strings(managed)
	for _, provider := range managed {
		if err := refreshManaged(ctx, p, provider, now); err != nil {
			if !diagnostic {
				return err
			}
			refreshErr = err
		}
	}
	if len(on) == 0 {
		return refreshErr
	}
	home, _ := os.UserHomeDir()
	// The key generations before anything is read or carried over from the cache. A key replaced or removed after this
	// (manualkey.go bumps its provider's generation under the short snapshot-write lock) invalidates every reading of
	// that provider in this refresh, fresh or carried; the publish below compares under the same lock.
	// The generations and the cache are read together under lockManualKeys (short, no network), so they come from one
	// consistent state: a key change in progress holds the same lock for its whole cache removal and generation bump.
	unlockSnapshot, lockErr := lockManualKeys(p.Cache)
	if lockErr != nil {
		return lockErr
	}
	generations := manualKeyGenerations(p.Cache)
	previous := map[string]codexbarEntry{}
	old := loadNative(p.Cache)
	if old != nil {
		for _, entry := range old.Providers {
			previous[entry.Provider] = entry
		}
	}
	unlockSnapshot()
	s := &nativeSnap{SchemaVersion: 1, ObservedAt: now.UTC(), Providers: []codexbarEntry{},
		ZaiMembership: zaiMembership(p.Cache, old, state)}
	if selected != nil {
		ids := []string{}
		for provider := range previous {
			if !selected[provider] {
				ids = append(ids, provider)
			}
		}
		sort.Strings(ids)
		for _, provider := range ids {
			s.Providers = append(s.Providers, previous[provider])
		}
	}
	for _, x := range on {
		if !consent.CurrentFence(state.Fence()) {
			return errors.New("consent changed; refresh stopped")
		}
		var e codexbarEntry
		n := nativeReaders[x.Provider]
		// Antigravity "not running" is a quick re-check, and Settings Retry (a changed login generation) is
		// due at once: neither waits behind the outer failure reservation (the reader keeps its own gates).
		retry := x.Provider == "antigravity" && antigravityRetryDue(p)
		if !retry && (!n.budgetDue(p.Cache, now) || !legacyNativeDue(p.Cache, x.Provider, previous[x.Provider], now)) {
			if old, ok := previous[x.Provider]; ok {
				// Migrate an older capture's deadline before cache-only status
				// projection can change its generation or availability.
				next, err := legacyNativeNext(p.Cache, x.Provider, old)
				if err == nil && !next.IsZero() {
					if err := reserveReaderAttempt(p.Cache, x.Provider, next); err != nil {
						return err
					}
				}
				s.Providers = append(s.Providers, projectLegacyNativeCache(ctx, p, x.Provider, old, now))
			}
			continue
		}
		reserve := 5 * time.Minute
		if x.Provider == "antigravity" {
			reserve = antigravityRecheck // the reader's own gates hold the other states for five minutes or more
		}
		if err := reserveReaderAttempt(p.Cache, x.Provider, now.Add(reserve)); err != nil {
			if !diagnostic {
				return err
			}
			refreshErr = err
			continue
		}
		if err := n.reserveBudget(p.Cache, now); err != nil {
			return err
		}
		readerCtx := productionReaderContext(ctx, p, x.Provider)
		loginRoute := zcodeLoginRoute(p, x.Provider)
		var key string
		var hasManual bool
		if loginRoute {
			e = collectZaiConfig(readerCtx, nativeClient, p.Cache, now)
		} else {
			key = os.Getenv(x.KeyEnv)
			mk, pasted, manualErr := loadManualKeyChecked(p.Cache, x.Provider)
			hasManual = pasted
			if manualErr != nil {
				// The saved key file is unsafe or unreadable: fail this provider closed. Neither the saved key
				// nor a detected key is sent anywhere, so a different account's usage cannot be shown.
				e = codexbarEntry{Status: "error", ErrorCode: "file_unreadable", ObservedAt: now.UTC()}
			} else if hasManual && x.Provider == "zai" && !zaiPastedKeyAdmitted() {
				// macrev2-1162-2: a pasted GLM key kept after its own API-key Deny is never sent, whatever
				// else admitted this provider; the row shows the consent cause instead.
				e = codexbarEntry{Status: "error", ErrorCode: "consent_required", ObservedAt: now.UTC()}
			} else if hasManual {
				// D90, owner decision 2026-11-14: a key the user entered wins over any detected key and is
				// the only one used; it goes only to the compiled official host of its region.
				e, key = fetchManualKey(ctx, nativeClient, x.Provider, mk, now), mk.Key
			} else if g, ok := p.ReaderAccessGrant(x.Provider); ok && g.ConfigSource != nil {
				e = collectZaiConfig(readerCtx, nativeClient, p.Cache, now)
			} else if n.Collect != nil {
				e = n.Collect(readerCtx, nativeClient, p.Cache, now)
			} else {
				// D230: for OpenCode Go only OPENCODE_API_KEY is a detected key; OpenCode's own saved
				// login is checked for existence by detection and never read here.
				e = n.Fetch(ctx, nativeClient, x.Region, key, now)
			}
			// D90: the entered key can be replaced or removed while this read is in flight. The reading belongs to the key it
			// was made with (possibly another account's), so when the saved key changed, drop it instead of caching it; the
			// provider's request-budget reservation stays, and the next due read uses the new key.
			if mk2, has2, err2 := loadManualKeyChecked(p.Cache, x.Provider); (err2 != nil) != (manualErr != nil) || has2 != hasManual || mk2 != mk {
				continue
			}
		}
		if e.Status == "ok" {
			e.ErrorCode = ""
		} else {
			e.ErrorCode = ReaderErrorCode(e.ErrorCode)
			e.Error = e.ErrorCode
		}
		if e.Status == "ok" && e.Admission == nil {
			e.Admission = state.CaptureStamp(captureScope(p, x.Provider, false))
		}
		e.Provider, e.Source = x.Provider, "api"
		if x.Provider == "kimi" || x.Provider == "minimax" {
			e.Region, e.KeyEnv = x.Region, x.KeyEnv
		}
		if x.Provider == "copilot" {
			e.Source = "runtime"
		}
		if x.Provider == "zai" && hasManual {
			e.ManualKeyGeneration = generations["zai"] // S8: read with this pasted key
			old := previous[x.Provider]
			if zaiTransientFailure(e.ErrorCode) && old.ManualKeyGeneration == e.ManualKeyGeneration &&
				old.ManualKeyGeneration != 0 && captureAllowed(p, x.Provider, old.Admission, false) {
				e.ObservedAt, e.Windows, e.Plan = old.ObservedAt, old.Windows, old.Plan
				e.Admission, e.SubscriptionRef = old.Admission, old.SubscriptionRef
			}
		}
		if x.Provider == "zai" && !loginRoute && !IdentityOff() {
			// One row (owner 2026-11-14): Settings says when the entered key differs from a detected one.
			// Only the detected key's local reference is kept (the keyed-hash identity map, as for every
			// subscription); the key itself is read on this Mac, never sent, logged or stored.
			e.DetectedKeyRef = assignSubscription(p.Cache, zaiKeyBasis, detectedZaiKey(p, x), now)
		}
		// D369: ZCode's sign-in is never the basis of a reference; nothing derived from it is stored.
		if e.Status == "ok" && key != "" && !IdentityOff() {
			e.SubscriptionRef = assignSubscription(p.Cache, nativeIdentityBasis(x), key, now) // a key is one subscription
		}
		if e.Error != "" {
			e.Error = clean(e.Error, home)
		}
		next := now.Add(NativeEvery)
		if e.Status != "ok" {
			next = now.Add(nativeRetryAfter)
			if x.Provider == "antigravity" && e.ErrorCode == "runtime_missing" {
				next = now.Add(antigravityRecheck) // not running is not a failure
			}
		}
		if err := n.finishBudget(p.Cache, next); err != nil {
			return err
		}
		if err := reserveReaderAttempt(p.Cache, x.Provider, next); err != nil {
			if !diagnostic {
				return err
			}
			refreshErr = err
		}
		s.Providers = append(s.Providers, e)
	}
	if err := os.MkdirAll(filepath.Dir(nativePath(p.Cache)), 0o700); err != nil {
		return err
	}
	if err := consent.Publish(state.Fence(), func() error {
		// D90: the short snapshot-write lock (the one SetManualKey / RemoveManualKey take while they bump a generation).
		// A reading of a manual-key provider whose key changed since this refresh began is dropped, so the previous
		// account's quota is never published after a successful key change. Save waits here for at most one write.
		unlockKeys, err := lockManualKeys(p.Cache)
		if err != nil {
			return err
		}
		defer unlockKeys()
		current := manualKeyGenerations(p.Cache)
		kept := s.Providers[:0]
		for _, e := range s.Providers {
			if ManualKeyProvider(e.Provider) && current[e.Provider] != generations[e.Provider] {
				continue
			}
			kept = append(kept, e)
			if e.Provider == "zai" {
				rememberZaiMembership(s.ZaiMembership, &e, state)
			}
		}
		s.Providers = kept
		// A concurrent key change may have cleared GLM while this refresh was in
		// flight. Carry forward only the current detected-key reference, never the
		// reading from the old generation.
		if current["zai"] != generations["zai"] {
			if cached := loadNative(p.Cache); cached != nil {
				for _, e := range cached.Providers {
					if e.Provider == "zai" {
						s.Providers = append(s.Providers, glmReferenceOnly(e))
					}
				}
			}
		}
		if nativePublishHook != nil {
			nativePublishHook()
		}
		b, _ := json.MarshalIndent(s, "", "  ")
		return writeAtomic(nativePath(p.Cache), append(b, '\n'))
	}); err != nil {
		return err
	}
	return refreshErr
}

// nativePublishHook is a test seam: it runs inside the publish write, after the generations were compared.
var nativePublishHook func()

// getJSON: one GET with the key as a bearer token, bounded, decoded into v. The error names the
// HTTP status, never the key or the body.
func getJSON(ctx context.Context, c *http.Client, url, key string, v any) error {
	return getJSONAuthorization(ctx, c, url, "Bearer "+key, v)
}

// getJSONAuthorization is getJSON with the complete Authorization value supplied by the
// caller, for a vendor contract that takes the key without a scheme prefix.
func getJSONAuthorization(ctx context.Context, c *http.Client, url, authorization string, v any) error {
	return getJSONHeaders(ctx, c, url, map[string]string{"Authorization": authorization}, v)
}

// getJSONHeaders is getJSONAuthorization with further fixed request headers (each reader's request
// set pins which names are allowed).
func getJSONHeaders(ctx context.Context, c *http.Client, url string, headers map[string]string, v any) error {
	ctx, cancel := context.WithTimeout(ctx, nativeTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return codeError("other", "bad request")
	}
	for name, value := range headers {
		req.Header.Set(name, value)
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "modelplan")
	resp, err := c.Do(req)
	if err != nil {
		if ctx.Err() != nil {
			return codeError("timeout", "timed out")
		}
		return codeError(transportErrorCode(err), "request failed")
	}
	defer resp.Body.Close()
	switch {
	case resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden:
		return codeError(httpErrorCode(resp.StatusCode), "the API key was rejected (HTTP "+strconv.Itoa(resp.StatusCode)+")")
	case resp.StatusCode != http.StatusOK:
		return codeError(httpErrorCode(resp.StatusCode), "HTTP "+strconv.Itoa(resp.StatusCode))
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, nativeMaxBody+1))
	if err != nil || len(b) > nativeMaxBody {
		return codeError("schema_changed", "response too large or cut off")
	}
	if json.Unmarshal(b, v) != nil {
		return codeError("parse_error", "unreadable response")
	}
	return nil
}

func nativeProviderIDs() []string {
	ids := make([]string, 0, len(nativeReaders))
	for id := range nativeReaders {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	return ids
}

// applyNative adds one account per native provider with a recent usable reading, and one source
// status per native provider saying what was read or why not.
func applyNative(r *Report, p Paths, now time.Time) {
	// Apply local state after native accounts, including early-return paths.
	// Both Read and the production ReadPermitted flow pass through this hook.
	defer applyClaudeSessions(r, p, now)
	defer applyZCodeNoProviderFile(r, p)
	ss, err := Selections(p)
	if err != nil {
		r.Sources = append(r.Sources, SourceStatus{Source: "connections", Status: "invalid", Reason: errorCode(err), ErrorCode: errorCode(err)})
		return
	}
	legacySelections := map[string]bool{}
	for _, s := range ss {
		if legacyNativeReader(p, s.Provider) {
			legacySelections[s.Provider] = true
		}
	}
	// Sorted, so the report (and every snapshot built from it) has one order; map order
	// changed the sources between identical reads and published a new snapshot (G3-147).
	for _, provider := range nativeProviderIDs() {
		if n := nativeReaders[provider]; n.Managed != nil && !legacySelections[provider] {
			if _, pending := PolicyPending(provider); pending {
				if p.ReaderAccess == nil {
					// Legacy cache-only readers report the veto only when a retained capture
					// exists; an unrelated fresh read must not invent provider membership.
					if _, err := os.Stat(readerPath(p.Cache, provider)); err == nil || !os.IsNotExist(err) {
						r.Sources = append(r.Sources, policyPendingSource(provider))
					}
				} else if _, exists := p.ReaderAccess.Grants[provider]; exists {
					r.Sources = append(r.Sources, policyPendingSource(provider))
				}
				continue
			}
			if p.ReaderAccess != nil {
				if _, allowed := readerAllowed(p, provider); !allowed {
					continue
				}
			}
			applyManaged(r, p, provider, now)
		}
	}
	s := loadNative(p.Cache)
	admission := admissionFor(p)
	if admission.Mode() == consent.Automatic && !nativeOff() {
		_, pending := PolicyPending("zai")
		r.ZaiSubscriptionEstablished = !pending && len(zaiMembership(p.Cache, s, admission.State())) != 0
	}
	by := map[string]codexbarEntry{}
	if s != nil {
		for _, e := range s.Providers {
			by[e.Provider] = e
		}
	}
	for _, x := range ss {
		if n := nativeReaders[x.Provider]; n != nil && !legacyNativeReader(p, x.Provider) {
			continue
		}
		if x.Backend != BackendNative {
			continue
		}
		if _, pending := PolicyPending(x.Provider); pending {
			r.Sources = append(r.Sources, policyPendingSource(x.Provider))
			continue
		}
		st := SourceStatus{Source: "native:" + x.Provider}
		e, ok := by[x.Provider]
		if x.Provider == "zai" {
			g, granted := p.ReaderAccessGrant(x.Provider)
			login := zcodeLoginRoute(p, x.Provider)
			_, pasted, err := loadManualKeyChecked(p.Cache, x.Provider)
			switch {
			case login:
				if ok && (e.Status == "ok" || len(e.Windows) != 0) {
					ctx := productionReaderContext(context.Background(), p, x.Provider)
					access, blocked := zaiConfigAdmission(ctx)
					// Saved-login results become visible only after the aggregate write.
					ok = blocked == "" && e.ZCodeLoginGeneration != "" && e.ZCodeLoginGeneration == access.LoginGeneration
				}
			case err != nil || pasted:
				ok = err == nil && ok && glmEntryOfPastedKey(p.Cache, e)
			case granted && g.ConfigSource != nil && g.ConfigSource.Tool == "zcode":
				// The typed cache carries the exact credential generation. An aggregate
				// capture can lag behind a provider-file change or a concurrent refresh.
				ctx := productionReaderContext(context.Background(), p, x.Provider)
				access, blocked := zaiConfigAdmission(ctx)
				state := loadZaiConfigState(p.Cache)
				ok = blocked == "" && state.LoginGeneration == access.LoginGeneration
				if ok {
					e = zaiConfigCachedEntryScope(state, now, access.LoginGeneration, zaiConfigScope(ctx))
				}
			}
		}
		if ok && (e.Status == "ok" || len(e.Windows) != 0) && !captureAllowed(p, x.Provider, e.Admission, false) {
			ok = false
		}
		if ok && x.Provider == "zai" {
			account := Account{Windows: append([]Window(nil), e.Windows...)}
			pruneReaderWindows(&account, now)
			e.Windows = account.Windows
		}
		switch {
		case x.Blocked == "no-native-reader":
			st.Status, st.Reason = "unsupported_schema", "no native reader for "+x.Provider+"; set its backend to codexbar-compat"
		case x.Blocked == "native-off":
			st.Status, st.Reason = "missing", "native readers are off (MODELPLAN_NATIVE)"
		case x.Blocked != "" && x.Blocked != "no-key":
			st.Status, st.Reason = "off", x.Blocked
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
		case e.ObservedAt.IsZero() && e.Status == "" && len(e.Windows) == 0:
			// A reference-only entry (a key change cleared the reading, glmReferenceOnly) has no observation to age.
			st.Status, st.Reason = "missing", "not read yet"
		case x.Provider == "kimi" && now.Sub(e.ObservedAt) > staleAfter:
			st.Status, st.Reason = "stale", "Kimi reading older than 60 minutes"
		case now.Sub(e.ObservedAt) > nativeKeep || e.ObservedAt.After(now.Add(5*time.Minute)):
			st.Status, st.Reason = "stale", "last reading older than 6 hours"
		case e.Status == toolcli.RuntimeMissing || strings.HasPrefix(e.Error, toolcli.RuntimeMissing+":"):
			st.Status, st.Reason = toolcli.RuntimeMissing, toolcli.RuntimeNextStep
			st.ErrorCode = "runtime_missing"
		case e.Status != "ok":
			st.ErrorCode = ReaderErrorCode(e.ErrorCode)
			st.Status, st.Reason = "unavailable", st.ErrorCode
			if x.Provider == "zai" && zaiTransientFailure(e.ErrorCode) && len(e.Windows) > 0 {
				account := Account{Source: st.Source, Plan: e.Plan, ObservedAt: e.ObservedAt, Windows: append([]Window(nil), e.Windows...),
					Via: "native", Subscription: e.binding("api-key"), retained: true}
				r.Accounts = append(r.Accounts, account)
			}
		case len(e.Windows) == 0:
			st.Status, st.Reason = "empty", "no usage windows"
		default:
			st.Status = "ok"
			windows := append([]Window(nil), e.Windows...)
			if x.Provider == "kimi" {
				a := Account{Windows: windows}
				pruneReaderWindows(&a, now)
				windows = a.Windows
			}
			basis := "api-key"
			if x.Provider == "cursor" {
				basis = "cursor-auth"
			}
			r.Accounts = append(r.Accounts, Account{Source: st.Source, Plan: e.Plan, ObservedAt: e.ObservedAt, Windows: windows, Via: "native", Subscription: e.binding(basis), ReportedModels: e.ReportedModels})
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

// A rejected or unreadable credential cannot keep a previously valid reading on screen.
func zaiTransientFailure(code string) bool {
	switch code {
	case "timeout", "network", "http_429", "http_5xx":
		return true
	}
	return false
}

// glmEntryOfPastedKey: e is reference-only, or was read with the pasted GLM key saved now.
func glmEntryOfPastedKey(cache string, e codexbarEntry) bool {
	if e.ObservedAt.IsZero() && e.Status == "" && len(e.Windows) == 0 {
		return true
	}
	return e.ManualKeyGeneration != 0 && e.ManualKeyGeneration == manualKeyGenerations(cache)["zai"]
}

// A throttled sweep still applies current generation/admission to typed caches.
// It must not call a collector just to invalidate an old aggregate account.
func projectLegacyNativeCache(ctx context.Context, p Paths, provider string, old codexbarEntry, now time.Time) codexbarEntry {
	ctx = productionReaderContext(ctx, p, provider)
	e := old
	// Sampling 11-20 S5: a saved (or unreadable) pasted GLM key is the only GLM route, so the
	// configured-tool cache (another key, possibly another account) is never projected over it;
	// the entry that the key change or the pasted key's own read left stands.
	// Sampling 11-21 S8: an entry a parent build left (another key's reading projected over the pasted key) is not
	// the pasted key's: only a reading of the current pasted-key generation stays; any other becomes reference-only,
	// keeping its deadline, so nothing is shown and no request is made before it.
	if provider == "zai" && !zcodeLoginRoute(p, provider) {
		if _, pasted, err := loadManualKeyChecked(p.Cache, provider); pasted || err != nil {
			if err == nil && !glmEntryOfPastedKey(p.Cache, old) {
				return glmReferenceOnly(old)
			}
			return old
		}
	}
	switch provider {
	case "copilot":
		access, blocked := copilotAdmission(ctx)
		e = copilotCachedEntry(loadCopilotState(p.Cache), now, access.LoginGeneration)
		if blocked != "" {
			e = codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: copilotNext(blocked)}
		}
	case "antigravity":
		access, blocked := antigravityAdmission(ctx)
		e = antigravityCachedEntry(loadAntigravityState(p.Cache), now, access.LoginGeneration)
		if blocked != "" {
			e = codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: antigravityNext(blocked)}
		}
	case "zai":
		if g, ok := p.ReaderAccessGrant(provider); ok && g.ConfigSource != nil {
			access, blocked := zaiConfigAdmission(ctx)
			e = zaiConfigCachedEntryScope(loadZaiConfigState(p.Cache), now, access.LoginGeneration, zaiConfigScope(ctx))
			if blocked != "" {
				e = codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: zaiConfigNext(blocked)}
			}
		}
	}
	if e.Status == "ok" {
		e.ErrorCode = ""
	} else if e.ErrorCode != "" {
		e.ErrorCode = ReaderErrorCode(e.ErrorCode)
		e.Error = e.ErrorCode
	}
	e.Provider, e.Source = old.Provider, old.Source
	return e
}

// KeychainGrantRead runs one foreground read for a saved-login reader right
// after the user grants its Keychain access in Settings, so the macOS prompt
// appears while the user is present and a timed-out background attempt cannot
// latch the Keychain state. It is the only caller of the foreground path.
func KeychainGrantRead(ctx context.Context, p Paths, provider string, now time.Time) error {
	if !nativePrivacyAllows() || ctx.Err() != nil {
		return errors.New("personal readers are suspended")
	}
	if n, ok := nativeReaders[provider]; !ok || n.Managed == nil {
		return errors.New("no saved-login reader")
	}
	admission, err := consent.ReaderLockContext(ctx)
	if err != nil {
		return err
	}
	defer admission()
	if provider != "claude" {
		return errors.New("no interactive credential adapter")
	}
	g, allowed := readerAllowed(p, provider)
	if !allowed || !g.Keychain {
		return errors.New("keychain consent required")
	}
	profiles := g.Profiles
	if len(profiles) == 0 {
		profiles = nativeReaders[provider].Profiles()
	}
	if len(profiles) != 1 {
		return errors.New("unsupported profile selection")
	}
	profileKey := readerHash(p.Cache, provider+":profile", profiles[0].Root+"\x00"+profiles[0].AccountFile)
	if profileKey == "" {
		return errors.New("identity key unavailable")
	}
	// Decide before the outcome below clears the failure facts this reads.
	localBackoff := claudeBackoffIsLocal(p.Cache)
	// This operation is interactive even when the remote budget is closed. Keep
	// its credential only in this stack frame and reuse it if a remote read is due.
	credential := g.Credential
	if credential == nil {
		if claudeSecurity == nil {
			return errors.New(claudeAppRequired)
		}
		credential = func(ctx context.Context) ([]byte, string) {
			k := (keychain.Reader{Cache: p.Cache, Execute: claudeSecurity}).ClaudeCredentials(ctx, keychain.Policy{Allowed: true, PriorGrant: g.KeychainPriorGrant, Interactive: true, ProfileRef: profileKey})
			if k.State != "ok" {
				return nil, k.State
			}
			return k.Value, ""
		}
	}
	value, status := credential(ctx)
	defer clear(value)
	if status != "" {
		return recordClaudeCredentialOutcome(p, g, profileKey, status, now)
	}
	if g.StillValid != nil && !g.StillValid() {
		return errors.New("reader consent changed")
	}
	if err := recordClaudeCredentialOutcome(p, g, profileKey, "ok", now); err != nil {
		return err
	}
	g.Credential = func(context.Context) ([]byte, string) { return value, "" }
	access := &ReaderAccess{Grants: map[string]ReaderGrant{provider: g}}
	p.ReaderAccess = access
	return refreshManagedAfter(ctx, p, provider, now, localBackoff)
}

// claudeBackoffIsLocal: every recorded failure stopped at the credential, before any
// provider request, so the back-off protects nothing the user's Allow should wait for.
// A provider failure or a success keeps its floor and any Retry-After.
func claudeBackoffIsLocal(cache string) bool {
	s, err := loadReaderState(cache, "claude")
	if err != nil || s.Failures == 0 || !s.LocalBackoff || len(s.Entries) == 0 {
		return false
	}
	for _, e := range s.Entries {
		if e.Status == "ok" || !credentialStageFailure(e) {
			return false
		}
	}
	return true
}

// zaiPastedKeyAdmitted: the GLM API-key scope (the pasted key's own admission) is not denied right now.
// An undecided scope stays with the selection's own consent check, as before.
func zaiPastedKeyAdmitted() bool {
	current, mode := consent.Current()
	if r, decided := current.Scopes[consent.ScopeZaiAccountUsageAPIKey]; decided && !r.Allowed {
		return false
	}
	return mode != consent.Off
}

// pastedGLMKeyRoute: a pasted GLM key is saved and the GLM selection runs natively, unblocked.
// The selected ZCode sign-in is not that route: it never reads the pasted key (macrev2-1162-2).
func pastedGLMKeyRoute(p Paths) bool {
	if !ManualKeyPresent(p.Cache, "zai") || zcodeLoginRoute(p, "zai") {
		return false
	}
	ss, err := Selections(p)
	if err != nil {
		return false
	}
	for _, x := range ss {
		if x.Provider == "zai" && x.Backend == BackendNative && x.Blocked == "" {
			return true
		}
	}
	return false
}

// zcodeLoginRoute: the provider is read through ZCode's sign-in (D369).
func zcodeLoginRoute(p Paths, provider string) bool {
	g, ok := p.ReaderAccessGrant(provider)
	return ok && provider == "zai" && g.ConfigSource != nil && g.ConfigSource.Tool == zcodeLoginTool
}

func credentialStageFailure(e readerEntry) bool {
	return e.CredentialReadState != "" || e.ErrorCode == "file_missing"
}

// applyZCodeNoProviderFile reports ZCode's unreadable layout as a fixed reason, never a
// pending first reading, unless another ZCode/GLM source already reported (G3-21).
// With ZCode's QR-code sign-in present but its saved-login scope not allowed (D369), the fixed reason
// is "consent required": the row offers the consent action and shows no data.
func applyZCodeNoProviderFile(r *Report, p Paths) {
	if !p.ZCodeNoProviderFile && !p.ZCodeLoginConsent && p.ZCodeKeychainPending == "" {
		return
	}
	// S6 (#1031 sampling): a selected, admitted pasted GLM key is a route that can run; its own
	// status (for instance "missing / not read yet" after a key change) stands.
	if pastedGLMKeyRoute(p) {
		return
	}
	cause := SourceStatus{Source: "native:zai", Status: "unavailable", Reason: "unsupported_login", ErrorCode: "unsupported_login"}
	if p.ZCodeLoginConsent {
		cause = SourceStatus{Source: "native:zai", Status: "unavailable", Reason: "consent_required", ErrorCode: "consent_required"}
	}
	if code := map[string]string{"unset": "keychain_unset", "denied": "keychain_denied"}[p.ZCodeKeychainPending]; code != "" {
		cause = SourceStatus{Source: "native:zai", Status: "unavailable", Reason: code, ErrorCode: code}
	}
	for i, s := range r.Sources {
		if s.Source == "native:zai" {
			// A bare legacy GLM allow reports its absent environment key; ZCode's missing
			// provider file is the actual cause (post-merge #711 (2)). Any other status stands.
			if s.Status == "missing" {
				r.Sources[i] = cause
			}
			return
		}
	}
	r.Sources = append(r.Sources, cause)
}
