package quota

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

const antigravityFixture = `{"userStatus":{"email":"private-email-canary","cascadeModelConfigData":{"clientModelConfigs":[{"label":"private-label-canary","modelOrAlias":{"model":"MODEL_CLAUDE"},"quotaInfo":{"remainingFraction":0.25,"resetTime":"2026-11-01T00:00:00Z"}},{"modelOrAlias":{"model":"MODEL_GEMINI"},"quotaInfo":{"remainingFraction":0}},{"modelOrAlias":{"model":"MISSING"},"quotaInfo":{}}]}}}`

func antigravityTestServer(t *testing.T, h http.HandlerFunc) (AntigravityServer, *httptest.Server) {
	t.Helper()
	old := antigravityVerify
	t.Cleanup(func() { antigravityVerify = old })
	antigravityVerify = func(context.Context, AntigravityServer) error { return nil }
	s := httptest.NewServer(h)
	t.Cleanup(s.Close)
	_, port, _ := net.SplitHostPort(s.Listener.Addr().String())
	n, _ := strconv.Atoi(port)
	return AntigravityServer{PID: 101, Port: n, CSRF: "csrf-canary"}, s
}
func TestAntigravityLocalRPCAndCache(t *testing.T) {
	isolateHome(t)
	calls := 0
	fail := false
	desc, _ := antigravityTestServer(t, func(w http.ResponseWriter, r *http.Request) {
		calls++
		if r.Method != "POST" || r.URL.Path != "/exa.language_server_pb.LanguageServerService/GetUserStatus" || r.Header.Get("X-Codeium-Csrf-Token") != "csrf-canary" {
			t.Error("wrong RPC")
		}
		var body map[string]any
		_ = json.NewDecoder(r.Body).Decode(&body)
		if _, ok := body["metadata"]; !ok || strings.Contains(r.Header.Get("Authorization"), "Bearer") {
			t.Error("wrong metadata")
		}
		if fail {
			http.Error(w, "private-error-canary", 500)
			return
		}
		_, _ = w.Write([]byte(antigravityFixture))
	})
	ctx := WithAntigravityServer(context.Background(), desc)
	cache := t.TempDir()
	e := collectAntigravity(ctx, nil, cache, now)
	if e.Status != "ok" || len(e.Windows) != 2 || *e.Windows[0].UsedPercent != 75 || *e.Windows[1].UsedPercent != 100 || e.Plan != "" || e.SubscriptionRef != "" {
		t.Fatal(e)
	}
	collectAntigravity(ctx, nil, cache, now.Add(time.Minute))
	if calls != 1 {
		t.Fatal(calls)
	}
	fail = true
	collectAntigravity(ctx, nil, cache, now.Add(10*time.Minute))
	r := ReadAntigravityCache(ctx, cache, now.Add(11*time.Minute))
	if calls != 2 || !r.Beta || r.Freshness != "stale" || !r.ObservedAt.Equal(now) || r.Reading == nil {
		t.Fatal(r)
	}
	b, _ := os.ReadFile(antigravityStatePath(cache))
	out, _ := json.Marshal(r)
	for _, canary := range []string{"csrf-canary", "private-email-canary", "private-label-canary", "private-error-canary"} {
		if bytes.Contains(append(b, out...), []byte(canary)) {
			t.Fatal("private text persisted")
		}
	}
	r = ReadAntigravityCache(ctx, cache, time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC))
	if len(r.Reading.Windows) != 1 || r.Reading.Windows[0].Limit != "MODEL_GEMINI" {
		t.Fatal(r)
	}
}
func TestAntigravityAdmissionAndDiscovery(t *testing.T) {
	isolateHome(t)
	old := antigravityCommand
	t.Cleanup(func() { antigravityCommand = old })
	calls := 0
	antigravityCommand = func(context.Context, string, ...string) ([]byte, error) { calls++; return nil, nil }
	for _, mode := range []string{"off", "passive"} {
		t.Setenv("MODELPLAN_READERS", mode)
		collectAntigravity(context.Background(), nil, t.TempDir(), now)
	}
	t.Setenv("MODELPLAN_READERS", "")
	collectAntigravity(WithAntigravityAccess(context.Background(), AntigravityAccess{Allowed: true, Denied: true}), nil, t.TempDir(), now)
	if calls != 0 {
		t.Fatal("discovery before admission")
	}
	e := collectAntigravity(context.Background(), nil, t.TempDir(), now)
	if e.Status != "error" || e.Error != "Open Antigravity" || calls != 1 {
		t.Fatal(e, calls)
	}
	raw := []byte(fmt.Sprintf("123 %d language_server /app/language_server --app_data_dir antigravity --csrf_token synthetic-token --extension_server_port 9876\n124 %d language_server language_server --app_data_dir other --csrf_token private --extension_server_port 9999\n", os.Getuid(), os.Getuid()))
	servers := antigravityServers(raw)
	if len(servers) != 1 || servers[0].Port != 9876 {
		t.Fatal(servers)
	}
	if got := antigravityServers([]byte("1 language_server --app_data_dir antigravity --csrf_token x --extension_server_port 70000")); len(got) != 0 {
		t.Fatal(got)
	}
}
func TestAntigravityNoRedirectRetryOrOAuth(t *testing.T) {
	isolateHome(t)
	calls := 0
	targetCalls := 0
	target := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { targetCalls++ }))
	defer target.Close()
	desc, _ := antigravityTestServer(t, func(w http.ResponseWriter, r *http.Request) { calls++; http.Redirect(w, r, target.URL, 302) })
	e := fetchAntigravity(WithAntigravityServer(context.Background(), desc), nil, "", "", now)
	if e.Status != "error" || calls != 1 || targetCalls != 0 {
		t.Fatal(e, calls, targetCalls)
	}
	for _, raw := range []string{`null`, `{}`, `{"userStatus":{"cascadeModelConfigData":{"clientModelConfigs":[{"modelOrAlias":{"model":"a"},"quotaInfo":{"remainingFraction":2}}]}}}`} {
		if e := parseAntigravity([]byte(raw), now); e.Status != "error" {
			t.Fatal(e)
		}
	}
}

