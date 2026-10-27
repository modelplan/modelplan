package quota

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"os/exec"
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

// Parse only this user's language_server processes with the exact app-data
// marker. Transient process arguments are never emitted or persisted.
func antigravityServers(raw []byte) []AntigravityServer {
	var out []AntigravityServer
	for _, line := range strings.Split(string(raw), "\n") {
		f := strings.Fields(line)
		if len(f) < 3 || !strings.Contains(strings.ToLower(line), "language_server") {
			continue
		}
		app := antigravityFlag(f, "--app_data_dir")
		if app != "antigravity" && app != "antigravity-ide" {
			continue
		}
		port, err := strconv.Atoi(antigravityFlag(f, "--extension_server_port"))
		if err != nil || port < 1 || port > 65535 {
			continue
		}
		token := antigravityFlag(f, "--csrf_token")
		if !antigravityCSRF(token) {
			continue
		}
		out = append(out, AntigravityServer{Port: port, CSRF: token})
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
		raw, err := antigravityCommand(ctx, "/bin/ps", "-u", strconv.Itoa(os.Getuid()), "-o", "pid=,args=")
		if err != nil {
			e.Error = antigravityNext("not_detected")
			return e
		}
		servers := antigravityServers(raw)
		if len(servers) == 0 {
			e.Error = antigravityNext("not_detected")
			return e
		}
		if len(servers) != 1 {
			e.Error = antigravityNext("not_supported_yet")
			return e
		}
		s = servers[0]
	}
	if s.Port < 1 || s.Port > 65535 || !antigravityCSRF(s.CSRF) {
		e.Error = antigravityNext("not_supported_yet")
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
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	resp, err := client.Do(req)
	if err != nil {
		e.Error = antigravityNext("network_error")
		return e
	}
	defer resp.Body.Close()
	if resp.StatusCode == 401 || resp.StatusCode == 403 {
		e.Error = antigravityNext("expired_login")
		return e
	}
	if resp.StatusCode != 200 {
		e.Error = antigravityNext("upstream_changed")
		return e
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, nativeMaxBody+1))
	if err != nil || len(b) > nativeMaxBody {
		e.Error = antigravityNext("upstream_changed")
		return e
	}
	return parseAntigravity(b, now)
}
func parseAntigravity(b []byte, now time.Time) codexbarEntry {
	e := codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: antigravityNext("not_supported_yet")}
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
	if json.Unmarshal(b, &raw) != nil || raw.UserStatus == nil || raw.UserStatus.Config == nil || len(raw.UserStatus.Config.Models) > 256 {
		return e
	}
	seen := map[string]bool{}
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
		e.Error = ""
	}
	// Models are Antigravity pools; no Claude Code/Codex plan or account binding.
	return e
}
