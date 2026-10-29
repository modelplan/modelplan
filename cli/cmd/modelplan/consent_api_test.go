// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func consentAPIHome(t *testing.T) string {
	t.Helper()
	home := consentFixtureHome(t)
	t.Setenv("MODELPLAN_NATIVE", "")
	t.Setenv("MODELPLAN_CODEXBAR", "")
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	return home
}

func apiRequest(t *testing.T, n int, generation uint64, allow, deny []string, keychain map[string]string) string {
	t.Helper()
	v := consent.TextVersion
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	b, err := json.Marshal(consentRequest{RequestID: fmt.Sprintf("00000000-0000-4000-8000-%012d", n),
		ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: &generation, ConsentTextVersion: &v, Allow: allow, Deny: deny, Keychain: keychain})
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func apiTools(rows []consentTool) map[string]consentTool {
	result := map[string]consentTool{}
	for _, r := range rows {
		result[r.ID] = r
	}
	return result
}

func readConsentAPI(t *testing.T) consentView {
	t.Helper()
	code, out, stderr := consentRun([]string{"consent", "--json", "--base", "://invalid"}, "")
	var r consentView
	if code != 0 || stderr != "" || json.Unmarshal([]byte(out), &r) != nil {
		t.Fatal(code, out, stderr)
	}
	return r
}

func grantConsentAPI(t *testing.T, input string) consentResult {
	t.Helper()
	code, out, stderr := consentRun([]string{"consent", "grant", "--json", "--base", "://invalid"}, input)
	var r consentResult
	if code != 0 || stderr != "" || json.Unmarshal([]byte(out), &r) != nil || !r.OK {
		t.Fatal(code, out, stderr)
	}
	return r
}

func TestConsentAPIReadIsPresenceOnlyAndReadOnly(t *testing.T) {
	home := consentAPIHome(t)
	// A credential-content read would fail JSON parsing. Presence is sufficient.
	if err := os.WriteFile(filepath.Join(home, ".claude", ".credentials.json"), []byte("SYNTHETIC SECRET MUST NOT BE READ"), 0600); err != nil {
		t.Fatal(err)
	}
	before := tree(t, home)
	r := readConsentAPI(t)
	if r.Generation != 0 || r.Mode != "automatic" || r.ConsentTextVersion != consent.TextVersion || r.ConsentText["en"] != consent.Text || r.ConsentText["zh"] != consent.TextZH {
		t.Fatal(r)
	}
	tools := apiTools(r.Tools)
	if len(tools) != 2 || tools["claude"].Allowed || tools["claude"].Keychain != "unset" || tools["claude"].AccessClass != "standard" || !tools["codex"].Detected {
		t.Fatal(tools)
	}
	if !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("read created or changed files")
	}
	t.Setenv("MODELPLAN_READERS", "off")
	if r := readConsentAPI(t); r.Mode != consent.Off {
		t.Fatal(r)
	}
}

func TestConsentWithoutJSONExplainsUsageWithoutReadingOrWriting(t *testing.T) {
	home := consentAPIHome(t)
	for _, args := range [][]string{{"consent"}, {"consent", "grant"}} {
		before := tree(t, home)
		code, out, stderr := consentRun(args, apiRequest(t, 1, 0, []string{"claude"}, nil, nil))
		if code != exitUsage || out != "" || stderr != "usage: modelplan consent [grant] --json\n" {
			t.Fatal(code, out, stderr)
		}
		if !reflect.DeepEqual(before, tree(t, home)) {
			t.Fatal("usage error wrote files")
		}
	}
}

func TestConsentReadbackExplainsUnsetClaudeKeychainChoice(t *testing.T) {
	home := consentAPIHome(t)
	result := grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude", "codex"}, nil, nil))
	check := func(tools []consentTool) {
		t.Helper()
		claude, codex := apiTools(tools)["claude"], apiTools(tools)["codex"]
		wantNotice, wantNextStep := "", ""
		if runtime.GOOS == "darwin" {
			wantNotice, wantNextStep = consent.ClaudeKeychainUnsetNotice, consent.ClaudeKeychainNextStep
		}
		if !claude.Allowed || claude.Keychain != "unset" || claude.Notice != wantNotice || claude.NextStep != wantNextStep {
			t.Fatal("unset readback remedy does not match platform", claude)
		}
		if codex.Notice != "" || codex.NextStep != "" {
			t.Fatal("unused Keychain permission got a notice", codex)
		}
	}
	check(result.Tools)
	before := tree(t, home)
	check(readConsentAPI(t).Tools)
	if !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("readback wrote files")
	}
	grantConsentAPI(t, apiRequest(t, 2, 1, []string{"claude"}, nil, map[string]string{"claude": "allow"}))
	claude := apiTools(readConsentAPI(t).Tools)["claude"]
	if claude.Keychain != "allowed" || claude.Notice != "" || claude.NextStep != "" {
		t.Fatal("notice survived an explicit allowance", claude)
	}
}

