// SPDX-License-Identifier: MIT
package quota

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

// Exercise the shared on-disk format with a real Go writer and each shipped
// Python reader: a sparse day must not displace the recent burst samples.
func TestSparseDaySnapshotBurstMatchesSkillReaders(t *testing.T) {
	python, err := exec.LookPath("python3")
	if err != nil {
		t.Skip("Python reader parity requires python3")
	}
	isolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache := t.TempDir()
	reset := now.Add(4 * 24 * time.Hour)
	for minute := 0; minute <= 1500; minute += 5 {
		used := 20 * float64(minute) / 1455
		if minute >= 1455 {
			used = 20 + 20*float64(minute-1455)/45
		}
		raw, _ := json.Marshal(map[string]any{"model": map[string]string{"id": "synthetic"}, "rate_limits": map[string]any{
			"seven_day": map[string]any{"used_percentage": used, "resets_at": reset.Unix()},
		}})
		var in StatuslineInput
		if err := json.Unmarshal(raw, &in); err != nil {
			t.Fatal(err)
		}
		if err := RecordClaudeCode(cache, in, now.Add(time.Duration(minute-1500)*time.Minute)); err != nil {
			t.Fatal(err)
		}
	}
	data, err := os.ReadFile(snapshotPath(cache))
	var snapshot ccSnapshot
	if err != nil || json.Unmarshal(data, &snapshot) != nil || len(snapshot.Recent["weekly"]) <= 64 {
		t.Fatal("fixture must exercise truncated sparse-day history", err)
	}
	accounts, status := readClaudeCode(cache, "")
	if status.Status != "ok" || len(accounts) != 1 {
		t.Fatal(status)
	}
	Evaluate(&accounts[0], now)
	w := accounts[0].Windows[0]
	type burst struct {
		Rate   *float64 `json:"recentPercentPerHour"`
		Runout *int     `json:"runsOutInMinutes"`
		Pace   string   `json:"pace"`
	}
	want := burst{w.RecentPercentPerHour, w.RunsOutInMinutes, w.Pace}
	if want.Rate == nil || want.Runout == nil || want.Pace != "tight" {
		t.Fatal("fixture must produce a recent burst", want)
	}
	root, err := filepath.Abs("../../..")
	if err != nil {
		t.Fatal(err)
	}
	script := `import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("quota", sys.argv[1])
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)
accounts, status = q.read_claude_code(sys.argv[2])
assert status["status"] == "ok", status
w = accounts[0]["windows"][0]
q.eval_window(w, q.parse_time(sys.argv[3]))
print(json.dumps({k: w[k] for k in ("recentPercentPerHour", "runsOutInMinutes", "pace")}))
`
	for _, path := range []string{"skills/model-plan/scripts/quota.py", "claude-code/skills/model-plan/scripts/quota.py", "codex/skills/model-plan/scripts/quota.py"} {
		t.Run(path, func(t *testing.T) {
			cmd := exec.Command(python, "-B", "-c", script, filepath.Join(root, path), cache, now.Format(time.RFC3339))
			raw, err := cmd.CombinedOutput()
			if err != nil {
				t.Fatalf("Python reader: %v: %s", err, raw)
			}
			var got burst
			if err := json.Unmarshal(raw, &got); err != nil {
				t.Fatal(err, string(raw))
			}
			actual, _ := json.Marshal(got)
			expected, _ := json.Marshal(want)
			if string(actual) != string(expected) {
				t.Fatalf("burst parity: Go %s, Python %s", expected, actual)
			}
		})
	}
}
