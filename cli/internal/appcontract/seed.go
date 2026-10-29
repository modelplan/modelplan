// SPDX-License-Identifier: MIT
package appcontract

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// A handwritten synthetic public graph. No producer/private data or signing
// secret is used: the consumer verifies this same content-addressed graph.
func seedPublication(home string) error {
	hash := func(b []byte) string { return fmt.Sprintf("%x", sha256.Sum256(b)) }
	detectors := []any{}
	for _, e := range []struct{ id, name, path string }{{"claude", "Claude Code", ".claude"}, {"codex", "Codex", ".codex"}, {"copilot", "GitHub Copilot", ".copilot"}} {
		detectors = append(detectors, map[string]any{"providerId": e.id, "displayName": e.name, "readerId": "native:" + e.id, "preferred": "native", "codexbar": map[string]any{"audited": false}, "minCli": "0.0.0", "beta": true, "detectionStatus": "signals", "signals": []any{map[string]any{"type": "path", "value": e.path}}})
	}
	dependencies := map[string]string{}
	for _, n := range []string{"models", "registry", "rules", "calendar"} {
		dependencies[n] = strings.Repeat("a", 64)
	}
	data := map[string]any{"units": map[string]string{"ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"}, "models": []any{}, "lineups": []any{}, "speedTiers": []any{}, "resets": []any{}, "windows": []any{}, "detectorSchemaVersion": 1, "detectorRevision": 1, "detectors": detectors}
	object, _ := json.Marshal(map[string]any{"schemaVersion": 1, "kind": "client", "dependencies": dependencies, "data": data})
	type ref struct {
		SchemaVersion int    `json:"schemaVersion"`
		Hash          string `json:"hash"`
		Bytes         int    `json:"bytes"`
	}
	refs := map[string]ref{}
	for _, n := range []string{"methods", "registry", "models", "plans", "rules", "news", "calendar"} {
		refs[n] = ref{1, strings.Repeat("a", 64), 2}
	}
	refs["client"] = ref{1, hash(object), len(object)}
	core := struct {
		SchemaVersion     int               `json:"schemaVersion"`
		ComparisonVersion string            `json:"comparisonVersion"`
		Methods           map[string]string `json:"methods"`
		Components        map[string]ref    `json:"components"`
	}{1, "synthetic-app-contract", map[string]string{"index": "unified-v03-estimator-0.1.0-internal", "recommendation": "balanced-coding-absolute-v4"}, refs}
	b, _ := json.Marshal(core)
	id := hash(b)[:24]
	manifest := []byte(strings.TrimSuffix(string(b), "}") + `,"publicationId":"` + id + `","publishedAt":"2020-01-01T00:00:00Z"}`)
	st := &store.Store{Dir: filepath.Join(home, "cache")}
	if err := os.MkdirAll(filepath.Join(st.Dir, "objects"), 0700); err != nil {
		return err
	}
	if err := st.PutObject(hash(object), object); err != nil {
		return err
	}
	if err := st.PutManifest(id, manifest); err != nil {
		return err
	}
	now := time.Now().UTC()
	if err := st.SaveState(store.State{Base: "http://127.0.0.1:1", PublicationID: id, ManifestHash: hash(manifest), PublishedAt: "2020-01-01T00:00:00Z", Component: "client", ComponentHash: hash(object), CheckedAt: now, NextCheckAt: now.Add(24 * time.Hour), VerifiedAt: now, LastAttemptAt: now}); err != nil {
		return err
	}
	_, _, err := publication.Load(st)
	return err
}
