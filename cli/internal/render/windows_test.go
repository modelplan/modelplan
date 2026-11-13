package render

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
)

func billingFloat(v float64) *float64 { return &v }

func TestWindowsLocalTextUTCJSONAndUnverified(t *testing.T) {
	loc, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		t.Fatal(err)
	}
	original := time.Local
	time.Local = loc
	defer func() { time.Local = original }()
	at := time.Date(2026, 10, 28, 8, 0, 0, 0, time.UTC)
	groups := []advise.WindowGroup{{Provider: "synthetic", PlanIDs: []string{"pro", "max"}, Qualifications: []string{"requiresQuotaAvailable"}, Series: []advise.WindowSeries{
		{Now: advise.RatePoint{Multiplier: billingFloat(1), Status: "CONFIRMED"}, Changes: []advise.RatePoint{{At: at, Multiplier: billingFloat(0.5), Status: "TENTATIVE"}}},
		{Model: "Model", Now: advise.RatePoint{Status: "unknown"}, Changes: []advise.RatePoint{}},
	}}}
	for _, tc := range []struct {
		s             Style
		want, unknown string
	}{{Style{T: EN}, "unverified", "unknown"}, {Style{T: ZH}, "未核实", "未知"}} {
		var b bytes.Buffer
		tc.s.Windows(&b, groups)
		out := b.String()
		for _, want := range []string{"16:00", tc.want, tc.unknown, "\n  Model:", "--json"} {
			if !strings.Contains(out, want) {
				t.Fatalf("missing %s in %s", want, out)
			}
		}
	}
	b, err := json.Marshal(groups)
	if err != nil || !strings.Contains(string(b), "2026-10-28T08:00:00Z") {
		t.Fatalf("UTC JSON=%s %v", b, err)
	}
}

func TestBillingHintSingleOptionalAndUnknownNotZero(t *testing.T) {
	at := time.Now().Add(time.Hour).UTC()
	cs := []advise.BillingContext{
		{PlanID: "pro", Model: "m", BaseCost: billingFloat(4), MultiplierNow: billingFloat(1), EffectiveCost: billingFloat(4), Status: "CONFIRMED", NextCheaperAt: &at, NextMultiplier: billingFloat(0.5), NextStatus: "TENTATIVE"},
		{PlanID: "max", Model: "m", Status: "unknown", NextCheaperAt: &at},
	}
	var b bytes.Buffer
	s := Style{T: EN}
	s.BillingHint(&b, cs)
	if out := b.String(); strings.Count(out, "waiting is an option") != 1 || !strings.Contains(out, "half price") || !strings.Contains(out, "unverified") {
		t.Fatal(out)
	}
	if out := s.BillingSuffix(cs, "m"); !strings.Contains(out, "base 4 × 1 = 4 now") || !strings.Contains(out, "unknown = — now") {
		t.Fatal(out)
	}
	if out := BillingBrief(cs); !strings.Contains(out, "context only") || !strings.Contains(out, "user decides") {
		t.Fatal(out)
	}
}
