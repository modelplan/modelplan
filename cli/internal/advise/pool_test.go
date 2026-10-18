package advise

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestDecidingWindowIsThePools(t *testing.T) {
	main, reserve := 30.0, 95.0
	a := &quota.Account{Source: "codex", Deciding: "weekly", Windows: []quota.Window{
		{Kind: "weekly", Limit: "reserve", UsedPercent: &reserve},
		{Kind: "weekly", UsedPercent: &main},
	}}
	if w := deciding(a); w == nil || w.Limit != "" {
		t.Fatalf("main pool: deciding = %+v", w)
	}
	a.Pool = "reserve"
	if w := deciding(a); w == nil || w.Limit != "reserve" {
		t.Fatalf("reserve pool: deciding = %+v", w)
	}
}

func TestHintsNameTheirAllowance(t *testing.T) {
	reserve, main := 99.0, 30.0
	a := &quota.Account{Source: "codex", Plan: "plus", Pool: "reserve", Headroom: "exhausted", Deciding: "weekly", Windows: []quota.Window{
		{Kind: "weekly", UsedPercent: &main},
		{Kind: "weekly", Limit: "reserve", UsedPercent: &reserve},
	}}
	if w := deciding(a); w == nil || w.Limit != "reserve" {
		t.Fatalf("deciding = %+v", w)
	}
	es := accountEvents(a, nil, time.Date(2026, 10, 17, 12, 0, 0, 0, time.UTC), nil)
	if len(es) == 0 {
		t.Fatal("an exhausted Reserve gives a hint")
	}
	for _, e := range es {
		if e.Limit != "reserve" {
			t.Errorf("event %s about %q, want reserve", e.Type, e.Limit)
		}
	}
}
