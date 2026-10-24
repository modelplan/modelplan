// Package qwenusage reads only user-selected Qwen Code aggregated JSON exports.
// It never runs Qwen, opens its credentials or sessions, or calls a network host.
package qwenusage

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"time"
)

const ExportEnv = "MODELPLAN_QWEN_USAGE_EXPORT"
const maxFile = 1 << 20
const maxExports = 64

// Totals preserve Qwen's token definitions: inputTokens may include cachedTokens;
// thoughtsTokens may overlap outputTokens. Do not add those buckets together.
type Totals struct {
	Requests       *int64 `json:"requests"`
	InputTokens    *int64 `json:"inputTokens"`
	OutputTokens   *int64 `json:"outputTokens"`
	CachedTokens   *int64 `json:"cachedTokens"`
	ThoughtsTokens *int64 `json:"thoughtsTokens"`
	TotalTokens    *int64 `json:"totalTokens"`
}

type Model struct {
	Totals
	Model string `json:"model"`
}

// Period is one calendar day or month, not a subscription billing window.
// Different periods can overlap; they must not be summed together.
type Period struct {
	Period      string    `json:"period"`
	Value       string    `json:"value"`
	GeneratedAt time.Time `json:"generatedAt"`
	Stale       bool      `json:"stale"`
	Totals      Totals    `json:"totals"`
	Models      []Model   `json:"models"`
}

type Report struct {
	Source  string   `json:"source"`
	Status  string   `json:"status"`
	Reason  string   `json:"reason,omitempty"`
	Periods []Period `json:"periods"`
}

func Configured() string { return os.Getenv(ExportEnv) }

// Read is off before any filesystem access when path is empty. Directory reads
// are bounded to Qwen's own export filename pattern; monthly/day buckets remain
// separate. Re-exporting the same bucket replaces it, never adds it twice.
func Read(path string, now time.Time) Report {
	r := Report{Source: "qwen-code-export", Status: "off", Periods: []Period{}}
	if path == "" {
		return r
	}
	fi, err := os.Lstat(path)
	if err != nil {
		r.Status = "missing"
		if !os.IsNotExist(err) {
			r.Status = "unreadable"
		}
		return r
	}
	paths := []string{path}
	if fi.IsDir() {
		paths = nil
		dir, err := os.Open(path)
		if err != nil {
			r.Status = "unreadable"
			return r
		}
		defer dir.Close()
		// Bound directory enumeration too; do not walk Qwen's runtime folders.
		entries, err := dir.ReadDir(4097)
		if err != nil && err != io.EOF {
			r.Status = "unreadable"
			return r
		}
		if len(entries) > 4096 {
			r.Status = "too-large"
			return r
		}
		for _, e := range entries {
			if ok, _ := filepath.Match("qwen-token-usage-*.json", e.Name()); ok {
				paths = append(paths, filepath.Join(path, e.Name()))
			}
		}
		sort.Strings(paths)
	}
	if len(paths) > maxExports {
		r.Status = "too-large"
		return r
	}
	by := map[string]Period{}
	failed := false
	for _, p := range paths {
		data, status := readFile(p)
		if status != "" {
			r.Reason = status
			failed = true
			continue
		}
		v, ok := parse(data, now)
		if !ok {
			r.Reason = "unsupported-export"
			failed = true
			continue
		}
		key := v.Period + ":" + v.Value
		if prev, ok := by[key]; !ok || v.GeneratedAt.After(prev.GeneratedAt) {
			by[key] = v
		}
	}
	keys := make([]string, 0, len(by))
	for k := range by {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		r.Periods = append(r.Periods, by[k])
	}
	r.Status = "ok"
	if len(r.Periods) == 0 {
		r.Status = "empty"
	}
	if failed {
		r.Status = "partial"
		if len(r.Periods) == 0 {
			r.Status = "invalid"
		}
	}
	return r
}

func readFile(path string) ([]byte, string) {
	fi, err := os.Lstat(path)
	if err != nil {
		return nil, "unreadable-export"
	}
	if !fi.Mode().IsRegular() {
		return nil, "unsafe-export"
	}
	if fi.Size() > maxFile {
		return nil, "oversized-export"
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, "unreadable-export"
	}
	defer f.Close()
	b, err := io.ReadAll(io.LimitReader(f, maxFile+1))
	if err != nil || len(b) > maxFile {
		return nil, "oversized-export"
	}
	return b, ""
}

var modelID = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._:/@-]{0,159}$`)

func parse(b []byte, now time.Time) (Period, bool) {
	// Only the exported TokenUsageSummary contract. Raw usage_record.jsonl,
	// sessions, OAuth and cloud billing responses are deliberately unsupported.
	var raw struct {
		Period      string    `json:"period"`
		Value       string    `json:"value"`
		GeneratedAt time.Time `json:"generatedAt"`
		Totals      *Totals   `json:"totals"`
		ByModel     []struct {
			Totals
			Key   string `json:"key"`
			Model string `json:"model"`
		} `json:"byModel"`
	}
	if json.Unmarshal(b, &raw) != nil || raw.Totals == nil || raw.ByModel == nil || len(raw.ByModel) > 256 || raw.GeneratedAt.IsZero() || raw.GeneratedAt.After(now) {
		return Period{}, false
	}
	layout := "2006-01-02"
	if raw.Period == "month" {
		layout = "2006-01"
	} else if raw.Period != "day" {
		return Period{}, false
	}
	t, err := time.Parse(layout, raw.Value)
	if err != nil || t.Format(layout) != raw.Value || raw.Value > now.Local().Format(layout) {
		return Period{}, false
	}
	v := Period{Period: raw.Period, Value: raw.Value, GeneratedAt: raw.GeneratedAt.UTC(), Stale: now.Sub(raw.GeneratedAt) > 24*time.Hour, Totals: clean(*raw.Totals), Models: []Model{}}
	seen := map[string]bool{}
	for _, m := range raw.ByModel {
		id := m.Model
		if id == "" {
			id = m.Key
		}
		if !modelID.MatchString(id) || seen[id] {
			return Period{}, false
		}
		seen[id] = true
		v.Models = append(v.Models, Model{Totals: clean(m.Totals), Model: id})
	}
	sort.Slice(v.Models, func(i, j int) bool { return v.Models[i].Model < v.Models[j].Model })
	return v, true
}

func clean(t Totals) Totals {
	for _, p := range []**int64{&t.Requests, &t.InputTokens, &t.OutputTokens, &t.CachedTokens, &t.ThoughtsTokens, &t.TotalTokens} {
		if *p != nil && (**p < 0 || **p > 1e15) {
			*p = nil
		}
	}
	return t
}
