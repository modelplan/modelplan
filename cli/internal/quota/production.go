// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
)

// ProductionPaths is the single CLI/App/hooks constructor. It reads ModelPlan
// consent and presence metadata only, never a login file or a provider endpoint.
func ProductionPaths(cache, version string) Paths {
	home, _ := os.UserHomeDir()
	codex := os.Getenv("CODEX_HOME")
	if codex == "" {
		codex = filepath.Join(home, ".codex")
	}
	p := Paths{CLIVersion: version, Cache: cache, CodexHome: codex,
		LocalFile:       filepath.Join(home, ".config", "modelplan", "local.json"),
		CodexBarFile:    filepath.Join(home, ".config", "modelplan", "codexbar.json"),
		ConnectionsFile: filepath.Join(home, ".config", "modelplan", "connections.json"),
		CodexThread:     os.Getenv("CODEX_THREAD_ID"), ClaudeSession: os.Getenv("CLAUDE_CODE_SESSION_ID"),
		ReaderAccess: &ReaderAccess{Grants: map[string]ReaderGrant{}}}
	state, mode := consent.Current()
	if mode == consent.Off || nativeOff() {
		return p
	}
	cat := loadReaderCatalogue(cache)
	routes := map[string]detect.Entry{}
	if cat != nil {
		for _, route := range cat.Detectors {
			routes[route.ProviderID] = route
		}
	}
	// Local session state is admitted independently of borrowed-login imports,
	// including in Passive mode. Construction remains read-only: no key creation.
	if record, exists := state.Tools["claude"]; exists && record.Allowed && record.ConsentTextVersion == consent.TextVersion && record.Backend == BackendNative && !record.BrowserSession && (record.ReaderID == "native:claude" || record.ReaderID == "native:claude-code") {
		route, known := routes["claude"]
		if !known || (route.Preferred == "native" && strings.HasPrefix(route.ReaderID, "native:") && detect.Compatible(version, route.MinCLI)) {
			root, access := localusage.ProductionHistoryAccess(home, "claude", false)
			if access.Allowed && !access.Denied && access.Privacy != consent.Off && os.Getenv("MODELPLAN_HISTORY") != "off" && detect.LocalRoot(root) {
				generation, priorValid := state.Generation, access.StillValid
				access.StillValid = func() bool {
					current, effective := consent.Current()
					return current.Generation == generation && effective != consent.Off && !nativeOff() && os.Getenv("MODELPLAN_HISTORY") != "off" && (priorValid == nil || priorValid())
				}
				p.ClaudeSessionRoot, p.ClaudeSessionAccess = root, &access
			}
		}
	}
	if mode != consent.Automatic {
		return p
	}
	for id, record := range state.Tools {
		n := nativeReaders[id]
		if n == nil || !record.Allowed || record.ConsentTextVersion != consent.TextVersion || record.Backend != BackendNative || record.BrowserSession ||
			(record.ReaderID != "native:"+id && !(id == "claude" && record.ReaderID == "native:claude-code")) || !state.Allows(id, consent.Credential, mode) {
			continue
		}
		if route, exists := routes[id]; exists && (route.Preferred != "native" || !strings.HasPrefix(route.ReaderID, "native:") || !detect.Compatible(version, route.MinCLI)) {
			continue
		}
		generation := state.Generation
		g := ReaderGrant{Generation: strconv.FormatUint(generation, 10), Region: record.Region,
			Publish: func(write func() error) error { return consent.Publish(generation, write) },
			StillValid: func() bool {
				current, effective := consent.Current()
				return effective == consent.Automatic && !nativeOff() && current.Generation == generation
			}}
		if g.Region != "" && !contains(n.Regions, g.Region) {
			continue
		}
		if n.Managed != nil {
			// An explicitly selected environment-key route must remain an environment-
			// key route. Otherwise a present supported login is admitted locally.
			if record.KeyEnv != "" {
				continue
			}
			for _, profile := range n.Profiles() {
				if detect.LocalRoot(profile.Root) || (id == "cursor" && missingCursorProfile(profile.Root)) {
					g.Profiles = append(g.Profiles, profile)
				}
			}
			if len(g.Profiles) == 0 {
				continue
			}
			g.SavedLogin = true
			g.KeychainConsent = state.KeychainStatus(id, mode)
			g.Keychain = g.KeychainConsent == "allowed"
			g.KeychainPriorGrant = g.Keychain
		}
		if id == "zai" && record.KeyEnv == "" && len(record.Profiles) == 1 {
			// Only a logical, locally selected source is accepted, never a path supplied
			// by catalogue data. OpenCode requires an explicit active-provider selector.
			switch record.Profiles[0] {
			case "claude-code":
				profiles := claudeProfiles()
				if len(profiles) == 1 && detect.LocalRoot(profiles[0].Root) {
					region := g.Region
					if region == "" {
						region = n.Regions[0]
					}
					g.ConfigSource = &ZaiConfigSource{Tool: "claude-code", SettingsPath: filepath.Join(profiles[0].Root, "settings.json"), Region: region}
				}
			}
		}
		p.ReaderAccess.Grants[id] = g
	}
	return p
}

// InteractiveReaders is only used by an explicit foreground refresh. Quiet
// detached refreshes and ordinary JSON/cache reads never use this policy.
func InteractiveReaders(p Paths) Paths {
	if p.ReaderAccess == nil {
		return p
	}
	copy := &ReaderAccess{Grants: map[string]ReaderGrant{}}
	for id, g := range p.ReaderAccess.Grants {
		g.Interactive = g.Keychain
		copy.Grants[id] = g
	}
	p.ReaderAccess = copy
	return p
}

