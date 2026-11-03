// SPDX-License-Identifier: MIT
package rows

import (
	"regexp"
	"sort"
	"time"
)

var resetCardID = regexp.MustCompile(`^[a-f0-9]{64}$`)

func unknownResetCards() *ResetCards {
	return &ResetCards{State: "unknown", Sources: []ResetCardSource{}}
}

// sanitizeResetCards admits only bounded, reviewed source facts from the current
// consent-fenced snapshot. A malformed cached record cannot become a zero.
func sanitizeResetCards(v *ResetCards, now time.Time) *ResetCards {
	if v == nil || (v.State != "complete" && v.State != "partial") || v.Count == nil || *v.Count < 0 || *v.Count > 10000 || len(v.Items) > 64 || len(v.Sources) != 1 {
		return unknownResetCards()
	}
	if len(v.Items) > *v.Count {
		return unknownResetCards()
	}
	source := v.Sources[0]
	if (source.Source != ResetCardCodexAccount && source.Source != ResetCardCodexBar) || source.ObservedAt.IsZero() || source.ObservedAt.After(now) {
		return unknownResetCards()
	}
	count := *v.Count
	out := &ResetCards{State: v.State, Count: &count, Truncated: v.Truncated, Sources: []ResetCardSource{source}}
	if out.Truncated {
		out.State = "partial"
	}
	seen := make(map[string]bool)
	allExpiring := true
	for _, item := range v.Items {
		if !resetCardID.MatchString(item.ID) || seen[item.ID] {
			return unknownResetCards()
		}
		seen[item.ID] = true
		if item.ExpiresAt != nil {
			if !validTime(item.ExpiresAt) || !item.ExpiresAt.After(now) {
				return unknownResetCards()
			}
			t := item.ExpiresAt.UTC()
			item.ExpiresAt = &t
			if out.EarliestExpiresAt == nil || t.Before(*out.EarliestExpiresAt) {
				out.EarliestExpiresAt = &t
			}
		} else {
			allExpiring = false
		}
		out.Items = append(out.Items, item)
	}
	if out.State == "complete" && len(out.Items) != count {
		out.State = "partial"
	}
	if !allExpiring || out.State != "complete" {
		out.EarliestExpiresAt = nil
	}
	sort.Slice(out.Items, func(i, j int) bool { return out.Items[i].ID < out.Items[j].ID })
	return out
}

