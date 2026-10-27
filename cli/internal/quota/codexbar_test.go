package quota

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

var cbNow = time.Date(2026, 10, 16, 10, 0, 0, 0, time.UTC)

// fakeCodexBar prints testdata/codexbar/<provider>.json like CodexBar's CLI (exit 1 on a
// provider error, an unknown provider falls back to another record) and logs its argv and LANG.
func fakeCodexBar(t *testing.T) (bin, log string) {
	dir := t.TempDir()
	data, _ := filepath.Abs("testdata/codexbar")
	bin, log = filepath.Join(dir, "CodexBarCLI"), filepath.Join(dir, "calls")
	script := `#!/bin/sh
echo "$* LANG=$LANG" >> "` + log + `"
f="` + data + `/$2.json"
[ -f "$f" ] || { echo '[{"provider":"codex","source":"auto","error":{"code":1,"kind":"provider","message":"No available fetch strategy for codex."}}]'; exit 1; }
cat "$f"
grep -q '"error"' "$f" && exit 1
exit 0
`
	if err := os.WriteFile(bin, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return bin, log
}

func cbPaths(t *testing.T, providers ...string) Paths {
	dir := t.TempDir()
	p := Paths{Cache: filepath.Join(dir, "cache"), CodexBarFile: filepath.Join(dir, "codexbar.json")}
	auditFixtureHelpers(t, &p)
	if providers != nil {
		if err := SetCodexBarEnabled(p.CodexBarFile, providers); err != nil {
			t.Fatal(err)
		}
	}
	return p
}

func TestCodexBarReadsEnabledProvidersWithoutIdentities(t *testing.T) {
	isolateHome(t)
	p := cbPaths(t, "zai", "cursor", "opencodego", "copilot", "kiro")
	bin, log := fakeCodexBar(t)
	if !CodexBarDue(p, cbNow) {
		t.Fatal("no reading yet: due")
	}
	if err := RefreshCodexBar(context.Background(), p, bin, cbNow); err != nil {
		t.Fatal(err)
	}
	calls, _ := os.ReadFile(log)
	for _, prov := range []string{"copilot", "cursor", "kiro", "opencodego", "zai"} {
		if !strings.Contains(string(calls), "--provider "+prov+" --format json --json-only LANG=en_US.UTF-8\n") {
			t.Fatalf("%s not asked alone in English: %s", prov, calls)
		}
	}
	b, _ := os.ReadFile(codexbarPath(p.Cache))
	for _, leak := range []string{"@example.com", "user_01", "/Users/", "accountEmail", "Resets ", "identity"} {
		if strings.Contains(string(b), leak) {
			t.Fatalf("cached %q: %s", leak, b)
		}
	}

	r := Read(p, cbNow)
	if len(r.Accounts) != 2 || r.Accounts[0].Source != "codexbar:cursor" || r.Accounts[1].Source != "codexbar:zai" {
		t.Fatalf("accounts = %+v", r.Accounts)
	}
	cur, zai := r.Accounts[0], r.Accounts[1]
	if cur.Plan != "Cursor Free" || cur.Via != "codexbar" || len(cur.Windows) != 4 {
		t.Fatalf("cursor = %+v", cur)
	}
	if w := cur.Windows[2]; w.Kind != "monthly" || w.Limit != "Third Party" || w.ResetsAt == nil {
		t.Fatalf("cursor third-party window = %+v", w)
	}
	if w := cur.Windows[3]; w.Kind != "unknown" || w.Limit != "Grok Bot" || *w.UsedPercent != 1.8 {
		t.Fatalf("cursor extra window = %+v", w)
	}
	if !cur.ObservedAt.Equal(time.Date(2026, 10, 16, 14, 40, 49, 0, time.UTC)) && !cur.ObservedAt.Equal(cbNow) {
		t.Fatalf("observed = %v", cur.ObservedAt)
	}
	if zai.Plan != "GLM Coding Pro" || zai.Windows[0].Kind != "five_hour" || zai.Windows[1].Kind != "weekly" || zai.Windows[0].Limit != "" {
		t.Fatalf("zai = %+v", zai)
	}
	if zai.Windows[0].Pace == "" || zai.Headroom == "" {
		t.Fatal("codexbar accounts are evaluated like the others")
	}
	status := map[string]SourceStatus{}
	for _, s := range r.Sources {
		status[s.Source] = s
	}
	if s := status["codexbar:opencodego"]; s.Status != "estimated" {
		t.Fatalf("estimated local history is not quota: %+v", s)
	}
	if s := status["codexbar:copilot"]; s.Status != "unavailable" || s.Reason != "No available fetch strategy for copilot." {
		t.Fatalf("copilot = %+v", s)
	}
	if s := status["codexbar:kiro"]; s.Status != "unavailable" || strings.Contains(s.Reason, "someone") || !strings.Contains(s.Reason, "kiro-cli login") {
		t.Fatalf("kiro = %+v", s)
	}
	if CodexBarDue(p, cbNow.Add(9*time.Minute)) || !CodexBarDue(p, cbNow.Add(10*time.Minute)) {
		t.Fatal("refresh at most every 10 minutes")
	}
}

func TestCodexBarFutureReadingsAreClampedToTheRun(t *testing.T) {
	isolateHome(t)
	e := parseCodexBar([]byte(`[{"provider":"zai","source":"api","usage":{"primary":{"usedPercent":150,"windowMinutes":300},"updatedAt":"2027-01-01T00:00:00Z"}}]`), "zai", "", cbNow)
	if e.Status != "ok" || !e.ObservedAt.Equal(cbNow) || *e.Windows[0].UsedPercent != 100 {
		t.Fatalf("entry = %+v", e)
	}
}

func TestCodexBarOnlyTheRequestedProviderCounts(t *testing.T) {
	isolateHome(t)
	p := cbPaths(t, "copilot")
	bin, _ := fakeCodexBar(t)
	e := parseCodexBar([]byte(`[{"provider":"codex","source":"oauth","usage":{"primary":{"usedPercent":5,"windowMinutes":300}}}]`), "copilot", "", cbNow)
	if e.Status != "error" || !strings.Contains(e.Error, "no copilot record") {
		t.Fatalf("a fallback record was taken: %+v", e)
	}
	if err := RefreshCodexBar(context.Background(), p, bin, cbNow); err != nil {
		t.Fatal(err)
	}
	if CodexBarDue(p, cbNow.Add(15*time.Minute)) || !CodexBarDue(p, cbNow.Add(30*time.Minute)) {
		t.Fatal("when every provider failed, wait half an hour")
	}
}

func TestCodexBarOffAndUnknownProviders(t *testing.T) {
	isolateHome(t)
	p := cbPaths(t)
	if err := SetCodexBarEnabled(p.CodexBarFile, []string{"cursor", "claude"}); err == nil {
		t.Fatal("claude is read by this client itself, never through CodexBar")
	}
	if CodexBarDue(p, cbNow) {
		t.Fatal("nothing enabled: never due")
	}
	p = cbPaths(t, "cursor")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	if CodexBarDue(p, cbNow) || len(codexbarSources(Read(p, cbNow))) != 0 {
		t.Fatal("off is off")
	}
}

func TestCodexBarMissingBinaryIsRecorded(t *testing.T) {
	isolateHome(t)
	p := cbPaths(t, "cursor")
	if err := RefreshCodexBar(context.Background(), p, "", cbNow); err != nil {
		t.Fatal(err)
	}
	r := Read(p, cbNow)
	if s := codexbarSources(r); len(r.Accounts) != 0 || len(s) != 1 || s[0].Status != "unreadable" || s[0].Reason != "CodexBar CLI not found" {
		t.Fatalf("report = %+v", r)
	}
}

func codexbarSources(r Report) []SourceStatus {
	var out []SourceStatus
	for _, s := range r.Sources {
		if strings.HasPrefix(s.Source, "codexbar:") {
			out = append(out, s)
		}
	}
	return out
}

func tarball(t *testing.T, files map[string]string, link bool) []byte {
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	for name, body := range files {
		mode := int64(0o644)
		if name == "CodexBarCLI" {
			mode = 0o755
		}
		_ = tw.WriteHeader(&tar.Header{Name: name, Mode: mode, Size: int64(len(body)), Typeflag: tar.TypeReg})
		_, _ = tw.Write([]byte(body))
	}
	if link {
		_ = tw.WriteHeader(&tar.Header{Name: "codexbar", Linkname: "/etc/passwd", Typeflag: tar.TypeSymlink})
	}
	_ = tw.Close()
	_ = gz.Close()
	return buf.Bytes()
}

func TestFetchCodexBarChecksTheSumAndStaysInItsDirectory(t *testing.T) {
	isolateHome(t)
	plat := runtime.GOOS + "/" + runtime.GOARCH
	old, had := codexbarPin[plat]
	t.Cleanup(func() {
		if had {
			codexbarPin[plat] = old
		} else {
			delete(codexbarPin, plat)
		}
	})
	good := tarball(t, map[string]string{"CodexBarCLI": "#!/bin/sh\n", "VERSION": "0.76.0", "../escape": "x", "Bundle/a.js": "1"}, true)
	served := good
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasSuffix(r.URL.Path, "/v"+CodexBarVersion+"/CodexBarCLI-v"+CodexBarVersion+"-test.tar.gz") {
			http.NotFound(w, r)
			return
		}
		_, _ = w.Write(served)
	}))
	defer srv.Close()
	sum := sha256.Sum256(good)
	codexbarPin[plat] = [2]string{"test", hex.EncodeToString(sum[:])}

	cache := t.TempDir()
	served = append([]byte(nil), good...)
	served[len(served)-1] ^= 1
	if _, err := FetchCodexBar(context.Background(), cache, srv.URL); err == nil || !strings.Contains(err.Error(), "checksum mismatch") {
		t.Fatalf("a changed archive must not install: %v", err)
	}
	if _, err := os.Stat(filepath.Join(cache, "codexbar", CodexBarVersion)); err == nil {
		t.Fatal("nothing installed after a mismatch")
	}
	served = good
	_ = os.MkdirAll(filepath.Join(cache, "codexbar", "0.0.1"), 0o700)
	bin, err := FetchCodexBar(context.Background(), cache, srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	if bin != filepath.Join(cache, "codexbar", CodexBarVersion, "CodexBarCLI") || !executable(bin) {
		t.Fatalf("bin = %s", bin)
	}
	if _, err := os.Lstat(filepath.Join(cache, "codexbar", CodexBarVersion, "codexbar")); err == nil {
		t.Fatal("links are not unpacked")
	}
	if _, err := os.Stat(filepath.Join(cache, "codexbar", "escape")); err == nil {
		t.Fatal("a path leaving the directory was unpacked")
	}
	if _, err := os.Stat(filepath.Join(cache, "codexbar", "0.0.1")); err == nil {
		t.Fatal("older pinned versions are removed")
	}
	if CodexBarBin(cache, t.TempDir()) != bin {
		t.Fatal("the pinned copy is the one used")
	}
}

