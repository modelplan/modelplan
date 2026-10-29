// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"slices"
	"sort"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

type sharedCockpit struct{ backend appserver.Backend }

func (s sharedCockpit) AdmitCockpit(ctx context.Context, stamp appserver.Stamp) (queries.CockpitAdmission, error) {
	view, err := s.backend.Get(ctx)
	if err != nil {
		return queries.CockpitAdmission{}, err
	}
	if view.Stamp != stamp {
		return queries.CockpitAdmission{}, appserver.ProtocolError{Code: wire.CodeConsentChanged}
	}
	if len(view.Scopes) == 0 {
		return queries.CockpitAdmission{}, appserver.ProtocolError{Code: wire.CodeConsentRejected}
	}
	scopes := append([]string{}, view.Scopes...)
	sort.Strings(scopes)
	return queries.CockpitAdmission{Stamp: stamp, Scopes: scopes}, nil
}
func (s sharedCockpit) ReadCockpit(ctx context.Context, a queries.CockpitAdmission) (wire.CockpitData, error) {
	view, err := s.backend.Get(ctx)
	if err != nil {
		return wire.CockpitData{}, err
	}
	scopes := append([]string{}, view.Scopes...)
	sort.Strings(scopes)
	if view.Stamp != a.Stamp || !slices.Equal(scopes, a.Scopes) {
		return wire.CockpitData{}, appserver.ProtocolError{Code: wire.CodeConsentChanged}
	}
	data := wire.CockpitData{Projection: wire.Project(view.Projection), Subscriptions: []wire.CockpitSubscription{}}
	groups := map[string][]wire.CockpitAccount{}
	for _, row := range view.Projection.Rows {
		for _, account := range row.Accounts {
			if account.SubscriptionRef != nil {
				ref := *account.SubscriptionRef
				groups[ref] = append(groups[ref], wire.CockpitAccount{Tool: row.ID, Account: account})
			}
		}
	}
	refs := []string{}
	for ref := range groups {
		refs = append(refs, ref)
	}
	sort.Strings(refs)
	for _, ref := range refs {
		data.Subscriptions = append(data.Subscriptions, wire.CockpitSubscription{SubscriptionRef: ref, Accounts: groups[ref]})
	}
	return data, nil
}
