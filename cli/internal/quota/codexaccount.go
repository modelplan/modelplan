package quota

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
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
	// MeterRef/Meters: the reset instants Codex reported for this account's windows, kept
	// across refreshes of the same account. A session-log reading of the same meter (same
	// allowance, window length and reset instant) is that account's reading, which binds the
	// logs to the account without a provider-name guess. No identity is kept here.
	MeterRef string      `json:"meterRef,omitempty"`
	Meters   []meterMark `json:"meters,omitempty"`
	// Foreign: cycles Codex reported for a different login on this Mac (no reference is
	// kept). A session-log reading of one of them is that other login's, never this one's.
	Foreign []meterMark `json:"foreign,omitempty"`
	// PlanSince/SincePlan: when ModelPlan first read this account on its current plan.
	// Unbound session logs of a different plan written before then are superseded.
	PlanSince time.Time `json:"planSince,omitempty"`
	SincePlan string    `json:"sincePlan,omitempty"`
}

// meterMark: one window cycle of an account, known by its reset instant.
type meterMark struct {
	Limit    string    `json:"limit,omitempty"`
	Kind     string    `json:"kind"`
	Minutes  int       `json:"windowMinutes"`
	ResetsAt time.Time `json:"resetsAt"`
}

const (
	maxMeterMarks = 32
	// meterKeep: a mark is kept while a session-log reading of its cycle can still be shown.
	meterKeep = 14 * 24 * time.Hour
	// meterSlack: older Codex logs give a relative reset time, so their instant can differ by
	// the moment the line was written; two different accounts do not share a reset this close.
	meterSlack = time.Minute
)

// windowMarks: the cycles of a reading's windows.
func windowMarks(windows []Window) []meterMark {
	var marks []meterMark
	for _, w := range windows {
		if w.ResetsAt != nil && w.WindowMinutes > 0 {
			marks = append(marks, meterMark{Limit: w.Limit, Kind: w.Kind, Minutes: w.WindowMinutes, ResetsAt: w.ResetsAt.UTC()})
		}
	}
	return marks
}

// withMeters: the account's marks after this reading, carrying earlier marks of the same
// account forward. Marks of a different login move to Foreign. A cache written before the
// marks existed contributes its windows as that login's marks.
func withMeters(prev *accountSnap, s *accountSnap, now time.Time) {
	if s.SubscriptionRef == "" || IdentityOff() {
		if prev != nil && s.Status != "ok" { // a failed read proves nothing new
			s.MeterRef, s.Meters, s.Foreign, s.PlanSince, s.SincePlan = prev.MeterRef, prev.Meters, prev.Foreign, prev.PlanSince, prev.SincePlan
		}
		return
	}
	add := func(list []meterMark, m meterMark) []meterMark {
		if now.Sub(m.ResetsAt) > meterKeep {
			return list
		}
		for _, x := range list {
			if x.Limit == m.Limit && x.Kind == m.Kind && x.Minutes == m.Minutes && x.ResetsAt.Equal(m.ResetsAt) {
				return list
			}
		}
		return append(list, m)
	}
	var own, foreign []meterMark
	for _, m := range windowMarks(s.Windows) {
		own = add(own, m)
	}
	s.PlanSince, s.SincePlan = s.ObservedAt, s.Plan
	if prev != nil {
		prevRef, prevMarks, prevPlan, prevSince := prev.MeterRef, prev.Meters, prev.SincePlan, prev.PlanSince
		if prevRef == "" && prev.Status == "ok" && prev.SubscriptionRef != "" {
			prevRef, prevMarks, prevPlan, prevSince = prev.SubscriptionRef, windowMarks(prev.Windows), prev.Plan, prev.ObservedAt
		}
		switch {
		case prevRef == s.SubscriptionRef:
			for _, m := range prevMarks {
				own = add(own, m)
			}
			if prevPlan == s.Plan && !prevSince.IsZero() && prevSince.Before(s.PlanSince) {
				s.PlanSince = prevSince
			}
		case prevRef != "":
			for _, m := range prevMarks {
				foreign = add(foreign, m)
			}
		}
		for _, m := range prev.Foreign {
			foreign = add(foreign, m)
		}
	}
	mine := foreign[:0]
	for _, m := range foreign {
		if !containsMark(own, m) { // a cycle this account reported is never another login's
			mine = append(mine, m)
		}
	}
	foreign = mine
	if len(own) > maxMeterMarks {
		own = own[:maxMeterMarks] // current windows first, then the newest earlier marks
	}
	if len(foreign) > maxMeterMarks {
		foreign = foreign[:maxMeterMarks]
	}
	s.MeterRef, s.Meters, s.Foreign = s.SubscriptionRef, own, foreign
}

