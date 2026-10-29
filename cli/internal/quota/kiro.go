package quota

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
	"io"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Kiro: its own CLI answers over the Agent Client Protocol. A short-lived `kiro-cli acp` is
// initialized and asked `_kiro/account/getUsage`, then stopped: no session is created and no
// prompt is sent, and Kiro keeps its sign-in (nothing of it is read here). Each credit pool with a
// limit becomes a monthly window ending at the billing-cycle reset. Ported from Pulse
// (github.com/qunqin24/Pulse, Apache-2.0, KiroACPClient.swift and KiroUsageService.swift at
// 8410d08), which validated the route with Kiro CLI 2.22.1.

var kiroReader = &nativeReader{Regions: []string{"local"}, Fetch: fetchKiro}

const kiroTimeout = 20 * time.Second

// kiroBin: $MODELPLAN_KIRO, PATH, then the usual install places. "" when none.
var kiroBin = func() string {
	if p := os.Getenv("MODELPLAN_KIRO"); p != "" && filepath.IsAbs(p) {
		return p
	}
	home, _ := os.UserHomeDir()
	return toolcli.Find(home, "kiro-cli", "/Applications/Kiro CLI.app/Contents/MacOS/kiro-cli", "/Applications/Kiro.app/Contents/Resources/app/bin/kiro-cli")
}

func fetchKiro(ctx context.Context, _ *http.Client, _, _ string, now time.Time) codexbarEntry {
	e := codexbarEntry{Status: "error", ObservedAt: now.UTC()}
	bin := kiroBin()
	if bin == "" {
		e.Error = "kiro-cli not found"
		e.ErrorCode = "runtime_missing"
		return e
	}
	raw, err := askKiro(ctx, bin)
	if err != nil {
		e.Error = err.Error()
		e.ErrorCode = errorCode(err)
		if errors.Is(err, toolcli.ErrRuntimeMissing) {
			e.Status = toolcli.RuntimeMissing
			e.Error = toolcli.RuntimeNextStep
		}
		return e
	}
	return parseKiro(raw, now)
}

// askKiro: initialize (Kiro sets up its sign-in while answering it), then getUsage.
func askKiro(ctx context.Context, bin string) (json.RawMessage, error) {
	ctx, cancel := context.WithTimeout(ctx, 2*kiroTimeout)
	defer cancel()
	cmd, err := toolcli.CommandContext(ctx, bin, "acp", "--agent-engine", "v3", "--auth-method", "cli")
	if err != nil {
		return nil, err
	}
	cmd.Stderr = io.Discard
	in, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	out, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		if ctx.Err() != nil {
			return nil, codeError(transportErrorCode(ctx.Err()), "Kiro read canceled")
		}
		return nil, codeError("runtime_missing", "kiro-cli did not start")
	}
	defer func() { _ = in.Close(); _ = cmd.Process.Kill(); _ = cmd.Wait() }()
	send := func(v any) error { b, _ := json.Marshal(v); _, err := in.Write(append(b, '\n')); return err }
	sc := bufio.NewScanner(out)
	sc.Buffer(make([]byte, 0, 64<<10), 4<<20)
	wait := func(id int) (json.RawMessage, error) {
		malformed := false
		for sc.Scan() {
			var m struct {
				ID     *int            `json:"id"`
				Result json.RawMessage `json:"result"`
				Error  *struct {
					Message string `json:"message"`
				} `json:"error"`
			}
			if json.Unmarshal(sc.Bytes(), &m) != nil {
				malformed = true
				continue
			}
			if m.ID == nil || *m.ID != id {
				continue
			}
			if m.Error != nil {
				return nil, codeError(kiroMessageCode(m.Error.Message), kiroReason(m.Error.Message))
			}
			return m.Result, nil
		}
		if ctx.Err() != nil {
			return nil, codeError("timeout", "timed out")
		}
		if malformed {
			return nil, codeError("parse_error", "invalid Kiro reply")
		}
		return nil, codeError("schema_changed", "kiro-cli closed")
	}
	if err := send(map[string]any{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": map[string]any{
		"protocolVersion": 1, "clientCapabilities": map[string]any{}, "clientInfo": map[string]any{"name": "modelplan", "version": "1"}}}); err != nil {
		return nil, err
	}
	if _, err := wait(1); err != nil {
		return nil, err
	}
	if err := send(map[string]any{"jsonrpc": "2.0", "id": 2, "method": "_kiro/account/getUsage", "params": map[string]any{}}); err != nil {
		return nil, err
	}
	return wait(2)
}

