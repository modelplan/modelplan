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

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Owner bad case 2026-11-28: the Codex card said "Codex 后台服务出错" for three hours. Every
// JSON-RPC error from Codex's app-server was one code, rpc_error, so an expired login, a backend
// outage and a Codex CLI too old to decode the plan all read "it retries on its own". The message
// is now classified in memory into a fixed code (CodexBar a26ca57b5,
// Sources/CodexBar/Providers/Codex/CodexConsumerProjection.swift:130-156 and
// Tests/CodexBarTests/CodexUserFacingErrorTests.swift:41-75); its text is never kept.

func TestCodexRPCErrorNamesItsClass(t *testing.T) {
	cases := map[string]struct{ message, want string }{
		"not signed in": {"codex account authentication required to read rate limits", "not_signed_in"},
		"token expired": {"failed to fetch codex rate limits: GET https://chatgpt.com/backend-api/wham/usage failed: 401 Unauthorized; " +
			`content-type=text/plain; body={"error":{"message":"Provided authentication token is expired. Please try signing in again.","code":"token_expired"}}`, "login_expired"},
		"bare 401":       {"failed to fetch codex rate limits: GET https://chatgpt.com/backend-api/wham/usage failed: 401", "login_expired"},
		"server error":   {"failed to fetch codex rate limits: GET https://chatgpt.com/backend-api/wham/usage failed: 500", "http_5xx"},
		"gateway body":   {`failed to fetch codex rate limits: GET https://chatgpt.com/backend-api/wham/usage failed: 503 Service Unavailable; body={"detail":"x"}`, "http_5xx"},
		"request failed": {"failed to fetch codex rate limits: request failed: 502", "http_5xx"},
		"rate limited":   {"failed to fetch codex rate limits: GET https://chatgpt.com/backend-api/wham/usage failed: 429 Too Many Requests", "http_429"},
		"outdated cli":   {g3158DecodeErrorMessage(`{"plan_type":"prolite","rate_limit":{"allowed":true}}`), "schema_changed"},
		"other":          {"something went wrong", "rpc_error"},
		// A number inside the quoted body is not the HTTP status.
		"status only in body": {`failed to fetch codex rate limits: oops; body={"error":"failed: 500"}`, "rpc_error"},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			isolateHome(t)
			cache := t.TempDir()
			if err := RefreshCodexAccount(context.Background(), cache, rpcErrorCodex(t, c.message), acctNow); err == nil || errorCode(err) != c.want {
				t.Fatalf("returned %v (%s), want %s", err, errorCode(err), c.want)
			}
			s := loadAccount(cache)
			if s == nil || s.Status == "ok" || s.ErrorCode != c.want || s.Error != c.want {
				t.Fatalf("snapshot %+v, want %s", s, c.want)
			}
			b, _ := os.ReadFile(accountPath(cache))
			for _, text := range []string{"Unauthorized", "token_expired", "wham", "prolite", "went wrong", "Service Unavailable"} {
				if strings.Contains(string(b), text) {
					t.Fatalf("snapshot keeps provider text %q", text)
				}
			}
		})
	}
}

// F2: a failure that clears on its own (backend outage, a lost pipe, a timeout) is retried after
// 5, 10, 20, then 30 minutes; a login failure keeps the half-hour wait.
func TestCodexTransientFailuresBackOffFromFiveMinutes(t *testing.T) {
	for _, c := range []struct {
		name, message string
		waits         []time.Duration
	}{
		{"outage", "failed to fetch codex rate limits: request failed: 500", []time.Duration{5 * time.Minute, 10 * time.Minute, 20 * time.Minute, 30 * time.Minute, 30 * time.Minute}},
		{"unclassified", "something went wrong", []time.Duration{5 * time.Minute, 10 * time.Minute, 20 * time.Minute, 30 * time.Minute}},
		{"login", "codex account authentication required to read rate limits", []time.Duration{30 * time.Minute, 30 * time.Minute}},
		{"outdated cli", g3158DecodeErrorMessage(`{"plan_type":"prolite","rate_limit":{"allowed":true}}`), []time.Duration{30 * time.Minute, 30 * time.Minute}},
	} {
		t.Run(c.name, func(t *testing.T) {
			isolateHome(t)
			cache := t.TempDir()
			goodAccount(t, cache, acctNow.Add(-time.Hour))
			bin := rpcErrorCodex(t, c.message)
			now := acctNow
			for i, want := range c.waits {
				_ = RefreshCodexAccount(context.Background(), cache, bin, now)
				if s := loadAccount(cache); s == nil || s.Status == "ok" || !s.ObservedAt.Equal(now) {
					t.Fatalf("failure %d not recorded: %+v", i+1, s)
				}
				if AccountDue(cache, now.Add(want-time.Second)) || !AccountDue(cache, now.Add(want)) {
					next, _ := codexRefreshNext(cache)
					t.Fatalf("failure %d: next read in %s, want %s", i+1, next.Sub(now), want)
				}
				if got := CodexFailureWait(cache); got != want {
					t.Fatalf("failure %d: scheduler wait %s, want %s", i+1, got, want)
				}
				now = now.Add(want)
			}
		})
	}
}

