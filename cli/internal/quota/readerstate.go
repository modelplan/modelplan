package quota

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strconv"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"strings"
	"time"
)

// ReaderAccess is the handoff from CLIJIT's shared consent store. Absence grants
// nothing: legacy connections alone never authorise new borrowed-login readers.
// This is a Go interface, not another command, consent file or publication feed.
type ReaderAccess struct{ Grants map[string]ReaderGrant }
type ReaderGrant struct {
	Admission          *consent.CaptureStamp
	CaptureAllowed     func(*consent.CaptureStamp) bool
	Generation         string
	SavedLogin         bool
	Keychain           bool
	KeychainConsent    string // preserves unset versus denied for an actionable reader notice
	KeychainPriorGrant bool
	Interactive        bool
	Credential         func(context.Context) ([]byte, string) // in-memory only; never persisted
	Region             string                                 // locally selected region; an empty value uses the reader's safe default
	Profiles           []ReaderProfile
	ConfigSource       *ZaiConfigSource
	Publish            func(func() error) error
	// StillValid checks the consent generation immediately before publication.
	StillValid func() bool
}
type ReaderProfile struct {
	Root        string // locally admitted tool root, never a remotely supplied path
	AccountFile string // optional locally admitted tool-owned account file; provider-specific
}

type readerMetadata struct {
	CredentialKey   string             `json:"credentialKey,omitempty"`
	AccountKey      string             `json:"accountKey,omitempty"`
	OrganizationKey string             `json:"organizationKey,omitempty"`
	VerifiedAt      time.Time          `json:"verifiedAt,omitempty"`
	Plan            string             `json:"plan,omitempty"`
	ScopeKey        string             `json:"scopeKey,omitempty"`
	PlanDetails     *readerPlanDetails `json:"planDetails,omitempty"`
}

// Stable metadata is projected explicitly, never a persisted raw vendor payload.
type readerPlanDetails struct {
	Minutes int        `json:"minutes"`
	ResetAt *time.Time `json:"resetAt,omitempty"`
	Unified bool       `json:"unified"`
}

// readerFailure retains only a bounded reader code and the per-profile attempt
// time. The rows projection owns conversion to its public reason vocabulary.
type readerFailure struct {
	Code string    `json:"code"`
	At   time.Time `json:"at"`
}

type readerProfileAttempt struct {
	ProfileKey        string    `json:"profileKey"`
	At                time.Time `json:"at"`
	GenerationChanged bool      `json:"generationChanged,omitempty"`
}

type readerEntry struct {
	Admission         *consent.CaptureStamp `json:"admission,omitempty"`
	AttemptedAt       time.Time             `json:"attemptedAt,omitempty"`
	LastFailure       *readerFailure        `json:"lastFailure,omitempty"`
	LoginChanged      bool                  `json:"loginChanged,omitempty"`
	GenerationChanged bool                  `json:"generationChanged,omitempty"`
	// CredentialReadState is set only on the missing-file Keychain path, never
	// from the saved Keychain permission alone. busy is an in-flight read.
	CredentialReadState string         `json:"credentialReadState,omitempty"`
	ErrorCode           string         `json:"errorCode,omitempty"`
	ProfileKey          string         `json:"profileKey"`
	Account             *Account       `json:"account,omitempty"`
	Metadata            readerMetadata `json:"metadata,omitempty"`
	Status              string         `json:"status"`
	Notice              string         `json:"notice,omitempty"`
	NextStep            string         `json:"nextStep,omitempty"`
}
type readerState struct {
	// Kept separately so reserving an attempt does not change legacy Sources
	// or introduce a legacy account for an unread profile.
	GenerationDiscards []string               `json:"generationDiscards,omitempty"`
	PendingAttempts    []readerProfileAttempt `json:"pendingAttempts,omitempty"`
	SchemaVersion      int                    `json:"schemaVersion"`
	Provider           string                 `json:"provider"`
	GrantKey           string                 `json:"grantKey"`
	AttemptedAt        time.Time              `json:"attemptedAt"`
	NextAttemptAt      time.Time              `json:"nextAttemptAt"`
	IntervalMinutes    int                    `json:"intervalMinutes"`
	Failures           int                    `json:"failures"`
	NextProfile        int                    `json:"nextProfile"`
	Entries            []readerEntry          `json:"entries"`
}
type readerContext struct {
	Paths      Paths
	Grant      ReaderGrant
	Profile    ReaderProfile
	ProfileKey string
	Previous   readerEntry
	Now        time.Time
}
type readerOutcome struct {
	Entry      readerEntry
	Invalidate bool
	RetryAfter time.Time
}

