// SPDX-License-Identifier: MIT
package speed

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestActivityTransitionsAndRecordExpiry(t *testing.T) {
	now := time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC)
	for _, tc := range []struct {
		source, body, phase string
		grace               time.Duration
	}{
		{"claude-code", `"type":"user","message":{"content":"[Request interrupted by user]"}`, "finished", 0},
		{"claude-code", `"type":"assistant","message":{}`, "model", 90 * time.Second},
		{"claude-code", `"type":"assistant","message":{"stop_reason":"tool_use"}`, "tool", 5 * time.Minute},
		{"codex", `"type":"event_msg","payload":{"type":"turn_aborted"}`, "finished", 0},
		{"codex", `"type":"response_item","payload":{"type":"function_call"}`, "tool", 5 * time.Minute},
		{"codex", `"type":"event_msg","payload":{"type":"task_started"}`, "model", 90 * time.Second},
	} {
		t.Run(tc.source+tc.phase, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "session.jsonl")
			body := fmt.Sprintf("{\"timestamp\":%q,%s}\n", now.Format(time.RFC3339Nano), tc.body)
			if err := os.WriteFile(path, []byte(body), 0600); err != nil {
				t.Fatal(err)
			}
			os.Chtimes(path, now, now)
			o := NewActivityObserver()
			logs := []LiveLog{{Path: path, Source: tc.source}}
			got := o.Observe(context.Background(), logs, nil, now)
			if len(got) != 1 || got[0].Phase != tc.phase || !got[0].RecordAt.Equal(now) {
				t.Fatalf("activity: %+v", got)
			}
			if tc.grace > 0 {
				// Unchanged files expire on cache hits too.
				got = o.Observe(context.Background(), logs, nil, now.Add(tc.grace))
				if len(got) != 1 || got[0].Phase != "finished" {
					t.Fatalf("expired: %+v", got)
				}
				// Touching a file cannot renew the original record's grace.
				os.Chtimes(path, now.Add(tc.grace), now.Add(tc.grace))
				got = o.Observe(context.Background(), logs, nil, now.Add(tc.grace))
				if len(got) != 1 || got[0].Phase != "finished" {
					t.Fatalf("mtime renewed record: %+v", got)
				}
			}
		})
	}
}

func TestActivityBindingCannotReviveAnEarlierGrantEpoch(t *testing.T) {
	state := consent.Empty()
	state.StoreEpoch = "0123456789abcdef0123456789abcdef"
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
	admission := consent.NewAdmission(state, consent.Automatic)
	cache := t.TempDir()
	ledger := PerfLedger{SchemaVersion: 1, Since: time.Now(), Sessions: []PerfSession{
		{Source: "codex", Key: "current", SubscriptionRef: "aaaaaaaaaaaaaaaa", GrantEpoch: currentEpoch(admission, "codex")},
		{Source: "codex", Key: "legacy", SubscriptionRef: "bbbbbbbbbbbbbbbb"},
	}}
	data, err := json.Marshal(ledger)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.MkdirAll(filepath.Dir(PerfPath(cache)), 0700); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(PerfPath(cache), data, 0600); err != nil {
		t.Fatal(err)
	}
	got := ExistingActivityBindings(cache, admission)
	if len(got) != 1 || got[0].Key != "current" {
		t.Fatalf("unadmitted binding: %+v", got)
	}
	state.Revoked[consent.ScopeCodexLocalHistory] = 2
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion, At: time.Now()}
	if got = ExistingActivityBindings(cache, consent.NewAdmission(state, consent.Automatic)); len(got) != 0 {
		t.Fatal("old activity binding survived revoke/regrant")
	}
}

