// SPDX-License-Identifier: MIT
package consent

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Grant is the engine mutation boundary. Only Allow is subject to detection,
// reader availability and policy gates. Deny and Forget accept retired scopes.
type Grant struct {
	RequestID          string            `json:"requestId"`
	ExpectStoreEpoch   string            `json:"expectStoreEpoch"`
	ExpectGeneration   uint64            `json:"expectGeneration"`
	ConsentTextVersion int               `json:"consentTextVersion"`
	Allow              []string          `json:"allow"`
	Deny               []string          `json:"deny"`
	Forget             []string          `json:"forget,omitempty"`
	Keychain           map[string]string `json:"keychain,omitempty"`
}

type GrantReceipt struct {
	Replayed            bool     `json:"-"`
	RequestID           string   `json:"requestId"`
	StoreEpoch          string   `json:"storeEpoch"`
	Committed           bool     `json:"committed"`
	CommittedGeneration *uint64  `json:"committedGeneration"`
	CleanupPending      []string `json:"cleanupPending,omitempty"`
	Code                string   `json:"code"`
	CleanupError        string   `json:"cleanupError,omitempty"`
}

// GrantHooks belongs to the engine. Admit must return route metadata for an
// allowed scope; Cleanup may erase only ModelPlan-owned values. Deny erases
// readings; Forget also erases derived history and identity. Neither erases
// request budgets. A nil cleanup keeps the durable obligation pending.
type GrantHooks struct {
	Admit   func(ScopeDefinition) (Record, error)
	Cleanup func(scope string, forget bool) error
}

// EnsureStore establishes an epoch before a client takes its first floor. The
// cache-only Load path remains read-only on a fresh home.
func EnsureStore(file string) (State, error) {
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		return Empty(), err
	}
	unlock, err := lockFile(file + ".lock")
	if err != nil {
		return Empty(), err
	}
	defer unlock()
	s, err := loadLocked(file)
	if err != nil {
		return Empty(), err
	}
	if s.StoreEpoch == "" {
		s.StoreEpoch = newEpoch()
		err = save(file, s)
	}
	return s, err
}

func ApplyGrant(file string, grant Grant, hooks GrantHooks) (GrantReceipt, error) {
	var result GrantReceipt
	if grant.RequestID == "" || len(grant.RequestID) > 128 || !validEpoch(grant.ExpectStoreEpoch) {
		return result, errors.New("invalid_request")
	}
	seen := map[string]bool{}
	for _, ids := range [][]string{grant.Allow, grant.Deny, grant.Forget} {
		for _, id := range ids {
			if !ValidScope(id) || seen[id] {
				return result, errors.New("invalid_request")
			}
			seen[id] = true
		}
	}
	for id, choice := range grant.Keychain {
		if !seen[id] || (choice != "allow" && choice != "deny") {
			return result, errors.New("invalid_request")
		}
	}
	raw, _ := json.Marshal(grant)
	hash := sha256.Sum256(raw)
	requestHash := hex.EncodeToString(hash[:])
	key := ReceiptKey(grant.ExpectStoreEpoch, grant.RequestID)
	cleanup := append(append([]string{}, grant.Deny...), grant.Forget...)
	err := Transaction(file, func(s *State) error {
		// Check the epoch before tuple-keyed receipt lookup, even at the same numeric generation.
		if grant.ExpectStoreEpoch != s.StoreEpoch {
			return errors.New("consent_stale")
		}
		if receipt, ok := s.Requests[key]; ok {
			if receipt.RequestHash != requestHash {
				return errors.New("request_mismatch")
			}
			if json.Unmarshal(receipt.Result, &result) != nil {
				return errors.New("consent_unavailable")
			}
			result.Replayed = true
			return ErrUnchanged
		}
		if s.Generation != grant.ExpectGeneration {
			return errors.New("stale_generation")
		}
		if len(grant.Allow) > 0 && grant.ConsentTextVersion != TextVersion {
			return errors.New("stale_consent_text")
		}
		admitted := map[string]Record{}
		for _, id := range grant.Allow {
			d, known := Definition(id)
			if !known {
				return errors.New("unknown_scope")
			}
			if s.Effective(os.Getenv("MODELPLAN_READERS")) == Off {
				return errors.New("readers_off")
			}
			if hooks.Admit == nil {
				return errors.New("reader_unavailable")
			}
			r, err := hooks.Admit(d)
			if err != nil {
				return err
			}
			admitted[id] = r
		}
		for id, choice := range grant.Keychain {
			d, known := Definition(id)
			if !known || !d.Keychain {
				return errors.New("keychain_not_supported")
			}
			if choice == "allow" {
				if _, ok := admitted[id]; !ok {
					return errors.New("invalid_request")
				}
			}
		}
		for id, r := range admitted {
			d, _ := Definition(id)
			old := s.Scopes[id]
			r.Allowed, r.ConsentTextVersion, r.At = true, TextVersion, time.Now().UTC()
			r.DeniedSources = cloneRecord(old).DeniedSources
			delete(r.DeniedSources, d.Class)
			if d.Keychain {
				r.Keychain = old.Keychain
				SetKeychain(&r, grant.Keychain[id])
			}
			s.Scopes[id] = r
			// Tools retains route descriptors for legacy collectors, never scope authority.
			tool := s.Tools[d.Tool]
			tool.ReaderID, tool.Backend, tool.Region, tool.KeyEnv = r.ReaderID, r.Backend, r.Region, r.KeyEnv
			tool.Allowed, tool.ConsentTextVersion = true, TextVersion
			if d.Keychain {
				tool.Keychain, tool.DeniedSources = r.Keychain, r.DeniedSources
			}
			s.Tools[d.Tool] = tool
		}
		for _, id := range cleanup {
			s.RevokeScope(id)
			r := s.Scopes[id]
			r.Allowed, r.ConsentTextVersion, r.At = false, TextVersion, time.Now().UTC()
			if grant.Keychain[id] == "deny" {
				SetKeychain(&r, "deny")
			}
			s.Scopes[id] = r
		}
		touched := map[string]bool{}
		for id := range seen {
			tool, _, _ := strings.Cut(id, ".")
			touched[tool] = true
		}
		for tool := range touched {
			syncScopeTool(s, tool)
		}
		generation := s.Generation + 1
		result = GrantReceipt{RequestID: grant.RequestID, StoreEpoch: s.StoreEpoch, Committed: true, CommittedGeneration: &generation, Code: "ok"}
		if len(cleanup) > 0 {
			result.Code = "cleanup_pending"
			result.CleanupError = "cleanup_incomplete"
			result.CleanupPending = cleanup
		}
		encoded, _ := json.Marshal(result)
		if s.Requests == nil {
			s.Requests = map[string]Receipt{}
		}
		forgetScopes := map[string]bool{}
		for _, id := range grant.Forget {
			forgetScopes[id] = true
		}
		s.Requests[key] = Receipt{RequestHash: requestHash, Result: encoded, PendingForget: cleanup, ForgetScopes: forgetScopes}
		return nil
	}, func(s *State) error {
		if len(cleanup) == 0 {
			return ErrUnchanged
		}
		pending := []string{}
		for _, id := range cleanup {
			forget := false
			for _, f := range grant.Forget {
				forget = forget || f == id
			}
			if hooks.Cleanup == nil || hooks.Cleanup(id, forget) != nil {
				pending = append(pending, id)
			}
		}
		result.CleanupPending = pending
		result.Code = "ok"
		result.CleanupError = ""
		if len(pending) > 0 {
			result.CleanupError = "cleanup_incomplete"
			result.Code = "cleanup_pending"
		}
		encoded, _ := json.Marshal(result)
		receipt := s.Requests[key]
		receipt.Result, receipt.PendingForget = encoded, pending
		s.Requests[key] = receipt
		return nil
	})
	if err != nil {
		var committed *FinalizationError
		if errors.As(err, &committed) {
			if receipt, ok := committed.Receipt(key); ok && json.Unmarshal(receipt.Result, &result) == nil {
				return result, nil
			}
		}
		return GrantReceipt{}, err
	}
	return result, nil
}

