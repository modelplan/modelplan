// Package diagnostics builds a shareable report from ModelPlan-owned cache metadata.
// It never invokes a reader, opens harness files, or includes arbitrary cached strings.
package diagnostics

import (
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

const maxCacheBytes = 1 << 20

var versionRE = regexp.MustCompile(`^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}(-[a-z0-9.-]{1,40})?$`)

type Source struct {
	Source string `json:"source"`
	Status string `json:"status"`
}

type Report struct {
	SchemaVersion int      `json:"schemaVersion"`
	Version       string   `json:"version"`
	OS            string   `json:"os"`
	Arch          string   `json:"arch"`
	ReaderMode    string   `json:"readerMode"`
	Publication   Source   `json:"publication"`
	Sources       []Source `json:"sources"`
}

// Collect reports cache state, not live authentication or a fresh provider reading.
// Only fixed source names and status enums can reach the output.
func Collect(cache, version string) Report {
	if !versionRE.MatchString(version) {
		version = "unknown"
	}
	mode := os.Getenv("MODELPLAN_READERS")
	switch mode {
	case "", "automatic":
		mode = "automatic"
	case "passive", "off":
	default:
		mode = "unknown"
	}
	r := Report{SchemaVersion: 1, Version: version, OS: runtime.GOOS, Arch: runtime.GOARCH, ReaderMode: mode, Sources: []Source{}}
	var state struct {
		PublicationID string `json:"publicationId"`
	}
	status := readJSON(cache, "state.json", &state)
	if status == "cached" && state.PublicationID == "" {
		status = "empty"
	}
	r.Publication = Source{Source: "publication-cache", Status: status}
	for _, item := range []struct{ name, file string }{
		{"claude-code", "claude-code.json"},
		{"codex-account", "codex-account.json"},
		{"native", "native.json"},
		{"codexbar", "codexbar.json"},
	} {
		var envelope struct {
			SchemaVersion int    `json:"schemaVersion"`
			Status        string `json:"status"`
			Providers     []struct {
				Provider string `json:"provider"`
				Status   string `json:"status"`
			} `json:"providers"`
		}
		status := readJSON(cache, filepath.Join("observed", item.file), &envelope)
		if status == "cached" && envelope.SchemaVersion != 1 {
			status = "unsupported_schema"
		}
		cacheStatus := status
		if status == "cached" && envelope.Status != "" {
			status = safeStatus(envelope.Status)
		}
		r.Sources = append(r.Sources, Source{Source: item.name, Status: status})
		if cacheStatus != "cached" || (item.name != "native" && item.name != "codexbar") {
			continue
		}
		// This is a diagnostics output allowlist, not a detector or reader catalogue.
		for _, id := range []string{"copilot", "cursor", "kimi", "kiro", "minimax", "opencodego", "zai"} {
			seen := map[string]bool{}
			for _, provider := range envelope.Providers {
				if provider.Provider == id {
					status := safeStatus(provider.Status)
					// Several accounts can have different states. Preserve every state
					// without sharing an account's ref, alias or number of readings.
					if !seen[status] {
						r.Sources = append(r.Sources, Source{Source: item.name + ":" + id, Status: status})
						seen[status] = true
					}
				}
			}
		}
	}
	return r
}

func safeStatus(status string) string {
	switch status {
	case "ok", "error", "estimated", "unavailable", "not_detected", "denied", "expired_login", "unsupported", "stale", "pay_as_you_go", "org_managed":
		return status
	}
	return "unknown"
}

// Read only bounded regular files beneath the supplied cache. Do not follow cache
// symlinks into harness credentials, and never return an OS or JSON error string.
func readJSON(cache, relative string, dst any) string {
	p := cache
	parts := append([]string{""}, strings.Split(relative, string(filepath.Separator))...)
	for i, part := range parts {
		p = filepath.Join(p, part)
		info, err := os.Lstat(p)
		if errors.Is(err, os.ErrNotExist) {
			return "missing"
		}
		if err != nil {
			return "unreadable"
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return "unsafe_path"
		}
		if i < len(parts)-1 && !info.IsDir() || i == len(parts)-1 && !info.Mode().IsRegular() {
			return "unsafe_path"
		}
		if i == len(parts)-1 && info.Size() > maxCacheBytes {
			return "too_large"
		}
	}
	f, err := os.Open(p)
	if err != nil {
		return "unreadable"
	}
	defer f.Close()
	b, err := io.ReadAll(io.LimitReader(f, maxCacheBytes+1))
	if err != nil {
		return "unreadable"
	}
	if len(b) > maxCacheBytes {
		return "too_large"
	}
	if json.Unmarshal(b, dst) != nil {
		return "invalid"
	}
	return "cached"
}
