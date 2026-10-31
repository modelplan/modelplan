// SPDX-License-Identifier: MIT
package advise_test

import (
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"testing"
	"time"
)

func TestNextCalendarChangeFromSaturday(t *testing.T) {
	d, now := contracttest.WeekdayCalendar()
	groups := advise.Windows(d, advise.WindowFilter{Provider: "zai"}, now)
	if len(groups) != 1 || len(groups[0].Series) != 1 {
		t.Fatalf("groups=%+v", groups)
	}
	s := groups[0].Series[0]
	monday := time.Date(2026, 11, 2, 6, 0, 0, 0, time.UTC)
	if s.Now.Multiplier == nil || *s.Now.Multiplier != 1 || s.Next == nil || !s.Next.At.Equal(monday) || s.Next.Multiplier == nil || *s.Next.Multiplier != 3 || s.Next.Status != "CONFIRMED" {
		t.Fatalf("series=%+v next=%+v", s, s.Next)
	}
	if len(s.Changes) != 0 {
		t.Fatal("calendar extended the existing short-horizon changes feed", s)
	}
	raw, _ := json.Marshal(s)
	var wire map[string]json.RawMessage
	_ = json.Unmarshal(raw, &wire)
	for _, field := range []string{"model", "now", "changes", "next"} {
		if _, ok := wire[field]; !ok {
			t.Fatal("missing field", field, string(raw))
		}
	}
	// The supplement is public timing, never an extension of billing's verified pack.
	billing := advise.Billing(d, quota.Report{Accounts: []quota.Account{{Source: "user", Plan: "synthetic-pro", Region: "global"}}}, []*digest.Model{&d.Models[0]}, monday)
	if len(billing) != 1 || billing[0].MultiplierNow != nil {
		t.Fatal("calendar escaped into billing", billing)
	}
}

func TestNextCalendarMissingScopeAndStatus(t *testing.T) {
	for _, mode := range []string{"missing", "different model", "different plan", "expired", "tentative"} {
		t.Run(mode, func(t *testing.T) {
			d, now := contracttest.WeekdayCalendar()
			switch mode {
			case "missing":
				d.CalendarIntervals = nil
			case "different model":
				d.CalendarIntervals[0].Models = []string{"other"}
			case "different plan":
				d.CalendarIntervals[0].PlanIDs = []string{"other"}
			case "expired":
				now = d.CalendarTo
			case "tentative":
				d.CalendarIntervals[0].Status = "TENTATIVE"
			}
			groups := advise.Windows(d, advise.WindowFilter{Provider: "zai", Plan: "synthetic-pro", Model: "GLM-5.3"}, now)
			if len(groups) != 1 || len(groups[0].Series) != 1 {
				t.Fatal(groups)
			}
			next := groups[0].Series[0].Next
			if mode == "tentative" {
				if next == nil || next.Status != "TENTATIVE" {
					t.Fatal(next)
				}
			} else if next != nil {
				t.Fatal("invented next change", next)
			}
		})
	}
}

func TestNextCalendarFutureRangeWithUnknownCurrentRate(t *testing.T) {
	d, now := contracttest.WeekdayCalendar()
	d.MultiplierHorizon.To = now.Add(-time.Minute).Format(time.RFC3339)
	d.CalendarFrom = now.Add(time.Hour)
	groups := advise.Windows(d, advise.WindowFilter{Provider: "zai"}, now)
	if len(groups) != 1 || groups[0].Series[0].Now.Multiplier != nil || groups[0].Series[0].Next == nil || *groups[0].Series[0].Next.Multiplier != 3 {
		t.Fatal("known future schedule lost", groups)
	}
}
