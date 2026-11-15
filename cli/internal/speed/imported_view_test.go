package speed

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestImportedRowsNeverCountADayALiveLedgerCovers(t *testing.T) {
	adm := consent.Admission{}
	imp := ImportLedger{SchemaVersion: 1, Rows: []PerfRow{
		{Origin: OriginImport, Day: "2026-10-01", Source: "codex", ObservedOutputTokens: 1, GenMs: 5, EligibleRequests: 1},
		{Origin: OriginImport, Day: "2026-10-10", Source: "codex", ObservedOutputTokens: 2},
		{Origin: OriginImport, Day: "2026-10-12", Source: "codex", ObservedOutputTokens: 3},
		{Origin: OriginImport, Day: "2026-10-12", Source: "claude-code", ObservedOutputTokens: 4},
		{Day: "2026-10-02", Source: "codex", ObservedOutputTokens: 5}, // not tagged: never an imported row
	}}
	v := PerfView{OK: true, LongOK: true,
		Ledger: PerfLedger{Rows: []PerfRow{{Day: "2026-10-12", Source: "codex"}}},
		Long:   LongLedger{Since: time.Now(), Rows: []Daily{{Day: "2026-10-10", Source: "codex"}}}}
	// Nothing is admitted without a grant epoch matching the current consent.
	if got := v.ImportedRows(imp, adm); len(got) != 0 {
		t.Fatalf("unadmitted rows counted: %+v", got)
	}
	if got := v.ImportedRows(ImportLedger{}, adm); got != nil {
		t.Fatalf("empty ledger: %+v", got)
	}
}

func TestWithImportedAddsCountsOnly(t *testing.T) {
	live := PerfView{OK: true, Now: time.Date(2026, 11, 5, 12, 0, 0, 0, time.Local), Ledger: PerfLedger{Rows: []PerfRow{{Day: "2026-11-04", Source: "codex", Model: "a", ObservedRequests: 1, ObservedOutputTokens: 10}}}}
	merged := live.WithImported([]PerfRow{{Origin: OriginImport, Day: "2026-10-20", Source: "codex", Model: "a", ObservedRequests: 1, ObservedOutputTokens: 5}})
	if len(live.Ledger.Rows) != 1 || len(merged.Ledger.Rows) != 2 {
		t.Fatalf("the live view must stay as it was: %d %d", len(live.Ledger.Rows), len(merged.Ledger.Rows))
	}
	w := merged.HistoryWindows()
	if len(w) != 1 || w[0].Recent7d.ObservedOutputTokens != 10 || w[0].Recent30d.ObservedOutputTokens != 15 {
		t.Fatalf("windows %+v", w)
	}
	if got := ImportedFirstDay([]PerfRow{{Day: "2026-10-21"}, {Day: "2026-10-20"}}); got != "2026-10-20" || ImportedFirstDay(nil) != "" {
		t.Fatalf("first day %q", got)
	}
}