func TestCleanDropsPathsAddressesAndTokens(t *testing.T) {
	isolateHome(t)
	got := clean("open /Users/jane/Library/x and /home/bob/.config failed for jane@corp.io with abcd0123efgh4567ijkl8901mnop2345", "/Users/jane")
	if strings.Contains(got, "jane") || strings.Contains(got, "bob") || strings.Contains(got, "abcd0123") {
		t.Fatalf("clean = %q", got)
	}
}

// MODELPLAN_CODEXBAR_LIVE=1: fetch the pinned CodexBar CLI and check that its output for every
// provider this client reads still parses (without credentials each is an error record).
// Run by the codexbar-pin workflow before a new pin is proposed.
func TestLiveCodexBarContract(t *testing.T) {
	isolateHome(t)
	if os.Getenv("MODELPLAN_CODEXBAR_LIVE") != "1" {
		t.Skip("set MODELPLAN_CODEXBAR_LIVE=1")
	}
	cache := t.TempDir()
	bin, err := FetchCodexBar(context.Background(), cache, "")
	if err != nil {
		t.Fatal(err)
	}
	// CodexBar resolves its config from the user database, not $HOME; keep it away from the real one.
	tmp := t.TempDir()
	t.Setenv("HOME", tmp)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(tmp, ".config"))
	t.Setenv("CODEXBAR_CONFIG", filepath.Join(tmp, "codexbar.json"))
	for _, prov := range knownProviders(keys(CodexBarProviders)) {
		out, _ := runCodexBar(context.Background(), bin, prov)
		e := parseCodexBar(out, prov, "", time.Now())
		if e.Error == "unreadable CodexBar output" || strings.HasPrefix(e.Error, "CodexBar returned no") {
			t.Errorf("%s: %s: %.300s", prov, e.Error, out)
		}
		t.Logf("%s: %s %s", prov, e.Status, e.Error)
	}
}

