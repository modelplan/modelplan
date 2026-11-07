package quota

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"
)

// resetCardIdentity holds a keyed representation; raw provider IDs are never cached.
type resetCardIdentity struct {
	ID        string     `json:"id"`
	ExpiresAt *time.Time `json:"expiresAt"`
}
type accountResetCredits struct {
	Count            int                 `json:"count"`
	Expiries         []*time.Time        `json:"expiries,omitempty"`
	Items            []resetCardIdentity `json:"items,omitempty"`
	IdentityComplete bool                `json:"identityComplete,omitempty"`
	IdentityObserved bool                `json:"identityObserved,omitempty"`
	Truncated        bool                `json:"truncated,omitempty"`
	countPresent     bool
}

// A malformed cache must not turn an absent count into a known zero.
func (c *accountResetCredits) UnmarshalJSON(data []byte) error {
	type fields accountResetCredits
	var raw struct {
		*fields
		Count json.RawMessage `json:"count"`
	}
	raw.fields = (*fields)(c)
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	var count int
	if len(raw.Count) != 0 && string(raw.Count) != "null" && json.Unmarshal(raw.Count, &count) == nil && count >= 0 && count < 10000 {
		c.Count, c.countPresent = count, true
	}
	return nil
}

// The Codex account reading comes from Codex itself: `codex app-server` answers
// account/rateLimits/read with the account's windows, its reset credits and its usage-credit
// balance, using the login Codex already holds. This client never sees a credential, starts no
// thread or turn, and never calls account/rateLimitResetCredit/consume. The reading is cached in
// <cache>/observed/codex-account.json without account or credit ids; Read merges it with the
// session-log windows (newest observation per window wins).

const (
	// AccountEvery: how often a refresh may ask Codex; failures wait longer.
	AccountEvery      = 5 * time.Minute
	accountRetryAfter = 30 * time.Minute
	// accountKeep: older readings are ignored; the session logs carry on alone.
	accountKeep    = 6 * time.Hour
	accountTimeout = 15 * time.Second
)

type accountSnap struct {
	Admission     *consent.CaptureStamp `json:"admission,omitempty"`
	SchemaVersion int                   `json:"schemaVersion"`
	ObservedAt    time.Time             `json:"observedAt"`
	Status        string                `json:"status"` // ok | error
	Error         string                `json:"error,omitempty"`
	Plan          string                `json:"plan,omitempty"`
	Windows       []Window              `json:"windows,omitempty"`
	// Credits: available reset credits; Expiries has one entry per credit whose details were
	// returned (nil time = never expires). Count may exceed len(Expiries).
	Credits *accountResetCredits `json:"credits,omitempty"`
	// Usage: the account's usage credits (not reset credits), nil when it has none. UsageRead:
	// the answer carried the field at all (older Codex versions leave it out).
	Usage     *Credits `json:"usageCredits,omitempty"`
	UsageRead bool     `json:"usageRead,omitempty"`
	// SubscriptionRef: the account's reference (identity.go); the identity itself is not kept.
	SubscriptionRef string `json:"subscriptionRef,omitempty"`
}

func accountPath(cache string) string { return filepath.Join(cache, "observed", "codex-account.json") }

func loadAccount(cache string) *accountSnap {
	if cache == "" {
		return nil
	}
	b, err := os.ReadFile(accountPath(cache))
	if err != nil || len(b) > 256<<10 {
		return nil
	}
	var s accountSnap
	if json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 {
		return nil
	}
	return &s
}

// CodexRuntimeAvailable reports only whether an admitted runtime snapshot was
// successful and still fresh. At the exact freshness deadline it permits the
// conservative local fallback even though Evaluate marks stale strictly after it.
// It exposes no provider values or identity.
func CodexRuntimeAvailable(cache string, admission consent.Admission, now time.Time) bool {
	if off() || !admission.Allows("codex", consent.Runtime) {
		return false
	}
	s := loadAccount(cache)
	if s == nil || s.Status != "ok" || s.ObservedAt.After(now) || now.Sub(s.ObservedAt) >= staleAfter || !admission.State().CaptureAllowed(s.Admission, consent.ScopeCodexRuntimeUsage) {
		return false
	}
	for _, window := range s.Windows {
		if window.ObservedAt.IsZero() || window.ObservedAt.After(now) || now.Sub(window.ObservedAt) >= staleAfter || finite(window.UsedPercent, 0, 1000) == nil {
			continue
		}
		if window.ResetsAt == nil || now.Before(*window.ResetsAt) {
			return true
		}
	}
	return false
}

