package history

import (
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestStatuslineAndEvaluatedReadShareHistoryCycle(t *testing.T) {
	cache := t.TempDir()
	reset := now.Add(4 * time.Hour)
	var in quota.StatuslineInput
	if err := json.Unmarshal([]byte(fmt.Sprintf(`{"rate_limits":{"five_hour":{"used_percentage":10,"resets_at":%d}}}`, reset.Unix())), &in); err != nil {
		t.Fatal(err)
	}
	first := quota.Report{Accounts: []quota.Account{in.Account(now)}}
	if err := Observe(cache, first, now); err != nil {
		t.Fatal(err)
	}
	second := first
	second.Accounts = append([]quota.Account(nil), first.Accounts...)
	second.Accounts[0].Windows = append([]quota.Window(nil), first.Accounts[0].Windows...)
	w := &second.Accounts[0].Windows[0]
	used := 20.0
	w.WindowMinutes, w.UsedPercent, w.ObservedAt = 300, &used, now.Add(time.Minute)
	if err := Observe(cache, second, now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	cycles := Load(cache).Cycles
	if len(cycles) != 1 || cycles[0].WindowMinutes != 300 || cycles[0].LastUsed != 20 {
		t.Fatalf("status-line and evaluated readings split: %+v", cycles)
	}
	pace := paceOf(t, cache, now.Add(time.Minute))
	if len(pace.Groups) != 1 || pace.Groups[0].WindowMinutes != 300 {
		t.Fatalf("pace split: %+v", pace.Groups)
	}
}

func TestPlanChangeStartsDistinctHistoryCycle(t *testing.T) {
	cache := t.TempDir()
	reset := now.Add(24 * time.Hour)
	first := reading("codex", "m", "high", "", 10, now, reset)
	first.Accounts[0].Plan = "plus"
	second := reading("codex", "m", "high", "", 20, now.Add(time.Minute), reset)
	second.Accounts[0].Plan = "pro"
	if err := Observe(cache, first, now); err != nil {
		t.Fatal(err)
	}
	if err := Observe(cache, second, now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	cycles := Load(cache).Cycles
	if len(cycles) != 2 || cycles[0].Plan != "plus" || cycles[1].Plan != "pro" {
		t.Fatalf("plan change merged: %+v", cycles)
	}
}