// F2: an explicit refresh may ask again one minute after a transient failure; a login failure
// keeps its wait, and a refresh inside the minute is still too soon.
func TestCodexManualRefreshAfterATransientFailure(t *testing.T) {
	for _, c := range []struct {
		name, message string
		allowed       bool
	}{
		{"outage", "failed to fetch codex rate limits: request failed: 500", true},
		{"login", "codex account authentication required to read rate limits", false},
	} {
		t.Run(c.name, func(t *testing.T) {
			isolateHome(t)
			cache := t.TempDir()
			goodAccount(t, cache, acctNow.Add(-time.Hour))
			_ = RefreshCodexAccount(context.Background(), cache, rpcErrorCodex(t, c.message), acctNow)
			good, _ := fakeCodex(t, acctResponse)
			if r := RefreshAccountNow(context.Background(), cache, good, acctNow.Add(30*time.Second)); r.Status != "too_soon" {
				t.Fatalf("inside the minute: %+v", r)
			}
			// The scheduler's own reads never take the manual shortcut.
			if err := RefreshCodexAccount(context.Background(), cache, good, acctNow.Add(time.Minute)); err != nil {
				t.Fatal(err)
			}
			if s := loadAccount(cache); s.Status == "ok" {
				t.Fatal("an automatic read ignored the back-off")
			}
			if _, ok := CodexManualNext(cache, acctNow.Add(time.Minute)); ok != c.allowed {
				t.Fatalf("member refresh due after a minute = %t, want %t", ok, c.allowed)
			}
			r := RefreshAccountNow(context.Background(), cache, good, acctNow.Add(time.Minute))
			if c.allowed && r.Status != "refreshed" || !c.allowed && r.Status != "too_soon" {
				t.Fatalf("after a minute: %+v", r)
			}
		})
	}
}

// A member refresh in the app plans with the manual shortcut: due one minute after a transient
// failure, not before.
func TestCodexManualNextIsDueOneMinuteAfterATransientFailure(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	goodAccount(t, cache, acctNow.Add(-time.Hour))
	_ = RefreshCodexAccount(context.Background(), cache, rpcErrorCodex(t, "failed to fetch codex rate limits: request failed: 500"), acctNow)
	if at, ok := CodexManualNext(cache, acctNow.Add(time.Minute)); !ok || !at.Equal(acctNow.Add(time.Minute)) {
		t.Fatalf("manual next = %s %t", at, ok)
	}
	if _, ok := CodexManualNext(cache, acctNow.Add(59*time.Second)); ok {
		t.Fatal("due inside the minute")
	}
}

// Owner bad case 2026-11-28: Codex usage credits are credits, so the card names them once
// ("Credits 1,865") instead of repeating its own "Reserve" label.
func TestCodexUsageCreditsCarryTheCreditsUnit(t *testing.T) {
	var resp rlResponse
	body := `{"rateLimitsByLimitId":{"codex":{"limitId":"codex","planType":"pro",
	 "secondary":{"usedPercent":31,"windowDurationMins":10080,"resetsAt":1792649570},
	 "credits":{"hasCredits":true,"unlimited":false,"balance":"1865"}}}}`
	if err := json.Unmarshal([]byte(body), &resp); err != nil {
		t.Fatal(err)
	}
	s := snapFrom(&resp, acctNow)
	if s.Usage == nil || s.Usage.Balance == nil || *s.Usage.Balance != 1865 || s.Usage.Unit != "credits" {
		t.Fatalf("usage credits %+v", s.Usage)
	}
}