func productionReaderContext(ctx context.Context, p Paths, provider string) context.Context {
	if p.ReaderAccess == nil {
		return ctx
	} // compatibility for explicit legacy callers
	g, ok := p.ReaderAccess.Grants[provider]
	valid := ok && (g.StillValid == nil || g.StillValid())
	sum := sha256.Sum256([]byte("modelplan/consent/" + g.Generation))
	generation := hex.EncodeToString(sum[:])
	switch provider {
	case "copilot":
		return WithCopilotAccess(ctx, CopilotAccess{Allowed: valid, LoginGeneration: generation, StillValid: g.StillValid, Publish: g.Publish})
	case "antigravity":
		return WithAntigravityAccess(ctx, AntigravityAccess{Allowed: valid, LoginGeneration: generation, StillValid: g.StillValid, Publish: g.Publish})
	case "zai":
		ctx = WithZaiConfigAccess(ctx, ZaiConfigAccess{Allowed: valid, LoginGeneration: generation, StillValid: g.StillValid, Publish: g.Publish})
		if g.ConfigSource != nil {
			ctx = context.WithValue(ctx, zaiConfigSourceKey{}, *g.ConfigSource)
		}
	}
	return ctx
}

func (p Paths) ReaderAccessGrant(provider string) (ReaderGrant, bool) {
	if p.ReaderAccess == nil {
		return ReaderGrant{}, false
	}
	g, ok := p.ReaderAccess.Grants[provider]
	return g, ok
}

// publishReaderCache fences each legacy reader's own sanitized state, not just
// the aggregate native snapshot. Attempt reservations remain provider scoped.
func publishReaderCache(publish func(func() error) error, save func() bool) bool {
	write := func() error {
		if !save() {
			return errors.New("reader cache unavailable")
		}
		return nil
	}
	if publish != nil {
		return publish(write) == nil
	}
	return write() == nil
}

func forgetProductionReaderState(cache, tool string) error {
	if tool == "claude" {
		return localusage.ForgetProductionHistoryLocked(cache, tool)
	}
	names := map[string]string{"copilot": "copilot-v1.json", "antigravity": "antigravity-v1.json", "zai": "zai-config-v1.json", "amp": "amp-v1.json"}
	name := names[tool]
	if name == "" {
		return nil
	}
	path := filepath.Join(cache, "observed", name)
	b, status := readBounded(path, 256<<10)
	if status == "missing" {
		return nil
	}
	var state map[string]json.RawMessage
	if status != "" || json.Unmarshal(b, &state) != nil {
		return errors.New("reader cache unavailable")
	}
	// Keep attempt/backoff and access Deny; remove captures only.
	for _, key := range []string{"lastGood", "pools", "observedAt", "goodGeneration"} {
		delete(state, key)
	}
	state["availability"] = json.RawMessage(`"consent_required"`)
	b, err := json.Marshal(state)
	if err != nil {
		return errors.New("reader cache unavailable")
	}
	return writeAtomic(path, b)
}

// claudeSessionsDue shares the production refresh entry point, while its actual
// reservation is the projection engine's local floor, never a quota/network gate.
func claudeSessionsDue(p Paths, now time.Time) bool {
	a := p.ClaudeSessionAccess
	if a == nil || !a.Allowed || a.Denied || a.Privacy == consent.Off || os.Getenv("MODELPLAN_HISTORY") == "off" || nativeOff() || p.ClaudeSessionRoot == "" || (a.StillValid != nil && !a.StillValid()) {
		return false
	}
	if len(a.Key) != 32 {
		return true
	}
	cached := localusage.ReadProjectionCache(p.Cache, "claude", *a, now)
	return !now.Before(cached.NextAttemptAt)
}

// The caller already holds consent's ReaderLock. Only this explicit refresh may
// create the shared local-history installation key; ProductionPaths never does.
func refreshProductionClaudeSessions(ctx context.Context, p Paths, now time.Time) bool {
	a := p.ClaudeSessionAccess
	if a == nil || !a.Allowed || a.Denied || a.Privacy == consent.Off || os.Getenv("MODELPLAN_HISTORY") == "off" || nativeOff() || p.ClaudeSessionRoot == "" || (a.StillValid != nil && !a.StillValid()) {
		return false
	}
	home, _ := os.UserHomeDir()
	root, access := localusage.ProductionHistoryAccess(home, "claude", true)
	if root != p.ClaudeSessionRoot || !access.Allowed || access.Denied {
		return false
	}
	RefreshClaudeSessions(ctx, root, p.Cache, access, now)
	return ctx.Err() == nil
}

// A presence-only grant may precede creation of Cursor's standard store. Admit
// that compiled missing location so refresh can report file_missing. Existing
// files, symlinks and permission failures remain inadmissible.
func missingCursorProfile(root string) bool {
	if !filepath.IsAbs(root) {
		return false
	}
	if _, err := os.Lstat(root); !os.IsNotExist(err) {
		return false
	}
	for parent := filepath.Dir(root); ; parent = filepath.Dir(parent) {
		info, err := os.Lstat(parent)
		if err == nil {
			return info.IsDir() && info.Mode()&os.ModeSymlink == 0
		}
		if !os.IsNotExist(err) || parent == filepath.Dir(parent) {
			return false
		}
	}
}
