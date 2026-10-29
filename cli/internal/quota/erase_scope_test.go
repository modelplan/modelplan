// SPDX-License-Identifier: MIT
package quota

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestAccountScopeCleanupKeepsIndependentKeyValuesAndBudget(t *testing.T) {
	for _, forget := range []bool{false, true} {
		t.Run(map[bool]string{false: "deny", true: "forget"}[forget], func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			cache := t.TempDir()
			p := Paths{Cache: cache}
			now := time.Now().UTC()
			loginRef := assignSubscription(cache, "kimi-code-login:china", "synthetic-login", now)
			keyRef := assignSubscription(cache, "api-key", "synthetic-explicit-key", now)
			if loginRef == "" || keyRef == "" {
				t.Fatal("identity setup failed")
			}
			state := &readerState{SchemaVersion: 1, Provider: "kimi", NextAttemptAt: now.Add(time.Hour), Entries: []readerEntry{{ProfileKey: "synthetic", Status: "ok", Account: &Account{Subscription: &Binding{Ref: loginRef, Status: "verified", Basis: "kimi-code-login:china"}}}}}
			if err := saveReaderState(cache, state); err != nil {
				t.Fatal(err)
			}
			native, _ := json.Marshal(nativeSnap{SchemaVersion: 1, Providers: []codexbarEntry{{Provider: "kimi", Status: "ok", SubscriptionRef: keyRef}}})
			path := filepath.Join(cache, "observed", "native.json")
			if err := writeAtomic(path, native); err != nil {
				t.Fatal(err)
			}
			if err := reserveReaderAttempt(cache, "kimi", state.NextAttemptAt); err != nil {
				t.Fatal(err)
			}
			if err := EraseScope(p, consent.ScopeKimiAccountUsageSavedLogin, forget); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(readerPath(cache, "kimi")); !os.IsNotExist(err) {
				t.Fatal("saved-login capture survived", err)
			}
			after, _ := os.ReadFile(path)
			if string(after) != string(native) {
				t.Fatal("saved-login revoke erased independent key reading")
			}
			if readerAttemptDue(cache, "kimi", now.Add(10*time.Minute)) {
				t.Fatal("cleanup reset shared budget")
			}
			if ref := lookupSubscription(cache, "api-key", "synthetic-explicit-key"); ref != keyRef {
				t.Fatal("other scope identity erased")
			}
			ref := lookupSubscription(cache, "kimi-code-login:china", "synthetic-login")
			if forget && ref != "" || !forget && ref != loginRef {
				t.Fatal("deny/Forget identity semantics", ref, forget)
			}
		})
	}
}

func TestRetiredScopeErasesCachesWithoutCompiledReader(t *testing.T) {
	for _, forget := range []bool{false, true} {
		t.Run(map[bool]string{false: "deny", true: "forget"}[forget], func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			cache := t.TempDir()
			now := time.Now().UTC()
			ref := assignSubscription(cache, "retired-auth", "synthetic-retired-account", now)
			s := &readerState{SchemaVersion: 1, Provider: "retired-tool", NextAttemptAt: now.Add(time.Hour), Entries: []readerEntry{{Status: "ok", Account: &Account{Subscription: &Binding{Ref: ref, Status: "verified", Basis: "retired-auth"}}}}}
			if err := saveReaderState(cache, s); err != nil {
				t.Fatal(err)
			}
			native, _ := json.Marshal(nativeSnap{SchemaVersion: 1, Providers: []codexbarEntry{{Provider: "retired-tool", SubscriptionRef: ref}, {Provider: "copilot", Status: "ok"}}})
			if err := writeAtomic(nativePath(cache), native); err != nil {
				t.Fatal(err)
			}
			if err := EraseScope(Paths{Cache: cache}, "retired-tool.account_usage.saved_login", forget); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(readerPath(cache, "retired-tool")); !os.IsNotExist(err) {
				t.Fatal("retired reader capture survived", err)
			}
			remaining := loadNative(cache)
			if remaining == nil || len(remaining.Providers) != 1 || remaining.Providers[0].Provider != "copilot" {
				t.Fatal("retired aggregate capture survived or other provider erased", remaining)
			}
			if readerAttemptDue(cache, "retired-tool", now.Add(10*time.Minute)) {
				t.Fatal("retired cache cleanup lost reservation")
			}
			identity := lookupSubscription(cache, "retired-auth", "synthetic-retired-account")
			if forget && identity != "" || !forget && identity != ref {
				t.Fatal("retired identity cleanup semantics", identity, forget)
			}
		})
	}
	t.Run("local", func(t *testing.T) {
		t.Setenv("HOME", t.TempDir())
		cache := t.TempDir()
		dir := filepath.Join(cache, "observed")
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
		stale := filepath.Join(dir, "history-v1-retired-tool-"+strings.Repeat("a", 64)+".json")
		other := filepath.Join(dir, "history-v1-codex-"+strings.Repeat("a", 64)+".json")
		for _, file := range []string{stale, other} {
			if err := os.WriteFile(file, []byte(`{}`), 0600); err != nil {
				t.Fatal(err)
			}
		}
		if err := EraseScope(Paths{Cache: cache}, "retired-tool.local_history", true); err != nil {
			t.Fatal(err)
		}
		if _, err := os.Stat(stale); !os.IsNotExist(err) {
			t.Fatal("retired local history survived", err)
		}
		if _, err := os.Stat(other); err != nil {
			t.Fatal("other tool history erased", err)
		}
	})
}

func TestHistoryForgetPreservesHyphenatedNeighbor(t *testing.T) {
	for _, tool := range []string{"retired", "grok"} {
		t.Run(tool, func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			cache := t.TempDir()
			dir := filepath.Join(cache, "observed")
			if err := os.MkdirAll(dir, 0700); err != nil {
				t.Fatal(err)
			}
			hash := strings.Repeat("a", 64)
			target := filepath.Join(dir, "history-v1-"+tool+"-"+hash+".json")
			neighbor := filepath.Join(dir, "history-v1-"+tool+"-other-"+hash+".json")
			for _, file := range []string{target, neighbor} {
				if err := os.WriteFile(file, []byte(`{}`), 0600); err != nil {
					t.Fatal(err)
				}
			}
			if err := EraseScope(Paths{Cache: cache}, tool+".local_history", true); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(target); !os.IsNotExist(err) {
				t.Fatal("target history survived", err)
			}
			if _, err := os.Stat(neighbor); err != nil {
				t.Fatal("neighboring tool history erased", err)
			}
		})
	}
}