func readerPath(cache, provider string) string {
	return filepath.Join(cache, "observed", "readers", provider+".json")
}

// readerHash shares the installation's existing identity key. Paths, credential
// generations and principals are stored only as domain-separated keyed hashes.
func readerHash(cache, domain, value string) string {
	if cache == "" || value == "" {
		return ""
	}
	unlock, ok := lockFile(filepath.Join(cache, "observed", "subscriptions.lock"), time.Now(), 10*time.Second)
	if !ok {
		return ""
	}
	defer unlock()
	m := subscriptionMap{SchemaVersion: 1, Refs: map[string]subscriptionItem{}}
	b, status := readBounded(subscriptionsPath(cache), 256<<10)
	if status == "" {
		if json.Unmarshal(b, &m) != nil || m.SchemaVersion != 1 || m.Refs == nil {
			return ""
		}
	} else if status != "missing" {
		return ""
	}
	key, err := hex.DecodeString(m.Key)
	if err != nil || len(key) != 32 {
		if len(m.Refs) != 0 {
			return ""
		}
		key = randomBytes(32)
		if len(key) != 32 {
			return ""
		}
		m.Key = hex.EncodeToString(key)
		out, _ := json.Marshal(m)
		if writeAtomic(subscriptionsPath(cache), append(out, '\n')) != nil {
			return ""
		}
	}
	h := hmac.New(sha256.New, key)
	_, _ = h.Write([]byte("reader:" + domain + "\x00" + value))
	return hex.EncodeToString(h.Sum(nil))
}

func readerAllowed(p Paths, provider string) (ReaderGrant, bool) {
	if _, pending := PolicyPending(provider); pending {
		return ReaderGrant{}, false
	}
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("MODELPLAN_READERS")))
	if p.Cache == "" || p.ReaderAccess == nil || nativeOff() || (mode != "" && mode != "automatic") {
		return ReaderGrant{}, false
	}
	g, ok := p.ReaderAccess.Grants[provider]
	return g, ok && g.SavedLogin && g.Generation != "" && (g.StillValid == nil || g.StillValid())
}

func loadReaderState(cache, provider string) (*readerState, error) {
	b, status := readBounded(readerPath(cache, provider), 256<<10)
	if status == "missing" {
		return &readerState{SchemaVersion: 1, Provider: provider, Entries: []readerEntry{}}, nil
	}
	var s readerState
	if status != "" || json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 || s.Provider != provider || len(s.Entries) > 16 || len(s.GenerationDiscards) > 16 || len(s.PendingAttempts) > 16 || s.NextProfile < 0 || s.Failures < 0 {
		return nil, errors.New("reader cache unavailable")
	}
	return &s, nil
}

func saveReaderState(cache string, s *readerState) error {
	path := readerPath(cache, s.Provider)
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return errors.New("reader cache unavailable")
	}
	b, err := json.Marshal(s)
	if err != nil || len(b) > 256<<10 {
		return errors.New("reader cache unavailable")
	}
	if writeAtomic(path, append(b, '\n')) != nil {
		return errors.New("reader cache unavailable")
	}
	return nil
}

func managedDue(p Paths, provider string, now time.Time) bool {
	if _, ok := readerAllowed(p, provider); !ok {
		return false
	}
	s, err := loadReaderState(p.Cache, provider)
	return err == nil && !now.Before(s.NextAttemptAt) && readerAttemptDue(p.Cache, provider, now) && nativeReaders[provider].budgetDue(p.Cache, now) && xSubscriptionDue(p.Cache, provider, now)
}

