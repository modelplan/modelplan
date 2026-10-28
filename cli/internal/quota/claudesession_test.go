package quota

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/keychain"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
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

func writeClaudeSession(t *testing.T, path string, rows ...[]byte) []byte {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	body := []byte{}
	for _, row := range rows {
		body = append(body, row...)
		body = append(body, '\n')
	}
	if err := os.WriteFile(path, body, 0600); err != nil {
		t.Fatal(err)
	}
	return body
}
func appendClaudeSession(t *testing.T, path string, body []byte) {
	t.Helper()
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if _, err := f.Write(body); err != nil {
		t.Fatal(err)
	}
}
func assertClaudeSessionCachePrivate(t *testing.T, cache string) map[string]string {
	t.Helper()
	files := map[string]string{}
	err := filepath.WalkDir(cache, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.IsDir() {
			return nil
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		for _, private := range []string{"PRIVATE-", "session-main", "session-old", "session-new", "shared-message", "parentUuid", "entrypoint", "sessionKind", "cwd", "content", "service_tier", "inference_geo", "iterations", "raw-node", "raw-message"} {
			if strings.Contains(string(b), private) || strings.Contains(path, private) {
				t.Fatalf("private record data escaped into cache: %s", private)
			}
		}
		files[path] = string(b)
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return files
}
func sessionSelected(t *testing.T, cache string, a localusage.HistoryAccess, caller string, now time.Time) ClaudeSessionObservation {
	t.Helper()
	projection, _ := ReadClaudeSessions(cache, a, caller, now)
	if projection.Selected == nil {
		t.Fatalf("missing session: %+v", projection)
	}
	assertClaudeProjectionPrivate(t, projection)
	return *projection.Selected
}

func TestClaudeSessionProjectionAppendRestartAndCacheOnly(t *testing.T) {
	a := sessionAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects", "PRIVATE-PROJECT-CANARY", "session-main.jsonl")
	batch := sessionBatch("session-main", "cli", claudeSessionNow.Add(-time.Minute), "claude-opus-5-5")
	writeClaudeSession(t, path, batch.Records...)
	ctx := context.Background()
	r := RefreshClaudeSessions(ctx, root, cache, a, claudeSessionNow)
	if !r.Complete || r.Availability != "ok" {
		t.Fatalf("bootstrap: %+v", r)
	}
	first := sessionSelected(t, cache, a, "session-main", claudeSessionNow)
	if first.Attribution != "current-thread" || first.FastMode == nil || *first.FastMode {
		t.Fatal("wrong current session")
	}
	// A new reducer instance restores only the serialized frontier. Unchanged
	// sources receive no data batches and retain the original capture age.
	lines := 0
	reduce := ClaudeSessionReducer(a, claudeSessionNow.Add(5*time.Second))
	r = localusage.RefreshProjection(ctx, "claude", root, cache, a, claudeSessionNow.Add(5*time.Second), func(ctx context.Context, s localusage.ProjectionState, b localusage.ProjectionBatch) (localusage.ProjectionState, error) {
		lines += len(b.Lines)
		return reduce(ctx, s, b)
	})
	if !r.Complete || lines != 0 || r.BytesRead != 0 || r.ValidationBytes != 0 || !r.CapturedAt.Equal(claudeSessionNow) {
		t.Fatalf("unchanged: %+v, lines=%d", r, lines)
	}
	// A torn trailing JSON record is not decoded or allowed to freshen a turn.
	row := sessionRow("raw-node", "assistant", "session-main", "claude-sonnet-4-6", "", "", claudeSessionNow, nil)
	cut := len(row) / 2
	appendClaudeSession(t, path, row[:cut])
	r = RefreshClaudeSessions(ctx, root, cache, a, claudeSessionNow.Add(10*time.Second))
	if !r.CapturedAt.Equal(claudeSessionNow) {
		t.Fatal("fragment changed capture")
	}
	appendClaudeSession(t, path, append(row[cut:], '\n'))
	r = RefreshClaudeSessions(ctx, root, cache, a, claudeSessionNow.Add(20*time.Second))
	if !r.Complete || r.BytesRead != int64(len(row)+1) {
		t.Fatalf("append: %+v", r)
	}
	selected := sessionSelected(t, cache, a, "session-main", claudeSessionNow.Add(20*time.Second))
	if selected.Model != "claude-sonnet-4-6" || selected.Effort != "" || selected.FastMode != nil {
		t.Fatal("append inherited missing fields")
	}
	before := assertClaudeSessionCachePrivate(t, cache)
	// Cache reads survive source removal and cannot mutate the capture or cache.
	if err := os.Rename(root, root+"-unavailable"); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Rename(root+"-unavailable", root) })
	p, cached := ReadClaudeSessions(cache, a, "missing-caller", claudeSessionNow.Add(25*time.Second))
	if p.Selected == nil || !p.CallerMissing || p.Selected.Attribution != "recent-thread" || !cached.CapturedAt.Equal(r.CapturedAt) {
		t.Fatal("cache-only selection failed")
	}
	after := assertClaudeSessionCachePrivate(t, cache)
	if !reflect.DeepEqual(before, after) {
		t.Fatal("cache read mutated files")
	}
}

