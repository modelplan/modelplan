// SPDX-License-Identifier: MIT
package localusage

import (
	"context"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
)

// HistoryProviders is the supported count-adapter inventory. The projection
// reducer seam is separate: it cannot be called as a token-count adapter.
func HistoryProviders() []string {
	tools := []string{}
	for tool := range historyDepths {
		tools = append(tools, tool)
	}
	sort.Strings(tools)
	return tools
}

func productionHistoryRoot(home, tool string) string {
	switch tool {
	case "claude":
		root := os.Getenv("CLAUDE_CONFIG_DIR")
		if root == "" {
			root = filepath.Join(home, ".claude")
		}
		return root
	case "amp":
		root := os.Getenv("XDG_DATA_HOME")
		if root == "" {
			root = filepath.Join(home, ".local", "share")
		}
		return filepath.Join(root, "amp", "threads")
	case "droid":
		return filepath.Join(home, ".factory", "sessions")
	case "kimi":
		return filepath.Join(home, ".kimi", "sessions")
	case "copilot":
		return filepath.Join(home, ".copilot", "session-state")
	case "grok":
		root := os.Getenv("GROK_HOME")
		if root == "" {
			root = filepath.Join(home, ".grok")
		}
		return filepath.Join(root, "sessions")
	case "qwen":
		return QwenHome(home)
	case "gemini":
		return GeminiHome(home)
	}
	return ""
}

// ProductionHistoryAccess resolves consent and a compiled local root. It reads
// no source content. Read-only callers never create an installation key.
func ProductionHistoryAccess(home, tool string, createKey bool) (string, HistoryAccess) {
	return ProductionHistoryAccessWithAdmission(home, tool, createKey, consent.Capture())
}

// ProductionHistoryAccessWithAdmission captures no second permission state.
// StillValid and Publish are live revocation fences, including for read-only caches.
func ProductionHistoryAccessWithAdmission(home, tool string, createKey bool, admission consent.Admission) (string, HistoryAccess) {
	state, mode := admission.State(), admission.Mode()
	record, decided := state.Tools[tool]
	setting, err := loadSetting(SettingsPath(home))
	legacy := err == nil && ((tool == "gemini" && setting.Enabled) || (tool == "qwen" && setting.Qwen))
	allowed := legacy
	if decided {
		allowed = record.Allowed && record.ConsentTextVersion == consent.TextVersion && state.Allows(tool, consent.Local, mode)
	}
	// The original per-source local opt-out remains a veto even when the shared
	// record still permits this tool's independent account reader.
	if err == nil && ((tool == "gemini" && !setting.Enabled) || (tool == "qwen" && !setting.Qwen)) {
		allowed = false
	}
	a := HistoryAccess{Allowed: allowed, Denied: decided && record.DeniedSources[consent.Local], Privacy: mode}
	if (tool == "gemini" && os.Getenv("MODELPLAN_GEMINI") == "off") || (tool == "qwen" && os.Getenv("MODELPLAN_QWEN") == "off") {
		a.Privacy = consent.Off
		mode = consent.Off
	}
	root := productionHistoryRoot(home, tool)
	if !allowed || mode == consent.Off || os.Getenv("MODELPLAN_HISTORY") == "off" || !detect.LocalRoot(root) {
		return root, a
	}
	if (err != nil || setting.Key == "") && createKey {
		if setSource(home, "identity", true) == nil {
			setting, err = loadSetting(SettingsPath(home))
		}
	}
	if err != nil {
		return root, a
	}
	a.Key, _ = hex.DecodeString(setting.Key)
	if len(a.Key) == 32 {
		a.ProfileRef = historyHash(a.Key, "production/profile", tool+"\x00"+root)
	}
	generation := state.Generation
	a.StillValid = func() bool {
		current, effective := consent.Current()
		if tool == "gemini" || tool == "qwen" {
			selected, err := loadSetting(SettingsPath(home))
			if err != nil || (tool == "gemini" && !selected.Enabled) || (tool == "qwen" && !selected.Qwen) {
				return false
			}
		}
		return current.Generation == generation && effective != consent.Off && os.Getenv("MODELPLAN_HISTORY") != "off"
	}
	a.Publish = func(write func() error) error { return consent.Publish(generation, write) }
	return root, a
}

