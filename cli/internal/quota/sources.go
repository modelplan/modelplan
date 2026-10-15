package quota

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
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

// StatuslineInput is the subset of Claude Code's status-line JSON that Model Plan uses.
// Session ids, paths and costs are deliberately not decoded.
type StatuslineInput struct {
	Model struct {
		ID          string `json:"id"`
		DisplayName string `json:"display_name"`
	} `json:"model"`
	Version string `json:"version"`
	Effort  *struct {
		Level string `json:"level"`
	} `json:"effort"`
	FastMode   *bool `json:"fast_mode"`
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
	SchemaVersion int       `json:"schemaVersion"`
	Source        string    `json:"source"`
	ObservedAt    time.Time `json:"observedAt"`
	Harness       Harness   `json:"harness"`
	Windows       []Window  `json:"windows"`
}

func snapshotPath(cache string) string { return filepath.Join(cache, "observed", "claude-code.json") }

// Account turns status-line input into an unevaluated Claude Code account.
func (in StatuslineInput) Account(now time.Time) Account {
	a := Account{Source: "claude-code", ObservedAt: now.UTC(), Windows: []Window{}}
	h := Harness{Model: clip(in.Model.ID), Version: clip(in.Version), FastMode: in.FastMode}
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
// unchanged snapshot is rewritten at most once a minute.
func RecordClaudeCode(cache string, in StatuslineInput, now time.Time) error {
	a := in.Account(now)
	if a.Harness.Model == "" && len(a.Windows) == 0 {
		return nil
	}
	snap := ccSnapshot{SchemaVersion: 1, Source: "claude-code-statusline", ObservedAt: a.ObservedAt, Harness: *a.Harness, Windows: a.Windows}
	p := snapshotPath(cache)
	if old, err := os.ReadFile(p); err == nil {
		var prev ccSnapshot
		if json.Unmarshal(old, &prev) == nil && now.Sub(prev.ObservedAt) < time.Minute && bytes.Equal(content(prev), content(snap)) {
			return nil
		}
	}
	if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
		return err
	}
	return writeAtomic(p, marshal(snap))
}

// content is the snapshot without its observation times.
func content(s ccSnapshot) []byte {
	s.ObservedAt = time.Time{}
	s.Windows = append([]Window(nil), s.Windows...)
	for i := range s.Windows {
		s.Windows[i].ObservedAt = time.Time{}
	}
	return marshal(s)
}

func readClaudeCode(cache string) ([]Account, SourceStatus) {
	st := SourceStatus{Source: "claude-code"}
	b, status := readBounded(snapshotPath(cache), 64<<10)
	if status != "" {
		st.Status = status
		if status == "missing" {
			st.Reason = "no status-line snapshot yet; install the Model Plan status line in Claude Code"
		}
		return nil, st
	}
	var s ccSnapshot
	if json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 {
		st.Status = "invalid"
		return nil, st
	}
	a := Account{Source: "claude-code", ObservedAt: s.ObservedAt, Harness: &s.Harness, Windows: s.Windows}
	if a.Windows == nil {
		a.Windows = []Window{}
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
	Primary   *codexWindow `json:"primary"`
	Secondary *codexWindow `json:"secondary"`
	PlanType  string       `json:"plan_type"`
}

const codexFiles = 8
const codexTail = 4 << 20

func readCodex(home string) ([]Account, SourceStatus) {
	st := SourceStatus{Source: "codex"}
	files := newestRollouts(filepath.Join(home, "sessions"), codexFiles)
	if len(files) == 0 {
		st.Status, st.Reason = "missing", "no Codex session logs found"
		return nil, st
	}
	for _, f := range files {
		if a := scanRollout(f); a != nil {
			st.Status = "ok"
			return []Account{*a}, st
		}
	}
	st.Status, st.Reason = "empty", "recent Codex sessions carry no rate-limit snapshot (API key login or no turn yet)"
	return nil, st
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

// scanRollout reads the file's tail and keeps the latest snapshot per limit id, plus the
// latest turn context (model, effort). It decodes nothing else from the log.
func scanRollout(path string) *Account {
	fh, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer fh.Close()
	if info, err := fh.Stat(); err == nil && info.Size() > codexTail {
		fh.Seek(info.Size()-codexTail, io.SeekStart)
	}
	sc := bufio.NewScanner(fh)
	sc.Buffer(make([]byte, 64<<10), 16<<20)
	var a *Account
	var h Harness
	limits := map[string]Window{}
	order := []string{}
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
				Model  string `json:"model"`
				Effort string `json:"effort"`
			}
			if json.Unmarshal(l.Payload, &tc) == nil {
				h = Harness{Model: clip(tc.Model), Effort: clip(tc.Effort)}
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
			if a == nil {
				a = &Account{Source: "codex"}
			}
			a.ObservedAt = ts.UTC()
			if p := clip(rl.PlanType); p != "" {
				a.Plan = p
			}
			for _, cw := range []*codexWindow{rl.Primary, rl.Secondary} {
				if cw == nil {
					continue
				}
				w := Window{UsedPercent: finite(cw.UsedPercent, 0, 1000), ResetMode: "fixed", ObservedAt: ts.UTC(), Limit: clip(rl.LimitID)}
				if w.Limit == "codex" {
					w.Limit = ""
				}
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
				if _, seen := limits[key]; !seen {
					order = append(order, key)
				}
				limits[key] = w
			}
		}
	}
	if a == nil {
		return nil
	}
	if h.Model != "" || h.Effort != "" {
		a.Harness = &h
	}
	a.Windows = []Window{}
	for _, k := range order {
		a.Windows = append(a.Windows, limits[k])
	}
	return a
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
			PlanID string `json:"planId"`
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
		if !ident.MatchString(p.PlanID) {
			st.Status = "invalid"
			return nil, st
		}
		acct(p.PlanID)
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

// clip keeps harness-reported identifiers short and printable; they are data, not instructions.
func clip(s string) string {
	s = strings.TrimSpace(s)
	if len(s) > 80 || !ident.MatchString(s) {
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
