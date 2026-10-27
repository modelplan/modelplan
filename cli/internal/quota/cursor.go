package quota

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

// Independently written compatibility reader. Schema references: CodexBar
// ee890b5 (MIT), Token Monitor e1c393c (MIT); see docs/cursor-native-quota.md.
// Credentials exist only in memory. No refresh, credential copy or browser access.
var cursorReader = &nativeReader{Name: "Cursor", Regions: []string{"global"}, Profiles: cursorProfiles, Managed: collectCursorAccount}
var cursorHost = "https://cursor.com"
var cursorRPCHost = "https://api2.cursor.sh"

const CursorEndpointNotice = "Undocumented Cursor personal dashboard compatibility endpoints; no public personal-quota API contract. Credentials are read-only, never refreshed, copied, printed or stored."

func CursorReadPath(home string) string {
	root := filepath.Join(home, ".config")
	switch runtime.GOOS {
	case "darwin":
		root = filepath.Join(home, "Library", "Application Support")
	case "windows":
		root = os.Getenv("APPDATA")
		if !filepath.IsAbs(root) {
			root = filepath.Join(home, "AppData", "Roaming")
		}
	default:
		if x := os.Getenv("XDG_CONFIG_HOME"); filepath.IsAbs(x) {
			root = x
		}
	}
	return filepath.Join(root, "Cursor", "User", "globalStorage", "state.vscdb")
}

// Only metadata is inspected on the reporting path. A changed or vanished store
// invalidates old-account quota without opening the credential again.
func cursorState() string {
	home, _ := os.UserHomeDir()
	return cursorStateAt(CursorReadPath(home))
}

func cursorStateAt(path string) string {
	h := sha256.New()
	for _, suffix := range []string{"", "-wal", "-shm"} {
		fi, err := os.Stat(path + suffix)
		if err != nil {
			if suffix == "" || !os.IsNotExist(err) {
				return ""
			}
			fmt.Fprint(h, "missing;")
		} else {
			if !fi.Mode().IsRegular() {
				return ""
			}
			fmt.Fprintf(h, "%s:%d:%d;", suffix, fi.Size(), fi.ModTime().UnixNano())
		}
	}
	return hex.EncodeToString(h.Sum(nil))
}

var cursorID = regexp.MustCompile(`^[A-Za-z0-9._-]{1,200}$`)
var cursorJWTPart = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)

type cursorSession struct{ token, user string }

func readCursorSession(ctx context.Context, now time.Time) (cursorSession, error) {
	home, _ := os.UserHomeDir()
	return readCursorSessionAt(ctx, CursorReadPath(home), now)
}

func readCursorSessionAt(ctx context.Context, path string, now time.Time) (cursorSession, error) {
	fail := func() (cursorSession, error) {
		return cursorSession{}, errors.New("Cursor local sign-in unavailable or unsupported; sign in through Cursor, or select --backend codexbar")
	}
	if fi, err := os.Lstat(path); err != nil || !fi.Mode().IsRegular() {
		return fail()
	}
	// Never create WAL sidecars. Immutable mode is safe only without live WAL.
	wal, shm := false, false
	for i, suffix := range []string{"-wal", "-shm"} {
		_, err := os.Stat(path + suffix)
		if err != nil && !os.IsNotExist(err) {
			return fail()
		}
		if i == 0 {
			wal = err == nil
		} else {
			shm = err == nil
		}
	}
	if wal != shm {
		return fail()
	}
	query := "mode=ro&_pragma=query_only(1)&_pragma=busy_timeout(250)"
	if !wal {
		query += "&immutable=1"
	}
	u := url.URL{Scheme: "file", Path: filepath.ToSlash(path), RawQuery: query}
	db, err := sql.Open("sqlite", u.String())
	if err != nil {
		return fail()
	}
	defer db.Close()
	db.SetMaxOpenConns(1)
	var b []byte
	// The SQL bounds credential allocation and reads no other ItemTable values.
	err = db.QueryRowContext(ctx, `SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken' AND length(value) BETWEEN 1 AND 16384 LIMIT 1`).Scan(&b)
	if err != nil {
		return fail()
	}
	// Cursor has used ASCII UTF-16LE BLOBs as well as UTF-8 TEXT.
	if len(b)%2 == 0 && len(b) > 0 {
		le := true
		for i := 0; i < len(b); i += 2 {
			if b[i] == 0 || b[i] >= 128 || b[i+1] != 0 {
				le = false
				break
			}
		}
		if le {
			out := make([]byte, len(b)/2)
			for i := range out {
				out[i] = b[i*2]
			}
			b = out
		}
	}
	token := string(b)
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return fail()
	}
	for _, part := range parts {
		if !cursorJWTPart.MatchString(part) {
			return fail()
		}
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return fail()
	}
	var claims struct {
		Sub string `json:"sub"`
		Exp int64  `json:"exp"`
	}
	if json.Unmarshal(payload, &claims) != nil {
		return fail()
	}
	if claims.Exp <= now.Add(time.Minute).Unix() {
		return cursorSession{}, errors.New("expired")
	}
	sub := strings.Split(claims.Sub, "|")
	user := sub[len(sub)-1]
	if !cursorID.MatchString(user) {
		return fail()
	}
	return cursorSession{token: token, user: user}, nil
}

