package quota

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

var poolNow = time.Date(2026, 10, 17, 12, 0, 0, 0, time.UTC)

func tokenCount(at time.Time, limitID, limitName string, used float64, minutes int, resets time.Time) string {
	return fmt.Sprintf(`{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":%q,"limit_name":%s,"plan_type":"plus","primary":{"used_percent":%g,"window_minutes":%d,"resets_at":%d},"secondary":null}}}`,
		at.Format(time.RFC3339), limitID, limitName, used, minutes, resets.Unix())
}

// One Plus thread that used the main allowance, then GPT Reserve (its own weekly pool), or the
// other way round when mainLast.
func poolHome(t *testing.T, mainLast bool) string {
	home := t.TempDir()
	dir := filepath.Join(home, "sessions", "2026", "10", "17")
	os.MkdirAll(dir, 0o755)
	week := poolNow.Add(3 * 24 * time.Hour)
	main := []string{
		tokenCount(poolNow.Add(-50*time.Minute), "codex", "null", 20, 300, poolNow.Add(2*time.Hour)),
		tokenCount(poolNow.Add(-50*time.Minute), "codex", "null", 30, 10080, week),
	}
	reserve := []string{tokenCount(poolNow.Add(-40*time.Minute), "base_model_inference", `"gpt-reserve"`, 100, 10080, week.Add(time.Hour))}
	lines := []string{`{"timestamp":"2026-10-17T11:00:00Z","type":"session_meta","payload":{"id":"t1","source":"cli"}}`,
		`{"timestamp":"2026-10-17T11:01:00Z","type":"turn_context","payload":{"model":"gpt-6-sol","effort":"medium"}}`}
	if mainLast {
		lines = append(append(lines, reserve...), main...)
	} else {
		lines = append(append(lines, main...), reserve...)
	}
	b := []byte{}
	for _, l := range lines {
		b = append(append(b, l...), '\n')
	}
	os.WriteFile(filepath.Join(dir, "rollout-2026-10-17T11-00-00-t1.jsonl"), b, 0o644)
	return home
}

func TestReserveIsItsOwnPool(t *testing.T) {
	isolateHome(t)
	for _, c := range []struct {
		mainLast           bool
		pool, room, decide string
	}{
		{false, "reserve", "exhausted", "weekly"},
		{true, "", "spend", "weekly"}, // Reserve used up, the main allowance in surplus
	} {
		as, st := readCodex(poolHome(t, c.mainLast), "")
		if st.Status != "ok" || len(as) != 1 {
			t.Fatalf("read = %+v %+v", as, st)
		}
		a := as[0]
		Evaluate(&a, poolNow)
		limits := map[string]bool{}
		for _, w := range a.Windows {
			limits[w.Limit+"/"+w.Kind] = true
		}
		if len(a.Windows) != 3 || !limits["/five_hour"] || !limits["/weekly"] || !limits["reserve/weekly"] {
			t.Fatalf("windows = %v", limits)
		}
		if a.Pool != c.pool || a.Headroom != c.room || a.Deciding != c.decide {
			t.Errorf("mainLast=%v: pool %q headroom %q deciding %q, want %q %q %q", c.mainLast, a.Pool, a.Headroom, a.Deciding, c.pool, c.room, c.decide)
		}
	}
}

func TestAccountReadingKeepsReserveApart(t *testing.T) {
	isolateHome(t)
	var resp rlResponse
	raw := `{"rateLimitsByLimitId":{
 "codex":{"limitId":"codex","planType":"plus","primary":{"usedPercent":20,"windowDurationMins":300,"resetsAt":1792148400},"secondary":{"usedPercent":30,"windowDurationMins":10080,"resetsAt":1792649570}},
 "base_model_inference":{"limitId":"base_model_inference","limitName":"gpt-reserve","planType":"plus","primary":{"usedPercent":90,"windowDurationMins":10080,"resetsAt":1792653170}}}}`
	if err := json.Unmarshal([]byte(raw), &resp); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	if err := save(cache, snapFrom(&resp, acctNow)); err != nil {
		t.Fatal(err)
	}
	old := acctNow.Add(-time.Hour)
	r := Report{Accounts: []Account{{Source: "codex", Plan: "plus", ObservedAt: old,
		Windows: []Window{{Kind: "weekly", UsedPercent: ptr(25.0), WindowMinutes: 10080, ObservedAt: old}}}}}
	applyAccount(&r, cache, acctNow)
	got := map[string]float64{}
	for _, w := range r.Accounts[0].Windows {
		got[w.Limit+"/"+w.Kind] = *w.UsedPercent
	}
	if len(got) != 3 || got["/weekly"] != 30 || got["/five_hour"] != 20 || got["reserve/weekly"] != 90 {
		t.Fatalf("windows = %v", got)
	}
}
