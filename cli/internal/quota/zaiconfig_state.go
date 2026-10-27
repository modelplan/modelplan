package quota

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// ZaiConfigAccess is CLIJIT's fail-closed admission seam. Explicit configured
// keys are allowed in Passive mode. No credential-store import is performed.
type ZaiConfigAccess struct {
	Allowed bool
	Denied  bool
	Privacy string
	// An opaque keyed generation changed after login changes or Settings Retry.
	// Never pass a token, account ID or path.
	LoginGeneration string
}
type zaiConfigAccessKey struct{}

func WithZaiConfigAccess(ctx context.Context, access ZaiConfigAccess) context.Context {
	return context.WithValue(ctx, zaiConfigAccessKey{}, access)
}

// ZaiConfigResult keeps availability, freshness and beta independent. CLIJIT must
// project these alongside the legacy account DTO. No membership is inferred.
type ZaiConfigResult struct {
	Availability  string    `json:"availability"`
	Freshness     string    `json:"freshness"`
	Confidence    string    `json:"confidence"`
	Beta          bool      `json:"beta"`
	NextStep      string    `json:"nextStep"`
	ObservedAt    time.Time `json:"observedAt,omitempty"`
	NextAttemptAt time.Time `json:"nextAttemptAt,omitempty"`
	Reading       *Account  `json:"reading,omitempty"`
}
type zaiConfigState struct {
	SchemaVersion   int            `json:"schemaVersion"`
	AttemptAt       time.Time      `json:"attemptAt"`
	NextAt          time.Time      `json:"nextAt"`
	Failures        int            `json:"failures"`
	Availability    string         `json:"availability"`
	LoginGeneration string         `json:"loginGeneration,omitempty"`
	GoodGeneration  string         `json:"goodGeneration,omitempty"`
	Good            *codexbarEntry `json:"lastGood,omitempty"`
}

func zaiConfigStatePath(cache string) string {
	return filepath.Join(cache, "observed", "zai-config-v1.json")
}
func loadZaiConfigState(cache string) zaiConfigState {
	var s zaiConfigState
	b, status := readBounded(zaiConfigStatePath(cache), 128<<10)
	if status != "" || json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 {
		return zaiConfigState{SchemaVersion: 1}
	}
	return s
}
func saveZaiConfigState(cache string, s zaiConfigState) bool {
	path := zaiConfigStatePath(cache)
	if os.MkdirAll(filepath.Dir(path), 0700) != nil {
		return false
	}
	b, err := json.Marshal(s)
	return err == nil && writeAtomic(path, append(b, '\n')) == nil
}
func zaiConfigNext(state string) string {
	switch state {
	case "ok":
		return "Refresh when needed and allowed"
	case "not_detected":
		return "Open the configured tool to review its GLM connection"
	case "denied":
		return "Retry ZaiConfig in Settings"
	case "expired_login":
		return "Open the configured tool to refresh its GLM key"
	case "not_supported_yet":
		return "Review the selected GLM provider endpoint and login type"
	case "consent_required", "privacy_blocked", "off":
		return "Review ZaiConfig consent and privacy settings"
	case "stale", "rate_limited":
		return "Wait until the next eligible ZaiConfig read"
	default:
		return "Check ZaiConfig connectivity and wait until the next eligible read"
	}
}
func zaiConfigAdmission(ctx context.Context) (ZaiConfigAccess, string) {
	a, ok := ctx.Value(zaiConfigAccessKey{}).(ZaiConfigAccess)
	if !ok {
		a.Allowed = false
	}
	if a.LoginGeneration != "" {
		decoded, err := hex.DecodeString(a.LoginGeneration)
		if err != nil || len(decoded) != 32 {
			return a, "privacy_blocked"
		}
	}
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("MODELPLAN_READERS")))
	switch {
	case mode == "off" || a.Privacy == "off":
		return a, "off"
	case a.Denied:
		return a, "denied"
	case !a.Allowed:
		return a, "consent_required"

	case mode != "" && mode != "automatic" && mode != "passive":
		return a, "privacy_blocked"
	}
	return a, ""
}