// refreshManaged reserves one provider-wide read before any tool/credential I/O.
// No caller, account switch or user refresh can bypass the five-minute floor.
func refreshManaged(ctx context.Context, p Paths, provider string, now time.Time) error {
	if err := nativeAdmissionError(provider); err != nil {
		return err
	}
	if ctx.Err() != nil {
		return errors.New("reader canceled")
	}
	g, allowed := readerAllowed(p, provider)
	admitted := captureFor(p, provider, false)
	if !allowed {
		return errors.New("saved-login consent required")
	}
	unlock, ok := lockFile(readerPath(p.Cache, provider)+".lock", now, time.Minute)
	if !ok {
		return errors.New("another provider read is running")
	}
	defer unlock()
	s, err := loadReaderState(p.Cache, provider)
	if err != nil {
		return err
	}
	if now.Before(s.NextAttemptAt) || !readerAttemptDue(p.Cache, provider, now) {
		return nil
	}
	n := nativeReaders[provider]
	if !n.budgetDue(p.Cache, now) || !xSubscriptionDue(p.Cache, provider, now) {
		return nil
	}
	profiles := g.Profiles
	if len(profiles) == 0 {
		profiles = n.Profiles()
	}
	if len(profiles) == 0 || len(profiles) > 16 {
		return errors.New("unsupported profile selection")
	}
	grantKey := readerHash(p.Cache, provider+":grant", g.Generation)
	if grantKey == "" {
		return errors.New("identity key unavailable")
	}
	generationChanged := (s.GrantKey != "" || len(s.Entries) != 0 || len(s.PendingAttempts) != 0) && s.GrantKey != grantKey
	if s.GrantKey != grantKey {
		if generationChanged {
			for _, e := range s.Entries {
				if !contains(s.GenerationDiscards, e.ProfileKey) && len(s.GenerationDiscards) < 16 {
					s.GenerationDiscards = append(s.GenerationDiscards, e.ProfileKey)
				}
			}
		}
		s.Entries = []readerEntry{}
		s.PendingAttempts = nil
		s.GrantKey = grantKey
	}
	index := s.NextProfile % len(profiles)
	profile := profiles[index]
	if !filepath.IsAbs(profile.Root) {
		return errors.New("unsupported profile selection")
	}
	profileKey := readerHash(p.Cache, provider+":profile", profile.Root+"\x00"+profile.AccountFile)
	if profileKey == "" {
		return errors.New("identity key unavailable")
	}
	previous := readerEntry{ProfileKey: profileKey}
	entryIndex := -1
	for i, e := range s.Entries {
		if e.ProfileKey == profileKey {
			previous = e
			entryIndex = i
			break
		}
	}
	s.AttemptedAt, s.NextAttemptAt = now.UTC(), now.Add(5*time.Minute).UTC()
	if err := reserveReaderAttempt(p.Cache, provider, s.NextAttemptAt); err != nil {
		return err
	}
	if err := reserveXSubscription(p.Cache, provider, now); err != nil {
		return err
	}
	if err := n.reserveBudget(p.Cache, now); err != nil {
		return err
	}
	s.NextProfile = (index + 1) % len(profiles)
	s.clearPending(profileKey)
	if len(s.PendingAttempts) == 16 {
		s.PendingAttempts = s.PendingAttempts[1:]
	}
	s.PendingAttempts = append(s.PendingAttempts, readerProfileAttempt{ProfileKey: profileKey, At: now.UTC(), GenerationChanged: generationChanged})
	if !IdentityOff() {
		// Allocation belongs to an authorized collection, never a cache read.
		assignSubscription(p.Cache, readerProfileBasis(provider), profileKey, now)
	}
	if err := saveReaderState(p.Cache, s); err != nil {
		return err
	}
	if g.StillValid != nil && !g.StillValid() {
		return errors.New("reader consent changed")
	}
	call, cancel := context.WithTimeout(ctx, nativeTimeout)
	defer cancel()
	out := n.Managed(call, nativeClient, readerContext{Paths: p, Grant: g, Profile: profile, ProfileKey: profileKey, Previous: previous, Now: now})
	if g.StillValid != nil && !g.StillValid() {
		return errors.New("reader consent changed")
	}
	e := out.Entry
	if e.Status == "ok" && e.Account != nil {
		e.Admission = admitted
	}
	if e.Status == "ok" {
		e.ErrorCode = ""
	} else if e.ErrorCode != "" {
		e.ErrorCode = ReaderErrorCode(e.ErrorCode)
	}
	e.ProfileKey = profileKey
	e.AttemptedAt = now.UTC()
	e.LoginChanged, e.GenerationChanged = out.Invalidate, generationChanged || contains(s.GenerationDiscards, profileKey)
	if e.Status != "ok" {
		e.LastFailure = &readerFailure{Code: readerAttemptCode(e), At: now.UTC()}
	} else {
		e.LastFailure = nil
		e.LoginChanged, e.GenerationChanged = false, false
		kept := s.GenerationDiscards[:0]
		for _, key := range s.GenerationDiscards {
			if key != profileKey {
				kept = append(kept, key)
			}
		}
		s.GenerationDiscards = kept
	}
	s.clearPending(profileKey)
	if e.Status != "ok" {
		if !out.Invalidate {
			e.Account, e.Metadata, e.Admission = previous.Account, previous.Metadata, previous.Admission
		}
		s.Failures++
		wait := 10 * time.Minute
		for i := 1; i < s.Failures && wait < time.Hour; i++ {
			wait *= 2
		}
		if wait > time.Hour {
			wait = time.Hour
		}
		s.NextAttemptAt = now.Add(wait).UTC()
	} else {
		s.Failures = 0
		interval := 5
		if sameReaderValues(previous.Account, e.Account) {
			switch s.IntervalMinutes {
			case 5:
				interval = 10
			case 10:
				interval = 15
			case 15, 30:
				interval = 30
			}
		}
		s.IntervalMinutes = interval
		s.NextAttemptAt = now.Add(time.Duration(interval) * time.Minute).UTC()
	}
	if out.RetryAfter.After(s.NextAttemptAt) {
		s.NextAttemptAt = out.RetryAfter.UTC()
	}
	if entryIndex < 0 {
		s.Entries = append(s.Entries, e)
	} else {
		s.Entries[entryIndex] = e
	}
	if err := n.finishBudget(p.Cache, s.NextAttemptAt); err != nil {
		return err
	}
	if err := reserveReaderAttempt(p.Cache, provider, s.NextAttemptAt); err != nil {
		return err
	}
	if g.StillValid != nil && !g.StillValid() {
		return errors.New("reader consent changed")
	}
	if g.Publish != nil {
		return g.Publish(func() error { return saveReaderState(p.Cache, s) })
	}
	return saveReaderState(p.Cache, s)
}

