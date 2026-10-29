package quota

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"
)

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
	Credits *struct {
		Count    int          `json:"count"`
		Expiries []*time.Time `json:"expiries,omitempty"`
	} `json:"credits,omitempty"`
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

// AccountDue: the cached reading is old enough to ask Codex again.
func AccountDue(cache string, now time.Time) bool {
	if off() || cache == "" {
		return false
	}
	s := loadAccount(cache)
	if s == nil {
		return true
	}
	wait := AccountEvery
	if s.Status != "ok" {
		wait = accountRetryAfter
	}
	return now.Sub(s.ObservedAt) >= wait
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
		return consent.Publish(state.Fence(), func() error { return save(cache, s) })
	}
	if off() {
		return errors.New("disabled by MODELPLAN_CODEX_ACCOUNT")
	}
	if codex == "" {
		return commit(&accountSnap{SchemaVersion: 1, ObservedAt: now.UTC(), Status: "error", Error: "codex not found"})
	}
	unlock, ok := lock(cache, now)
	if !ok {
		return errors.New("another refresh is running")
	}
	defer unlock()
	if !consent.CurrentFence(state.Fence()) {
		return errors.New("consent changed; refresh stopped")
	}
	ctx, cancel := context.WithTimeout(ctx, accountTimeout)
	defer cancel()
	resp, err := askCodex(ctx, codex)
	if err != nil {
		status, reason := "error", short(err.Error())
		if errors.Is(err, toolcli.ErrRuntimeMissing) {
			status, reason = toolcli.RuntimeMissing, toolcli.RuntimeNextStep
		}
		return errors.Join(err, commit(&accountSnap{SchemaVersion: 1, ObservedAt: now.UTC(), Status: status, Error: reason}))
	}
	s := snapFrom(resp, now)
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
		AvailableCount int64 `json:"availableCount"`
		Credits        []struct {
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
				return nil, errors.New(m.Error.Message)
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
	if c := r.RateLimitResetCredit; c != nil && c.AvailableCount >= 0 && c.AvailableCount < 10000 {
		s.Credits = &struct {
			Count    int          `json:"count"`
			Expiries []*time.Time `json:"expiries,omitempty"`
		}{Count: int(c.AvailableCount)}
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

// applyAccount merges a recent account reading into the Codex account from the logs: newest
// observation per window, the account's plan and its reset credits. Without logs it stands alone.
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
	for i := range r.Accounts {
		if r.Accounts[i].Source == "codex" {
			a = &r.Accounts[i]
		}
	}
	if a == nil {
		r.Accounts = append(r.Accounts, Account{Source: "codex", Plan: s.Plan, ObservedAt: s.ObservedAt, Windows: []Window{}})
		a = &r.Accounts[len(r.Accounts)-1]
		for i := range r.Sources {
			if r.Sources[i].Source == "codex" {
				r.Sources[i] = SourceStatus{Source: "codex", Status: "ok", Reason: "Codex account reading; no Codex log carries one"}
			}
		}
	}
	if s.Plan != "" && a.Plan != "" && s.Plan != a.Plan && s.ObservedAt.After(a.ObservedAt) {
		a.Windows = []Window{} // the account changed plan since the logs were written
	}
	if s.Plan != "" {
		a.Plan = s.Plan
	}
	for _, w := range s.Windows {
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
	if c := s.Credits; c != nil && c.Count > 0 {
		a.Cards = append(a.Cards, creditCards(c.Count, c.Expiries)...)
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
