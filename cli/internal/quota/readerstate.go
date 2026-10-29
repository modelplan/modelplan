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
	"strings"
	"time"
)

// ReaderAccess is the handoff from CLIJIT's shared consent store. Absence grants
// nothing: legacy connections alone never authorise new borrowed-login readers.
// This is a Go interface, not another command, consent file or publication feed.
type ReaderAccess struct{ Grants map[string]ReaderGrant }
type ReaderGrant struct {
	Generation         string
	SavedLogin         bool
	Keychain           bool
	KeychainConsent    string // preserves unset versus denied for an actionable reader notice
	KeychainPriorGrant bool
	Interactive        bool
	Region             string // locally selected region; an empty value uses the reader's safe default
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
	ProfileKey string    `json:"profileKey"`
	At         time.Time `json:"at"`
	Discarded  bool      `json:"discarded,omitempty"`
}

type readerEntry struct {
	AttemptedAt time.Time      `json:"attemptedAt,omitempty"`
	LastFailure *readerFailure `json:"lastFailure,omitempty"`
	Discarded   bool           `json:"discarded,omitempty"`
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
	PendingAttempt  *readerProfileAttempt `json:"pendingAttempt,omitempty"`
	SchemaVersion   int                   `json:"schemaVersion"`
	Provider        string                `json:"provider"`
	GrantKey        string                `json:"grantKey"`
	AttemptedAt     time.Time             `json:"attemptedAt"`
	NextAttemptAt   time.Time             `json:"nextAttemptAt"`
	IntervalMinutes int                   `json:"intervalMinutes"`
	Failures        int                   `json:"failures"`
	NextProfile     int                   `json:"nextProfile"`
	Entries         []readerEntry         `json:"entries"`
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
	if status != "" || json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 || s.Provider != provider || len(s.Entries) > 16 || s.NextProfile < 0 || s.Failures < 0 {
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
	if ctx.Err() != nil {
		return errors.New("reader canceled")
	}
	g, allowed := readerAllowed(p, provider)
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
	generationChanged := s.GrantKey != "" && s.GrantKey != grantKey
	if s.GrantKey != grantKey {
		s.Entries = []readerEntry{}
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
	s.PendingAttempt = &readerProfileAttempt{ProfileKey: profileKey, At: now.UTC(), Discarded: generationChanged}
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
	if e.Status == "ok" {
		e.ErrorCode = ""
	} else if e.ErrorCode != "" {
		e.ErrorCode = ReaderErrorCode(e.ErrorCode)
	}
	e.ProfileKey = profileKey
	e.AttemptedAt = now.UTC()
	e.Discarded = out.Invalidate || generationChanged
	if e.Status != "ok" {
		e.LastFailure = &readerFailure{Code: readerAttemptCode(e), At: now.UTC()}
	} else {
		e.LastFailure = nil
		e.Discarded = false
	}
	s.PendingAttempt = nil
	if e.Status != "ok" {
		if !out.Invalidate {
			e.Account, e.Metadata = previous.Account, previous.Metadata
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
		switch e.CredentialReadState {
		case "unset", "denied", "canceled", "not-found", "unavailable", "keychain-confirmation-needed", "consent-required", "busy":
			return e.CredentialReadState
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
		if e.Account == nil {
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
		if e.Account != nil {
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
	if n := nativeReaders[provider]; n == nil || n.Managed == nil {
		return errors.New("unknown managed reader")
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