// F4 (owner diagnostics 2026-11-28): an old npm Codex CLI first on PATH hid a newer Homebrew one.
// Every runnable codex is a candidate; the newest `codex --version` wins, each binary is asked at
// most once a minute while unchanged.
func TestCodexBinPicksTheNewestInstalledCLI(t *testing.T) {
	isolateHome(t)
	home := t.TempDir()
	calls := filepath.Join(t.TempDir(), "calls")
	write := func(dir, version string) string {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			t.Fatal(err)
		}
		bin := filepath.Join(dir, "codex")
		script := "#!/bin/sh\necho \"$0\" >> '" + calls + "'\n[ \"$1\" = --version ] && echo 'codex-cli " + version + "'\n"
		if err := os.WriteFile(bin, []byte(script), 0o755); err != nil {
			t.Fatal(err)
		}
		return bin
	}
	old := write(filepath.Join(home, ".nvm", "versions", "node", "v22.21.1", "bin"), "0.146.0")
	newer := write(filepath.Join(home, ".local", "bin"), "0.161.2")
	pre := write(filepath.Join(t.TempDir(), "pre"), "0.161.2-alpha.3")
	t.Setenv("PATH", filepath.Dir(old)+string(os.PathListSeparator)+filepath.Dir(pre))
	t.Setenv("MODELPLAN_CODEX", "")
	t.Setenv("CODEX_CLI_PATH", "")
	resetCodexVersions(t)
	now := acctNow
	codexClock = func() time.Time { return now }
	if got := CodexBin(home); got != newer {
		t.Fatalf("picked %s, want the newest %s", got, newer)
	}
	if v := codexMemoLoad("").versionAt(newer, now); v != "0.161.2" {
		t.Fatalf("version %q", v)
	}
	asked := func() int { b, _ := os.ReadFile(calls); return strings.Count(string(b), "\n") }
	first := asked()
	if first != 3 {
		t.Fatalf("asked %d binaries for their version, want 3", first)
	}
	_ = CodexBin(home)
	if asked() != first {
		t.Fatal("an unchanged binary was asked again")
	}
	// An upgraded binary (new mtime) is asked again, but not within the minute.
	_ = write(filepath.Dir(old), "0.170.0")
	future := now.Add(2 * time.Second)
	_ = os.Chtimes(old, future, future)
	if got := CodexBin(home); got != newer || asked() != first {
		t.Fatalf("re-asked inside the minute: %s %d", got, asked())
	}
	now = now.Add(time.Minute)
	if got := CodexBin(home); got != old {
		t.Fatalf("after the upgrade picked %s, want %s", got, old)
	}
	// The explicit override always wins and is not compared.
	t.Setenv("MODELPLAN_CODEX", pre)
	if got := CodexBin(home); got != pre {
		t.Fatalf("override ignored: %s", got)
	}
}

