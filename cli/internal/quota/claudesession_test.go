package quota

import (
	"bytes"
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

var claudeSessionNow = time.Date(2026, 10, 27, 20, 0, 0, 0, time.UTC)

func sessionAccess(t *testing.T) localusage.HistoryAccess {
	t.Helper()
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	return localusage.HistoryAccess{Allowed: true, Privacy: "automatic", ProfileRef: strings.Repeat("a", 64), Key: bytes.Repeat([]byte{7}, 32)}
}
func TestClaudeSessionConfirmedAndOptionalFields(t *testing.T) {
	sessionAccess(t)
	b, err := os.ReadFile(filepath.Join("testdata", "claude-sessions", "owner-confirmed.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	f := parseClaudeSessionFields(b)
	if f.Model != "claude-opus-5-5" || f.Effort != "high" || f.FastMode == nil || *f.FastMode {
		t.Fatal("confirmed fields missing")
	}
	b, err = os.ReadFile(filepath.Join("testdata", "claude-sessions", "older-optional.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	for i, row := range bytes.Split(bytes.TrimSpace(b), []byte{'\n'}) {
		f = parseClaudeSessionFields(row)
		switch i {
		case 0:
			if f.Model != "claude-opus-5-5" || f.Effort != "" || f.FastMode != nil {
				t.Fatal("optional values inferred")
			}
		case 1:
			if f.Model != "" || f.Effort != "high" || f.FastMode == nil || *f.FastMode {
				t.Fatal("optional model inferred")
			}
		case 2:
			if f.Model != "" || f.Effort != "" || f.FastMode != nil {
				t.Fatal("unknown values inherited")
			}
		}
	}
	f = parseClaudeSessionFields([]byte(`{"effort":123,"message":{"model":"claude-opus-5-5","usage":"invalid"}}`))
	if f.Model != "claude-opus-5-5" || f.Effort != "" || f.FastMode != nil {
		t.Fatal("one malformed field discarded valid model")
	}
}
func sessionRow(id, parent, session, model, effort, speed string, at time.Time, extra map[string]any) []byte {
	v := map[string]any{"type": "assistant", "uuid": id, "parentUuid": parent, "sessionId": session, "timestamp": at.Format(time.RFC3339Nano), "effort": effort, "message": map[string]any{"id": "message-" + id, "model": model, "role": "assistant", "stop_reason": "end_turn", "content": []any{map[string]any{"text": "PRIVATE-CONTENT-CANARY", "type": "text"}}, "usage": map[string]any{"speed": speed, "service_tier": "PRIVATE-TIER-CANARY", "inference_geo": "PRIVATE-GEO-CANARY", "iterations": []any{"PRIVATE-ITERATIONS-CANARY"}}}, "cwd": "/private/PRIVATE-PROJECT-CANARY", "title": "PRIVATE-TITLE-CANARY"}
	for k, value := range extra {
		v[k] = value
	}
	b, _ := json.Marshal(v)
	return b
}
func sessionBatch(session, entrypoint string, at time.Time, model string) ClaudeSessionBatch {
	header, _ := json.Marshal(map[string]any{"type": "system", "uuid": "root", "parentUuid": nil, "sessionId": session, "timestamp": at.Add(-time.Second).Format(time.RFC3339Nano), "entrypoint": entrypoint, "version": "2.1.301"})
	return ClaudeSessionBatch{ExpectedSessionID: session, CompleteDiscovery: true, Records: [][]byte{header, sessionRow("assistant", "root", session, model, "high", "standard", at, nil)}}
}
func TestClaudeSessionInteractiveCurrentAndUnknownSelection(t *testing.T) {
	a := sessionAccess(t)
	old := sessionBatch("session-old", "cli", claudeSessionNow.Add(-time.Hour), "claude-opus-5-5")
	newer := sessionBatch("session-new", "claude-vscode", claudeSessionNow.Add(-time.Minute), "claude-sonnet-4-6")
	unknown := sessionBatch("session-unknown", "", claudeSessionNow, "claude-opus-5-5")
	sdk := sessionBatch("session-sdk", "sdk-ts", claudeSessionNow, "claude-opus-5-5")
	daemon := sessionBatch("session-daemon", "cli", claudeSessionNow, "claude-opus-5-5")
	var h map[string]any
	_ = json.Unmarshal(daemon.Records[0], &h)
	h["sessionKind"] = "daemon-worker"
	daemon.Records[0], _ = json.Marshal(h)
	r := ProjectClaudeSessions(a, []ClaudeSessionBatch{old, newer, unknown, sdk, daemon}, "", claudeSessionNow)
	if r.Selected == nil || r.Selected.Model != "claude-sonnet-4-6" || r.Selected.Attribution != "recent-thread" {
		t.Fatal("unknown/headless session displaced interactive")
	}
	r = ProjectClaudeSessions(a, []ClaudeSessionBatch{old, newer}, "session-old", claudeSessionNow)
	if r.Selected == nil || r.Selected.Attribution != "current-thread" || r.Selected.Model != "claude-opus-5-5" {
		t.Fatal("explicit session not selected")
	}
	r = ProjectClaudeSessions(a, []ClaudeSessionBatch{newer}, "missing", claudeSessionNow)
	if !r.CallerMissing || r.Selected == nil || r.Selected.Attribution != "recent-thread" {
		t.Fatal("missing caller relabelled current")
	}
	r = ProjectClaudeSessions(a, []ClaudeSessionBatch{unknown, sdk, daemon}, "", claudeSessionNow)
	if r.Selected != nil {
		t.Fatal("fabricated interactive attribution")
	}
	newer.CompleteDiscovery = false
	r = ProjectClaudeSessions(a, []ClaudeSessionBatch{newer}, "", claudeSessionNow)
	if r.Selected != nil || r.Availability != "partial" {
		t.Fatal("bounded uncertainty claimed recent")
	}
	assertClaudeProjectionPrivate(t, r)
}
func TestClaudeSessionMainChainResumeAndStreamingConflicts(t *testing.T) {
	a := sessionAccess(t)
	batch := sessionBatch("session-main", "cli", claudeSessionNow.Add(-time.Minute), "claude-opus-5-5")
	batch.Records = append(batch.Records, sessionRow("branch-a", "assistant", "session-main", "claude-sonnet-4-6", "low", "fast", claudeSessionNow.Add(-30*time.Second), nil))
	// A resumed user leaf points back to the earlier main-chain assistant.
	user, _ := json.Marshal(map[string]any{"type": "user", "uuid": "resume", "parentUuid": "assistant", "sessionId": "session-main", "timestamp": claudeSessionNow.Format(time.RFC3339Nano)})
	batch.Records = append(batch.Records, user)
	r := ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow)
	if r.Selected == nil || r.Selected.Model != "claude-opus-5-5" {
		t.Fatal("abandoned branch displaced resumed main chain")
	}
	batch.Records = append(batch.Records, sessionRow("reply", "resume", "session-main", "", "", "", claudeSessionNow, nil))
	r = ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow)
	if r.Selected == nil || r.Selected.Model != "" || r.Selected.Effort != "" || r.Selected.FastMode != nil {
		t.Fatal("newer missing fields inherited")
	}
	// Two complete blocks of the same message disagree only about effort/speed.
	var first map[string]any
	_ = json.Unmarshal(sessionRow("fragment-one", "reply", "session-main", "claude-opus-5-5", "high", "fast", claudeSessionNow, nil), &first)
	first["message"].(map[string]any)["id"] = "shared-message"
	one, _ := json.Marshal(first)
	var second map[string]any
	_ = json.Unmarshal(sessionRow("fragment-two", "fragment-one", "session-main", "claude-opus-5-5", "low", "standard", claudeSessionNow, nil), &second)
	second["message"].(map[string]any)["id"] = "shared-message"
	two, _ := json.Marshal(second)
	batch.Records = append(batch.Records, one, two, two)
	r = ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow)
	if r.Selected == nil || r.Selected.Model != "claude-opus-5-5" || r.Selected.Effort != "" || r.Selected.FastMode != nil {
		t.Fatal("streaming conflict guessed a value")
	}
	account := Account{Harness: &Harness{Model: "optional-plugin-model", Effort: "max"}}
	applyClaudeSessionProjection(&account, r)
	if account.Harness.Model != "claude-opus-5-5" || account.Harness.Effort != "" || account.Harness.FastMode != nil {
		t.Fatal("optional snapshot overrode native unknowns")
	}
	assertClaudeProjectionPrivate(t, r)
}
func TestClaudeSessionExclusionsPrivacyAndScopedKeys(t *testing.T) {
	a := sessionAccess(t)
	batch := sessionBatch("session-main", "cli", claudeSessionNow.Add(-time.Minute), "claude-opus-5-5")
	for _, extra := range []map[string]any{{"isSidechain": true}, {"agentId": "PRIVATE-AGENT-CANARY"}, {"teamName": "PRIVATE-TEAM-CANARY"}, {"isMeta": true}, {"isCompactSummary": true}, {"isApiErrorMessage": true}} {
		batch.Records = append(batch.Records, sessionRow("excluded", "assistant", "session-main", "claude-sonnet-4-6", "max", "fast", claudeSessionNow, extra))
	}
	batch.Records = append(batch.Records, sessionRow("synthetic", "assistant", "session-main", "<synthetic>", "max", "fast", claudeSessionNow, nil))
	r := ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow)
	if r.Selected == nil || r.Selected.Model != "claude-opus-5-5" {
		t.Fatal("excluded record displaced native session")
	}
	key := r.Selected.SessionKey
	a.ProfileRef = strings.Repeat("b", 64)
	other := ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow)
	if other.Selected == nil || other.Selected.SessionKey == key {
		t.Fatal("profiles shared an unscoped session key")
	}
	a.Key = nil
	if ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow).Selected != nil {
		t.Fatal("missing HMAC key accepted")
	}
	a = sessionAccess(t)
	a.Allowed = false
	if ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow).Availability != "consent_required" {
		t.Fatal("no consent accepted")
	}
	a.Allowed = true
	t.Setenv("MODELPLAN_READERS", "off")
	if ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow).Availability != "off" {
		t.Fatal("off ignored")
	}
	t.Setenv("MODELPLAN_READERS", "passive")
	if ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow).Selected == nil {
		t.Fatal("passive blocked local projection")
	}
	assertClaudeProjectionPrivate(t, r)
}
func TestClaudeSessionFilenameTimestampAndPartialBlocks(t *testing.T) {
	a := sessionAccess(t)
	batch := sessionBatch("session-main", "cli", claudeSessionNow.Add(-time.Minute), "claude-opus-5-5")
	mismatch := batch
	mismatch.ExpectedSessionID = "other-session"
	if ProjectClaudeSessions(a, []ClaudeSessionBatch{mismatch}, "", claudeSessionNow).Selected != nil {
		t.Fatal("filename/header mismatch accepted")
	}
	var partial map[string]any
	_ = json.Unmarshal(sessionRow("partial", "assistant", "session-main", "claude-sonnet-4-6", "max", "fast", claudeSessionNow, nil), &partial)
	partial["message"].(map[string]any)["stop_reason"] = nil
	b, _ := json.Marshal(partial)
	batch.Records = append(batch.Records, b)
	r := ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow)
	if r.Selected == nil || r.Selected.Model != "claude-opus-5-5" || !r.Selected.ObservedAt.Equal(claudeSessionNow.Add(-time.Minute)) {
		t.Fatal("partial block freshened old state")
	}
	// The minimal owner fixture proves fields, but no timestamp/interactivity.
	raw, err := os.ReadFile(filepath.Join("testdata", "claude-sessions", "owner-confirmed.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	r = ProjectClaudeSessions(a, []ClaudeSessionBatch{{ExpectedSessionID: "session-minimal", CompleteDiscovery: true, Records: [][]byte{raw}}}, "", claudeSessionNow)
	if r.Selected != nil {
		t.Fatal("field fixture fabricated a live session")
	}
}
func assertClaudeProjectionPrivate(t *testing.T, r ClaudeSessionProjection) {
	t.Helper()
	b, _ := json.Marshal(r)
	for _, private := range []string{"PRIVATE-", "session-main", "session-old", "session-new", "shared-message", "parentUuid", "entrypoint", "sessionKind", "cwd", "content", "service_tier", "inference_geo", "iterations"} {
		if strings.Contains(string(b), private) {
			t.Fatal("private record field escaped projection")
		}
	}
}
