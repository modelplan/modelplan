package quota

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"
)

// Independent implementation of Antigravity Panel's GetUserStatus contract at
// n2ns/antigravity-panel dc1c63dd16c4621f115310fdea37b4c86fecc0cd.
// No Panel code is copied. Only the already-running app's loopback server is used.
var antigravityReader = &nativeReader{Name: "Antigravity", Regions: []string{"local"}, Collect: collectAntigravity, Fetch: fetchAntigravity}

// AntigravityServer contains transient local connection metadata, never OAuth.
// A descriptor can be supplied by CLIJIT after consent. Ambiguous discovery is
// unavailable: no port scanning, probing, network fallback or app launch.
type AntigravityServer struct {
	PID  int
	Port int
	CSRF string
	TLS  bool
	// Hub: Antigravity 2.34 hub mode; Port and CSRF come from its descriptor file, not argv.
	Hub bool
}
type antigravityServerKey struct{}

func WithAntigravityServer(ctx context.Context, s AntigravityServer) context.Context {
	return context.WithValue(ctx, antigravityServerKey{}, s)
}

var antigravityCommand = func(ctx context.Context, bin string, args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	cmd, err := toolcli.Command(ctx, bin, args...)
	if err != nil {
		return nil, errors.New("local process metadata unavailable")
	}
	cmd.Stderr = io.Discard
	var b bytes.Buffer
	cmd.Stdout = &limited{w: &b, n: 1 << 20}
	if toolcli.Run(cmd) != nil {
		return nil, errors.New("local process metadata unavailable")
	}
	return b.Bytes(), nil
}

func antigravityFlag(fields []string, name string) string {
	for i, f := range fields {
		if f == name && i+1 < len(fields) {
			return fields[i+1]
		}
		if strings.HasPrefix(f, name+"=") {
			return strings.TrimPrefix(f, name+"=")
		}
	}
	return ""
}

// Parse only this user's language_server processes with the exact app-data
// marker. Transient process arguments are never emitted or persisted.
func antigravityServers(raw []byte) []AntigravityServer {
	var out []AntigravityServer
	for _, line := range strings.Split(string(raw), "\n") {
		f := strings.Fields(line)
		if len(f) < 4 {
			continue
		}
		pid, pidErr := strconv.Atoi(f[0])
		uid, uidErr := strconv.Atoi(f[1])
		// The binary name is what identifies the server, wherever Antigravity.app lives: comm may be the
		// bare name or a full path, and a newer build may report another comm with the binary in argv.
		if pidErr != nil || uidErr != nil || pid <= 0 || uid != os.Getuid() || !(antigravityBinary(f[2]) || antigravityBinary(f[3])) {
			antigravityDebug(line, "not a language_server binary of this user")
			continue
		}
		app := antigravityFlag(f, "--app_data_dir")
		if app != "antigravity" && app != "antigravity-ide" {
			antigravityDebug(line, "app_data_dir is not antigravity")
			continue
		}
		if antigravityFlag(f, "--csrf_token") == "" && strings.Contains(line, "--read_host_bridge_token_from_stdin") {
			out = append(out, AntigravityServer{PID: pid, Hub: true})
			continue
		}
		port, err := strconv.Atoi(antigravityFlag(f, "--extension_server_port"))
		if err != nil || port < 1 || port > 65535 {
			antigravityDebug(line, "no usable extension_server_port")
			continue
		}
		token := antigravityFlag(f, "--csrf_token")
		if !antigravityCSRF(token) {
			antigravityDebug(line, "no usable csrf_token")
			continue
		}
		out = append(out, AntigravityServer{PID: pid, Port: port, CSRF: token})
	}
	return out
}
func antigravityLsof() string {
	if runtime.GOOS == "darwin" {
		return "/usr/sbin/lsof"
	}
	return "/usr/bin/lsof"
}
func antigravityBinary(path string) bool {
	name := strings.ToLower(filepath.Base(path))
	return name == "language_server" || strings.HasPrefix(name, "language_server_")
}

// antigravityDebugFlags are the only argument names a diagnostic may print. Values are never printed.
var antigravityDebugFlags = map[string]bool{
	"--app_data_dir": true, "--extension_server_port": true, "--csrf_token": true, "--standalone": true,
	"--subclient_type": true, "--https_server_port": true, "--read_host_bridge_token_from_stdin": true,
	"--enable_sidecars": true, "--host_bridge_url": true,
}