func cursorJSON(ctx context.Context, c *http.Client, method, endpoint string, s cursorSession, bearer bool, out any) error {
	var body io.Reader
	if method == "POST" {
		body = strings.NewReader("{}")
	}
	req, err := http.NewRequestWithContext(ctx, method, endpoint, body)
	if err != nil {
		return errors.New("Cursor request failed")
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "modelplan")
	if bearer {
		req.Header.Set("Authorization", "Bearer "+s.token)
		req.Header.Set("Connect-Protocol-Version", "1")
	} else {
		req.Header.Set("Cookie", "WorkosCursorSessionToken="+s.user+"%3A%3A"+s.token)
		req.Header.Set("Origin", cursorHost)
	}
	client := *c
	client.Jar = nil
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	resp, err := client.Do(req)
	if err != nil {
		return errors.New("Cursor request failed or timed out")
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return cursorResponseError{code: resp.StatusCode, retry: resp.Header.Get("Retry-After")}
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, nativeMaxBody+1))
	if err != nil || len(b) > nativeMaxBody {
		return errors.New("Cursor response too large or cut off")
	}
	if json.Unmarshal(b, out) != nil {
		return errors.New("unsupported Cursor response")
	}
	return nil
}

func parseCursor(summary, plan, usage, requests []byte, now time.Time) codexbarEntry {
	e := codexbarEntry{Status: "error", Error: "unsupported Cursor quota format", ObservedAt: now.UTC()}
	var s struct {
		Membership string `json:"membershipType"`
		End        string `json:"billingCycleEnd"`
		Individual struct {
			Plan     map[string]json.RawMessage `json:"plan"`
			OnDemand map[string]json.RawMessage `json:"onDemand"`
		} `json:"individualUsage"`
	}
	if json.Unmarshal(summary, &s) != nil {
		return e
	}
	var p struct {
		Merged *bool `json:"isMerged"`
		Info   struct {
			Name   string          `json:"planName"`
			Period string          `json:"includedUsagePeriod"`
			Reset  json.RawMessage `json:"includedUsageResetsAt"`
			End    json.RawMessage `json:"billingCycleEnd"`
		} `json:"planInfo"`
	}
	if json.Unmarshal(plan, &p) != nil {
		p.Merged = nil
	} else {
		p.Merged = cursorMerged(plan)
	}
	// Plan names are deliberately from a fixed set, not arbitrary account text.
	for _, name := range []string{p.Info.Name, s.Membership} {
		switch strings.ToLower(name) {
		case "hobby", "pro", "pro+", "pro-plus", "ultra", "business", "teams", "plus", "premium", "super", "free":
			e.Plan = "Cursor " + strings.ToLower(name)
		}
		if e.Plan != "" {
			break
		}
	}
	reset := stamp(s.End)
	if reset == nil {
		reset = cursorEpoch(p.Info.End)
	}
	add := func(w Window) {
		if w.ResetsAt != nil && !w.ResetsAt.After(now) {
			w.UsedPercent, w.UsedUSD, w.LimitUSD, w.Requests = nil, nil, nil, nil
		}
		e.Windows = append(e.Windows, w)
	}
	base := func(kind, name string, minutes int, at *time.Time) Window {
		return Window{Kind: kind, Limit: name, WindowMinutes: minutes, ResetsAt: at, ResetMode: "fixed", ObservedAt: now.UTC()}
	}
	percent := func(v map[string]json.RawMessage, k string) *float64 {
		n := kimiNumber(v[k], false)
		if n == nil || *n > 100 {
			return nil
		}
		return n
	}
	if p.Merged != nil && *p.Merged {
		// A unified weekly pool must never fall back to stale monthly summary zeroes.
		var u struct {
			Enabled *bool                      `json:"enabled"`
			Plan    map[string]json.RawMessage `json:"planUsage"`
		}
		if json.Unmarshal(usage, &u) != nil {
			u.Plan = nil
		}
		minutes := map[string]int{"INCLUDED_USAGE_PERIOD_WEEKLY": 10080, "INCLUDED_USAGE_PERIOD_MONTHLY": 43200}[p.Info.Period]
		if minutes > 0 {
			w := base(kindOf(minutes), "Included", minutes, cursorEpoch(p.Info.Reset))
			if u.Enabled == nil || *u.Enabled {
				w.UsedPercent = percent(u.Plan, "totalPercentUsed")
			}
			add(w)
		}
	} else if p.Merged != nil {
		v := s.Individual.Plan
		if v != nil {
			w := base("monthly", "Included", 43200, reset)
			w.UsedPercent = percent(v, "totalPercentUsed")
			w.UsedUSD, w.LimitUSD = cursorUSD(v["used"]), cursorUSD(v["limit"])
			if w.UsedPercent == nil && w.UsedUSD != nil && w.LimitUSD != nil && *w.LimitUSD > 0 {
				n := min(100, *w.UsedUSD / *w.LimitUSD * 100)
				w.UsedPercent = &n
			}
			add(w)
			for _, lane := range []struct{ key, name string }{{"autoPercentUsed", "Cursor Models"}, {"apiPercentUsed", "Other Models"}} {
				if n := percent(v, lane.key); n != nil {
					w := base("monthly", lane.name, 43200, reset)
					w.UsedPercent = n
					add(w)
				}
			}
		}
		var r map[string]map[string]json.RawMessage
		if json.Unmarshal(requests, &r) != nil {
			r = nil
		}
		if v := r["gpt-4"]; v != nil {
			used, limit := kimiNumber(v["numRequestsTotal"], true), kimiNumber(v["maxRequestUsage"], true)
			if used == nil {
				used = kimiNumber(v["numRequests"], true)
			}
			if used != nil || limit != nil {
				w := base("monthly", "Included requests", 43200, reset)
				w.Requests = &RequestUsage{}
				if used != nil {
					n := int64(*used)
					w.Requests.Used = &n
				}
				if limit != nil {
					n := int64(*limit)
					w.Requests.Limit = &n
				}
				if used != nil && limit != nil && *limit > 0 {
					n := min(100, *used / *limit * 100)
					w.UsedPercent = &n
				}
				add(w)
			}
		}
	}
	if v := s.Individual.OnDemand; v != nil {
		w := base("spend", "Usage-based spend", 43200, reset)
		w.UsedUSD, w.LimitUSD = cursorUSD(v["used"]), cursorUSD(v["limit"])
		if w.UsedUSD != nil && w.LimitUSD != nil && *w.LimitUSD > 0 {
			n := min(100, *w.UsedUSD / *w.LimitUSD * 100)
			w.UsedPercent = &n
		}
		add(w)
	}
	if len(e.Windows) > 0 {
		e.Status, e.Error = "ok", ""
	}
	return e
}
func cursorEpoch(b json.RawMessage) *time.Time {
	n := kimiNumber(b, true)
	if n == nil || *n < 1e12 || *n > 4e12 {
		return nil
	}
	at := time.UnixMilli(int64(*n)).UTC()
	return &at
}
func cursorUSD(b json.RawMessage) *float64 {
	n := kimiNumber(b, false)
	if n == nil {
		return nil
	}
	v := *n / 100
	return &v
}

