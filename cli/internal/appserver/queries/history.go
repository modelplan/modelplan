// SPDX-License-Identifier: MIT
package queries

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"regexp"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// HistoryAdmission is captured by the shared backend under the consent fence.
// Scopes and AccountLocator describe exactly the data ReadHistory may touch.
// A backend must reject denied, revoked, unsupported or mismatched identities;
// the query handler never creates a grant or infers it from installed tools.
type HistoryAdmission struct {
	Stamp          appserver.Stamp
	Scopes         []string
	AccountLocator string
}

type HistoryBatch struct {
	Items []wire.HistoryItem
	Next  string // backend position, never a client cursor or a credential
}

// HistorySource reads existing local engine data only. Returned admissions and
// items are immutable. ReadHistory must obey the admitted scopes and row limit;
// it never refreshes a provider or writes another tool's state.
type HistorySource interface {
	AdmitHistory(context.Context, appserver.Stamp, wire.HistoryQueryParams) (HistoryAdmission, error)
	ReadHistory(context.Context, HistoryAdmission, wire.HistoryQueryParams, string) (HistoryBatch, error)
}

type HistoryConfig struct {
	State   appserver.Backend
	Source  HistorySource
	Session func(context.Context) string // initialized pipe session, supplied by U3
}

var toolID = regexp.MustCompile(`^[a-z][a-z0-9_-]{0,63}$`)
var accountLocator = regexp.MustCompile(`^[a-f0-9]{16}$`)

func protocol(code int) error { return appserver.ProtocolError{Code: code} }

func historyParams(raw json.RawMessage) (wire.HistoryQueryParams, error) {
	var p wire.HistoryQueryParams
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] != '{' {
		return p, protocol(wire.CodeInvalidParams)
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&p) != nil || decoder.Decode(new(any)) != io.EOF ||
		!toolID.MatchString(p.Tool) || p.Limit < 1 || p.Limit > 500 ||
		(p.Ref != "" && !accountLocator.MatchString(p.Ref)) {
		return p, protocol(wire.CodeInvalidParams)
	}
	// Optional string fields distinguish omission from JSON null. Decode their
	// raw presence as well as the typed DTO, whose zero value otherwise hides null.
	var selectors struct {
		Ref    json.RawMessage `json:"ref"`
		Cursor json.RawMessage `json:"cursor"`
	}
	if json.Unmarshal(raw, &selectors) != nil || bytes.Equal(bytes.TrimSpace(selectors.Ref), []byte("null")) || bytes.Equal(bytes.TrimSpace(selectors.Cursor), []byte("null")) {
		return p, protocol(wire.CodeInvalidParams)
	}
	switch p.Kind {
	case wire.HistoryTokens, wire.HistoryQuotaCycles, wire.HistorySessions:
	default:
		return p, protocol(wire.CodeInvalidParams)
	}
	if len(p.Cursor) > 8192 {
		return p, cursorStale()
	}
	return p, nil
}

// HistoryHandler is an interface-stage adapter for the real U3 Handler seam.
// Registration and production sources belong to the shared engine constructor.
// A missing dependency is refused, so an unwired capability is not advertised.
func HistoryHandler(config HistoryConfig) (appserver.Handler, error) {
	if config.State == nil || config.Source == nil || config.Session == nil {
		return appserver.Handler{}, protocol(wire.CodeInternal)
	}
	codec, err := newCursorCodec()
	if err != nil {
		return appserver.Handler{}, err
	}
	return appserver.Handler{Capability: "history", Query: true, Private: true, Handle: func(ctx context.Context, raw json.RawMessage, stamp appserver.Stamp) (appserver.Reply, error) {
		p, err := historyParams(raw)
		if err != nil {
			return appserver.Reply{}, err
		}
		if err := ctx.Err(); err != nil {
			return appserver.Reply{}, err
		}
		session := config.Session(ctx)
		if session == "" {
			return appserver.Reply{}, protocol(wire.CodeInternal)
		}
		view, err := config.State.Get(ctx)
		if err != nil {
			return appserver.Reply{}, err
		}
		if view.Stamp != stamp {
			return appserver.Reply{}, protocol(wire.CodeConsentChanged)
		}
		admission, err := config.Source.AdmitHistory(ctx, stamp, p)
		if err != nil {
			return appserver.Reply{}, err
		}
		if admission.Stamp != stamp {
			return appserver.Reply{}, protocol(wire.CodeConsentChanged)
		}
		if admission.AccountLocator != "" && !accountLocator.MatchString(admission.AccountLocator) || p.Ref != "" && p.Ref != admission.AccountLocator {
			return appserver.Reply{}, protocol(wire.CodeConsentRejected)
		}
		admission.Scopes = append([]string(nil), admission.Scopes...)
		binding := cursorBinding{Session: session, Stamp: stamp, Scopes: admission.Scopes, Account: admission.AccountLocator, Tool: p.Tool, Kind: p.Kind}
		if _, err := binding.additionalData(); err != nil {
			return appserver.Reply{}, protocol(wire.CodeConsentRejected)
		}
		position := ""
		if p.Cursor != "" {
			position, err = codec.decode(binding, p.Cursor)
			if err != nil {
				return appserver.Reply{}, err
			}
		}
		p.Cursor = "" // storage sees only its authenticated position argument
		if err := ctx.Err(); err != nil {
			return appserver.Reply{}, err
		}
		batch, err := config.Source.ReadHistory(ctx, admission, p, position)
		if err != nil {
			return appserver.Reply{}, err
		}
		if err := ctx.Err(); err != nil {
			return appserver.Reply{}, err
		}
		view, err = config.State.Get(ctx)
		if err != nil {
			return appserver.Reply{}, err
		}
		if view.Stamp != stamp {
			return appserver.Reply{}, protocol(wire.CodeConsentChanged)
		}
		if len(batch.Items) > p.Limit {
			return appserver.Reply{}, protocol(wire.CodeHistoryUnavailable)
		}
		page := wire.HistoryPage{Items: append([]wire.HistoryItem{}, batch.Items...)}
		if batch.Next != "" {
			page.NextCursor, err = codec.encode(binding, batch.Next)
			if err != nil {
				return appserver.Reply{}, err
			}
		}
		return appserver.Reply{Stamp: stamp, Scopes: append([]string(nil), admission.Scopes...), Data: page}, nil
	}}, nil
}