// antigravityDebug logs, with MODELPLAN_DEBUG set, a process line that mentions the language server or
// Antigravity but was not matched, so a newer build's signature can be seen. Only a numeric pid, a fixed
// binary label, allowlisted flag names and a count of other arguments are written; no argument value
// (the CSRF token, paths, other flag names) ever is.
func antigravityDebug(line, why string) {
	low := strings.ToLower(line)
	if os.Getenv("MODELPLAN_DEBUG") == "" || !(strings.Contains(low, "language_server") || strings.Contains(low, "antigravity")) {
		return
	}
	f := strings.Fields(line)
	if len(f) < 4 {
		return
	}
	pid, err := strconv.Atoi(f[0])
	if err != nil {
		return
	}
	binary := "other"
	if antigravityBinary(f[2]) || antigravityBinary(f[3]) {
		binary = "language_server"
	}
	var flags []string
	other := 0
	for _, a := range f[2:] {
		if !strings.HasPrefix(a, "--") {
			continue
		}
		if name := strings.SplitN(a, "=", 2)[0]; antigravityDebugFlags[name] {
			flags = append(flags, name)
		} else {
			other++
		}
	}
	fmt.Fprintf(os.Stderr, "modelplan: antigravity: unmatched process pid=%d binary=%s flags=%v otherFlags=%d: %s\n", pid, binary, flags, other, why)
}
func antigravityCSRF(s string) bool {
	if s == "" || len(s) > 256 {
		return false
	}
	for _, r := range s {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '-' || r == '_') {
			return false
		}
	}
	return true
}
func fetchAntigravity(ctx context.Context, c *http.Client, _, _ string, now time.Time) codexbarEntry {
	e := codexbarEntry{Status: "error", ObservedAt: now.UTC()}
	s, ok := ctx.Value(antigravityServerKey{}).(AntigravityServer)
	if !ok {
		raw, err := antigravityCommand(ctx, "/bin/ps", "-u", strconv.Itoa(os.Getuid()), "-o", "pid=,uid=,comm=,args=")
		if err != nil {
			e.Error = antigravityNext("not_detected")
			e.ErrorCode = "runtime_missing"
			return e
		}
		servers := antigravityServers(raw)
		if len(servers) == 0 {
			e.Error = antigravityNext("not_detected")
			e.ErrorCode = "runtime_missing"
			return e
		}
		if len(servers) != 1 {
			e.Error = antigravityNext("not_supported_yet")
			e.ErrorCode = "unsupported_login"
			return e
		}
		s = servers[0]
	}
	if s.Hub && s.Port == 0 {
		// Missing or invalid descriptor: the app is running but its token cannot be read.
		port, token, found := readAntigravityHubDescriptor(s.PID)
		if !found {
			e.Error = antigravityNext("not_supported_yet")
			e.ErrorCode = "unsupported_login"
			return e
		}
		s.Port, s.CSRF = port, token
	}
	if s.PID <= 0 || s.Port < 1 || s.Port > 65535 || !antigravityCSRF(s.CSRF) {
		e.Error = antigravityNext("not_supported_yet")
		e.ErrorCode = "unsupported_login"
		return e
	}
	if antigravityVerify(ctx, s) != nil {
		e.Error = antigravityNext("not_supported_yet")
		e.ErrorCode = "unsupported_login"
		return e
	}
	scheme := "http"
	if s.TLS {
		scheme = "https"
	}
	base := scheme + "://127.0.0.1:" + strconv.Itoa(s.Port) + "/exa.language_server_pb.LanguageServerService/"
	if c == nil {
		c = nativeClient
	}
	client := *c
	transport, ok := c.Transport.(*http.Transport)
	if c.Transport == nil {
		transport = http.DefaultTransport.(*http.Transport)
	} else if !ok {
		e.Error = antigravityNext("not_supported_yet")
		e.ErrorCode = "unsupported_login"
		return e
	}
	local := transport.Clone()
	// This RPC is bound to a verified loopback listener. Supplied system/proxy
	// policy must not route its nonce through a proxy or block the local dial.
	local.Proxy = nil
	baseDial := local.DialContext
	if baseDial == nil {
		baseDial = (&net.Dialer{Timeout: nativeTimeout}).DialContext
	}
	local.DialTLSContext = nil
	local.DialContext = func(dialCtx context.Context, network, address string) (net.Conn, error) {
		if address != net.JoinHostPort("127.0.0.1", strconv.Itoa(s.Port)) {
			return nil, errors.New("local endpoint changed")
		}
		conn, err := baseDial(dialCtx, network, address)
		if err != nil {
			return nil, err
		}
		// Revalidate after connect, before Transport sends HTTP headers/nonce.
		if err := antigravityVerify(dialCtx, s); err != nil {
			conn.Close()
			return nil, err
		}
		if la, ok := conn.LocalAddr().(*net.TCPAddr); s.Hub && (!ok || !antigravitySocketOwned(dialCtx, s, la.Port)) {
			conn.Close() // send no bytes, hence no token, to a socket the pid does not own
			return nil, errors.New("Antigravity socket owner unverified")
		}
		return conn, nil
	}
	client.Transport = local
	defer local.CloseIdleConnections()
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	rpc := func(method, body string) ([]byte, *codexbarEntry) {
		fail := codexbarEntry{Status: "error", ObservedAt: now.UTC()}
		rctx, cancel := context.WithTimeout(ctx, nativeTimeout)
		defer cancel()
		req, _ := http.NewRequestWithContext(rctx, http.MethodPost, base+method, strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Connect-Protocol-Version", "1")
		req.Header.Set("X-Codeium-Csrf-Token", s.CSRF)
		resp, err := client.Do(req)
		if err != nil {
			fail.Error = antigravityNext("network_error")
			fail.ErrorCode = transportErrorCode(err)
			return nil, &fail
		}
		defer resp.Body.Close()
		if resp.StatusCode == 401 || resp.StatusCode == 403 {
			fail.Error = antigravityNext("expired_login")
			fail.ErrorCode = httpErrorCode(resp.StatusCode)
			return nil, &fail
		}
		if resp.StatusCode != 200 {
			fail.Error = antigravityNext("upstream_changed")
			fail.ErrorCode = httpErrorCode(resp.StatusCode)
			return nil, &fail
		}
		b, err := io.ReadAll(io.LimitReader(resp.Body, nativeMaxBody+1))
		if err != nil || len(b) > nativeMaxBody {
			fail.Error = antigravityNext("upstream_changed")
			fail.ErrorCode = "schema_changed"
			return nil, &fail
		}
		return b, nil
	}
	if s.Hub {
		// Token Monitor@417f84d2 probe.js:783-797: RetrieveUserQuotaSummary first, GetUserStatus as the fallback.
		if b, fail := rpc("RetrieveUserQuotaSummary", `{"forceRefresh":true}`); fail == nil {
			if got := parseAntigravitySummary(b, now); got.Status == "ok" {
				return got
			}
		} else if fail.ErrorCode == "unauthorized" || fail.Error == antigravityNext("expired_login") {
			return *fail
		}
	}
	b, fail := rpc("GetUserStatus", `{"metadata":{"ideName":"antigravity","extensionName":"antigravity","ideVersion":"unknown","locale":"en"}}`)
	if fail != nil {
		return *fail
	}
	return parseAntigravity(b, now)
}

// parseAntigravitySummary reads RetrieveUserQuotaSummary: groups of 5-hour and weekly buckets.
// Reference: Token Monitor@417f84d2 probe.js:530-610 (quotaSummaryWindows and its helpers).
func parseAntigravitySummary(b []byte, now time.Time) codexbarEntry {
	e := codexbarEntry{ErrorCode: "schema_changed", Status: "error", ObservedAt: now.UTC(), Error: antigravityNext("not_supported_yet")}
	type bucket struct {
		BucketID    string   `json:"bucketId"`
		DisplayName string   `json:"displayName"`
		Window      string   `json:"window"`
		Disabled    bool     `json:"disabled"`
		Fraction    *float64 `json:"remainingFraction"`
		Remaining   *struct {
			Fraction *float64 `json:"remainingFraction"`
			Case     string   `json:"case"`
			Value    *float64 `json:"value"`
		} `json:"remaining"`
		Reset json.RawMessage `json:"resetTime"`
	}
	type group struct {
		DisplayName string   `json:"displayName"`
		Buckets     []bucket `json:"buckets"`
	}
	type summary struct {
		Groups []group `json:"groups"`
	}
	var raw struct {
		summary
		Response *summary `json:"response"`
		Summary  *summary `json:"summary"`
	}
	if json.Unmarshal(b, &raw) != nil {
		e.ErrorCode = "parse_error"
		return e
	}
	groups := raw.Groups
	if raw.Response != nil {
		groups = raw.Response.Groups
	} else if raw.Summary != nil {
		groups = raw.Summary.Groups
	}
	if len(groups) > 16 {
		return e
	}
	rank := func(name string) int {
		switch name {
		case "Gemini":
			return 0
		case "Gemini 4 Argon":
			return 1
		case "Claude/GPT":
			return 2
		}
		return 3
	}
	sort.SliceStable(groups, func(i, j int) bool {
		return rank(antigravityGroupName(groups[i].DisplayName)) < rank(antigravityGroupName(groups[j].DisplayName))
	})
	for _, g := range groups {
		name := antigravityGroupName(g.DisplayName)
		var session, weekly []Window
		for _, bk := range g.Buckets {
			kind := antigravityBucketKind(bk.Window, bk.BucketID, bk.DisplayName)
			if kind == "" || bk.Disabled {
				continue
			}
			fr := bk.Fraction
			if fr == nil && bk.Remaining != nil {
				fr = bk.Remaining.Fraction
				if fr == nil && bk.Remaining.Case == "remainingFraction" {
					fr = bk.Remaining.Value
				}
			}
			fr = finite(fr, 0, 1)
			if fr == nil {
				continue
			}
			var reset *time.Time
			var text string
			if json.Unmarshal(bk.Reset, &text) == nil {
				reset = stamp(text)
			}
			if reset != nil && !reset.After(now) {
				continue
			}
			used := 100 * (1 - *fr)
			w := Window{Kind: kind, Limit: name, UsedPercent: &used, ResetsAt: reset, ResetMode: "fixed", ObservedAt: now.UTC()}
			if kind == "five_hour" {
				w.WindowMinutes = 300
				session = append(session, w)
			} else {
				w.WindowMinutes = 7 * 24 * 60
				weekly = append(weekly, w)
			}
		}
		e.Windows = append(e.Windows, append(session, weekly...)...)
	}
	if len(e.Windows) > 0 {
		e.Status, e.ErrorCode, e.Error = "ok", "", ""
	}
	return e
}

// antigravityGroupName maps a vendor group display name to a reviewed label. An unrecognised name is
// vendor text and is never stored or shown: it becomes a fixed label.
func antigravityGroupName(display string) string {
	lower := strings.ToLower(strings.Join(strings.Fields(display), " "))
	switch {
	case lower == "gemini" || lower == "gemini models":
		return "Gemini"
	case lower == "gemini 4 argon":
		return "Gemini 4 Argon"
	case antigravityClaudeGPT.MatchString(lower):
		return "Claude/GPT"
	}
	return "Other models"
}

var antigravityClaudeGPT = regexp.MustCompile(`^claude\s*(and|&|/)\s*gpt( models)?$`)

func antigravityBucketKind(values ...string) string {
	for _, v := range values {
		n := strings.ReplaceAll(strings.ToLower(strings.TrimSpace(v)), "_", "-")
		n = strings.TrimSuffix(strings.TrimSuffix(n, " remaining"), " limit")
		n = strings.TrimSuffix(n, " remaining")
		switch {
		case n == "weekly" || strings.HasSuffix(n, "-weekly") || strings.HasSuffix(n, " weekly"):
			return "weekly"
		case n == "session" || n == "5h" || n == "5-hour" || n == "five hour" || n == "five-hour" ||
			strings.HasSuffix(n, "-5h") || strings.HasSuffix(n, "-5-hour") || strings.HasSuffix(n, "-five-hour") || strings.HasSuffix(n, "-session"):
			return "five_hour"
		}
	}
	return ""
}
func parseAntigravity(b []byte, now time.Time) codexbarEntry {
	e := codexbarEntry{ErrorCode: "schema_changed", Status: "error", ObservedAt: now.UTC(), Error: antigravityNext("not_supported_yet")}
	var raw struct {
		UserStatus *struct {
			Config *struct {
				Models []struct {
					Model struct {
						Model string `json:"model"`
					} `json:"modelOrAlias"`
					Quota *struct {
						Remaining *float64 `json:"remainingFraction"`
						Reset     string   `json:"resetTime"`
					} `json:"quotaInfo"`
				} `json:"clientModelConfigs"`
			} `json:"cascadeModelConfigData"`
		} `json:"userStatus"`
	}
	if json.Unmarshal(b, &raw) != nil {
		e.ErrorCode = "parse_error"
		return e
	}
	if raw.UserStatus == nil || raw.UserStatus.Config == nil || len(raw.UserStatus.Config.Models) > 256 {
		return e
	}
	seen := map[string]bool{}
	var reported []string
	for _, m := range raw.UserStatus.Config.Models {
		reported = append(reported, m.Model.Model)
	}
	for _, m := range raw.UserStatus.Config.Models {
		id := clip(m.Model.Model)
		if id == "" || seen[id] || m.Quota == nil {
			continue
		}
		seen[id] = true
		remaining := finite(m.Quota.Remaining, 0, 1)
		if remaining == nil {
			continue
		}
		reset := stamp(m.Quota.Reset)
		if reset != nil && !reset.After(now) {
			continue
		}
		used := 100 * (1 - *remaining)
		e.Windows = append(e.Windows, Window{Kind: "unknown", Limit: id, UsedPercent: &used, ResetsAt: reset, ResetMode: "fixed", ObservedAt: now.UTC()})
	}
	if len(e.Windows) > 0 {
		e.Status = "ok"
		e.ErrorCode = ""
		e.Error = ""
		// D99: every model the app lists for the account (not only those with a quota), slugs only.
		e.ReportedModels = cleanReportedModels(reported)
	}
	// Models are Antigravity pools; no Claude Code/Codex plan or account binding.
	return e
}

// A supplied descriptor is not authority by itself. Re-read the current process
// nonce/port and the OS listener owner; never send the nonce to an unrelated PID.
var antigravityVerify = verifyAntigravityServer

func verifyAntigravityServer(ctx context.Context, s AntigravityServer) error {
	raw, err := antigravityCommand(ctx, "/bin/ps", "-p", strconv.Itoa(s.PID), "-o", "pid=,uid=,comm=,args=")
	if err != nil {
		return errors.New("Antigravity process unavailable")
	}
	candidates := antigravityServers(raw)
	if len(candidates) != 1 || candidates[0].PID != s.PID {
		return errors.New("Antigravity process changed")
	}
	if s.Hub {
		if port, token, ok := readAntigravityHubDescriptor(s.PID); !candidates[0].Hub || !ok || port != s.Port || token != s.CSRF {
			return errors.New("Antigravity process changed")
		}
	} else if candidates[0].Hub || candidates[0].Port != s.Port || candidates[0].CSRF != s.CSRF {
		return errors.New("Antigravity process changed")
	}
	bin := antigravityLsof()
	raw, err = antigravityCommand(ctx, bin, "-nP", "-iTCP:"+strconv.Itoa(s.Port), "-sTCP:LISTEN", "-Fpcun")
	if err != nil {
		return errors.New("Antigravity listener unavailable")
	}
	pid, uid := -1, -1
	matched := false
	for _, line := range strings.Split(string(raw), "\n") {
		if len(line) < 2 {
			continue
		}
		switch line[0] {
		case 'p':
			pid, err = strconv.Atoi(line[1:])
			if err != nil || pid != s.PID {
				return errors.New("Antigravity listener owner changed")
			}
			uid = -1
		case 'u':
			uid, err = strconv.Atoi(line[1:])
			if err != nil || uid != os.Getuid() {
				return errors.New("Antigravity listener user changed")
			}
		case 'n':
			if pid != s.PID || uid != os.Getuid() {
				return errors.New("Antigravity listener unverified")
			}
			if line[1:] == net.JoinHostPort("127.0.0.1", strconv.Itoa(s.Port)) {
				matched = true
			}
		}
	}
	if !matched {
		return errors.New("Antigravity loopback listener unavailable")
	}
	return nil
}
