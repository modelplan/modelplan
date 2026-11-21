// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"
)

// G3-147: reading an existing identity reference must not touch the observed directory. A lock
// file created and removed on every read changed the directory the app-server watches, so each
// snapshot woke the watcher into the next one and the idle engine never stopped reading.
func TestG3147IdentityReadsLeaveObservedDirectoryAlone(t *testing.T) {
	cache := t.TempDir()
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	ref := assignSubscription(cache, "synthetic-basis", "synthetic-identity", now)
	hash := readerHash(cache, "profile", "synthetic-profile")
	if ref == "" || hash == "" {
		t.Fatalf("setup: ref %q hash %q", ref, hash)
	}
	observed := filepath.Join(cache, "observed")
	before, err := os.Stat(observed)
	if err != nil {
		t.Fatal(err)
	}
	// Coarse file systems keep one timestamp for a while; age the directory so any change shows.
	old := before.ModTime().Add(-time.Hour)
	if err := os.Chtimes(observed, old, old); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 3; i++ {
		if got := assignSubscription(cache, "synthetic-basis", "synthetic-identity", now.Add(time.Duration(i)*time.Minute)); got != ref {
			t.Fatalf("read %d: reference changed %q -> %q", i, ref, got)
		}
		if got := readerHash(cache, "profile", "synthetic-profile"); got != hash {
			t.Fatalf("read %d: reader hash changed %q -> %q", i, hash, got)
		}
	}
	after, err := os.Stat(observed)
	if err != nil {
		t.Fatal(err)
	}
	if !after.ModTime().Equal(old) {
		t.Fatalf("identity reads changed the observed directory (%v -> %v)", old, after.ModTime())
	}
	// A held lock (another process writing) no longer blanks a reference that needs no write.
	lock := filepath.Join(observed, "subscriptions.lock")
	if err := os.WriteFile(lock, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	if got := assignSubscription(cache, "synthetic-basis", "synthetic-identity", now); got != ref {
		t.Fatalf("fresh reference unavailable while the lock is held: %q", got)
	}
	if got := readerHash(cache, "profile", "synthetic-profile"); got != hash {
		t.Fatalf("reader hash unavailable while the lock is held: %q", got)
	}
	// A reference that is due its hourly refresh still takes the lock (and so waits for it).
	if got := assignSubscription(cache, "synthetic-basis", "synthetic-identity", now.Add(2*time.Hour)); got != "" {
		t.Fatalf("stale reference refreshed without the lock: %q", got)
	}
}

// G3-147: the same cached reader states give the same report every time. The managed readers
// were visited in map order, so two identical reads listed their sources in different orders
// and the app-server published a "changed" snapshot on every read.
func TestG3147ManagedReaderSourcesHaveOneOrder(t *testing.T) {
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "")
	cache := t.TempDir()
	dir := t.TempDir()
	p := Paths{Cache: cache, ConnectionsFile: filepath.Join(dir, "connections.json"), CodexBarFile: filepath.Join(dir, "codexbar.json"),
		ReaderAccess: &ReaderAccess{Grants: map[string]ReaderGrant{}}}
	var managed []string
	for _, provider := range nativeProviderIDs() {
		if nativeReaders[provider].Managed == nil {
			continue
		}
		if _, pending := PolicyPending(provider); pending {
			continue
		}
		managed = append(managed, provider)
		p.ReaderAccess.Grants[provider] = ReaderGrant{SavedLogin: true, Generation: "synthetic-" + provider}
		s := &readerState{SchemaVersion: 1, Provider: provider, Entries: []readerEntry{{ProfileKey: "synthetic", Status: "unavailable", ErrorCode: "file_missing"}}}
		if err := saveReaderState(cache, s); err != nil {
			t.Fatal(err)
		}
	}
	if len(managed) < 2 {
		t.Skipf("needs two managed readers, have %v", managed)
	}
	order := func() []string {
		var r Report
		applyNative(&r, p, claudeTestNow)
		var sources []string
		for _, s := range r.Sources {
			sources = append(sources, s.Source)
		}
		return sources
	}
	first := order()
	if len(first) < 2 {
		t.Fatalf("setup: managed sources missing: %v", first)
	}
	for i := 0; i < 30; i++ {
		if got := order(); !reflect.DeepEqual(got, first) {
			t.Fatalf("read %d listed sources %v, first read %v", i, got, first)
		}
	}
}