func TestPinnedCodexBarIsFetchedEvenWithAUserCopy(t *testing.T) {
	isolateHome(t)
	if _, ok := codexbarPin[runtime.GOOS+"/"+runtime.GOARCH]; !ok {
		t.Skip("no pinned build for this platform")
	}
	cache := t.TempDir()
	home := t.TempDir()
	user := filepath.Join(home, ".local", "bin", "codexbar")
	_ = os.MkdirAll(filepath.Dir(user), 0o755)
	_ = os.WriteFile(user, []byte("#!/bin/sh\n"), 0o755)
	t.Setenv("PATH", "/usr/bin:/bin")
	if CodexBarBin(cache, home) != user {
		t.Fatal("a copy the user installed is used meanwhile")
	}
	if !CodexBarFetchDue(cache, time.Now()) {
		t.Fatal("an older user copy does not stop the pinned release from being fetched")
	}
	// A failed fetch is retried after half an hour, not on every prompt.
	if _, err := FetchCodexBar(context.Background(), cache, "http://127.0.0.1:9"); err == nil {
		t.Fatal("no server: the fetch fails")
	}
	if !strings.HasPrefix(CodexBarFetchResult(cache), CodexBarVersion+" failed: download failed") {
		t.Fatalf("fetch result = %q", CodexBarFetchResult(cache))
	}
	if CodexBarFetchDue(cache, time.Now()) || !CodexBarFetchDue(cache, time.Now().Add(31*time.Minute)) {
		t.Fatal("a failed fetch waits half an hour")
	}
	t.Setenv("MODELPLAN_CODEXBAR", user)
	if CodexBarFetchDue(cache, time.Now().Add(time.Hour)) {
		t.Fatal("an explicit MODELPLAN_CODEXBAR is the user's choice: nothing to fetch")
	}
}