func TestClaudeSessionProjectionResetEmptyAndProfileScope(t *testing.T) {
	a := sessionAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects", "p", "session-main.jsonl")
	batch := sessionBatch("session-main", "cli", claudeSessionNow.Add(-time.Minute), "claude-opus-5-5")
	writeClaudeSession(t, path, batch.Records...)
	r := RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow)
	oldKey := sessionSelected(t, cache, a, "session-main", claudeSessionNow).SessionKey
	// Replacement discards old branch/classification/frontier state.
	replacement := sessionBatch("session-main", "claude-desktop", claudeSessionNow, "claude-sonnet-4-6")
	next := path + ".replacement"
	writeClaudeSession(t, next, replacement.Records...)
	if err := os.Rename(next, path); err != nil {
		t.Fatal(err)
	}
	r = RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow.Add(5*time.Second))
	selected := sessionSelected(t, cache, a, "", claudeSessionNow.Add(5*time.Second))
	if !r.Complete || selected.Model != "claude-sonnet-4-6" || selected.Origin != "desktop" {
		t.Fatal("replacement retained stale frontier")
	}
	// A different consent/profile scope cannot read the first profile's cache.
	other := a
	other.ProfileRef = strings.Repeat("b", 64)
	p, _ := ReadClaudeSessions(cache, other, "session-main", claudeSessionNow.Add(5*time.Second))
	if p.Selected != nil {
		t.Fatal("profile cache leaked")
	}
	RefreshClaudeSessions(context.Background(), root, cache, other, claudeSessionNow.Add(10*time.Second))
	if sessionSelected(t, cache, other, "session-main", claudeSessionNow.Add(10*time.Second)).SessionKey == oldKey {
		t.Fatal("profile key collision")
	}
	// Truncation to an empty file clears the selected session rather than keeping
	// the previous fields; exhaustive removal also prunes frontier/cursors.
	writeClaudeSession(t, path)
	r = RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow.Add(15*time.Second))
	p, _ = ReadClaudeSessions(cache, a, "session-main", claudeSessionNow.Add(15*time.Second))
	if !r.Complete || p.Selected != nil {
		t.Fatal("truncation kept selection")
	}
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	r = RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow.Add(20*time.Second))
	if !r.Complete || r.Availability != "not_detected" {
		t.Fatalf("empty discovery: %+v", r)
	}
	assertClaudeSessionCachePrivate(t, cache)
}