// A macOS ps row exactly as `ps -o pid=,uid=,comm=,args=` prints the hub-mode server
// (Antigravity 2.34): comm is the first 16 characters of the executable path, and
// neither the port nor the transport nonce is on the command line.
const antigravityHubRow = "555 %d /Applications/An /Applications/Antigravity.app/Contents/Resources/bin/language_server --standalone --app_data_dir antigravity --read_host_bridge_token_from_stdin"
const antigravityHubNonce = "hub-nonce-canary"

// The daemon folder layout under an isolated home: ~/.gemini/<app data>/daemon.
func antigravityDaemonHome(t *testing.T) string {
	t.Helper()
	old := antigravityDaemonDir
	t.Cleanup(func() { antigravityDaemonDir = old })
	home := t.TempDir()
	antigravityDaemonDir = func(appData string) string { return filepath.Join(home, ".gemini", appData, "daemon") }
	return home
}

func TestAntigravityLanguageServerRows(t *testing.T) {
	uid := os.Getuid()
	rows := func(lines ...string) []antigravityProcessRow {
		return antigravityProcessRows([]byte(strings.Join(lines, "\n") + "\n"))
	}
	server := "/Applications/Antigravity.app/Contents/Resources/bin/language_server_macos_arm --app_data_dir antigravity"
	// macOS truncates comm beside args; Linux, and a path of at most 16 characters, print the bare name.
	for _, comm := range []string{"/Applications/An", "language_server", "language_server_m"} {
		if got := rows(fmt.Sprintf("555 %d %s %s", uid, comm, server)); len(got) != 1 || got[0].pid != 555 {
			t.Fatal(comm, got)
		}
	}
	for name, line := range map[string]string{
		"another user's server": fmt.Sprintf("555 %d /Applications/An %s", uid+1, server),
		"another executable":    fmt.Sprintf("555 %d /Applications/An /Applications/Antigravity.app/Contents/MacOS/Antigravity %s", uid, server),
		"a later argument":      fmt.Sprintf("555 %d /bin/zsh /bin/zsh -c language_server --app_data_dir antigravity", uid),
		// Not guessed: the executable's path is split, so its name cannot be read with certainty.
		"a space in the executable's path": fmt.Sprintf("555 %d /Users/Janet Doe /Users/Janet Doe/Applications/Antigravity.app/Contents/Resources/bin/language_server --app_data_dir antigravity", uid),
	} {
		if got := rows(line); len(got) != 0 {
			t.Fatal(name, got)
		}
	}
}

