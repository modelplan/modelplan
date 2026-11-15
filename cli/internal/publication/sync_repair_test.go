package publication

import (
	"context"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/store"
)

// A forced sync repairs the current publication's cached object when it went missing or
// corrupt, whether the pointer answers 304 or 200 with the same publication (audit C, P2).
func TestSyncRepairsMissingCurrentObject(t *testing.T) {
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
	c.Now = func() time.Time { return time.Date(2026, 10, 11, 0, 0, 0, 0, time.UTC) }
	ctx := context.Background()
	if res, err := c.Sync(ctx, false); err != nil || !res.Switched {
		t.Fatalf("first sync: %+v %v", res, err)
	}
	_, s, err := Load(st)
	if err != nil {
		t.Fatal(err)
	}
	object := st.ObjectPath(s.ComponentHash)

	// Missing object; the pointer is unchanged (a conditional request would answer 304).
	if err := os.Remove(object); err != nil {
		t.Fatal(err)
	}
	if _, err := c.Sync(ctx, true); err != nil {
		t.Fatalf("304 path: %v", err)
	}
	if _, _, err := Load(st); err != nil {
		t.Fatalf("304 path left the cache broken: %v", err)
	}

	// Corrupt object; the pointer answers 200 with the same publication.
	if err := os.WriteFile(object, []byte("{}"), 0o600); err != nil {
		t.Fatal(err)
	}
	f.etag = `W/"other"`
	if _, err := c.Sync(ctx, true); err != nil {
		t.Fatalf("200 path: %v", err)
	}
	if _, _, err := Load(st); err != nil {
		t.Fatalf("200 path left the cache broken: %v", err)
	}
}
