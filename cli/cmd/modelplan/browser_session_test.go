package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func accessCatalogue(t *testing.T, access string) {
	t.Helper()
	codex := detect.Entry{ProviderID: "codex", DisplayName: "Codex", ReaderID: "native:codex", Preferred: "native", MinCLI: "0.0.0", Beta: true, DetectionStatus: "signals", Signals: []json.RawMessage{json.RawMessage(`{"type":"path","value":".codex"}`)}}
	browser := codex
	browser.ProviderID = "windsurf"
	browser.DisplayName = "Windsurf"
	browser.ReaderID = "codexbar:windsurf"
	browser.Preferred = "codexbar"
	browser.CodexBar.Audited = true
	browser.CodexBar.AccessClass = access
	f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		var data map[string]json.RawMessage
		json.Unmarshal(doc["data"], &data)
		data["detectorSchemaVersion"] = json.RawMessage("1")
		data["detectorRevision"] = json.RawMessage("10")
		data["detectors"] = publicationJSON(t, []detect.Entry{codex, browser})
		doc["data"] = publicationJSON(t, data)
	})
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	if err = st.PutObject(f.objectHash, f.object); err != nil {
		t.Fatal(err)
	}
	if err = st.PutManifest(f.id, f.manifest); err != nil {
		t.Fatal(err)
	}
	if err = st.SaveState(store.State{PublicationID: f.id, ManifestHash: publicationHash(f.manifest), Component: "client", ComponentHash: f.objectHash}); err != nil {
		t.Fatal(err)
	}
}

func TestAdvancedBrowserNeverIncludedInStandardConfirmation(t *testing.T) {
	consentFixtureHome(t)
	accessCatalogue(t, "browser-session")
	code, out, errOut := consentRun([]string{"connect", "--detected", "--json"}, "")
	if code != 0 {
		t.Fatal(code, errOut)
	}
	var preview struct{ Tools, Advanced []consentChoice }
	if err := json.Unmarshal([]byte(out), &preview); err != nil {
		t.Fatal(err)
	}
	if len(preview.Advanced) != 1 || preview.Advanced[0].Selected || preview.Advanced[0].Group != "advanced" {
		t.Fatal(out)
	}
	code, out, errOut = consentRun([]string{"connect", "--detected"}, "\ny\n")
	if code != 0 {
		t.Fatal(code, errOut)
	}
	if !strings.Contains(out, "Advanced browser sessions") || !strings.Contains(out, "[ ] 2.") {
		t.Fatal(out)
	}
	s, _ := consent.Load(consent.Path())
	if !s.Tools["codex"].Allowed || s.Tools["windsurf"].Allowed || s.Tools["windsurf"].BrowserSession {
		t.Fatal(s)
	}
	code, _, _ = consentRun([]string{"connect", "--detected"}, "2\ny\n")
	if code != exitUsage {
		t.Fatal("advanced selected through standard consent")
	}
}

func TestBrowserExplicitPreviewConsentAndPrivacy(t *testing.T) {
	home := consentFixtureHome(t)
	accessCatalogue(t, "browser-session")
	before := tree(t, home)
	code, out, errOut := consentRun([]string{"connect", "windsurf", "--browser-session", "--json"}, "yes\n")
	if code != 0 {
		t.Fatal(code, errOut)
	}
	for _, want := range []string{"Safe Storage", "saved sign-ins", "own Keychain", "https://windsurf.com", `"dryRun": true`} {
		if !strings.Contains(out, want) {
			t.Fatal("missing", want, out)
		}
	}
	after := tree(t, home)
	if len(before) != len(after) {
		t.Fatal("preview created files")
	}
	for path, body := range before {
		if after[path] != body {
			t.Fatal("preview changed", path)
		}
	}
	code, _, _ = consentRun([]string{"connect", "windsurf", "--backend", "codexbar"}, "yes\n")
	if code != exitUsage {
		t.Fatal("browser flag was optional")
	}
	code, out, errOut = consentRun([]string{"connect", "windsurf", "--browser-session"}, "yes\n")
	if code != 0 {
		t.Fatal(code, out, errOut)
	}
	s, _ := consent.Load(consent.Path())
	r := s.Tools["windsurf"]
	if !r.Allowed || !r.BrowserSession || !r.BrowserCookieCache || r.ConsentTextVersion != consent.TextVersion {
		t.Fatal(s)
	}
	t.Setenv("MODELPLAN_READERS", "passive")
	code, _, _ = consentRun([]string{"connect", "windsurf", "--browser-session"}, "yes\n")
	if code != exitUsage {
		t.Fatal("passive browser grant accepted")
	}
}