func TestClaudeSessionProjectionRecoveryAndAtomicRollback(t *testing.T) {
	a := sessionAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects", "p", "session-main.jsonl")
	batch := sessionBatch("session-main", "cli", claudeSessionNow.Add(-time.Minute), "claude-opus-5-5")
	writeClaudeSession(t, path, batch.Records...)
	ctx := context.Background()
	first := RefreshClaudeSessions(ctx, root, cache, a, claudeSessionNow)
	// Cross the shared record budget using ignored synthetic metadata, followed
	// by a new assistant. Partial cursor/frontier progress must survive restart.
	padding := bytes.Repeat([]byte("{\"type\":\"summary\"}\n"), 4096)
	row := sessionRow("raw-node", "assistant", "session-main", "claude-sonnet-4-6", "low", "standard", claudeSessionNow, nil)
	appendClaudeSession(t, path, append(padding, append(row, '\n')...))
	partial := RefreshClaudeSessions(ctx, root, cache, a, claudeSessionNow.Add(5*time.Second))
	if partial.Complete || !partial.CapturedAt.Equal(first.CapturedAt) || !bytes.Equal(partial.Snapshot, first.Snapshot) {
		t.Fatal("incomplete recovery replaced last good")
	}
	complete := RefreshClaudeSessions(ctx, root, cache, a, claudeSessionNow.Add(15*time.Second))
	if !complete.Complete || complete.BytesRead != int64(len(row)+1) {
		t.Fatalf("recovery did not resume: %+v", complete)
	}
	if sessionSelected(t, cache, a, "", claudeSessionNow.Add(15*time.Second)).Model != "claude-sonnet-4-6" {
		t.Fatal("recovered snapshot wrong")
	}
	next := sessionRow("raw-node-two", "raw-node", "session-main", "claude-opus-5-5", "high", "standard", claudeSessionNow, nil)
	appendClaudeSession(t, path, append(next, '\n'))
	reduce := ClaudeSessionReducer(a, claudeSessionNow.Add(20*time.Second))
	// Failure after decoding aborts the cursor and frontier together. Reducer error
	// text must never be serialized, and the next attempt replays exactly one row.
	failed := localusage.RefreshProjection(ctx, "claude", root, cache, a, claudeSessionNow.Add(20*time.Second), func(ctx context.Context, s localusage.ProjectionState, b localusage.ProjectionBatch) (localusage.ProjectionState, error) {
		state, err := reduce(ctx, s, b)
		if b.Final {
			return state, errors.New("PRIVATE-REDUCER-ERROR-CANARY")
		}
		return state, err
	})
	if !bytes.Equal(failed.Snapshot, complete.Snapshot) || !failed.CapturedAt.Equal(complete.CapturedAt) {
		t.Fatal("failed reducer published")
	}
	replayed := 0
	reduce = ClaudeSessionReducer(a, claudeSessionNow.Add(time.Minute))
	recovered := localusage.RefreshProjection(ctx, "claude", root, cache, a, claudeSessionNow.Add(time.Minute), func(ctx context.Context, s localusage.ProjectionState, b localusage.ProjectionBatch) (localusage.ProjectionState, error) {
		replayed += len(b.Lines)
		return reduce(ctx, s, b)
	})
	if !recovered.Complete || replayed != 1 || recovered.BytesRead != int64(len(next)+1) {
		t.Fatalf("rollback lost cursor consistency: %+v rows=%d", recovered, replayed)
	}
	assertClaudeSessionCachePrivate(t, cache)
}

func TestClaudeSessionProjectionConsentForgetAndNoPlugin(t *testing.T) {
	a := sessionAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects", "p", "session-main.jsonl")
	batch := sessionBatch("session-main", "cli", claudeSessionNow.Add(-time.Minute), "claude-opus-5-5")
	writeClaudeSession(t, path, batch.Records...)
	for _, tc := range []struct {
		mode            string
		allowed, denied bool
		want            string
	}{
		{"", false, false, "consent_required"}, {"", true, true, "denied"}, {"off", true, false, "off"}, {"invalid", true, false, "privacy_blocked"},
	} {
		access := a
		access.Allowed, access.Denied = tc.allowed, tc.denied
		t.Setenv("MODELPLAN_READERS", tc.mode)
		r := RefreshClaudeSessions(context.Background(), root, cache, access, claudeSessionNow)
		if r.Availability != tc.want || len(r.Snapshot) != 0 {
			t.Fatalf("admission: %+v", r)
		}
	}
	t.Setenv("MODELPLAN_READERS", "passive")
	r := RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow)
	if !r.Complete {
		t.Fatalf("passive blocked: %+v", r)
	}
	// No status-line or plugin snapshot exists. The collector emits a session-only
	// account with an empty quota list from the sanitized cache.
	p := Paths{Cache: cache, ClaudeSession: "session-main", ClaudeSessionAccess: &a}
	report := Read(p, claudeSessionNow)
	found := false
	for _, account := range report.Accounts {
		if account.Source == "claude-code" {
			found = true
			if account.Harness == nil || account.Harness.Model != "claude-opus-5-5" || len(account.Windows) != 0 {
				t.Fatal("session-only collector missing")
			}
		}
	}
	if !found {
		t.Fatal("collector depended on plugin")
	}
	before := assertClaudeSessionCachePrivate(t, cache)
	revoked := a
	revoked.Allowed = false
	if err := ForgetClaudeSessions(cache, revoked); err != nil {
		t.Fatal(err)
	}
	after := assertClaudeSessionCachePrivate(t, cache)
	for name, body := range before {
		if strings.Contains(filepath.Base(name), "gate") && after[name] != body {
			t.Fatal("Forget removed reservation")
		}
	}
	p1, _ := ReadClaudeSessions(cache, a, "session-main", claudeSessionNow.Add(time.Second))
	if p1.Selected != nil {
		t.Fatal("Forget resurrected cached selection")
	}
	again := RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow.Add(time.Second))
	if len(again.Snapshot) != 0 || again.BytesRead != 0 {
		t.Fatal("Forget bypassed local floor")
	}
}

