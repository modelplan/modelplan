// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"errors"
	"os"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/store"
)

func TestCockpitPublicationSourceRequiresVerifiedLocalCache(t *testing.T) {
	t.Setenv("MODELPLAN_CACHE", t.TempDir())
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	if d, err := loadCockpitPublication(context.Background(), st); err != nil || d != nil {
		t.Fatalf("empty cache: %+v %v", d, err)
	}
	f := newPublicationFixture(t, nil)
	if err := st.PutObject(f.objectHash, f.object); err != nil {
		t.Fatal(err)
	}
	if err := st.PutManifest(f.id, f.manifest); err != nil {
		t.Fatal(err)
	}
	if err := st.SaveState(store.State{PublicationID: f.id, ManifestHash: publicationHash(f.manifest), Component: "client", ComponentHash: f.objectHash}); err != nil {
		t.Fatal(err)
	}
	d, err := loadCockpitPublication(context.Background(), st)
	if err != nil || d == nil || d.PublicationID != f.id || d.PublishedAt != "2026-10-24T12:00:00Z" || len(d.Models) != 2 {
		t.Fatalf("verified source: %+v %v", d, err)
	}
	if err := os.WriteFile(st.ObjectPath(f.objectHash), []byte(`{"invalid":"tampered"}`), 0600); err != nil {
		t.Fatal(err)
	}
	if d, err := loadCockpitPublication(context.Background(), st); err != nil || d != nil {
		t.Fatalf("tampered cache: %+v %v", d, err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := loadCockpitPublication(ctx, st); !errors.Is(err, context.Canceled) {
		t.Fatalf("cancellation: %v", err)
	}
}
