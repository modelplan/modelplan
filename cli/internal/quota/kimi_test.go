package quota

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

var kimiNow = time.Date(2026, 10, 23, 12, 0, 0, 0, time.UTC)

func kimiFixture(t *testing.T, name string) []byte {
	t.Helper()
	b, e := os.ReadFile("testdata/kimi/" + name + ".json")
	if e != nil {
		t.Fatal(e)
	}
	return b
}
func TestKimiResponseGenerations(t *testing.T) {
	isolateHome(t)
	for _, tc := range []struct {
		name string
		used []float64
	}{{"counts", []float64{40, 24}}, {"ratios", []float64{12.5, 41, 73}}} {
		e := parseKimi(kimiFixture(t, tc.name), kimiNow)
		if e.Status != "ok" || len(e.Windows) != len(tc.used) {
			t.Fatalf("%s: %+v", tc.name, e)
		}
		for i, w := range e.Windows {
			if w.UsedPercent == nil || *w.UsedPercent != tc.used[i] || w.ResetsAt == nil {
				t.Fatalf("%s: %+v", tc.name, w)
			}
		}
	}
	for _, raw := range []string{`{}`, `{"error":{"message":"secret"}}`, `{"usages":[]}`} {
		if e := parseKimi([]byte(raw), kimiNow); e.Status != "error" || strings.Contains(e.Error, "secret") {
			t.Fatal(e)
		}
	}
	for _, raw := range []string{
		`{"usage":{"limit":"100"}}`,
		`{"usage":{"limit":0,"used":0}}`,
		`{"usages":{"limit_5h":{"used_ratio":-1}}}`,
		`{"usages":{"limit_5h":{"reset_time":"2026-10-24T00:00:00Z"}}}`,
		`{"usages":{"limit_5h":{"used_ratio":0.5,"reset_time":"2026-10-22T00:00:00Z"}}}`,
	} {
		e := parseKimi([]byte(raw), kimiNow)
		if len(e.Windows) != 1 || e.Windows[0].UsedPercent != nil {
			t.Fatalf("unknown became known: %+v", e)
		}
	}
	// Zero is known only when explicitly reported. Invalid ratios fall back to
	// valid counts, and matching reset periods retain the more exhausted value.
	raw := `{"usage":{"limit":100,"used":70,"resetTime":"2026-10-29T00:00:00Z"},"usages":{"limit_7d":{"used_ratio":0.3,"reset_time":"2026-10-29T00:00:00Z"},"limit_5h":{"used_ratio":0}}}`
	e := parseKimi([]byte(raw), kimiNow)
	if len(e.Windows) != 2 || *e.Windows[0].UsedPercent != 0 || *e.Windows[1].UsedPercent != 70 {
		t.Fatal(e)
	}
}

