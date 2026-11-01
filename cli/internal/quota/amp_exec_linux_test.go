package quota

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The test binary doubles as the stand-in runtime: re-executed with this
// variable set, it echoes its arguments. /bin/echo cannot be used because
// multi-call coreutils (Ubuntu 26.04) dispatch on argv[0], which is the Amp path.
func init() {
	if os.Getenv("MODELPLAN_TEST_AMP_ECHO") == "1" {
		fmt.Println(strings.Join(os.Args[1:], " "))
		os.Exit(0)
	}
}

func TestAmpExecutesSealedBytesAfterPathReplacement(t *testing.T) {
	isolateHome(t)
	// This test binary, in echo mode, stands in for an audited native runtime.
	// No Amp runtime, account, credential or provider is accessed.
	self, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	body, err := os.ReadFile(self)
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_TEST_AMP_ECHO", "1")
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
