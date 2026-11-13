// SPDX-License-Identifier: MIT
package localusage

import (
	"encoding/json"
	"strings"
)

// Numeric event-log contract: independently implemented from the existing MIT
// Cursor Token Usage emitter at 9379e191c3d1caa80315cf7814146127833a492e.
// See docs/cursor-local-history.md. Never open its prompt/chat snapshots, execute
// the exporter, or infer counts from transcript text, context gauges or costs.
func decodeCursorCounts(b []byte) ([]historyDatum, error) {
	var r struct {
		Event        string          `json:"event"`
		At           json.RawMessage `json:"ts"`
		Conversation string          `json:"conversation_id"`
		Generation   string          `json:"generation_id"`
		Model        string          `json:"model"`
		ModelID      string          `json:"model_id"`
		Present      *bool           `json:"tokens_present"`
		Input        *int64          `json:"input_tokens"`
		Output       *int64          `json:"output_tokens"`
		CacheRead    *int64          `json:"cache_read_tokens"`
		CacheWrite   *int64          `json:"cache_write_tokens"`
		Total        *int64          `json:"total_tokens"`
	}
	if json.Unmarshal(b, &r) != nil {
		return nil, errUnsupportedHistory
	}
	if r.Event != "stop" || r.Present == nil || !*r.Present {
		return nil, nil
	}
	if len(r.Conversation) == 0 || len(r.Generation) == 0 || len(r.Conversation)+len(r.Generation) > 500 || strings.ContainsAny(r.Conversation+r.Generation, "\x00\r\n") {
		return nil, errUnsupportedHistory
	}
	counts := HistoryCounts{Input: r.Input, Output: r.Output, CacheRead: r.CacheRead, CacheWrite: r.CacheWrite, Total: r.Total}
	for _, n := range []*int64{r.Input, r.Output, r.CacheRead, r.CacheWrite, r.Total} {
		if n != nil && (*n < 0 || *n > 1e15) {
			return nil, errUnsupportedHistory
		}
	}
	if !counts.known() {
		return nil, nil
	}
	at := historyStamp(r.At)
	if at.IsZero() {
		return nil, errUnsupportedHistory
	}
	model := r.ModelID
	if model == "" {
		model = r.Model
	}
	return []historyDatum{{ID: r.Conversation + "\x00" + r.Generation, At: at, Model: historyModel(model), Counts: counts}}, nil
}
