package quota

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Independently implemented from the official Copilot SDK's documented server RPC and
// wire contract (github/copilot-sdk, 538675843887643ce471c874a3a9870ebda3f6f4).
// Authentication stays with the installed runtime. No session, turn, login, token import,
// credential-file read/write, or inferred entitlement is needed.
var copilotReader = &nativeReader{Regions: []string{"local"}, Collect: collectCopilot, Fetch: fetchCopilot}

var copilotBin = func() string {
	if p := os.Getenv("MODELPLAN_COPILOT"); p != "" && filepath.IsAbs(p) {
		return p
	}
	home, _ := os.UserHomeDir()
	return toolcli.Find(home, "copilot")
}

type copilotRPCError struct{ state string }

func (e *copilotRPCError) Error() string { return copilotNext(e.state) }

func fetchCopilot(ctx context.Context, _ *http.Client, _, _ string, now time.Time) codexbarEntry {
	e := codexbarEntry{Status: "error", ObservedAt: now.UTC()}
	bin := copilotBin()
	if bin == "" {
		e.Error = copilotNext("not_detected")
		e.ErrorCode = "runtime_missing"
		return e
	}
	raw, err := askCopilot(ctx, bin)
	if err != nil {
		e.Error = err.Error()
		e.ErrorCode = errorCode(err)
		if errors.Is(err, toolcli.ErrRuntimeMissing) {
			e.Status = toolcli.RuntimeMissing
			e.Error = toolcli.RuntimeNextStep
		} else {
			var rpc *copilotRPCError
			if errors.As(err, &rpc) {
				e.ErrorCode = statusErrorCode(rpc.state)
			}
		}
		return e
	}
	return parseCopilot(raw, now)
}

func askCopilot(ctx context.Context, bin string) (json.RawMessage, error) {
	ctx, cancel := context.WithTimeout(ctx, nativeTimeout)
	defer cancel()
	cmd, err := toolcli.CommandContext(ctx, bin, "--headless", "--no-auto-update", "--stdio")
	if err != nil {
		return nil, err
	}
	cmd.Stderr = io.Discard
	cmd.Env = copilotEnvironment(os.Environ())
	cmd.WaitDelay = time.Second
	in, err := cmd.StdinPipe()
	if err != nil {
		return nil, errors.New("Copilot input unavailable")
	}
	out, err := cmd.StdoutPipe()
	if err != nil {
		return nil, errors.New("Copilot output unavailable")
	}
	if cmd.Start() != nil {
		return nil, &copilotRPCError{"not_detected"}
	}
	defer func() { _ = in.Close(); _ = out.Close(); _ = cmd.Process.Kill(); _ = cmd.Wait() }()
	raw, err := copilotQuotaRPC(out, in)
	if ctx.Err() != nil {
		return nil, codeError("timeout", "Copilot quota read timed out")
	}
	return raw, err
}

// Copilot uses Content-Length frames, not newline-delimited JSON. The allowlist here is
// deliberately tiny: the protocol handshake (or legacy ping), then account.getQuota.
func copilotQuotaRPC(out io.Reader, in io.Writer) (json.RawMessage, error) {
	r := bufio.NewReader(io.LimitReader(out, 4*nativeMaxBody))
	call := func(id int, method string) (json.RawMessage, int, error) {
		body, _ := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": id, "method": method, "params": map[string]any{}})
		if _, err := fmt.Fprintf(in, "Content-Length: %d\r\n\r\n%s", len(body), body); err != nil {
			return nil, 0, errors.New("Copilot request failed")
		}
		for n := 0; n < 32; n++ {
			raw, err := readCopilotFrame(r)
			if err != nil {
				return nil, 0, err
			}
			var m struct {
				ID     *int            `json:"id"`
				Result json.RawMessage `json:"result"`
				Error  *struct {
					Code int `json:"code"`
				} `json:"error"`
			}
			if json.Unmarshal(raw, &m) != nil {
				return nil, 0, errors.New("unreadable Copilot reply")
			}
			if m.ID == nil || *m.ID != id {
				continue
			}
			if m.Error != nil {
				state := "upstream_changed"
				if m.Error.Code == -32601 {
					state = "not_supported_yet"
				}
				if m.Error.Code == 401 || m.Error.Code == 403 {
					state = "expired_login"
				}
				return nil, m.Error.Code, &copilotRPCError{state}
			}
			if len(m.Result) == 0 || string(m.Result) == "null" {
				return nil, 0, errors.New("empty Copilot reply")
			}
			return m.Result, 0, nil
		}
		return nil, 0, errors.New("too many Copilot messages")
	}
	handshake, code, err := call(1, "connect")
	if code == -32601 {
		handshake, _, err = call(2, "ping")
	}
	if err != nil {
		return nil, err
	}
	var protocol struct {
		Version int `json:"protocolVersion"`
	}
	if json.Unmarshal(handshake, &protocol) != nil || protocol.Version != 3 {
		return nil, errors.New("unsupported Copilot runtime protocol (expected 3)")
	}
	auth, _, err := call(3, "auth.getStatus")
	if err != nil {
		return nil, err
	}
	var status struct {
		Authenticated bool   `json:"isAuthenticated"`
		Type          string `json:"authType"`
	}
	if json.Unmarshal(auth, &status) != nil {
		return nil, &copilotRPCError{"upstream_changed"}
	}
	if !status.Authenticated {
		return nil, &copilotRPCError{"expired_login"}
	}
	if status.Type != "user" {
		return nil, &copilotRPCError{"not_supported_yet"}
	}
	raw, _, err := call(4, "account.getQuota")
	return raw, err
}

