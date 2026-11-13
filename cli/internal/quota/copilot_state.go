package quota

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// CopilotAccess is CLIJIT's admission seam. With no override, the legacy explicit
// native connection is the consent: only an enabled connection dispatches Collect.
// Passive blocks the authenticated runtime, including potential Keychain reads.
type CopilotAccess struct {
	Admission      *consent.CaptureStamp
	CaptureAllowed func(*consent.CaptureStamp) bool
	StillValid     func() bool
	Publish        func(func() error) error
	Allowed        bool
	Denied         bool
	Privacy        string
	// An opaque keyed generation changed after login changes or Settings Retry.
	// Never pass a token, account ID or path.
	LoginGeneration string
}
type copilotAccessKey struct{}

func WithCopilotAccess(ctx context.Context, access CopilotAccess) context.Context {
	return context.WithValue(ctx, copilotAccessKey{}, access)
}

// CopilotResult keeps availability, freshness and beta independent. CLIJIT must
// project these alongside the legacy account DTO. No membership is inferred.
type CopilotResult struct {
	ErrorCode     string    `json:"errorCode,omitempty"`
	Availability  string    `json:"availability"`
	Freshness     string    `json:"freshness"`
	Confidence    string    `json:"confidence"`
	Beta          bool      `json:"beta"`
	NextStep      string    `json:"nextStep"`
	ObservedAt    time.Time `json:"observedAt,omitempty"`
	NextAttemptAt time.Time `json:"nextAttemptAt,omitempty"`
	Reading       *Account  `json:"reading,omitempty"`
}
type copilotState struct {
	ErrorCode       string         `json:"errorCode,omitempty"`
	SchemaVersion   int            `json:"schemaVersion"`
	AttemptAt       time.Time      `json:"attemptAt"`
	NextAt          time.Time      `json:"nextAt"`
	Failures        int            `json:"failures"`
	Availability    string         `json:"availability"`
	LoginGeneration string         `json:"loginGeneration,omitempty"`
	GoodGeneration  string         `json:"goodGeneration,omitempty"`
	Good            *codexbarEntry `json:"lastGood,omitempty"`
}

func copilotStatePath(cache string) string {
	return filepath.Join(cache, "observed", "copilot-v1.json")
}
func loadCopilotState(cache string) copilotState {
	var s copilotState
	b, status := readBounded(copilotStatePath(cache), 128<<10)
	if status != "" || json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 {
		return copilotState{SchemaVersion: 1}
	}
	return s
}
func saveCopilotState(cache string, s copilotState) bool {
	path := copilotStatePath(cache)
	if os.MkdirAll(filepath.Dir(path), 0700) != nil {
		return false
	}
	b, err := json.Marshal(s)
	return err == nil && writeAtomic(path, append(b, '\n')) == nil
}
func copilotNext(state string) string {
	switch state {
	case "ok":
		return "Refresh when needed and allowed"
	case toolcli.RuntimeMissing:
		return toolcli.RuntimeNextStep
	case "not_detected":
		return "Open Copilot; IDE-only quota reading is not supported yet"
	case "denied":
		return "Retry Copilot in Settings"
	case "expired_login":
		return "Open Copilot to refresh its sign-in"
	case "not_supported_yet":
		return "Report the Copilot runtime version for reader support"
	case "consent_required", "privacy_blocked", "off":
		return "Review Copilot consent and privacy settings"
	case "stale", "rate_limited":
		return "Wait until the next eligible Copilot read"
	default:
		return "Check Copilot connectivity and wait until the next eligible read"
	}
}
func copilotAdmission(ctx context.Context) (CopilotAccess, string) {
	a, ok := ctx.Value(copilotAccessKey{}).(CopilotAccess)
	if !ok {
		a.Allowed = true
	}
	if a.LoginGeneration != "" {
		decoded, err := hex.DecodeString(a.LoginGeneration)
		if err != nil || len(decoded) != 32 {
			return a, "privacy_blocked"
		}
	}
	if a.StillValid != nil && !a.StillValid() {
		return a, "consent_required"
	}
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("MODELPLAN_READERS")))
	switch {
	case mode == "off" || a.Privacy == "off":
		return a, "off"
	case a.Denied:
		return a, "denied"
	case !a.Allowed:
		return a, "consent_required"
	case mode == "passive" || a.Privacy == "passive":
		return a, "privacy_blocked"
	case mode != "" && mode != "automatic":
		return a, "privacy_blocked"
	}
	return a, ""
}

