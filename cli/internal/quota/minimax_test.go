package quota

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
)

var minimaxNow = time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)

// All response literals are handwritten synthetic fixtures, never live captures.
const minimaxModern = `{"base_resp":{"status_code":0},"data":{"model_remains":[{"model_name":"general","current_interval_status":1,"current_interval_remaining_percent":"76","current_interval_total_count":0,"current_interval_usage_count":0,"start_time":1792839600000,"end_time":1792857600000,"current_weekly_status":1,"current_weekly_remaining_percent":64,"weekly_end_time":1793361600000},{"model_name":"video","current_interval_remaining_percent":0}]}}`

func TestMiniMaxSchemasAndUnknowns(t *testing.T) {
	e, _ := parseMiniMax([]byte(minimaxModern), minimaxNow)
	if e.Status != "ok" || len(e.Windows) != 2 || *e.Windows[0].UsedPercent != 24 || *e.Windows[1].UsedPercent != 36 || e.Windows[0].ResetsAt == nil {
		t.Fatalf("modern: %+v", e)
	}
	legacy := `{"model_remains":[{"model_name":"MiniMax-M2.7","current_interval_total_count":100,"current_interval_usage_count":30,"end_time":1792857600}],"base_resp":{"status_code":"0"}}`
	e, _ = parseMiniMax([]byte(legacy), minimaxNow)
	if len(e.Windows) != 1 || math.Abs(*e.Windows[0].UsedPercent-70) > 0.00001 || e.Windows[0].Kind != "five_hour" {
		t.Fatalf("remaining counter reversed: %+v", e)
	}
	for _, raw := range []string{
		`{}`, `[]`, `{"model_remains":[]}`, `{"data":null}`, `{"base_resp":{}}`,
		`{"base_resp":{"status_code":1002,"status_msg":"synthetic secret"},"model_remains":[{"model_name":"general","current_interval_remaining_percent":0}]}`,
		`{"model_remains":[{"model_name":"video","current_interval_remaining_percent":0}]}`,
		`{"model_remains":[{"model_name":"general","current_interval_status":99,"current_interval_remaining_percent":100}]}`,
		`{"model_remains":[{"model_name":"general","current_interval_status":3,"current_interval_remaining_percent":100,"current_weekly_status":0,"current_weekly_remaining_percent":0}]}`,
	} {
		e, _ := parseMiniMax([]byte(raw), minimaxNow)
		if e.Status != "error" || len(e.Windows) != 0 || strings.Contains(e.Error, "synthetic secret") {
			t.Fatal("unsupported accepted or echoed", raw)
		}
	}
	for _, fields := range []string{
		`"current_interval_remaining_percent":null`,
		`"current_interval_remaining_percent":-1`,
		`"current_interval_remaining_percent":101`,
		`"current_interval_remaining_percent":"NaN"`,
		`"current_interval_total_count":0,"current_interval_usage_count":0`,
		`"current_interval_total_count":100,"current_interval_usage_count":101`,
		`"current_interval_total_count":100`,
		`"current_interval_remaining_percent":null,"current_interval_total_count":0,"current_interval_usage_count":0`,
	} {
		e, _ := parseMiniMax([]byte(`{"model_remains":[{"model_name":"general","end_time":1792857600000,`+fields+`}]}`), minimaxNow)
		if e.Status != "ok" || len(e.Windows) != 1 || e.Windows[0].UsedPercent != nil {
			t.Fatal("unknown became known", fields, e)
		}
	}
	e, _ = parseMiniMax([]byte(`{"model_remains":[{"model_name":"general","current_interval_remaining_percent":100,"current_weekly_remaining_percent":0,"weekly_end_time":1792700000000}]}`), minimaxNow)
	if len(e.Windows) != 2 || *e.Windows[0].UsedPercent != 0 || e.Windows[1].UsedPercent != nil {
		t.Fatal("explicit zero or expired reset failed")
	}
	_, retry := parseMiniMax([]byte(`{"base_resp":{"status_code":1004,"status_msg":"secret"}}`), minimaxNow)
	if !retry {
		t.Fatal("recognized rejection missing")
	}
}

