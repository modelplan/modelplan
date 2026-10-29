package quota

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Original implementation; schema evidence from CodexBar ee890b5 and Token
// Monitor e1c393c (MIT), Tokscale 669fdae (MIT). See docs/minimax-quota.md.
var minimaxHosts = map[string]string{"international": "https://api.minimax.io", "china": "https://api.minimaxi.com"}
var minimaxReader = &nativeReader{Name: "MiniMax", Regions: []string{"international", "china"}, KeyEnv: "MINIMAX_CODING_API_KEY", Fetch: fetchMiniMax}

const miniMaxCurrentPath = "/v1/token_plan/remains"
const miniMaxLegacyPath = "/v1/api/openplatform/coding_plan/remains"
const MiniMaxEndpointNotice = "GET /v1/token_plan/remains is documented on www.minimax.io; API subdomains and response schema are compatibility interfaces. Same-host legacy GET /v1/api/openplatform/coding_plan/remains is undocumented. No cross-region retry."

func MiniMaxHost(region string) string {
	if region == "" {
		region = "international"
	}
	return minimaxHosts[region]
}

func fetchMiniMax(ctx context.Context, c *http.Client, region, key string, now time.Time) codexbarEntry {
	e := codexbarEntry{Status: "error", Plan: "MiniMax", ObservedAt: now.UTC()}
	host := minimaxHosts[region]
	if host == "" {
		e.Error = "unknown MiniMax region"
		return e
	}
	if key == "" {
		e.Error = "MiniMax environment key is missing; quota is unknown"
		return e
	}
	c = accountReadClient(consent.ScopeMiniMaxAccountUsageAPIKey, c)
	// Both attempts share one deadline and one region. HTTP 401/403 end the read.
	// Only endpoint compatibility failures may try legacy; no auth refresh or cookie jar.
	ctx, cancel := context.WithTimeout(ctx, nativeTimeout)
	defer cancel()
	for i, path := range []string{miniMaxCurrentPath, miniMaxLegacyPath} {
		b, status, err := miniMaxJSON(ctx, c, host+path, key)
		if err != nil {
			if i == 0 && (status == 404 || status == 405) {
				continue
			}
			e.Error = err.Error()
			e.ErrorCode = errorCode(err)
			return e
		}
		parsed, rejected := parseMiniMax(b, now)
		if i == 0 && rejected {
			continue
		}
		return parsed
	}
	return e
}
func miniMaxJSON(ctx context.Context, c *http.Client, endpoint, key string) ([]byte, int, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, 0, codeError("other", "MiniMax request failed")
	}
	req.Header.Set("Authorization", "Bearer "+key)
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "modelplan")
	client := *c
	client.Jar = nil
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	resp, err := client.Do(req)
	if err != nil {
		return nil, 0, codeError(transportErrorCode(err), "MiniMax request failed or timed out")
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, resp.StatusCode, codeError(httpErrorCode(resp.StatusCode), "MiniMax HTTP "+strconv.Itoa(resp.StatusCode)+"; verify the selected region and plan key")
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, nativeMaxBody+1))
	if err != nil || len(b) > nativeMaxBody {
		return nil, 200, codeError("schema_changed", "MiniMax response too large or cut off")
	}
	return b, 200, nil
}