func TestConsentAPICASReadbackReplayAndProductionAdmission(t *testing.T) {
	home := consentAPIHome(t)
	input := apiRequest(t, 1, 0, []string{"claude", "codex"}, nil, map[string]string{"claude": "allow"})
	r := grantConsentAPI(t, input)
	if r.Generation != 1 || !apiTools(r.Tools)["claude"].Allowed || apiTools(r.Tools)["claude"].Keychain != "allowed" {
		t.Fatal(r)
	}
	view := readConsentAPI(t)
	if view.Generation != r.Generation || !reflect.DeepEqual(view.Tools, r.Tools) {
		t.Fatal(view, r)
	}
	p := quota.ProductionPaths(filepath.Join(home, "modelplan-cache"), version)
	g, ok := p.ReaderAccessGrant("claude")
	if !ok || !strings.HasSuffix(g.Generation, ":1") || !g.SavedLogin || !g.Keychain || !g.StillValid() {
		t.Fatal("grant did not reach production admission", g, ok)
	}
	before := tree(t, home)
	if replay := grantConsentAPI(t, input); !reflect.DeepEqual(replay, r) {
		t.Fatal("replay changed result", replay, r)
	}
	if !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("replay wrote files")
	}
	grantConsentAPI(t, apiRequest(t, 2, 1, []string{"claude"}, nil, map[string]string{"claude": "deny"}))
	if g.StillValid() {
		t.Fatal("old in-flight production grant survived generation change")
	}
	updated, ok := quota.ProductionPaths(p.Cache, version).ReaderAccessGrant("claude")
	if !ok || !strings.HasSuffix(updated.Generation, ":2") || updated.Keychain || !updated.StillValid() {
		t.Fatal(updated, ok)
	}
	// Replay returns the original receipt even after another consent change.
	before = tree(t, home)
	if replay := grantConsentAPI(t, input); !reflect.DeepEqual(replay, r) || !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("old receipt was recomputed or rewritten", replay)
	}
}

func TestConsentAPIFailuresAreAtomic(t *testing.T) {
	consentAPIHome(t)
	grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude"}, nil, nil))
	for _, tc := range []struct{ name, input, want string }{
		{"stale generation", apiRequest(t, 2, 0, []string{"codex"}, nil, nil), "stale_generation"},
		{"stale text", strings.Replace(apiRequest(t, 3, 1, []string{"codex"}, nil, nil), `"consentTextVersion":2`, `"consentTextVersion":1`, 1), "stale_consent_text"},
		{"unknown allow", apiRequest(t, 4, 1, []string{"codex", "unknown"}, nil, nil), "unknown_tool"},
		{"undetected", apiRequest(t, 5, 1, []string{"gemini"}, nil, nil), "unknown_tool"},
		{"unknown deny", apiRequest(t, 6, 1, []string{"codex"}, []string{"unknown"}, nil), "unknown_tool"},
		{"unknown keychain", apiRequest(t, 7, 1, []string{"codex"}, nil, map[string]string{"unknown": "allow"}), "unknown_tool"},
		{"reused ID", apiRequest(t, 1, 1, []string{"codex"}, nil, nil), "request_id_conflict"},
		{"conflicting decisions", apiRequest(t, 8, 1, []string{"codex"}, []string{"codex"}, nil), "invalid_request"},
		{"duplicate selection", apiRequest(t, 9, 1, []string{"codex", "codex"}, nil, nil), "invalid_request"},
		{"two documents", apiRequest(t, 10, 1, []string{"codex"}, nil, nil) + `{}`, "invalid_request"},
		{"missing CAS", `{"requestId":"00000000-0000-4000-8000-000000000011","consentTextVersion":2}`, "invalid_request"},
		{"null", `null`, "invalid_request"},
		{"oversized", strings.Repeat(" ", (64<<10)+1), "invalid_request"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			before, _ := os.ReadFile(consent.Path())
			code, out, stderr := consentRun([]string{"consent", "grant", "--json"}, tc.input)
			var failure struct {
				OK    bool
				Error string
			}
			if code == 0 || stderr != "" || json.Unmarshal([]byte(out), &failure) != nil || failure.OK || failure.Error != tc.want {
				t.Fatal(code, out, stderr, tc.want)
			}
			after, _ := os.ReadFile(consent.Path())
			if !bytes.Equal(before, after) {
				t.Fatal("failed transaction changed consent")
			}
		})
	}
}