func TestKimiOptInRegionsCacheAndPrivacy(t *testing.T) {
	isolateHome(t)
	p := nativePaths(t)
	t.Setenv("KIMI_CODE_API_KEY", "synthetic-secret")
	t.Setenv("MODELPLAN_NATIVE", "")
	t.Setenv("MODELPLAN_IDENTITY", "")
	hits := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits++
		if r.URL.Path != "/coding/v1/usages" || r.Method != "GET" || r.Header.Get("Authorization") != "Bearer synthetic-secret" || r.Header.Get("Cookie") != "" {
			t.Errorf("wrong passive request")
		}
		w.Write(kimiFixture(t, "ratios"))
	}))
	defer srv.Close()
	oldHosts, oldClient := kimiHosts, nativeClient
	defer func() { kimiHosts, nativeClient = oldHosts, oldClient }()
	kimiHosts = map[string]string{"china": srv.URL, "international": srv.URL}
	nativeClient = srv.Client()
	if NativeDue(p, kimiNow) {
		t.Fatal("enabled by key alone")
	}
	if err := RefreshNative(context.Background(), p, kimiNow); err == nil || hits != 0 {
		t.Fatal("read without consent")
	}
	var refs []string
	for _, region := range []string{"china", "international"} {
		if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "kimi", Backend: BackendNative, Enabled: true, Region: region}); err != nil {
			t.Fatal(err)
		}
		if !NativeDue(p, kimiNow) {
			t.Fatal("region switch did not invalidate cache")
		}
		if err := RefreshNative(context.Background(), p, kimiNow); err != nil {
			t.Fatal(err)
		}
		if NativeDue(p, kimiNow.Add(5*time.Minute)) || !NativeDue(p, kimiNow.Add(NativeEvery)) {
			t.Fatal("cache throttle")
		}
		e := loadNative(p.Cache).Providers[0]
		refs = append(refs, e.SubscriptionRef)
		if e.SubscriptionRef == "" {
			t.Fatal("missing keyed identity")
		}
	}
	if refs[0] == refs[1] {
		t.Fatal("regions shared identity")
	}
	for _, path := range []string{nativePath(p.Cache), subscriptionsPath(p.Cache), p.ConnectionsFile} {
		b, _ := os.ReadFile(path)
		if strings.Contains(string(b), "synthetic-secret") || strings.Contains(string(b), "example.invalid") {
			t.Fatal("secret/account leaked")
		}
	}
	// Main's #117 freshness evaluator hides an expired current value while
	// retaining the original observation for snapshot revision/history.
	cached := loadNative(p.Cache)
	reset := kimiNow.Add(time.Minute)
	cached.Providers[0].Windows[0].ResetsAt = &reset
	encoded, _ := json.Marshal(cached)
	if err := os.WriteFile(nativePath(p.Cache), encoded, 0600); err != nil {
		t.Fatal(err)
	}
	report := Read(p, kimiNow.Add(2*time.Minute))
	found := false
	for _, a := range report.Accounts {
		if a.Source == "native:kimi" {
			for i := range a.Windows {
				w := &a.Windows[i]
				if w.Kind == "five_hour" {
					used, _ := w.ObservedUsage()
					if w.UsedPercent != nil || w.RemainingPercent != nil || w.UnknownReason != "reset_passed" || used == nil || *used != 12.5 {
						t.Fatalf("reset freshness lost original reading: %+v", w)
					}
					found = true
				}
			}
		}
	}
	if !found {
		t.Fatal("missing Kimi reset window")
	}
	t.Setenv("KIMI_CODE_API_KEY", "new-synthetic-key")
	if !NativeDue(p, kimiNow) {
		t.Fatal("key change did not invalidate cache")
	}
	var r Report
	applyNative(&r, p, kimiNow)
	if len(r.Accounts) != 0 {
		t.Fatal("old key quota reused")
	}
	t.Setenv("KIMI_CODE_API_KEY", "")
	r = Report{}
	applyNative(&r, p, kimiNow)
	if len(r.Accounts) != 0 || hits != 2 {
		t.Fatal("missing key read old quota")
	}
	t.Setenv("KIMI_CODE_API_KEY", "synthetic-secret")
	r = Report{}
	applyNative(&r, p, kimiNow.Add(61*time.Minute))
	if len(r.Accounts) != 0 {
		t.Fatal("stale quota remained known")
	}
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "kimi", Backend: BackendNative, Enabled: false}); err != nil {
		t.Fatal(err)
	}
	if NativeDue(p, kimiNow) {
		t.Fatal("disconnect did not stop reader")
	}
}

func TestKimiFailuresDoNotFollowRedirectsOrEchoBodies(t *testing.T) {
	isolateHome(t)
	for _, status := range []int{401, 403, 429, 500, 302, 200} {
		t.Run(http.StatusText(status), func(t *testing.T) {
			hits := 0
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				hits++
				w.Header().Set("Location", "/inference")
				w.WriteHeader(status)
				w.Write([]byte(`{"error":"secret-must-not-escape"}`))
			}))
			defer srv.Close()
			old := kimiHosts
			defer func() { kimiHosts = old }()
			kimiHosts = map[string]string{"china": srv.URL}
			e := fetchKimi(context.Background(), srv.Client(), "china", "synthetic-secret", kimiNow)
			b, _ := json.Marshal(e)
			if e.Status != "error" || hits != 1 || strings.Contains(string(b), "secret-must-not-escape") {
				t.Fatal(string(b), hits)
			}
			p := nativePaths(t)
			SetConnection(p.ConnectionsFile, QuotaSource{Provider: "kimi", Backend: BackendNative, Enabled: true})
			e.Provider, e.Region, e.KeyEnv = "kimi", "china", "KIMI_CODE_API_KEY"
			os.MkdirAll(filepath.Dir(nativePath(p.Cache)), 0700)
			snap, _ := json.Marshal(nativeSnap{SchemaVersion: 1, ObservedAt: kimiNow, Providers: []codexbarEntry{e}})
			os.WriteFile(nativePath(p.Cache), snap, 0600)
			t.Setenv("KIMI_CODE_API_KEY", "synthetic-secret")
			if NativeDue(p, kimiNow.Add(15*time.Minute)) || !NativeDue(p, kimiNow.Add(30*time.Minute)) {
				t.Fatal("failure backoff")
			}
		})
	}
}