func ProductionHistory(home, cache, tool string, readOnly bool, now time.Time) HistoryResult {
	if readOnly {
		_, a := ProductionHistoryAccess(home, tool, false)
		return ReadHistoryCache(cache, tool, a, now)
	}
	return RefreshProductionHistory(context.Background(), home, cache, tool, now)
}

// RefreshProductionHistory is the foreground, cancellable production count read.
func RefreshProductionHistory(ctx context.Context, home, cache, tool string, now time.Time) HistoryResult {
	unlock, err := consent.ReaderLockContext(ctx)
	if err != nil {
		_, a := ProductionHistoryAccess(home, tool, false)
		return ReadHistoryCache(cache, tool, a, now)
	}
	defer unlock()
	root, a := ProductionHistoryAccess(home, tool, true)
	return RefreshHistory(ctx, tool, root, cache, a, now)
}

func ProductionHistories(home, cache string, readOnly bool, now time.Time) []HistoryResult {
	return ProductionHistoriesWithAdmission(home, cache, readOnly, now, consent.Capture())
}

func ProductionHistoriesWithAdmission(home, cache string, readOnly bool, now time.Time, admission consent.Admission) []HistoryResult {
	state := admission.State()
	out := []HistoryResult{}
	for _, tool := range HistoryProviders() {
		// Gemini/Qwen retain their existing explicitly opted-in feed; do not add a
		// second measurement of those same records to desktop totals.
		if readOnly && (tool == "gemini" || tool == "qwen") {
			continue
		}
		_, access := ProductionHistoryAccessWithAdmission(home, tool, false, admission)
		if _, decided := state.Tools[tool]; decided || access.Allowed {
			if readOnly {
				out = append(out, ReadHistoryCache(cache, tool, access, now))
			} else {
				out = append(out, RefreshProductionHistory(context.Background(), home, cache, tool, now))
			}
		}
	}
	return out
}

func ProductionHistoryDue(home, cache string, now time.Time) bool {
	for _, tool := range HistoryProviders() {
		root, a := ProductionHistoryAccess(home, tool, false)
		if !a.Allowed || a.Privacy == consent.Off || os.Getenv("MODELPLAN_HISTORY") == "off" || !detect.LocalRoot(root) {
			continue
		}
		if len(a.Key) != 32 {
			return true
		}
		r := ReadHistoryCache(cache, tool, a, now)
		if !now.Before(r.NextAttemptAt) {
			return true
		}
	}
	return false
}

// ForgetProductionHistory removes all of this tool's derived profile captures,
// preserving its shared request gate and the installation identity key.
func ForgetProductionHistory(cache, tool string) error {
	unlock, err := consent.ReaderLock()
	if err != nil {
		return err
	}
	defer unlock()
	return ForgetProductionHistoryLocked(cache, tool)
}

// ForgetProductionHistoryLocked is the same purge for callers already holding
// consent.ReaderLock, such as quota.ForgetTool. It still acquires the engine's
// own lock and preserves the shared reservation and installation identity key.
func ForgetProductionHistoryLocked(cache, tool string) error {
	if tool == "claude" {
		tool = projectionTool
	} else if _, ok := historyDepths[tool]; !ok {
		return nil
	}
	_, lockPath := historyGatePaths(cache, tool)
	if _, err := os.Stat(filepath.Dir(lockPath)); os.IsNotExist(err) {
		return nil
	}
	lock, err := os.OpenFile(lockPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return errors.New("local history refresh must finish before cleanup")
	}
	lock.Close()
	defer os.Remove(lockPath)
	entries, err := os.ReadDir(filepath.Join(cache, "observed"))
	if err != nil {
		return err
	}
	prefix := "history-v1-" + tool + "-"
	for _, entry := range entries {
		if strings.HasPrefix(entry.Name(), prefix) && strings.HasSuffix(entry.Name(), ".json") {
			if err := os.Remove(filepath.Join(cache, "observed", entry.Name())); err != nil {
				return errors.New("local history cleanup unavailable")
			}
		}
	}
	return nil
}