// mergeResetCards joins only already-admitted, verified subscription refs. An
// incomplete or differently timed source cannot assert a complete union.
func mergeResetCards(sets []*ResetCards) *ResetCards {
	if len(sets) == 1 {
		return sets[0]
	}
	out := unknownResetCards()
	items := map[string]ResetCardItem{}
	sources := map[ResetCardSourceKind]ResetCardSource{}
	known, complete := false, true
	var stamp *time.Time
	for _, set := range sets {
		if set == nil || set.State == "unknown" {
			complete = false
			continue
		}
		known = true
		if set.State != "complete" {
			complete = false
		}
		out.Truncated = out.Truncated || set.Truncated
		for _, source := range set.Sources {
			if old, ok := sources[source.Source]; ok && !old.ObservedAt.Equal(source.ObservedAt) {
				complete = false
			}
			if stamp != nil && !stamp.Equal(source.ObservedAt) {
				complete = false
			}
			t := source.ObservedAt
			stamp = &t
			sources[source.Source] = source
		}
		for _, item := range set.Items {
			if old, ok := items[item.ID]; ok && ((old.ExpiresAt == nil) != (item.ExpiresAt == nil) || old.ExpiresAt != nil && !old.ExpiresAt.Equal(*item.ExpiresAt)) {
				complete = false
				continue
			}
			items[item.ID] = item
		}
	}
	if !known {
		return out
	}
	out.State = "partial"
	ids := make([]string, 0, len(items))
	for id := range items {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	if len(ids) > 64 {
		ids = ids[:64]
		out.Truncated = true
		complete = false
	}
	for _, id := range ids {
		out.Items = append(out.Items, items[id])
	}
	keys := make([]string, 0, len(sources))
	for k := range sources {
		keys = append(keys, string(k))
	}
	sort.Strings(keys)
	if len(keys) > 16 {
		keys = keys[:16]
		out.Truncated = true
		complete = false
	}
	for _, k := range keys {
		out.Sources = append(out.Sources, sources[ResetCardSourceKind(k)])
	}
	if complete && !out.Truncated {
		count := len(out.Items)
		out.Count = &count
		out.State = "complete"
		allExpiring := true
		for _, item := range out.Items {
			if item.ExpiresAt == nil {
				allExpiring = false
				break
			}
			if out.EarliestExpiresAt == nil || item.ExpiresAt.Before(*out.EarliestExpiresAt) {
				t := *item.ExpiresAt
				out.EarliestExpiresAt = &t
			}
		}
		if !allExpiring {
			out.EarliestExpiresAt = nil
		}
	}
	return out
}

func mergeProjectionResetCards(p *Projection) {
	groups := map[string][]*ResetCards{}
	for i := range p.Rows {
		for j := range p.Rows[i].Accounts {
			a := &p.Rows[i].Accounts[j]
			if a.SubscriptionRef != nil {
				groups[*a.SubscriptionRef] = append(groups[*a.SubscriptionRef], a.ResetCards)
			}
		}
	}
	for i := range p.Rows {
		for j := range p.Rows[i].Accounts {
			a := &p.Rows[i].Accounts[j]
			if a.SubscriptionRef != nil {
				a.ResetCards = mergeResetCards(groups[*a.SubscriptionRef])
			}
		}
	}
}

func validResetCards(in Input, facts *ResetCards, ref *string) bool {
	if facts == nil {
		return true
	} // old snapshots omit the additive field
	if facts.State == ResetCardUnknown {
		return facts.Count == nil && !facts.Truncated && len(facts.Items) == 0 && facts.EarliestExpiresAt == nil && len(facts.Sources) == 0
	}
	if facts.State != ResetCardComplete && facts.State != ResetCardPartial || len(facts.Items) > 64 || len(facts.Sources) == 0 || len(facts.Sources) > 16 {
		return false
	}
	if facts.Count != nil && (*facts.Count < 0 || *facts.Count > 10000 || *facts.Count < len(facts.Items)) {
		return false
	}
	if facts.State == ResetCardComplete && (facts.Count == nil || *facts.Count != len(facts.Items) || facts.Truncated) {
		return false
	}
	if facts.State != ResetCardComplete && facts.EarliestExpiresAt != nil {
		return false
	}
	allowedIDs := map[string][]ResetCardItem{}
	allowedSources := map[ResetCardSource]bool{}
	for _, raw := range in.Accounts {
		if ref != nil && (raw.SubscriptionRef == nil || *raw.SubscriptionRef != *ref) {
			continue
		}
		v := sanitizeResetCards(raw.ResetCards, in.Now)
		for _, item := range v.Items {
			allowedIDs[item.ID] = append(allowedIDs[item.ID], item)
		}
		for _, source := range v.Sources {
			allowedSources[source] = true
		}
	}
	seen := map[string]bool{}
	allExpiring := true
	var earliest *time.Time
	for _, item := range facts.Items {
		if !resetCardID.MatchString(item.ID) || seen[item.ID] {
			return false
		}
		matched := false
		for _, original := range allowedIDs[item.ID] {
			if (original.ExpiresAt == nil && item.ExpiresAt == nil) || (original.ExpiresAt != nil && item.ExpiresAt != nil && original.ExpiresAt.Equal(*item.ExpiresAt)) {
				matched = true
				break
			}
		}
		if !matched {
			return false
		}
		seen[item.ID] = true
		if item.ExpiresAt == nil {
			allExpiring = false
		} else {
			if !validTime(item.ExpiresAt) || !item.ExpiresAt.After(in.Now) {
				return false
			}
			if earliest == nil || item.ExpiresAt.Before(*earliest) {
				t := *item.ExpiresAt
				earliest = &t
			}
		}
	}
	for _, source := range facts.Sources {
		if !allowedSources[source] {
			return false
		}
	}
	if facts.State == ResetCardComplete {
		if !allExpiring {
			earliest = nil
		}
		if (earliest == nil) != (facts.EarliestExpiresAt == nil) || earliest != nil && !earliest.Equal(*facts.EarliestExpiresAt) {
			return false
		}
	}
	return true
}