// AccountDue: the cached reading is old enough to ask Codex again.
func AccountDue(cache string, now time.Time) bool {
	if off() || cache == "" {
		return false
	}
	next, err := codexRefreshNext(cache)
	return err == nil && !now.Before(next)
}

// CodexAccountOff: MODELPLAN_CODEX_ACCOUNT=off keeps the CLI to the session logs.
func CodexAccountOff() bool { return off() }

// off: MODELPLAN_CODEX_ACCOUNT=off keeps the CLI to the session logs.
func off() bool {
	v := strings.ToLower(os.Getenv("MODELPLAN_CODEX_ACCOUNT"))
	return v == "off" || v == "0" || v == "false"
}

// CodexBin finds the codex executable: $MODELPLAN_CODEX, PATH, then the usual install places
// (hooks run with a short PATH). Empty when there is none.
func CodexBin(home string) string {
	if p := os.Getenv("MODELPLAN_CODEX"); p != "" {
		return p
	}
	exe := "codex"
	if runtime.GOOS == "windows" {
		exe = "codex.exe"
	}
	return toolcli.Find(home, exe, "/Applications/Codex.app/Contents/Resources/"+exe)
}

// AccountRefresh is the outcome of an explicit refresh. It covers Codex only: no other source
// has one, each keeps its own schedule.
type AccountRefresh struct {
	Source string     `json:"source"`
	Status string     `json:"status"`           // refreshed | too_soon | failed | not_allowed
	NextAt *time.Time `json:"nextAt,omitempty"` // too_soon: when asking again is allowed
	Reason string     `json:"reason,omitempty"` // failed, or why too_soon follows a failure
}

// RefreshAccountNow runs RefreshCodexAccount and says what came of it: that call returns nil
// both when it is too soon to ask and when it caches a failure.
func RefreshAccountNow(ctx context.Context, cache, codex string, now time.Time) *AccountRefresh {
	r := &AccountRefresh{Source: "codex"}
	failure := func() string {
		if s := loadAccount(cache); s != nil && s.Status != "ok" {
			return s.Error
		}
		return ""
	}
	if next, err := codexRefreshNext(cache); err == nil && now.Before(next) {
		at := next.UTC()
		r.Status, r.NextAt, r.Reason = "too_soon", &at, failure()
		return r
	}
	if err := RefreshCodexAccount(ctx, cache, codex, now); err != nil {
		r.Status, r.Reason = "failed", err.Error()
		return r
	}
	if s := loadAccount(cache); s == nil || s.Status != "ok" {
		r.Status, r.Reason = "failed", failure()
		return r
	}
	r.Status = "refreshed"
	return r
}

