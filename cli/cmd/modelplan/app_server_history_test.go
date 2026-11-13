// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestHistorySourceReadsSanitizedCacheWithoutRefreshing(t *testing.T) {
	home := t.TempDir()
	cache := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_GEMINI", "")
	t.Setenv("MODELPLAN_GEMINI_HOME", "")
	file := filepath.Join(home, ".gemini", "tmp", "synthetic", "chats", "session-synthetic.json")
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	raw, _ := json.Marshal(map[string]any{"sessionId": "synthetic", "messages": []any{map[string]any{"id": "one", "type": "gemini", "timestamp": now, "model": "synthetic-model", "tokens": map[string]int{"input": 10, "output": 2, "total": 12}}}})
	if err := os.WriteFile(file, raw, 0600); err != nil {
		t.Fatal(err)
	}
	if err := localusage.SetGemini(home, true); err != nil {
		t.Fatal(err)
	}
	paths := func(a consent.Admission) quota.Paths { return quota.ProductionPathsWithAdmission(cache, "1.0.0", a) }
	backend, err := appserver.NewSharedBackend(appserver.SharedConfig{Detect: func() detect.Report {
		return detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: "gemini", Preferred: "native", ReaderID: "native:gemini"}, Detected: true}}}
	}, Paths: paths, Cleanup: func(scope string, forget bool) error {
		return quota.EraseScope(quota.ProductionPaths(cache, "1.0.0"), scope, forget)
	}})
	if err != nil {
		t.Fatal(err)
	}
	s, _ := consent.Load(consent.Path())
	_, err = backend.Grant(context.Background(), wire.ConsentGrantParams{RequestID: "history-source", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, TextVersion: consent.TextVersion, Allow: []string{consent.ScopeGeminiLocalHistory}, Deny: []string{}})
	if err != nil {
		t.Fatal(err)
	}
	if result := localusage.RefreshProductionHistory(context.Background(), home, cache, "gemini", now); result.Availability != "ok" {
		t.Fatal(result)
	}
	// The provider now contains invalid data. A query must retain the existing
	// sanitized capture and must not refresh or overwrite it from this source.
	if err := os.WriteFile(file, []byte("invalid changed source"), 0600); err != nil {
		t.Fatal(err)
	}
	view, err := backend.Get(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	source := sharedHistory{backend: backend, cache: cache}
	p := wire.HistoryQueryParams{Kind: wire.HistoryTokens, Tool: "gemini", Limit: 1}
	admitted, err := source.AdmitHistory(context.Background(), view.Stamp, p)
	if err != nil {
		t.Fatal(err)
	}
	batch, err := source.ReadHistory(context.Background(), admitted, p, "")
	if err != nil {
		t.Fatal(err)
	}
	if len(batch.Items) != 1 || batch.Items[0].Tokens == nil || *batch.Items[0].Tokens != 12 {
		t.Fatalf("cache-only history lost: %+v", batch)
	}
	_, err = backend.Grant(context.Background(), wire.ConsentGrantParams{RequestID: "deny-history-source", ExpectStoreEpoch: view.Stamp.Epoch, ExpectGeneration: view.Stamp.Generation, TextVersion: consent.TextVersion, Allow: []string{}, Deny: []string{consent.ScopeGeminiLocalHistory}})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := source.ReadHistory(context.Background(), admitted, p, ""); err == nil {
		t.Fatal("old admission survived revoke")
	}
}
