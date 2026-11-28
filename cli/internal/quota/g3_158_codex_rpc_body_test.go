// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// G3-158 follow-up: on the owner's Mac every Codex account read since 01:14Z failed with
// rpc_error. Codex's app-server fails account/rateLimits/read when its own client cannot decode
// the usage response (a plan or field it does not know yet), but the error message still carries
// the response body ("...; body={...}"). CodexBar (a26ca57b5, UsageFetcher.swift
// recoverUsageFromRPCError) reads the windows and credits from that body; so does this reader.

// rpcErrorCodex answers account/rateLimits/read with a JSON-RPC error whose message is message.
func rpcErrorCodex(t *testing.T, message string) string {
	t.Helper()
	errLine, err := json.Marshal(map[string]any{"id": 2, "error": map[string]any{"code": -32603, "message": message}})
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	payload := filepath.Join(dir, "error.json")
	if err := os.WriteFile(payload, append(errLine, '\n'), 0o600); err != nil {
		t.Fatal(err)
	}
	bin := filepath.Join(dir, "codex")
	script := `#!/bin/sh
[ "$1" = app-server ] || exit 2
while IFS= read -r line; do
  case "$line" in
    *'"id":1,'*) echo '{"id":1,"result":{"userAgent":"x"}}' ;;
    *'"method":"account/read"'*) echo '{"id":3,"result":{"account":{"type":"chatgpt","email":"someone@example.com","planType":"pro"}}}' ;;
    *'"method":"account/rateLimits/read"'*) cat '` + payload + `' ;;
  esac
done
`
	if err := os.WriteFile(bin, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return bin
}

func g3158DecodeErrorMessage(body string) string {
	return "failed to fetch codex rate limits: Decode error for https://chatgpt.com/backend-api/wham/usage: " +
		"unknown variant `prolite`, expected one of `guest`, `free`, `go`, `plus`, `pro`; content-type=application/json; body=" + body
}

func TestG3158RateLimitDecodeErrorBodyIsAReading(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	weeklyReset := acctNow.Add(25 * time.Hour).Unix()
	body := `{"user_id":"user-secret","account_id":"account-secret","email":"someone@example.com","plan_type":"prolite",
 "rate_limit":{"allowed":false,"limit_reached":true,
  "primary_window":{"used_percent":40,"limit_window_seconds":18000,"reset_after_seconds":3600,"reset_at":` + g3158Int(acctNow.Add(time.Hour).Unix()) + `},
  "secondary_window":{"used_percent":100,"limit_window_seconds":604800,"reset_after_seconds":90000,"reset_at":` + g3158Int(weeklyReset) + `}},
 "credits":{"has_credits":true,"unlimited":false,"balance":"2021"}}`
	if err := RefreshCodexAccount(context.Background(), cache, rpcErrorCodex(t, g3158DecodeErrorMessage(body)), acctNow); err != nil {
		t.Fatalf("a used-up week reported by the error body failed the read: %v", err)
	}
	s := loadAccount(cache)
	if s == nil || s.Status != "ok" || s.Plan != "prolite" || len(s.Windows) != 2 {
		t.Fatalf("snapshot %+v", s)
	}
	for _, w := range s.Windows {
		switch w.WindowMinutes {
		case 300:
			if *w.UsedPercent != 40 || w.Kind != "five_hour" {
				t.Fatalf("5h window %+v", w)
			}
		case 10080:
			if *w.UsedPercent != 100 || w.Kind != "weekly" || w.ResetsAt == nil || w.ResetsAt.Unix() != weeklyReset {
				t.Fatalf("weekly window %+v", w)
			}
		default:
			t.Fatalf("window %+v", w)
		}
	}
	if s.Usage == nil || s.Usage.Balance == nil || *s.Usage.Balance != 2021 {
		t.Fatalf("credits %+v", s.Usage)
	}
	// Nothing of the provider's text or identifiers is stored.
	raw, _ := os.ReadFile(accountPath(cache))
	for _, secret := range []string{"someone@example.com", "user-secret", "account-secret", "Decode error", "wham"} {
		if strings.Contains(string(raw), secret) {
			t.Fatalf("stored %q: %s", secret, raw)
		}
	}
	r := Report{}
	applyAccount(&r, cache, acctNow.Add(time.Minute))
	if len(r.Accounts) != 1 || r.Accounts[0].Via != "codex-account" {
		t.Fatalf("accounts %+v", r.Accounts)
	}
}

// An error without a usable body stays an error; a malformed 5h window gives no reading (as in
// CodexBar: a partial body never stands in for the session window). Owner bad case 2026-11-28:
// the error names its class: a server error, or a Codex CLI too old to decode the plan.
func TestG3158RateLimitErrorWithoutAUsableBodyStaysAnError(t *testing.T) {
	for name, c := range map[string]struct{ message, want string }{
		"no_body":    {"failed to fetch codex rate limits: request failed: 500", "http_5xx"},
		"no_windows": {g3158DecodeErrorMessage(`{"plan_type":"prolite","rate_limit":{"allowed":true}}`), "schema_changed"},
		"bad_primary": {g3158DecodeErrorMessage(`{"plan_type":"prolite","rate_limit":{"primary_window":{"used_percent":"oops","limit_window_seconds":18000,"reset_at":1},
 "secondary_window":{"used_percent":19,"limit_window_seconds":604800,"reset_at":1792649570}}}`), "schema_changed"},
		"truncated": {g3158DecodeErrorMessage(`{"plan_type":"prolite","rate_limit":{"primary_window":{"used_percent":4`), "schema_changed"},
	} {
		message := c.message
		t.Run(name, func(t *testing.T) {
			isolateHome(t)
			cache := t.TempDir()
			if err := RefreshCodexAccount(context.Background(), cache, rpcErrorCodex(t, message), acctNow); err == nil {
				t.Fatal("an unusable error body counted as a reading")
			}
			if s := loadAccount(cache); s == nil || s.Status == "ok" || s.ErrorCode != c.want {
				t.Fatalf("snapshot %+v, want %s", s, c.want)
			}
		})
	}
}

func TestG3158UnrepresentableResetKeepsLastGoodAndAllowsLaterRefresh(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	ctx := context.Background()
	read := func(body string, at time.Time) error {
		return RefreshCodexAccount(ctx, cache, rpcErrorCodex(t, g3158DecodeErrorMessage(body)), at)
	}
	body := func(percent, reset string) string {
		return `{"rate_limit":{"primary_window":{"used_percent":` + percent +
			`,"limit_window_seconds":18000,` + reset + `}}}`
	}
	if err := read(body("30", `"reset_after_seconds":3600`), acctNow); err != nil {
		t.Fatalf("seed: %v", err)
	}
	now := acctNow.Add(AccountEvery)
	// A decode error whose body cannot be used names an outdated Codex CLI (owner bad case 2026-11-28).
	if err := read(body("99", `"reset_at":253402300800`), now); errorCode(err) != "schema_changed" {
		t.Fatalf("malformed reset error = %q", errorCode(err))
	}
	failed := loadAccount(cache)
	if failed == nil || failed.ErrorCode != "schema_changed" || failed.Good == nil ||
		len(failed.Good.Windows) < 1 || failed.Good.Windows[0].UsedPercent == nil ||
		*failed.Good.Windows[0].UsedPercent != 30 {
		t.Fatal("malformed reset did not preserve the last good reading")
	}
	if err := save(cache, &accountSnap{ObservedAt: time.Unix(253402300800, 0).UTC()}); errorCode(err) != "parse_error" {
		t.Fatalf("unserializable snapshot error = %q", errorCode(err))
	}
	if kept := loadAccount(cache); kept == nil || kept.Good == nil || !kept.Good.ObservedAt.Equal(acctNow) {
		t.Fatal("serialization failure replaced the readable snapshot")
	}
	next, err := codexRefreshNext(cache)
	if err != nil || !next.After(now) {
		t.Fatalf("ordinary retry budget unavailable: %v", err)
	}
	if err := read(body("50", `"reset_after_seconds":3600`), next); err != nil {
		t.Fatalf("later refresh: %v", err)
	}
	if got := loadAccount(cache); got == nil || got.Status != "ok" ||
		len(got.Windows) < 1 || got.Windows[0].UsedPercent == nil || *got.Windows[0].UsedPercent != 50 {
		t.Fatal("valid retry did not replace the retained reading")
	}
}

func g3158Int(v int64) string { b, _ := json.Marshal(v); return string(b) }
