// SPDX-License-Identifier: MIT
package releaseguard

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestAppleSPI(t *testing.T) {
	for _, tc := range []struct {
		name, path, source string
		hits               int
	}{
		{"private-property", "Bad.swift", `let pid = view._webProcessIdentifier`, 1},
		{"swift-kvc", "Bad.swift", `let pid = view.value(forKey: "_privatePID")`, 1},
		{"objc-kvc", "Bad.m", `[view valueForKey:@"_privatePID"];`, 1},
		{"selector", "Bad.swift", `view.perform(NSSelectorFromString("_privatePID"))`, 1},
		{"multiline", "Bad.swift", "view.value(\n forKey: \"_privatePID\")", 1},
		{"test-and", "Good.swift", "#if MODELPLAN_TEST_ONLY_SPI && DEBUG\nview._webProcessIdentifier\n#endif", 0},
		{"go-negated-or", "Bad.go", "//go:build MODELPLAN_TEST_ONLY_SPI || !darwin\n\npackage bad; var key = \"_webProcessIdentifier\"", 1},
		{"negated-else", "Good.swift", "#if !MODELPLAN_TEST_ONLY_SPI\nlet ok = true\n#else\nview._webProcessIdentifier\n#endif", 0},
		{"test-elseif", "Good.swift", "#if DEBUG\nlet ok = true\n#elseif MODELPLAN_TEST_ONLY_SPI\nview._webProcessIdentifier\n#endif", 0},
		{"commented-directive", "Bad.swift", "/*\n#if MODELPLAN_TEST_ONLY_SPI\n*/\nview._webProcessIdentifier", 1},
		{"objc-setter", "Bad.m", `[view setValue:value forKey:@"_privatePID"];`, 1},
		{"go-kvc-raw-string", "Bad.go", "package bad; func bad(){ obj.ValueForKey(`_privatePID`) }", 1},
		{"swift-raw-string", "Bad.swift", `view.value(forKey: #"_privatePID"#)`, 1},
		{"objc-c-selector", "Bad.m", `sel_registerName("_privatePID")`, 1},
		{"public-kvc", "Good.swift", `view.value(forKey: "title")`, 0},
		{"comment", "Good.swift", `// view._webProcessIdentifier`, 0},
		{"block-comment", "Good.swift", `/* view._webProcessIdentifier */ let ok = true`, 0},
		{"test-flag", "Test.swift", "#if MODELPLAN_TEST_ONLY_SPI\nview._webProcessIdentifier\n#endif", 0},
		{"nested-test-flag", "Test.swift", "#if MODELPLAN_TEST_ONLY_SPI\n#if DEBUG\nview._webProcessIdentifier\n#endif\n#endif", 0},
		{"else-is-release", "Bad.swift", "#if MODELPLAN_TEST_ONLY_SPI\nlet ok = true\n#else\nview._webProcessIdentifier\n#endif", 1},
		{"debug-is-release", "Bad.swift", "#if DEBUG\nview._webProcessIdentifier\n#endif", 1},
		{"or-not-test-only", "Bad.swift", "#if MODELPLAN_TEST_ONLY_SPI || DEBUG\nview._webProcessIdentifier\n#endif", 1},
		{"go-cgo", "Bad.go", "package bad\n/* [view valueForKey:@\"_privatePID\"]; */\nimport \"C\"", 1},
		{"go-release", "Bad.go", `package bad; var key = "_webProcessIdentifier"`, 1},
		{"go-test-tag", "Good.go", "//go:build MODELPLAN_TEST_ONLY_SPI\n\npackage good; var key = \"_webProcessIdentifier\"", 0},
		{"go-or-tag", "Bad.go", "//go:build MODELPLAN_TEST_ONLY_SPI || darwin\n\npackage bad; var key = \"_webProcessIdentifier\"", 1},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := AppleSPI(tc.path, tc.source); len(got) != tc.hits {
				t.Fatalf("got %v; want %d hits", got, tc.hits)
			}
		})
	}
}

func TestAppleTreeRejectsMinimalBadRelease(t *testing.T) {
	root := t.TempDir()
	for _, dir := range []string{"desktop/native/Sources", "clients/swift/Sources"} {
		if err := os.MkdirAll(filepath.Join(root, dir), 0700); err != nil {
			t.Fatal(err)
		}
	}
	bad := filepath.Join(root, "desktop/native/Sources/Bad.swift")
	if err := os.WriteFile(bad, []byte(`view.value(forKey: "_privatePID")`), 0600); err != nil {
		t.Fatal(err)
	}
	findings, err := CheckApple(root)
	if err != nil || len(findings) != 1 || findings[0].Path != "desktop/native/Sources/Bad.swift" || findings[0].Line != 1 {
		t.Fatalf("bad release not rejected: %v %v", findings, err)
	}
	if err := os.WriteFile(bad, []byte("#if MODELPLAN_TEST_ONLY_SPI\nview.value(forKey: \"_privatePID\")\n#endif\n"), 0600); err != nil {
		t.Fatal(err)
	}
	findings, err = CheckApple(root)
	if err != nil || len(findings) != 0 {
		t.Fatalf("test-only SPI rejected: %v %v", findings, err)
	}
}

func TestAppleReviewFixturesThroughTree(t *testing.T) {
	b, err := os.ReadFile("testdata/review-fixtures.json")
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
			path := filepath.Join(root, "desktop/native", fixture.Path)
			if err := os.WriteFile(path, []byte(fixture.Source), 0600); err != nil {
				t.Fatal(err)
			}
			hits, err := CheckApple(root)
			if err != nil || len(hits) != fixture.Hits {
				t.Fatalf("got %v, %v; want %d findings", hits, err, fixture.Hits)
			}
		})
	}
}
