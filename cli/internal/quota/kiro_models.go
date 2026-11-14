package quota

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

// D98/D99/D102: the model ids Kiro reports for the signed-in account. Kiro lists them only in the reply to
// ACP `session/new`, so one throwaway session is opened per read, in an empty temporary directory (never a
// user project), and no prompt is ever sent. The process is killed right after the reply. Kiro may leave a
// small session stub under ~/.kiro; the owner accepted that (D102). At most one read per 24 hours, counted
// from the last attempt even when it failed; a failure, timeout or malformed reply keeps the previous list
// (or none) and never changes the quota outcome. Only ids are cached.
//
// UNVERIFIED against a live account: the reply shape is parsed defensively (models.availableModels and the
// `model` config option). See docs/readers/kiro.md for the verification run that records a real fixture.
const kiroModelsEvery = 24 * time.Hour

// A var only so tests can shorten the cap.
var kiroModelsTimeout = 20 * time.Second

type kiroModelsCache struct {
	AttemptedAt time.Time `json:"attemptedAt"`
	Models      []string  `json:"models,omitempty"`
}

func kiroModelsPath(cache string) string {
	return filepath.Join(cache, "observed", "kiro-models.json")
}

// collectKiro is the usage read plus, when due, the model list. The usage entry is final before the models
// read starts; the models read can only add ReportedModels.
func collectKiro(ctx context.Context, c *http.Client, cache string, now time.Time) codexbarEntry {
	e := fetchKiro(ctx, c, "", "", now)
	if e.Status != "ok" || cache == "" {
		return e
	}
	e.ReportedModels = kiroReportedModels(ctx, cache, now)
	return e
}

func kiroReportedModels(ctx context.Context, cache string, now time.Time) []string {
	var old kiroModelsCache
	if b, err := os.ReadFile(kiroModelsPath(cache)); err == nil {
		_ = json.Unmarshal(b, &old)
		old.Models = cleanReportedModels(old.Models)
	}
	if !old.AttemptedAt.IsZero() && !old.AttemptedAt.After(now) && now.Sub(old.AttemptedAt) < kiroModelsEvery {
		return old.Models
	}
	next := kiroCache(old, now)
	if bin := kiroBin(); bin != "" {
		if ids := readKiroModels(ctx, bin); ids != nil {
			next.Models = ids
		}
	}
	if b, err := json.Marshal(next); err == nil {
		_ = os.MkdirAll(filepath.Dir(kiroModelsPath(cache)), 0o700)
		_ = os.WriteFile(kiroModelsPath(cache), b, 0o600)
	}
	return next.Models
}

func kiroCache(old kiroModelsCache, now time.Time) kiroModelsCache {
	return kiroModelsCache{AttemptedAt: now.UTC(), Models: old.Models}
}

// readKiroModels runs one throwaway session. nil on any failure.
func readKiroModels(ctx context.Context, bin string) []string {
	ctx, cancel := context.WithTimeout(ctx, kiroModelsTimeout)
	defer cancel()
	dir, err := os.MkdirTemp("", "modelplan-kiro-*")
	if err != nil {
		return nil
	}
	defer os.RemoveAll(dir)
	c, err := openKiro(ctx, bin, dir)
	if err != nil {
		return nil
	}
	defer c.close()
	if c.initialize() != nil {
		return nil
	}
	if c.send(map[string]any{"jsonrpc": "2.0", "id": 3, "method": "session/new", "params": map[string]any{"cwd": dir, "mcpServers": []any{}}}) != nil {
		return nil
	}
	raw, err := c.wait(3)
	if err != nil {
		return nil
	}
	return parseKiroModels(raw)
}

// parseKiroModels takes ids only from models.availableModels[].modelId and from the options of the `model`
// config option. Every other field (session id, names, paths, account data) is ignored.
func parseKiroModels(raw json.RawMessage) []string {
	var r struct {
		Models struct {
			Available []struct {
				ModelID string `json:"modelId"`
				ID      string `json:"id"`
			} `json:"availableModels"`
		} `json:"models"`
		Config []struct {
			ID       string `json:"id"`
			ConfigID string `json:"configId"`
			Options  []struct {
				Value   string `json:"value"`
				ID      string `json:"id"`
				ModelID string `json:"modelId"`
			} `json:"options"`
			Values []struct {
				Value string `json:"value"`
				ID    string `json:"id"`
			} `json:"values"`
		} `json:"configOptions"`
	}
	if json.Unmarshal(raw, &r) != nil {
		return nil
	}
	var ids []string
	for _, m := range r.Models.Available {
		ids = append(ids, m.ModelID, m.ID)
	}
	for _, o := range r.Config {
		if o.ID != "model" && o.ConfigID != "model" {
			continue
		}
		for _, v := range o.Options {
			ids = append(ids, v.Value, v.ID, v.ModelID)
		}
		for _, v := range o.Values {
			ids = append(ids, v.Value, v.ID)
		}
	}
	out := cleanReportedModels(ids)
	if len(out) == 0 {
		return nil
	}
	return out
}