// readerAttemptCode is a bounded input code, not the rows classifier. Preserve
// actionable reader states whose meaning is more specific than ErrorCode (e.g.
// expired); never persist a notice, provider message or unknown status as a code.
func readerAttemptCode(e readerEntry) string {
	if e.CredentialReadState != "" {
		// Namespace credential-store failures so a retained account's failure
		// cannot be confused with reader consent or generic unavailability.
		switch e.CredentialReadState {
		case "unset", "consent-required":
			return "keychain_unset"
		case "denied":
			return "keychain_denied"
		case "canceled":
			return "keychain_canceled"
		case "not-found":
			return "keychain_not_found"
		case "unavailable":
			return "keychain_unavailable"
		case "keychain-confirmation-needed":
			return "keychain_confirmation_needed"
		case "busy":
			return "reader_busy"
		}
	}
	switch e.Status {
	case "expired", "expired_login", "login_expired", "busy", "consent_required", "denied", "off", "privacy_blocked":
		return e.Status
	}
	if e.ErrorCode != "" {
		return ReaderErrorCode(e.ErrorCode)
	}
	return statusErrorCode(e.Status)
}

func readerProfileBasis(provider string) string { return "reader-profile:" + provider }

// AppendManagedRows appends cache-only managed-reader facts to the rows input.
// ReaderAccess must be the captured admission passed to ReadPermitted by the
// caller. This function never rereads consent, stats credentials, collects,
// allocates identity references or migrates a pre-rows cache.
func AppendManagedRows(in *rows.Input, p Paths) {
	if in == nil || p.Cache == "" || p.ReaderAccess == nil {
		return
	}
	providers := make([]string, 0, len(p.ReaderAccess.Grants))
	for provider, g := range p.ReaderAccess.Grants {
		if _, pending := PolicyPending(provider); pending {
			in.Sources = append(in.Sources, rows.SourceState{ToolID: provider, Source: "native:" + provider, Status: "unavailable", ErrorCode: "policy_pending"})
			continue
		}
		if n := nativeReaders[provider]; n != nil && n.Managed != nil && g.SavedLogin && g.Generation != "" {
			providers = append(providers, provider)
		}
	}
	sort.Strings(providers)
	for _, provider := range providers {
		g := p.ReaderAccess.Grants[provider]
		s, err := loadReaderState(p.Cache, provider)
		if err != nil {
			in.Sources = append(in.Sources, rows.SourceState{ToolID: provider, Source: "native:" + provider, Status: "unavailable", ErrorCode: "other"})
			s = &readerState{}
		}
		nextAttempt, budgetKnown := managedReaderNext(p.Cache, provider, s.NextAttemptAt)
		grantKey := lookupReaderHash(p.Cache, provider+":grant", g.Generation)
		generationChanged := (s.GrantKey != "" || len(s.Entries) != 0 || len(s.PendingAttempts) != 0) && (grantKey == "" || s.GrantKey != grantKey)
		for index, profile := range g.Profiles {
			if index >= 16 {
				break
			}
			key := lookupReaderHash(p.Cache, provider+":profile", profile.Root+"\x00"+profile.AccountFile)
			// This key is correlation only. It is never an exported identity or a
			// substitute locator; before the first collection there is no key.
			joinKey := key
			if joinKey == "" {
				joinKey = "unread:" + strconv.Itoa(index)
			}
			f := rows.ProfileState{ToolID: provider, ProfileKey: joinKey, LatestAttempt: rows.AttemptResultNever, GenerationChanged: generationChanged || contains(s.GenerationDiscards, key),
				NextAttemptAt: readerTime(nextAttempt), CoolingDown: !budgetKnown || in.Now.Before(nextAttempt)}
			if !in.IdentityOff {
				f.AccountLocator = readerString(readerProfileLocator(p.Cache, provider, key))
			}
			var entry *readerEntry
			if key != "" && !generationChanged {
				for i := range s.Entries {
					if s.Entries[i].ProfileKey == key {
						entry = &s.Entries[i]
						break
					}
				}
			}
			if entry != nil {
				e := *entry
				f.AttemptedAt = readerTime(e.AttemptedAt)
				f.LoginChanged = e.LoginChanged
				f.GenerationChanged = f.GenerationChanged || e.GenerationChanged
				if e.Status == "ok" {
					f.LatestAttempt = rows.AttemptResultSucceeded
				} else if e.Status == "busy" {
					f.Busy = true
				} else if e.Status != "" {
					f.LatestAttempt = rows.AttemptResultFailed
					// An older cache knows this profile failed, but not when.
					// Never borrow the provider-wide timestamp for that profile.
					f.LastFailure = &rows.FailureInput{Code: readerAttemptCode(e)}
					if e.LastFailure != nil {
						f.LastFailure.At = readerTime(e.LastFailure.At)
					}
				}
				if provider == "claude" && e.CredentialReadState != "" {
					state := readerCredentialReadState(e.CredentialReadState)
					if state != "" {
						in.KeychainBlocks = append(in.KeychainBlocks, rows.KeychainBlock{ToolID: provider, Status: state, Blocked: state != "busy"})
						f.Busy = state == "busy"
					}
				}
				in.Sources = append(in.Sources, rows.SourceState{ToolID: provider, Source: "native:" + provider, Status: e.Status, ErrorCode: e.ErrorCode})
				if a := e.Account; a != nil && !f.LoginChanged && !f.GenerationChanged && captureAllowed(p, provider, e.Admission, false) {
					f.ObservedAt = readerTime(a.ObservedAt)
					if !a.ObservedAt.IsZero() && !a.ObservedAt.After(in.Now) {
						f.FreshUntil = readerTime(a.ObservedAt.Add(staleAfter))
						f.WithinFreshness = in.Now.Before(*f.FreshUntil)
					}
					in.Accounts = append(in.Accounts, managedRowsAccount(provider, joinKey, a, p.Cache, in.Now, in.IdentityOff))
				}
			}
			for _, pending := range s.PendingAttempts {
				if key != "" && pending.ProfileKey == key && !generationChanged {
					f.AttemptedAt = readerTime(pending.At)
					f.LatestAttempt = rows.AttemptResultNever
					f.Busy = in.Now.Before(pending.At.Add(nativeTimeout))
					f.GenerationChanged = f.GenerationChanged || pending.GenerationChanged
				}
			}
			in.Profiles = append(in.Profiles, f)
		}
	}
}