func containsMark(list []meterMark, m meterMark) bool {
	for _, x := range list {
		if x.Limit == m.Limit && x.Kind == m.Kind && x.Minutes == m.Minutes && x.ResetsAt.Equal(m.ResetsAt) {
			return true
		}
	}
	return false
}

// nearMark: a log window reports this cycle (relative-time logs may be off by meterSlack).
func nearMark(w Window, m meterMark) bool {
	if w.ResetsAt == nil || m.Limit != w.Limit || m.Kind != w.Kind || m.Minutes != w.WindowMinutes {
		return false
	}
	d := w.ResetsAt.Sub(m.ResetsAt)
	return d <= meterSlack && d >= -meterSlack
}

// overlapsMark: a log window reports a different cycle that overlaps this one in time. One
// login's cycles of one window never overlap, so the log is not this login's.
func overlapsMark(w Window, m meterMark) bool {
	if w.ResetsAt == nil || m.Limit != w.Limit || m.Kind != w.Kind || m.Minutes != w.WindowMinutes || nearMark(w, m) {
		return false
	}
	d := w.ResetsAt.Sub(m.ResetsAt)
	if d < 0 {
		d = -d
	}
	return d < time.Duration(m.Minutes)*time.Minute
}

// sameMeter: a session-log account with no account binding of its own reports window cycles
// that Codex reported for the runtime reading's account, and none that disagrees with them
// or that Codex reported for another login. A single matching reset is not enough when
// another window of the same reading points elsewhere (macrevb-602-2).
func sameMeter(local *Account, s *accountSnap) bool {
	if s.SubscriptionRef == "" {
		return false
	}
	marks := windowMarks(s.Windows)
	if s.MeterRef == s.SubscriptionRef {
		marks = append(marks, s.Meters...)
	}
	matched := false
	for _, w := range local.Windows {
		if w.ResetsAt == nil || w.WindowMinutes <= 0 {
			continue
		}
		for _, m := range s.Foreign {
			if nearMark(w, m) {
				return false
			}
		}
		hit, conflict := false, false
		for _, m := range marks {
			hit = hit || nearMark(w, m)
			conflict = conflict || overlapsMark(w, m)
		}
		if conflict && !hit {
			return false
		}
		matched = matched || hit
	}
	return matched
}

// supersededLogs: an unbound session-log account of a different plan whose newest reading
// predates ModelPlan's first reading of the runtime account on its current plan, and which
// reports no other login's cycle. It is the account before a plan change that ModelPlan did
// not observe (macrevb-602-1); it is hidden, not bound, so no identity is claimed for it. A
// log written after that first reading is shown on its own as usual.
func supersededLogs(local *Account, s *accountSnap) bool {
	if local.Source != "codex" || local.Via != "" || local.Subscription != nil || IdentityOff() ||
		s.SubscriptionRef == "" || s.Plan == "" || local.Plan == "" || local.Plan == s.Plan ||
		s.SincePlan != s.Plan || s.PlanSince.IsZero() || !local.ObservedAt.Before(s.PlanSince) {
		return false
	}
	for _, w := range local.Windows {
		for _, m := range s.Foreign {
			if nearMark(w, m) {
				return false
			}
		}
	}
	return true
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
	commit := func(s *accountSnap) error {
		s.Admission = state.CaptureStamp(consent.ScopeCodexRuntimeUsage)
		withMeters(loadAccount(cache), s, now)
		wait := AccountEvery
		if s.Status != "ok" {
			wait = accountRetryAfter
		}
		if err := reserveReaderAttempt(cache, "codex", now.Add(wait)); err != nil {
			return err
		}
		return consent.Publish(state.Fence(), func() error { return save(cache, s) })
	}
	if off() {
		return errors.New("disabled by MODELPLAN_CODEX_ACCOUNT")
	}

	unlock, ok := lock(cache, now)
	if !ok {
		return errors.New("another refresh is running")
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
	var a *Account
	hadLocal := false
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
	if a == nil && !IdentityOff() {
		// Session logs carry no account, but they do carry the meters: a log reading of a
		// window cycle Codex reported for this account is this account's reading (G3-20).
		// A log account bound to another account is never joined.
		for i := range r.Accounts {
			candidate := &r.Accounts[i]
			if candidate.Source == "codex" && candidate.Via == "" && candidate.Subscription == nil && sameMeter(candidate, s) {
				a = candidate
				break
			}
		}
	}
	if a == nil {
		kept := r.Accounts[:0]
		for _, candidate := range r.Accounts {
			if !supersededLogs(&candidate, s) {
				kept = append(kept, candidate)
			}
		}
		r.Accounts = kept
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
