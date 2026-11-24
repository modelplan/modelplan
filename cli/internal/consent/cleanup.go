// SPDX-License-Identifier: MIT
package consent

import (
	"sort"
	"strings"
)

// RetryCleanup retries durable erasure obligations without replaying a mutation,
// changing permissions, or changing the original receipt returned to a client.
// The engine calls it after in-flight readers drain and on restart.
//
// Erasure runs without the consent lock (macrevb-1218-2): each callback may wait for the reader
// lock, and holding the consent lock across that wait made a foreground Deny or Forget give up
// before it committed. Completed obligations are then cleared under the lock, only if no consent
// commit happened meanwhile; otherwise they stay owed and the next retry erases again, which is
// idempotent. A failed erasure always stays owed.
func RetryCleanup(file string, cleanup func(scope string, forget bool) error) error {
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
	scopes := make([]string, 0, len(owed))
	for scope := range owed {
		scopes = append(scopes, scope)
	}
	sort.Strings(scopes)
	done := map[string]bool{}
	for _, scope := range scopes {
		if cleanup != nil && cleanup(scope, owed[scope]) == nil {
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