// RefreshCodexAccount asks Codex for the account's windows and credits and caches the answer
// (or the failure, so a missing login is not retried for half an hour). One refresh at a time.
func RefreshCodexAccount(ctx context.Context, cache, codex string, now time.Time) error {
	if cache == "" {
		return errors.New("reader budget unavailable")
	}
	if off() {
		return errors.New("disabled by MODELPLAN_CODEX_ACCOUNT") // before taking any shared lock
	}
	admission, err := consent.ReaderLockContext(ctx)
	if err != nil {
		return err
	}
	defer admission()
	state, mode := consent.Current()
	if !state.Allows("codex", consent.Runtime, mode) {
		return errors.New("Codex reader not permitted")
	}
	// A finished reading must survive a brief hold on the consent lock, and a timed-out read
	// must still be recorded, so this bounded wait does not follow the read's context.
	commit := func(s *accountSnap) error {
		s.Admission = state.CaptureStamp(consent.ScopeCodexRuntimeUsage)
		wait := AccountEvery
		if s.Status != "ok" {
			wait = accountRetryAfter
		}
		if err := reserveReaderAttempt(cache, "codex", now.Add(wait)); err != nil {
			return err
		}
		return consent.PublishContext(context.Background(), state.Fence(), func() error { return save(cache, s) })
	}
	if off() {
		return errors.New("disabled by MODELPLAN_CODEX_ACCOUNT")
	}

	unlock, ok := lock(cache, now)
	if !ok {
		return fmt.Errorf("another refresh is running: %w", consent.ErrReaderBusy)
	}
	defer unlock()
	next, err := codexRefreshNext(cache)
	if err != nil {
		return err
	}
	if now.Before(next) {
		return nil
	}
	if err := reserveReaderAttempt(cache, "codex", now.Add(AccountEvery)); err != nil {
		return err
	}
	if codex == "" {
		return commit(&accountSnap{SchemaVersion: 1, ObservedAt: now.UTC(), Status: "error", Error: "codex not found"})
	}
	if !consent.CurrentFence(state.Fence()) {
		return errors.New("consent changed; refresh stopped")
	}
	ctx, cancel := context.WithTimeout(ctx, accountTimeout)
	defer cancel()
	resp, err := askCodex(ctx, codex)
	if err != nil {
		// Runtime and process errors may contain credentials, paths or identities.
		// Discard their text before either returning the failure or caching it.
		status, reason := "error", errorCode(err)
		if errors.Is(err, context.DeadlineExceeded) {
			reason = "timeout"
		}
		safeErr := codeError(reason, reason)
		if errors.Is(err, toolcli.ErrRuntimeMissing) {
			status, reason = toolcli.RuntimeMissing, toolcli.RuntimeNextStep
			safeErr = toolcli.ErrRuntimeMissing
		}
		return errors.Join(safeErr, commit(&accountSnap{SchemaVersion: 1, ObservedAt: now.UTC(), Status: status, Error: reason}))
	}
	s := snapFrom(resp, now)
	attachResetCardIdentities(s, resp, cache)
	if resp.identity != "" {
		s.SubscriptionRef = assignSubscription(cache, "codex-account", resp.identity, now)
	}
	return commit(s)
}

// short keeps an error message to one line of at most 160 bytes.
func short(s string) string {
	s = strings.Join(strings.Fields(s), " ")
	if len(s) > 160 {
		s = s[:160]
	}
	return s
}

func lock(cache string, now time.Time) (func(), bool) {
	p := filepath.Join(cache, "observed", "codex-account.lock")
	_ = os.MkdirAll(filepath.Dir(p), 0o700)
	if fi, err := os.Stat(p); err == nil && now.Sub(fi.ModTime()) > 2*accountTimeout {
		_ = os.Remove(p) // left behind by a killed refresh
	}
	f, err := os.OpenFile(p, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		return nil, false
	}
	f.Close()
	return func() { _ = os.Remove(p) }, true
}

func save(cache string, s *accountSnap) error {
	b, _ := json.MarshalIndent(s, "", "  ")
	p := accountPath(cache)
	if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
		return err
	}
	return writeAtomic(p, b)
}

// Wire types: the part of account/rateLimits/read this client uses (Codex app-server v2).
type rlWindow struct {
	UsedPercent        *float64 `json:"usedPercent"`
	WindowDurationMins *int     `json:"windowDurationMins"`
	ResetsAt           *int64   `json:"resetsAt"`
}

type rlSnapshot struct {
	LimitID   *string   `json:"limitId"`
	LimitName *string   `json:"limitName"`
	Primary   *rlWindow `json:"primary"`
	Secondary *rlWindow `json:"secondary"`
	PlanType  *string   `json:"planType"`
	Credits   *struct {
		HasCredits bool            `json:"hasCredits"`
		Unlimited  bool            `json:"unlimited"`
		Balance    json.RawMessage `json:"balance"`
	} `json:"credits"`
}