// ReadZaiConfigCache does no detection, subprocess or credential I/O. Expired
// windows disappear without changing the original capture time or stored read.
func ReadZaiConfigCache(ctx context.Context, cache string, now time.Time) ZaiConfigResult {
	r := ZaiConfigResult{Beta: true, Confidence: "exact", Freshness: "unknown"}
	access, blocked := zaiConfigAdmission(ctx)
	if blocked != "" {
		r.Availability = blocked
		r.NextStep = zaiConfigNext(blocked)
		return r
	}
	s := loadZaiConfigState(cache)
	r.Availability = s.Availability
	if r.Availability == "" || s.LoginGeneration != access.LoginGeneration {
		r.Availability = "stale"
	}
	r.NextAttemptAt = s.NextAt
	// A last-good reading belongs only to its capture generation. Cache-only
	// requests for a new generation must not expose the preceding login's quota.
	// Older unbound cache entries remain usable only by the legacy empty scope.
	if s.Good != nil && s.GoodGeneration != access.LoginGeneration {
		if r.Availability == "ok" {
			r.Availability = "stale"
		}
		r.NextStep = zaiConfigNext(r.Availability)
		return r
	}
	r.NextStep = zaiConfigNext(r.Availability)
	if s.Good != nil && !s.Good.ObservedAt.IsZero() && !s.Good.ObservedAt.After(now) {
		r.ObservedAt = s.Good.ObservedAt
		a := Account{Source: "native:zai", ObservedAt: r.ObservedAt, Via: "native", Windows: []Window{}}
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
func zaiConfigCachedEntry(s zaiConfigState, now time.Time, generation string) codexbarEntry {
	availability := s.Availability
	if s.LoginGeneration != generation {
		availability = "stale"
	}
	if s.Good != nil && s.GoodGeneration != generation {
		if availability == "ok" {
			availability = "stale"
		}
		return codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: zaiConfigNext(availability)}
	}
	if s.Good == nil {
		return codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: zaiConfigNext(s.Availability)}
	}
	e := *s.Good
	// The native dispatcher must receive the latest attempt's availability,
	// independently of the retained historical payload. It persists this error
	// in native.json, so RefreshNative -> Read cannot call a failed source ok.
	if availability != "ok" {
		e.Status = "error"
		e.Error = zaiConfigNext(availability)
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
var zaiConfigAttempts sync.Map

func collectZaiConfig(ctx context.Context, _ *http.Client, cache string, now time.Time) codexbarEntry {
	access, blocked := zaiConfigAdmission(ctx)
	if blocked != "" {
		return codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: zaiConfigNext(blocked)}
	}
	if cache == "" {
		return codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: "ZaiConfig cache unavailable"}
	}
	unlock, ok := lockFile(filepath.Join(cache, "observed", "zai.lock"), time.Now(), 2*nativeTimeout)
	if !ok {
		return zaiConfigCachedEntry(loadZaiConfigState(cache), now, access.LoginGeneration)
	}
	defer unlock()
	s := loadZaiConfigState(cache)
	if last, ok := zaiConfigAttempts.Load(cache); ok && now.Sub(last.(time.Time)) < 5*time.Minute {
		return zaiConfigCachedEntry(s, now, access.LoginGeneration)
	}
	if now.Before(s.NextAt) || now.Before(s.AttemptAt.Add(5*time.Minute)) {
		return zaiConfigCachedEntry(s, now, access.LoginGeneration)
	}
	// A supplied generation permits an authentication hold until a proven tool
	// state change/Settings Retry. Legacy dispatch has no generation handoff:
	// retry only after its persisted adaptive backoff, never hold it forever.
	if s.Availability == "expired_login" && access.LoginGeneration != "" && s.LoginGeneration == access.LoginGeneration {
		return zaiConfigCachedEntry(s, now, access.LoginGeneration)
	}
	s.AttemptAt = now.UTC()
	s.NextAt = now.Add(5 * time.Minute).UTC()
	s.LoginGeneration = access.LoginGeneration
	if !saveZaiConfigState(cache, s) {
		return codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: "ZaiConfig attempt gate unavailable"}
	}
	zaiConfigAttempts.Store(cache, now)
	e := fetchZaiConfig(ctx, nativeClient, "local", "", now)
	// CLIJIT cancels in-flight reads on revocation. Never republish their result.
	if _, blocked := zaiConfigAdmission(ctx); ctx.Err() != nil || blocked != "" {
		return codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: zaiConfigNext("consent_required")}
	}
	if e.Status == "ok" {
		s.Good = &e
		s.GoodGeneration = access.LoginGeneration
		s.Failures = 0
		s.Availability = "ok"
		s.NextAt = now.Add(10 * time.Minute).UTC()
	} else {
		s.Failures = min(s.Failures+1, 4)
		wait := time.Duration(10*(1<<(s.Failures-1))) * time.Minute
		if s.Failures == 4 {
			wait = time.Hour
		}
		s.NextAt = now.Add(wait).UTC()
		s.Availability = "upstream_changed"
		for _, state := range []string{"not_detected", "expired_login", "not_supported_yet"} {
			if e.Error == zaiConfigNext(state) {
				s.Availability = state
			}
		}
	}
	if !saveZaiConfigState(cache, s) {
		return codexbarEntry{Status: "error", ObservedAt: now.UTC(), Error: "ZaiConfig result cache unavailable"}
	}
	return zaiConfigCachedEntry(s, now, access.LoginGeneration)
}