func TestClaudeSessionProjectionPersistedResumeAndStreaming(t *testing.T) {
	a := sessionAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects", "p", "session-main.jsonl")
	batch := sessionBatch("session-main", "cli", claudeSessionNow.Add(-time.Minute), "claude-opus-5-5")
	branch := sessionRow("branch-a", "assistant", "session-main", "claude-sonnet-4-6", "low", "fast", claudeSessionNow.Add(-30*time.Second), nil)
	writeClaudeSession(t, path, append(batch.Records, branch)...)
	RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow)
	if sessionSelected(t, cache, a, "", claudeSessionNow).Model != "claude-sonnet-4-6" {
		t.Fatal("branch not selected")
	}
	resume, _ := json.Marshal(map[string]any{"type": "user", "uuid": "resume", "parentUuid": "assistant", "sessionId": "session-main", "timestamp": claudeSessionNow.Format(time.RFC3339Nano)})
	appendClaudeSession(t, path, append(resume, '\n'))
	RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow.Add(5*time.Second))
	if sessionSelected(t, cache, a, "", claudeSessionNow.Add(5*time.Second)).Model != "claude-opus-5-5" {
		t.Fatal("restart lost resumed ancestry")
	}
	one := sessionRow("raw-node", "resume", "session-main", "claude-opus-5-5", "high", "fast", claudeSessionNow, nil)
	appendClaudeSession(t, path, append(one, '\n'))
	first := RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow.Add(10*time.Second))
	// Repeated complete blocks are idempotent across engine/reducer instances.
	appendClaudeSession(t, path, append(one, '\n'))
	duplicate := RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow.Add(15*time.Second))
	if !duplicate.Complete || !bytes.Equal(first.Snapshot, duplicate.Snapshot) || !duplicate.CapturedAt.Equal(first.CapturedAt) {
		t.Fatal("duplicate freshened snapshot")
	}
	var conflict map[string]any
	if err := json.Unmarshal(one, &conflict); err != nil {
		t.Fatal(err)
	}
	conflict["effort"] = "low"
	conflict["message"].(map[string]any)["usage"].(map[string]any)["speed"] = "standard"
	two, _ := json.Marshal(conflict)
	appendClaudeSession(t, path, append(two, '\n'))
	r := RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow.Add(20*time.Second))
	selected := sessionSelected(t, cache, a, "", claudeSessionNow.Add(20*time.Second))
	if !r.Complete || selected.Model != "claude-opus-5-5" || selected.Effort != "" || selected.FastMode != nil {
		t.Fatal("cross-refresh conflict guessed fields")
	}
	// The optional hook cannot fill independent unknowns from the native cache.
	report := Report{Accounts: []Account{{Source: "claude-code", Harness: &Harness{Model: "hook-model", Effort: "max", FastMode: new(bool)}}}}
	applyClaudeSessions(&report, Paths{Cache: cache, ClaudeSessionAccess: &a}, claudeSessionNow.Add(20*time.Second))
	if report.Accounts[0].Harness.Model != "claude-opus-5-5" || report.Accounts[0].Harness.Effort != "" || report.Accounts[0].Harness.FastMode != nil {
		t.Fatal("hook filled native unknowns")
	}
	assertClaudeSessionCachePrivate(t, cache)
}

