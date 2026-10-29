// SPDX-License-Identifier: MIT
package queries

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// PublicationSource returns the same public-only projection as the existing
// publication --json command. It contains no personal history or account data.
type PublicationSource interface {
	Publication(context.Context) (digest.Publication, error)
}

// VerifiedPublication reads the already-verified cache through the existing
// publication loader. It never opens a store, syncs, writes or makes a request.
type VerifiedPublication struct{ Store *store.Store }

func (p VerifiedPublication) Publication(ctx context.Context) (digest.Publication, error) {
	if err := ctx.Err(); err != nil {
		return digest.Publication{}, err
	}
	if p.Store == nil {
		return digest.Publication{}, protocol(wire.CodeInternal)
	}
	d, _, err := publication.Load(p.Store)
	if err != nil {
		return digest.Publication{}, protocol(wire.CodeInternal)
	}
	if err := ctx.Err(); err != nil {
		return digest.Publication{}, err
	}
	return d.Publication(), nil
}

func emptyParams(raw json.RawMessage) bool {
	if len(bytes.TrimSpace(raw)) == 0 {
		return true
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	var p *wire.Empty
	return decoder.Decode(&p) == nil && p != nil && decoder.Decode(new(any)) == io.EOF
}

// PublicationHandler returns existing published verdicts verbatim. Publication
// is public, so it does not consume a private-query slot or attach private scopes.
// The real core still applies its shared stamp at enqueue and write time.
func PublicationHandler(source PublicationSource) (appserver.Handler, error) {
	if source == nil {
		return appserver.Handler{}, protocol(wire.CodeInternal)
	}
	return appserver.Handler{Capability: "publication", Handle: func(ctx context.Context, raw json.RawMessage, stamp appserver.Stamp) (appserver.Reply, error) {
		if !emptyParams(raw) {
			return appserver.Reply{}, protocol(wire.CodeInvalidParams)
		}
		if err := ctx.Err(); err != nil {
			return appserver.Reply{}, err
		}
		data, err := source.Publication(ctx)
		if err != nil {
			if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
				return appserver.Reply{}, err
			}
			return appserver.Reply{}, protocol(wire.CodeInternal)
		}
		if err := ctx.Err(); err != nil {
			return appserver.Reply{}, err
		}
		return appserver.Reply{Stamp: stamp, Data: data}, nil
	}}, nil
}
