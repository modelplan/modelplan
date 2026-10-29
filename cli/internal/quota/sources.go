package quota

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

// ---- Claude Code: the status line receives rate_limits on stdin; we keep a sanitised copy.

// StatuslineInput is the subset of Claude Code's status-line JSON that ModelPlan uses.
// Paths and costs are deliberately not decoded; the session id only becomes a one-way key.
type StatuslineInput struct {
	SessionID string `json:"session_id"`
	Model     struct {
		ID          string `json:"id"`
		DisplayName string `json:"display_name"`
	} `json:"model"`
	Version string `json:"version"`
	Effort  *struct {
		Level string `json:"level"`
	} `json:"effort"`
	FastMode *bool `json:"fast_mode"`
	// TranscriptPath: the session's transcript, read only for local speed measurement.
	TranscriptPath string `json:"transcript_path"`
	// Endpoint is not part of the status-line JSON: the caller sets it from ANTHROPIC_BASE_URL,
	// reduced to scheme, host and path.
	Endpoint   string `json:"-"`
	RateLimits *struct {
		FiveHour   *ccWindow `json:"five_hour"`
		SevenDay   *ccWindow `json:"seven_day"`
		SpendLimit *ccWindow `json:"spend_limit"`
	} `json:"rate_limits"`
}

type ccWindow struct {
	UsedPercentage *float64 `json:"used_percentage"`
	ResetsAt       *int64   `json:"resets_at"`
	UsedUSD        *float64 `json:"used_usd"`
	LimitUSD       *float64 `json:"limit_usd"`
	Period         string   `json:"period"`
}

type ccSnapshot struct {
	Admission     *consent.CaptureStamp `json:"admission,omitempty"`
	SchemaVersion int                   `json:"schemaVersion"`
	Source        string                `json:"source"`
	ObservedAt    time.Time             `json:"observedAt"`
	Harness       Harness               `json:"harness"`
	Windows       []Window              `json:"windows"`
	// SessionKey tells this session's model and effort from another's (the usage windows are
	// the account's either way); a hash, so the snapshot holds no session id.
	SessionKey string `json:"sessionKey,omitempty"`
	// Recent: earlier readings per window kind from the last hour, for the recent rate of use.
	Recent map[string][]Sample `json:"recent,omitempty"`
	// Identity: the subscription of the account Claude Code is signed in to (identity.go), with
	// the size and time of the file it came from, so the file is read again only when it changes.
	Identity *ccIdentity `json:"identity,omitempty"`
}

type ccIdentity struct {
	Ref        string    `json:"subscriptionRef"`
	FileSize   int64     `json:"fileSize"`
	FileTime   time.Time `json:"fileTime"`
	ObservedAt time.Time `json:"observedAt"`
}

// SessionKey is the one-way key for a Claude Code session id ("" for none).
func SessionKey(id string) string {
	if id == "" {
		return ""
	}
	h := sha256.Sum256([]byte("modelplan-session:" + id))
	return hex.EncodeToString(h[:8])
}

func snapshotPath(cache string) string { return filepath.Join(cache, "observed", "claude-code.json") }

// Account turns status-line input into an unevaluated Claude Code account.
func (in StatuslineInput) Account(now time.Time) Account {
	a := Account{Source: "claude-code", ObservedAt: now.UTC(), Windows: []Window{}}
	h := Harness{Model: clip(in.Model.ID), Version: clip(in.Version), FastMode: in.FastMode, Endpoint: clipEndpoint(in.Endpoint)}
	if in.Effort != nil {
		h.Effort = clip(in.Effort.Level)
	}
	a.Harness = &h
	if in.RateLimits == nil {
		return a
	}
	for _, x := range []struct {
		kind string
		w    *ccWindow
	}{{"five_hour", in.RateLimits.FiveHour}, {"weekly", in.RateLimits.SevenDay}, {"spend", in.RateLimits.SpendLimit}} {
		if x.w == nil {
			continue
		}
		w := Window{Kind: x.kind, UsedPercent: finite(x.w.UsedPercentage, 0, 1000), ResetsAt: unixTime(x.w.ResetsAt), ResetMode: "fixed", ObservedAt: a.ObservedAt}
		if x.kind == "spend" {
			w.WindowMinutes = map[string]int{"daily": 1440, "weekly": 10080, "monthly": 43200}[x.w.Period]
			w.UsedUSD, w.LimitUSD = finite(x.w.UsedUSD, 0, 1e9), finite(x.w.LimitUSD, 0, 1e9)
		}
		a.Windows = append(a.Windows, w)
	}
	return a
}