func readCopilotFrame(r *bufio.Reader) ([]byte, error) {
	length, headers := -1, 0
	for {
		line, err := r.ReadString('\n')
		headers += len(line)
		if err != nil || headers > 8192 {
			return nil, errors.New("invalid Copilot frame header")
		}
		if line == "\r\n" || line == "\n" {
			break
		}
		name, value, ok := strings.Cut(strings.TrimSpace(line), ":")
		if ok && strings.EqualFold(name, "Content-Length") {
			if length != -1 {
				return nil, errors.New("duplicate Copilot frame length")
			}
			length, err = strconv.Atoi(strings.TrimSpace(value))
			if err != nil || length <= 0 || length > nativeMaxBody {
				return nil, errors.New("invalid Copilot frame length")
			}
		}
	}
	if length <= 0 {
		return nil, errors.New("missing Copilot frame length")
	}
	body := make([]byte, length)
	if _, err := io.ReadFull(r, body); err != nil {
		return nil, errors.New("cut-off Copilot reply")
	}
	return body, nil
}

func parseCopilot(raw json.RawMessage, now time.Time) codexbarEntry {
	e := codexbarEntry{ErrorCode: "schema_changed", Status: "error", ObservedAt: now.UTC()}
	var r struct {
		Snapshots map[string]*struct {
			Used      *int64   `json:"usedRequests"`
			Limit     *int64   `json:"entitlementRequests"`
			Remaining *float64 `json:"remainingPercentage"`
			Reset     string   `json:"resetDate"`
			Unlimited bool     `json:"isUnlimitedEntitlement"`
		} `json:"quotaSnapshots"`
	}
	if json.Unmarshal(raw, &r) != nil {
		e.ErrorCode = "parse_error"
		e.Error = "unreadable Copilot quota reply"
		return e
	}
	for _, pool := range []string{"premium_interactions", "chat", "completions"} {
		q := r.Snapshots[pool]
		if q == nil || (q.Used == nil && q.Limit == nil && q.Remaining == nil && !q.Unlimited) {
			continue
		}
		w := Window{Kind: "unknown", Limit: pool, ResetMode: "fixed", ObservedAt: now.UTC()}
		// A missing field is unknown. Zero entitlement is not 100% remaining; -1 is unlimited.
		if q.Used != nil && *q.Used >= 0 {
			w.Requests = &RequestUsage{Used: q.Used}
		}
		if q.Limit != nil && *q.Limit > 0 && !q.Unlimited {
			if w.Requests == nil {
				w.Requests = &RequestUsage{}
			}
			w.Requests.Limit = q.Limit
			if p := finite(q.Remaining, 0, 100); p != nil {
				used := 100 - *p
				w.UsedPercent = &used
			} else if w.Requests.Used != nil {
				used := float64(*q.Used) / float64(*q.Limit) * 100
				w.UsedPercent = &used
			}
		} else if q.Unlimited || (q.Limit != nil && *q.Limit == -1) {
			if w.Requests == nil {
				w.Requests = &RequestUsage{}
			}
			w.Requests.Unlimited = true
		}
		if t, err := time.Parse(time.RFC3339, q.Reset); err == nil {
			t = t.UTC()
			w.ResetsAt = &t
			// The SDK gives a reset date but no cycle length. Do not guess monthly.
			if !t.After(now) {
				continue
			}
		}
		if w.UsedPercent == nil {
			if w.Requests == nil {
				w.Requests = &RequestUsage{}
			}
			w.Requests.Reason = "missing_entitlement_or_usage"
		}
		e.Windows = append(e.Windows, w)
	}
	if len(e.Windows) == 0 {
		e.Error = copilotNext("not_supported_yet")
		return e
	}
	e.Status = "ok"
	e.ErrorCode = ""
	return e
}

// Do not import GitHub CLI/SDK tokens from the caller's environment. Proxy and
// runtime-home settings are inherited; the installed runtime owns its sign-in.
func copilotEnvironment(env []string) []string {
	out := make([]string, 0, len(env))
	for _, entry := range env {
		name, _, _ := strings.Cut(entry, "=")
		switch name {
		case "GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN", "COPILOT_GITHUB_TOKEN", "COPILOT_SDK_AUTH_TOKEN", "NODE_DEBUG":
			continue
		}
		out = append(out, entry)
	}
	return out
}
