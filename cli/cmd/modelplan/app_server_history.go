// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"os"
	"strconv"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/localusage"
)

// sharedHistory adapts only the engine's sanitized count cache. A query never
// scans a tool directory, refreshes a provider or creates an identity key.
// Other history kinds are unavailable until a typed production source exists.
type sharedHistory struct {
	backend appserver.Backend
	cache   string
}

func (s sharedHistory) AdmitHistory(ctx context.Context, stamp appserver.Stamp, p wire.HistoryQueryParams) (queries.HistoryAdmission, error) {
	view, err := s.backend.Get(ctx)
	if err != nil {
		return queries.HistoryAdmission{}, err
	}
	if view.Stamp != stamp {
		return queries.HistoryAdmission{}, appserver.ProtocolError{Code: wire.CodeConsentChanged}
	}
	scope := p.Tool + ".local_history"
	allowed := false
	for _, id := range view.Scopes {
		if id == scope {
			allowed = true
		}
	}
	if !allowed || p.Ref != "" {
		return queries.HistoryAdmission{}, appserver.ProtocolError{Code: wire.CodeConsentRejected}
	}
	supported := false
	for _, tool := range localusage.HistoryProviders() {
		if tool == p.Tool {
			supported = true
		}
	}
	if !supported || p.Kind != wire.HistoryTokens {
		return queries.HistoryAdmission{}, appserver.ProtocolError{Code: wire.CodeHistoryUnavailable}
	}
	return queries.HistoryAdmission{Stamp: stamp, Scopes: []string{scope}}, nil
}
func (s sharedHistory) ReadHistory(ctx context.Context, a queries.HistoryAdmission, p wire.HistoryQueryParams, position string) (queries.HistoryBatch, error) {
	if err := ctx.Err(); err != nil {
		return queries.HistoryBatch{}, err
	}
	admission := consent.Capture()
	f := admission.Fence()
	if f.StoreEpoch != a.Stamp.Epoch || f.Generation != a.Stamp.Generation {
		return queries.HistoryBatch{}, appserver.ProtocolError{Code: wire.CodeConsentChanged}
	}
	if len(a.Scopes) != 1 || a.Scopes[0] != p.Tool+".local_history" || !admission.State().AllowsScope(a.Scopes[0], admission.Mode()) {
		return queries.HistoryBatch{}, appserver.ProtocolError{Code: wire.CodeConsentRejected}
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return queries.HistoryBatch{}, appserver.ProtocolError{Code: wire.CodeHistoryUnavailable}
	}
	_, access := localusage.ProductionHistoryAccessWithAdmission(home, p.Tool, false, admission)
	result := localusage.ReadHistoryCache(s.cache, p.Tool, access, time.Now())
	if result.Availability != "ok" && result.Availability != "empty" {
		return queries.HistoryBatch{}, appserver.ProtocolError{Code: wire.CodeHistoryUnavailable}
	}
	start := 0
	if position != "" {
		start, err = strconv.Atoi(position)
		if err != nil || start < 0 {
			return queries.HistoryBatch{}, appserver.ProtocolError{Code: wire.CodeCursorStale}
		}
	}
	rows := append(append([]localusage.HistoryRow{}, result.Rows...), result.Unallocated...)
	if start > len(rows) {
		return queries.HistoryBatch{}, appserver.ProtocolError{Code: wire.CodeCursorStale}
	}
	end := start + p.Limit
	if end > len(rows) {
		end = len(rows)
	}
	batch := queries.HistoryBatch{Items: []wire.HistoryItem{}}
	for _, row := range rows[start:end] {
		at, err := time.Parse("2006-01-02", row.Day)
		if err != nil {
			at = result.ObservedAt
		}
		if at.IsZero() {
			continue
		}
		item := wire.HistoryItem{At: at, Tokens: row.Total}
		if row.Model != "" {
			model := row.Model
			item.Model = &model
		}
		batch.Items = append(batch.Items, item)
	}
	if end < len(rows) {
		batch.Next = strconv.Itoa(end)
	}
	if err := ctx.Err(); err != nil {
		return queries.HistoryBatch{}, err
	}
	return batch, nil
}
