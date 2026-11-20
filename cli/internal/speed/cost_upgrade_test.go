// SPDX-License-Identifier: MIT
package speed

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// claudeFastTranscript is the redacted Claude fixture with its second response in fast mode.
func claudeFastTranscript(t *testing.T) string {
	t.Helper()
	src, err := os.ReadFile(filepath.Join("testdata", "accounting", "claude", "projects", "redacted", "session.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimSpace(string(src)), "\n")
	lines[2] = strings.Replace(lines[2], `"output_tokens":20}`, `"output_tokens":20,"speed":"fast"}`, 1)
	path := filepath.Join(t.TempDir(), "session.jsonl")
	if err := os.WriteFile(path, []byte(strings.Join(lines, "\n")+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

// stripTiers rewrites the accounting cache as a build before WP-06 left it: no tier on any
// record and no tiered mark on any file.
func stripTiers(t *testing.T, cache string) {
	t.Helper()
	l, ok := loadAccounting(cache)
	if !ok || len(l.Files) == 0 {
		t.Fatalf("no accounting cache to downgrade: %+v", l)
	}
	for k, f := range l.Files {
		f.Tiered = false
		for i := range f.Records {
			f.Records[i].Tier = ""
		}
		l.Files[k] = f
	}
	if err := saveAccounting(cache, l); err != nil {
		t.Fatal(err)
	}
}

// macrevd-1050-1 / macrevb-1050-1 / macrev2-1050-1. Invariant: a response whose speed tier was
// never recorded is never priced at the standard rate. An upgraded cache over an unchanged log
// agrees with a fresh scan, with and without a published fast multiplier; when the log is gone,
// its tokens still count but carry no price.
func TestUpgradedAccountingCacheNeverPricesAnUnrecordedTier(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	path := claudeFastTranscript(t)
	model := map[string]bool{"claude-sonnet-4-5-20250929": true}
	for _, c := range []struct {
		name  string
		tiers map[string]float64
	}{
		{"published fast multiplier", map[string]float64{"": 1, "fast": 2}},
		{"no fast multiplier", map[string]float64{"": 1}},
	} {
		fresh := t.TempDir()
		if err := ObserveClaude(fresh, path, false, Ingest{}, now); err != nil {
			t.Fatal(err)
		}
		want := view(t, fresh, now).Costs(&fakePricer{threshold: 1 << 40, models: model, tiers: c.tiers})

		upgraded := t.TempDir()
		if err := ObserveClaude(upgraded, path, false, Ingest{}, now); err != nil {
			t.Fatal(err)
		}
		stripTiers(t, upgraded)
		if err := ObserveClaude(upgraded, path, false, Ingest{}, now.Add(time.Minute)); err != nil {
			t.Fatal(err)
		}
		got := view(t, upgraded, now).Costs(&fakePricer{threshold: 1 << 40, models: model, tiers: c.tiers})
		if fmt.Sprint(got) != fmt.Sprint(want) {
			t.Fatalf("%s: upgraded cache %+v, fresh scan %+v", c.name, got, want)
		}
	}

	// The original log is gone: the legacy records survive, counted but unpriced.
	gone := t.TempDir()
	if err := ObserveClaude(gone, path, false, Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	stripTiers(t, gone)
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	if err := ObserveClaude(gone, path, false, Ingest{}, now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	rows := view(t, gone, now).Costs(&fakePricer{threshold: 1 << 40, models: model, tiers: map[string]float64{"": 1, "fast": 2}})
	if len(rows) != 1 || rows[0].PricedTokens != 0 || rows[0].UnpricedTokens != 3090 || rows[0].USD != 0 {
		t.Fatalf("legacy records without their log: %+v", rows)
	}
}

// macrevb-1050-2 / macrev2-1050-2. Invariant: priced use that a reader timed to the hour reaches
// the hourly ≈cost, and is counted once in its day. OpenCode is priced by day totals; its hours
// come from the ledger's hourly view as hour-only rows.
func TestOpenCodeHourlyUseIsPricedOnceInItsHour(t *testing.T) {
	utc(t)
	cache, home := t.TempDir(), t.TempDir()
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "data"))
	seedPerf(t, cache, t0.Add(-time.Minute))
	db := sqliteDB(t, OpenCodeDB(home), `
		CREATE TABLE session_v2 (id TEXT PRIMARY KEY, directory TEXT NOT NULL, project_id TEXT, fork_session_id TEXT, fork_boundary TEXT);
		CREATE TABLE session_message (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, type TEXT NOT NULL, seq INTEGER NOT NULL, data TEXT NOT NULL);`)
	exec(t, db, `INSERT INTO session_v2 VALUES ('ses', '/redacted', NULL, NULL, NULL)`)
	data := fmt.Sprintf(`{"id":"msg-1","time":{"created":%d,"completed":%d},"model":{"id":"glm-5.3","providerID":"zai"},"content":[{"text":"[redacted]"}],"tokens":{"input":100,"output":10,"reasoning":0,"cache":{"read":0,"write":0}}}`, ms(t0), ms(t0.Add(3*time.Second)))
	exec(t, db, `INSERT INTO session_message VALUES ('m1', 'ses', 'assistant', 1, ?)`, data)
	if err := ObserveOpenCode(cache, home, Ingest{}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	v := view(t, cache, t0.Add(time.Minute))
	if len(v.Hourly()) != 1 {
		t.Fatalf("the reader recorded no hour: %+v", v.Hourly())
	}
	rows := v.Costs(&fakePricer{models: map[string]bool{"glm-5.3": true}})
	var day, hour *CostRow
	for i := range rows {
		if rows[i].HourOnly {
			hour = &rows[i]
		} else {
			day = &rows[i]
		}
	}
	if len(rows) != 2 || day == nil || hour == nil {
		t.Fatalf("rows = %+v", rows)
	}
	if day.Hour != "" || day.PricedTokens != 110 || day.USD != 200 {
		t.Fatalf("day: %+v", *day)
	}
	if hour.Hour != localHour(t0) || hour.Day != day.Day || hour.PricedTokens != 110 || hour.USD != 200 {
		t.Fatalf("hour: %+v", *hour)
	}
}