// ScopeFacts includes persisted retired scopes so tightening remains reachable.
type ScopeFact struct {
	Disabled       *string `json:"disabledReason,omitempty"`
	Scope          string  `json:"scope"`
	Tool           string  `json:"tool"`
	Route          string  `json:"route"`
	Detected       bool    `json:"detected"`
	Retired        bool    `json:"retired"`
	State          string  `json:"state"`
	DefaultCheck   bool    `json:"defaultCheck"`
	Keychain       *string `json:"keychain"`
	CleanupPending bool    `json:"cleanupPending"`
}

func (a Admission) ScopeFacts(detected map[string]bool) []ScopeFact {
	ids := map[string]bool{}
	for _, d := range Definitions() {
		if detected[d.Tool] {
			ids[d.ID] = true
		} else if _, persisted := a.state.Tools[d.Tool]; persisted {
			ids[d.ID] = true
		}
	}
	for id := range a.state.Scopes {
		ids[id] = true
	}
	ordered := []string{}
	for id := range ids {
		ordered = append(ordered, id)
	}
	sort.Strings(ordered)
	out := []ScopeFact{}
	for _, id := range ordered {
		d, known := Definition(id)
		if !known {
			d.Tool, _, _ = strings.Cut(id, ".")
		}
		fact := ScopeFact{Scope: id, Tool: d.Tool, Route: d.Route, Detected: detected[d.Tool], Retired: !known, State: "unset", DefaultCheck: d.DefaultCheck, CleanupPending: a.cleanup[id]}
		if d.Keychain {
			v := "unset"
			fact.Keychain = &v
		}
		if r, ok := a.state.Scopes[id]; ok {
			fact.State = "denied"
			if r.Allowed {
				fact.State = "allowed"
			}
			if d.Keychain {
				v := r.Keychain
				if v == "" {
					v = "unset"
				}
				fact.Keychain = &v
			}
		}
		out = append(out, fact)
	}
	return out
}

// ReceiptKey is the persistent idempotency identity, including the reset epoch.
func ReceiptKey(epoch, requestID string) string { return epoch + "/" + requestID }

func syncScopeTool(s *State, tool string) {
	record := s.Tools[tool]
	record.Allowed = false
	record.ConsentTextVersion = TextVersion
	// Prefer an explicitly configured key when both key and saved-login scopes
	// are granted. Local scope metadata never changes an account reader's route.
	for _, class := range []string{Local, Runtime, Credential, ExplicitKey} {
		for _, d := range Definitions() {
			r, ok := s.Scopes[d.ID]
			if ok && d.Tool == tool && d.Class == class && r.Allowed {
				record = r
				record.Allowed = true
			}
		}
	}
	if r, ok := s.Scopes[ScopeClaudeAccountUsageSavedLogin]; tool == "claude" && ok {
		record.Keychain = r.Keychain
		record.DeniedSources = cloneRecord(r).DeniedSources
	}
	s.Tools[tool] = record
}
