package advise

import (
	"math"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

// OtherPlan is another connected plan with clear room, named beside a low notice so the user
// knows it is there. It never switches anything and never recommends a plan the user lacks.
type OtherPlan struct {
	Name      string // display name: Codex, Claude, Z.ai, …
	Window    string // the window that decided: its kind (five_hour, weekly, monthly, …)
	Remaining float64
	ResetsIn  int
}

// RoomyPercent: a plan's least-remaining fresh window must keep at least this much, the share
// the brief already calls surplus.
const RoomyPercent = 30

// harnessVendors: sources that are the prompting harness's own plan under another reader.
var harnessVendors = map[string][]string{
	"claude-code": {"claude-code", "native:claude", "native:claude-code", "codexbar:claude"},
	"codex":       {"codex", "native:codex", "codexbar:codex"},
}

// OtherPlanWithRoom picks, among the connected plans other than the harness's own, the one
// with the most left. A plan counts by its least-remaining window that is fresh (read within
// the hour, not stale, its reset still ahead); percentages of different windows are not the
// same unit, so only that floor is compared, and the plan must not itself be tight. Stale,
// unread, reset-passed and hand-entered plans never count as having room.
func OtherPlanWithRoom(r quota.Report, harness string, now time.Time) *OtherPlan {
	own := map[string]bool{}
	for _, s := range harnessVendors[harness] {
		own[s] = true
	}
	var best *OtherPlan
	for i := range r.Accounts {
		a := &r.Accounts[i]
		if own[a.Source] || a.Source == "user" || a.Stale || a.Headroom == "conserve" || a.Headroom == "exhausted" {
			continue
		}
		var floor *OtherPlan
		for j := range a.Windows {
			w := &a.Windows[j]
			if w.RemainingPercent == nil || w.ResetsAt == nil || w.ResetsInMinutes == nil || w.Stale ||
				w.UnknownReason != "" || w.ObservedAt.IsZero() || w.ObservedAt.After(now) ||
				now.Sub(w.ObservedAt) > quota.ObservationFreshness || !w.ResetsAt.After(now) {
				continue
			}
			left := *w.RemainingPercent
			if math.IsNaN(left) || left < 0 || left > 100 {
				floor = nil // a reading that makes no sense leaves the plan out
				break
			}
			if floor == nil || left < floor.Remaining {
				floor = &OtherPlan{Window: w.Kind, Remaining: left, ResetsIn: *w.ResetsInMinutes}
			}
		}
		if floor == nil || floor.Remaining < RoomyPercent {
			continue
		}
		if best == nil || floor.Remaining > best.Remaining {
			floor.Name = planName(a.Source)
			best = floor
		}
	}
	return best
}

func planName(source string) string {
	switch source {
	case "claude-code":
		return "Claude"
	case "codex":
		return "Codex"
	}
	for _, p := range []string{"native:", "codexbar:"} {
		if id, ok := strings.CutPrefix(source, p); ok {
			if n := quota.ProviderName(id); n != "" {
				return n
			}
			return id
		}
	}
	return source
}
