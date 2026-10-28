package quota

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"time"
)

// The inspected Cursor/Grok contracts do not establish a common seat/principal
// ID. Equal usage, resets, email or installation never creates an alias. Keep the
// two source refs separate and non-additive until a verified link contract exists.
func unverifiedXSubscription() *SharedPoolBinding {
	return &SharedPoolBinding{Kind: "x-subscription", Status: "unverified", Additive: false}
}

type xSubscriptionAttempt struct {
	SchemaVersion int       `json:"schemaVersion"`
	NextAttemptAt time.Time `json:"nextAttemptAt"`
}

func xSubscriptionPath(cache string) string {
	return filepath.Join(cache, "observed", "x-subscription-attempt.json")
}

func xSubscriptionDue(cache, provider string, now time.Time) bool {
	if provider != "cursor" && provider != "grok" {
		return true
	}
	b, status := readBounded(xSubscriptionPath(cache), 4096)
	if status == "missing" {
		return true
	}
	var s xSubscriptionAttempt
	return status == "" && json.Unmarshal(b, &s) == nil && s.SchemaVersion == 1 && !now.Before(s.NextAttemptAt)
}

// refreshManaged holds the existing cross-process native lock. Reserve the
// conservative shared pool floor before any credential or usage I/O; publication
// and personal link discovery cannot relax it or add a remote lookup request.
func reserveXSubscription(cache, provider string, now time.Time) error {
	if provider != "cursor" && provider != "grok" {
		return nil
	}
	path := xSubscriptionPath(cache)
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return errors.New("usage budget unavailable")
	}
	b, _ := json.Marshal(xSubscriptionAttempt{SchemaVersion: 1, NextAttemptAt: now.Add(5 * time.Minute).UTC()})
	if writeAtomic(path, append(b, '\n')) != nil {
		return errors.New("usage budget unavailable")
	}
	return nil
}
