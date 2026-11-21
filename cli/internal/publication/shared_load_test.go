// SPDX-License-Identifier: MIT
package publication

import (
	"context"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/store"
)

// WP-17 (Fable perf plan 5.1 row 1): the engine verified and parsed the 163 KB publication
// up to nine times per view. LoadShared verifies and parses it once while the cache files are
// unchanged, and again after any change to them.
func TestLoadSharedVerifiesAnUnchangedPublicationOnce(t *testing.T) {
	f := &fakeServer{objects: map[string][]byte{}, hits: map[string]int{}}
	publish(f, "first", 50, false)
	srv := httptest.NewServer(f)
	defer srv.Close()
	t.Setenv("MODELPLAN_CACHE", t.TempDir())
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	c, err := New(srv.URL, st, "test")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Date(2026, 10, 11, 0, 0, 0, 0, time.UTC)
	c.Now = func() time.Time { return now }
	ctx := context.Background()
	if _, _, err := LoadShared(st); err != ErrNoData {
		t.Fatalf("empty cache: %v", err)
	}
	if _, err := c.Sync(ctx, false); err != nil {
		t.Fatal(err)
	}
	settle := func() {
		past := time.Now().Add(-time.Hour)
		_ = filepath.Walk(st.Dir, func(path string, info os.FileInfo, err error) error {
			if err == nil && !info.IsDir() {
				_ = os.Chtimes(path, past, past)
			}
			return nil
		})
	}
	settle()
	first, _, err := LoadShared(st)
	if err != nil || *first.Model("m1").Rec().Ability != 50 {
		t.Fatalf("load: %v", err)
	}
	again, _, _ := LoadShared(st)
	if again != first {
		t.Fatal("an unchanged publication was verified and parsed again")
	}
	if plain, _, _ := Load(st); plain == first || *plain.Model("m1").Rec().Ability != 50 {
		t.Fatal("Load must keep returning its own copy")
	}

	// A new publication switches the cache: read again, at once (its files are fresh).
	publish(f, "last", 70, false)
	if res, err := c.Sync(ctx, true); err != nil || !res.Switched {
		t.Fatalf("sync: %+v %v", res, err)
	}
	next, _, err := LoadShared(st)
	if err != nil || next == first || *next.Model("m1").Rec().Ability != 70 {
		t.Fatalf("switched publication not read: %v", err)
	}

	// A file removed under it (a prune, a cleared cache): read again, and the error is reported.
	settle()
	if d, _, _ := LoadShared(st); d == nil {
		t.Fatal("setup")
	}
	state, _ := st.State()
	if err := os.Remove(st.ObjectPath(state.ComponentHash)); err != nil {
		t.Fatal(err)
	}
	if d, _, err := LoadShared(st); d != nil || err == nil {
		t.Fatal("a removed object was served from the memo")
	}
}
