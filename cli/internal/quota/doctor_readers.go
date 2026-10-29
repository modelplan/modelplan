// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
	"os"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/localusage"
)

// ReaderDiagnostic is an explicit allowlist, never an embedded reader DTO.
// Provider comes only from compiled inventories; all other strings are fixed
// codes or a computed UTC age. No cache/provider text reaches the output.
type ReaderDiagnostic struct {
	Provider string `json:"provider"`
	Detected string `json:"detected"`
	Consent  string `json:"consent"`
	Admitted string `json:"admitted"`
	State    string `json:"state"`
	Windows  int    `json:"windows"`
	Last     string `json:"last"`
	Beta     bool   `json:"beta"`
}

func yesNo(v bool) string {
	if v {
		return "yes"
	}
	return "no"
}
func diagnosticConsent(s consent.State, id, class string) string {
	r, ok := s.Tools[id]
	if !ok {
		return "none"
	}
	if !r.Allowed || r.DeniedSources[class] {
		return "denied"
	}
	if r.ConsentTextVersion == consent.TextVersion {
		return "granted"
	}
	return "none"
}
func diagnosticAge(at, now time.Time) string {
	if at.IsZero() || at.After(now) {
		return "unknown"
	}
	return fmt.Sprintf("%ds", int64(now.UTC().Sub(at.UTC())/time.Second))
}
func diagnosticState(status string) string {
	switch status {
	case toolcli.RuntimeMissing:
		return "unavailable:" + toolcli.RuntimeMissing
	case "ok":
		return "ok"
	case "stale":
		return "stale"
	case "not_supported_yet", "unsupported_schema", "unsupported-schema":
		return "not_supported_yet"
	case "denied", "keychain_denied":
		return "unavailable:denied"
	case "consent_required", "consent-required":
		return "unavailable:consent_required"
	case "off", "privacy_blocked":
		return "unavailable:privacy_blocked"
	case "not_detected", "not-detected":
		return "unavailable:not_detected"
	case "rate-limited", "rate_limited":
		return "unavailable:rate_limited"
	case "auth-expired", "auth_expired", "login_expired", "expired":
		return "unavailable:login_expired"
	case "confirmation-needed", "confirmation_needed", "keychain-confirmation-needed":
		return "unavailable:confirmation_needed"
	case "partial":
		return "unavailable:partial"
	case "":
		return "unavailable:not_read"
	default:
		return "unavailable:reader_error"
	}
}
func diagnosticBlocked(blocked string) string {
	switch blocked {
	case "no-key":
		return "unavailable:no_key"
	case "native-off", "reader-consent-or-privacy":
		return "unavailable:privacy_blocked"
	case "update-required":
		return "unavailable:update_required"
	case "catalogue-off":
		return "unavailable:catalogue_off"
	default:
		return "unavailable:not_admitted"
	}
}
func diagnosticWindows(ws []Window, now time.Time) int {
	n := 0
	for _, w := range ws {
		if w.ResetsAt == nil || w.ResetsAt.After(now) {
			n++
		}
	}
	return n
}

