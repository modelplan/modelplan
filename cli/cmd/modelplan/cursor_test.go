package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestCursorNativeConnectionConsent(t *testing.T) {
	isolateHome(t)
	old := startDetached
	defer func() { startDetached = old }()
	startDetached = func(...string) error { t.Fatal("offline connect started process"); return nil }
	for _, cmd := range [][]string{
		{"connect", "cursor", "--offline", "--lang", "en"},
		{"connections", "--json", "--offline"},
		{"desktop", "snapshot", "--json", "--offline"},
	} {
		var out bytes.Buffer
		if code := run(cmd, nil, &out, &out); code != 0 {
			t.Fatal(code, out.String())
		}
		for _, want := range []string{"state.vscdb", "cursor.com", "api2.cursor.sh", "Undocumented"} {
			if !strings.Contains(out.String(), want) {
				t.Fatalf("missing %s: %s", want, out.String())
			}
		}
	}
	var out bytes.Buffer
	if code := run([]string{"connect", "cursor", "--backend", "codexbar", "--offline", "--json"}, nil, &out, &out); code != 0 || !strings.Contains(out.String(), "codexbar-compat") {
		t.Fatal(code, out.String())
	}
	out.Reset()
	if code := run([]string{"disconnect", "cursor", "--offline", "--json"}, nil, &out, &out); code != 0 || !strings.Contains(out.String(), `"backend": "off"`) {
		t.Fatal(code, out.String())
	}
}