// Include reservations that survive Forget, key/login route changes and shared
// Cursor/Grok reads. This observes exactly the persisted gates without changing
// them; an unreadable gate cannot advertise an available refresh time.
func managedReaderNext(cache, provider string, next time.Time) (time.Time, bool) {
	paths := []string{readerAttemptPath(cache, provider)}
	switch provider {
	case "kimi":
		paths = append(paths, kimiBudgetPath(cache))
	case "cursor", "grok":
		paths = append(paths, xSubscriptionPath(cache))
	}
	for _, path := range paths {
		b, status := readBounded(path, 4096)
		if status == "missing" {
			continue
		}
		var gate readerAttempt
		if status != "" || json.Unmarshal(b, &gate) != nil || gate.SchemaVersion != 1 {
			return time.Time{}, false
		}
		if gate.NextAttemptAt.After(next) {
			next = gate.NextAttemptAt
		}
	}
	return next, true
}

func (s *readerState) clearPending(profileKey string) {
	kept := s.PendingAttempts[:0]
	for _, attempt := range s.PendingAttempts {
		if attempt.ProfileKey != profileKey {
			kept = append(kept, attempt)
		}
	}
	s.PendingAttempts = kept
}

func readerCredentialReadState(state string) string {
	switch state {
	case "unset", "denied", "canceled", "not-found", "unavailable", "keychain-confirmation-needed", "consent-required", "busy":
		return state
	}
	return ""
}

