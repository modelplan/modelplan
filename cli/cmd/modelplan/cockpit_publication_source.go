// SPDX-License-Identifier: MIT
package main

import (
	"context"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// loadCockpitPublication reads only the verified, local publication cache.
// Unavailable and unverifiable data have the same absent result; cancellation
// remains observable to the caller. It does not fetch or write publication data.
func loadCockpitPublication(ctx context.Context, st *store.Store) (*digest.Digest, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if st == nil {
		return nil, nil
	}
	d, _, err := publication.Load(st)
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if err != nil {
		return nil, nil
	}
	return d, nil
}
