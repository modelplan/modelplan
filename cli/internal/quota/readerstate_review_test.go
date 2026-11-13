package quota

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"testing"
	"time"
)

func TestManagedBetaSurvivesSerializedSuccessStaleUnavailable(t *testing.T) {
	isolateHome(t)
	p := nativePaths(t)
	now := time.Date(2026, 10, 27, 12, 0, 0, 0, time.UTC)
	for _, tc := range []struct {
		name, status string
		age          time.Duration
		account      bool
	}{
		{"success", "ok", 0, true}, {"stale", "ok", 2 * time.Hour, true},
		{"unavailable-last-good", "unavailable", 2 * time.Hour, true},
		{"unavailable-no-account", "unavailable", 0, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			e := readerEntry{ProfileKey: "synthetic-key", Status: tc.status}
			if tc.account {
				e.Account = &Account{Source: "native:synthetic", ObservedAt: now, Windows: []Window{}}
			}
			if err := saveReaderState(p.Cache, &readerState{SchemaVersion: 1, Provider: "synthetic", Entries: []readerEntry{e}}); err != nil {
				t.Fatal(err)
			}
			r := Report{}
			applyManaged(&r, p, "synthetic", now.Add(tc.age))
			for i := range r.Accounts {
				Evaluate(&r.Accounts[i], now.Add(tc.age))
			}
			b, err := json.Marshal(r)
			if err != nil {
				t.Fatal(err)
			}
			var encoded struct {
				Accounts []struct {
					Beta  bool `json:"beta"`
					Stale bool `json:"stale"`
				}
				Sources []struct {
					Beta bool `json:"beta"`
				}
			}
			if json.Unmarshal(b, &encoded) != nil || len(encoded.Sources) != 1 || !encoded.Sources[0].Beta {
				t.Fatal("source beta lost in JSON")
			}
			if tc.account && (len(encoded.Accounts) != 1 || !encoded.Accounts[0].Beta || encoded.Accounts[0].Stale != (tc.age > staleAfter)) {
				t.Fatal("account beta/freshness lost in JSON")
			}
		})
	}
	if err := os.WriteFile(readerPath(p.Cache, "synthetic"), []byte("{"), 0600); err != nil {
		t.Fatal(err)
	}
	r := Report{}
	applyManaged(&r, p, "synthetic", now)
	if len(r.Sources) != 1 || !r.Sources[0].Beta {
		t.Fatal("cache error lost beta")
	}
}

func TestManagedForgetPreservesFloorAcrossNewGrantAndRestart(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "")
	p := nativePaths(t)
	now := time.Date(2026, 10, 27, 12, 0, 0, 0, time.UTC)
	calls := 0
	const provider = "synthetic-floor"
	nativeReaders[provider] = &nativeReader{Managed: func(context.Context, *http.Client, readerContext) readerOutcome {
		calls++
		return readerOutcome{Entry: readerEntry{Status: "ok", Account: &Account{Source: "native:" + provider, ObservedAt: now, Windows: []Window{}}}}
	}}
	defer delete(nativeReaders, provider)
	root := t.TempDir()
	p.ReaderAccess = &ReaderAccess{Grants: map[string]ReaderGrant{provider: {SavedLogin: true, Generation: "grant-A", Profiles: []ReaderProfile{{Root: root}}}}}
	if err := refreshManaged(context.Background(), p, provider, now); err != nil {
		t.Fatal(err)
	}
	if err := ForgetReader(p.Cache, provider); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(readerPath(p.Cache, provider)); !os.IsNotExist(err) {
		t.Fatal("personal reading retained")
	}
	// Reconstruct the caller and grant as a restarted process would; no reading
	// or transient state participates in the independent reservation decision.
	restarted := Paths{Cache: p.Cache, ReaderAccess: &ReaderAccess{Grants: map[string]ReaderGrant{provider: {SavedLogin: true, Generation: "grant-B", Profiles: []ReaderProfile{{Root: root}}}}}}
	for _, seconds := range []int{60, 299} {
		at := now.Add(time.Duration(seconds) * time.Second)
		if managedDue(restarted, provider, at) {
			t.Fatal("Forget reset due gate")
		}
		if err := refreshManaged(context.Background(), restarted, provider, at); err != nil {
			t.Fatal(err)
		}
	}
	if calls != 1 {
		t.Fatal("Forget/reconnect bypassed provider floor")
	}
	if err := refreshManaged(context.Background(), restarted, provider, now.Add(300*time.Second)); err != nil {
		t.Fatal(err)
	}
	if calls != 2 {
		t.Fatal("reservation never released")
	}
	// Migration: preserve old combined-file reservations when first forgetting.
	if err := os.Remove(readerAttemptPath(p.Cache, provider)); err != nil {
		t.Fatal(err)
	}
	if err := ForgetReader(p.Cache, provider); err != nil {
		t.Fatal(err)
	}
	if readerAttemptDue(p.Cache, provider, now.Add(301*time.Second)) {
		t.Fatal("legacy reservation lost during purge")
	}
}
