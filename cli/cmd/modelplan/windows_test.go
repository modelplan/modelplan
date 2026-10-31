package main

import (
	"bytes"
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/advise"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func windowsFixture(t *testing.T) publicationFixture {
	return newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		var data map[string]json.RawMessage
		if err := json.Unmarshal(doc["data"], &data); err != nil {
			t.Fatal(err)
		}
		now := time.Now().UTC()
		data["multiplierHorizon"] = publicationJSON(t, map[string]any{"from": now.Add(-time.Hour), "to": now.Add(48 * time.Hour), "selection": "highest-priority-no-stacking"})
		data["multipliers"] = publicationJSON(t, []map[string]any{{"ruleId": "base", "provider": "test", "planIds": []string{"test-pro"}, "models": []string{"Synthetic Z"}, "multiplier": 2, "startsAt": now.Add(-time.Hour), "endsAt": now.Add(48 * time.Hour), "status": "CONFIRMED"}, {"ruleId": "cheaper", "provider": "test", "planIds": []string{"test-pro"}, "models": []string{"Synthetic Z"}, "priority": 10, "multiplier": 1, "startsAt": now.Add(time.Hour), "endsAt": now.Add(48 * time.Hour), "status": "TENTATIVE"}})
		doc["data"] = publicationJSON(t, data)
	})
}

func commandRun(args ...string) (int, string, string) {
	var out, err bytes.Buffer
	code := run(args, nil, &out, &err)
	return code, out.String(), err.String()
}

func TestWindowsIsCacheOnlyPublicAndFiltersFlags(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	t.Setenv("MODELPLAN_CACHE", cache)
	f := windowsFixture(t)
	srv, hits := publicationServer(t, &f)
	t.Setenv("MODELPLAN_BASE", srv.URL)
	if code, _, err := publicationRun("--json"); code != 0 {
		t.Fatal(err)
	}
	initialHits := len(*hits)
	path := filepath.Join(os.Getenv("HOME"), ".config", "modelplan", "local.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(`{"personal":"not public"}`), 0600); err != nil {
		t.Fatal(err)
	}
	beforeCache, beforeHome := tree(t, cache), tree(t, os.Getenv("HOME"))
	old := startDetached
	defer func() { startDetached = old }()
	startDetached = func(...string) error { t.Fatal("started subprocess"); return nil }
	code, out, err := commandRun("windows", "--provider", "test", "--plan", "test-pro", "--model", "z-model", "--json")
	if code != 0 || err != "" || !strings.Contains(out, `"multiplier": 2`) || strings.Contains(out, "personal") {
		t.Fatalf("exit=%d out=%s err=%s", code, out, err)
	}
	var view struct {
		Groups []advise.WindowGroup `json:"groups"`
	}
	if parseErr := json.Unmarshal([]byte(out), &view); parseErr != nil {
		t.Fatal(parseErr)
	}
	if len(view.Groups) != 1 || len(view.Groups[0].Series) != 1 || view.Groups[0].Series[0].Next == nil || view.Groups[0].Series[0].Next.Multiplier == nil || *view.Groups[0].Series[0].Next.Multiplier != 1 || view.Groups[0].Series[0].Next.Status != "TENTATIVE" {
		t.Fatal("next field missing from real windows JSON", out)
	}
	if len(*hits) != initialHits || !reflect.DeepEqual(beforeCache, tree(t, cache)) || !reflect.DeepEqual(beforeHome, tree(t, os.Getenv("HOME"))) {
		t.Fatal("windows performed network/write work")
	}
	code, out, err = commandRun("windows", "--provider", "missing", "--json")
	if code != 0 || !strings.Contains(out, `"groups": []`) {
		t.Fatalf("exit=%d out=%s err=%s", code, out, err)
	}
}

func TestWindowsMissingCacheDoesNotCreateIt(t *testing.T) {
	isolateHome(t)
	cache := filepath.Join(t.TempDir(), "missing")
	t.Setenv("MODELPLAN_CACHE", cache)
	code, out, _ := commandRun("windows", "--json")
	if code != exitNoData || out != "" {
		t.Fatalf("exit=%d out=%s", code, out)
	}
	if _, err := os.Stat(cache); !os.IsNotExist(err) {
		t.Fatalf("cache created: %v", err)
	}
}

func TestLineupPositionalAndPlanBillingContext(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_CACHE", t.TempDir())
	f := windowsFixture(t)
	srv, _ := publicationServer(t, &f)
	t.Setenv("MODELPLAN_BASE", srv.URL)
	if code, _, err := publicationRun("--json"); code != 0 {
		t.Fatal(err)
	}
	for _, cmd := range []string{"lineup", "plan"} {
		code, out, err := commandRun(cmd, "z-dev", "--json", "--offline")
		if code != 0 || !strings.Contains(out, `"z-dev": {`) || strings.Contains(out, `"openai":`) {
			t.Fatalf("exit=%d out=%s err=%s", code, out, err)
		}
		if !strings.Contains(out, `"billingContext": []`) || !strings.Contains(out, "modelplan windows") {
			t.Fatal(out)
		}
		for _, args := range [][]string{{cmd, "z-dev", "a-dev"}, {cmd, "z-dev", "--dev", "a-dev"}} {
			if code, _, err := commandRun(args...); code != exitUsage || !strings.Contains(err, "usage:") {
				t.Fatalf("args=%v code=%d err=%s", args, code, err)
			}
		}
	}
	path := filepath.Join(os.Getenv("HOME"), ".config", "modelplan", "local.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(`{"schemaVersion":1,"plans":[{"planId":"test-pro"}]}`), 0600); err != nil {
		t.Fatal(err)
	}
	code, out, err := commandRun("plan", "z-dev", "--json", "--offline")
	for _, want := range []string{`"multiplierNow": 2`, `"baseCost": 2`, `"effectiveCost": 4`, `"nextCheaperAt":`, `"nextStatus": "TENTATIVE"`} {
		if !strings.Contains(out, want) {
			t.Fatalf("missing=%s exit=%d out=%s err=%s", want, code, out, err)
		}
	}
}