// When no candidate answers --version the lookup order decides, as before.
func TestCodexBinWithoutVersionsKeepsTheLookupOrder(t *testing.T) {
	isolateHome(t)
	home := t.TempDir()
	first, second := filepath.Join(t.TempDir(), "codex"), filepath.Join(home, ".local", "bin", "codex")
	_ = os.MkdirAll(filepath.Dir(second), 0o700)
	for _, p := range []string{first, second} {
		if err := os.WriteFile(p, []byte("#!/bin/sh\nexit 3\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", filepath.Dir(first))
	t.Setenv("MODELPLAN_CODEX", "")
	t.Setenv("CODEX_CLI_PATH", "")
	resetCodexVersions(t)
	if got := CodexBin(home); got != first {
		t.Fatalf("picked %s, want the first on PATH", got)
	}
}

// Review macrevb-1316-1: the reading records only where the CLI came from and its version. A
// folder whose name is an account identifier reaches neither the caches nor the doctor row.
func TestCodexReadingRecordsTheCLIForDoctor(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	const identifier = "acct-SYNTH-77810"
	target := filepath.Join(home, identifier, "bin", "codex")
	codexStub(t, target, "0.161.2", codexInitOK, codexRateOK, "")
	t.Setenv("PATH", filepath.Dir(target))
	t.Setenv("MODELPLAN_CODEX", "")
	t.Setenv("CODEX_CLI_PATH", "")
	resetCodexVersions(t)
	cache := t.TempDir()
	if err := RefreshCodexAccountDiscover(context.Background(), cache, home, acctNow); err != nil {
		t.Fatal(err)
	}
	s := loadAccount(cache)
	if s.CLI == nil || s.CLI.Version != "0.161.2" || s.CLI.Source != "path" {
		t.Fatalf("cli %+v", s.CLI)
	}
	_ = filepath.WalkDir(cache, func(p string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() && (strings.Contains(string(mustRead(t, p)), identifier) || strings.Contains(string(mustRead(t, p)), home)) {
			t.Fatalf("%s keeps the identifier or the home folder", filepath.Base(p))
		}
		return nil
	})
	state, _ := consent.Current()
	row := codexDiagnostic(Paths{Cache: cache}, state, true, acctNow.Add(time.Minute))
	out, _ := json.Marshal(row)
	if row.CodexCLI != "path 0.161.2" || strings.Contains(string(out), identifier) || strings.Contains(string(out), home) {
		t.Fatalf("doctor row %s", out)
	}
}

func mustRead(t *testing.T, p string) []byte {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func resetCodexVersions(t *testing.T) {
	t.Helper()
	codexMemory.Lock()
	codexMemory.memo = nil
	codexMemory.Unlock()
	clock, dirs, apps := codexClock, codexSearchDirs, codexAppPaths
	// No desktop app of the machine running the tests takes part.
	codexAppPaths = func(string) []string { return nil }
	// Only the test's home folders: a codex installed on the machine running the tests stays out.
	codexSearchDirs = func(home string) []string {
		var out []string
		for _, d := range dirs(home) {
			if strings.HasPrefix(d, home+string(filepath.Separator)) {
				out = append(out, d)
			}
		}
		return out
	}
	t.Cleanup(func() { codexClock, codexSearchDirs, codexAppPaths = clock, dirs, apps })
}

// doctor prints only a source word and a version from the cached note; anything else is dropped.
func TestCodexCLIDiagnosticRejectsAnythingButASourceAndVersion(t *testing.T) {
	for _, c := range []struct {
		cli  *codexCLI
		want string
	}{
		{&codexCLI{Source: "npm", Version: "0.146.0"}, "npm 0.146.0"},
		{&codexCLI{Source: "homebrew", Version: "0.144.1"}, "homebrew 0.144.1"},
		{&codexCLI{Source: "app", Version: "0.171.0-alpha.13.2"}, "app 0.171.0-alpha.13.2"},
		{&codexCLI{Source: "path"}, "path"},
		{&codexCLI{Source: "override", Version: "1.2.3"}, "override 1.2.3"},
		{&codexCLI{Source: "surprise"}, ""},
		{&codexCLI{Source: "npm", Version: "Bearer synthetic"}, ""},
		{&codexCLI{Source: "~/acct-SYNTH-77810/bin/codex"}, ""},
		{&codexCLI{}, ""},
		{nil, ""},
	} {
		if got := codexCLIDiagnostic(c.cli); got != c.want {
			t.Fatalf("%+v: %q, want %q", c.cli, got, c.want)
		}
	}
}

// Owner decision D487 (2026-11-28): an explicit path first, then the CLI the desktop app carries,
// then the newest installed copy. The owner's Mac: npm 0.146.0 first on PATH, Homebrew 0.144.1,
// and the ChatGPT app's 0.171.0-alpha.13.2.
func TestCodexBinPrefersTheDesktopAppCLI(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir() // the bundle exception is for the real home folder's Applications
	write := func(p, version string) string {
		if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
			t.Fatal(err)
		}
		answer := ""
		if version != "" {
			answer = "[ \"$1\" = --version ] && echo 'codex-cli " + version + "'\n"
		}
		if err := os.WriteFile(p, []byte("#!/bin/sh\n"+answer+"exit 0\n"), 0o755); err != nil {
			t.Fatal(err)
		}
		return p
	}
	npm := write(filepath.Join(home, ".nvm", "versions", "node", "v22.21.1", "bin", "codex"), "0.146.0")
	brew := write(filepath.Join(t.TempDir(), "homebrew", "bin", "codex"), "0.144.1")
	t.Setenv("PATH", filepath.Dir(npm)+string(os.PathListSeparator)+filepath.Dir(brew))
	t.Setenv("MODELPLAN_CODEX", "")
	t.Setenv("CODEX_CLI_PATH", "")
	resetCodexVersions(t)
	apps := filepath.Join(home, "Applications")
	codexAppPaths = func(string) []string {
		return []string{filepath.Join(apps, "ChatGPT.app", "Contents", "Resources", "codex"), filepath.Join(apps, "ChatGPT.app", "Contents", "Resources", "codex-cli", "bin", "codex"), filepath.Join(apps, "Codex.app", "Contents", "Resources", "codex")}
	}
	// No app: the newest installed copy.
	if p, source := codexChoice(codexMemoLoad(""), home); p != npm || source != "npm" {
		t.Fatalf("without an app: %s (%s)", p, source)
	}
	// An app CLI that does not answer --version is skipped; the next app place that does is used,
	// even though its version is not compared with the PATH copies.
	write(filepath.Join(apps, "ChatGPT.app", "Contents", "Resources", "codex"), "")
	bundled := write(filepath.Join(apps, "ChatGPT.app", "Contents", "Resources", "codex-cli", "bin", "codex"), "0.171.0-alpha.13.2")
	resetCodexVersions(t)
	codexAppPaths = func(string) []string {
		return []string{filepath.Join(apps, "ChatGPT.app", "Contents", "Resources", "codex"), bundled, filepath.Join(apps, "Codex.app", "Contents", "Resources", "codex")}
	}
	if p, source := codexChoice(codexMemoLoad(""), home); p != bundled || source != "app" {
		t.Fatalf("with the app: %s (%s)", p, source)
	}
	if got := CodexBin(home); got != bundled {
		t.Fatalf("CodexBin = %s", got)
	}
	// An explicit path wins: CodexBar's CODEX_CLI_PATH as well as MODELPLAN_CODEX.
	t.Setenv("CODEX_CLI_PATH", brew)
	if p, source := codexChoice(codexMemoLoad(""), home); p != brew || source != "override" {
		t.Fatalf("CODEX_CLI_PATH: %s (%s)", p, source)
	}
	t.Setenv("MODELPLAN_CODEX", npm)
	if p, _ := codexChoice(codexMemoLoad(""), home); p != npm {
		t.Fatalf("MODELPLAN_CODEX: %s", p)
	}
}

func TestCodexSourceNamesWhereACopyCameFrom(t *testing.T) {
	home, _ := os.UserHomeDir()
	for p, want := range map[string]string{
		filepath.Join(home, ".nvm", "versions", "node", "v22.21.1", "bin", "codex"): "npm",
		"/opt/homebrew/bin/codex":                                                          "homebrew",
		"/Applications/ChatGPT.app/Contents/Resources/codex":                               "app",
		filepath.Join(home, "Applications", "Codex.app", "Contents", "Resources", "codex"): "app",
		"/somewhere/else/codex":                                                            "path",
		"":                                                                                 "",
	} {
		if got := codexSource(p); got != want {
			t.Fatalf("codexSource(%s) = %q, want %q", p, got, want)
		}
	}
}

const (
	codexInitOK = `{"id":1,"result":{"userAgent":"x"}}`
	codexRateOK = "" // the account reading in acctResponse
)

// codexStub writes a fake codex at p that logs each start ("<$1>") to calls, answers --version
// with version (none when empty), initialize with initReply and the rate-limit read with
// rateReply (acctResponse when empty).
func codexStub(t *testing.T, p, version, initReply, rateReply, calls string) string {
	t.Helper()
	if rateReply == "" {
		rateReply = `{"id":2,"result":` + strings.ReplaceAll(acctResponse, "\n", "") + `}`
	}
	if calls == "" {
		calls = filepath.Join(t.TempDir(), "calls")
	}
	answer := "exit 0"
	if version != "" {
		answer = "echo 'codex-cli " + version + "'; exit 0"
	}
	script := "#!/bin/sh\necho \"<$1>\" >> '" + calls + "'\n[ \"$1\" = --version ] && { " + answer + "; }\n[ \"$1\" = app-server ] || exit 2\n" +
		"while IFS= read -r line; do\n  case \"$line\" in\n" +
		"    *'\"id\":1,'*) echo '" + initReply + "' ;;\n" +
		"    *'\"method\":\"account/rateLimits/read\"'*) echo '" + rateReply + "' ;;\n" +
		"    *'\"method\":\"account/read\"'*) echo '{\"id\":3,\"result\":{\"account\":null}}' ;;\n" +
		"    *'\"method\":\"model/list\"'*) echo \"$line\" | sed -n 's/.*\"id\":\\([0-9]*\\).*/{\"id\":\\1,\"result\":{\"data\":[],\"nextCursor\":null}}/p' ;;\n" +
		"  esac\ndone\n"
	if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return p
}

func countCalls(t *testing.T, calls, what string) int {
	t.Helper()
	b, _ := os.ReadFile(calls)
	return strings.Count(string(b), "<"+what+">")
}

// D487 addendum and review macrevb-1316-2: only a protocol failure of the desktop app's CLI (an
// unknown method or params, an answer it cannot decode) tries the next binary, once, in the same
// read. A provider outage or a sign-in failure, even at initialize, is the account's: no other CLI
// starts and the outage is recorded.
func TestCodexProtocolFailureOfTheAppCLIFallsBackOnce(t *testing.T) {
	incompatible := `{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":"lots"}}}}`
	for _, c := range []struct {
		name, init, rate string
		fallback         bool
		code             string
	}{
		{"unknown method at initialize", `{"id":1,"error":{"code":-32601,"message":"Method not found"}}`, "", true, ""},
		{"invalid params at initialize", `{"id":1,"error":{"code":-32602,"message":"invalid params"}}`, "", true, ""},
		{"incompatible rate-limit result", codexInitOK, incompatible, true, ""},
		{"undecodable answer", codexInitOK, `{"id":2,"error":{"code":-32603,"message":"failed to fetch codex rate limits: Decode error: unknown variant` + "`x`" + `"}}`, true, ""},
		{"outage at initialize", `{"id":1,"error":{"code":-32603,"message":"failed: 503 Service Unavailable"}}`, "", false, "http_5xx"},
		{"sign-in at initialize", `{"id":1,"error":{"code":-32603,"message":"codex account authentication required to read rate limits"}}`, "", false, "not_signed_in"},
		{"outage at the read", codexInitOK, `{"id":2,"error":{"code":-32603,"message":"failed to fetch codex rate limits: request failed: 500"}}`, false, "http_5xx"},
		{"other error at initialize", `{"id":1,"error":{"code":-32600,"message":"unsupported client"}}`, "", false, "rpc_error"},
	} {
		t.Run(c.name, func(t *testing.T) {
			isolateHome(t)
			home, _ := os.UserHomeDir()
			calls := filepath.Join(t.TempDir(), "calls")
			npm := codexStub(t, filepath.Join(home, ".nvm", "versions", "node", "v22.21.1", "bin", "codex"), "0.146.0", codexInitOK, codexRateOK, calls+".npm")
			app := codexStub(t, filepath.Join(home, "Applications", "ChatGPT.app", "Contents", "Resources", "codex"), "0.171.0-alpha.13.2", c.init, c.rate, calls+".app")
			t.Setenv("PATH", filepath.Dir(npm))
			t.Setenv("MODELPLAN_CODEX", "")
			t.Setenv("CODEX_CLI_PATH", "")
			resetCodexVersions(t)
			codexAppPaths = func(string) []string { return []string{app} }
			cache := t.TempDir()
			if p, source := codexChoice(codexMemoLoad(cache), home); p != app || source != "app" {
				t.Fatalf("first choice %s (%s)", p, source)
			}
			err := RefreshCodexAccountDiscover(context.Background(), cache, home, acctNow)
			s := loadAccount(cache)
			if !c.fallback {
				if err == nil || s.Status == "ok" || s.ErrorCode != c.code || countCalls(t, calls+".npm", "app-server") != 0 {
					t.Fatalf("a %s moved to another CLI: %v %+v, npm app-server starts %d", c.code, err, s, countCalls(t, calls+".npm", "app-server"))
				}
				if p, _ := codexChoice(codexMemoLoad(cache), home); p != app {
					t.Fatalf("a %s pinned another CLI: %s", c.code, p)
				}
				return
			}
			if err != nil || s.Status != "ok" || s.CLI == nil || s.CLI.Source != "npm" || s.CLI.Version != "0.146.0" || countCalls(t, calls+".npm", "app-server") != 1 {
				t.Fatalf("no single fallback read: %v %+v", err, s)
			}
			if p, _ := codexChoice(codexMemoLoad(cache), home); p != npm {
				t.Fatalf("working copy not kept: %s", p)
			}
		})
	}
}

// Review macrevb-1316-2: an incompatible answer with no other CLI to try is schema_changed.
func TestCodexIncompatibleResultWithoutAFallbackIsSchemaChanged(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	app := codexStub(t, filepath.Join(home, "Applications", "ChatGPT.app", "Contents", "Resources", "codex"), "0.171.0-alpha.13.2", codexInitOK,
		`{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":"lots"}}}}`, "")
	t.Setenv("PATH", filepath.Join(home, "nothing"))
	t.Setenv("MODELPLAN_CODEX", "")
	t.Setenv("CODEX_CLI_PATH", "")
	resetCodexVersions(t)
	codexAppPaths = func(string) []string { return []string{app} }
	cache := t.TempDir()
	_ = RefreshCodexAccountDiscover(context.Background(), cache, home, acctNow)
	if s := loadAccount(cache); s == nil || s.Status == "ok" || s.ErrorCode != "schema_changed" {
		t.Fatalf("snapshot %+v", s)
	}
}

// Review macrevb-1316-5: the versions and the working fallback outlive the CLI process. Two due
// reads in separate processes (the in-process memo cleared between them) share one cache: the second
// asks no --version and does not start the known-incompatible app CLI. A replaced app CLI is
// considered again on the next eligible read.
func TestCodexFallbackAndVersionsPersistAcrossProcesses(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	calls := filepath.Join(t.TempDir(), "calls")
	npm := codexStub(t, filepath.Join(home, ".nvm", "versions", "node", "v22.21.1", "bin", "codex"), "0.146.0", codexInitOK, codexRateOK, calls+".npm")
	appPath := filepath.Join(home, "Applications", "ChatGPT.app", "Contents", "Resources", "codex")
	app := codexStub(t, appPath, "0.171.0-alpha.13.2", `{"id":1,"error":{"code":-32601,"message":"Method not found"}}`, "", calls+".app")
	t.Setenv("PATH", filepath.Dir(npm))
	t.Setenv("MODELPLAN_CODEX", "")
	t.Setenv("CODEX_CLI_PATH", "")
	resetCodexVersions(t)
	codexAppPaths = func(string) []string { return []string{app} }
	cache := t.TempDir()
	now := acctNow
	codexClock = func() time.Time { return now }
	read := func() {
		t.Helper()
		codexMemory.Lock()
		codexMemory.memo = nil // a new process
		codexMemory.Unlock()
		if err := RefreshCodexAccountDiscover(context.Background(), cache, home, now); err != nil {
			t.Fatal(err)
		}
	}
	read()
	if a, n := countCalls(t, calls+".app", "--version")+countCalls(t, calls+".app", "app-server"), countCalls(t, calls+".npm", "--version")+countCalls(t, calls+".npm", "app-server"); a != 2 || n != 2 {
		t.Fatalf("first read: app starts %d, npm starts %d", a, n)
	}
	if info, err := os.Stat(codexMemoPath(cache)); err != nil || info.Mode().Perm() != 0o600 || strings.Contains(string(mustRead(t, codexMemoPath(cache))), home) {
		t.Fatalf("memo file %v %v", info, err)
	}
	now = now.Add(AccountEvery)
	read()
	if a, n := countCalls(t, calls+".app", "--version")+countCalls(t, calls+".app", "app-server"), countCalls(t, calls+".npm", "--version")+countCalls(t, calls+".npm", "app-server"); a != 2 || n != 3 {
		t.Fatalf("second read: app starts %d (want no new), npm starts %d (want one app-server)", a, n)
	}
	// The app CLI is replaced (a new build that works): the next eligible read considers it again.
	codexStub(t, appPath, "0.172.0", codexInitOK, codexRateOK, calls+".app")
	future := now.Add(time.Minute)
	_ = os.Chtimes(appPath, future, future)
	now = now.Add(AccountEvery)
	read()
	if s := loadAccount(cache); s.CLI == nil || s.CLI.Source != "app" || s.CLI.Version != "0.172.0" || countCalls(t, calls+".app", "app-server") != 2 {
		t.Fatalf("the replaced app CLI was not used: %+v", s.CLI)
	}
}

// Review macrevb-1316-3: discovery runs programs, so a read that is off, too soon or not
// permitted starts none (no --version either), at the CLI entry and the scheduler's entry.
func TestCodexDiscoveryStartsNothingUnlessTheReadGoesAhead(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	calls := filepath.Join(t.TempDir(), "calls")
	npm := codexStub(t, filepath.Join(home, ".nvm", "versions", "node", "v22.21.1", "bin", "codex"), "0.146.0", codexInitOK, codexRateOK, calls)
	t.Setenv("PATH", filepath.Dir(npm))
	t.Setenv("MODELPLAN_CODEX", "")
	t.Setenv("CODEX_CLI_PATH", "")
	resetCodexVersions(t)
	cache := t.TempDir()
	started := func() int { b, _ := os.ReadFile(calls); return strings.Count(string(b), "\n") }
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	if r := RefreshAccountNowDiscover(context.Background(), cache, home, acctNow); r.Status != "failed" || started() != 0 {
		t.Fatalf("off: %+v, %d starts", r, started())
	}
	if err := RefreshCodexAccountDiscover(context.Background(), cache, home, acctNow); err == nil || started() != 0 {
		t.Fatalf("off (scheduler entry): %v, %d starts", err, started())
	}
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "")
	if err := RefreshCodexAccountDiscover(context.Background(), cache, home, acctNow); err != nil || started() == 0 {
		t.Fatalf("a due read: %v, %d starts", err, started())
	}
	before := started()
	if r := RefreshAccountNowDiscover(context.Background(), cache, home, acctNow.Add(time.Minute)); r.Status != "too_soon" || started() != before {
		t.Fatalf("too soon: %+v, %d new starts", r, started()-before)
	}
	if err := RefreshCodexAccountDiscover(context.Background(), cache, home, acctNow.Add(time.Minute)); err != nil || started() != before {
		t.Fatalf("too soon (scheduler entry): %v, %d new starts", err, started()-before)
	}
}

// Review macrevb-1316-4: semantic-version precedence, numeric prerelease parts numerically.
func TestCodexVersionPrecedence(t *testing.T) {
	for _, c := range []struct{ newer, older string }{
		{"0.171.0-alpha.10", "0.171.0-alpha.9"},
		{"0.171.0", "0.171.0-alpha.10"},
		{"0.171.0-beta", "0.171.0-alpha.10"},
		{"0.171.0-alpha.1.1", "0.171.0-alpha.1"},
		{"0.171.0-alpha", "0.171.0-1"},
		{"0.172.0-alpha.1", "0.171.9"},
		{"1.10.0", "1.9.0"},
	} {
		if !codexNewer(c.newer, c.older) || codexNewer(c.older, c.newer) {
			t.Fatalf("%s should outrank %s", c.newer, c.older)
		}
	}
	if codexNewer("0.171.0-alpha.9", "0.171.0-alpha.9") {
		t.Fatal("equal versions")
	}
	// Discovery picks alpha.10 over alpha.9 in both PATH orders, and a release over either.
	isolateHome(t)
	home, _ := os.UserHomeDir()
	a9 := codexStub(t, filepath.Join(t.TempDir(), "a9", "codex"), "0.171.0-alpha.9", codexInitOK, codexRateOK, "")
	a10 := codexStub(t, filepath.Join(t.TempDir(), "a10", "codex"), "0.171.0-alpha.10", codexInitOK, codexRateOK, "")
	rel := codexStub(t, filepath.Join(t.TempDir(), "rel", "codex"), "0.171.0", codexInitOK, codexRateOK, "")
	t.Setenv("MODELPLAN_CODEX", "")
	t.Setenv("CODEX_CLI_PATH", "")
	for _, order := range [][]string{{a9, a10}, {a10, a9}} {
		resetCodexVersions(t)
		t.Setenv("PATH", filepath.Dir(order[0])+string(os.PathListSeparator)+filepath.Dir(order[1]))
		if got := CodexBin(home); got != a10 {
			t.Fatalf("PATH %v picked %s", order, got)
		}
	}
	resetCodexVersions(t)
	t.Setenv("PATH", strings.Join([]string{filepath.Dir(a10), filepath.Dir(rel), filepath.Dir(a9)}, string(os.PathListSeparator)))
	if got := CodexBin(home); got != rel {
		t.Fatalf("a release lost to a prerelease: %s", got)
	}
}

// An explicit path has no fallback: a protocol failure stays its own.
func TestCodexProtocolFailureOfAnExplicitCLITriesNothingElse(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	calls := filepath.Join(t.TempDir(), "calls")
	npm := codexStub(t, filepath.Join(home, ".nvm", "versions", "node", "v22.21.1", "bin", "codex"), "0.146.0", codexInitOK, codexRateOK, calls)
	t.Setenv("PATH", filepath.Dir(npm))
	resetCodexVersions(t)
	bin := codexStub(t, filepath.Join(t.TempDir(), "codex"), "", `{"id":1,"error":{"code":-32601,"message":"Method not found"}}`, "", "")
	t.Setenv("MODELPLAN_CODEX", bin)
	cache := t.TempDir()
	if err := RefreshCodexAccountDiscover(context.Background(), cache, home, acctNow); err == nil {
		t.Fatal("an explicit failing CLI read succeeded")
	}
	if s := loadAccount(cache); s == nil || s.Status == "ok" || s.CLI == nil || s.CLI.Source != "override" || countCalls(t, calls, "app-server") != 0 {
		t.Fatalf("snapshot %+v", s)
	}
}