func TestNotReadNeverOffered(t *testing.T) {
	consentFixtureHome(t)
	accessCatalogue(t, "not-read")
	code, out, errOut := consentRun([]string{"connect", "--detected", "--json"}, "")
	if code != 0 {
		t.Fatal(code, errOut)
	}
	if strings.Contains(out, "windsurf") {
		t.Fatal("not-read platform offered", out)
	}
	code, _, _ = consentRun([]string{"connect", "windsurf", "--browser-session"}, "yes\n")
	if code != exitUsage {
		t.Fatal("not-read accepted")
	}
}

func TestLegacyConnectPreviewAndConfirmationNeverRunReaders(t *testing.T) {
	home := consentFixtureHome(t)
	code, out, errOut := consentRun([]string{"connect", "cursor", "--json"}, "yes\n")
	if code != 0 {
		t.Fatal(code, errOut)
	}
	if !strings.Contains(out, `"dryRun": true`) || !strings.Contains(out, "https://cursor.com") {
		t.Fatal(out)
	}
	for _, path := range []string{consent.Path(), filepath.Join(home, ".config/modelplan/connections.json"), filepath.Join(home, "modelplan-cache")} {
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Fatal("JSON wrote", path)
		}
	}
	code, _, errOut = consentRun([]string{"connect", "cursor"}, "yes\n")
	if code != 0 {
		t.Fatal(code, errOut)
	}
	s, _ := consent.Load(consent.Path())
	if !s.Tools["cursor"].Allowed {
		t.Fatal(s)
	}
	if _, err := os.Stat(filepath.Join(home, "modelplan-cache")); !os.IsNotExist(err) {
		t.Fatal("connect ran cache/reader work")
	}
}

func TestConsentDestinationsFollowSelectedRegion(t *testing.T) {
	for _, v := range []struct{ tool, region, host string }{{"zai", "bigmodel-cn", "https://open.bigmodel.cn"}, {"kimi", "international", "https://api.kimi.ai"}, {"minimax", "china", "https://api.minimaxi.com"}} {
		t.Run(v.tool, func(t *testing.T) {
			consentFixtureHome(t)
			code, out, errOut := consentRun([]string{"connect", v.tool, "--region", v.region, "--json"}, "")
			if code != 0 {
				t.Fatal(code, errOut)
			}
			var p struct{ Tools []consentChoice }
			json.Unmarshal([]byte(out), &p)
			if len(p.Tools) != 1 || len(p.Tools[0].Hosts) != 1 || p.Tools[0].Hosts[0] != v.host {
				t.Fatal(out)
			}
			code, out, errOut = consentRun([]string{"connect", v.tool, "--region", v.region}, "yes\n")
			if code != 0 || !strings.Contains(out, v.host) {
				t.Fatal(code, out, errOut)
			}
		})
	}
}

func TestForgetClearsOnlyProviderCookieCacheAndRetainsFailedMarker(t *testing.T) {
	home := consentFixtureHome(t)
	accessCatalogue(t, "browser-session")
	code, _, errOut := consentRun([]string{"connect", "windsurf", "--browser-session"}, "yes\n")
	if code != 0 {
		t.Fatal(code, errOut)
	}
	log, failed, cookie, other := filepath.Join(home, "calls"), filepath.Join(home, "fail"), filepath.Join(home, "windsurf.cookie"), filepath.Join(home, "devin.cookie")
	for _, p := range []string{failed, cookie, other} {
		os.WriteFile(p, []byte("synthetic"), 0600)
	}
	t.Setenv("MODELPLAN_TEST_COOKIE_LOG", log)
	t.Setenv("MODELPLAN_TEST_COOKIE_FAIL", failed)
	t.Setenv("MODELPLAN_TEST_COOKIE_FILE", cookie)
	bin := filepath.Join(home, "fake-helper")
	script := `#!/bin/sh
printf '%s|%s\n' "$*" "$CODEXBAR_DISABLE_KEYCHAIN_ACCESS" >> "$MODELPLAN_TEST_COOKIE_LOG"
[ "$*" = 'cache clear --cookies --provider windsurf --format json' ] || exit 9
[ ! -f "$MODELPLAN_TEST_COOKIE_FAIL" ] || exit 7
/bin/rm "$MODELPLAN_TEST_COOKIE_FILE"
`
	os.WriteFile(bin, []byte(script), 0700)
	t.Setenv("MODELPLAN_CODEXBAR", bin)
	code, _, errOut = consentRun([]string{"disconnect", "windsurf", "--json"}, "")
	if code == 0 || !strings.Contains(errOut, "cookie-cache cleanup failed") {
		t.Fatal(code, errOut)
	}
	s, _ := consent.Load(consent.Path())
	if s.Tools["windsurf"].Allowed || !s.Tools["windsurf"].BrowserCookieCache {
		t.Fatal(s)
	}
	os.Remove(failed)
	code, out, errOut := consentRun([]string{"disconnect", "windsurf", "--json"}, "")
	if code != 0 {
		t.Fatal(code, out, errOut)
	}
	s, _ = consent.Load(consent.Path())
	if s.Tools["windsurf"].BrowserCookieCache {
		t.Fatal("cleanup marker retained after success")
	}
	if _, err := os.Stat(cookie); !os.IsNotExist(err) {
		t.Fatal("cookie not cleared")
	}
	if _, err := os.Stat(other); err != nil {
		t.Fatal("other provider cookie changed")
	}
	b, _ := os.ReadFile(log)
	if strings.Count(string(b), "--provider windsurf") != 2 || strings.Contains(string(b), "--all") || !strings.Contains(string(b), "json|0") {
		t.Fatal(string(b))
	}
}

