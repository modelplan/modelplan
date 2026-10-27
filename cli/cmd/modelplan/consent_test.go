package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func consentFixtureHome(t *testing.T) string {
	t.Helper()
	isolateHome(t)
	home := os.Getenv("HOME")
	t.Setenv("MODELPLAN_CACHE", filepath.Join(home, "modelplan-cache"))
	t.Setenv("PATH", filepath.Join(home, "bin"))
	t.Setenv("MODELPLAN_READERS", "")
	for _, dir := range []string{".claude", ".codex"} {
		if err := os.MkdirAll(filepath.Join(home, dir), 0700); err != nil {
			t.Fatal(err)
		}
	}
	old := version
	version = "1.0.0"
	t.Cleanup(func() { version = old })
	oldStart := startDetached
	startDetached = func(...string) error { t.Fatal("started reader/process"); return nil }
	t.Cleanup(func() { startDetached = oldStart })
	return home
}
func consentRun(args []string, input string) (int, string, string) {
	var out, errOut bytes.Buffer
	code := run(args, strings.NewReader(input), &out, &errOut)
	return code, out.String(), errOut.String()
}
func TestConnectDetectedJSONIsReadOnlyPreview(t *testing.T) {
	home := consentFixtureHome(t)
	code, out, errOut := consentRun([]string{"connect", "--detected", "--json", "--privacy", "passive"}, "")
	if code != 0 || errOut != "" {
		t.Fatal(code, errOut)
	}
	var r struct {
		DryRun             bool
		EffectivePrivacy   string
		ConsentTextVersion int
		Tools              []consentChoice
	}
	if err := json.Unmarshal([]byte(out), &r); err != nil {
		t.Fatal(err)
	}
	if !r.DryRun || r.EffectivePrivacy != "passive" || r.ConsentTextVersion != consent.TextVersion || len(r.Tools) != 2 {
		t.Fatal(out)
	}
	for _, x := range r.Tools {
		if !x.Selected {
			t.Fatal(x)
		}
	}
	for _, path := range []string{consent.Path(), filepath.Join(home, "modelplan-cache"), filepath.Join(home, ".config")} {
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Fatal("preview wrote", path)
		}
	}
}
func TestConnectDetectedOneConfirmationAndPersistentSelection(t *testing.T) {
	consentFixtureHome(t)
	code, out, errOut := consentRun([]string{"connect", "--detected", "--privacy", "passive", "--lang", "en"}, "1\ny\n")
	if code != 0 || errOut != "" {
		t.Fatal(code, out, errOut)
	}
	if strings.Count(out, "Allow selected tools?") != 1 || !strings.Contains(out, "[x] 1.") || !strings.Contains(out, "[x] 2.") {
		t.Fatal(out)
	}
	s, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	if s.Privacy != consent.Passive || !s.Tools["claude"].Allowed || s.Tools["codex"].Allowed || s.Tools["claude"].ConsentTextVersion != consent.TextVersion {
		t.Fatal(s)
	}
	if consent.Allowed("codex", consent.Runtime) {
		t.Fatal("unselected tool admitted")
	}
	if consent.Allowed("claude", consent.Credential) {
		t.Fatal("passive allowed credential import")
	}
}
func TestNotNowEOFAndInvalidSelectionEnableNothing(t *testing.T) {
	for _, input := range []string{"none\n", "\nno\n", "", "\nmaybe\n", "999\ny\n"} {
		t.Run(strings.ReplaceAll(input, "\n", "_"), func(t *testing.T) {
			consentFixtureHome(t)
			consentRun([]string{"connect", "--detected"}, input)
			s, err := consent.Load(consent.Path())
			if err != nil {
				t.Fatal(err)
			}
			if len(s.Tools) != 0 {
				t.Fatal("saved permissions without confirmation")
			}
		})
	}
}
func TestChoiceNeverFallsBackAndRequiresAudit(t *testing.T) {
	tool := detect.Tool{Entry: detect.Entry{ProviderID: "claude", ReaderID: "native:claude-code", Preferred: "native"}, Detected: true}
	if x := choice(tool, consent.Automatic); x.Backend != "native" || !x.Selected {
		t.Fatal(x)
	}
	tool.Preferred = "codexbar"
	if x := choice(tool, consent.Automatic); x.Selected || x.Status != "codexbar-not-audited" {
		t.Fatal(x)
	}
	tool.CodexBar.Audited = true
	tool.CodexBar.AccessClass = "standard"
	if x := choice(tool, consent.Automatic); !x.Selected || !strings.Contains(x.Access, "CodexBar") {
		t.Fatal(x)
	}
	if x := choice(tool, consent.Passive); x.Selected {
		t.Fatal(x)
	}
	tool.Preferred = "off"
	if x := choice(tool, consent.Automatic); x.Selected {
		t.Fatal(x)
	}
}
func TestDisconnectDeletesOnlyOwnReadingsAndAll(t *testing.T) {
	home := consentFixtureHome(t)
	cache := filepath.Join(home, "modelplan-cache", "observed")
	os.MkdirAll(cache, 0700)
	for _, file := range []string{"native.json", "codexbar.json"} {
		os.WriteFile(filepath.Join(cache, file), []byte(`{"schemaVersion":1,"providers":[{"provider":"cursor","windows":[{"usedPercent":25}]},{"provider":"zai","windows":[{"usedPercent":10}]}]}`), 0600)
	}
	for _, file := range []string{"cycles.json", "pace.json"} {
		os.WriteFile(filepath.Join(cache, file), []byte(`{"schemaVersion":1,"cycles":[{"source":"native:cursor"},{"source":"native:zai"}]}`), 0600)
	}
	for _, file := range []string{"speed.json", "perf.json", "daily-long.json"} {
		os.WriteFile(filepath.Join(cache, file), []byte(`{"schemaVersion":1,"rows":[{"source":"cursor"},{"source":"zai"}],"sessions":[{"source":"cursor"},{"source":"zai"}],"hourly":[{"source":"cursor"},{"source":"zai"}],"live":[{"source":"cursor"},{"source":"zai"}]}`), 0600)
	}
	os.WriteFile(filepath.Join(cache, "claude-code.json"), []byte(`synthetic snapshot`), 0600)
	toolFile := filepath.Join(home, ".claude", ".credentials.json")
	os.WriteFile(toolFile, []byte("SYNTHETIC-DO-NOT-TOUCH"), 0600)
	gate := filepath.Join(cache, "attempt-gates.json")
	os.WriteFile(gate, []byte("KEEP-GATE"), 0600)
	code, out, errOut := consentRun([]string{"disconnect", "cursor", "--json"}, "")
	if code != 0 {
		t.Fatal(code, out, errOut)
	}
	for _, file := range []string{"native.json", "codexbar.json", "cycles.json", "pace.json", "perf.json"} {
		b, _ := os.ReadFile(filepath.Join(cache, file))
		if bytes.Contains(b, []byte("cursor")) || !bytes.Contains(b, []byte("zai")) {
			t.Fatal(file, string(b))
		}
	}
	s, _ := consent.Load(consent.Path())
	if s.Tools["cursor"].Allowed || s.Tools["cursor"].ConsentTextVersion != consent.TextVersion {
		t.Fatal(s)
	}
	code, out, errOut = consentRun([]string{"disconnect", "--all", "--json"}, "")
	if code != 0 {
		t.Fatal(code, out, errOut)
	}
	if _, err := os.Stat(filepath.Join(cache, "claude-code.json")); !os.IsNotExist(err) {
		t.Fatal("snapshot not removed")
	}
	if b, _ := os.ReadFile(toolFile); string(b) != "SYNTHETIC-DO-NOT-TOUCH" {
		t.Fatal("changed owner tool data")
	}
	if b, _ := os.ReadFile(gate); string(b) != "KEEP-GATE" {
		t.Fatal("cleared rate-limit gate")
	}
}
func TestDisconnectBusyCacheKeepsRevocation(t *testing.T) {
	home := consentFixtureHome(t)
	cache := filepath.Join(home, "modelplan-cache", "observed")
	os.MkdirAll(cache, 0700)
	os.WriteFile(filepath.Join(cache, "native.lock"), nil, 0600)
	code, _, errOut := consentRun([]string{"disconnect", "cursor"}, "")
	if code == 0 || !strings.Contains(errOut, "permissions revoked") {
		t.Fatal(code, errOut)
	}
	s, _ := consent.Load(consent.Path())
	if s.Tools["cursor"].Allowed {
		t.Fatal("revocation lost")
	}
}
func TestHintOnceAndNoReaskAfterDecision(t *testing.T) {
	consentFixtureHome(t)
	st, _ := store.Locate()
	var out bytes.Buffer
	detectedHint(st, &out, common{json: true})
	if out.Len() != 0 {
		t.Fatal("JSON polluted")
	}
	detectedHint(st, &out, common{})
	if strings.Count(out.String(), "connect --detected") != 1 {
		t.Fatal(out.String())
	}
	out.Reset()
	detectedHint(st, &out, common{})
	if out.Len() != 0 {
		t.Fatal("repeated hint")
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		s.Hinted = map[string]bool{}
		consent.Set(s, "claude", false, "", "", time.Now())
		return consent.Set(s, "codex", false, "", "", time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	detectedHint(st, &out, common{})
	if out.Len() != 0 {
		t.Fatal("asked revoked tools again")
	}
}
func TestReadersOffAndPassiveAdmission(t *testing.T) {
	consentFixtureHome(t)
	t.Setenv("MODELPLAN_READERS", "off")
	code, out, errOut := consentRun([]string{"quota", "--refresh-account", "--json"}, "")
	if code != 0 || errOut != "" || !strings.Contains(out, `"accounts": []`) {
		t.Fatal(code, out, errOut)
	}
	if r := quota.ReadPermitted(quota.Paths{Cache: t.TempDir()}, time.Now()); len(r.Accounts) != 0 {
		t.Fatal(r)
	}
	if !consent.CurrentGeneration(0) {
		t.Fatal("missing state generation")
	}
}

func TestPublishedAuditGateAndPassivePolicy(t *testing.T) {
	for _, v := range []struct {
		preferred       string
		audited, legacy bool
		mode, want      string
	}{
		{"codexbar", false, false, "", "codexbar-not-audited"},
		{"codexbar", false, true, "", "codexbar-not-audited"},
		{"codexbar", true, false, "", ""},
		{"codexbar", true, false, "passive", "reader-consent-or-privacy"},
		{"native", false, false, "passive", "reader-consent-or-privacy"},
		{"off", true, false, "", "catalogue-off"},
	} {
		t.Run(v.preferred+v.mode+strconv.FormatBool(v.legacy), func(t *testing.T) {
			consentFixtureHome(t)
			t.Setenv("MODELPLAN_READERS", v.mode)
			f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
				var data map[string]json.RawMessage
				json.Unmarshal(doc["data"], &data)
				data["detectorSchemaVersion"] = json.RawMessage("1")
				data["detectorRevision"] = json.RawMessage("3")
				data["detectors"] = publicationJSON(t, []any{map[string]any{"providerId": "cursor", "displayName": "Cursor", "readerId": "native:cursor", "preferred": v.preferred, "codexbar": map[string]any{"audited": v.audited, "accessClass": "standard"}, "minCli": "0.1.0", "beta": true, "detectionStatus": "signals", "signals": []any{map[string]string{"type": "path", "value": ".cursor"}}}})
				doc["data"] = publicationJSON(t, data)
			})
			st, err := store.Open()
			if err != nil {
				t.Fatal(err)
			}
			if err := st.PutObject(f.objectHash, f.object); err != nil {
				t.Fatal(err)
			}
			if err := st.PutManifest(f.id, f.manifest); err != nil {
				t.Fatal(err)
			}
			if err := st.SaveState(store.State{PublicationID: f.id, ManifestHash: publicationHash(f.manifest), Component: "client", ComponentHash: f.objectHash}); err != nil {
				t.Fatal(err)
			}
			backend := v.preferred
			if backend == "off" {
				backend = "native"
			}
			p := quotaPaths(st)
			if v.legacy {
				err = quota.SetConnection(p.ConnectionsFile, quota.QuotaSource{Provider: "cursor", Backend: quota.BackendCodexBar, Enabled: true})
			} else {
				err = consent.Change(consent.Path(), func(s *consent.State) error {
					return consent.Set(s, "cursor", true, "native:cursor", backend, time.Now())
				})
			}
			if err != nil {
				t.Fatal(err)
			}
			ss, err := quota.Selections(p)
			if err != nil || len(ss) != 1 || ss[0].Blocked != v.want {
				t.Fatal(ss, err, v.want)
			}
			p.CLIVersion = "0.0.1"
			if ss, err := quota.Selections(p); err != nil || len(ss) != 1 || ss[0].Blocked != "update-required" {
				t.Fatal("minCli was bypassed", ss, err)
			}
		})
	}
}
