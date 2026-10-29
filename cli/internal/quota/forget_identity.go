// SPDX-License-Identifier: MIT
package quota

import (
	"encoding/json"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// ForgetScopeIdentity removes ModelPlan's derived identity entries without
// changing its installation key, other tools or provider budget reservations.
func forgetScopeIdentity(cache, tool, scopeClass string) error {
	if _, status := readBounded(subscriptionsPath(cache), 256<<10); status == "missing" {
		return nil
	}
	unlock, ok := lockFile(filepath.Join(cache, "observed", "subscriptions.lock"), time.Now(), 10*time.Second)
	if !ok {
		return errors.New("identity cleanup busy")
	}
	defer unlock()
	raw, status := readBounded(subscriptionsPath(cache), 256<<10)
	if status == "missing" {
		return nil
	}
	var m subscriptionMap
	if status != "" || json.Unmarshal(raw, &m) != nil || m.SchemaVersion != 1 || m.Refs == nil {
		return errors.New("identity cleanup unavailable")
	}
	// Erase exact references found in this scope's captures, and its compiled
	// provider/profile namespaces. Keep unreferenced keys owned by other tools.
	prefixes := map[string][]string{"claude": {"claude-", "reader-profile:claude"}, "gemini": {"gemini-", "reader-profile:gemini"}, "grok": {"grok-", "reader-profile:grok"}, "kimi": {"kimi-", "reader-profile:kimi"}, "cursor": {"cursor-", "reader-profile:cursor"}, "codex": {"codex-"}, "copilot": {"copilot-"}, "kiro": {"kiro-"}, "antigravity": {"antigravity-"}}
	refs := map[string]bool{}
	var collect func(any)
	collect = func(v any) {
		switch x := v.(type) {
		case map[string]any:
			for k, v := range x {
				if k == "subscriptionRef" {
					if ref, ok := v.(string); ok {
						refs[ref] = true
					}
				} else {
					collect(v)
				}
			}
		case []any:
			for _, v := range x {
				collect(v)
			}
		}
	}
	files := []string{}
	if scopeClass == "" || scopeClass == consent.Credential {
		files = append(files, readerPath(cache, tool))
	}
	if scopeClass != consent.Credential && scopeClass != consent.Bridge {
		files = append(files, filepath.Join(cache, "observed", tool+"-account.json"), filepath.Join(cache, "observed", tool+"-v1.json"))
	}
	for _, file := range files {
		if b, status := readBounded(file, 256<<10); status == "" {
			var v any
			if json.Unmarshal(b, &v) == nil {
				collect(v)
			}
		}
	}
	for _, name := range []string{"native.json", "codexbar.json"} {
		if scopeClass == consent.Credential || scopeClass == consent.Bridge && name == "native.json" {
			continue
		}
		if b, status := readBounded(filepath.Join(cache, "observed", name), 256<<10); status == "" {
			var doc struct {
				Providers []map[string]any `json:"providers"`
			}
			if json.Unmarshal(b, &doc) == nil {
				for _, entry := range doc.Providers {
					if entry["provider"] == tool {
						collect(entry)
					}
				}
			}
		}
	}
	for id, item := range m.Refs {
		if refs[item.Ref] {
			delete(m.Refs, id)
			continue
		}
		for _, prefix := range prefixes[tool] {
			if scopeClass == consent.ExplicitKey || scopeClass == consent.Bridge {
				continue
			}
			if scopeClass == consent.Credential && tool == "claude" && prefix == "claude-" {
				prefix = "claude-oauth"
			}
			if strings.HasPrefix(item.Basis, prefix) {
				delete(m.Refs, id)
				break
			}
		}
	}
	encoded, err := json.Marshal(m)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(subscriptionsPath(cache)), 0700); err != nil {
		return err
	}
	return writeAtomic(subscriptionsPath(cache), append(encoded, '\n'))
}
