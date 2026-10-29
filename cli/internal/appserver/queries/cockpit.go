// SPDX-License-Identifier: MIT
package queries

import (
	"context"
	"encoding/json"
	"slices"
	"sort"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

type CockpitAdmission struct {
	Stamp  appserver.Stamp
	Scopes []string
}

// CockpitSource admits every covered scope before reading display values.
// Sources use the existing shared backend and never refresh or mutate rows.
type CockpitSource interface {
	AdmitCockpit(context.Context, appserver.Stamp) (CockpitAdmission, error)
	ReadCockpit(context.Context, CockpitAdmission) (wire.CockpitData, error)
}
type CockpitConfig struct {
	State  appserver.Backend
	Source CockpitSource
}

func cockpitScopes(scopes []string) ([]string, bool) {
	result := append([]string{}, scopes...)
	sort.Strings(result)
	for i, s := range result {
		if s == "" || (i > 0 && s == result[i-1]) {
			return nil, false
		}
	}
	return result, len(result) > 0
}
func CockpitHandler(config CockpitConfig) (appserver.Handler, error) {
	if config.State == nil || config.Source == nil {
		return appserver.Handler{}, protocol(wire.CodeInternal)
	}
	return appserver.Handler{Capability: "cockpit", Query: true, Private: true, Handle: func(ctx context.Context, raw json.RawMessage, stamp appserver.Stamp) (appserver.Reply, error) {
		if !emptyParams(raw) {
			return appserver.Reply{}, protocol(wire.CodeInvalidParams)
		}
		if err := ctx.Err(); err != nil {
			return appserver.Reply{}, err
		}
		admission, err := config.Source.AdmitCockpit(ctx, stamp)
		if err != nil {
			return appserver.Reply{}, err
		}
		if admission.Stamp != stamp {
			return appserver.Reply{}, protocol(wire.CodeConsentChanged)
		}
		scopes, ok := cockpitScopes(admission.Scopes)
		if !ok {
			return appserver.Reply{}, protocol(wire.CodeConsentRejected)
		}
		view, err := config.State.Get(ctx)
		if err != nil {
			return appserver.Reply{}, err
		}
		if view.Stamp != stamp {
			return appserver.Reply{}, protocol(wire.CodeConsentChanged)
		}
		current, ok := cockpitScopes(view.Scopes)
		if !ok || !slices.Equal(scopes, current) {
			return appserver.Reply{}, protocol(wire.CodeConsentRejected)
		}
		if err := ctx.Err(); err != nil {
			return appserver.Reply{}, err
		}
		admission.Scopes = append([]string{}, scopes...)
		data, err := config.Source.ReadCockpit(ctx, admission)
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
		current, ok = cockpitScopes(view.Scopes)
		if !ok || !slices.Equal(scopes, current) {
			return appserver.Reply{}, protocol(wire.CodeConsentChanged)
		}
		return appserver.Reply{Stamp: stamp, Scopes: scopes, Data: data}, nil
	}}, nil
}