// ReadCopilotCache does no detection, subprocess or credential I/O. Expired
// windows disappear without changing the original capture time or stored read.
func ReadCopilotCache(ctx context.Context, cache string, now time.Time) CopilotResult {
	r := CopilotResult{Beta: true, Confidence: "exact", Freshness: "unknown"}
	access, blocked := copilotAdmission(ctx)
	if blocked != "" {
		r.Availability = blocked
		r.NextStep = copilotNext(blocked)
		return r
	}
	s := loadCopilotState(cache)
	if s.Good != nil && !typedCaptureAllowed(s.Good.Admission, consent.ScopeCopilotRuntimeUsage, access.CaptureAllowed) {
		s.Good = nil
	}
	r.Availability = s.Availability
	if r.Availability == "" || s.LoginGeneration != access.LoginGeneration {
		r.Availability = "stale"
	}
	if r.Availability != "ok" && r.Availability == s.Availability && s.ErrorCode != "" {
		r.ErrorCode = ReaderErrorCode(s.ErrorCode)
	}
	r.NextAttemptAt = s.NextAt
	// A last-good reading belongs only to its capture generation. Cache-only
	// requests for a new generation must not expose the preceding login's quota.
	// Older unbound cache entries remain usable only by the legacy empty scope.
	if s.Good != nil && s.GoodGeneration != access.LoginGeneration {
		if r.Availability == "ok" {
			r.Availability = "stale"
		}
		r.NextStep = copilotNext(r.Availability)
		return r
	}
	r.NextStep = copilotNext(r.Availability)
	if s.Good != nil && !s.Good.ObservedAt.IsZero() && !s.Good.ObservedAt.After(now) {
		r.ObservedAt = s.Good.ObservedAt
		a := Account{Source: "native:copilot", ObservedAt: r.ObservedAt, Via: "native", Windows: []Window{}}
		for _, w := range s.Good.Windows {
			if w.ResetsAt == nil || w.ResetsAt.After(now) {
				a.Windows = append(a.Windows, w)
			}
		}
		r.Freshness = "fresh"
		if r.Availability != "ok" || now.Sub(r.ObservedAt) > staleAfter || len(a.Windows) == 0 {
			r.Freshness = "stale"
			a.Stale = true
		}
		r.Reading = &a
	}
	return r
}
func copilotCachedEntry(s copilotState, now time.Time, generation string) codexbarEntry {
	if s.Good != nil && !typedCaptureAllowed(s.Good.Admission, consent.ScopeCopilotRuntimeUsage, nil) {
		s.Good = nil
	}
	availability := s.Availability
	if s.LoginGeneration != generation {
		availability = "stale"
	}
	if s.Good != nil && s.GoodGeneration != generation {
		if availability == "ok" {
			availability = "stale"
		}
		return codexbarEntry{Status: "error", ErrorCode: s.ErrorCode, ObservedAt: now.UTC(), Error: copilotNext(availability)}
	}
	if s.Good == nil {
		status := "error"
		if availability == toolcli.RuntimeMissing {
			status = toolcli.RuntimeMissing
		}
		return codexbarEntry{Status: status, ErrorCode: s.ErrorCode, ObservedAt: now.UTC(), Error: copilotNext(availability)}
	}
	e := *s.Good
	// The native dispatcher must receive the latest attempt's availability,
	// independently of the retained historical payload. It persists this error
	// in native.json, so RefreshNative -> Read cannot call a failed source ok.
	if availability != "ok" {
		e.Status = "error"
		if availability == toolcli.RuntimeMissing {
			e.Status = toolcli.RuntimeMissing
		}
		e.ErrorCode = s.ErrorCode
		e.Error = copilotNext(availability)
	}
	e.Windows = nil
	for _, w := range s.Good.Windows {
		if w.ResetsAt == nil || w.ResetsAt.After(now) {
			e.Windows = append(e.Windows, w)
		}
	}
	return e
}