// RecordClaudeCode saves the sanitised snapshot. The status line renders often, so an
// unchanged snapshot is rewritten at most once a minute. The previous readings of the last hour
// are kept with it, for the recent rate of use.
func RecordClaudeCode(cache string, in StatuslineInput, now time.Time) error {
	a := in.Account(now)
	if a.Harness.Model == "" && len(a.Windows) == 0 {
		return nil
	}
	state, _ := consent.Current()
	snap := ccSnapshot{Admission: state.CaptureStamp(consent.ScopeClaudeLocalHistory), SchemaVersion: 1, Source: "claude-code-statusline", ObservedAt: a.ObservedAt, Harness: *a.Harness, Windows: a.Windows, SessionKey: SessionKey(in.SessionID)}
	p := snapshotPath(cache)
	var prev *ccSnapshot
	if old, err := os.ReadFile(p); err == nil {
		var x ccSnapshot
		if json.Unmarshal(old, &x) == nil && x.SchemaVersion == 1 && state.CaptureAllowed(x.Admission, consent.ScopeClaudeLocalHistory) {
			prev = &x
		}
	}
	snap.Identity = claudeIdentity(cache, prev, now)
	if prev != nil {
		if now.Sub(prev.ObservedAt) < time.Minute && bytes.Equal(content(*prev), content(snap)) {
			return nil
		}
		snap.Recent = keepRecent(*prev, snap.Windows)
	}
	if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
		return err
	}
	return writeAtomic(p, marshal(snap))
}

// AttachRecent gives a Claude Code account read from status-line input the earlier readings the
// snapshot keeps, so the status line sees the same recent rate as the hook and `quota`.
func AttachRecent(cache string, a *Account) {
	b, status := readBounded(snapshotPath(cache), 64<<10)
	var s ccSnapshot
	if status != "" || json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 {
		return
	}
	state, _ := consent.Current()
	if !state.CaptureAllowed(s.Admission, consent.ScopeClaudeLocalHistory) {
		return
	}
	for i := range a.Windows {
		for _, x := range s.Recent[a.Windows[i].Kind] {
			if x.At.Before(a.Windows[i].ObservedAt) {
				a.Windows[i].addSample(x)
			}
		}
	}
}

