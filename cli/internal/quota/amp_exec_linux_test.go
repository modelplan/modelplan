package quota

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"testing"
)

func TestAmpExecutesSealedBytesAfterPathReplacement(t *testing.T) {
	isolateHome(t)
	// A harmless system echo executable stands in for an audited native runtime.
	// No Amp runtime, account, credential or provider is accessed.
	body, err := os.ReadFile("/bin/echo")
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "amp")
	if err := os.WriteFile(path, body, 0700); err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(body)
	file, err := ampVerifiedArtifact(path, hex.EncodeToString(sum[:]))
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	marker := filepath.Join(t.TempDir(), "replacement-ran")
	t.Setenv("MODELPLAN_TEST_AMP_MARKER", marker)
	replacement := filepath.Join(t.TempDir(), "replacement")
	_ = os.WriteFile(replacement, []byte("#!/bin/sh\ntouch \"$MODELPLAN_TEST_AMP_MARKER\"\n"), 0700)
	if err := os.Rename(replacement, path); err != nil {
		t.Fatal(err)
	}
	if _, err := file.WriteAt([]byte("mutate"), 0); err == nil {
		t.Fatal("verified artifact was mutable")
	}
	ctx := context.WithValue(context.Background(), ampArtifactKey{}, file)
	out, err := runAmpUsage(ctx, path)
	if err != nil || !bytes.Equal(bytes.TrimSpace(out), []byte("usage --no-color")) {
		t.Fatal(err, string(out))
	}
	if _, err := os.Stat(marker); !os.IsNotExist(err) {
		t.Fatal("unaudited replacement executed")
	}
}
