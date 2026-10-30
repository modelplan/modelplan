// SPDX-License-Identifier: MIT
package consent

import (
	"os"
	"path/filepath"
	"testing"
)

func TestReadOnlyProjectsLegacyScopesWithoutMigration(t *testing.T) {
	dir := t.TempDir()
	file := filepath.Join(dir, "consent.json")
	raw := `{"schemaVersion":1,"generation":7,"privacy":"passive","tools":{"gemini":{"allowed":true,"consentTextVersion":2,"at":"2026-01-01T00:00:00Z","readerId":"native:gemini","backend":"native","deniedSources":{"local":true}}}}`
	if err := os.WriteFile(file, []byte(raw), 0600); err != nil {
		t.Fatal(err)
	}
	before, err := os.Stat(file)
	if err != nil {
		t.Fatal(err)
	}
	projected, err := ReadOnly(file)
	if err != nil {
		t.Fatal(err)
	}
	after, err := os.Stat(file)
	if err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	if string(b) != raw || !before.ModTime().Equal(after.ModTime()) {
		t.Fatal("read-only view changed consent")
	}
	if _, err := os.Stat(filepath.Join(dir, "consent.v1.bak")); !os.IsNotExist(err) {
		t.Fatal("read-only view created a backup")
	}
	if _, err := os.Stat(file + ".lock"); !os.IsNotExist(err) {
		t.Fatal("read-only view created a lock")
	}
	migrated, err := Load(file)
	if err != nil {
		t.Fatal(err)
	}
	for _, d := range Definitions() {
		if projected.AllowsScope(d.ID, Passive) != migrated.AllowsScope(d.ID, Passive) {
			t.Fatal("legacy projection differs from actual migration", d.ID)
		}
	}
}