func TestMiniMaxConsentRegionsBindingAndPrivacy(t *testing.T) {
	isolateHome(t)
	p := nativePaths(t)
	t.Setenv("MINIMAX_CODING_API_KEY", "synthetic-minimax-secret")
	hits := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits++
		if r.Method != "GET" || r.URL.Path != miniMaxCurrentPath || r.Header.Get("Authorization") != "Bearer synthetic-minimax-secret" || r.Header.Get("Cookie") != "" {
			t.Error("wrong passive request")
		}
		w.Write([]byte(minimaxModern))
	}))
	defer srv.Close()
	oldHosts, oldClient := minimaxHosts, nativeClient
	minimaxHosts = map[string]string{"international": srv.URL, "china": srv.URL}
	nativeClient = srv.Client()
	defer func() { minimaxHosts, nativeClient = oldHosts, oldClient }()
	if NativeDue(p, minimaxNow) {
		t.Fatal("key alone enabled adapter")
	}
	if err := RefreshNative(context.Background(), p, minimaxNow); err == nil || hits != 0 {
		t.Fatal("read without opt-in")
	}
	refs := []string{}
	for index, region := range []string{"international", "china"} {
		at := minimaxNow.Add(time.Duration(index) * NativeEvery)
		if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "minimax", Backend: BackendNative, Enabled: true, Region: region}); err != nil {
			t.Fatal(err)
		}
		if index > 0 {
			early := minimaxNow.Add(time.Minute)
			if NativeDue(p, early) {
				t.Fatal("region change bypassed interval")
			}
			if err := RefreshNative(context.Background(), p, early); err != nil {
				t.Fatal(err)
			}
			if hits != 1 {
				t.Fatal("region change repeated request early")
			}
		}
		if !NativeDue(p, at) {
			t.Fatal("region unavailable at next interval")
		}
		if err := RefreshNative(context.Background(), p, at); err != nil {
			t.Fatal(err)
		}
		e := loadNative(p.Cache).Providers[0]
		if e.SubscriptionRef == "" || e.Region != region || e.KeyEnv != "MINIMAX_CODING_API_KEY" {
			t.Fatal("missing region binding")
		}
		refs = append(refs, e.SubscriptionRef)
		if NativeDue(p, at.Add(time.Minute)) || !NativeDue(p, at.Add(NativeEvery)) {
			t.Fatal("cache cadence")
		}
	}
	if refs[0] == refs[1] {
		t.Fatal("region identities combined")
	}
	for _, path := range []string{nativePath(p.Cache), subscriptionsPath(p.Cache), p.ConnectionsFile} {
		b, _ := os.ReadFile(path)
		if strings.Contains(string(b), "synthetic-minimax-secret") {
			t.Fatal("key persisted")
		}
	}
	t.Setenv("MINIMAX_CODING_API_KEY", "different-synthetic-key")
	var r Report
	applyNative(&r, p, minimaxNow)
	if len(r.Accounts) != 0 || NativeDue(p, minimaxNow.Add(NativeEvery+time.Minute)) || !NativeDue(p, minimaxNow.Add(2*NativeEvery)) {
		t.Fatal("old-key quota reused or key change bypassed interval")
	}
	t.Setenv("MINIMAX_CODING_API_KEY", "")
	r = Report{}
	applyNative(&r, p, minimaxNow)
	if len(r.Accounts) != 0 {
		t.Fatal("removed key reused")
	}
	t.Setenv("MINIMAX_CODING_API_KEY", "synthetic-minimax-secret")
	t.Setenv("MODELPLAN_NATIVE", "off")
	if err := RefreshNative(context.Background(), p, minimaxNow); err == nil || hits != 2 {
		t.Fatal("kill switch ignored")
	}
	t.Setenv("MODELPLAN_NATIVE", "")
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "minimax", Backend: BackendNative, Enabled: false}); err != nil {
		t.Fatal(err)
	}
	if NativeDue(p, minimaxNow) {
		t.Fatal("disconnect ignored")
	}
}