func TestClaudeSessionReducerUncertaintyAndBounds(t *testing.T) {
	a := sessionAccess(t)
	batch := sessionBatch("session-main", "cli", claudeSessionNow.Add(-time.Minute), "claude-opus-5-5")
	ref := strings.Repeat("c", 64)
	for _, uncertainty := range []string{"prefix", "ancestry", "filename", "discovery", "recovery", "bound"} {
		t.Run(uncertainty, func(t *testing.T) {
			reduce := ClaudeSessionReducer(a, claudeSessionNow)
			b := localusage.ProjectionBatch{FileRef: ref, SessionID: "session-main", Reset: "initial", Lines: batch.Records}
			switch uncertainty {
			case "prefix":
				b.PrefixOmitted = true
			case "ancestry":
				b.Lines = batch.Records[1:]
			case "filename":
				b.SessionID = "different-session"
			case "bound":
				b.Lines = nil
				for i := 0; i < 4096; i++ {
					b.Lines = append(b.Lines, sessionRow(fmt.Sprintf("raw-node-%d", i), "", "session-main", "claude-opus-5-5", "high", "standard", claudeSessionNow, nil))
				}
			}
			state, err := reduce(context.Background(), localusage.ProjectionState{}, b)
			if err != nil {
				t.Fatal(err)
			}
			if uncertainty == "bound" {
				state, err = reduce(context.Background(), state, localusage.ProjectionBatch{FileRef: ref, SessionID: "session-main", Lines: [][]byte{sessionRow("raw-node-overflow", "", "session-main", "claude-sonnet-4-6", "high", "standard", claudeSessionNow, nil)}})
				if err != nil {
					t.Fatal(err)
				}
			}
			state, err = reduce(context.Background(), state, localusage.ProjectionBatch{Final: true, DiscoveryComplete: uncertainty != "discovery", RecoveryComplete: uncertainty != "recovery", LiveFileRefs: []string{ref}})
			if err != nil || !state.Incomplete || len(state.Decoder) > 2<<20 || len(state.Snapshot) != 0 {
				t.Fatalf("uncertainty published: incomplete=%v decoder=%d err=%v", state.Incomplete, len(state.Decoder), err)
			}
			if bytes.Contains(state.Decoder, []byte("PRIVATE-")) || bytes.Contains(state.Decoder, []byte("raw-node")) {
				t.Fatal("raw frontier escaped")
			}
		})
	}
}

func TestClaudeSessionProgressCannotSelectAbandonedBranch(t *testing.T) {
	for _, incremental := range []bool{false, true} {
		t.Run(fmt.Sprintf("persisted=%v", incremental), func(t *testing.T) {
			a := sessionAccess(t)
			root, cache := t.TempDir(), t.TempDir()
			path := filepath.Join(root, "projects", "p", "session-main.jsonl")
			at := claudeSessionNow.Add(-time.Minute)
			batch := sessionBatch("session-main", "cli", at, "claude-opus-5-5")
			branch := sessionRow("branch-sonnet", "assistant", "session-main", "claude-sonnet-4-6", "low", "fast", at.Add(10*time.Second), nil)
			resume, _ := json.Marshal(map[string]any{"type": "user", "uuid": "resume-main", "parentUuid": "assistant", "sessionId": "session-main", "timestamp": at.Add(20 * time.Second).Format(time.RFC3339Nano)})
			batch.Records = append(batch.Records, branch, resume)
			progress, _ := json.Marshal(map[string]any{"type": "progress", "uuid": "delayed-progress", "parentUuid": "branch-sonnet", "sessionId": "session-main", "timestamp": at.Add(30 * time.Second).Format(time.RFC3339Nano)})
			before := ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow)
			if before.Selected == nil || before.Selected.Model != "claude-opus-5-5" {
				t.Fatal("resume setup failed")
			}
			if !incremental {
				batch.Records = append(batch.Records, progress)
				after := ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow)
				if !reflect.DeepEqual(before, after) {
					t.Fatal("progress changed resumed selection, fields, classification or observation")
				}
			} else {
				writeClaudeSession(t, path, batch.Records...)
				first := RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow)
				prior := sessionSelected(t, cache, a, "", claudeSessionNow)
				appendClaudeSession(t, path, append(progress, '\n'))
				// Each refresh constructs a new reducer and reloads the persisted frontier.
				after := RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow.Add(5*time.Second))
				selected := sessionSelected(t, cache, a, "", claudeSessionNow.Add(5*time.Second))
				if !after.Complete || !reflect.DeepEqual(prior, selected) || !bytes.Equal(first.Snapshot, after.Snapshot) || !after.ObservedAt.Equal(first.ObservedAt) || !after.CapturedAt.Equal(first.CapturedAt) {
					t.Fatal("persisted progress changed resumed state or capture age")
				}
				assertClaudeSessionCachePrivate(t, cache)
			}
		})
	}
}

