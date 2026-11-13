// SPDX-License-Identifier: MIT
package contracttest

import (
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"time"
)

// Authored public-calendar fixtures; no provider, account or producer data.
const WeekdayRules = `{"rules":[{"id":"weekday-peak","provider":"zai","kind":"peak","models":["GLM-5.3"],"planIds":["synthetic-pro"],"clients":[],"generations":[],"region":"global","timezone":"Asia/Shanghai","weekdays":[1,2,3,4,5],"startHour":14,"endHour":18,"priority":10}]}`

const WeekdayIntervals = `{"from":"2026-10-31T00:00:00+08:00","to":"2026-11-04T00:00:00+08:00","providers":{"zai":{"en":{"provider":"zai","timezone":"Asia/Shanghai","from":"2026-10-31T00:00:00+08:00","to":"2026-11-04T00:00:00+08:00","events":[{"start":"2026-11-02T14:00:00+08:00","end":"2026-11-02T18:00:00+08:00","multiplier":3,"status":"CONFIRMED","eligibility":"eligible","ruleIds":["weekday-peak"]}]}}}}`

func WeekdayCalendar() (*digest.Digest, time.Time) {
	now := time.Date(2026, 10, 31, 2, 0, 0, 0, time.UTC) // Saturday 10:00 CST
	one := 1.0
	d := &digest.Digest{PublicationID: "synthetic-calendar", ProjectionVersion: "client-v1.3",
		Units:             digest.Units{Ability: "websiteAbility", Cost: "usdPerReferenceTask", Time: "taskTimeCrossModel"},
		Models:            []digest.Model{{ID: "glm-synthetic", Name: "GLM-5.3", DeveloperID: "synthetic-dev", HarnessIDs: map[string][]string{"api": {"glm-synthetic"}}, Efforts: []digest.Effort{}}},
		Lineups:           []digest.PublishedLineup{},
		Resets:            []json.RawMessage{},
		Windows:           []json.RawMessage{},
		MultiplierHorizon: &digest.MultiplierHorizon{From: "2026-10-30T16:00:00Z", To: "2026-11-01T16:00:00Z", Selection: "highest-priority-no-stacking"},
		Multipliers:       []digest.MultiplierWindow{{RuleID: "base", Provider: "zai", Kind: "base", Models: []string{"GLM-5.3"}, PlanIDs: []string{"synthetic-pro"}, Region: "global", Timezone: "Asia/Shanghai", Multiplier: &one, StartsAt: "2026-10-30T16:00:00Z", EndsAt: "2026-11-01T16:00:00Z", Status: "CONFIRMED"}},
	}
	intervals, from, to, err := digest.CalendarIntervals([]byte(WeekdayRules), []byte(WeekdayIntervals))
	if err != nil {
		panic(err)
	}
	d.CalendarIntervals, d.CalendarFrom, d.CalendarTo = intervals, from, to
	return d, now
}
