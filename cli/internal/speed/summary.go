package speed

import (
	"math"
	"sort"
	"time"
)

// Stat is one configuration over the kept days. A rate or median needs MinSamples requests or
// turns; with fewer it is nil and only the counts show.
type Stat struct {
	Source string `json:"source"`
	Model  string `json:"model"`
	Effort string `json:"effort,omitempty"`
	Speed  string `json:"speed,omitempty"`
	Days   int    `json:"days"`
	// Requests and Turns are the valid samples behind the figures.
	Requests int `json:"requests"`
	Turns    int `json:"turns"`
	// OutputTokensPerSecond: all valid requests' output tokens over their generation time.
	OutputTokensPerSecond *float64 `json:"outputTokensPerSecond"`
	TTFTSeconds           *float64 `json:"ttftSeconds"`      // median time to the first token
	TurnSeconds           *float64 `json:"turnSeconds"`      // median turn, tools included
	TurnOutputTokens      *float64 `json:"turnOutputTokens"` // median output tokens per turn
}

// Summarize merges the ledger's days per configuration, ordered by source, model, speed and effort.
func Summarize(l Ledger, now time.Time) []Stat {
	from := day(now.Add(-Keep))
	type acc struct {
		Stat
		out, gen      int64
		ttft, ms, tok Hist
		days          map[string]bool
	}
	by := map[[4]string]*acc{}
	var keys [][4]string
	for _, r := range l.Rows {
		if r.Day < from {
			continue
		}
		k := [4]string{r.Source, r.Model, r.Speed, r.Effort}
		a := by[k]
		if a == nil {
			a = &acc{Stat: Stat{Source: r.Source, Model: r.Model, Effort: r.Effort, Speed: r.Speed}, days: map[string]bool{}}
			by[k] = a
			keys = append(keys, k)
		}
		a.days[r.Day] = true
		a.Requests += r.Requests
		a.Turns += r.Turns
		a.out += r.OutputTokens
		a.gen += r.GenMs
		a.ttft, a.ms, a.tok = a.ttft.merge(r.TTFTMs), a.ms.merge(r.TurnMs), a.tok.merge(r.TurnTokens)
	}
	sort.Slice(keys, func(i, j int) bool {
		for x := range keys[i] {
			if keys[i][x] != keys[j][x] {
				return keys[i][x] < keys[j][x]
			}
		}
		return false
	})
	out := []Stat{}
	for _, k := range keys {
		a := by[k]
		s := a.Stat
		s.Days = len(a.days)
		if a.Requests >= MinSamples && a.gen > 0 {
			s.OutputTokensPerSecond = round(float64(a.out) / (float64(a.gen) / 1000))
		}
		if a.ttft.Count() >= MinSamples {
			s.TTFTSeconds = round(a.ttft.Median() / 1000)
		}
		if a.Turns >= MinSamples {
			s.TurnSeconds = round(a.ms.Median() / 1000)
			s.TurnOutputTokens = round(a.tok.Median())
		}
		out = append(out, s)
	}
	return out
}

func round(v float64) *float64 {
	p := 1.0
	if v < 10 {
		p = 10
	}
	x := math.Round(v*p) / p
	return &x
}