func TestConsentAPIConcurrentGrantsHaveOneWinner(t *testing.T) {
	consentAPIHome(t)
	inputs := []string{apiRequest(t, 1, 0, []string{"claude"}, nil, nil), apiRequest(t, 2, 0, []string{"codex"}, nil, nil)}
	var wg sync.WaitGroup
	start := make(chan struct{})
	results := make([]string, 2)
	for i := range inputs {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			<-start
			_, results[i], _ = consentRun([]string{"consent", "grant", "--json"}, inputs[i])
		}(i)
	}
	close(start)
	wg.Wait()
	winners, stale := 0, 0
	for _, result := range results {
		var r consentResult
		if json.Unmarshal([]byte(result), &r) != nil {
			t.Fatal(result)
		}
		if r.OK {
			winners++
		}
		if r.Error == "stale_generation" {
			stale++
		}
	}
	s, err := consent.Load(consent.Path())
	if winners != 1 || stale != 1 || err != nil || s.Generation != 1 || len(s.Requests) != 1 {
		t.Fatal(results, s, err)
	}
}

func cacheConsentCatalogue(t *testing.T, preferred, access, reader string) {
	t.Helper()
	f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		var data map[string]json.RawMessage
		json.Unmarshal(doc["data"], &data)
		data["detectorSchemaVersion"] = json.RawMessage("1")
		data["detectorRevision"] = json.RawMessage("3")
		data["detectors"] = publicationJSON(t, []any{map[string]any{"providerId": "claude", "displayName": "Claude Code", "readerId": reader, "preferred": preferred,
			"codexbar": map[string]any{"audited": true, "accessClass": access}, "minCli": "0.1.0", "beta": true, "detectionStatus": "signals", "signals": []any{map[string]string{"type": "path", "value": ".claude"}}}})
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
}

func TestConsentAPICachedCatalogueClassAndKillGates(t *testing.T) {
	for _, tc := range []struct{ preferred, access, reader, wantClass, wantError string }{
		{"codexbar", "browser-session", "codexbar:claude", "browser-session", "access_class_forbidden"},
		{"codexbar", "not-read", "codexbar:claude", "not-read", "readers_off"},
		{"codexbar", "future", "codexbar:claude", "not-read", "readers_off"},
		{"off", "standard", "native:claude", "not-read", "readers_off"},
		// The helper's not-read class cannot disable a separate native reader.
		{"native", "not-read", "native:claude", "standard", ""},
		{"codexbar", "standard", "codexbar:claude", "standard", ""},
	} {
		t.Run(tc.preferred+tc.access, func(t *testing.T) {
			consentAPIHome(t)
			cacheConsentCatalogue(t, tc.preferred, tc.access, tc.reader)
			if view := readConsentAPI(t); len(view.Tools) != 1 || view.Tools[0].AccessClass != tc.wantClass {
				t.Fatal(view)
			}
			code, out, stderr := consentRun([]string{"consent", "grant", "--json"}, apiRequest(t, 1, 0, []string{"claude"}, nil, nil))
			var r consentResult
			if json.Unmarshal([]byte(out), &r) != nil || stderr != "" || r.Error != tc.wantError || (code == 0) != (tc.wantError == "") {
				t.Fatal(code, out, stderr)
			}
			if tc.wantError != "" {
				if s, _ := consent.Load(consent.Path()); s.Generation != 0 || len(s.Tools) != 0 {
					t.Fatal(s)
				}
			}
		})
	}
}

func TestConsentAPIModesAndPersistentKeychainDenial(t *testing.T) {
	consentAPIHome(t)
	t.Setenv("MODELPLAN_READERS", "passive")
	grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude"}, nil, nil))
	if p := quota.ProductionPaths(t.TempDir(), version); len(p.ReaderAccess.Grants) != 0 {
		t.Fatal("passive admitted a credential reader")
	}
	t.Setenv("MODELPLAN_READERS", "off")
	before, _ := os.ReadFile(consent.Path())
	code, out, _ := consentRun([]string{"consent", "grant", "--json"}, apiRequest(t, 2, 1, []string{"codex"}, nil, nil))
	if code == 0 || !strings.Contains(out, `"readers_off"`) {
		t.Fatal(code, out)
	}
	after, _ := os.ReadFile(consent.Path())
	if !bytes.Equal(before, after) {
		t.Fatal("off wrote consent")
	}
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "off")
	code, out, _ = consentRun([]string{"consent", "grant", "--json"}, apiRequest(t, 2, 1, []string{"codex"}, nil, nil))
	if code == 0 || !strings.Contains(out, `"readers_off"`) {
		t.Fatal(code, out)
	}
	t.Setenv("MODELPLAN_NATIVE", "")
	if err := consent.Deny(consent.Path(), "claude", "keychain"); err != nil {
		t.Fatal(err)
	}
	r := grantConsentAPI(t, apiRequest(t, 3, 2, []string{"claude"}, nil, map[string]string{"claude": "allow"}))
	if apiTools(r.Tools)["claude"].Keychain != "denied" || consent.Allowed("claude", "keychain") {
		t.Fatal("reconnect cleared existing source Deny", r)
	}
}