// keepRecent: the previous snapshot's samples and readings that belong to the new readings' cycles.
func keepRecent(prev ccSnapshot, ws []Window) map[string][]Sample {
	out := map[string][]Sample{}
	for _, w := range ws {
		older := Window{recent: prev.Recent[w.Kind]}
		for _, x := range prev.Windows {
			if x.Kind == w.Kind {
				older.UsedPercent, older.ObservedAt, older.ResetsAt = x.UsedPercent, x.ObservedAt, x.ResetsAt
			}
		}
		if rec := withHistory(w, older).recent; len(rec) > 0 {
			out[w.Kind] = rec
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

// content is the snapshot without its observation times and history.
func content(s ccSnapshot) []byte {
	s.ObservedAt, s.Recent = time.Time{}, nil
	s.Windows = append([]Window(nil), s.Windows...)
	for i := range s.Windows {
		s.Windows[i].ObservedAt = time.Time{}
	}
	return marshal(s)
}

// readClaudeCode: session, when known (the hook's or CLAUDE_CODE_SESSION_ID), marks whose
// model and effort the snapshot holds: current-thread or recent-thread (another session).
func readClaudeCode(cache, session string) ([]Account, SourceStatus) {
	st := SourceStatus{Source: "claude-code"}
	b, status := readBounded(snapshotPath(cache), 64<<10)
	if status != "" {
		st.Status = status
		if status == "missing" {
			st.Reason = "no status-line snapshot yet; install the ModelPlan status line in Claude Code"
		}
		return nil, st
	}
	var s ccSnapshot
	if json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 {
		st.Status = "invalid"
		return nil, st
	}
	state, _ := consent.Current()
	if !state.CaptureAllowed(s.Admission, consent.ScopeClaudeLocalHistory) {
		st.Status = "missing"
		st.Reason = "no reading under current consent"
		return nil, st
	}
	a := Account{Source: "claude-code", ObservedAt: s.ObservedAt, Harness: &s.Harness, Windows: s.Windows}
	for i := range a.Windows {
		for _, x := range s.Recent[a.Windows[i].Kind] {
			a.Windows[i].addSample(x)
		}
	}
	if session != "" && s.SessionKey != "" {
		a.Harness.Attribution = "recent-thread"
		if SessionKey(session) == s.SessionKey {
			a.Harness.Attribution = "current-thread"
		}
	}
	if a.Windows == nil {
		a.Windows = []Window{}
	}
	if id := s.Identity; id != nil && id.Ref != "" && !IdentityOff() {
		a.Subscription = &Binding{Ref: id.Ref, Status: "verified", Basis: "claude-config", ObservedAt: id.ObservedAt}
	}
	st.Status = "ok"
	if len(a.Windows) == 0 {
		st.Reason = "Claude Code reported no usage windows (API key or not yet a response this session)"
	}
	return []Account{a}, st
}

// ---- Codex: every turn's token_count event carries the account's rate_limits snapshot.

type rolloutLine struct {
	Timestamp string          `json:"timestamp"`
	Type      string          `json:"type"`
	Payload   json.RawMessage `json:"payload"`
}

type codexWindow struct {
	UsedPercent   *float64 `json:"used_percent"`
	WindowMinutes *int     `json:"window_minutes"`
	ResetsAt      *int64   `json:"resets_at"`
	ResetsIn      *int64   `json:"resets_in_seconds"` // older Codex versions
}

type codexLimits struct {
	LimitID   string       `json:"limit_id"`
	LimitName string       `json:"limit_name"`
	Primary   *codexWindow `json:"primary"`
	Secondary *codexWindow `json:"secondary"`
	PlanType  string       `json:"plan_type"`
	Credits   *struct {
		Has       bool            `json:"has_credits"`
		Unlimited bool            `json:"unlimited"`
		Balance   json.RawMessage `json:"balance"`
	} `json:"credits"`
}

const codexFiles = 8
const codexTail = 4 << 20
const codexHead = 1 << 20 // session_meta is the first line; it carries the instructions

// readCodex keeps three things apart. The account's windows are merged across recent rollouts,
// newest observation per limit id and window, because every thread (background reviews
// included) reports the same account meters. The model and effort come from one thread: the
// one named by thread (CODEX_THREAD_ID or a hook's session id) when its log is found, else the
// most recent interactive thread, marked as such. Background threads never supply them.
func readCodex(home, thread string) ([]Account, SourceStatus) {
	st := SourceStatus{Source: "codex"}
	if home == "" {
		st.Status, st.Reason = "missing", "not read"
		return nil, st
	}
	root := filepath.Join(home, "sessions")
	files := newestRollouts(root, codexFiles)
	own := ""
	if thread = clip(thread); thread != "" {
		own = findThread(root, thread)
		if own != "" && !contains(files, own) {
			files = append([]string{own}, files...)
		}
	}
	if len(files) == 0 {
		st.Status, st.Reason = "missing", "no Codex session logs found"
		return nil, st
	}
	var rs []*rollout
	for _, f := range files {
		if r := scanRollout(f); r != nil {
			rs = append(rs, r)
		}
	}
	a := mergeCodex(rs)
	if a == nil {
		st.Status, st.Reason = "empty", "recent Codex sessions carry no rate-limit snapshot (API key login or no turn yet)"
		return nil, st
	}
	a.Harness, a.Pool = codexHarness(rs, own)
	st.Status = "ok"
	return []Account{*a}, st
}

func contains(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}

// findThread looks for rollout-*-<thread>.jsonl in the most recent day directories.
func findThread(root, thread string) string {
	suffix, days := "-"+thread+".jsonl", 0
	for _, y := range dirsDesc(root) {
		for _, m := range dirsDesc(y) {
			for _, d := range dirsDesc(m) {
				if days++; days > 62 {
					return ""
				}
				es, _ := os.ReadDir(d)
				for _, e := range es {
					if e.Type().IsRegular() && rolloutName.MatchString(e.Name()) && strings.HasSuffix(e.Name(), suffix) {
						return filepath.Join(d, e.Name())
					}
				}
			}
		}
	}
	return ""
}

func background(origin, model string) bool {
	return strings.HasPrefix(origin, "subagent") || strings.HasPrefix(origin, "internal") || model == "codex-auto-review"
}

// mergeCodex: plan and observedAt from the newest snapshot; windows from every rollout of the
// same plan, newest per limit/kind/length, each keeping its own observedAt.
func mergeCodex(rs []*rollout) *Account {
	var newest *rollout
	for _, r := range rs {
		if !r.observed.IsZero() && (newest == nil || r.observed.After(newest.observed)) {
			newest = r
		}
	}
	if newest == nil {
		return nil
	}
	a := &Account{Source: "codex", Plan: newest.plan, ObservedAt: newest.observed, Windows: []Window{}, Credits: newest.credits}
	pos := map[string]int{}
	for _, r := range append([]*rollout{newest}, rs...) {
		if r.observed.IsZero() || (r.plan != "" && newest.plan != "" && r.plan != newest.plan) {
			continue
		}
		for _, k := range r.order {
			w := r.windows[k]
			if i, ok := pos[k]; ok {
				if w.ObservedAt.After(a.Windows[i].ObservedAt) {
					a.Windows[i] = withHistory(w, a.Windows[i])
				} else if r != newest {
					a.Windows[i] = withHistory(a.Windows[i], w) // another thread's readings of the same meter
				}
				continue
			}
			pos[k] = len(a.Windows)
			a.Windows = append(a.Windows, w)
		}
	}
	return a
}

// codexHarness also returns the pool of the thread it picked: the allowance that thread last drew from.
func codexHarness(rs []*rollout, own string) (*Harness, string) {
	var pick *rollout
	for _, r := range rs {
		if r.harness == nil {
			continue
		}
		if r.path == own {
			pick = r
			break
		}
		if background(r.origin, r.harness.Model) {
			continue
		}
		if pick == nil || r.harness.ObservedAt.After(*pick.harness.ObservedAt) {
			pick = r
		}
	}
	if pick == nil {
		return nil, ""
	}
	h := *pick.harness
	h.Attribution = "recent-thread"
	if pick.path == own {
		h.Attribution = "current-thread"
	}
	h.Origin = pick.origin
	return &h, pick.pool
}

// codexLimit names a Codex allowance: "" for the main one (limit id codex), "reserve" for GPT
// Reserve, else the limit id.
func codexLimit(id, name string) string {
	switch id, name = clip(id), clip(name); {
	case id == "base_model_inference" || name == "gpt-reserve":
		return "reserve"
	case id == "codex":
		return ""
	}
	return id
}

var rolloutName = regexp.MustCompile(`^rollout-.*\.jsonl$`)

// newestRollouts walks sessions/YYYY/MM/DD from the newest day and returns up to n files by mtime.
func newestRollouts(root string, n int) []string {
	type f struct {
		path string
		mod  time.Time
	}
	var out []f
	years := dirsDesc(root)
	for _, y := range years {
		for _, m := range dirsDesc(y) {
			for _, d := range dirsDesc(m) {
				es, _ := os.ReadDir(d)
				for _, e := range es {
					if e.Type().IsRegular() && rolloutName.MatchString(e.Name()) {
						if info, err := e.Info(); err == nil {
							out = append(out, f{filepath.Join(d, e.Name()), info.ModTime()})
						}
					}
				}
				if len(out) >= n*2 {
					goto done
				}
			}
		}
	}
done:
	sort.Slice(out, func(i, j int) bool { return out[i].mod.After(out[j].mod) })
	var paths []string
	for i := 0; i < len(out) && i < n; i++ {
		paths = append(paths, out[i].path)
	}
	return paths
}

func dirsDesc(p string) []string {
	es, _ := os.ReadDir(p)
	var out []string
	for _, e := range es {
		if e.IsDir() {
			out = append(out, filepath.Join(p, e.Name()))
		}
	}
	sort.Sort(sort.Reverse(sort.StringSlice(out)))
	return out
}

type rollout struct {
	path, origin, plan, pool string
	observed                 time.Time
	harness                  *Harness
	credits                  *Credits
	windows                  map[string]Window
	order                    []string
}

// originOf names where a thread came from: cli, vscode, exec, … or subagent:review,
// internal:guardian for threads Codex starts itself.
func originOf(raw json.RawMessage) string {
	var s string
	if json.Unmarshal(raw, &s) == nil {
		return clip(s)
	}
	var o map[string]json.RawMessage
	if json.Unmarshal(raw, &o) != nil || len(o) != 1 {
		return ""
	}
	for k, v := range o {
		var inner string
		if json.Unmarshal(v, &inner) != nil {
			var obj map[string]json.RawMessage
			if json.Unmarshal(v, &obj) == nil {
				for ik := range obj {
					if inner == "" || ik < inner {
						inner = ik
					}
				}
			}
		}
		return clip(k + ":" + inner)
	}
	return ""
}

// scanRollout reads the first line (session_meta) and the file's tail. It keeps the latest
// snapshot per limit id and the latest turn context; it decodes nothing else from the log.
func scanRollout(path string) *rollout {
	fh, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer fh.Close()
	r := &rollout{path: path, windows: map[string]Window{}}
	head := bufio.NewReaderSize(io.LimitReader(fh, codexHead), 64<<10)
	if first, err := head.ReadBytes('\n'); err == nil || err == io.EOF {
		var l rolloutLine
		if json.Unmarshal(first, &l) == nil && l.Type == "session_meta" {
			var meta struct {
				Source json.RawMessage `json:"source"`
			}
			if json.Unmarshal(l.Payload, &meta) == nil && len(meta.Source) > 0 {
				r.origin = originOf(meta.Source)
			}
		}
	}
	fh.Seek(0, io.SeekStart)
	if info, err := fh.Stat(); err == nil && info.Size() > codexTail {
		fh.Seek(info.Size()-codexTail, io.SeekStart)
	}
	sc := bufio.NewScanner(fh)
	sc.Buffer(make([]byte, 64<<10), 16<<20)
	for sc.Scan() {
		line := sc.Bytes()
		if !bytes.Contains(line, []byte(`"rate_limits"`)) && !bytes.Contains(line, []byte(`"turn_context"`)) {
			continue
		}
		var l rolloutLine
		if json.Unmarshal(line, &l) != nil {
			continue
		}
		ts, _ := time.Parse(time.RFC3339Nano, l.Timestamp)
		switch l.Type {
		case "turn_context":
			var tc struct {
				Model       string `json:"model"`
				Effort      string `json:"effort"`
				ServiceTier string `json:"service_tier"`
				Mode        struct {
					Settings struct {
						Effort string `json:"reasoning_effort"`
					} `json:"settings"`
				} `json:"collaboration_mode"`
			}
			if json.Unmarshal(l.Payload, &tc) == nil && !ts.IsZero() {
				h := Harness{Model: clip(tc.Model), Effort: clip(tc.Effort), ServiceTier: clip(tc.ServiceTier)}
				if h.Effort == "" {
					h.Effort = clip(tc.Mode.Settings.Effort)
				}
				t := ts.UTC()
				h.ObservedAt = &t
				if h.Model != "" || h.Effort != "" {
					r.harness = &h
				}
			}
		case "event_msg":
			var ev struct {
				Type       string       `json:"type"`
				RateLimits *codexLimits `json:"rate_limits"`
			}
			if json.Unmarshal(l.Payload, &ev) != nil || ev.Type != "token_count" || ev.RateLimits == nil || ts.IsZero() {
				continue
			}
			rl := ev.RateLimits
			r.observed = ts.UTC()
			r.pool = codexLimit(rl.LimitID, rl.LimitName) // the allowance this thread's latest turn drew from
			if p := clip(rl.PlanType); p != "" {
				r.plan = p
			}
			if c := rl.Credits; c != nil {
				r.credits = creditsFrom(c.Has, c.Unlimited, c.Balance, ts) // the latest turn's say, none included
			}
			for _, cw := range []*codexWindow{rl.Primary, rl.Secondary} {
				if cw == nil {
					continue
				}
				w := Window{UsedPercent: finite(cw.UsedPercent, 0, 1000), ResetMode: "fixed", ObservedAt: ts.UTC(), Limit: r.pool}
				if cw.WindowMinutes != nil && *cw.WindowMinutes > 0 && *cw.WindowMinutes < 1e6 {
					w.WindowMinutes = *cw.WindowMinutes
				}
				w.Kind = kindOf(w.WindowMinutes)
				switch {
				case cw.ResetsAt != nil:
					w.ResetsAt = unixTime(cw.ResetsAt)
				case cw.ResetsIn != nil && *cw.ResetsIn >= 0:
					t := ts.Add(time.Duration(*cw.ResetsIn) * time.Second).UTC()
					w.ResetsAt = &t
				}
				key := w.Limit + "/" + w.Kind + "/" + itoa(w.WindowMinutes)
				if prev, seen := r.windows[key]; !seen {
					r.order = append(r.order, key)
				} else {
					w = withHistory(w, prev)
				}
				r.windows[key] = w
			}
		}
	}
	if r.observed.IsZero() && r.harness == nil {
		return nil
	}
	return r
}

func kindOf(minutes int) string {
	switch {
	case minutes >= 240 && minutes <= 360:
		return "five_hour"
	case minutes >= 9000 && minutes <= 11000:
		return "weekly"
	case minutes >= 40000 && minutes <= 46000:
		return "monthly"
	}
	return "unknown"
}

// ---- User-maintained ~/.config/modelplan/local.json (schema in the Skill reference).

var ident = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9_.:-]{0,95}$`)

func readLocal(path string, now time.Time) ([]Account, SourceStatus) {
	st := SourceStatus{Source: "user"}
	b, status := readBounded(path, 128<<10)
	if status != "" {
		st.Status = status
		return nil, st
	}
	var raw struct {
		SchemaVersion int `json:"schemaVersion"`
		Plans         []struct {
			PlanID     string `json:"planId"`
			Generation string `json:"generation"`
			Region     string `json:"region"`
		} `json:"plans"`
		ResetCards []struct {
			PlanID    string `json:"planId"`
			Kind      string `json:"kind"`
			Count     *int   `json:"count"`
			ExpiresAt string `json:"expiresAt"`
		} `json:"resetCards"`
		Windows []struct {
			PlanID           string   `json:"planId"`
			Kind             string   `json:"kind"`
			RemainingPercent *float64 `json:"remainingPercent"`
			ResetAt          string   `json:"resetAt"`
			ObservedAt       string   `json:"observedAt"`
			ResetMode        string   `json:"resetMode"`
		} `json:"windows"`
	}
	if err := json.Unmarshal(b, &raw); err != nil {
		st.Status = "invalid"
		return nil, st
	}
	if raw.SchemaVersion != 1 {
		st.Status = "unsupported_schema"
		return nil, st
	}
	if len(raw.Plans) > 100 || len(raw.ResetCards) > 100 || len(raw.Windows) > 100 {
		st.Status = "invalid"
		return nil, st
	}
	by := map[string]*Account{}
	var order []string
	acct := func(id string) *Account {
		if by[id] == nil {
			by[id] = &Account{Source: "user", Plan: id, Windows: []Window{}}
			order = append(order, id)
		}
		return by[id]
	}
	for _, p := range raw.Plans {
		if !ident.MatchString(p.PlanID) || (p.Generation != "" && !ident.MatchString(p.Generation)) {
			st.Status = "invalid"
			return nil, st
		}
		acct(p.PlanID).Generation = p.Generation
		acct(p.PlanID).Region = clip(p.Region)
	}
	for _, c := range raw.ResetCards {
		if !ident.MatchString(c.PlanID) {
			st.Status = "invalid"
			return nil, st
		}
		card := Card{Kind: oneOf(c.Kind, "five_hour", "weekly"), ExpiresAt: stamp(c.ExpiresAt)}
		if c.Count != nil && *c.Count >= 0 && *c.Count <= 100000 {
			card.Count = c.Count
		}
		a := acct(c.PlanID)
		a.Cards = append(a.Cards, card)
	}
	for _, w := range raw.Windows {
		if !ident.MatchString(w.PlanID) {
			st.Status = "invalid"
			return nil, st
		}
		x := Window{Kind: oneOf(w.Kind, "five_hour", "weekly", "monthly"), ResetsAt: stamp(w.ResetAt), ResetMode: oneOf(w.ResetMode, "fixed", "rolling")}
		if r := finite(w.RemainingPercent, 0, 100); r != nil {
			u := 100 - *r
			x.UsedPercent = &u
		}
		if o := stamp(w.ObservedAt); o != nil && !o.After(now) {
			x.ObservedAt = *o
		} else {
			x.UsedPercent = nil // a future or missing observation time cannot be trusted
		}
		a := acct(w.PlanID)
		a.Windows = append(a.Windows, x)
		if x.ObservedAt.After(a.ObservedAt) {
			a.ObservedAt = x.ObservedAt
		}
	}
	var out []Account
	for _, id := range order {
		out = append(out, *by[id])
	}
	st.Status = "ok"
	return out, st
}

// readBounded refuses symlinks, non-regular and oversized files; "" means ok.
func readBounded(path string, limit int64) ([]byte, string) {
	info, err := os.Lstat(path)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		return nil, "missing"
	case errors.Is(err, fs.ErrPermission):
		return nil, "unreadable"
	case err != nil:
		return nil, "unreadable"
	case !info.Mode().IsRegular():
		return nil, "unsafe_path"
	case info.Size() > limit:
		return nil, "too_large"
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, "unreadable"
	}
	return b, ""
}

func stamp(s string) *time.Time {
	if s == "" || len(s) > 40 {
		return nil
	}
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return nil
	}
	t = t.UTC()
	return &t
}

func oneOf(v string, allowed ...string) string {
	for _, a := range allowed {
		if v == a {
			return v
		}
	}
	return "unknown"
}

var endpointRe = regexp.MustCompile(`^https?://[a-z0-9.-]+(:[0-9]{1,5})?(/[A-Za-z0-9._~%/-]*)?$`)

// clipEndpoint keeps an already reduced base URL (scheme, host, path) and nothing else.
func clipEndpoint(s string) string {
	if len(s) > 200 || !endpointRe.MatchString(s) {
		return ""
	}
	return s
}

// harnessIdent: a model id, effort or version as a harness reports it; Claude Code marks the
// 1M-context variants with a suffix ("glm-5.3[1m]", "claude-opus-4-6[1m]").
var harnessIdent = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9_.:-]{0,95}(\[[a-z0-9]{1,8}\])?$`)

// clip keeps harness-reported identifiers short and printable; they are data, not instructions.
func clip(s string) string {
	s = strings.TrimSpace(s)
	if len(s) > 80 || !harnessIdent.MatchString(s) {
		return ""
	}
	return s
}

func itoa(n int) string { b, _ := json.Marshal(n); return string(b) }

func writeAtomic(path string, b []byte) error {
	f, err := os.CreateTemp(filepath.Dir(path), ".tmp-*")
	if err != nil {
		return err
	}
	tmp := f.Name()
	_, err = f.Write(b)
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		err = os.Rename(tmp, path)
	}
	if err != nil {
		os.Remove(tmp)
	}
	return err
}

// DeclarePlan records in local.json which plan the user has (and its metering generation), or
// removes it, keeping everything else in the file as it is. The user asked for it; nothing
// else writes this file.
func DeclarePlan(path, planID, generation string, remove bool, regions ...string) error {
	region := ""
	if len(regions) > 0 {
		region = regions[0]
	}
	if region != "" && !ident.MatchString(region) {
		return errors.New("region must be a published region id")
	}
	if !ident.MatchString(planID) || (generation != "" && !ident.MatchString(generation)) {
		return errors.New("plan and generation are ids like zhipu-global-pro and legacy-v2")
	}
	doc := map[string]any{"schemaVersion": 1}
	b, status := readBounded(path, 128<<10)
	switch status {
	case "":
		d := json.NewDecoder(bytes.NewReader(b))
		d.UseNumber()
		if err := d.Decode(&doc); err != nil {
			return fmt.Errorf("%s is not valid JSON; fix or move it first", path)
		}
		if v, _ := doc["schemaVersion"].(json.Number); v.String() != "1" {
			return fmt.Errorf("%s has an unsupported schemaVersion", path)
		}
	case "missing":
	default:
		return fmt.Errorf("%s: %s", path, status)
	}
	var plans []any
	if raw, ok := doc["plans"]; ok {
		if plans, ok = raw.([]any); !ok {
			return fmt.Errorf("%s: plans is not a list", path)
		}
	}
	var out []any
	found := false
	for _, x := range plans {
		p, ok := x.(map[string]any)
		if !ok || p["planId"] != planID {
			out = append(out, x)
			continue
		}
		found = true
		if remove {
			continue
		}
		if generation != "" {
			p["generation"] = generation
		} else {
			delete(p, "generation")
		}
		if region != "" {
			p["region"] = region
		}
		out = append(out, p)
	}
	if !found && !remove {
		p := map[string]any{"planId": planID}
		if generation != "" {
			p["generation"] = generation
		}
		if region != "" {
			p["region"] = region
		}
		out = append(out, p)
	}
	if out == nil {
		out = []any{}
	}
	doc["plans"] = out
	nb, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	return writeAtomic(path, append(nb, '\n'))
}

// RecentRollouts: the newest n Codex session logs under codexHome, newest first.
func RecentRollouts(codexHome string, n int) []string {
	return newestRollouts(filepath.Join(codexHome, "sessions"), n)
}

// ThreadOrigin: where the thread of a rollout came from (cli, vscode, exec, subagent:review, …),
// from its first line; "" when unknown.
func ThreadOrigin(path string) string {
	fh, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer fh.Close()
	first, _ := bufio.NewReaderSize(io.LimitReader(fh, codexHead), 64<<10).ReadBytes('\n')
	var l rolloutLine
	var meta struct {
		Source json.RawMessage `json:"source"`
	}
	if json.Unmarshal(first, &l) != nil || l.Type != "session_meta" || json.Unmarshal(l.Payload, &meta) != nil || len(meta.Source) == 0 {
		return ""
	}
	return originOf(meta.Source)
}

// Background: a thread Codex runs by itself (subagent reviews, internal guardians, auto review),
// not the user's own work.
func Background(origin, model string) bool { return background(origin, model) }

// DeclaredPlans reads only the bounded local plan declarations; no account reader is started.
func DeclaredPlans(path string, now time.Time) []Account { a, _ := readLocal(path, now); return a }