func TestAntigravityDaemonDescriptorDiscovery(t *testing.T) {
	uid := os.Getuid()
	hubRow := fmt.Sprintf(antigravityHubRow, uid)
	ideAppDataRow := strings.Replace(hubRow, "--app_data_dir antigravity ", "--app_data_dir antigravity-ide ", 1)
	valid := `{"pid":555,"httpsPort":63530,"httpPort":63531,"lsVersion":"2.34.0","csrfToken":"` + antigravityHubNonce + `"}`
	for _, tc := range []struct {
		name, folder, file, body, rows string
		known                          []AntigravityServer
		want                           int
	}{
		{name: "hub-mode server", folder: "antigravity", file: "hub_63531.json", body: valid, rows: hubRow, want: 1},
		// An `agy --hub` server names its file after the hub port, not the HTTP one.
		{name: "file name port is not the HTTP port", folder: "antigravity", file: "hub_40000.json", body: valid, rows: hubRow, want: 1},
		{name: "IDE app data", folder: "antigravity-ide", file: "hub_63531.json", body: valid, rows: ideAppDataRow, want: 1},
		{name: "stale pid", folder: "antigravity", file: "hub_63531.json", body: valid, rows: strings.Replace(hubRow, "555 ", "556 ", 1)},
		{name: "pid runs with another app data", folder: "antigravity", file: "hub_63531.json", body: valid, rows: strings.Replace(hubRow, "--app_data_dir antigravity ", "--app_data_dir other ", 1)},
		{name: "another app data's folder", folder: "antigravity", file: "hub_63531.json", body: valid, rows: ideAppDataRow},
		{name: "no nonce", folder: "antigravity", file: "hub_63531.json", body: `{"pid":555,"httpPort":63531}`, rows: hubRow},
		{name: "nonce with another charset", folder: "antigravity", file: "hub_63531.json", body: `{"pid":555,"httpPort":63531,"csrfToken":"not a nonce"}`, rows: hubRow},
		{name: "no pid", folder: "antigravity", file: "hub_63531.json", body: `{"httpPort":63531,"csrfToken":"` + antigravityHubNonce + `"}`, rows: hubRow},
		{name: "no HTTP port", folder: "antigravity", file: "hub_63531.json", body: `{"pid":555,"httpsPort":63530,"csrfToken":"` + antigravityHubNonce + `"}`, rows: hubRow},
		{name: "HTTP port out of range", folder: "antigravity", file: "hub_63531.json", body: `{"pid":555,"httpPort":70000,"csrfToken":"` + antigravityHubNonce + `"}`, rows: hubRow},
		{name: "another file name", folder: "antigravity", file: "ls_63531.json", body: valid, rows: hubRow},
		{name: "another file name, no digits", folder: "antigravity", file: "hub_port.json", body: valid, rows: hubRow},
		{name: "unparsable", folder: "antigravity", file: "hub_63531.json", body: `not json`, rows: hubRow},
		{name: "already found from the command line", folder: "antigravity", file: "hub_63531.json", body: valid, rows: hubRow, known: []AntigravityServer{{PID: 555, Port: 1, CSRF: "x"}}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			home := antigravityDaemonHome(t)
			dir := filepath.Join(home, ".gemini", tc.folder, "daemon")
			if err := os.MkdirAll(dir, 0700); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(filepath.Join(dir, tc.file), []byte(tc.body), 0600); err != nil {
				t.Fatal(err)
			}
			got := antigravityDaemonServers([]byte(tc.rows), tc.known)
			if len(got) != tc.want {
				t.Fatal(got)
			}
			if tc.want == 1 && (got[0].PID != 555 || got[0].Port != 63531 || got[0].CSRF != antigravityHubNonce) {
				t.Fatal(got[0])
			}
		})
	}
}

