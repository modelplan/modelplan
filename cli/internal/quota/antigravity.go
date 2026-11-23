package quota

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"slices"
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
}
type antigravityServerKey struct{}

func WithAntigravityServer(ctx context.Context, s AntigravityServer) context.Context {
	return context.WithValue(ctx, antigravityServerKey{}, s)
}

var antigravityCommand = func(ctx context.Context, bin string, args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, args...)
	cmd.Stderr = io.Discard
	cmd.WaitDelay = time.Second
	var b bytes.Buffer
	cmd.Stdout = &limited{w: &b, n: 1 << 20}
	if cmd.Run() != nil {
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

// One parsed `ps -o pid=,uid=,comm=,args=` row for this user's language_server
// process. Kept only for discovery and verification inside this file; transient
// process arguments are never emitted or persisted.
type antigravityProcessRow struct {
	pid    int
	fields []string
}

// macOS prints `comm` beside `args` as the first 16 characters of the executable path
// (`/Applications/An`), so the name is then read from the command line's first
// argument, which that prefix must begin; Linux, and a path of at most 16 characters,
// print the bare name. Anything else, including a path split by a space, is not a match.
func antigravityLanguageServer(fields []string) bool {
	isName := func(s string) bool {
		s = strings.ToLower(filepath.Base(s))
		return s == "language_server" || strings.HasPrefix(s, "language_server_")
	}
	return isName(fields[2]) || strings.HasPrefix(fields[3], fields[2]) && isName(fields[3])
}

func antigravityProcessRows(raw []byte) []antigravityProcessRow {
	var out []antigravityProcessRow
	for _, line := range strings.Split(string(raw), "\n") {
		f := strings.Fields(line)
		if len(f) < 4 {
			continue
		}
		pid, pidErr := strconv.Atoi(f[0])
		uid, uidErr := strconv.Atoi(f[1])
		if pidErr != nil || uidErr != nil || pid <= 0 || uid != os.Getuid() || !antigravityLanguageServer(f) {
			continue
		}
		out = append(out, antigravityProcessRow{pid: pid, fields: f})
	}
	return out
}

// The exact app-data marker of an Antigravity server; also the folder under
// ~/.gemini that holds its daemon descriptors. Empty for any other process.
func antigravityAppData(fields []string) string {
	app := antigravityFlag(fields, "--app_data_dir")
	if app != "antigravity" && app != "antigravity-ide" {
		return ""
	}
	return app
}

// Parse only this user's language_server processes with the exact app-data
// marker and the extension-server port and transport nonce on the command line
// (the IDE extension mode). Hub-mode servers are found by antigravityDaemonServers.
func antigravityServers(raw []byte) []AntigravityServer {
	var out []AntigravityServer
	for _, row := range antigravityProcessRows(raw) {
		if antigravityAppData(row.fields) == "" {
			continue
		}
		port, err := strconv.Atoi(antigravityFlag(row.fields, "--extension_server_port"))
		if err != nil || port < 1 || port > 65535 {
			continue
		}
		token := antigravityFlag(row.fields, "--csrf_token")
		if !antigravityCSRF(token) {
			continue
		}
		out = append(out, AntigravityServer{PID: row.pid, Port: port, CSRF: token})
	}
	return out
}

// Newer Antigravity (2.3x) hub-mode language servers start without the
// extension-server port and transport nonce on the command line (the nonce arrives
// on stdin) and write them to a descriptor beside their app data instead:
// ~/.gemini/<app data dir>/daemon/hub_<port>.json with pid, httpsPort, httpPort,
// lsVersion and csrfToken, the file antigravity-panel reads for the same servers
// (n2ns/antigravity-panel#224). csrfToken is the same transient local transport nonce
// the command line carried in IDE mode, never an account credential.
type antigravityDaemonDescriptor struct {
	PID       int    `json:"pid"`
	HTTPPort  int    `json:"httpPort"`
	CSRFToken string `json:"csrfToken"`
}

var antigravityDaemonDir = func(appData string) string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".gemini", appData, "daemon")
}