// Dashboard RPC JSON can omit proto3 false values. An explicit period supplies
// the classification; an absent/unrecognized plan never defaults to monthly.
func cursorMerged(raw []byte) *bool {
	var p struct {
		Merged *bool `json:"isMerged"`
		Info   struct {
			Period string `json:"includedUsagePeriod"`
		} `json:"planInfo"`
	}
	if json.Unmarshal(raw, &p) != nil {
		return nil
	}
	if p.Merged != nil {
		if !*p.Merged && p.Info.Period == "INCLUDED_USAGE_PERIOD_WEEKLY" {
			return nil
		}
		return p.Merged
	}
	switch p.Info.Period {
	case "INCLUDED_USAGE_PERIOD_WEEKLY":
		v := true
		return &v
	case "INCLUDED_USAGE_PERIOD_MONTHLY":
		v := false
		return &v
	}
	return nil
}

func cursorProfiles() []ReaderProfile {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil
	}
	return []ReaderProfile{{Root: filepath.Dir(CursorReadPath(home))}}
}

type cursorResponseError struct {
	code  int
	retry string
}

func (e cursorResponseError) Error() string { return "Cursor HTTP " + strconv.Itoa(e.code) }

func cursorAccountFailure(err error, now time.Time) readerOutcome {
	out := readerOutcome{Entry: readerEntry{Status: "unavailable", Notice: "Cursor usage temporarily unavailable"}}
	var response cursorResponseError
	if errors.As(err, &response) {
		switch response.code {
		case 401:
			out.Entry.Status = "expired"
			out.Entry.NextStep = "Open Cursor to refresh"
		case 403:
			out.Entry.Status = "denied"
			out.Entry.NextStep = "Open Cursor to refresh"
		case 404:
			out.Entry.Status = "unsupported_schema"
			out.Entry.Notice = "This Cursor usage format is not supported yet"
		case 429:
			out.Entry.Status = "rate-limited"
		}
		if seconds, err := strconv.Atoi(response.retry); err == nil && seconds > 0 && seconds <= 86400 {
			out.RetryAfter = now.Add(time.Duration(seconds) * time.Second)
		} else if at, err := http.ParseTime(response.retry); err == nil && at.After(now) {
			out.RetryAfter = at
		}
	} else if err.Error() == "unsupported Cursor response" {
		out.Entry.Status = "unsupported_schema"
		out.Entry.Notice = "This Cursor usage format is not supported yet"
	}
	return out
}