func TestAntigravityDaemonDescriptorFolderIsReadOnceAndRefusesSymlinks(t *testing.T) {
	home := antigravityDaemonHome(t)
	uid := os.Getuid()
	dir := filepath.Join(home, ".gemini", "antigravity", "daemon")
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	descriptor := func(pid, port int) string {
		return fmt.Sprintf(`{"pid":%d,"httpPort":%d,"csrfToken":"%s"}`, pid, port, antigravityHubNonce)
	}
	// Two servers share one folder, and the descriptor of the server listed last is read too.
	rows := fmt.Sprintf(antigravityHubRow, uid) + "\n" + strings.Replace(fmt.Sprintf(antigravityHubRow, uid), "555 ", "557 ", 1)
	for _, f := range []struct {
		name, body string
	}{{"hub_63531.json", descriptor(555, 63531)}, {"hub_63532.json", descriptor(557, 63532)}} {
		if err := os.WriteFile(filepath.Join(dir, f.name), []byte(f.body), 0600); err != nil {
			t.Fatal(err)
		}
	}
	if got := antigravityDaemonServers([]byte(rows), nil); len(got) != 2 {
		t.Fatal(got)
	}
	// A descriptor the server did not write: a link to a file elsewhere is not read.
	real := filepath.Join(home, "elsewhere.json")
	if err := os.WriteFile(real, []byte(descriptor(555, 63531)), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(filepath.Join(dir, "hub_63531.json")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(real, filepath.Join(dir, "hub_63531.json")); err != nil {
		t.Fatal(err)
	}
	if got := antigravityDaemonServers([]byte(rows), nil); len(got) != 1 || got[0].PID != 557 {
		t.Fatal(got)
	}
}

func TestAntigravityHubDaemonEndToEnd(t *testing.T) {
	isolateHome(t)
	home := antigravityDaemonHome(t)
	// Binding is covered by TestAntigravityListenerBindingBeforeHTTP and TestAntigravityVerifyBindsHubModeToTheListener.
	_, ts := antigravityTestServer(t, func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Codeium-Csrf-Token") != antigravityHubNonce || r.URL.Path != "/exa.language_server_pb.LanguageServerService/GetUserStatus" {
			t.Error("wrong transport nonce or RPC")
		}
		_, _ = w.Write([]byte(antigravityFixture))
	})
	_, port, _ := net.SplitHostPort(ts.Listener.Addr().String())
	dir := filepath.Join(home, ".gemini", "antigravity", "daemon")
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	body := fmt.Sprintf(`{"pid":555,"httpsPort":%[1]s,"httpPort":%[1]s,"lsVersion":"2.34.0","csrfToken":"%s"}`, port, antigravityHubNonce)
	if err := os.WriteFile(filepath.Join(dir, "hub_"+port+".json"), []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	raw := []byte(fmt.Sprintf(antigravityHubRow, os.Getuid()))
	old := antigravityCommand
	t.Cleanup(func() { antigravityCommand = old })
	antigravityCommand = func(_ context.Context, bin string, _ ...string) ([]byte, error) {
		if bin != "/bin/ps" {
			return nil, fmt.Errorf("unexpected command %s", bin)
		}
		return raw, nil
	}
	cache := t.TempDir()
	e := collectAntigravity(context.Background(), nil, cache, now)
	if e.Status != "ok" || len(e.Windows) != 2 || *e.Windows[0].UsedPercent != 75 {
		t.Fatal(e)
	}
	// The nonce is sent once and never persisted with the reading.
	b, _ := os.ReadFile(antigravityStatePath(cache))
	out, _ := json.Marshal(e)
	if bytes.Contains(b, []byte(antigravityHubNonce)) || bytes.Contains(out, []byte(antigravityHubNonce)) {
		t.Fatal("transport nonce persisted")
	}
}

func TestAntigravityVerifyBindsHubModeToTheListener(t *testing.T) {
	isolateHome(t)
	old := antigravityCommand
	t.Cleanup(func() { antigravityCommand = old })
	uid := os.Getuid()
	s := AntigravityServer{PID: 555, Port: 63531, CSRF: antigravityHubNonce}
	command := func(ps string, listenerOwner int) {
		t.Helper()
		antigravityCommand = func(_ context.Context, bin string, _ ...string) ([]byte, error) {
			switch bin {
			case "/bin/ps":
				return []byte(ps), nil
			case "/usr/sbin/lsof", "/usr/bin/lsof": // macOS, then Linux
				return []byte(fmt.Sprintf("p%d\nu%d\nn127.0.0.1:63531\n", listenerOwner, uid)), nil
			}
			return nil, fmt.Errorf("unexpected command %s", bin)
		}
	}
	hubRow := fmt.Sprintf(antigravityHubRow, uid)
	// A hub-mode row states neither the port nor the nonce, so the listener's owner pins the port.
	command(hubRow, 555)
	if err := verifyAntigravityServer(context.Background(), s); err != nil {
		t.Fatal(err)
	}
	command(hubRow, 556)
	if err := verifyAntigravityServer(context.Background(), s); err == nil {
		t.Fatal("read through a listener another process owns")
	}
	// A row that does state them must re-state exactly this server.
	command(fmt.Sprintf("555 %d language_server /app/language_server --app_data_dir antigravity --csrf_token other-nonce --extension_server_port 63531", uid), 555)
	if err := verifyAntigravityServer(context.Background(), s); err == nil {
		t.Fatal("accepted a row whose nonce changed")
	}
	// The pid must be this user's language_server with Antigravity's app data.
	for _, ps := range []string{
		fmt.Sprintf("555 %d /bin/zsh /bin/zsh -c language_server", uid),
		strings.Replace(hubRow, "--app_data_dir antigravity ", "--app_data_dir other ", 1),
	} {
		command(ps, 555)
		if err := verifyAntigravityServer(context.Background(), s); err == nil {
			t.Fatal("verified a foreign process")
		}
	}
}

func TestAntigravityListenerBindingBeforeHTTP(t *testing.T) {
	isolateHome(t)
	for _, mode := range []string{"wrong_owner", "reused_port", "exited", "nonce_changed", "owner_changes_after_dial"} {
		t.Run(mode, func(t *testing.T) {
			calls := 0
			desc, _ := antigravityTestServer(t, func(w http.ResponseWriter, r *http.Request) { calls++; _, _ = w.Write([]byte(antigravityFixture)) })
			antigravityVerify = verifyAntigravityServer
			old := antigravityCommand
			t.Cleanup(func() { antigravityCommand = old })
			checks := 0
			antigravityCommand = func(_ context.Context, bin string, args ...string) ([]byte, error) {
				if bin == "/bin/ps" {
					checks++
					if mode == "exited" {
						return nil, errors.New("synthetic exited process")
					}
					nonce := desc.CSRF
					if mode == "nonce_changed" {
						nonce = "other-nonce"
					}
					return []byte(fmt.Sprintf("%d %d language_server /app/language_server --app_data_dir antigravity --csrf_token %s --extension_server_port %d\n", desc.PID, os.Getuid(), nonce, desc.Port)), nil
				}
				owner := desc.PID
				if mode == "wrong_owner" || mode == "reused_port" || (mode == "owner_changes_after_dial" && checks >= 2) {
					owner++
				}
				return []byte(fmt.Sprintf("p%d\nu%d\nn127.0.0.1:%d\n", owner, os.Getuid(), desc.Port)), nil
			}
			e := fetchAntigravity(WithAntigravityServer(context.Background(), desc), nil, "", "", now)
			if e.Status != "error" || calls != 0 {
				t.Fatal("nonce sent to an unbound listener", mode, e, calls)
			}
		})
	}
}
func TestAntigravityNativeFailureGenerationAndLegacyRecovery(t *testing.T) {
	isolateHome(t)
	expired := false
	desc, _ := antigravityTestServer(t, func(w http.ResponseWriter, r *http.Request) {
		if expired {
			w.WriteHeader(401)
			return
		}
		_, _ = w.Write([]byte(antigravityFixture))
	})
	p := nativePaths(t)
	_ = SetConnection(p.ConnectionsFile, QuotaSource{Provider: "antigravity", Backend: BackendNative, Enabled: true})
	ctx := WithAntigravityServer(context.Background(), desc)
	if err := RefreshNative(ctx, p, now); err != nil {
		t.Fatal(err)
	}
	expired = true
	_ = RefreshNative(ctx, p, now.Add(10*time.Minute))
	found := false
	for _, s := range Read(p, now.Add(10*time.Minute)).Sources {
		if s.Source == "native:antigravity" {
			found = true
			if s.Status != "unavailable" {
				t.Fatal(s)
			}
		}
	}
	if !found {
		t.Fatal("native source missing")
	}
	r := ReadAntigravityCache(ctx, p.Cache, now.Add(10*time.Minute))
	if r.Reading == nil || r.Freshness != "stale" || !r.ObservedAt.Equal(now) {
		t.Fatal(r)
	}
	expired = false
	_ = RefreshNative(ctx, p, now.Add(19*time.Minute))
	if !loadAntigravityState(p.Cache).Good.ObservedAt.Equal(now) {
		t.Fatal("backoff bypass")
	}
	// Native dispatch also preserves the shared thirty-minute failure backoff.
	_ = RefreshNative(ctx, p, now.Add(39*time.Minute))
	if !loadAntigravityState(p.Cache).Good.ObservedAt.Equal(now) {
		t.Fatal("shared native backoff bypassed")
	}
	_ = RefreshNative(ctx, p, now.Add(40*time.Minute))
	if !loadAntigravityState(p.Cache).Good.ObservedAt.Equal(now.Add(40 * time.Minute)) {
		t.Fatal("legacy recovery blocked")
	}
	// Explicit generations isolate both cache-only, throttled and failed reads.
	cache := t.TempDir()
	ctxA := WithAntigravityAccess(ctx, AntigravityAccess{Allowed: true, LoginGeneration: strings.Repeat("a", 64)})
	ctxB := WithAntigravityAccess(ctx, AntigravityAccess{Allowed: true, LoginGeneration: strings.Repeat("b", 64)})
	collectAntigravity(ctxA, nil, cache, now)
	if r := ReadAntigravityCache(ctxB, cache, now.Add(time.Minute)); r.Reading != nil {
		t.Fatal(r)
	}
	if e := collectAntigravity(ctxB, nil, cache, now.Add(time.Minute)); e.Status != "error" || len(e.Windows) != 0 {
		t.Fatal(e)
	}
	if !loadAntigravityState(cache).AttemptAt.Equal(now) {
		t.Fatal("generation bypassed floor")
	}
	expired = true
	if e := collectAntigravity(ctxB, nil, cache, now.Add(10*time.Minute)); e.Status != "error" || len(e.Windows) != 0 {
		t.Fatal(e)
	}
	if r := ReadAntigravityCache(ctxB, cache, now.Add(10*time.Minute)); r.Reading != nil || r.Availability != "expired_login" {
		t.Fatal(r)
	}
}

func TestAntigravityVerifiedLoopbackBypassesSuppliedProxy(t *testing.T) {
	isolateHome(t)
	localCalls, proxyCalls, verifications := 0, 0, 0
	desc, _ := antigravityTestServer(t, func(w http.ResponseWriter, r *http.Request) {
		localCalls++
		if r.Header.Get("X-Codeium-Csrf-Token") != "csrf-canary" {
			t.Error("local nonce missing")
		}
		_, _ = w.Write([]byte(antigravityFixture))
	})
	antigravityVerify = func(context.Context, AntigravityServer) error { verifications++; return nil }
	proxy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		proxyCalls++
		http.Error(w, "proxy must not receive local RPC", 502)
	}))
	defer proxy.Close()
	proxyURL, err := url.Parse(proxy.URL)
	if err != nil {
		t.Fatal(err)
	}
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.Proxy = http.ProxyURL(proxyURL)
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, Timeout: nativeTimeout}
	e := fetchAntigravity(WithAntigravityServer(context.Background(), desc), client, "", "", now)
	if e.Status != "ok" || localCalls != 1 || proxyCalls != 0 || verifications != 2 {
		t.Fatalf("entry=%+v local=%d proxy=%d verification=%d", e, localCalls, proxyCalls, verifications)
	}
	if transport.Proxy == nil {
		t.Fatal("caller transport was mutated")
	}
}
