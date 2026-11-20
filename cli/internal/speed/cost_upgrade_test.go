// SPDX-License-Identifier: MIT
package speed

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
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
func openCodeTimedRequest(t *testing.T) (cache, home string) {
	cache, home, _ = openCodeTimedDB(t)
	return cache, home
}

func openCodeTimedDB(t *testing.T) (cache, home string, add func(id string, seq int, at time.Time)) {
	t.Helper()
	cache, home = t.TempDir(), t.TempDir()
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "data"))
	seedPerf(t, cache, t0.Add(-time.Minute))
	db := sqliteDB(t, OpenCodeDB(home), `
		CREATE TABLE session_v2 (id TEXT PRIMARY KEY, directory TEXT NOT NULL, project_id TEXT, fork_session_id TEXT, fork_boundary TEXT);
		CREATE TABLE session_message (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, type TEXT NOT NULL, seq INTEGER NOT NULL, data TEXT NOT NULL);`)
	exec(t, db, `INSERT INTO session_v2 VALUES ('ses', '/redacted', NULL, NULL, NULL)`)
	add = func(id string, seq int, at time.Time) {
		data := fmt.Sprintf(`{"id":"msg-%s","time":{"created":%d,"completed":%d},"model":{"id":"glm-5.3","providerID":"zai"},"content":[{"text":"[redacted]"}],"tokens":{"input":100,"output":10,"reasoning":0,"cache":{"read":0,"write":0}}}`, id, ms(at), ms(at.Add(3*time.Second)))
		exec(t, db, `INSERT INTO session_message VALUES (?, 'ses', 'assistant', ?, ?)`, id, seq, data)
	}
	add("m1", 1, t0)
	if err := ObserveOpenCode(cache, home, Ingest{}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	return cache, home, add
}

func TestOpenCodeHourlyUseIsPricedOnceInItsHour(t *testing.T) {
	utc(t)
	cache, _ := openCodeTimedRequest(t)
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

// macrevd-1050-6 / macrevb-1050-2 / macrev2-1050-2. Invariant: a timed hour stays in the hourly
// ≈cost for the whole rolling 48 hours, through the ledger's pruning, and then only the hour
// expires. t0 is 09:00 UTC; 40 hours later is 01:00 two local dates on, past the second midnight.
func TestOpenCodeHourSurvivesTheRolling48Hours(t *testing.T) {
	utc(t)
	cache, home, add := openCodeTimedDB(t)
	pricer := &fakePricer{models: map[string]bool{"glm-5.3": true}}
	seq := 1
	at := func(now time.Time) (hour, day *CostRow) {
		t.Helper()
		// A later request makes the observation save, and so prune, the ledger at that time.
		seq++
		add(fmt.Sprintf("m%d", seq), seq, now.Add(-time.Minute))
		if err := ObserveOpenCode(cache, home, Ingest{}, now); err != nil {
			t.Fatal(err)
		}
		rows := view(t, cache, now).Costs(pricer)
		for i := range rows {
			if rows[i].HourOnly && rows[i].Hour == localHour(t0) {
				hour = &rows[i]
			} else if !rows[i].HourOnly && rows[i].Day == day0(t0) {
				day = &rows[i]
			}
		}
		return hour, day
	}
	hour, d := at(t0.Add(40 * time.Hour))
	if hour == nil || hour.Hour != localHour(t0) || hour.PricedTokens != 110 || d == nil || d.PricedTokens != 110 {
		t.Fatalf("at 40h: hour %+v day %+v", hour, d)
	}
	hour, d = at(t0.Add(48*time.Hour + time.Minute))
	if hour != nil || d == nil || d.PricedTokens != 110 {
		t.Fatalf("after 48h: hour %+v day %+v (only the hour expires)", hour, d)
	}
}

func day0(at time.Time) string { return at.Local().Format("2006-01-02") }

// macrevb-1050-1 / macrev2-1050-1. Invariant (as in TestUpgradedAccountingCacheNeverPricesAnUnrecordedTier):
// a partial history import of a file whose live records predate tiers must not mark them tiered, so
// the next observation of the unchanged log rescans them; imported ownership survives.
func TestPartialImportKeepsLegacyLiveRecordsRescannable(t *testing.T) {
	f := newFixture(t)
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "config"))
	t.Setenv("MODELPLAN_READERS", "")
	raw, _ := json.Marshal(both().State())
	if err := os.MkdirAll(filepath.Dir(consent.Path()), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(consent.Path(), raw, 0o600); err != nil {
		t.Fatal(err)
	}
	path, out := accountingImportLog(t, f, "claude-code", -0.1, 0.1)
	seedPerf(t, f.cache, t0)
	observe := func() {
		t.Helper()
		if err := ObserveClaude(f.cache, path, false, Ingest{}, f.now); err != nil {
			t.Fatal(err)
		}
	}
	observe()
	stripTiers(t, f.cache)
	f.run(7, both())
	observe()
	l, ok := loadAccounting(f.cache)
	if !ok {
		t.Fatal("unreadable accounting cache")
	}
	imported, tierless := 0, 0
	for _, file := range l.Files {
		for _, r := range file.Records {
			if r.Imported {
				imported++
			}
			if r.Tier == "" {
				tierless++
			}
		}
	}
	if tierless != 0 || imported == 0 {
		t.Fatalf("after import and an unchanged observation: %d tierless records, %d imported", tierless, imported)
	}
	if got := accountingImportedOutput(t, f, "claude-code"); got != 2*out {
		t.Fatalf("total changed: %d want %d", got, 2*out)
	}
}
