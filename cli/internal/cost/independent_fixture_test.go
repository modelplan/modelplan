// SPDX-License-Identifier: MIT
package cost

import (
	"encoding/json"
	"math"
	"os"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

// The fixture is hand-calculated (testdata/cost-fixture/independent-cost.json); nothing in this repo produced
// its numbers. The cockpit asserts the same file (desktop/tests/cockpit/unit/independent-cost.test.mjs), so a
// wrong total (output-only tokens, the wrong window) cannot pass in both places by sharing one bug.
type fixtureLong struct {
	AboveInputTokens int64
	Input            float64
	Output           float64
	CacheRead        *float64
	CacheWrite       *float64
}

type fixtureRate struct {
	Input       float64
	Output      float64
	CacheRead   *float64
	CacheWrite  *float64
	LongContext *fixtureLong
}

type fixtureRequest struct {
	Model       string
	Input       int64
	CacheRead   int64
	CacheWrite  int64
	Output      int64
	Reasoning   int64
	ExpectedUsd *float64
}

type fixtureFast struct {
	Request     string
	Multiplier  float64
	ExpectedUsd float64
}

type independentFixture struct {
	Prices         map[string]fixtureRate
	Requests       map[string]fixtureRequest
	FastMultiplier fixtureFast
}

func fixturePrice(r fixtureRate) *digest.Price {
	p := &digest.Price{Input: r.Input, Output: r.Output, CacheRead: r.CacheRead, CacheWrite: r.CacheWrite, Source: "fixture", AsOf: "2026-11-20"}
	if lc := r.LongContext; lc != nil {
		p.LongContext = &digest.LongContextPrice{AboveInputTokens: lc.AboveInputTokens, Input: lc.Input, Output: lc.Output, CacheRead: lc.CacheRead, CacheWrite: lc.CacheWrite}
	}
	return p
}

func loadIndependentFixture(t *testing.T) independentFixture {
	t.Helper()
	raw, err := os.ReadFile("../../../testdata/cost-fixture/independent-cost.json")
	if err != nil {
		t.Fatal(err)
	}
	var fx independentFixture
	if err := json.Unmarshal(raw, &fx); err != nil {
		t.Fatal(err)
	}
	return fx
}

func buckets(r fixtureRequest) tokenacct.Buckets {
	return tokenacct.Buckets{Input: r.Input, CacheRead: r.CacheRead, CacheWrite: r.CacheWrite, Output: r.Output, Reasoning: r.Reasoning}
}

func TestRequestMatchesTheIndependentHandCalculatedFixture(t *testing.T) {
	fx := loadIndependentFixture(t)
	if len(fx.Requests) < 6 {
		t.Fatalf("fixture has %d requests", len(fx.Requests))
	}
	for name, r := range fx.Requests {
		got, ok := Request(fixturePrice(fx.Prices[r.Model]), buckets(r), 1)
		if r.ExpectedUsd == nil {
			if ok {
				t.Errorf("%s: priced %.9f, want unpriced", name, got)
			}
			continue
		}
		if !ok || math.Abs(got-*r.ExpectedUsd) > 1e-9 {
			t.Errorf("%s: got %.9f ok=%v, want %.9f", name, got, ok, *r.ExpectedUsd)
		}
	}
}

func TestFastMultiplierMatchesTheIndependentFixture(t *testing.T) {
	fx := loadIndependentFixture(t)
	r := fx.Requests[fx.FastMultiplier.Request]
	got, ok := Request(fixturePrice(fx.Prices[r.Model]), buckets(r), fx.FastMultiplier.Multiplier)
	if !ok || math.Abs(got-fx.FastMultiplier.ExpectedUsd) > 1e-9 {
		t.Fatalf("fast: got %.9f ok=%v, want %.9f", got, ok, fx.FastMultiplier.ExpectedUsd)
	}
}