// At most plan + period usage, never the former summary/plan/legacy waterfall.
// No credentials or local-store stats are read by the JSON/cache projection.
func collectCursorAccount(ctx context.Context, c *http.Client, r readerContext) readerOutcome {
	path := filepath.Join(r.Profile.Root, "state.vscdb")
	stamp := cursorStateAt(path)
	session, err := readCursorSessionAt(ctx, path, r.Now)
	if err != nil {
		out := readerOutcome{Entry: readerEntry{Status: "unavailable", Notice: "This Cursor saved-login type is not supported yet", NextStep: "Open Cursor to refresh"}}
		if err.Error() == "expired" {
			out.Entry.Status = "expired"
		}
		return out
	}
	credentialKey := readerHash(r.Paths.Cache, "cursor:credential", session.token)
	accountKey := readerHash(r.Paths.Cache, "cursor:account", session.user)
	if credentialKey == "" || accountKey == "" {
		return readerOutcome{Entry: readerEntry{Status: "unavailable", Notice: "Identity key unavailable"}}
	}
	meta := r.Previous.Metadata
	changed := (meta.CredentialKey != "" && meta.CredentialKey != credentialKey) || (meta.AccountKey != "" && meta.AccountKey != accountKey)
	cold := meta.CredentialKey != credentialKey || meta.AccountKey != accountKey || meta.PlanDetails == nil || meta.VerifiedAt.After(r.Now) || r.Now.Sub(meta.VerifiedAt) >= 24*time.Hour
	if meta.PlanDetails != nil && meta.PlanDetails.ResetAt != nil && !meta.PlanDetails.ResetAt.After(r.Now) {
		cold = true
	}
	if cold {
		var raw json.RawMessage
		if err := cursorJSON(ctx, c, "POST", cursorHost+"/api/dashboard/get-plan-info", session, false, &raw); err != nil {
			out := cursorAccountFailure(err, r.Now)
			out.Invalidate = changed
			return out
		}
		plan, details := parseCursorPlan(raw)
		if details == nil {
			return readerOutcome{Entry: readerEntry{Status: "unsupported_schema", Notice: "This Cursor plan format is not supported yet"}, Invalidate: changed}
		}
		meta = readerMetadata{CredentialKey: credentialKey, AccountKey: accountKey, VerifiedAt: r.Now.UTC(), Plan: plan, PlanDetails: details}
	}
	var usage json.RawMessage
	if err := cursorJSON(ctx, c, "POST", cursorRPCHost+"/aiserver.v1.DashboardService/GetCurrentPeriodUsage", session, true, &usage); err != nil {
		out := cursorAccountFailure(err, r.Now)
		out.Invalidate = changed
		return out
	}
	windows, ok := parseCursorPeriod(usage, meta.PlanDetails, r.Now)
	if !ok {
		return readerOutcome{Entry: readerEntry{Status: "unsupported_schema", Notice: "This Cursor period-usage format is not supported yet"}, Invalidate: changed}
	}
	if stamp == "" || cursorStateAt(path) != stamp {
		return readerOutcome{Entry: readerEntry{Status: "unavailable", Notice: "Cursor sign-in changed during the read; refresh required"}, Invalidate: true}
	}
	a := &Account{Source: "native:cursor", Via: "native", Plan: meta.Plan, ObservedAt: r.Now.UTC(), Windows: windows}
	if !IdentityOff() {
		ref := assignSubscription(r.Paths.Cache, "cursor-auth", session.user, r.Now)
		if ref != "" {
			a.Subscription = &Binding{Ref: ref, Status: "verified", Basis: "cursor-auth", ObservedAt: r.Now.UTC()}
		}
	}
	notice := ""
	if meta.PlanDetails.Unified {
		a.SharedPool = unverifiedXSubscription()
		notice = "Shared-pool link unverified"
	}
	return readerOutcome{Entry: readerEntry{Status: "ok", Account: a, Metadata: meta, Notice: notice}}
}

