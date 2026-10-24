package main

import (
	"bytes"
	"io"
	"strings"
	"testing"
)

func TestKimiConnectionConsentAndDisclosures(t *testing.T) {
	isolateHome(t)
	t.Setenv("KIMI_CODE_API_KEY", "")
	t.Setenv("SYNTHETIC_KIMI_KEY", "")
	old := startDetached
	defer func() { startDetached = old }()
	startDetached = func(...string) error { t.Fatal("offline connection started process"); return nil }
	var out bytes.Buffer
	if code := run([]string{"connect", "kimi", "--offline", "--region", "international", "--key-env", "SYNTHETIC_KIMI_KEY", "--lang", "en"}, nil, &out, &out); code != 0 {
		t.Fatal(code, out.String())
	}
	for _, want := range []string{"SYNTHETIC_KIMI_KEY", "https://api.kimi.ai", "Undocumented", "No key was read or request sent", "docs/kimi-code-quota.md"} {
		if !strings.Contains(out.String(), want) {
			t.Fatalf("missing %s: %s", want, out.String())
		}
	}
	t.Setenv("SYNTHETIC_KIMI_KEY", "synthetic-secret-must-not-print")
	out.Reset()
	if code := run([]string{"connections", "--json", "--offline"}, nil, &out, &out); code != 0 {
		t.Fatal(code, out.String())
	}
	if strings.Contains(out.String(), "synthetic-secret-must-not-print") || !strings.Contains(out.String(), "endpointNotice") {
		t.Fatal(out.String())
	}
	if code := run([]string{"connect", "kimi", "--backend", "codexbar", "--offline"}, nil, io.Discard, io.Discard); code != exitUsage {
		t.Fatal("credential backend accepted", code)
	}
	if code := run([]string{"disconnect", "kimi", "--offline"}, nil, io.Discard, io.Discard); code != 0 {
		t.Fatal(code)
	}
}
