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
// most once a minute while unchanged, and an app-bundled copy is never run (#14).
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
	if v := codexVersionFor(newer); v != "0.161.2" {
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

// The reading records which CLI answered, as a home-relative or system path and a version only.
func TestCodexReadingRecordsTheCLIForDoctor(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	dir := filepath.Join(home, ".local", "bin")
	_ = os.MkdirAll(dir, 0o700)
	bin, _ := fakeCodex(t, acctResponse)
	b, _ := os.ReadFile(bin)
	target := filepath.Join(dir, "codex")
	script := strings.Replace(string(b), "[ \"$1\" = app-server ] || exit 2", "[ \"$1\" = --version ] && { echo 'codex-cli 0.161.2'; exit 0; }\n[ \"$1\" = app-server ] || exit 2", 1)
	if err := os.WriteFile(target, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	resetCodexVersions(t)
	cache := t.TempDir()
	if err := RefreshCodexAccount(context.Background(), cache, target, acctNow); err != nil {
		t.Fatal(err)
	}
	s := loadAccount(cache)
	if s.CLI == nil || s.CLI.Path != "~/.local/bin/codex" || s.CLI.Version != "0.161.2" || s.CLI.Source != "other" {
		t.Fatalf("cli %+v", s.CLI)
	}
	if strings.Contains(string(mustRead(t, accountPath(cache))), home) {
		t.Fatal("the home path reached the cache")
	}
	for _, c := range []struct{ path, want string }{
		{filepath.Join(home, ".nvm", "versions", "node", "v22.21.1", "bin", "codex"), "~/.nvm/versions/node/v22.21.1/bin/codex"},
		{"/opt/homebrew/bin/codex", "/opt/homebrew/bin/codex"},
		{"/Users/Someone Else/bin/codex", "other"},
		{filepath.Join(home, "odd dir", "codex"), "other"},
	} {
		if got := codexDisplayPath(c.path, home); got != c.want {
			t.Fatalf("display %s = %q, want %q", c.path, got, c.want)
		}
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
	codexVersions.Lock()
	codexVersions.m = map[string]codexVersionProbe{}
	codexVersions.Unlock()
	codexPin.Lock()
	codexPin.app, codexPin.appKey, codexPin.alt = "", "", ""
	codexPin.Unlock()
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

// doctor prints only a display path and a version from the cached note; anything else is dropped.
func TestCodexCLIDiagnosticRejectsAnythingButAPathAndVersion(t *testing.T) {
	for _, c := range []struct {
		cli  *codexCLI
		want string
	}{
		{&codexCLI{Source: "npm", Path: "~/.nvm/versions/node/v22.21.1/bin/codex", Version: "0.146.0"}, "npm ~/.nvm/versions/node/v22.21.1/bin/codex 0.146.0"},
		{&codexCLI{Source: "homebrew", Path: "/opt/homebrew/bin/codex", Version: "0.144.1"}, "homebrew /opt/homebrew/bin/codex 0.144.1"},
		{&codexCLI{Source: "app", Path: "/Applications/ChatGPT.app/Contents/Resources/codex", Version: "0.171.0-alpha.13.2"}, "app /Applications/ChatGPT.app/Contents/Resources/codex 0.171.0-alpha.13.2"},
		{&codexCLI{Path: "other"}, "other other"},
		{&codexCLI{Source: "surprise", Path: "~/bin/codex"}, ""},
		{&codexCLI{Source: "npm", Path: "/Users/Synthetic Person/bin/codex", Version: "1.0.0"}, ""},
		{&codexCLI{Source: "npm", Path: "/Users/synthetic/bin/codex", Version: "1.0.0"}, ""},
		{&codexCLI{Source: "npm", Path: "~/../../etc/codex"}, ""},
		{&codexCLI{Source: "npm", Path: "~/bin/codex", Version: "Bearer synthetic"}, ""},
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
	if p, source := codexChoice(home); p != npm || source != "npm" {
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
	if p, source := codexChoice(home); p != bundled || source != "app" {
		t.Fatalf("with the app: %s (%s)", p, source)
	}
	if got := CodexBin(home); got != bundled {
		t.Fatalf("CodexBin = %s", got)
	}
	// An explicit path wins: CodexBar's CODEX_CLI_PATH as well as MODELPLAN_CODEX.
	t.Setenv("CODEX_CLI_PATH", brew)
	if p, source := codexChoice(home); p != brew || source != "override" {
		t.Fatalf("CODEX_CLI_PATH: %s (%s)", p, source)
	}
	t.Setenv("MODELPLAN_CODEX", npm)
	if p, _ := codexChoice(home); p != npm {
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
		"/somewhere/else/codex":                                                            "other",
		"":                                                                                 "",
	} {
		if got := codexSource(p); got != want {
			t.Fatalf("codexSource(%s) = %q, want %q", p, got, want)
		}
	}
}

// D487 addendum: the desktop app's CLI can be an alpha. When it fails the protocol (initialize
// refused, an unknown method, a decode error) the next binary in the order is tried once in the same
// read, and the working one is kept until the app's CLI changes. A provider error (5xx) or a sign-in
// error is not a protocol failure and tries nothing else.
func TestCodexProtocolFailureOfTheAppCLIFallsBackOnce(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	good, _ := fakeCodex(t, acctResponse)
	goodScript := string(mustRead(t, good))
	withVersion := func(script, version string) string {
		return strings.Replace(script, "[ \"$1\" = app-server ] || exit 2", "[ \"$1\" = --version ] && { echo 'codex-cli "+version+"'; exit 0; }\n[ \"$1\" = app-server ] || exit 2", 1)
	}
	failing := func(version, reply string) string {
		calls := filepath.Join(t.TempDir(), "calls")
		return "#!/bin/sh\n[ \"$1\" = --version ] && { echo 'codex-cli " + version + "'; exit 0; }\n[ \"$1\" = app-server ] || exit 2\n" +
			"while IFS= read -r line; do\n  echo x >> '" + calls + "'\n  case \"$line\" in\n    *'\"id\":1,'*) echo '" + reply + "' ;;\n" +
			"    *'\"method\":\"account/rateLimits/read\"'*) echo '{\"id\":2,\"error\":{\"code\":-32603,\"message\":\"failed to fetch codex rate limits: request failed: 500\"}}' ;;\n  esac\ndone\n"
	}
	put := func(p, body string) string {
		if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
		return p
	}
	npm := put(filepath.Join(home, ".nvm", "versions", "node", "v22.21.1", "bin", "codex"), withVersion(goodScript, "0.146.0"))
	app := filepath.Join(home, "Applications", "ChatGPT.app", "Contents", "Resources", "codex")
	t.Setenv("PATH", filepath.Dir(npm))
	t.Setenv("MODELPLAN_CODEX", "")
	t.Setenv("CODEX_CLI_PATH", "")
	for _, c := range []struct {
		name, reply string
		fallback    bool
	}{
		{"initialize refused", `{"id":1,"error":{"code":-32600,"message":"unsupported client"}}`, true},
		{"unknown method", `{"id":1,"error":{"code":-32601,"message":"Method not found"}}`, true},
		{"provider outage", `{"id":1,"result":{"userAgent":"x"}}`, false},
	} {
		t.Run(c.name, func(t *testing.T) {
			resetCodexVersions(t)
			codexAppPaths = func(string) []string { return []string{app} }
			put(app, failing("0.171.0-alpha.13.2", c.reply))
			cache := t.TempDir()
			if p, source := codexChoice(home); p != app || source != "app" {
				t.Fatalf("first choice %s (%s)", p, source)
			}
			err := RefreshCodexAccount(context.Background(), cache, CodexBin(home), acctNow)
			s := loadAccount(cache)
			if !c.fallback {
				if err == nil || s.Status == "ok" || s.ErrorCode != "http_5xx" || CodexBin(home) != app {
					t.Fatalf("a provider error moved to another CLI: %v %+v", err, s)
				}
				return
			}
			if err != nil || s.Status != "ok" || s.CLI == nil || s.CLI.Source != "npm" || s.CLI.Version != "0.146.0" {
				t.Fatalf("no fallback read: %v %+v", err, s)
			}
			// Remembered while the app's CLI is unchanged.
			if p := CodexBin(home); p != npm {
				t.Fatalf("working copy not kept: %s", p)
			}
			// A new app CLI (new version, new file) is tried first again.
			put(app, failing("0.172.0", `{"id":1,"result":{"userAgent":"x"}}`))
			future := acctNow.Add(time.Hour)
			_ = os.Chtimes(app, future, future)
			codexClock = func() time.Time { return future }
			if p := CodexBin(home); p != app {
				t.Fatalf("an updated app CLI was not tried again: %s", p)
			}
		})
	}
}

// An explicit path, or a binary the reader did not find itself, has no fallback.
func TestCodexProtocolFailureOfAnExplicitCLITriesNothingElse(t *testing.T) {
	isolateHome(t)
	resetCodexVersions(t)
	cache := t.TempDir()
	bin := codexScript(t, "[ \"$1\" = app-server ] || exit 2\nwhile IFS= read -r line; do echo '{\"id\":1,\"error\":{\"code\":-32601,\"message\":\"Method not found\"}}'; done\n")
	t.Setenv("MODELPLAN_CODEX", bin)
	if err := RefreshCodexAccount(context.Background(), cache, CodexBin(os.Getenv("HOME")), acctNow); err == nil {
		t.Fatal("an explicit failing CLI read succeeded")
	}
	if s := loadAccount(cache); s == nil || s.Status == "ok" || s.CLI == nil || s.CLI.Source != "override" {
		t.Fatalf("snapshot %+v", s)
	}
}