func readerTime(at time.Time) *time.Time {
	if at.IsZero() {
		return nil
	}
	at = at.UTC()
	return &at
}

func readerString(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func managedRowsAccount(provider, key string, a *Account, cache string, now time.Time, identityOff bool) rows.AccountInput {
	// Evaluate only the freshly decoded cache copy, never the legacy Report or
	// a persisted file. This reuses the quota window arithmetic/reset handling.
	Evaluate(a, now)
	out := rows.AccountInput{ToolID: provider, ProfileKey: key, Source: a.Source, PlanID: a.Plan, Beta: true}
	if !identityOff {
		out.SubscriptionRef = readerString(existingReaderSubscription(cache, provider, a.Subscription))
	}
	if c := a.Credits; c != nil {
		out.Credits = &rows.CreditsInput{Balance: c.Balance, Unit: c.Unit}
	}
	for _, w := range a.Windows {
		v := rows.WindowInput{Kind: w.Kind, Limit: w.Limit, Pool: a.Pool, ResetMode: w.ResetMode, RemainingPercent: w.RemainingPercent, ResetsAt: w.ResetsAt, ObservedAt: readerTime(w.ObservedAt)}
		if w.WindowMinutes > 0 {
			seconds := int64(w.WindowMinutes) * 60
			v.DurationSeconds = &seconds
		}
		out.Windows = append(out.Windows, v)
	}
	return out
}

func sameReaderValues(a, b *Account) bool {
	if a == nil || b == nil {
		return false
	}
	x, y := *a, *b
	x.ObservedAt, y.ObservedAt = time.Time{}, time.Time{}
	x.Windows, y.Windows = append([]Window(nil), a.Windows...), append([]Window(nil), b.Windows...)
	for i := range x.Windows {
		x.Windows[i].ObservedAt = time.Time{}
	}
	for i := range y.Windows {
		y.Windows[i].ObservedAt = time.Time{}
	}
	x.Subscription, y.Subscription = nil, nil
	if a.Credits != nil {
		c := *a.Credits
		c.ObservedAt = time.Time{}
		c.AgeMinutes = nil
		x.Credits = &c
	}
	if b.Credits != nil {
		c := *b.Credits
		c.ObservedAt = time.Time{}
		c.AgeMinutes = nil
		y.Credits = &c
	}
	xb, _ := json.Marshal(x)
	yb, _ := json.Marshal(y)
	return string(xb) == string(yb)
}

func pruneReaderWindows(a *Account, now time.Time) {
	if a == nil {
		return
	}
	ws := make([]Window, 0, len(a.Windows))
	for _, w := range a.Windows {
		if w.ResetsAt == nil || w.ResetsAt.After(now) {
			ws = append(ws, w)
		}
	}
	a.Windows = ws
}

// applyManaged loads only ModelPlan's sanitized cache. It never calls collectors,
// stats tool files, writes freshness, or launches a refresh (including --json).
func applyManaged(r *Report, p Paths, provider string, now time.Time) {
	if _, pending := PolicyPending(provider); pending {
		r.Sources = append(r.Sources, policyPendingSource(provider))
		return
	}
	if p.Cache == "" {
		return
	}
	s, err := loadReaderState(p.Cache, provider)
	if err != nil {
		r.Sources = append(r.Sources, SourceStatus{Beta: true, Source: "native:" + provider, Status: "unavailable", Reason: "reader cache unavailable"})
		return
	}
	if len(s.Entries) == 0 {
		return
	}
	newest := map[string]time.Time{}
	for _, e := range s.Entries {
		if e.Account == nil || !captureAllowed(p, provider, e.Admission, false) {
			continue
		}
		key := e.ProfileKey
		if e.Account.Subscription != nil && e.Account.Subscription.Ref != "" {
			key = e.Account.Subscription.Ref
		}
		if e.Account.ObservedAt.After(newest[key]) {
			newest[key] = e.Account.ObservedAt
		}
	}
	seen := map[string]bool{}
	for _, e := range s.Entries {
		st := SourceStatus{Beta: true, Source: "native:" + provider, Status: e.Status, Reason: e.Notice}
		if e.Status != "ok" && e.ErrorCode != "" {
			st.ErrorCode = ReaderErrorCode(e.ErrorCode)
		}
		if e.NextStep != "" {
			st.Reason = e.NextStep
		}
		if st.ErrorCode != "" {
			st.Reason = st.ErrorCode
		}
		if e.Account != nil && captureAllowed(p, provider, e.Admission, false) {
			a := *e.Account
			a.Beta = true
			a.Windows = append([]Window(nil), a.Windows...)
			pruneReaderWindows(&a, now)
			key := e.ProfileKey
			if a.Subscription != nil && a.Subscription.Ref != "" {
				key = a.Subscription.Ref
			}
			if !seen[key] && !a.ObservedAt.Before(newest[key]) {
				seen[key] = true
				if provider == "claude" {
					kept := r.Accounts[:0]
					for _, old := range r.Accounts {
						if old.Source != "claude-code" || old.Via == "native" {
							kept = append(kept, old)
						}
					}
					r.Accounts = kept
				}
				r.Accounts = append(r.Accounts, a)
			}
		}
		r.Sources = append(r.Sources, st)
	}
}

// ForgetReader is called only by explicit disconnect/Forget orchestration. The
// consent layer cancels in-flight work first. Tool credentials are never touched.
func ForgetReader(cache, provider string) error {
	if !consent.ValidTool(provider) {
		return errors.New("invalid reader ID")
	}
	unlock, ok := lockFile(readerPath(cache, provider)+".lock", time.Now(), time.Minute)
	if !ok {
		return errors.New("another provider read is running")
	}
	defer unlock()
	s, err := loadReaderState(cache, provider)
	if err != nil {
		return err
	}
	// Also migrate a reservation written by an older reader before purging it.
	if err := reserveReaderAttempt(cache, provider, s.NextAttemptAt); err != nil {
		return err
	}
	if err := os.Remove(readerPath(cache, provider)); err != nil && !os.IsNotExist(err) {
		return errors.New("reader cache unavailable")
	}
	return nil
}
