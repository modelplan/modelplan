package quota

import (
	"context"
	"encoding/json"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// Undocumented compatibility endpoint. Contract evidence: CodexBar (0827f30,
// MIT) KimiModels/UsageFetcher and token-monitor (0c7dd85, MIT) kimi/limits.
// Original implementation; no OAuth, cookies, enrichment, inference or key files.
var kimiHosts = map[string]string{"china": "https://api.kimi.com", "international": "https://api.kimi.ai"}
var kimiReader = &nativeReader{Name: "Kimi Code", Regions: []string{"china", "international"}, KeyEnv: "KIMI_CODE_API_KEY", Fetch: fetchKimi}

const KimiEndpointNotice = "Undocumented compatibility endpoint: GET /coding/v1/usages. Only the selected environment key is read; its value is never printed or stored. No Kimi credentials are refreshed or rewritten."

func KimiHost(region string) string {
	if region == "" {
		region = "china"
	}
	return kimiHosts[region]
}

func fetchKimi(ctx context.Context, c *http.Client, region, key string, now time.Time) codexbarEntry {
	e := codexbarEntry{Status: "error", ObservedAt: now.UTC(), Plan: "Kimi Code"}
	host := kimiHosts[region]
	if host == "" {
		e.Error = "unknown region"
		return e
	}
	if key == "" {
		e.Error = "no API key in the environment; Kimi quota is unknown. The plan-key quota endpoint is undocumented; see docs/kimi-code-quota.md"
		return e
	}
	// A redirect must never send the region's key to another host/path.
	client := *c
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	var raw json.RawMessage
	if err := getJSON(ctx, &client, host+"/coding/v1/usages", key, &raw); err != nil {
		e.Error = err.Error()
		return e
	}
	return parseKimi(raw, now)
}

func parseKimi(b []byte, now time.Time) codexbarEntry {
	e := codexbarEntry{Status: "error", ObservedAt: now.UTC(), Plan: "Kimi Code", Error: "unsupported Kimi quota format"}
	var body map[string]json.RawMessage
	if json.Unmarshal(b, &body) != nil || body == nil || body["error"] != nil {
		return e
	}
	// Some monitors accept the same payload in a data envelope.
	if data := body["data"]; data != nil {
		if json.Unmarshal(data, &body) != nil || body == nil || body["error"] != nil {
			return e
		}
	}
	by := map[int]Window{}
	add := func(minutes int, raw json.RawMessage, ratio bool) {
		var v map[string]json.RawMessage
		if json.Unmarshal(raw, &v) != nil || v == nil {
			return
		}
		w := Window{Kind: kindOf(minutes), WindowMinutes: minutes, ResetMode: "fixed", ObservedAt: now.UTC()}
		for _, k := range []string{"reset_time", "resetTime", "reset_at", "resetAt"} {
			var s string
			if json.Unmarshal(v[k], &s) == nil {
				if at := stamp(s); at != nil {
					w.ResetsAt = at
					break
				}
			}
		}
		if ratio {
			n := kimiNumber(v["used_ratio"], false)
			if n == nil {
				n = kimiNumber(v["usedRatio"], false)
			}
			if n != nil {
				p := math.Min(100, *n*100)
				w.UsedPercent = &p
			}
		} else {
			limit, used, remaining := kimiNumber(v["limit"], true), kimiNumber(v["used"], true), kimiNumber(v["remaining"], true)
			if limit != nil && *limit > 0 {
				if used == nil && remaining != nil && *remaining <= *limit {
					n := *limit - *remaining
					used = &n
				}
				if used != nil {
					p := math.Min(100, *used / *limit * 100)
					w.UsedPercent = &p
				}
			}
		}
		if old, ok := by[minutes]; ok {
			// Do not combine values from different reset periods. A valid ratio pool
			// supersedes a legacy window; matching periods retain the higher use.
			if w.UsedPercent == nil {
				return
			}
			if old.UsedPercent != nil && old.ResetsAt != nil && w.ResetsAt != nil && math.Abs(old.ResetsAt.Sub(*w.ResetsAt).Seconds()) <= 2 && *old.UsedPercent > *w.UsedPercent {
				w.UsedPercent = old.UsedPercent
			}
		}
		by[minutes] = w
	}
	if raw := body["usage"]; raw != nil && string(raw) != "null" {
		add(10080, raw, false)
	}
	var limits []struct {
		Window struct {
			Duration int    `json:"duration"`
			TimeUnit string `json:"timeUnit"`
		} `json:"window"`
		Detail json.RawMessage `json:"detail"`
	}
	if json.Unmarshal(body["limits"], &limits) == nil && len(limits) <= 64 {
		for _, l := range limits {
			unit := map[string]int{"TIME_UNIT_MINUTE": 1, "TIME_UNIT_HOUR": 60, "TIME_UNIT_DAY": 1440}[l.Window.TimeUnit]
			if unit > 0 && l.Window.Duration > 0 && l.Window.Duration <= 46000/unit {
				m := l.Window.Duration * unit
				if _, seen := by[m]; !seen {
					add(m, l.Detail, false)
				}
			}
		}
	}
	var pools map[string]json.RawMessage
	if json.Unmarshal(body["usages"], &pools) == nil {
		for _, p := range []struct {
			key     string
			minutes int
		}{{"limit_5h", 300}, {"limit_7d", 10080}, {"limit_month_total", 43200}} {
			if raw := pools[p.key]; raw != nil && string(raw) != "null" {
				add(p.minutes, raw, true)
			}
		}
	}
	for _, m := range []int{300, 10080, 43200} {
		if w, ok := by[m]; ok {
			// Neither an expired window nor a malformed reset can imply a fresh tank.
			if w.ResetsAt != nil && !w.ResetsAt.After(now) {
				w.UsedPercent = nil
			}
			e.Windows = append(e.Windows, w)
		}
	}
	if len(e.Windows) > 0 {
		e.Status, e.Error = "ok", ""
	}
	return e
}

func kimiNumber(b json.RawMessage, integer bool) *float64 {
	s := strings.TrimSpace(string(b))
	if len(s) > 40 || len(s) == 0 {
		return nil
	}
	if s[0] == '"' {
		if json.Unmarshal(b, &s) != nil {
			return nil
		}
	}
	n, err := strconv.ParseFloat(s, 64)
	if err != nil || math.IsNaN(n) || math.IsInf(n, 0) || n < 0 || n > 1e15 || (integer && math.Trunc(n) != n) {
		return nil
	}
	return &n
}