func TestClaudeSessionExcludedRecordsCannotReclassifyMain(t *testing.T) {
	exclusions := []map[string]any{{"isSidechain": true, "agentId": "synthetic-worker"}, {"agentId": "synthetic-worker"}, {"teamName": "synthetic-team"}, {"isMeta": true}, {"isCompactSummary": true}, {"isApiErrorMessage": true}, {"error": "synthetic-error"}, {"synthetic": true}}
	for i, extra := range exclusions {
		for _, entrypoint := range []string{"sdk-ts", "claude-vscode"} {
			t.Run(fmt.Sprintf("%d/%s", i, entrypoint), func(t *testing.T) {
				a := sessionAccess(t)
				root, cache := t.TempDir(), t.TempDir()
				path := filepath.Join(root, "projects", "p", "session-main.jsonl")
				batch := sessionBatch("session-main", "cli", claudeSessionNow.Add(-time.Minute), "claude-opus-5-5")
				extra["entrypoint"], extra["sessionKind"] = entrypoint, "daemon-worker"
				model := "claude-sonnet-4-6"
				if extra["synthetic"] == true {
					model = "<synthetic>"
				}
				ignored := sessionRow("ignored-worker", "assistant", "session-main", model, "low", "fast", claudeSessionNow, extra)
				before := ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow)
				writeClaudeSession(t, path, batch.Records...)
				first := RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow)
				prior := sessionSelected(t, cache, a, "", claudeSessionNow)
				batch.Records = append(batch.Records, ignored)
				after := ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow)
				if !reflect.DeepEqual(before, after) {
					t.Error("excluded record changed main-session projection")
				}
				appendClaudeSession(t, path, append(ignored, '\n'))
				refreshed := RefreshClaudeSessions(context.Background(), root, cache, a, claudeSessionNow.Add(5*time.Second))
				projection, _ := ReadClaudeSessions(cache, a, "", claudeSessionNow.Add(5*time.Second))
				if !refreshed.Complete || projection.Selected == nil || !reflect.DeepEqual(prior, *projection.Selected) || !bytes.Equal(first.Snapshot, refreshed.Snapshot) || !refreshed.ObservedAt.Equal(first.ObservedAt) || !refreshed.CapturedAt.Equal(first.CapturedAt) {
					t.Error("excluded append reclassified persisted main session or changed capture age")
				}
				assertClaudeSessionCachePrivate(t, cache)
			})
		}
	}
}

func TestClaudeSessionProgressAncestryAndGenuineHeadlessClassification(t *testing.T) {
	a := sessionAccess(t)
	batch := sessionBatch("session-main", "cli", claudeSessionNow.Add(-time.Minute), "claude-opus-5-5")
	progress, _ := json.Marshal(map[string]any{"type": "progress", "uuid": "progress-link", "parentUuid": "assistant", "sessionId": "session-main", "timestamp": claudeSessionNow.Format(time.RFC3339Nano)})
	// An eligible main record may point through an otherwise ignored progress node.
	user, _ := json.Marshal(map[string]any{"type": "user", "uuid": "user-through-progress", "parentUuid": "progress-link", "sessionId": "session-main", "timestamp": claudeSessionNow.Format(time.RFC3339Nano)})
	batch.Records = append(batch.Records, progress, user)
	r := ProjectClaudeSessions(a, []ClaudeSessionBatch{batch}, "", claudeSessionNow)
	if r.Selected == nil || r.Selected.Model != "claude-opus-5-5" {
		t.Fatal("progress broke valid main ancestry")
	}
	for _, classification := range []map[string]any{{"entrypoint": "sdk-ts"}, {"sessionKind": "daemon"}, {"sessionKind": "daemon-worker"}} {
		row := sessionRow("headless-main", "user-through-progress", "session-main", "claude-sonnet-4-6", "low", "fast", claudeSessionNow, classification)
		headless := batch
		headless.Records = append(append([][]byte{}, batch.Records...), row)
		projected := ProjectClaudeSessions(a, []ClaudeSessionBatch{headless}, "", claudeSessionNow)
		if projected.Selected != nil {
			t.Fatal("genuine main-session SDK/daemon became interactive")
		}
	}
}