func TestMiniMaxFallbackBoundaries(t *testing.T) {
	isolateHome(t)
	for _, tc := range []struct {
		name     string
		status   int
		body     string
		fallback bool
	}{
		{"not-found", 404, "", true}, {"forbidden", 403, "", false}, {"unauthorized", 401, "", false}, {"method", 405, "", true},
		{"vendor-auth", 200, `{"base_resp":{"status_code":1004,"status_msg":"synthetic-key-secret"}}`, true},
		{"rate-limited", 429, "", false}, {"server", 500, "", false}, {"redirect", 302, "", false},
		{"invalid", 200, "{", false}, {"unsupported", 200, `{}`, false},
		{"vendor-rate", 200, `{"base_resp":{"status_code":1002}}`, false},
		{"oversized", 200, strings.Repeat("x", nativeMaxBody+1), false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			paths := []string{}
			otherHits := 0
			other := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { otherHits++ }))
			defer other.Close()
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				paths = append(paths, r.URL.Path)
				if r.Header.Get("Authorization") != "Bearer synthetic-key-secret" {
					t.Error("key missing")
				}
				if r.URL.Path == miniMaxCurrentPath {
					w.Header().Set("Location", other.URL)
					w.WriteHeader(tc.status)
					w.Write([]byte(tc.body))
					return
				}
				if r.URL.Path != miniMaxLegacyPath {
					t.Error("unexpected route")
				}
				w.Write([]byte(minimaxModern))
			}))
			defer srv.Close()
			old := minimaxHosts
			minimaxHosts = map[string]string{"international": srv.URL, "china": other.URL}
			defer func() { minimaxHosts = old }()
			e := fetchMiniMax(context.Background(), srv.Client(), "international", "synthetic-key-secret", minimaxNow)
			want := 1
			if tc.fallback {
				want = 2
			}
			if len(paths) != want || otherHits != 0 || strings.Contains(e.Error, "synthetic-key-secret") {
				t.Fatal("unsafe fallback", paths, e.Error)
			}
			if tc.fallback && e.Status != "ok" {
				t.Fatal("legacy did not recover", e.Error)
			}
			if !tc.fallback && e.Status != "error" {
				t.Fatal("bad response accepted")
			}
		})
	}
	// Missing key, transport failure and cancelled context never probe another host.
	old := minimaxHosts
	defer func() { minimaxHosts = old }()
	srv := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { t.Error("unexpected request") }))
	minimaxHosts = map[string]string{"international": srv.URL}
	srv.Close()
	for _, key := range []string{"", "synthetic-secret"} {
		if e := fetchMiniMax(context.Background(), http.DefaultClient, "international", key, minimaxNow); e.Status != "error" {
			t.Fatal("missing source accepted")
		}
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if e := fetchMiniMax(ctx, http.DefaultClient, "international", "synthetic-secret", minimaxNow); e.Status != "error" {
		t.Fatal("cancel ignored")
	}
}
func TestMiniMaxNativeCacheResetAndErrorBackoff(t *testing.T) {
	isolateHome(t)
	p := nativePaths(t)
	t.Setenv("MINIMAX_CODING_API_KEY", "synthetic-key")
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "minimax", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	e, _ := parseMiniMax([]byte(minimaxModern), minimaxNow)
	ref := assignSubscription(p.Cache, "api-key:minimax:international", "synthetic-key", minimaxNow)
	e.Provider, e.Region, e.KeyEnv, e.SubscriptionRef = "minimax", "international", "MINIMAX_CODING_API_KEY", ref
	reset := minimaxNow.Add(time.Minute)
	e.Windows[0].ResetsAt = &reset
	save := func() {
		b, _ := json.Marshal(nativeSnap{SchemaVersion: 1, ObservedAt: minimaxNow, Providers: []codexbarEntry{e}})
		if err := writeAtomic(nativePath(p.Cache), b); err != nil {
			t.Fatal(err)
		}
	}
	save()
	r := Read(p, minimaxNow.Add(2*time.Minute))
	found := false
	for _, a := range r.Accounts {
		if a.Source == "native:minimax" {
			found = true
			if a.Windows[0].UsedPercent != nil || a.Windows[0].UnknownReason != "reset_passed" {
				t.Fatal("reset became full")
			}
		}
	}
	if !found {
		t.Fatal("missing sanitized reading")
	}
	e.Status, e.Error, e.Windows = "error", "MiniMax HTTP 429", nil
	save()
	if NativeDue(p, minimaxNow.Add(10*time.Minute)) || !NativeDue(p, minimaxNow.Add(30*time.Minute)) {
		t.Fatal("error backoff")
	}
	for _, bad := range []QuotaSource{{Provider: "minimax", Backend: BackendCodexBar}, {Provider: "minimax", Backend: BackendNative, Region: "auto"}, {Provider: "minimax", Backend: BackendNative, KeyEnv: "bad name"}} {
		if err := SetConnection(p.ConnectionsFile, bad); err == nil {
			t.Fatal(fmt.Sprintf("accepted invalid selection: %+v", bad))
		}
	}
}

func TestMiniMaxIdentityOffDoesNotReuseQuotaOrDefeatThrottle(t *testing.T) {
	isolateHome(t)
	p := nativePaths(t)
	t.Setenv("MINIMAX_CODING_API_KEY", "synthetic-key")
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "minimax", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	e, _ := parseMiniMax([]byte(minimaxModern), minimaxNow)
	e.Provider, e.Region, e.KeyEnv = "minimax", "international", "MINIMAX_CODING_API_KEY"
	e.SubscriptionRef = assignSubscription(p.Cache, "api-key:minimax:international", "synthetic-key", minimaxNow)
	b, _ := json.Marshal(nativeSnap{SchemaVersion: 1, ObservedAt: minimaxNow, Providers: []codexbarEntry{e}})
	if err := writeAtomic(nativePath(p.Cache), b); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_IDENTITY", "off")
	var r Report
	applyNative(&r, p, minimaxNow)
	if len(r.Accounts) != 0 {
		t.Fatal("unverifiable key cache reused")
	}
	if NativeDue(p, minimaxNow.Add(time.Minute)) || !NativeDue(p, minimaxNow.Add(NativeEvery)) {
		t.Fatal("identity-off defeated cadence")
	}
}
