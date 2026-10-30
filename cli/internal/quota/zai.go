package quota

import (
	"context"
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"math"
	"net/http"
	"sort"
	"strings"
	"time"
)

// Z.ai / GLM Coding Plan: GET <host>/api/monitor/usage/quota/limit with the API key as a bearer
// token, for a personal plan. Ported from CodexBar's zai provider
// (Sources/CodexBarCore/Resources/Plugins/zai.js at 8de11ff, MIT): the same hosts, limit types,
// unit table and plausibility rule for a five-hour reset. Team scope, the BigModel balance and
// the per-model usage charts are not ported.

var zaiHosts = map[string]string{
	"global":      "https://api.z.ai",
	"bigmodel-cn": "https://open.bigmodel.cn",
}

var zaiReader = &nativeReader{Regions: []string{"global", "bigmodel-cn"}, KeyEnv: "Z_AI_API_KEY", Fetch: fetchZai}

type zaiLimit struct {
	Type          string `json:"type"`
	Unit          *int   `json:"unit"`
	Number        *int   `json:"number"`
	Percentage    *int   `json:"percentage"`
	Usage         *int64 `json:"usage"`
	CurrentValue  *int64 `json:"currentValue"`
	Remaining     *int64 `json:"remaining"`
	NextResetTime *int64 `json:"nextResetTime"`
}

type zaiResponse struct {
	Code    int    `json:"code"`
	Success bool   `json:"success"`
	Msg     string `json:"msg"`
	Data    *struct {
		Limits      []json.RawMessage `json:"limits"`
		PlanName    string            `json:"planName"`
		Plan        string            `json:"plan"`
		PlanType    string            `json:"plan_type"`
		PackageName string            `json:"packageName"`
		Level       string            `json:"level"`
	} `json:"data"`
}

func fetchZai(ctx context.Context, c *http.Client, region, key string, now time.Time) codexbarEntry {
	c = accountReadClient(consent.ScopeZaiAccountUsageAPIKey, c)
	e := codexbarEntry{Status: "error", ObservedAt: now.UTC()}
	host := zaiHosts[region]
	if host == "" {
		e.Error = "unknown region"
		return e
	}
	if key == "" {
		e.Error = "no API key in the environment"
		return e
	}
	var r zaiResponse
	if err := getJSON(ctx, c, host+"/api/monitor/usage/quota/limit", key, &r); err != nil {
		e.Error = err.Error()
		e.ErrorCode = errorCode(err)
		return e
	}
	return parseZai(r, now)
}

// zaiUnit: minutes per unit (1 day, 3 hour, 5 minute, 6 week).
var zaiUnit = map[int]int{1: 1440, 3: 60, 5: 1, 6: 10080}

func parseZai(r zaiResponse, now time.Time) codexbarEntry {
	e := codexbarEntry{ErrorCode: "schema_changed", Status: "error", ObservedAt: now.UTC()}
	if !r.Success || r.Code != 200 {
		e.Error = e.ErrorCode
		return e
	}
	if r.Data == nil || r.Data.Limits == nil {
		e.Error = "unsupported quota format"
		return e
	}
	var tokens, times []Window
	for _, raw := range r.Data.Limits {
		var l zaiLimit
		if json.Unmarshal(raw, &l) != nil {
			e.Error = "unsupported quota entry"
			return e
		}
		if l.Type != "TOKENS_LIMIT" && l.Type != "TIME_LIMIT" && l.Type != "CREDIT_LIMIT" {
			continue // a kind this reader does not know
		}
		if l.Unit == nil || l.Number == nil || l.Percentage == nil {
			e.Error = "unsupported quota entry"
			return e
		}
		used := float64(*l.Percentage)
		if l.Usage != nil && *l.Usage > 0 {
			var spent *int64
			switch {
			case l.Remaining != nil:
				x := *l.Usage - *l.Remaining
				if l.CurrentValue != nil && *l.CurrentValue > x {
					x = *l.CurrentValue
				}
				spent = &x
			case l.CurrentValue != nil:
				spent = l.CurrentValue
			}
			if spent != nil {
				used = math.Round(float64(max(0, min(*l.Usage, *spent)))/float64(*l.Usage)*1000) / 10
			}
		}
		used = math.Max(0, math.Min(100, used))
		minutes := 0
		if m, ok := zaiUnit[*l.Unit]; ok && *l.Number > 0 {
			minutes = *l.Number * m
		}
		w := Window{Kind: "unknown", UsedPercent: &used, ResetMode: "fixed", ObservedAt: now.UTC()}
		if l.Type == "TIME_LIMIT" {
			w.Limit = "MCP"
			if *l.Unit == 5 && *l.Number == 1 {
				minutes = 30 * 24 * 60 // upstream: this marker is the monthly MCP allowance
			}
		}
		if minutes > 0 {
			w.WindowMinutes, w.Kind = minutes, kindOf(minutes)
		}
		// A five-hour reset cannot be more than five hours away; never guess a timezone fix.
		if t := l.NextResetTime; t != nil && *t > 0 && (l.Type == "TIME_LIMIT" || minutes != 300 || *t <= now.Add(5*time.Hour+time.Minute).UnixMilli()) {
			at := time.UnixMilli(*t).UTC()
			w.ResetsAt = &at
		}
		if l.Type == "TIME_LIMIT" {
			times = append(times, w)
		} else {
			tokens = append(tokens, w)
		}
	}
	sort.SliceStable(tokens, func(i, j int) bool { return length(tokens[i]) < length(tokens[j]) })
	e.Windows = append(tokens, times...)
	for _, p := range []string{r.Data.PlanName, r.Data.Plan, r.Data.PlanType, r.Data.PackageName, r.Data.Level} {
		if p = label(strings.TrimSpace(p)); p != "" {
			e.Plan = p
			break
		}
	}
	e.Status = "ok"
	e.ErrorCode = ""
	return e
}

func length(w Window) int {
	if w.WindowMinutes == 0 {
		return math.MaxInt
	}
	return w.WindowMinutes
}
