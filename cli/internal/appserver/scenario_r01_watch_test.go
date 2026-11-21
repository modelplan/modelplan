// SPDX-License-Identifier: MIT
package appserver

// Spec-data scenario R-01 (delivery trigger at the production seam): "Granted
// source has a fresh 4% reading / Launch and source changes to 3% / App
// subscription shows the new 3% with its source observation time." The
// un-clicked delivery depends on the production watcher: SharedBackend.Changes
// samples the observed cache and notifies subscribers when a local observation
// lands, so the rebuilt view can reach the subscription without any refresh
// request. The value projection itself is pinned by scenario_r01_test.go.

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestR01LocalObservationChangeNotifiesSharedBackend(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "")
	b, err := NewSharedBackend(SharedConfig{
		Detect:  func() detect.Report { return detect.Report{} },
		Paths:   func(a consent.Admission) quota.Paths { return quota.Paths{Admission: &a} },
		Cleanup: func(string, bool) error { return nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	changes := b.Changes(ctx)

	// Drain the watcher's initial snapshot notification and let the sampler
	// settle so a stale tick cannot masquerade as the file notification.
	select {
	case <-changes:
	case <-time.After(2 * time.Second):
		t.Fatal("watcher did not produce its initial snapshot notification")
	}
	time.Sleep(300 * time.Millisecond)
	select {
	case <-changes:
	default:
	}

	// A newer local observation lands in the observed cache; no refresh is
	// requested anywhere.
	cache := b.paths(consent.Capture()).Cache
	if cache == "" {
		t.Fatal("backend cache path is empty")
	}
	observed := filepath.Join(cache, "observed")
	if err := os.MkdirAll(observed, 0700); err != nil {
		t.Fatal(err)
	}
	body, err := json.Marshal(map[string]any{"schemaVersion": 1, "observedAt": time.Now().UTC(), "status": "ok"})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(observed, "codex-account.json"), body, 0600); err != nil {
		t.Fatal(err)
	}
	select {
	case <-changes:
	case <-time.After(2 * time.Second):
		t.Fatal("a new local observation did not notify the subscription (R-01 delivery trigger)")
	}
}