func TestQwenStatusPathsRespectOffAndRevocation(t *testing.T) {
	for _, mode := range []string{"off", "revoked"} {
		t.Run(mode, func(t *testing.T) {
			home := consentFixtureHome(t)
			file := filepath.Join(home, "export.json")
			os.WriteFile(file, []byte(`{"period":"day","value":"2026-01-02","generatedAt":"2026-01-03T10:00:00Z","totals":{"outputTokens":123456},"byModel":[{"key":"private-qwen","outputTokens":123456}]}`), 0600)
			t.Setenv("MODELPLAN_QWEN_USAGE_EXPORT", file)
			if mode == "off" {
				t.Setenv("MODELPLAN_READERS", "off")
			} else {
				consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "qwen", false, "", "", time.Now()) })
			}
			for _, args := range [][]string{{"connections", "--json", "--offline"}, {"desktop", "--json", "--read-only", "--offline"}} {
				code, out, errOut := consentRun(args, "")
				if code != 0 {
					t.Fatal(code, errOut)
				}
				if !strings.Contains(out, "reader-consent-or-privacy") || strings.Contains(out, "private-qwen") || strings.Contains(out, "123456") {
					t.Fatal(out)
				}
			}
		})
	}
}

func TestPurgeActualLocalSourceAliases(t *testing.T) {
	for _, id := range []string{"zai", "opencodego", "--all"} {
		t.Run(id, func(t *testing.T) {
			home := consentFixtureHome(t)
			observed := filepath.Join(home, "modelplan-cache/observed")
			os.MkdirAll(observed, 0700)
			body := []byte(`{"schemaVersion":1,"rows":[{"source":"zcode","totalTokens":10},{"source":"opencode","totalTokens":20},{"source":"unrelated","totalTokens":30}]}`)
			for _, file := range []string{"speed.json", "perf.json", "daily-long.json"} {
				os.WriteFile(filepath.Join(observed, file), body, 0600)
			}
			code, out, errOut := consentRun([]string{"disconnect", id, "--json"}, "")
			if code != 0 {
				t.Fatal(code, out, errOut)
			}
			for _, file := range []string{"speed.json", "perf.json", "daily-long.json"} {
				b, _ := os.ReadFile(filepath.Join(observed, file))
				if !bytes.Contains(b, []byte("unrelated")) {
					t.Fatal("unrelated rows removed")
				}
				if (id == "zai" || id == "--all") && bytes.Contains(b, []byte(`"zcode"`)) {
					t.Fatal(string(b))
				}
				if (id == "opencodego" || id == "--all") && bytes.Contains(b, []byte(`"opencode"`)) {
					t.Fatal(string(b))
				}
			}
		})
	}
}

func TestDetectedConfirmationRetainsAndShowsNativeRegion(t *testing.T) {
	home := consentFixtureHome(t)
	os.Mkdir(filepath.Join(home, ".zcode"), 0700)
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		if err := consent.Set(s, "zai", true, "native:zai", "native", time.Now()); err != nil {
			return err
		}
		r := s.Tools["zai"]
		r.Region = "bigmodel-cn"
		r.KeyEnv = "SYNTHETIC_CHINA_KEY"
		s.Tools["zai"] = r
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	code, out, errOut := consentRun([]string{"connect", "--detected", "--json"}, "")
	if code != 0 {
		t.Fatal(code, errOut)
	}
	var p struct{ Tools []consentChoice }
	json.Unmarshal([]byte(out), &p)
	found := false
	for _, r := range p.Tools {
		if r.Tool == "zai" {
			found = true
			if r.Region != "bigmodel-cn" || r.KeyEnv != "SYNTHETIC_CHINA_KEY" || len(r.Hosts) != 1 || r.Hosts[0] != "https://open.bigmodel.cn" {
				t.Fatal(r)
			}
		}
	}
	if !found {
		t.Fatal("ZCode not detected")
	}
	code, out, errOut = consentRun([]string{"connect", "--detected"}, "\nyes\n")
	if code != 0 {
		t.Fatal(code, out, errOut)
	}
	s, _ := consent.Load(consent.Path())
	if s.Tools["zai"].Region != "bigmodel-cn" || s.Tools["zai"].KeyEnv != "SYNTHETIC_CHINA_KEY" {
		t.Fatal("region changed behind confirmation", s)
	}
}
