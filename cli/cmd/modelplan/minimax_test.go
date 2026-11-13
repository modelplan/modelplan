package main

import (
	"bytes"
	"io"
	"strings"
	"testing"
)

func TestMiniMaxConnectionConsentAndDisclosure(t *testing.T) {
	isolateHome(t)
	t.Setenv("MINIMAX_CODING_API_KEY", "")
	t.Setenv("SYNTHETIC_MINIMAX_KEY", "")
	old := startDetached
	defer func() { startDetached = old }()
	startDetached = func(...string) error { t.Fatal("offline connection started process"); return nil }
	var out bytes.Buffer
	if code := run([]string{"connect", "minimax", "--offline", "--region", "china", "--key-env", "SYNTHETIC_MINIMAX_KEY", "--lang", "en"}, strings.NewReader("yes\n"), &out, &out); code != 0 {
		t.Fatal(code, out.String())
	}
	for _, want := range []string{"SYNTHETIC_MINIMAX_KEY", "https://api.minimaxi.com", "documented on www.minimax.io", "undocumented", "no-key"} {
		if !strings.Contains(out.String(), want) {
			t.Fatal("missing disclosure", want, out.String())
		}
	}
	t.Setenv("SYNTHETIC_MINIMAX_KEY", "synthetic-minimax-key-must-not-print")
	for _, cmd := range [][]string{{"connections", "--json", "--offline"}, {"desktop", "--json", "--offline"}} {
		out.Reset()
		if code := run(cmd, nil, &out, &out); code != 0 {
			t.Fatal(code, out.String())
		}
		for _, want := range []string{"SYNTHETIC_MINIMAX_KEY", "api.minimaxi.com", "endpointNotice", "token_plan/remains", "coding_plan/remains"} {
			if !strings.Contains(out.String(), want) {
				t.Fatal("missing disclosure", want)
			}
		}
		if strings.Contains(out.String(), "synthetic-minimax-key-must-not-print") {
			t.Fatal("secret printed")
		}
	}
	if code := run([]string{"connect", "minimax", "--backend", "codexbar", "--offline"}, nil, io.Discard, io.Discard); code != exitUsage {
		t.Fatal("unsupported backend accepted")
	}
	if code := run([]string{"disconnect", "minimax", "--offline"}, nil, io.Discard, io.Discard); code != 0 {
		t.Fatal("disconnect failed")
	}
}
