// SPDX-License-Identifier: MIT
package modeldisplay

import (
	"strings"
	"testing"
)

// G3-134: a model the publication does not list but whose name is readable is shown by a prettified raw name.
func TestDisplayPrettifiesAnUnlistedName(t *testing.T) {
	for raw, want := range map[string]string{
		"gpt-6.2-sol":                "Sol 6.2",
		"claude-opus-5-6":            "Opus 5.6",
		"claude-sonnet-5-6-20261101": "Sonnet 5.6",
		"claude-3-7-sonnet":          "Sonnet 3.7",
		"gemini-3-pro":               "Gemini 3 Pro",
		"gemini-3-pro-preview":       "Gemini 3 Pro Preview",
		"anthropic/claude-opus-5-6":  "Opus 5.6",
		"GPT-6.2-Sol":                "Sol 6.2",
		"glm-5.2":                    "Glm 5.2",
		"kimi_k3":                    "Kimi K3",
		"qwen3-max-latest":           "Qwen3 Max",
		"foo-bar-2-baz":              "Foo Bar 2 Baz",
	} {
		got, ok := Display(raw)
		if !ok || got != want {
			t.Errorf("Display(%q) = %q, %v; want %q", raw, got, ok, want)
		}
	}
}

// Unreadable names are not shown: the strip reads "Unknown model" for them (V1-FINAL 8.7).
func TestDisplayRefusesUnreadableNames(t *testing.T) {
	long := ""
	for i := 0; i < 70; i++ {
		long += "a"
	}
	for _, raw := range []string{"", "unknown", " ", "gpt", "claude", "20261101", "a b", "x\ny", "../../etc", "model‮txt", long, "<b>x</b>", "sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789"} {
		if got, ok := Display(raw); ok {
			t.Errorf("Display(%q) = %q, true; want unreadable", raw, got)
		}
	}
}

// The longest readable raw name still fits the wire field (macrevb-1024-6).
func TestDisplayNeverExceedsTheWireBound(t *testing.T) {
	for _, raw := range []string{strings.Repeat("a-", 32), strings.Repeat("ab-1-", 12) + "abcd", strings.Repeat("abcdefgh", 8), "claude-" + strings.Repeat("x", 57), strings.Repeat("1-a-", 16)} {
		if len(raw) > 64 {
			t.Fatalf("test input %q is longer than a readable name", raw)
		}
		got, ok := Display(raw)
		if ok && (len(got) > MaxDisplay || got == "" || strings.HasSuffix(got, " ")) {
			t.Errorf("Display(%q) = %q (%d)", raw, got, len(got))
		}
	}
	got, ok := Display(strings.Repeat("abcdefgh", 8))
	if !ok || len(got) != MaxDisplay {
		t.Errorf("the longest single word is cut to the bound: %q %v", got, ok)
	}
}

// Truncation never leaves an empty or punctuation-only name with ok=true (macrevb-1024-6, round 2): such a name is
// unreadable, and what is returned always fits the wire bounds (1 to 48 characters).
func TestDisplayTruncationTable(t *testing.T) {
	long := func(n int) string { return strings.Repeat("a", n) }
	for name, raw := range map[string]string{
		"dots only":               "...",
		"vendor dots then a":      "vendor/" + strings.Repeat(".", 48) + "a",
		"dots at the boundary":    strings.Repeat("a", 47) + "." + strings.Repeat(".", 10),
		"empty tail":              "vendor/",
		"emoji":                   "gpt-6-\U0001F600",
		"multibyte at boundary":   strings.Repeat("a", 47) + "\u00e9" + "b",
		"punctuation after words": "x-" + strings.Repeat("-.", 20),
		"exactly 48":              long(48),
		"49":                      long(49),
		"64":                      long(64),
		"65":                      long(65),
	} {
		got, ok := Display(raw)
		if !ok {
			if got != "" {
				t.Errorf("%s: unreadable but returned %q", name, got)
			}
			continue
		}
		if n := len([]rune(got)); n < 1 || n > MaxDisplay || strings.Trim(got, " .") == "" {
			t.Errorf("%s: Display(%q) = %q (%d runes)", name, raw, got, n)
		}
	}
	for raw, want := range map[string]bool{"...": false, "vendor/": false, "gpt-6-\U0001F600": false, strings.Repeat("a", 47) + "\u00e9" + "b": false, strings.Repeat("a", 48): true, strings.Repeat("a", 49): true, strings.Repeat("a", 65): false} {
		if _, ok := Display(raw); ok != want {
			t.Errorf("Display(%q) ok = %v, want %v", raw, ok, want)
		}
	}
	if got, _ := Display(strings.Repeat("a", 48)); len(got) != 48 {
		t.Errorf("exactly 48 is kept whole: %q", got)
	}
}