// In-process time.Time values retain their monotonic component; persisted wall
// gates cover restart and rollback. Never reset this gate on consent changes.
var copilotAttempts sync.Map

func collectCopilot(ctx context.Context, _ *http.Client, cache string, now time.Time) codexbarEntry {
	access, blocked := copilotAdmission(ctx)
	if access.Admission == nil {
		state, _ := consent.Current()
		access.Admission = state.CaptureStamp(consent.ScopeCopilotRuntimeUsage)
	}
	if blocked != "" {
		return codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: copilotNext(blocked)}
	}
	if cache == "" {
		return codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: "Copilot cache unavailable"}
	}
	unlock, ok := lockFile(filepath.Join(cache, "observed", "copilot.lock"), time.Now(), 2*nativeTimeout)
	if !ok {
		return copilotCachedEntry(loadCopilotState(cache), now, access.LoginGeneration)
	}
	defer unlock()
	s := loadCopilotState(cache)
	if last, ok := copilotAttempts.Load(cache); ok && now.Sub(last.(time.Time)) < 5*time.Minute {
		return copilotCachedEntry(s, now, access.LoginGeneration)
	}
	if now.Before(s.NextAt) || now.Before(s.AttemptAt.Add(5*time.Minute)) {
		return copilotCachedEntry(s, now, access.LoginGeneration)
	}
	// A supplied generation permits an authentication hold until a proven tool
	// state change/Settings Retry. Legacy dispatch has no generation handoff:
	// retry only after its persisted adaptive backoff, never hold it forever.
	if s.Availability == "expired_login" && access.LoginGeneration != "" && s.LoginGeneration == access.LoginGeneration {
		return copilotCachedEntry(s, now, access.LoginGeneration)
	}
	s.AttemptAt = now.UTC()
	s.NextAt = now.Add(5 * time.Minute).UTC()
	s.LoginGeneration = access.LoginGeneration
	if !publishReaderCache(access.Publish, func() bool { return saveCopilotState(cache, s) }) {
		return codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: "Copilot attempt gate unavailable"}
	}
	copilotAttempts.Store(cache, now)
	e := fetchCopilot(ctx, nil, "local", "", now)
	// CLIJIT cancels in-flight reads on revocation. Never republish their result.
	if _, blocked := copilotAdmission(ctx); ctx.Err() != nil || blocked != "" {
		return codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: copilotNext("consent_required")}
	}
	if e.Status == "ok" {
		e.Admission = access.Admission
		s.Good = &e
		s.GoodGeneration = access.LoginGeneration
		s.Failures = 0
		s.Availability = "ok"
		s.ErrorCode = ""
		s.NextAt = now.Add(10 * time.Minute).UTC()
	} else {
		s.ErrorCode = ReaderErrorCode(e.ErrorCode)
		s.Failures = min(s.Failures+1, 4)
		wait := time.Duration(10*(1<<(s.Failures-1))) * time.Minute
		if s.Failures == 4 {
			wait = time.Hour
		}
		s.NextAt = now.Add(wait).UTC()
		s.Availability = "upstream_changed"
		for _, state := range []string{toolcli.RuntimeMissing, "not_detected", "expired_login", "not_supported_yet"} {
			if e.Error == copilotNext(state) {
				s.Availability = state
			}
		}
	}
	if !publishReaderCache(access.Publish, func() bool { return saveCopilotState(cache, s) }) {
		return codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: "Copilot result cache unavailable"}
	}
	return copilotCachedEntry(s, now, access.LoginGeneration)
}
