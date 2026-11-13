package render

import (
	"bytes"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/history"
)

func TestHistoryListsWeeksAndSummarisesFiveHourCycles(t *testing.T) {
	now := time.Date(2026, 10, 14, 10, 0, 0, 0, time.UTC)
	f := func(v float64) *float64 { return &v }
	d := &digest.Digest{Models: []digest.Model{{ID: "claude-opus-5-5", Name: "Claude Opus 5.5", Recommended: "medium",
		HarnessIDs: map[string][]string{"claude-code": {"claude-opus-5-5", "opus"}},
		Efforts:    []digest.Effort{{Effort: "medium", Label: "Med", Ability: f(70)}, {Effort: "high", Label: "High", Ability: f(74)}}}}}
	l := history.Ledger{SchemaVersion: 1, Cycles: []history.Cycle{
		{Source: "claude-code", Kind: "weekly", ResetsAt: now.Add(-7 * 24 * time.Hour), FirstUsed: 4, LastUsed: 64,
			Spent: []history.Share{{Model: "opus", Effort: "medium", Points: 18}, {Model: "claude-opus-5-5", Effort: "high", Points: 42}}},
		{Source: "claude-code", Kind: "weekly", ResetsAt: now.Add(50 * time.Hour), LastUsed: 30, Spent: []history.Share{{Model: "claude-opus-5-5", Effort: "", Points: 30}}},
		{Source: "claude-code", Kind: "five_hour", ResetsAt: now.Add(-24 * time.Hour), LastUsed: 40},
		{Source: "claude-code", Kind: "five_hour", ResetsAt: now.Add(-5 * time.Hour), LastUsed: 100, HitLimit: true},
	}}
	var b bytes.Buffer
	Style{T: ZH}.History(&b, l, d, "/c/observed/cycles.json", now)
	got := b.String()
	for _, want := range []string{
		"不上传；MODELPLAN_HISTORY=off 停止记录，删除 /c/observed/cycles.json 清空",
		"▲ Claude Code 每周\n  进行中，2天2时重置 · 用到 30% · Opus 5.5 ★Med 30 点\n",
		" 重置 · 用到 64% · Opus 5.5 High 42 点 · Opus 5.5 ★Med 18 点 · 开始记录前 4 点\n",
		"▲ Claude Code 5小时\n  最近 2 天 2 个周期 · 平均用到 70% · 用满 1 次\n",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("missing %q in:\n%s", want, got)
		}
	}
	b.Reset()
	Style{T: EN}.History(&b, history.Ledger{}, nil, "/c/observed/cycles.json", now)
	if !strings.Contains(b.String(), "Nothing recorded yet") {
		t.Errorf("empty = %s", b.String())
	}
}
