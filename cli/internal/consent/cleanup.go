// SPDX-License-Identifier: MIT
package consent

import (
	"sort"
	"strings"
)

// EraseGuard fences one erasure at the point of deletion (macrevb-1218-5). An eraser calls it
// after it has taken the reader lock, which every private capture holds while it commits, and
// erases nothing unless it returns nil. While the eraser keeps the reader lock no capture can
// land, so whatever it then deletes predates the check. A nil guard means the caller already
// holds the consent lock (a foreground Deny or Forget finalizing its own commit).
type EraseGuard func() error

// Check runs the guard; a nil guard always passes.
func (g EraseGuard) Check() error {
	if g == nil {
		return nil
	}
	return g()
}

// Eraser is a fenced erasure hook: it must call guard.Check under the reader lock before each
// destructive step and stop when it fails.
type Eraser func(scope string, forget bool, guard EraseGuard) error

// owes reports whether state still owes erasure of scope, and whether any owing receipt asks
// for the stronger Forget erasure.
func owes(state State, scope string) (owed, forget bool) {
	for _, receipt := range state.Requests {
		for _, pending := range receipt.PendingForget {
			if pending == scope {
				owed = true
				forget = forget || receipt.ForgetScopes[scope] || !strings.Contains(scope, ".")
			}
		}
	}
	return owed, forget
}

// RetryCleanup retries durable erasure obligations without replaying a mutation,
// changing permissions, or changing the original receipt returned to a client.
// The engine calls it after in-flight readers drain and on restart.
//
// Erasure runs without the consent lock (macrevb-1218-2): each callback may wait for the reader
// lock, and holding the consent lock across that wait made a foreground Deny or Forget give up
// before it committed. Completed obligations are then cleared under the lock, only if no consent
// commit happened meanwhile; otherwise they stay owed and the next retry erases again, which is
// idempotent. A failed erasure always stays owed.
//
// Erasure authority never outlives the store that granted it (macrevb-1218-5): each callback
// gets a guard that, at the point of deletion, passes only while the authoritative store is
// still the snapshot's epoch and still owes that scope at least as strongly. A confirmed reset,
// or a re-grant after the obligation was met, therefore makes a waiting retry erase nothing,
// so a capture admitted afterwards survives.
func RetryCleanup(file string, cleanup Eraser) error {
	if err := writable(); err != nil {
		return err
	}
	snapshot, err := loadAuthoritative(file)
	if err != nil {
		return err
	}
	owed := map[string]bool{}
	for _, receipt := range snapshot.Requests {
		for _, scope := range receipt.PendingForget {
			owed[scope] = owed[scope] || receipt.ForgetScopes[scope] || !strings.Contains(scope, ".")
		}
	}
	guard := func(scope string, forget bool) EraseGuard {
		return func() error {
			current, err := loadAuthoritative(file)
			if err != nil {
				return err
			}
			still, strong := owes(current, scope)
			if current.StoreEpoch != snapshot.StoreEpoch || !still || (forget && !strong) {
				return ErrChanged
			}
			return nil
		}
	}
	scopes := make([]string, 0, len(owed))
	for scope := range owed {
		scopes = append(scopes, scope)
	}
	sort.Strings(scopes)
	done := map[string]bool{}
	for _, scope := range scopes {
		if cleanup != nil && cleanup(scope, owed[scope], guard(scope, owed[scope])) == nil {
			done[scope] = true
		}
	}
	if len(done) == 0 {
		return nil
	}
	unlock, err := lockConsent(file)
	if err != nil {
		return err
	}
	defer unlock()
	state, err := loadLocked(file)
	if err != nil {
		return err
	}
	if state.Fence() != snapshot.Fence() {
		return nil
	}
	changed := false
	owedKey := ReceiptKey(state.StoreEpoch, owedReceiptID)
	for id, receipt := range state.Requests {
		pending := []string{}
		for _, scope := range receipt.PendingForget {
			forget := receipt.ForgetScopes[scope] || !strings.Contains(scope, ".")
			// Clear only what was erased at least as strongly as this receipt owes.
			if done[scope] && (owed[scope] || !forget) {
				changed = true
				continue
			}
			pending = append(pending, scope)
		}
		receipt.PendingForget = pending
		if id == owedKey && len(pending) == 0 {
			delete(state.Requests, id)
			changed = true
			continue
		}
		state.Requests[id] = receipt
	}
	if changed {
		return save(file, state)
	}
	return nil
}
