// SPDX-License-Identifier: MIT
package render_test

import (
	"bytes"
	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/render"
	"strings"
	"testing"
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
