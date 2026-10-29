package quota

import (
	"context"
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// OpenCode Go: GET https://opencode.ai/zen/go/v1/usage with the OpenCode API key as a bearer token.
// Ported from CodexBar's OpenCode Go provider (OpenCodeGoUsageFetcher.fetchAPIUsage/parseAPIUsage
// and OpenCodeWebParsing at 8de11ff, MIT): the rolling five-hour window is required, weekly and
// monthly are optional, percentages are already 0–100, and a reset is given in seconds or as a
// time. The console and browser-session paths and the local cost estimate are not ported.

var opencodegoHosts = map[string]string{"global": "https://opencode.ai"}

var opencodegoReader = &nativeReader{Regions: []string{"global"}, KeyEnv: "OPENCODE_API_KEY", Fetch: fetchOpenCodeGo}

func fetchOpenCodeGo(ctx context.Context, c *http.Client, region, key string, now time.Time) codexbarEntry {
	c = accountReadClient(consent.ScopeOpenCodeGoAccountUsageAPIKey, c)
	e := codexbarEntry{Status: "error", ObservedAt: now.UTC()}
	host := opencodegoHosts[region]
	if host == "" {
		e.Error = "unknown region"
		return e
	}
	if key = strings.TrimSpace(key); key == "" {
		e.Error = "no API key in the environment"
		return e
	}
	var r map[string]any
	if err := getJSON(ctx, c, host+"/zen/go/v1/usage", key, &r); err != nil {
		e.Error = err.Error()
		e.ErrorCode = errorCode(err)
		return e
	}
	return parseOpenCodeGo(r, now)
}

var (
	ocPercentKeys = []string{"usagePercent", "usedPercent", "percentUsed", "percent", "usage_percent", "used_percent", "utilization", "utilizationPercent", "utilization_percent", "usage"}
	ocResetInKeys = []string{"resetInSec", "resetInSeconds", "resetSeconds", "reset_sec", "reset_in_sec", "resetsInSec", "resetsInSeconds", "resetIn", "resetSec"}
	ocResetAtKeys = []string{"resetAt", "resetsAt", "reset_at", "resets_at", "nextReset", "next_reset", "renewAt", "renew_at"}
	ocUsedKeys    = []string{"used", "usage", "consumed", "count", "usedTokens", "usedMicroCents"}
	ocLimitKeys   = []string{"limit", "total", "quota", "max", "cap", "tokenLimit", "limitMicroCents"}
)

func parseOpenCodeGo(r map[string]any, now time.Time) codexbarEntry {
	e := codexbarEntry{ErrorCode: "schema_changed", Status: "error", ObservedAt: now.UTC()}
	usage, _ := r["usage"].(map[string]any)
	rolling, _ := usage["rolling"].(map[string]any)
	if rolling == nil {
		e.Error = "missing usage fields"
		return e
	}
	for _, x := range []struct {
		raw     any
		minutes int
		need    bool
	}{{rolling, 300, true}, {usage["weekly"], 10080, true}, {usage["monthly"], 43200, false}} {
		m, ok := x.raw.(map[string]any)
		if !ok {
			continue
		}
		w, ok := ocWindow(m, x.minutes, now)
		if !ok {
			if x.need {
				e.Windows = nil
				e.Error = "missing usage fields"
				return e
			}
			continue
		}
		e.Windows = append(e.Windows, w)
	}
	e.Status = "ok"
	e.ErrorCode = ""
	return e
}

func ocWindow(m map[string]any, minutes int, now time.Time) (Window, bool) {
	pct, ok := ocNumber(m, ocPercentKeys)
	if !ok {
		used, ok1 := ocNumber(m, ocUsedKeys)
		limit, ok2 := ocNumber(m, ocLimitKeys)
		if !ok1 || !ok2 || limit <= 0 {
			return Window{}, false
		}
		pct = used / limit * 100
	}
	pct = math.Max(0, math.Min(100, pct))
	w := Window{Kind: kindOf(minutes), WindowMinutes: minutes, UsedPercent: &pct, ResetMode: "fixed", ObservedAt: now.UTC()}
	if s, ok := ocNumber(m, ocResetInKeys); ok && s >= 0 && s < 1e9 {
		t := now.Add(time.Duration(s) * time.Second).UTC()
		w.ResetsAt = &t
	} else {
		for _, k := range ocResetAtKeys {
			if t := ocTime(m[k]); t != nil {
				w.ResetsAt = t
				break
			}
		}
	}
	return w, true
}

// ocNumber: the first key holding a finite number or a numeric string.
func ocNumber(m map[string]any, keys []string) (float64, bool) {
	for _, k := range keys {
		switch v := m[k].(type) {
		case float64:
			if !math.IsNaN(v) && !math.IsInf(v, 0) {
				return v, true
			}
		case string:
			if f, err := strconv.ParseFloat(strings.TrimSpace(v), 64); err == nil && !math.IsNaN(f) && !math.IsInf(f, 0) {
				return f, true
			}
		case json.Number:
			if f, err := v.Float64(); err == nil {
				return f, true
			}
		}
	}
	return 0, false
}

// ocTime: unix seconds or milliseconds (as a number or a numeric string), or an RFC 3339 time.
func ocTime(v any) *time.Time {
	var n float64
	switch x := v.(type) {
	case float64:
		n = x
	case string:
		s := strings.TrimSpace(x)
		if f, err := strconv.ParseFloat(s, 64); err == nil {
			n = f
		} else if t := stamp(s); t != nil {
			u := t.UTC()
			return &u
		}
	}
	var t time.Time
	switch {
	case n > 1e12:
		t = time.UnixMilli(int64(n))
	case n > 1e9:
		t = time.Unix(int64(n), 0)
	default:
		return nil
	}
	t = t.UTC()
	return &t
}