// The second result allows only a recognized auth rejection to try legacy.
// No arbitrary server strings, identity fields or raw labels reach the cache.
func parseMiniMax(b []byte, now time.Time) (codexbarEntry, bool) {
	e := codexbarEntry{ErrorCode: "schema_changed", Status: "error", Error: "unsupported MiniMax quota format", Plan: "MiniMax", ObservedAt: now.UTC()}
	var top map[string]json.RawMessage
	if err := json.Unmarshal(b, &top); err != nil {
		e.ErrorCode = jsonErrorCode(err)
		return e, false
	}
	if top == nil {
		return e, false
	}
	body := top
	if data, ok := top["data"]; ok {
		if json.Unmarshal(data, &body) != nil || body == nil {
			return e, false
		}
	}
	for _, env := range []map[string]json.RawMessage{top, body} {
		if raw, ok := env["base_resp"]; ok {
			var base map[string]json.RawMessage
			if json.Unmarshal(raw, &base) != nil {
				return e, false
			}
			code := kimiNumber(base["status_code"], true)
			if code == nil {
				return e, false
			}
			if *code != 0 {
				e.Error = "MiniMax rejected the quota request; verify the selected region and plan key"
				return e, *code == 1004
			}
		}
	}
	var rows []map[string]json.RawMessage
	if json.Unmarshal(body["model_remains"], &rows) != nil || len(rows) > 64 {
		return e, false
	}
	// The general pool supersedes per-model aliases for the same shared quota.
	general := -1
	for i, row := range rows {
		var name string
		_ = json.Unmarshal(row["model_name"], &name)
		if name == "general" {
			if general >= 0 {
				return e, false
			}
			general = i
		}
	}
	if general >= 0 {
		rows = rows[general : general+1]
	}
	seen := map[string]bool{}
	for _, row := range rows {
		var name string
		if json.Unmarshal(row["model_name"], &name) != nil {
			continue
		}
		switch strings.ToLower(name) {
		case "general", "minimax-m2", "minimax-m2.1", "minimax-m2.5", "minimax-m2.5-highspeed", "minimax-m2.7", "minimax-m2.7-highspeed", "minimax-m3":
		default:
			continue
		}
		if seen[name] {
			e.Windows = nil
			return e, false
		}
		seen[name] = true
		for _, period := range []struct {
			prefix, start, end string
			minutes            int
		}{{"current_interval_", "start_time", "end_time", 300}, {"current_weekly_", "weekly_start_time", "weekly_end_time", 10080}} {
			status := kimiNumber(row[period.prefix+"status"], true)
			// Explicit inactive/no-entitlement markers never manufacture a full tank.
			if status != nil && *status != 1 && *status != 2 {
				continue
			}
			if raw, ok := row[period.prefix+"status"]; ok && status == nil && string(raw) != "null" {
				continue
			}
			remaining := kimiNumber(row[period.prefix+"remaining_percent"], false)
			used := (*float64)(nil)
			if remaining != nil && *remaining <= 100 {
				n := 100 - *remaining
				used = &n
			}
			// Legacy *_usage_count is REMAINING quota. Percent fields are authoritative;
			// invalid-present percentages do not fall back to zero placeholder counters.
			rawPercent, hasPercent := row[period.prefix+"remaining_percent"]
			if !hasPercent || string(rawPercent) == "null" {
				total := kimiNumber(row[period.prefix+"total_count"], true)
				remain := kimiNumber(row[period.prefix+"remaining_count"], true)
				if remain == nil {
					remain = kimiNumber(row[period.prefix+"usage_count"], true)
				}
				if total != nil && *total > 0 && remain != nil && *remain <= *total {
					n := 100 * (1 - *remain / *total)
					used = &n
				}
			}
			end := miniMaxEpoch(row[period.end])
			start := miniMaxEpoch(row[period.start])
			minutes := period.minutes
			if start != nil && end != nil && end.After(*start) {
				m := int(end.Sub(*start) / time.Minute)
				if m > 0 && m <= 44640 {
					minutes = m
				}
			}
			// Do not add a weekly row merely because model_remains exists.
			if used == nil && end == nil && !hasPercent {
				continue
			}
			w := Window{Kind: kindOf(minutes), WindowMinutes: minutes, Limit: "Coding", UsedPercent: used, ResetsAt: end, ResetMode: "fixed", ObservedAt: now.UTC()}
			if name != "general" {
				w.Limit = name
			}
			if end != nil && !end.After(now) {
				w.UsedPercent = nil
			}
			e.Windows = append(e.Windows, w)
		}
	}
	if len(e.Windows) > 0 {
		e.Status, e.Error = "ok", ""
		e.ErrorCode = ""
	}
	return e, false
}
func miniMaxEpoch(b json.RawMessage) *time.Time {
	n := kimiNumber(b, true)
	if n == nil || *n < 1e9 {
		return nil
	}
	ms := *n
	if ms < 1e12 {
		ms *= 1000
	}
	if ms > 4e12 {
		return nil
	}
	at := time.UnixMilli(int64(ms)).UTC()
	return &at
}
func minimaxCacheMatches(cache string, x Selection, e codexbarEntry) bool {
	if e.Region != x.Region || e.KeyEnv != x.KeyEnv {
		return false
	}
	if e.Status != "ok" {
		return true
	}
	// Without a binding, cached old-key quota cannot safely be reused.
	if IdentityOff() {
		return false
	}
	ref := lookupSubscription(cache, nativeIdentityBasis(x), os.Getenv(x.KeyEnv))
	return ref != "" && ref == e.SubscriptionRef
}
