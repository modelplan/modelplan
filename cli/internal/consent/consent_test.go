package consent

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestConsentPersistencePrivacyAndDeny(t *testing.T) {
	for _, class := range []string{Credential, Bridge, "keychain"} {
		if Empty().Allows("new-tool", class, Automatic) {
			t.Fatal("implicit import grant", class)
		}
	}
	file := filepath.Join(t.TempDir(), "shared", "consent.json")
	if err := Change(file, func(s *State) error {
		s.Privacy = Passive
		return Set(s, "claude", true, "native:claude-code", "native", time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	if err := Deny(file, "claude", "keychain"); err != nil {
		t.Fatal(err)
	}
	if err := Change(file, func(s *State) error { return Set(s, "claude", false, "", "", time.Now()) }); err != nil {
		t.Fatal(err)
	}
	if err := Change(file, func(s *State) error { return Set(s, "claude", true, "native:claude-code", "native", time.Now()) }); err != nil {
		t.Fatal(err)
	}
	s, err := Load(file)
	if err != nil {
		t.Fatal(err)
	}
	if s.Generation != 4 || s.Tools["claude"].ConsentTextVersion != TextVersion || !s.Tools["claude"].DeniedSources["keychain"] {
		t.Fatal(s)
	}
	for _, v := range []struct{ env, mode string }{{"", Passive}, {"passive", Passive}, {"off", Off}, {"automatic", Off}, {"invalid", Off}} {
		if s.Effective(v.env) != v.mode {
			t.Fatal(v)
		}
	}
	for _, class := range []string{Local, Runtime, ExplicitKey} {
		if !s.Allows("claude", class, Passive) {
			t.Fatal(class)
		}
	}
	for _, class := range []string{Credential, Bridge, "keychain"} {
		if s.Allows("claude", class, Passive) {
			t.Fatal(class)
		}
	}
	if s.Allows("claude", "keychain", Automatic) {
		t.Fatal("Deny was cleared")
	}
	if s.Allows("claude", Local, Off) {
		t.Fatal("off admitted a reader")
	}
	fi, _ := os.Stat(file)
	if fi.Mode().Perm() != 0600 {
		t.Fatal(fi.Mode())
	}
}

func TestConsentMalformedAndLockFailClosed(t *testing.T) {
	file := filepath.Join(t.TempDir(), "consent.json")
	if err := os.WriteFile(file, []byte(`{"schemaVersion":99}`), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := Load(file); err == nil {
		t.Fatal("accepted invalid state")
	}
	if err := Change(file, func(s *State) error { t.Fatal("modified invalid state"); return nil }); err == nil {
		t.Fatal("overwrote invalid state")
	}
	os.Remove(file)
	os.WriteFile(file+".lock", nil, 0600)
	if err := Change(file, func(s *State) error { t.Fatal("ignored lock"); return nil }); err == nil {
		t.Fatal("ignored lock")
	}
}
