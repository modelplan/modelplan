// SPDX-License-Identifier: MIT
package appserver

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestCodexLocalChangeRespectsConsent(t *testing.T) {
	root := t.TempDir()
	file := filepath.Join(root, "sessions", "2026", "11", "05", "rollout-synthetic.jsonl")
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(file, []byte("one\n"), 0600); err != nil {
		t.Fatal(err)
	}
	calls := 0
	b := &SharedBackend{config: SharedConfig{Paths: func(consent.Admission) quota.Paths { calls++; return quota.Paths{CodexHome: root} }}}
	off := consent.NewAdmission(consent.Empty(), consent.Off)
	if got := b.codexLocalStamps(off); len(got) != 0 || calls != 0 {
		t.Fatal("read source paths with readers off")
	}
	deniedState := consent.Empty()
	if err := consent.Set(&deniedState, "codex", false, "native:codex", "native", time.Now()); err != nil {
		t.Fatal(err)
	}
	denied := consent.NewAdmission(deniedState, consent.Automatic)
	if got := b.codexLocalStamps(denied); len(got) != 0 || calls != 0 {
		t.Fatal("read source paths after explicit denial")
	}
	allow := consent.NewAdmission(consent.Empty(), consent.Automatic)
	before := b.codexLocalStamps(allow)
	if len(before) != 1 {
		t.Fatalf("implicit permitted source missing: %v", before)
	}
	if err := os.WriteFile(file, []byte("two longer\n"), 0600); err != nil {
		t.Fatal(err)
	}
	after := b.codexLocalStamps(allow)
	if len(after) != 1 || before[0] == after[0] {
		t.Fatal("local file modification was missed")
	}
}