func TestClaudeSessionProductionAdmissionRefreshCacheAndForget(t *testing.T) {
	for _, custom := range []bool{false, true} {
		t.Run(fmt.Sprintf("custom=%v", custom), func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_NATIVE", "")
			t.Setenv("MODELPLAN_HISTORY", "")
			t.Setenv("MODELPLAN_READERS", "passive")
			t.Setenv("CLAUDE_CONFIG_DIR", "")
			t.Setenv("CLAUDE_CODE_SESSION_ID", "session-main")
			home, _ := os.UserHomeDir()
			root := filepath.Join(home, ".claude")
			if custom {
				root = filepath.Join(home, "custom-claude")
				t.Setenv("CLAUDE_CONFIG_DIR", root)
			}
			cache := t.TempDir()
			path := filepath.Join(root, "projects", "p", "session-main.jsonl")
			batch := sessionBatch("session-main", "cli", claudeSessionNow.Add(-time.Minute), "claude-opus-5-5")
			writeClaudeSession(t, path, batch.Records...)
			paths := func() Paths { return ProductionPaths(cache, "1.0.0") }
			before := paths()
			if before.ClaudeSessionAccess != nil || NativeDue(before, claudeSessionNow) {
				t.Fatal("production local reader admitted before consent")
			}
			productionConsent(t, "claude", true)
			p := paths()
			if p.ClaudeSessionAccess == nil || p.ClaudeSessionRoot != root || p.ClaudeSessionAccess.Privacy != "passive" {
				t.Fatal("missing production passive-session admission")
			}
			if _, err := os.Stat(localusage.SettingsPath(home)); !os.IsNotExist(err) {
				t.Fatal("read-only constructor created identity key")
			}
			if len(p.ReaderAccess.Grants) != 0 || !NativeDue(p, claudeSessionNow) {
				t.Fatal("session admission depended on credential admission")
			}
			keylessPaths := p
			// Both vendor/Keychain adapters would fail the test if the local route
			// attempted account collection. No synthetic login or plugin is installed.
			vendorCalls, keychainCalls := 0, 0
			oldClient, oldSecurity := nativeClient, claudeSecurity
			nativeClient = &http.Client{Transport: productionTransport(func(*http.Request) (*http.Response, error) {
				vendorCalls++
				return nil, errors.New("unexpected vendor call")
			})}
			claudeSecurity = func(context.Context, string, ...string) (keychain.ProcessResult, error) {
				keychainCalls++
				return keychain.ProcessResult{}, errors.New("unexpected Keychain call")
			}
			t.Cleanup(func() { nativeClient = oldClient; claudeSecurity = oldSecurity })
			if err := RefreshNative(context.Background(), p, claudeSessionNow); err != nil {
				t.Fatal(err)
			}
			p = paths()
			if p.ClaudeSessionAccess == nil || len(p.ClaudeSessionAccess.Key) != 32 || !claudeKeyedRef(p.ClaudeSessionAccess.ProfileRef) {
				t.Fatal("shared installation key/profile not admitted")
			}
			selected := sessionSelected(t, cache, *p.ClaudeSessionAccess, "session-main", claudeSessionNow)
			if selected.Attribution != "current-thread" {
				t.Fatal("production caller not selected")
			}
			prior := assertClaudeSessionCachePrivate(t, cache)
			report := ReadPermitted(p, claudeSessionNow.Add(time.Second))
			found := false
			for _, account := range report.Accounts {
				if account.Source == "claude-code" && account.Harness != nil && account.Harness.Model == "claude-opus-5-5" {
					found = true
				}
			}
			if !found || vendorCalls != 0 || keychainCalls != 0 {
				t.Fatal("production cache report missing or invoked account adapters")
			}
			if !reflect.DeepEqual(prior, assertClaudeSessionCachePrivate(t, cache)) {
				t.Fatal("production cache-only report wrote state")
			}
			if NativeDue(paths(), claudeSessionNow.Add(time.Second)) {
				t.Fatal("production scheduling ignored projection floor")
			}
			if !NativeDue(paths(), claudeSessionNow.Add(5*time.Second)) {
				t.Fatal("network quota floor blocked local projection")
			}
			// Keychain denial does not revoke local transcript consent.
			if err := consent.Deny(consent.Path(), "claude", "keychain"); err != nil {
				t.Fatal(err)
			}
			if paths().ClaudeSessionAccess == nil {
				t.Fatal("Keychain Deny blocked credential-free session")
			}
			t.Setenv("MODELPLAN_READERS", "automatic")
			automatic := paths()
			if automatic.ClaudeSessionAccess == nil {
				t.Fatal("Automatic mode lost local session admission")
			}
			if err := RefreshNative(context.Background(), automatic, claudeSessionNow.Add(5*time.Second)); err != nil {
				t.Fatal(err)
			}
			if vendorCalls != 0 || keychainCalls != 0 {
				t.Fatal("local refresh bypassed account/Keychain denial")
			}
			t.Setenv("MODELPLAN_READERS", "passive")
			// Include the independent account attempt gates in the retained set.
			prior = assertClaudeSessionCachePrivate(t, cache)
			// Even previously constructed Paths must lose access after revocation.
			productionConsent(t, "claude", false)
			if NativeDue(p, claudeSessionNow.Add(time.Hour)) || NativeDue(keylessPaths, claudeSessionNow.Add(time.Hour)) {
				t.Fatal("stale production grant scheduled reads")
			}
			projected, _ := ReadClaudeSessions(cache, *p.ClaudeSessionAccess, "session-main", claudeSessionNow)
			if projected.Selected != nil {
				t.Fatal("stale production access exposed a revoked snapshot")
			}
			if err := ForgetTool(paths(), "claude"); err != nil {
				t.Fatal(err)
			}
			productionConsent(t, "claude", true)
			fresh := paths()
			projected, _ = ReadClaudeSessions(cache, *fresh.ClaudeSessionAccess, "session-main", claudeSessionNow.Add(time.Second))
			if projected.Selected != nil || NativeDue(fresh, claudeSessionNow.Add(time.Second)) {
				t.Fatal("Forget/reconnect restored snapshot or reset projection gate")
			}
			after := assertClaudeSessionCachePrivate(t, cache)
			for name, body := range prior {
				if strings.Contains(filepath.Base(name), "gate") && after[name] != body {
					t.Fatal("production Forget changed projection gate")
				}
			}
		})
	}
}

