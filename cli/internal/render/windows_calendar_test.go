// SPDX-License-Identifier: MIT
package render_test

import (
	"bytes"
	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/render"
	"strings"
	"testing"
	"time"
)

func TestWindowsSaturdayShowsMondayBeyondPack(t *testing.T) {
	d, now := contracttest.WeekdayCalendar()
	groups := advise.Windows(d, advise.WindowFilter{Provider: "zai"}, now)
	for _, lang := range []render.Text{render.EN, render.ZH} {
		var out bytes.Buffer
		render.Style{T: lang}.Windows(&out, groups)
		if !strings.Contains(out.String(), "GLM-5.3: ×1 → Mon 14:00 CST ×3") {
			t.Fatal(out.String())
		}
	}
}

func TestWindowsDistantChangesKeepCalendarDate(t *testing.T) {
	now := time.Date(2026, 10, 31, 2, 0, 0, 0, time.UTC) // Saturday 10:00 CST
	one, three := 1.0, 3.0
	for _, tc := range []struct {
		days int
		want string
	}{{2, "Mon 14:00 CST ×3"}, {16, "Mon Nov 16 14:00 CST ×3"}} {
		next := advise.RatePoint{At: now.Add(time.Duration(tc.days)*24*time.Hour + 4*time.Hour), Multiplier: &three, Status: "active"}
		groups := []advise.WindowGroup{{Provider: "zai", Timezones: []string{"Asia/Shanghai"}, Series: []advise.WindowSeries{{
			Model: "GLM-5.3", Now: advise.RatePoint{At: now, Multiplier: &one, Status: "active"}, Next: &next,
		}}}}
		for _, lang := range []render.Text{render.EN, render.ZH} {
			var out bytes.Buffer
			render.Style{T: lang}.Windows(&out, groups)
			if !strings.Contains(out.String(), tc.want) {
				t.Fatal(out.String())
			}
		}
	}
}