type rlResponse struct {
	RateLimits           *rlSnapshot            `json:"rateLimits"`
	RateLimitsByLimitID  map[string]*rlSnapshot `json:"rateLimitsByLimitId"`
	identity             string                 // from account/read; never cached
	RateLimitResetCredit *struct {
		AvailableCount *int64 `json:"availableCount"`
		Credits        []struct {
			ID        string `json:"id"`
			Status    string `json:"status"`
			ExpiresAt *int64 `json:"expiresAt"`
		} `json:"credits"`
	} `json:"rateLimitResetCredits"`
}

func askCodex(ctx context.Context, codex string) (*rlResponse, error) {
	cmd, err := toolcli.CommandContext(ctx, codex, "app-server")
	if err != nil {
		return nil, err
	}
	cmd.Stderr = io.Discard
	in, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	out, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	defer func() { _ = in.Close(); _ = cmd.Process.Kill(); _ = cmd.Wait() }()
	send := func(v any) error { b, _ := json.Marshal(v); _, err := in.Write(append(b, '\n')); return err }
	sc := bufio.NewScanner(out)
	sc.Buffer(make([]byte, 0, 64<<10), 4<<20)
	wait := func(id int) (json.RawMessage, error) {
		for sc.Scan() {
			var m struct {
				ID     *int            `json:"id"`
				Result json.RawMessage `json:"result"`
				Error  *struct {
					Message string `json:"message"`
				} `json:"error"`
			}
			if json.Unmarshal(sc.Bytes(), &m) != nil || m.ID == nil || *m.ID != id {
				continue
			}
			if m.Error != nil {
				return nil, codeError("other", "other")
			}
			return m.Result, nil
		}
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return nil, errors.New("codex app-server closed")
	}
	if err := send(map[string]any{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": map[string]any{
		"clientInfo": map[string]any{"name": "modelplan", "title": "modelplan quota", "version": "1"}, "capabilities": map[string]any{"experimentalApi": true}}}); err != nil {
		return nil, err
	}
	if _, err := wait(1); err != nil {
		return nil, err
	}
	_ = send(map[string]any{"jsonrpc": "2.0", "method": "initialized"})
	if err := send(map[string]any{"jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read", "params": map[string]any{}}); err != nil {
		return nil, err
	}
	raw, err := wait(2)
	if err != nil {
		return nil, err
	}
	var r rlResponse
	if err := json.Unmarshal(raw, &r); err != nil {
		return nil, err
	}
	if IdentityOff() {
		return &r, nil
	}
	// Which account the meters belong to: account/read, without refreshing the login. A failure
	// leaves the reading without a subscription.
	if send(map[string]any{"jsonrpc": "2.0", "id": 3, "method": "account/read", "params": map[string]any{"refreshToken": false}}) == nil {
		if raw, err := wait(3); err == nil {
			r.identity = codexIdentity(raw)
		}
	}
	return &r, nil
}

// codexIdentity: the signed-in ChatGPT account (its e-mail, as Codex reports it), "" for an API
// key login or none.
func codexIdentity(raw json.RawMessage) string {
	var a struct {
		Account *struct {
			Type  string `json:"type"`
			Email string `json:"email"`
		} `json:"account"`
	}
	if json.Unmarshal(raw, &a) != nil || a.Account == nil || a.Account.Type == "apiKey" {
		return ""
	}
	return strings.ToLower(strings.TrimSpace(a.Account.Email))
}