func TestClaudeSessionProductionAdmissionVetoes(t *testing.T) {
	for _, tc := range []struct{ name, mode, denial, preferred, min, root string }{
		{name: "off", mode: "off"}, {name: "invalid privacy", mode: "invalid"}, {name: "local denied", denial: consent.Local}, {name: "disabled route", preferred: "off"}, {name: "helper route", preferred: "codexbar"}, {name: "requires update", preferred: "native", min: "99.0.0"}, {name: "relative root", root: "relative"}, {name: "symlink root", root: "symlink"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_READERS", tc.mode)
			t.Setenv("MODELPLAN_NATIVE", "")
			t.Setenv("MODELPLAN_HISTORY", "")
			t.Setenv("CLAUDE_CONFIG_DIR", "")
			home, _ := os.UserHomeDir()
			root := filepath.Join(home, ".claude")
			if tc.root == "symlink" {
				if err := os.Symlink(t.TempDir(), root); err != nil {
					t.Fatal(err)
				}
			} else if err := os.MkdirAll(root, 0700); err != nil {
				t.Fatal(err)
			}
			if tc.root == "relative" {
				t.Setenv("CLAUDE_CONFIG_DIR", "relative")
			}
			productionConsent(t, "claude", true)
			if tc.denial != "" {
				if err := consent.Deny(consent.Path(), "claude", tc.denial); err != nil {
					t.Fatal(err)
				}
			}
			if tc.preferred != "" {
				old := loadReaderCatalogue
				loadReaderCatalogue = func(string) *detect.Catalogue {
					return &detect.Catalogue{Detectors: []detect.Entry{{ProviderID: "claude", ReaderID: "native:claude", Preferred: tc.preferred, MinCLI: tc.min}}}
				}
				t.Cleanup(func() { loadReaderCatalogue = old })
			}
			p := ProductionPaths(t.TempDir(), "1.0.0")
			if p.ClaudeSessionAccess != nil {
				t.Fatal("vetoed source admitted")
			}
		})
	}
}
