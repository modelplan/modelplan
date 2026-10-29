// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func TestCursorConsentGrantAdmitsMissingStandardProfile(t *testing.T) {
	home := consentAPIHome(t)
	if err := os.MkdirAll(filepath.Join(home, ".cursor"), 0700); err != nil {
		t.Fatal(err)
	}
	initial := readConsentAPI(t)
	result := grantConsentAPI(t, apiRequest(t, 41, initial.Generation, []string{"cursor"}, nil, nil))
	tool := apiTools(result.Tools)["cursor"]
	if !tool.Detected || !tool.Allowed || tool.Backend != "native" {
		t.Fatal(tool)
	}
	p := quotaPaths(&store.Store{Dir: os.Getenv("MODELPLAN_CACHE")})
	grant, admitted := p.ReaderAccessGrant("cursor")
	if !admitted || !grant.SavedLogin || len(grant.Profiles) != 1 {
		t.Fatal("granted Cursor with missing standard profile was not admitted")
	}
	var out, stderr bytes.Buffer
	if code := run([]string{"doctor", "readers", "--json", "--refresh"}, nil, &out, &stderr); code != 0 {
		t.Fatal(code, stderr.String())
	}
	var diagnostic struct {
		Readers []quota.ReaderDiagnostic `json:"readers"`
	}
	if err := json.Unmarshal(out.Bytes(), &diagnostic); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, r := range diagnostic.Readers {
		if r.Provider == "cursor" {
			found = true
			if r.State != "unavailable:reader_error:file_missing" {
				t.Fatal(r)
			}
		}
	}
	if !found {
		t.Fatal("missing refreshed Cursor diagnostic")
	}
	out.Reset()
	if code := run([]string{"desktop", "--json", "--read-only", "--offline"}, nil, &out, &stderr); code != 0 {
		t.Fatal(code, stderr.String())
	}
	if err := contracttest.ValidateOutput("desktop", out.Bytes()); err != nil {
		t.Fatal(err)
	}
	var desktop struct {
		Connections []struct {
			ID    string `json:"id"`
			Quota struct {
				Reason string `json:"reason"`
			} `json:"quota"`
		} `json:"connections"`
	}
	if err := json.Unmarshal(out.Bytes(), &desktop); err != nil {
		t.Fatal(err)
	}
	found = false
	for _, c := range desktop.Connections {
		if c.ID == "native:cursor" {
			found = true
			if c.Quota.Reason != "file_missing" {
				t.Fatal(c)
			}
		}
	}
	if !found {
		t.Fatal("desktop Cursor reason missing")
	}
	for _, r := range quota.ReaderDiagnostics(p, time.Now()) {
		if r.Provider == "cursor" {
			if r.Detected != "yes" || r.Consent != "granted" || r.Admitted != "yes" {
				t.Fatal(r)
			}
			return
		}
	}
	t.Fatal("missing Cursor diagnostic")
}
