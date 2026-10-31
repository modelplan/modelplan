// SPDX-License-Identifier: MIT
package digest

import (
	"encoding/json"
	"errors"
	"math"
	"time"
	_ "time/tzdata" // Standalone clients also need published IANA zones.
)

// CalendarIntervals decodes server-expanded intervals and their published rule
// scopes. It never expands recurrence, synthesizes a coefficient or extends a
// multiplier horizon. The caller verifies both components against one manifest.
func CalendarIntervals(rules, calendar []byte) ([]MultiplierWindow, time.Time, time.Time, error) {
	var r struct {
		Rules []struct {
			ID string `json:"id"`
			MultiplierWindow
		} `json:"rules"`
	}
	var c struct {
		From      time.Time `json:"from"`
		To        time.Time `json:"to"`
		Providers map[string]map[string]struct {
			Provider string    `json:"provider"`
			Timezone string    `json:"timezone"`
			From     time.Time `json:"from"`
			To       time.Time `json:"to"`
			Events   []struct {
				Start       time.Time `json:"start"`
				End         time.Time `json:"end"`
				Multiplier  *float64  `json:"multiplier"`
				Status      string    `json:"status"`
				Eligibility string    `json:"eligibility"`
				RuleIDs     []string  `json:"ruleIds"`
			} `json:"events"`
		} `json:"providers"`
	}
	if json.Unmarshal(rules, &r) != nil || json.Unmarshal(calendar, &c) != nil || c.From.IsZero() || !c.To.After(c.From) || c.Providers == nil {
		return nil, time.Time{}, time.Time{}, errors.New("calendar: invalid interval data")
	}
	byID := map[string]MultiplierWindow{}
	for _, rule := range r.Rules {
		if rule.ID == "" || rule.Provider == "" || rule.Models == nil || rule.Clients == nil || rule.Generations == nil {
			continue
		}
		if _, duplicate := byID[rule.ID]; duplicate {
			return nil, time.Time{}, time.Time{}, errors.New("calendar: duplicate rule")
		}
		rule.RuleID = rule.ID
		byID[rule.ID] = rule.MultiplierWindow
	}
	out := []MultiplierWindow{}
	for provider, languages := range c.Providers {
		view, ok := languages["en"]
		if !ok {
			view, ok = languages["zh"]
		}
		if !ok || view.Provider != provider || view.From.Before(c.From) || view.To.After(c.To) || !view.To.After(view.From) {
			continue
		}
		if _, err := time.LoadLocation(view.Timezone); err != nil {
			continue
		}
		for _, event := range view.Events {
			if event.Start.IsZero() || !event.End.After(event.Start) ||
				(event.Status != "CONFIRMED" && event.Status != "TENTATIVE") ||
				(event.Eligibility != "eligible" && event.Eligibility != "conditional" && event.Eligibility != "unknown") || len(event.RuleIDs) != 1 {
				continue
			}
			rule, ok := byID[event.RuleIDs[0]]
			// Multi-rule events do not identify one model/scope coefficient.
			if !ok || rule.Provider != provider || event.Multiplier != nil && (*event.Multiplier < 0 || math.IsNaN(*event.Multiplier) || math.IsInf(*event.Multiplier, 0)) {
				continue
			}
			start, end := event.Start, event.End
			if start.Before(view.From) {
				start = view.From
			}
			if end.After(view.To) {
				end = view.To
			}
			if !end.After(start) {
				continue
			}
			rule.StartsAt, rule.EndsAt = start.UTC().Format(time.RFC3339), end.UTC().Format(time.RFC3339)
			rule.Multiplier, rule.Status, rule.Timezone = event.Multiplier, event.Status, view.Timezone
			if event.Eligibility != "eligible" {
				rule.Conditions = append(append([]string(nil), rule.Conditions...), "calendarEligibility:"+event.Eligibility)
				if event.Eligibility == "unknown" {
					rule.Multiplier = nil
				}
			}
			out = append(out, rule)
		}
	}
	return out, c.From, c.To, nil
}
