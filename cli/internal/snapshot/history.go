package snapshot

// The v1.1 history projection: the performance ledger's recent 7- and 30-day windows per
// subscription and its model/tool rankings. It joins the personal snapshot only when the caller
// asked for it, and crosses the app-server only behind the negotiated cockpitHistoryV1
// capability.

import (
	"math"
	"regexp"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// BindingSourceWideCurrent names the only binding basis the local ledgers support: the totals
// describe a source's traffic while one verified account is bound to it now; they are not proof
// of historic subscription ownership.
const BindingSourceWideCurrent = "source-wide-current-binding"

var subscriptionRef = regexp.MustCompile(`^[a-f0-9]{16}$`)

// SourceBindings names, for every source with exactly one fresh verified binding, the
// subscription its locally observed traffic may be shown under. A source missing from the map is
// ambiguous or unverified: its figures then stay source-wide and are never copied to a
// subscription. The caller must pass every account of the source, not a filtered subset.
func SourceBindings(accounts []quota.Account, now time.Time) map[string]string {
	type candidate struct {
		ref       string
		ambiguous bool
	}
	bySource := map[string]candidate{}
	for _, account := range accounts {
		if account.Source == "" {
			continue
		}
		c := bySource[account.Source]
		b := account.Subscription
		if account.Stale || b == nil || b.Status != "verified" || !subscriptionRef.MatchString(b.Ref) || b.ObservedAt.IsZero() || b.ObservedAt.After(now) || now.Sub(b.ObservedAt) > time.Hour {
			c.ambiguous = true
		} else if c.ref != "" && c.ref != b.Ref {
			c.ambiguous = true
		} else {
			c.ref = b.Ref
		}
		bySource[account.Source] = c
	}
	out := map[string]string{}
	for source, c := range bySource {
		if !c.ambiguous && c.ref != "" {
			out[source] = c.ref
		}
	}
	return out
}

// PerfHistory sums what the CLI observed over the recent 7 and 30 local days. Coverage:
// local-history (readable, recording on), recording-off or unavailable. RecordingSince says
// when the ledger started, so a 30-day window that opens before it is known to be partial.
type PerfHistory struct {
	Coverage       string                    `json:"coverage"`
	RecordingSince *time.Time                `json:"recordingSince"`
	Subscriptions  []PerfSubscriptionHistory `json:"subscriptions"`
	Models         speed.EntityRanking       `json:"models"`
	Tools          speed.EntityRanking       `json:"tools"`
}

// PerfSubscriptionHistory is one subscription's source-wide windows under the current binding.
type PerfSubscriptionHistory struct {
	SubscriptionRef string              `json:"subscriptionRef"`
	Sources         []PerfSourceHistory `json:"sources"`
}

// PerfSourceHistory is one source's contribution to a subscription.
type PerfSourceHistory struct {
	Source       string         `json:"source"`
	BindingBasis string         `json:"bindingBasis"`
	Recent7d     PerfWindowSums `json:"recent7d"`
	Recent30d    PerfWindowSums `json:"recent30d"`
}

// PerfWindowSums: observed token sums of one window. The nullable token kinds and derived
// figures stay null when unknown, never zero.
type PerfWindowSums struct {
	InputTokens      *int64   `json:"inputTokens"`
	OutputTokens     int64    `json:"outputTokens"`
	CacheReadTokens  *int64   `json:"cacheReadTokens"`
	CacheWriteTokens *int64   `json:"cacheWriteTokens"`
	CacheHitRatio    *float64 `json:"cacheHitRatio"`
	GenerationTps    *float64 `json:"generationTps"`
	ObservedRequests int      `json:"observedRequests"`
	EligibleRequests int      `json:"eligibleRequests"`
}

// BuildPerfHistory projects an already admitted performance ledger. allowed names the sources
// whose local history may be read; a source without it contributes nowhere, in the windows or
// the rankings. perf nil leaves an unavailable section with empty, non-nil lists.
func BuildPerfHistory(perf *speed.PerfView, accounts []quota.Account, allowed map[string]bool, now time.Time) *PerfHistory {
	h := &PerfHistory{Coverage: "unavailable", Subscriptions: []PerfSubscriptionHistory{},
		Models: speed.EntityRanking{Measure: "observed-output-tokens", Attribution: "unattributed", Recent7d: speed.EntityWindow{Top: []speed.RankedEntity{}}, Recent30d: speed.EntityWindow{Top: []speed.RankedEntity{}}},
		Tools: speed.EntityRanking{Measure: "observed-output-tokens", Attribution: "unattributed", Recent7d: speed.EntityWindow{Top: []speed.RankedEntity{}}, Recent30d: speed.EntityWindow{Top: []speed.RankedEntity{}}}}
	if perf == nil || !perf.OK || len(allowed) == 0 {
		return h
	}
	if !perf.Recording {
		h.Coverage = "recording-off"
		return h
	}
	since := perf.Ledger.Since.UTC()
	h.RecordingSince = &since
	h.Coverage = "local-history"
	rankings := perf.HistoryRankings(allowed)
	h.Models, h.Tools = rankings.Models, rankings.Tools
	bindings := SourceBindings(accounts, now)
	byRef := map[string]*PerfSubscriptionHistory{}
	var refs []string
	for _, w := range perf.HistoryWindows() {
		if !allowed[w.Source] {
			continue
		}
		// A source with no counted row in either window is left out, not zero-filled.
		if w.Recent30d.ObservedRequests == 0 && w.Recent30d.MixedConfigTurnsExcluded == 0 {
			continue
		}
		ref, ok := bindings[w.Source]
		if !ok {
			continue
		}
		s := byRef[ref]
		if s == nil {
			s = &PerfSubscriptionHistory{SubscriptionRef: ref}
			byRef[ref] = s
			refs = append(refs, ref)
		}
		s.Sources = append(s.Sources, PerfSourceHistory{Source: w.Source, BindingBasis: BindingSourceWideCurrent, Recent7d: windowSums(w.Recent7d), Recent30d: windowSums(w.Recent30d)})
	}
	sort.Strings(refs)
	if len(refs) > 128 {
		refs = refs[:128]
	}
	for _, ref := range refs {
		s := byRef[ref]
		sort.Slice(s.Sources, func(i, j int) bool { return s.Sources[i].Source < s.Sources[j].Source })
		h.Subscriptions = append(h.Subscriptions, *s)
	}
	return h
}

func windowSums(s speed.PerfSums) PerfWindowSums {
	out := PerfWindowSums{InputTokens: s.InputTokens, CacheReadTokens: s.CacheReadTokens, CacheWriteTokens: s.CacheWriteTokens,
		OutputTokens: s.ObservedOutputTokens, ObservedRequests: s.ObservedRequests, EligibleRequests: s.EligibleRequests}
	out.CacheHitRatio = cacheHitRatio(s.CacheReadTokens, s.InputTokens)
	if s.EligibleRequests >= speed.MinSamples && s.GenMs > 0 && s.EligibleOutputTokens >= 0 {
		v := math.Round(float64(s.EligibleOutputTokens)/(float64(s.GenMs)/1000)*10) / 10
		out.GenerationTps = &v
	}
	return out
}

// cacheHitRatio: the share of read tokens among read and uncached input, the definition the
// parsers normalize to; nil unless both sums are known and the denominator is positive.
func cacheHitRatio(read, input *int64) *float64 {
	if read == nil || input == nil || *read < 0 || *input < 0 || *read+*input <= 0 {
		return nil
	}
	v := math.Round(float64(*read)/float64(*read+*input)*10000) / 10000
	return &v
}