// ReaderDiagnostics uses only production admission, presence metadata and
// ModelPlan caches. In particular it never calls ReadPermitted, whose legacy
// paths can open tool-owned session files or inspect current login state.
func ReaderDiagnostics(p Paths, now time.Time) []ReaderDiagnostic {
	policy, _ := consent.Current()
	cat := loadReaderCatalogue(p.Cache)
	if cat == nil {
		cat = detect.Fallback()
	}
	presence := map[string]bool{}
	for _, tool := range detect.Run(cat, detect.Local(), p.CLIVersion, "").Tools {
		presence[tool.ProviderID] = tool.Detected
	}
	selected := map[string]Selection{}
	selections, selectionErr := Selections(p)
	for _, x := range selections {
		selected[x.Provider] = x
	}
	old := map[string]codexbarEntry{}
	if s := loadNative(p.Cache); s != nil {
		for _, e := range s.Providers {
			old[e.Provider] = e
		}
	}
	rows := []ReaderDiagnostic{}
	for id, n := range nativeReaders {
		x := selected[id]
		g, _ := p.ReaderAccessGrant(id)
		_, managed := readerAllowed(p, id)
		managed = n.Managed != nil && managed
		admitted := managed || (selectionErr == nil && x.Backend == BackendNative && x.Blocked == "" && legacyNativeReader(p, id))
		class := consent.Credential
		if id == "copilot" || id == "kiro" {
			class = consent.Runtime
		}
		if n.KeyEnv != "" && !managed {
			class = consent.ExplicitKey
		}
		_, policyPending := PolicyPending(id)
		if policyPending {
			admitted = false
		}
		row := ReaderDiagnostic{Provider: id, Detected: yesNo(presence[id]), Consent: diagnosticConsent(policy, id, class), Admitted: yesNo(admitted), Last: "unknown", State: "unavailable:not_admitted", Beta: n.Managed != nil || id == "copilot" || id == "antigravity" || (id == "zai" && g.ConfigSource != nil)}
		// Legacy explicit connections are existing consent, even without a new record.
		if _, decided := policy.Tools[id]; !decided && (admitted || (x.Origin == "connections.json" && x.Backend == BackendNative)) {
			row.Consent = "granted"
		}
		switch {
		case policyPending:
			row.State = "unavailable:policy_pending"
		case !admitted:
			row.State = diagnosticBlocked(x.Blocked)
			if row.Consent == "denied" {
				row.State = "unavailable:denied"
			}
			if selectionErr != nil {
				row.State = "unavailable:config_unavailable"
			}
		case managed:
			s, err := loadReaderState(p.Cache, id)
			if err != nil {
				row.State = "unavailable:cache_unavailable"
				break
			}
			row.State = "unavailable:not_read"
			var last time.Time
			failure := ""
			for _, e := range s.Entries {
				state := nativeDiagnosticState(e.Status, e.ErrorCode)
				if state != "ok" {
					failure = state
				}
				if e.Account != nil {
					row.Windows += diagnosticWindows(e.Account.Windows, now)
					if e.Account.ObservedAt.After(last) {
						last = e.Account.ObservedAt
					}
				}
			}
			if len(s.Entries) > 0 {
				row.State = "ok"
			}
			if last.IsZero() || now.Sub(last) > staleAfter || last.After(now) {
				if len(s.Entries) > 0 {
					row.State = "stale"
				}
			}
			if failure != "" {
				row.State = failure
			}
			row.Last = diagnosticAge(last, now)
		default:
			e, exists := old[id]
			row.State = "unavailable:not_read"
			if exists {
				row.State = nativeDiagnosticState(e.Status, e.ErrorCode)
				row.Last = diagnosticAge(e.ObservedAt, now)
				row.Windows = diagnosticWindows(e.Windows, now)
				if row.State == "ok" && (e.ObservedAt.IsZero() || now.Sub(e.ObservedAt) > nativeKeep || e.ObservedAt.After(now)) {
					row.State = "stale"
				}
			}
		}
		if admitted && !managed {
			ctx := productionReaderContext(context.Background(), p, id)
			switch {
			case id == "copilot":
				r := ReadCopilotCache(ctx, p.Cache, now)
				fillDiagnosticCache(&row, r.Availability, r.Freshness, r.ObservedAt, r.Reading, now)
				if r.ErrorCode != "" {
					row.State = nativeDiagnosticState(r.Availability, r.ErrorCode)
				}
			case id == "antigravity":
				r := ReadAntigravityCache(ctx, p.Cache, now)
				fillDiagnosticCache(&row, r.Availability, r.Freshness, r.ObservedAt, r.Reading, now)
				if r.ErrorCode != "" {
					row.State = nativeDiagnosticState(r.Availability, r.ErrorCode)
				}
			case id == "zai" && g.ConfigSource != nil:
				r := ReadZaiConfigCache(ctx, p.Cache, now)
				fillDiagnosticCache(&row, r.Availability, r.Freshness, r.ObservedAt, r.Reading, now)
				if r.ErrorCode != "" {
					row.State = nativeDiagnosticState(r.Availability, r.ErrorCode)
				}
			}
		}
		rows = append(rows, row)
	}
	home, _ := os.UserHomeDir()
	for _, id := range localusage.HistoryProviders() {
		root, a := localusage.ProductionHistoryAccess(home, id, false)
		admitted := historyDiagnosticAdmission(root, a)
		r := localusage.ReadHistoryCache(p.Cache, id, a, now)
		state := diagnosticState(r.Availability)
		if r.Availability == "ok" && r.Freshness != "fresh" {
			state = "stale"
		}
		if !admitted {
			state = "unavailable:not_admitted"
			if a.Denied {
				state = "unavailable:denied"
			}
		}
		grant := diagnosticConsent(policy, id, consent.Local)
		if grant == "denied" {
			state = "unavailable:denied"
		}
		if grant == "none" && a.Allowed {
			grant = "granted"
		}
		rows = append(rows, ReaderDiagnostic{Provider: id + ":history", Detected: yesNo(detect.LocalRoot(root)), Consent: grant, Admitted: yesNo(admitted), State: state, Last: diagnosticAge(r.ObservedAt, now), Beta: true})
	}
	a := p.ClaudeSessionAccess
	row := ReaderDiagnostic{Provider: "claude:session", Detected: yesNo(presence["claude"]), Consent: diagnosticConsent(policy, "claude", consent.Local), Admitted: "no", State: "unavailable:not_admitted", Last: "unknown", Beta: true}
	if a != nil && historyDiagnosticAdmission(p.ClaudeSessionRoot, *a) {
		row.Admitted = "yes"
		r := localusage.ReadProjectionCache(p.Cache, "claude", *a, now)
		row.State, row.Last = diagnosticState(r.Availability), diagnosticAge(r.ObservedAt, now)
		if r.Availability == "ok" && r.Freshness != "fresh" {
			row.State = "stale"
		}
	}
	rows = append(rows, row)
	sort.Slice(rows, func(i, j int) bool { return rows[i].Provider < rows[j].Provider })
	return rows
}
func historyDiagnosticAdmission(root string, a localusage.HistoryAccess) bool {
	return a.Allowed && !a.Denied && a.Privacy != consent.Off && os.Getenv("MODELPLAN_HISTORY") != "off" && detect.LocalRoot(root) && (a.StillValid == nil || a.StillValid())
}