func snapFrom(r *rlResponse, now time.Time) *accountSnap {
	s := &accountSnap{SchemaVersion: 1, ObservedAt: now.UTC(), Status: "ok", Windows: []Window{}}
	snaps := r.RateLimitsByLimitID
	if len(snaps) == 0 && r.RateLimits != nil {
		snaps = map[string]*rlSnapshot{"": r.RateLimits}
	}
	keys := make([]string, 0, len(snaps))
	for k := range snaps {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		x := snaps[k]
		if x == nil {
			continue
		}
		limit, name := k, ""
		if x.LimitID != nil && *x.LimitID != "" {
			limit = *x.LimitID
		}
		if x.LimitName != nil {
			name = *x.LimitName
		}
		limit = codexLimit(limit, name)
		if x.PlanType != nil && s.Plan == "" && *x.PlanType != "unknown" {
			s.Plan = clip(*x.PlanType)
		}
		if c := x.Credits; c != nil && !s.UsageRead {
			s.Usage, s.UsageRead = creditsFrom(c.HasCredits, c.Unlimited, c.Balance, now), true
		}
		for _, w := range []*rlWindow{x.Primary, x.Secondary} {
			if w == nil || w.UsedPercent == nil || w.WindowDurationMins == nil || *w.WindowDurationMins <= 0 {
				continue
			}
			win := Window{Kind: kindOf(*w.WindowDurationMins), Limit: limit, UsedPercent: w.UsedPercent, WindowMinutes: *w.WindowDurationMins, ResetMode: "fixed", ObservedAt: now.UTC()}
			if w.ResetsAt != nil {
				t := time.Unix(*w.ResetsAt, 0).UTC()
				win.ResetsAt = &t
			}
			s.Windows = append(s.Windows, win)
		}
	}
	if c := r.RateLimitResetCredit; c != nil && c.AvailableCount != nil && *c.AvailableCount >= 0 && *c.AvailableCount < 10000 {
		s.Credits = &accountResetCredits{Count: int(*c.AvailableCount)}
		for _, d := range c.Credits {
			if d.Status != "available" {
				continue
			}
			var t *time.Time
			if d.ExpiresAt != nil {
				x := time.Unix(*d.ExpiresAt, 0).UTC()
				t = &x
			}
			s.Credits.Expiries = append(s.Credits.Expiries, t)
		}
	}
	return s
}

