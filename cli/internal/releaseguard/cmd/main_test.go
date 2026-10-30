// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestAppleReviewFixturesThroughCommand(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "releaseguard")
	if out, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, out)
	}
	b, err := os.ReadFile("../testdata/review-fixtures.json")
	if err != nil {
		t.Fatal(err)
	}
	var data struct {
		Fixtures []struct {
			Name, Path, Source string
			Hits               int
		}
	}
	if err := json.Unmarshal(b, &data); err != nil {
		t.Fatal(err)
	}
	for _, fixture := range data.Fixtures {
		t.Run(fixture.Name, func(t *testing.T) {
			root := t.TempDir()
			for _, dir := range []string{"desktop/native", "clients/swift"} {
				if err := os.MkdirAll(filepath.Join(root, dir), 0700); err != nil {
					t.Fatal(err)
				}
			}
			if err := os.WriteFile(filepath.Join(root, "desktop/native", fixture.Path), []byte(fixture.Source), 0600); err != nil {
				t.Fatal(err)
			}
			out, err := exec.Command(binary, "--root", root).CombinedOutput()
			if fixture.Hits == 0 {
				if err != nil {
					t.Fatalf("valid source rejected: %v: %s", err, out)
				}
				return
			}
			exit, ok := err.(*exec.ExitError)
			if !ok || exit.ExitCode() != 1 || !strings.Contains(string(out), "desktop/native/"+fixture.Path+":") {
				t.Fatalf("bad source accepted or wrong diagnostic: %v: %s", err, out)
			}
		})
	}
}
