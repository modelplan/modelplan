// SPDX-License-Identifier: MIT
package consent

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func grantedStore(t *testing.T) string {
	t.Helper()
	t.Setenv("HOME", t.TempDir())
	file := Path()
	now := time.Date(2026, 11, 6, 0, 0, 0, 0, time.UTC)
	if err := Change(file, func(s *State) error {
		for _, tool := range []string{"codex", "zai", "claude", "cursor"} {
			if err := Set(s, tool, true, "native:"+tool, "native", now); err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	return file
}

func TestVerifyReadersUnsetChangesNothing(t *testing.T) {
	file := grantedStore(t)
	s, err := Load(file)
	if err != nil {
		t.Fatal(err)
	}
	for _, tool := range []string{"codex", "zai", "claude"} {
		if !s.Allows(tool, Local, Automatic) {
			t.Fatalf("%s local denied without the switch", tool)
		}
	}
	if !s.AllowsScope(ScopeGeminiLocalHistory, Automatic) {
		t.Fatal("default-on gemini local history denied without the switch")
	}
}

func TestVerifyReadersNarrowsSavedAndDefaultConsent(t *testing.T) {
	file := grantedStore(t)
	t.Setenv(VerifyReadersEnv, "codex, zai")
	for name, load := range map[string]func(string) (State, error){"Load": Load, "ReadOnly": ReadOnly} {
		s, err := load(file)
		if err != nil {
			t.Fatal(err)
		}
		for _, scope := range []string{ScopeCodexLocalHistory, ScopeCodexRuntimeUsage, ScopeZaiLocalHistory} {
			if !s.AllowsScope(scope, Automatic) {
				t.Fatalf("%s: listed scope %s denied", name, scope)
			}
		}
		if !s.Allows("codex", Runtime, Automatic) || !s.Allows("zai", Local, Automatic) {
			t.Fatalf("%s: listed tool denied", name)
		}
		for _, scope := range []string{ScopeClaudeLocalHistory, ScopeClaudeAccountUsageSavedLogin, ScopeCursorLocalHistory,
			ScopeGeminiLocalHistory, ScopeCopilotRuntimeUsage, ScopeKiroRuntimeUsage} {
			if s.AllowsScope(scope, Automatic) {
				t.Fatalf("%s: unlisted scope %s allowed", name, scope)
			}
		}
		for _, tool := range []string{"claude", "cursor", "gemini", "amp"} {
			if s.Allows(tool, Local, Automatic) || s.Allows(tool, Credential, Automatic) || s.Allows(tool, Bridge, Automatic) {
				t.Fatalf("%s: unlisted tool %s allowed", name, tool)
			}
			if r, ok := s.Tools[tool]; ok && r.Allowed {
				t.Fatalf("%s: unlisted tool record %s still allowed", name, tool)
			}
		}
	}
	state, mode := Current()
	if mode != Automatic || state.Allows("claude", Local, mode) || !state.Allows("codex", Local, mode) {
		t.Fatal("Current must carry the narrowing")
	}
	if Capture().Allows("cursor", Local) {
		t.Fatal("Capture must carry the narrowing")
	}
}

func TestVerifyReadersNeverWidens(t *testing.T) {
	file := grantedStore(t)
	if err := Change(file, func(s *State) error {
		return Set(s, "codex", false, "native:codex", "native", time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	t.Setenv(VerifyReadersEnv, "codex,gemini")
	s, err := Load(file)
	if err != nil {
		t.Fatal(err)
	}
	if s.Allows("codex", Local, Automatic) || s.AllowsScope(ScopeCodexRuntimeUsage, Automatic) {
		t.Fatal("a listed tool the user denied must stay denied")
	}
	if s.Allows("codex", Local, Off) || s.AllowsScope(ScopeGeminiLocalHistory, Off) {
		t.Fatal("MODELPLAN_READERS=off must still win")
	}
	if s.Allows("gemini", Credential, Automatic) {
		t.Fatal("listing a tool must not grant a credential scope it never had")
	}
}

func TestVerifyReadersInvalidOrEmptyDeniesEverything(t *testing.T) {
	file := grantedStore(t)
	for _, value := range []string{"", "codex,Bad!", "../codex"} {
		t.Setenv(VerifyReadersEnv, value)
		s, err := Load(file)
		if err != nil {
			t.Fatal(err)
		}
		for _, d := range Definitions() {
			if s.AllowsScope(d.ID, Automatic) {
				t.Fatalf("%q: scope %s allowed", value, d.ID)
			}
		}
	}
}

func TestVerifyReadersIsNeverPersisted(t *testing.T) {
	file := grantedStore(t)
	before, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv(VerifyReadersEnv, "codex")
	if _, err := Load(file); err != nil {
		t.Fatal(err)
	}
	if after, _ := os.ReadFile(file); !bytes.Equal(before, after) {
		t.Fatal("Load under the switch rewrote the consent file")
	}
	// A real change made under the switch keeps the other tools' saved grants.
	if err := Change(file, func(s *State) error {
		if !s.Tools["claude"].Allowed {
			t.Fatal("Change saw the narrowed state")
		}
		s.Hinted["x"] = true
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	os.Unsetenv(VerifyReadersEnv)
	s, err := Load(file)
	if err != nil || !s.Tools["claude"].Allowed || !s.Tools["cursor"].Allowed || !s.Allows("claude", Local, Automatic) {
		t.Fatalf("narrowing leaked into the file: %+v %v", s.Tools, err)
	}
	if _, err := os.Stat(filepath.Join(filepath.Dir(file), "consent.v1.bak")); err == nil {
		t.Fatal("unexpected migration backup")
	}
}
