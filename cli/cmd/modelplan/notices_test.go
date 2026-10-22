package main

import (
	"os"
	"os/exec"
	"strings"
	"testing"
)

// THIRD-PARTY-NOTICES.md ships with the binary; every module linked into it needs its entry.
func TestThirdPartyNoticesCoverTheBinary(t *testing.T) {
	out, err := exec.Command("go", "list", "-deps", "-f", "{{if .Module}}{{.Module.Path}} {{.Module.Version}}{{end}}", ".").Output()
	if err != nil {
		t.Skip("go list unavailable:", err)
	}
	b, err := os.ReadFile("../../THIRD-PARTY-NOTICES.md")
	if err != nil {
		t.Fatal(err)
	}
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if line == "" || strings.HasPrefix(line, "github.com/modelplan/") {
			continue
		}
		if !strings.Contains(string(b), "## "+line+"\n") {
			t.Errorf("THIRD-PARTY-NOTICES.md has no entry for %s", line)
		}
	}
}