func TestActivityPartialMalformedAndCachedTail(t *testing.T) {
	now := time.Now().UTC()
	path := filepath.Join(t.TempDir(), "s.jsonl")
	valid := fmt.Sprintf("{\"timestamp\":%q,\"type\":\"event_msg\",\"payload\":{\"type\":\"turn_aborted\"}}\n{\"type\":", now.Format(time.RFC3339Nano))
	os.WriteFile(path, []byte(valid), 0600)
	os.Chtimes(path, now, now)
	o := NewActivityObserver()
	logs := []LiveLog{{Path: path, Source: "codex"}}
	got := o.Observe(context.Background(), logs, nil, now)
	if len(got) != 1 || got[0].Phase != "finished" {
		t.Fatalf("partial must not hide terminal record: %+v", got)
	}
	// Same mtime/size must use the cached verdict, rather than reopening this file.
	os.WriteFile(path, []byte("x"+valid[1:]), 0600)
	os.Chtimes(path, now, now)
	got = o.Observe(context.Background(), logs, nil, now)
	if len(got) != 1 || got[0].Phase != "finished" {
		t.Fatal("cache reopened unchanged signature")
	}
	os.WriteFile(path, []byte("malformed\n"), 0600)
	os.Chtimes(path, now, now)
	got = o.Observe(context.Background(), logs, nil, now)
	if len(got) != 1 || got[0].Phase != "fallback" {
		t.Fatalf("fallback: %+v", got)
	}
	got = o.Observe(context.Background(), logs, nil, now.Add(30*time.Second))
	if len(got) != 1 || got[0].Phase != "finished" {
		t.Fatalf("fallback expiry: %+v", got)
	}
}

func TestZCodeOverlappingTurns(t *testing.T) {
	now := time.Now().UTC()
	dir := t.TempDir()
	path := filepath.Join(dir, "z.jsonl")
	line := func(event, turn string) string {
		return fmt.Sprintf("{\"timestamp\":%q,\"event\":%q,\"sessionId\":\"synthetic\",\"turnId\":%q}\n", now.Format(time.RFC3339Nano), event, turn)
	}
	os.WriteFile(path, []byte(line("turn.started", "a")+line("turn.started", "b")+line("turn.completed", "a")), 0600)
	os.Chtimes(path, now, now)
	o := NewActivityObserver()
	logs := []LiveLog{{Path: path, Source: "zcode"}}
	got := o.Observe(context.Background(), logs, nil, now)
	if len(got) != 1 || got[0].Phase != "model" {
		t.Fatalf("turn b remains active: %+v", got)
	}
	f, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0600)
	f.WriteString(line("turn.failed", "b"))
	f.Close()
	os.Chtimes(path, now, now)
	got = o.Observe(context.Background(), logs, nil, now)
	if len(got) != 1 || got[0].Phase != "finished" {
		t.Fatalf("both ended: %+v", got)
	}
}

func TestActivityRequiresExactUnambiguousSessionBinding(t *testing.T) {
	now := time.Now().UTC()
	dir := t.TempDir()
	logs := []LiveLog{}
	for _, name := range []string{"one", "two"} {
		p := filepath.Join(dir, name+".jsonl")
		os.WriteFile(p, []byte(fmt.Sprintf("{\"timestamp\":%q,\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\"}}\n", now.Format(time.RFC3339Nano))), 0600)
		os.Chtimes(p, now, now)
		logs = append(logs, LiveLog{Path: p, Source: "codex"})
	}
	b := []ActivityBinding{{Source: "codex", Key: fileKey(logs[0].Path), SubscriptionRef: "aaaaaaaaaaaaaaaa", Verified: true}, {Source: "codex", Key: fileKey(logs[1].Path), SubscriptionRef: "bbbbbbbbbbbbbbbb", Verified: true}}
	o := NewActivityObserver()
	got := o.Observe(context.Background(), logs, b, now)
	if len(got) != 2 || got[0].SubscriptionRef == got[1].SubscriptionRef {
		t.Fatalf("accounts collapsed: %+v", got)
	}
	b[0].NotBefore = now.Add(time.Second)
	got = o.Observe(context.Background(), logs, b, now)
	for _, v := range got {
		if v.SessionKey == fileKey(logs[0].Path) && v.SubscriptionRef != "" {
			t.Fatal("a pre-grant record acquired the new binding")
		}
		if v.SessionKey == fileKey(logs[1].Path) && v.SubscriptionRef != "bbbbbbbbbbbbbbbb" {
			t.Fatal("an unrelated current binding was lost")
		}
	}
	b[0].NotBefore = time.Time{}
	b = append(b, ActivityBinding{Source: "codex", Key: fileKey(logs[0].Path), SubscriptionRef: "cccccccccccccccc", Verified: true})
	got = o.Observe(context.Background(), logs, b, now)
	for _, v := range got {
		if v.SessionKey == fileKey(logs[0].Path) && v.SubscriptionRef != "" {
			t.Fatal("ambiguous binding exported")
		}
	}
}