func antigravityHubDescriptorName(name string) bool {
	stem, ok := strings.CutPrefix(name, "hub_")
	if !ok {
		return false
	}
	if stem, ok = strings.CutSuffix(stem, ".json"); !ok || stem == "" {
		return false
	}
	for _, r := range stem {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

// A descriptor alone is not authority. As in antigravity-panel, a file is accepted
// only when its pid is a language_server from the same ps snapshot that runs with
// the app data owning the descriptor's folder, so a stale descriptor from an earlier
// run (dead or recycled pid), or another tool's server, yields nothing. The listener
// ownership check in verifyAntigravityServer then pins the port. A pid already
// discovered from the command line is not repeated.
func antigravityDaemonServers(raw []byte, known []AntigravityServer) []AntigravityServer {
	discovered := map[int]bool{}
	for _, s := range known {
		discovered[s.PID] = true
	}
	// Each running server by pid with the folder that holds its app data's descriptors.
	apps, dirs := map[int]string{}, []string{}
	for _, row := range antigravityProcessRows(raw) {
		dir := ""
		if app := antigravityAppData(row.fields); app != "" {
			dir = antigravityDaemonDir(app)
		}
		if dir != "" && apps[row.pid] == "" {
			apps[row.pid] = dir
			dirs = append(dirs, dir)
		}
	}
	var out []AntigravityServer
	for i, dir := range dirs {
		if slices.Contains(dirs[:i], dir) {
			continue
		}
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, entry := range entries {
			if !antigravityHubDescriptorName(entry.Name()) {
				continue
			}
			b, status := readBounded(filepath.Join(dir, entry.Name()), 8<<10)
			if status != "" {
				continue
			}
			var d antigravityDaemonDescriptor
			if json.Unmarshal(b, &d) != nil || d.PID <= 0 || discovered[d.PID] || !antigravityCSRF(d.CSRFToken) {
				continue
			}
			if apps[d.PID] != dir || d.HTTPPort < 1 || d.HTTPPort > 65535 {
				continue
			}
			out = append(out, AntigravityServer{PID: d.PID, Port: d.HTTPPort, CSRF: d.CSRFToken})
		}
	}
	return out
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
		servers = append(servers, antigravityDaemonServers(raw, servers)...)
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
	url := scheme + "://127.0.0.1:" + strconv.Itoa(s.Port) + "/exa.language_server_pb.LanguageServerService/GetUserStatus"
	ctx, cancel := context.WithTimeout(ctx, nativeTimeout)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, url, strings.NewReader(`{"metadata":{"ideName":"antigravity","extensionName":"antigravity","ideVersion":"unknown","locale":"en"}}`))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Connect-Protocol-Version", "1")
	req.Header.Set("X-Codeium-Csrf-Token", s.CSRF)
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
		return conn, nil
	}
	client.Transport = local
	defer local.CloseIdleConnections()
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	resp, err := client.Do(req)
	if err != nil {
		e.Error = antigravityNext("network_error")
		e.ErrorCode = transportErrorCode(err)
		return e
	}
	defer resp.Body.Close()
	if resp.StatusCode == 401 || resp.StatusCode == 403 {
		e.Error = antigravityNext("expired_login")
		e.ErrorCode = httpErrorCode(resp.StatusCode)
		return e
	}
	if resp.StatusCode != 200 {
		e.Error = antigravityNext("upstream_changed")
		e.ErrorCode = httpErrorCode(resp.StatusCode)
		return e
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, nativeMaxBody+1))
	if err != nil || len(b) > nativeMaxBody {
		e.Error = antigravityNext("upstream_changed")
		e.ErrorCode = "schema_changed"
		return e
	}
	return parseAntigravity(b, now)
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
	// Identity is the pid's own row: this user's language_server with Antigravity's
	// app data. An IDE-mode row re-states the port and nonce, and a mismatch fails the
	// read. A hub-mode row carries neither (its daemon descriptor owns them), so for
	// those the listener ownership below is what pins the port.
	identity := false
	for _, row := range antigravityProcessRows(raw) {
		if row.pid != s.PID || antigravityAppData(row.fields) == "" {
			continue
		}
		port, portErr := strconv.Atoi(antigravityFlag(row.fields, "--extension_server_port"))
		token := antigravityFlag(row.fields, "--csrf_token")
		if portErr == nil || token != "" {
			if port != s.Port || token != s.CSRF {
				return errors.New("Antigravity process changed")
			}
		}
		identity = true
		break
	}
	if !identity {
		return errors.New("Antigravity process changed")
	}
	bin := "/usr/bin/lsof"
	if runtime.GOOS == "darwin" {
		bin = "/usr/sbin/lsof"
	}
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
