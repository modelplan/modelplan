// SPDX-License-Identifier: MIT
package quota

import (
	"errors"
	"os"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/localusage"
)

// ScopeRefreshPlan projects the existing permission and budget gates. It never
// reserves a read, opens a credential, launches a provider or allocates identity.
// Execution must still pass through the existing locked refresh entry point.
type ScopeRefreshPlan struct {
	Provider      string
	At            time.Time
	Admitted      bool
	BudgetKnown   bool
	PolicyPending bool
}

func PlanScopeRefresh(p Paths, scope string, now time.Time) (ScopeRefreshPlan, error) {
	definition, known := consent.Definition(scope)
	plan := ScopeRefreshPlan{Provider: definition.Tool, At: now.UTC(), BudgetKnown: true}
	if !known {
		return plan, nil
	}
	if id, pending := PolicyPending(definition.Tool); pending && id == scope {
		plan.PolicyPending = true
		return plan, nil
	}
	admission := admissionFor(p)
	if !admission.State().AllowsScope(scope, admission.Mode()) {
		return plan, nil
	}
	switch definition.Class {
	case consent.Local:
		if definition.Tool == "codex" {
			plan.Admitted = p.CodexHome != ""
			return plan, nil
		}
		home, _ := os.UserHomeDir()
		root, access := localusage.ProductionHistoryAccessWithAdmission(home, definition.Tool, false, admission)
		plan.Admitted = root != "" && access.Allowed && !access.Denied && access.Privacy != consent.Off
		if plan.Admitted {
			reading := localusage.ReadHistoryCache(p.Cache, definition.Tool, access, now)
			plan.At = laterRefreshTime(now, reading.NextAttemptAt)
		}
		return plan, nil
	case consent.Runtime:
		if definition.Tool == "codex" {
			plan.Admitted = !CodexAccountOff() && p.Cache != ""
			next, err := codexRefreshNext(p.Cache)
			if err != nil {
				plan.BudgetKnown = false
				return plan, nil
			}
			plan.At = laterRefreshTime(now, next)
			return plan, nil
		}
	case consent.Credential, consent.ExplicitKey:
	default:
		return plan, nil
	}
	if nativeOff() {
		return plan, nil
	}
	reader := nativeReaders[definition.Tool]
	if reader == nil {
		return plan, nil
	}
	if definition.Class == consent.Credential && reader.Managed != nil {
		_, plan.Admitted = readerAllowed(p, definition.Tool)
	} else {
		selections, err := SelectionsWithAdmission(p, admission)
		if err != nil {
			return plan, err
		}
		for _, selection := range selections {
			if selection.Provider == definition.Tool && selection.Backend == BackendNative && selection.Blocked == "" {
				plan.Admitted = true
			}
		}
	}
	if !plan.Admitted {
		return plan, nil
	}
	next := time.Time{}
	early := false
	if reader.Managed != nil {
		if grant, ok := p.ReaderAccessGrant(definition.Tool); ok && grant.SavedLogin {
			state, err := loadReaderState(p.Cache, definition.Tool)
			if err != nil {
				plan.BudgetKnown = false
				return plan, nil
			}
			next = state.NextAttemptAt
			// G3-103 (#911): a new sign-in or grant ends a failure back-off. The desktop plans the
			// read at the five-minute floor, any provider Retry-After and the reader-attempt gate,
			// behind the shared gates, as the locked read admits it (macrev2-942-1).
			if earlyAt, ok := state.earlyNext(p.Cache, definition.Tool); ok && state.earlyEligible(p, definition.Tool, grant) && state.NextAttemptAt.After(earlyAt) {
				early = true
				next = earlyAt
			}
		}
	}
	var budgetKnown bool
	next, budgetKnown = readerGatesNext(p.Cache, definition.Tool, next, !early)
	if !budgetKnown {
		plan.BudgetKnown = false
		return plan, nil
	}
	if capture := loadNative(p.Cache); capture != nil && !early {
		for _, entry := range capture.Providers {
			if entry.Provider == definition.Tool {
				legacy, err := legacyNativeNext(p.Cache, definition.Tool, entry)
				if err != nil {
					plan.BudgetKnown = false
					return plan, nil
				}
				next = laterRefreshTime(next, legacy)
			}
		}
	}
	switch definition.Tool {
	case "copilot":
		next = laterRefreshTime(next, loadCopilotState(p.Cache).NextAt)
	case "antigravity":
		next = laterRefreshTime(next, loadAntigravityState(p.Cache).NextAt)
	case "zai":
		next = laterRefreshTime(next, loadZaiConfigState(p.Cache).NextAt)
	}
	plan.At = laterRefreshTime(now, next)
	if p.Cache == "" {
		return plan, errors.New("reader budget unavailable")
	}
	return plan, nil
}
func laterRefreshTime(a, b time.Time) time.Time {
	if b.After(a) {
		return b.UTC()
	}
	return a.UTC()
}