// Duplicate IDs with conflicting expiries make the set incomplete.
func attachResetCardIdentities(s *accountSnap, r *rlResponse, cache string) {
	if s.Credits == nil || r.RateLimitResetCredit == nil {
		return
	}
	s.Credits.IdentityObserved = true
	if IdentityOff() {
		s.Credits.IdentityComplete = s.Credits.Count == 0 && len(r.RateLimitResetCredit.Credits) == 0
		return
	}
	seen := map[string]*time.Time{}
	complete := true
	for index, c := range r.RateLimitResetCredit.Credits {
		if index >= 64 {
			s.Credits.Truncated = true
			complete = false
			break
		}
		if c.Status != "available" {
			continue
		}
		if c.ID == "" || len(c.ID) > 512 {
			complete = false
			continue
		}
		id := readerHash(cache, "codex-reset-card", c.ID)
		if len(id) != 64 {
			complete = false
			continue
		}
		var expiry *time.Time
		if c.ExpiresAt != nil {
			t := time.Unix(*c.ExpiresAt, 0).UTC()
			expiry = &t
		}
		if previous, ok := seen[id]; ok {
			if (previous == nil) != (expiry == nil) || previous != nil && !previous.Equal(*expiry) {
				complete = false
			}
			continue
		}
		seen[id] = expiry
	}
	ids := make([]string, 0, len(seen))
	for id := range seen {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	for _, id := range ids {
		s.Credits.Items = append(s.Credits.Items, resetCardIdentity{ID: id, ExpiresAt: seen[id]})
	}
	s.Credits.IdentityComplete = complete && len(ids) == s.Credits.Count
}

// applyAccount merges only when an existing verified reference binds the local
// and runtime readings. Otherwise the runtime reading stands alone.

func applyAccount(r *Report, cache string, now time.Time, admissions ...consent.Admission) {
	admission := consent.Capture()
	if len(admissions) > 0 {
		admission = admissions[0]
	}
	if !admission.Allows("codex", consent.Runtime) {
		return
	}
	s := loadAccount(cache)
	if s != nil && !admission.State().CaptureAllowed(s.Admission, consent.ScopeCodexRuntimeUsage) {
		return
	}
	if s != nil && s.Status == toolcli.RuntimeMissing && now.Sub(s.ObservedAt) <= accountKeep && !s.ObservedAt.After(now) {
		r.Sources = append(r.Sources, SourceStatus{Source: "codex-account", Status: toolcli.RuntimeMissing, Reason: toolcli.RuntimeNextStep, ErrorCode: "runtime_missing"})
	}
	if s == nil || s.Status != "ok" || now.Sub(s.ObservedAt) > accountKeep || s.ObservedAt.After(now.Add(5*time.Minute)) {
		return
	}
	// Owner decision (2026-11-06, G3-20 option B): while Codex's own live account reading is
	// available it is the only Codex account. Session logs carry no account, so they are not a
	// second source: no guessing which login wrote them, no joining, no second row. Only the
	// current session's harness (model, effort, allowance pool) carries over; the logs' plan,
	// windows and credits do not.
	// "Available" is CodexRuntimeAvailable, the predicate the scheduler uses to fall back to
	// local history (macrev2-602-2): not turned off, a successful admitted reading within
	// accountKeep, and at least one window not yet reset. Otherwise the session logs remain the
	// Codex reading, as before; the unusable runtime snapshot is only shown when there are no
	// logs at all.
	live := CodexRuntimeAvailable(cache, admission, now)
	if !live {
		for _, candidate := range r.Accounts {
			if candidate.Source == "codex" && candidate.Via == "" && candidate.Subscription == nil {
				return
			}
		}
	}
	var harness *Harness
	pool := ""
	hadLocal := false
	kept := r.Accounts[:0]
	for _, candidate := range r.Accounts {
		if candidate.Source == "codex" && candidate.Via == "" && candidate.Subscription == nil {
			hadLocal = true
			if harness == nil && candidate.Harness != nil {
				harness, pool = candidate.Harness, candidate.Pool
			}
			continue
		}
		kept = append(kept, candidate)
	}
	r.Accounts = kept
	var a *Account
	for i := range r.Accounts {
		candidate := &r.Accounts[i]
		if candidate.Source == "codex" {
			hadLocal = true
		}
		// A provider name is not an account binding. Without matching verified
		// references, keep the local and runtime readings separate.
		if candidate.Source == "codex" && !IdentityOff() && s.SubscriptionRef != "" &&
			candidate.Subscription != nil && candidate.Subscription.Status == "verified" &&
			candidate.Subscription.Ref == s.SubscriptionRef {
			a = candidate

			break
		}
	}
	if a == nil {
		r.Accounts = append(r.Accounts, Account{Source: "codex", Plan: s.Plan, ObservedAt: s.ObservedAt, Windows: []Window{}})
		a = &r.Accounts[len(r.Accounts)-1]
		if !hadLocal {
			for i := range r.Sources {
				if r.Sources[i].Source == "codex" {
					r.Sources[i] = SourceStatus{Source: "codex", Status: "ok", Reason: "Codex account reading; no Codex log carries one"}
				}
			}
		}
	}
	if s.Plan != "" && a.Plan != "" && s.Plan != a.Plan && s.ObservedAt.After(a.ObservedAt) {
		a.Windows = []Window{} // the account changed plan since the logs were written
	}
	// An older runtime reading of a different plan says nothing about the newer plan's
	// windows: none of them is merged or fills a gap (macrevb-602-3).
	olderPlan := s.Plan != "" && a.Plan != "" && s.Plan != a.Plan && s.ObservedAt.Before(a.ObservedAt)
	if s.Plan != "" && (a.Plan == "" || !s.ObservedAt.Before(a.ObservedAt)) {
		a.Plan = s.Plan // an older runtime reading never undoes a newer plan (an upgrade)
	}
	if a.Harness == nil && harness != nil {
		a.Harness, a.Pool = harness, pool
	}
	for _, w := range s.Windows {
		if olderPlan {
			break
		}
		w.Origin = "runtime"
		found := false
		for i := range a.Windows {
			x := &a.Windows[i]
			if x.Kind == w.Kind && x.WindowMinutes == w.WindowMinutes && x.Limit == w.Limit {
				found = true
				if w.ObservedAt.After(x.ObservedAt) {
					*x = withHistory(w, *x)
				} else {
					*x = withHistory(*x, w)
				}
			}
		}
		if !found {
			a.Windows = append(a.Windows, w)
		}
	}
	if s.ObservedAt.After(a.ObservedAt) {
		a.ObservedAt = s.ObservedAt
	}
	a.Via = "codex-account"
	if s.SubscriptionRef != "" && !IdentityOff() {
		a.Subscription = &Binding{Ref: s.SubscriptionRef, Status: "verified", Basis: "codex-account", ObservedAt: s.ObservedAt}
	}
	if s.UsageRead && (a.Credits == nil || !s.ObservedAt.Before(a.Credits.ObservedAt)) {
		a.Credits = s.Usage // the newer say wins, "none" included
	}
	if c := s.Credits; c != nil {
		if !c.countPresent {
			a.ResetCards = &rows.ResetCards{State: rows.ResetCardUnknown, Sources: []rows.ResetCardSource{}}
			return
		}
		if c.Count > 0 {
			a.Cards = append(a.Cards, creditCards(c.Count, c.Expiries)...)
		}
		if !c.IdentityObserved {
			a.ResetCards = &rows.ResetCards{State: rows.ResetCardUnknown, Sources: []rows.ResetCardSource{}}
			return
		}
		count := c.Count
		facts := &rows.ResetCards{State: "partial", Count: &count, Truncated: c.Truncated,
			Sources: []rows.ResetCardSource{{Source: "codex-account", ObservedAt: s.ObservedAt.UTC()}}}
		if c.IdentityComplete {
			facts.State = "complete"
		}
		for _, item := range c.Items {
			facts.Items = append(facts.Items, rows.ResetCardItem{ID: item.ID, ExpiresAt: item.ExpiresAt})
		}
		if c.IdentityComplete && len(c.Items) > 0 {
			allExpiring := true
			for _, item := range c.Items {
				if item.ExpiresAt == nil || !item.ExpiresAt.After(now) {
					allExpiring = false
					break
				}
				if facts.EarliestExpiresAt == nil || item.ExpiresAt.Before(*facts.EarliestExpiresAt) {
					facts.EarliestExpiresAt = item.ExpiresAt
				}
			}
			if !allExpiring {
				facts.EarliestExpiresAt = nil
			}
		}
		a.ResetCards = facts
	}
}

// creditCards: Codex reset credits restore every window ("full"). Credits sharing an expiry are
// one card; credits without details are counted with an unknown expiry.
func creditCards(count int, expiries []*time.Time) []Card {
	var cards []Card
	byTime := map[time.Time]int{}
	never := 0
	for _, t := range expiries {
		if t == nil {
			never++
		} else {
			byTime[*t]++
		}
	}
	times := make([]time.Time, 0, len(byTime))
	for t := range byTime {
		times = append(times, t)
	}
	sort.Slice(times, func(i, j int) bool { return times[i].Before(times[j]) })
	listed := never
	for _, t := range times {
		n, at := byTime[t], t
		listed += n
		cards = append(cards, Card{Kind: "full", Count: &n, ExpiresAt: &at})
	}
	if rest := count - listed + never; rest > 0 {
		cards = append(cards, Card{Kind: "full", Count: &rest})
	}
	return cards
}

// The independent attempt file survives Forget and is checked inside the
// existing provider lock by explicit CLI and app-server refreshes alike.
func codexRefreshNext(cache string) (time.Time, error) {
	next, err := loadReaderAttempt(cache, "codex")
	if err != nil {
		return next, err
	}
	if snapshot := loadAccount(cache); snapshot != nil {
		wait := AccountEvery
		if snapshot.Status != "ok" {
			wait = accountRetryAfter
		}
		until := snapshot.ObservedAt.Add(wait)
		if until.After(next) {
			next = until
		}
	} else {
		if _, status := readBounded(accountPath(cache), 256<<10); status != "missing" {
			return next, errors.New("reader budget unavailable")
		}
	}
	return next, nil
}
