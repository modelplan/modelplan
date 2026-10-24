package snapshot

import (
	"github.com/modelplan/modelplan/cli/internal/qwenusage"
	"testing"
	"time"
)

func TestQwenSnapshotRevisionAndFreshness(t *testing.T) {
	at := time.Date(2026, 10, 23, 10, 0, 0, 0, time.UTC)
	r := qwenusage.Report{Source: "qwen-code-export", Status: "ok", Periods: []qwenusage.Period{{Period: "day", Value: "2026-10-22", GeneratedAt: at}}}
	in := Input{Now: at.Add(time.Hour), QwenUsage: &r}
	a := Build(in)
	if a.SchemaVersion != 1 || a.QwenUsage == nil || len(a.Accounts) != 0 || a.ValidUntil == nil || !a.ValidUntil.Equal(at.Add(24*time.Hour)) {
		t.Fatalf("%+v", a)
	}
	in.Now = at.Add(25 * time.Hour)
	r.Periods[0].Stale = true
	b := Build(in)
	if a.DataRevision != b.DataRevision {
		t.Fatal("clock-only staleness changed revision")
	}
	n := int64(50)
	r.Periods[0].Totals.OutputTokens = &n
	if c := Build(in); c.DataRevision == b.DataRevision {
		t.Fatal("new aggregate did not change revision")
	}
}