func parseCursorPlan(raw []byte) (string, *readerPlanDetails) {
	var p struct {
		Info struct {
			Name   string          `json:"planName"`
			Period string          `json:"includedUsagePeriod"`
			Reset  json.RawMessage `json:"includedUsageResetsAt"`
			End    json.RawMessage `json:"billingCycleEnd"`
		} `json:"planInfo"`
	}
	if json.Unmarshal(raw, &p) != nil {
		return "", nil
	}
	merged := cursorMerged(raw)
	minutes := map[string]int{"INCLUDED_USAGE_PERIOD_WEEKLY": 10080, "INCLUDED_USAGE_PERIOD_MONTHLY": 43200}[p.Info.Period]
	if merged == nil || minutes == 0 {
		return "", nil
	}
	details := &readerPlanDetails{Minutes: minutes, ResetAt: cursorEpoch(p.Info.Reset), Unified: *merged && minutes == 10080}
	if details.ResetAt == nil {
		details.ResetAt = cursorEpoch(p.Info.End)
	}
	if details.ResetAt == nil {
		var iso string
		if json.Unmarshal(p.Info.Reset, &iso) == nil {
			details.ResetAt = stamp(iso)
		}
	}
	plan := ""
	if details.Unified {
		plan = "The X Subscription"
	} else {
		switch strings.ToLower(p.Info.Name) {
		case "hobby", "pro", "pro+", "pro-plus", "ultra", "business", "teams", "plus", "premium", "super", "free":
			plan = "Cursor " + strings.ToLower(p.Info.Name)
		}
	}
	return plan, details
}

func parseCursorPeriod(raw []byte, details *readerPlanDetails, now time.Time) ([]Window, bool) {
	if details == nil {
		return nil, false
	}
	var usage struct {
		Enabled *bool                      `json:"enabled"`
		Plan    map[string]json.RawMessage `json:"planUsage"`
	}
	if json.Unmarshal(raw, &usage) != nil || (usage.Enabled != nil && !*usage.Enabled) {
		return nil, false
	}
	pct := kimiNumber(usage.Plan["totalPercentUsed"], false)
	if pct == nil || *pct > 100 {
		return nil, false
	}
	if details.ResetAt != nil && !details.ResetAt.After(now) {
		return nil, false
	}
	return []Window{{Kind: kindOf(details.Minutes), Limit: "Included", WindowMinutes: details.Minutes, ResetsAt: details.ResetAt, UsedPercent: pct, ObservedAt: now.UTC(), ResetMode: "fixed"}}, true
}
