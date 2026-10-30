// SPDX-License-Identifier: MIT
package releaseguard

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAppleBinaryBackstop(t *testing.T) {
	path := filepath.Join(t.TempDir(), "release")
	for _, tc := range []struct {
		data string
		hits int
	}{
		{"\xcf\xfa\xed\xfe\x00public_selector\x00", 0},
		{"\xcf\xfa\xed\xfe\x00_webProcessIdentifier\x00", 1},
	} {
		if err := os.WriteFile(path, []byte(tc.data), 0600); err != nil {
			t.Fatal(err)
		}
		hits, err := CheckBinary(path)
		if err != nil || len(hits) != tc.hits {
			t.Fatalf("hits=%v err=%v", hits, err)
		}
	}
	if _, err := CheckBinary(path + "-missing"); err == nil {
		t.Fatal("missing binary accepted")
	}
}
func TestAppleBinaryBackstopWiredToReleaseBuild(t *testing.T) {
	b, err := os.ReadFile("../../../.github/workflows/macos-distribution.yml")
	if err != nil {
		t.Fatal(err)
	}
	workflow := string(b)
	build := strings.Index(workflow, "run: bash desktop/native/tools/package-neutral.sh")
	scan := strings.Index(workflow, `--binary "$RUNNER_TEMP/neutral-build/ModelPlan Community.app/Contents/MacOS/ModelPlanCommunity"`)
	archive := strings.Index(workflow, "- name: Archive checked universal neutral app")
	upload := strings.Index(workflow, "- uses: actions/upload-artifact@v4")
	if build < 0 || scan <= build || archive <= scan || upload <= archive {
		t.Fatal("built release binary is not scanned before archive/upload")
	}
}
