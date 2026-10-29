// SPDX-License-Identifier: MIT
package readers

import (
	"net/http"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

type requestPin struct {
	stage, limit int
	crossHost    bool
	headers      []string
	body         string
}

// requestSet is compiled from the reader cards. A metadata request may be
// omitted on a warm read; a stage can never be repeated. Regional routes bind
// the first authority for the entire logical read. Cursor's two distinct
// authorities have disjoint credential headers and are explicitly pinned.
func requestSet(scope string, r *http.Request) (requestPin, bool) {
	p := requestPin{limit: 1, headers: []string{"Accept", "Authorization", "User-Agent"}}
	host, path := r.URL.Host, r.URL.EscapedPath()
	method, query := http.MethodGet, ""
	valid := false
	switch scope {
	case consent.ScopeMiniMaxAccountUsageAPIKey:
		p.limit = 2
		valid = host == "api.minimax.io" || host == "api.minimaxi.com"
		switch path {
		case "/v1/token_plan/remains":
		case "/v1/api/openplatform/coding_plan/remains":
			p.stage = 1
		default:
			valid = false
		}
	case consent.ScopeClaudeAccountUsageSavedLogin:
		p.limit = 2
		p.headers = append(p.headers, "Anthropic-Beta")
		valid = host == "api.anthropic.com"
		switch path {
		case "/api/oauth/profile":
		case "/api/oauth/usage":
			p.stage = 1
		default:
			valid = false
		}
	case consent.ScopeKimiAccountUsageAPIKey:
		valid = (host == "api.kimi.com" || host == "api.kimi.ai") && path == "/coding/v1/usages"
	case consent.ScopeKimiAccountUsageSavedLogin:
		valid = host == "api.kimi.com" && path == "/coding/v1/usages"
		p.headers = append(p.headers, "X-Msh-Platform", "X-Msh-Version", "X-Msh-Device-Id", "X-Msh-Device-Name", "X-Msh-Device-Model", "X-Msh-Os-Version")
	case consent.ScopeZaiAccountUsageAPIKey:
		valid = (host == "api.z.ai" || host == "open.bigmodel.cn") && path == "/api/monitor/usage/quota/limit"
	case consent.ScopeOpenCodeGoAccountUsageAPIKey:
		valid = host == "opencode.ai" && path == "/zen/go/v1/usage"
	case consent.ScopeGrokAccountUsageSavedLogin:
		valid = host == "cli-chat-proxy.grok.com" && path == "/v1/billing"
		query = "format=credits"
		p.headers = append(p.headers, "X-Xai-Token-Auth", "X-Userid", "X-Grok-Client-Version", "X-Grok-Client-Mode")
	case consent.ScopeGeminiAccountUsageSavedLogin:
		p.limit, method = 2, http.MethodPost
		p.headers = append(p.headers, "Content-Type")
		valid = host == "cloudcode-pa.googleapis.com"
		switch path {
		case "/v1internal:loadCodeAssist":
			p.body = "gemini_load"
		case "/v1internal:retrieveUserQuota":
			p.stage, p.body = 1, "gemini_quota"
		default:
			valid = false
		}
	case consent.ScopeCursorAccountUsageSavedLogin:
		p.limit, p.crossHost, method, p.body = 2, true, http.MethodPost, "cursor"
		switch {
		case host == "cursor.com" && path == "/api/dashboard/get-plan-info":
			valid = true
			p.headers = []string{"Accept", "Content-Type", "User-Agent", "Cookie", "Origin"}
		case host == "api2.cursor.sh" && path == "/aiserver.v1.DashboardService/GetCurrentPeriodUsage":
			valid = true
			p.stage = 1
			p.headers = append(p.headers, "Content-Type", "Connect-Protocol-Version")
		default:
			valid = false
		}
	}
	return p, valid && r.Method == method && r.URL.RawQuery == query
}

func (p requestPin) validHeaders(r *http.Request) bool {
	seen := map[string]bool{}
	for name, values := range r.Header {
		key := strings.ToLower(name)
		if seen[key] || len(values) != 1 {
			return false
		}
		seen[key] = true
		allowed := false
		for _, pinned := range p.headers {
			if strings.EqualFold(name, pinned) {
				allowed = true
				break
			}
		}
		if !allowed {
			return false
		}
	}
	if p.body != "" {
		for _, name := range p.headers {
			if r.Header.Get(name) == "" {
				return false
			}
		}
		if r.Header.Get("Content-Type") != "application/json" || r.Header.Get("Accept") != "application/json" || r.Header.Get("User-Agent") != "modelplan" {
			return false
		}
	}
	if p.body == "cursor" {
		if p.stage == 0 {
			return r.Header.Get("Origin") == "https://cursor.com" && strings.HasPrefix(r.Header.Get("Cookie"), "WorkosCursorSessionToken=")
		}
		return r.Header.Get("Connect-Protocol-Version") == "1" && strings.HasPrefix(r.Header.Get("Authorization"), "Bearer ")
	}
	return true
}
