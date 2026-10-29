package quota

import (
	"context"
	"encoding/json"
	"errors"
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
		if legacyNativeDue(p.Cache, x.Provider, by[x.Provider], now) {
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

func refreshNative(ctx context.Context, p Paths, now time.Time, diagnostic bool) error {
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
	sessionRead := false
	if !diagnostic {
		sessionRead = refreshProductionClaudeSessions(ctx, p, now)
	} else if claudeSessionsDue(p, now) && diagnosticSessionDue(p, now) {
		if err := reserveReaderAttempt(p.Cache, "claude-session", now.Add(5*time.Minute)); err != nil {
			return err
		}
		sessionRead = refreshProductionClaudeSessions(ctx, p, now)
	}
	on := active(p, BackendNative)
	legacy := on[:0]
	for _, x := range on {
		if legacyNativeReader(p, x.Provider) {
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
		if sessionRead {
			return nil
		}
		return errors.New("no native provider is on")
	}
	unlock, ok := lockFile(filepath.Join(p.Cache, "observed", "native.lock"), now, time.Duration(len(on)+len(managed)+1)*nativeTimeout)
	if !ok {
		return errors.New("another refresh is running")
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
	previous := map[string]codexbarEntry{}
	if old := loadNative(p.Cache); old != nil {
		for _, entry := range old.Providers {
			previous[entry.Provider] = entry
		}
	}
	s := &nativeSnap{SchemaVersion: 1, ObservedAt: now.UTC(), Providers: []codexbarEntry{}}
	for _, x := range on {
		if !consent.CurrentFence(state.Fence()) {
			return errors.New("consent changed; refresh stopped")
		}
		var e codexbarEntry
		n := nativeReaders[x.Provider]
		if !n.budgetDue(p.Cache, now) || !legacyNativeDue(p.Cache, x.Provider, previous[x.Provider], now) {
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
		if err := reserveReaderAttempt(p.Cache, x.Provider, now.Add(5*time.Minute)); err != nil {
			if !diagnostic {
				return err
			}
			refreshErr = err
			continue
		}
		if err := n.reserveBudget(p.Cache, now); err != nil {
			return err
		}
		key := os.Getenv(x.KeyEnv)
		readerCtx := productionReaderContext(ctx, p, x.Provider)
		if g, ok := p.ReaderAccessGrant(x.Provider); ok && g.ConfigSource != nil {
			e = collectZaiConfig(readerCtx, nativeClient, p.Cache, now)
		} else if n.Collect != nil {
			e = n.Collect(readerCtx, nativeClient, p.Cache, now)
		} else {
			e = n.Fetch(ctx, nativeClient, x.Region, key, now)
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
		if e.Status == "ok" && key != "" && !IdentityOff() {
			e.SubscriptionRef = assignSubscription(p.Cache, nativeIdentityBasis(x), key, now) // a key is one subscription
		}
		if e.Error != "" {
			e.Error = clean(e.Error, home)
		}
		next := now.Add(NativeEvery)
		if e.Status != "ok" {
			next = now.Add(nativeRetryAfter)
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
	b, _ := json.MarshalIndent(s, "", "  ")
	if err := os.MkdirAll(filepath.Dir(nativePath(p.Cache)), 0o700); err != nil {
		return err
	}
	if err := consent.Publish(state.Fence(), func() error { return writeAtomic(nativePath(p.Cache), append(b, '\n')) }); err != nil {
		return err
	}
	return refreshErr
}

// getJSON: one GET with the key as a bearer token, bounded, decoded into v. The error names the
// HTTP status, never the key or the body.
func getJSON(ctx context.Context, c *http.Client, url, key string, v any) error {
	ctx, cancel := context.WithTimeout(ctx, nativeTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return codeError("other", "bad request")
	}
	req.Header.Set("Authorization", "Bearer "+key)
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

// applyNative adds one account per native provider with a recent usable reading, and one source
// status per native provider saying what was read or why not.
func applyNative(r *Report, p Paths, now time.Time) {
	// Apply local state after native accounts, including early-return paths.
	// Both Read and the production ReadPermitted flow pass through this hook.
	defer applyClaudeSessions(r, p, now)
	ss, err := Selections(p)
	if err != nil {
		r.Sources = append(r.Sources, SourceStatus{Source: "connections", Status: "invalid", Reason: short(err.Error())})
		return
	}
	legacySelections := map[string]bool{}
	for _, s := range ss {
		if legacyNativeReader(p, s.Provider) {
			legacySelections[s.Provider] = true
		}
	}
	for provider, n := range nativeReaders {
		if n.Managed != nil && !legacySelections[provider] {
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
		if ok && e.Status == "ok" && !captureAllowed(p, x.Provider, e.Admission, false) {
			ok = false
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

// A throttled sweep still applies current generation/admission to typed caches.
// It must not call a collector just to invalidate an old aggregate account.
func projectLegacyNativeCache(ctx context.Context, p Paths, provider string, old codexbarEntry, now time.Time) codexbarEntry {
	ctx = productionReaderContext(ctx, p, provider)
	e := old
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
			e = zaiConfigCachedEntry(loadZaiConfigState(p.Cache), now, access.LoginGeneration)
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
	return refreshManaged(ctx, p, provider, now)
}
