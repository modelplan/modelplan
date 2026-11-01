// SPDX-License-Identifier: MIT
package digest_test

import (
	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"strings"
	"testing"
)

func TestCalendarIntervalsPreserveUnknownAndRejectUnsupported(t *testing.T) {
	for _, tc := range []struct {
		name, from, to string
		want           int
		unknown        bool
	}{
		{"unknown coefficient", `"multiplier":3`, `"multiplier":null`, 1, true},
		{"unknown eligibility", `"eligibility":"eligible"`, `"eligibility":"unknown"`, 1, true},
		{"cancelled", `"status":"CONFIRMED"`, `"status":"CANCELLED"`, 0, false},
		{"ineligible", `"eligibility":"eligible"`, `"eligibility":"ineligible"`, 0, false},
		{"ambiguous rules", `"ruleIds":["weekday-peak"]`, `"ruleIds":["weekday-peak","other"]`, 0, false},
		{"invalid zone", `"timezone":"Asia/Shanghai"`, `"timezone":"Invalid/Zone"`, 0, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			raw := strings.ReplaceAll(contracttest.WeekdayIntervals, tc.from, tc.to)
			intervals, _, _, err := digest.CalendarIntervals([]byte(contracttest.WeekdayRules), []byte(raw))
			if err != nil || len(intervals) != tc.want {
				t.Fatal(intervals, err)
			}
			if tc.unknown && intervals[0].Multiplier != nil {
				t.Fatal("unknown coefficient became known")
			}
		})
	}
}

func TestCalendarMissingModelScopeIsNotAllModels(t *testing.T) {
	rules := strings.ReplaceAll(contracttest.WeekdayRules, `"models":["GLM-5.3"],`, "")
	intervals, _, _, err := digest.CalendarIntervals([]byte(rules), []byte(contracttest.WeekdayIntervals))
	if err != nil || len(intervals) != 0 {
		t.Fatal("missing model scope was treated as all models", intervals, err)
	}
}

func TestCalendarConditionalEligibilityDoesNotInventAQuotaCondition(t *testing.T) {
	raw := strings.ReplaceAll(contracttest.WeekdayIntervals, `"eligibility":"eligible"`, `"eligibility":"conditional"`)
	intervals, _, _, err := digest.CalendarIntervals([]byte(contracttest.WeekdayRules), []byte(raw))
	if err != nil || len(intervals) != 1 || intervals[0].RequiresQuotaAvailable || len(intervals[0].Conditions) != 1 || intervals[0].Conditions[0] != "calendarEligibility:conditional" {
		t.Fatal(intervals, err)
	}
}
