package quota

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

type codexBarProviderConfig struct {
	ID           string `json:"id"`
	Enabled      bool   `json:"enabled"`
	CookieSource string `json:"cookieSource"`
}

type codexBarUsageDocument struct {
	Version   int                      `json:"version"`
	Providers []codexBarProviderConfig `json:"providers"`
}

// The pinned metadata-only commands load/normalize config but invoke no reader.
// Discover the effective registry from that binary, not the legacy five-provider
// allowlist. Then prove that normalization preserves every explicit Off control.
// Source: v0.81.0 CLIConfigCommand.swift and CodexBarConfig.normalized().
func codexBarUsageConfig(ctx context.Context, bin, provider, access string) (file string, cleanup func(), err error) {
	if !consent.ValidTool(provider) || provider == "all" || provider == "both" {
		return "", nil, errors.New("invalid single CodexBar provider")
	}
	dir, err := os.MkdirTemp("", "modelplan-codexbar-")
	if err != nil {
		return "", nil, errors.New("CodexBar usage config unavailable")
	}
	cleanup = func() { _ = os.RemoveAll(dir) }
	defer func() {
		if err != nil {
			cleanup()
		}
	}()
	file = filepath.Join(dir, "config.json")
	write := func(c codexBarUsageDocument) error {
		b, err := json.Marshal(c)
		if err != nil {
			return err
		}
		return os.WriteFile(file, b, 0600)
	}
	config := codexBarUsageDocument{Version: 1, Providers: []codexBarProviderConfig{}}
	// This empty private config is for metadata only, never a usage invocation.
	// Neither registry discovery nor validation inherits an ambient config.
	if err = write(config); err != nil {
		return file, cleanup, errors.New("CodexBar usage config unavailable")
	}
	out, err := codexBarConfigMetadata(ctx, bin, file, "providers")
	if err != nil {
		return file, cleanup, err
	}
	var registry []struct {
		Provider string `json:"provider"`
	}
	if json.Unmarshal(out, &registry) != nil || len(registry) == 0 || len(registry) > 512 {
		return file, cleanup, errors.New("CodexBar effective registry unavailable")
	}
	expected := map[string]codexBarProviderConfig{}
	for _, entry := range registry {
		id := entry.Provider
		if !consent.ValidTool(id) || id == "all" || id == "both" {
			return file, cleanup, errors.New("invalid CodexBar registry provider")
		}
		if _, exists := expected[id]; exists {
			return file, cleanup, errors.New("duplicate CodexBar registry provider")
		}
		p := codexBarProviderConfig{ID: id, Enabled: id == provider, CookieSource: "off"}
		if p.Enabled && access == "browser-session" {
			p.CookieSource = "auto"
		}
		expected[id] = p
		config.Providers = append(config.Providers, p)
	}
	if _, found := expected[provider]; !found {
		return file, cleanup, errors.New("provider absent from CodexBar effective registry")
	}
	if err = write(config); err != nil {
		return file, cleanup, errors.New("CodexBar usage config unavailable")
	}
	out, err = codexBarConfigMetadata(ctx, bin, file, "dump")
	if err != nil {
		return file, cleanup, err
	}
	var normalized struct {
		Version   int `json:"version"`
		Providers []struct {
			ID           string `json:"id"`
			Enabled      *bool  `json:"enabled"`
			CookieSource string `json:"cookieSource"`
		} `json:"providers"`
	}
	if json.Unmarshal(out, &normalized) != nil || normalized.Version != 1 || len(normalized.Providers) != len(expected) {
		return file, cleanup, errors.New("CodexBar normalized cookie policy unavailable")
	}
	for _, p := range normalized.Providers {
		want, found := expected[p.ID]
		if !found || p.Enabled == nil || *p.Enabled != want.Enabled || p.CookieSource != want.CookieSource {
			return file, cleanup, errors.New("CodexBar normalized cookie policy not enforced")
		}
		delete(expected, p.ID)
	}
	if len(expected) != 0 {
		return file, cleanup, errors.New("CodexBar normalized cookie policy incomplete")
	}
	return file, cleanup, nil
}

func codexBarConfigMetadata(ctx context.Context, bin, file, command string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, "config", command, "--json")
	cmd.Env = codexBarConfigEnvironment("standard", file)
	cmd.Stdin = nil
	cmd.Stderr = io.Discard
	var out bytes.Buffer
	cmd.Stdout = &limited{w: &out, n: codexbarMaxOut}
	if err := cmd.Run(); err != nil {
		return nil, errors.New("CodexBar config metadata unavailable; usage not started")
	}
	return out.Bytes(), nil
}