// kiroReason: a sign-in or version problem in plain words, else the message as given.
func kiroReason(msg string) string {
	m := strings.ToLower(msg)
	switch {
	case strings.Contains(m, "sign in") || strings.Contains(m, "not authenticated") || strings.Contains(m, "login"):
		return "Kiro CLI is signed out (kiro-cli login)"
	case strings.Contains(m, "method not found") || strings.Contains(m, "unsupported") || strings.Contains(m, "agent-engine"):
		return "Kiro CLI is too old for its usage call; update it"
	}
	return msg
}

type kiroResult struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Data    *struct {
		PlanName          string `json:"planName"`
		BillingCycleReset string `json:"billingCycleReset"` // yyyy-mm-dd
		UsageBreakdowns   []struct {
			ResourceType string   `json:"resourceType"`
			DisplayName  string   `json:"displayName"`
			Used         *float64 `json:"used"`
			Limit        *float64 `json:"limit"`
			Percentage   *float64 `json:"percentage"`
			HasLimit     *bool    `json:"hasLimit"`
		} `json:"usageBreakdowns"`
	} `json:"data"`
}

func parseKiro(raw json.RawMessage, now time.Time) codexbarEntry {
	e := codexbarEntry{ErrorCode: "schema_changed", Status: "error", ObservedAt: now.UTC()}
	var r kiroResult
	if json.Unmarshal(raw, &r) != nil {
		e.ErrorCode = "parse_error"
		e.Error = "unreadable reply"
		return e
	}
	if !r.Success || r.Data == nil {
		e.Error = "no usage"
		e.ErrorCode = "schema_changed"
		if r.Message != "" {
			e.Error = kiroReason(r.Message)
			e.ErrorCode = kiroMessageCode(r.Message)
		}
		return e
	}
	var reset *time.Time
	if t, err := time.Parse("2006-01-02", strings.TrimSpace(r.Data.BillingCycleReset)); err == nil {
		reset = &t
	}
	for _, b := range r.Data.UsageBreakdowns {
		if b.HasLimit != nil && !*b.HasLimit || b.Limit == nil || !finiteF(*b.Limit) || *b.Limit <= 0 {
			continue // no bounded pool: no share to show
		}
		var used float64
		switch {
		case b.Used != nil && finiteF(*b.Used):
			used = *b.Used
		case b.Percentage != nil && finiteF(*b.Percentage):
			used = *b.Percentage / 100 * *b.Limit
		default:
			continue
		}
		pct := math.Round(math.Max(0, math.Min(1, used / *b.Limit))*1000) / 10
		name := label(b.DisplayName)
		if name == "" {
			name = label(b.ResourceType)
		}
		e.Windows = append(e.Windows, Window{Kind: "monthly", Limit: name, UsedPercent: &pct, ResetsAt: reset, ResetMode: "fixed", ObservedAt: now.UTC()})
	}
	if len(e.Windows) == 0 {
		e.Error = "no limits reported"
		return e
	}
	e.Plan = label(r.Data.PlanName)
	e.Status = "ok"
	e.ErrorCode = ""
	return e
}

func finiteF(v float64) bool { return !math.IsNaN(v) && !math.IsInf(v, 0) }

func kiroMessageCode(message string) string {
	switch kiroReason(message) {
	case "Kiro CLI is signed out (kiro-cli login)":
		return "unsupported_login"
	case "Kiro CLI is too old for its usage call; update it":
		return "schema_changed"
	default:
		return "other"
	}
}