// RefreshReaderDiagnostics is an explicit foreground read. Existing provider
// gates reserve before I/O; ordinary and diagnostic legacy dispatch share the
// persistent floor and cached interval/backoff. No helper fallback is run.
func RefreshReaderDiagnostics(ctx context.Context, p Paths, now time.Time) error {
	err := refreshNative(ctx, InteractiveReaders(p), now, true)
	home, _ := os.UserHomeDir()
	for _, id := range localusage.HistoryProviders() {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		root, a := localusage.ProductionHistoryAccess(home, id, false)
		if historyDiagnosticAdmission(root, a) {
			localusage.RefreshProductionHistory(ctx, home, p.Cache, id, now)
		}
	}
	return err
}

func fillDiagnosticCache(row *ReaderDiagnostic, availability, freshness string, at time.Time, a *Account, now time.Time) {
	row.State, row.Last, row.Windows = diagnosticState(availability), diagnosticAge(at, now), 0
	if availability == "ok" && freshness != "fresh" {
		row.State = "stale"
	}
	if a != nil {
		row.Windows = diagnosticWindows(a.Windows, now)
	}
}

// The session projection normally polls faster. This explicit doctor sweep
// applies the same five-minute minimum as the account/count verification reads.
func diagnosticSessionDue(p Paths, now time.Time) bool {
	if p.ClaudeSessionAccess == nil || !readerAttemptDue(p.Cache, "claude-session", now) {
		return false
	}
	r := localusage.ReadProjectionCache(p.Cache, "claude", *p.ClaudeSessionAccess, now)
	return r.CapturedAt.IsZero() || !now.Before(r.CapturedAt.Add(5*time.Minute))
}