func TestConsentAPIDenyForgetsAndReplaysWithoutWrites(t *testing.T) {
	home := consentAPIHome(t)
	grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude", "codex"}, nil, nil))
	observed := filepath.Join(home, "modelplan-cache", "observed")
	if err := os.MkdirAll(observed, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(observed, "claude-code.json"), []byte("SYNTHETIC CAPTURE"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(observed, "attempt-gates.json"), []byte("KEEP GATES"), 0600); err != nil {
		t.Fatal(err)
	}
	input := apiRequest(t, 2, 1, nil, []string{"claude"}, nil)
	r := grantConsentAPI(t, input)
	if r.Generation != 2 || apiTools(r.Tools)["claude"].Allowed || !apiTools(r.Tools)["codex"].Allowed {
		t.Fatal(r)
	}
	if _, err := os.Stat(filepath.Join(observed, "claude-code.json")); !os.IsNotExist(err) {
		t.Fatal("snapshot survived Forget", err)
	}
	if b, _ := os.ReadFile(filepath.Join(observed, "attempt-gates.json")); string(b) != "KEEP GATES" {
		t.Fatal("deleted request gates")
	}
	before := tree(t, home)
	if replay := grantConsentAPI(t, input); !reflect.DeepEqual(replay, r) || !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("deny replay wrote or changed result")
	}
}

func TestConsentAPIFailedForgetKeepsDurableRevocationAndReceipt(t *testing.T) {
	home := consentAPIHome(t)
	grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude"}, nil, nil))
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		r := s.Tools["claude"]
		r.BrowserSession, r.BrowserCookieCache = true, true
		s.Tools["claude"] = r
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	t.Setenv("CODEXBAR_DISABLE_KEYCHAIN_ACCESS", "")
	helper := filepath.Join(home, "fake-codexbar")
	if err := os.WriteFile(helper, []byte("#!/bin/sh\ntouch '"+filepath.Join(home, "helper-was-started")+"'\n"), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_CODEXBAR", helper)
	input := apiRequest(t, 2, 2, nil, []string{"claude"}, nil)
	code, out, stderr := consentRun([]string{"consent", "grant", "--json"}, input)
	var r consentResult
	if code == 0 || stderr != "" || json.Unmarshal([]byte(out), &r) != nil || r.Error != "cleanup_pending" || r.Generation != 3 || len(r.PendingForget) != 1 {
		t.Fatal(code, out, stderr)
	}
	s, err := consent.Load(consent.Path())
	if err != nil || s.Tools["claude"].Allowed || !s.Tools["claude"].BrowserCookieCache || len(s.Requests[consent.ReceiptKey(s.StoreEpoch, r.RequestID)].PendingForget) != 1 {
		t.Fatal(s, err)
	}
	before := tree(t, home)
	replayCode, replay, _ := consentRun([]string{"consent", "grant", "--json"}, input)
	if replayCode != code || replay != out || !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("failed cleanup replay changed result or wrote files", replay)
	}
	if consent.CurrentFence(consent.Fence{StoreEpoch: s.StoreEpoch, Generation: 2}) {
		t.Fatal("revocation did not invalidate old generation")
	}
	if _, err := os.Stat(filepath.Join(home, "helper-was-started")); !os.IsNotExist(err) {
		t.Fatal("JSON API started cookie cleanup that might prompt Keychain")
	}
}

func TestConsentKeychainGrantRunsOneForegroundClaudeRead(t *testing.T) {
	consentAPIHome(t)
	calls := []string{}
	old := keychainGrantReadFn
	keychainGrantReadFn = func(ctx context.Context, _ quota.Paths, provider string, _ time.Time) error {
		if _, ok := ctx.Deadline(); !ok {
			t.Fatal("foreground read has no deadline")
		}
		calls = append(calls, provider)
		return nil
	}
	t.Cleanup(func() { keychainGrantReadFn = old })
	input := apiRequest(t, 1, 0, []string{"claude", "codex"}, nil, map[string]string{"claude": "allow"})
	grantConsentAPI(t, input)
	if len(calls) != 1 || calls[0] != "claude" {
		t.Fatal("a Keychain grant must run exactly one foreground Claude read", calls)
	}
	grantConsentAPI(t, input) // replayed receipt
	grantConsentAPI(t, apiRequest(t, 2, 1, []string{"codex"}, nil, nil))
	grantConsentAPI(t, apiRequest(t, 3, 2, []string{"claude"}, nil, map[string]string{"claude": "deny"}))
	if len(calls) != 1 {
		t.Fatal("replays, grants without Keychain and Keychain denials must not read", calls)
	}
}
