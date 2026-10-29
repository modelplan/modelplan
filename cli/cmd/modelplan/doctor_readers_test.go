// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestDoctorReadersCacheOnlyOutput(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "")
	cache := filepath.Join(t.TempDir(), "missing-cache")
	t.Setenv("MODELPLAN_CACHE", cache)
	old := startDetached
	t.Cleanup(func() { startDetached = old })
	startDetached = func(...string) error { t.Fatal("doctor started a process"); return nil }
	home, _ := os.UserHomeDir()
	before := tree(t, home)
	var out, stderr bytes.Buffer
	args := []string{"doctor", "readers", "--json", "--lang", "en", "--base", "invalid://synthetic.person@example.invalid/private"}
	if code := run(args, nil, &out, &stderr); code != 0 || stderr.Len() != 0 {
		t.Fatal(code, stderr.String(), out.String())
	}
	var report struct {
		Readers []quota.ReaderDiagnostic `json:"readers"`
		Message string                   `json:"message"`
	}
	if err := json.Unmarshal(out.Bytes(), &report); err != nil {
		t.Fatal(err)
	}
	if len(report.Readers) != 12+len(localusage.HistoryProviders()) || report.Message != "Paste this whole output back to the coordinator; it contains no personal data." {
		t.Fatal(out.String())
	}
	jsonBytes := out.String()
	for _, lang := range []string{"en", "zh"} {
		out.Reset()
		if code := run([]string{"doctor", "readers", "--lang", lang}, nil, &out, &stderr); code != 0 {
			t.Fatal(code, stderr.String())
		}
		for _, r := range report.Readers {
			if !strings.Contains(out.String(), r.Provider+"  detected="+r.Detected+"  consent="+r.Consent+"  admitted="+r.Admitted+"  state="+r.State+"  windows=0  last=unknown  beta=") {
				t.Fatal("text and JSON disagree", r, out.String())
			}
		}
		if !strings.Contains(out.String(), report.Message) {
			t.Fatal("missing safe-sharing line")
		}
		if lang == "zh" && !strings.Contains(out.String(), "其中不含个人数据") {
			t.Fatal("missing Chinese line")
		}
		for _, hidden := range []string{home, cache, "synthetic.person@example.invalid", "invalid://"} {
			if strings.Contains(out.String()+jsonBytes, hidden) {
				t.Fatal("unsafe output", hidden)
			}
		}
	}
	if _, err := os.Stat(cache); !os.IsNotExist(err) {
		t.Fatal("cache was created", err)
	}
	if !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("cache-only diagnostics wrote files")
	}
}

func TestDoctorReadersRefreshAndFlagValidation(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "off")
	t.Setenv("MODELPLAN_CACHE", t.TempDir())
	for _, args := range [][]string{{"doctor", "readers", "--refresh", "--json"}, {"doctor", "readers", "--json", "--refresh"}} {
		var out, stderr bytes.Buffer
		if code := run(args, nil, &out, &stderr); code != 0 || stderr.Len() != 0 || !json.Valid(out.Bytes()) {
			t.Fatal(code, stderr.String(), out.String())
		}
	}
	for _, args := range [][]string{{"doctor", "readers", "extra"}, {"doctor", "readers", "--share"}, {"doctor", "readers", "--offline", "--refresh"}, {"doctor", "--refresh"}, {"quota", "--refresh"}} {
		var out, stderr bytes.Buffer
		if code := run(args, nil, &out, &stderr); code != exitUsage || out.Len() != 0 {
			t.Fatal(args, code, stderr.String(), out.String())
		}
	}
}
