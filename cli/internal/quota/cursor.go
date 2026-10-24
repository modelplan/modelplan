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
var cursorReader = &nativeReader{Name: "Cursor", Regions: []string{"global"}, Collect: collectCursor}
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
	path := CursorReadPath(home)
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
	path := CursorReadPath(home)
	fail := func() (cursorSession, error) {
		return cursorSession{}, errors.New("Cursor local sign-in unavailable or unsupported; sign in through Cursor, or select --backend codexbar")
	}
	if fi, err := os.Stat(path); err != nil || !fi.Mode().IsRegular() {
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
	if json.Unmarshal(payload, &claims) != nil || claims.Exp <= now.Add(time.Minute).Unix() {
		return fail()
	}
	sub := strings.Split(claims.Sub, "|")
	user := sub[len(sub)-1]
	if !cursorID.MatchString(user) {
		return fail()
	}
	return cursorSession{token: token, user: user}, nil
}

func collectCursor(ctx context.Context, c *http.Client, cache string, now time.Time) codexbarEntry {
	ctx, cancel := context.WithTimeout(ctx, nativeTimeout)
	defer cancel()
	e := codexbarEntry{Status: "error", ObservedAt: now.UTC(), CursorState: cursorState()}
	session, err := readCursorSession(ctx, now)
	if err != nil {
		e.Error = err.Error()
		return e
	}
	var summary, plan, usage, requests json.RawMessage
	if err = cursorJSON(ctx, c, "GET", cursorHost+"/api/usage-summary", session, false, &summary); err != nil {
		e.Error = err.Error()
		return e
	}
	// Plan classification must succeed before monthly and weekly usage can be mixed.
	_ = cursorJSON(ctx, c, "POST", cursorHost+"/api/dashboard/get-plan-info", session, false, &plan)
	var p struct {
		IsMerged *bool `json:"isMerged"`
	}
	if json.Unmarshal(plan, &p) != nil {
		p.IsMerged = nil
	}
	if p.IsMerged != nil && *p.IsMerged {
		_ = cursorJSON(ctx, c, "POST", cursorRPCHost+"/aiserver.v1.DashboardService/GetCurrentPeriodUsage", session, true, &usage)
	} else if p.IsMerged != nil {
		_ = cursorJSON(ctx, c, "GET", cursorHost+"/api/usage?user="+url.QueryEscape(session.user), session, false, &requests)
	}
	parsed := parseCursor(summary, plan, usage, requests, now)
	parsed.CursorState = e.CursorState
	if e.CursorState == "" || cursorState() != e.CursorState {
		parsed.Status, parsed.Error, parsed.Windows = "error", "Cursor sign-in state changed during refresh; retry required", nil
	}
	if parsed.Status == "ok" && !IdentityOff() {
		parsed.SubscriptionRef = assignSubscription(cache, "cursor-auth", session.user, now)
	}
	return parsed
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
		return errors.New("Cursor HTTP " + strconv.Itoa(resp.StatusCode))
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
