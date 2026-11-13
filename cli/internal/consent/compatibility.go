// SPDX-License-Identifier: MIT
package consent

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
)

// These are inert metadata to schema-v1 readers: only "keychain" is an access
// class. Old writers preserve all DeniedSources entries, so the restriction and
// its recorded choice survive even when they drop Record.Keychain.
const keychainUnset = "consent-api/keychain/unset"
const keychainAllowed = "consent-api/keychain/allowed"

const ClaudeKeychainUnsetNotice = "Claude Code Keychain permission is unset"
const ClaudeKeychainNextStep = "Allow Keychain for Claude Code in Settings"

// KeychainSupported names the native route which actually uses Keychain. The
// standard helper always disables it, including when its provider is Claude.
func KeychainSupported(tool, backend, reader string) bool {
	return tool == "claude" && backend == "native" && (reader == "native:claude" || reader == "native:claude-code")
}

// KeychainStatus is the shared consent policy for API readback and production
// admission. Legacy connect grants include Keychain permission implicitly; API
// grants distinguish unset from Deny. Mode restrictions still win, and unused
// Keychain fields on other tools never describe a permission the reader uses.
func (s State) KeychainStatus(tool, mode string) string {
	status := s.keychainStatus(tool)
	if status == "allowed" && !s.Allows(tool, "keychain", mode) {
		return "denied"
	}
	return status
}

func (s State) keychainStatus(tool string) string {
	r, exists := s.Tools[tool]
	if !exists || !KeychainSupported(tool, r.Backend, r.ReaderID) || r.BrowserSession || r.KeyEnv != "" {
		return "unset"
	}
	r.restoreKeychain()
	if r.Keychain == "unset" || r.Keychain == "denied" {
		return r.Keychain
	}
	if !r.Allowed || r.ConsentTextVersion != TextVersion {
		return "unset"
	}
	if r.DeniedSources[Credential] {
		return "denied"
	}
	return "allowed"
}

func (r *Record) restoreKeychain() {
	switch {
	case r.DeniedSources[keychainUnset] && r.DeniedSources["keychain"]:
		r.Keychain = "unset"
	case r.DeniedSources["keychain"]:
		r.Keychain = "denied"
	case r.DeniedSources[keychainAllowed]:
		r.Keychain = "allowed"
	}
}

// SetKeychain records API choices using the source veto understood by every
// supported CLI copy. An explicit allow can resolve the API's initial unset
// choice, but cannot clear a persisted user/OS Deny.
func SetKeychain(r *Record, choice string) {
	r.restoreKeychain()
	if r.DeniedSources == nil {
		r.DeniedSources = map[string]bool{}
	}
	switch choice {
	case "allow":
		if r.DeniedSources[keychainUnset] {
			delete(r.DeniedSources, "keychain")
			delete(r.DeniedSources, keychainUnset)
		}
		r.Keychain = "allowed"
		r.DeniedSources[keychainAllowed] = true
	case "deny":
		r.Keychain = "denied"
		delete(r.DeniedSources, keychainUnset)
		delete(r.DeniedSources, keychainAllowed)
	case "":
		if r.Keychain == "" {
			r.Keychain = "unset"
		}
	}
	if r.Keychain == "unset" {
		r.DeniedSources[keychainUnset] = true
	}
	if r.Keychain == "unset" || r.Keychain == "denied" {
		r.DeniedSources["keychain"] = true
	}
	r.restoreKeychain()
}

// Schema-1 receipt encoding is migration input only. Schema 2 stores explicit
// epoch/request-id keys; older writers reject the entire store.
const receiptPrefix = "consent-api/receipt/v1/"

func loadReceipts(s *State, raw []byte) error {
	// Migrate the pre-release API format when it has not met an older writer.
	var previous struct {
		Requests map[string]Receipt `json:"requests"`
	}
	if json.Unmarshal(raw, &previous) != nil {
		return errors.New("invalid consent receipts")
	}
	s.Requests = previous.Requests
	if s.Requests == nil {
		s.Requests = map[string]Receipt{}
	}
	seen := map[string]bool{}
	for key, value := range s.Hinted {
		if !strings.HasPrefix(key, receiptPrefix) {
			continue
		}
		id, encoded, ok := strings.Cut(strings.TrimPrefix(key, receiptPrefix), "/")
		var receipt Receipt
		b, err := base64.RawURLEncoding.DecodeString(encoded)
		if !value || !ok || id == "" || seen[id] || err != nil || json.Unmarshal(b, &receipt) != nil || len(receipt.RequestHash) != 64 || !json.Valid(receipt.Result) {
			return errors.New("invalid consent receipts")
		}
		seen[id] = true
		s.Requests[id] = receipt
	}
	for id, receipt := range s.Requests {
		if len(receipt.RequestHash) != 64 || !json.Valid(receipt.Result) {
			return errors.New("invalid consent receipts")
		}
		if s.SchemaVersion == 2 {
			epoch, requestID, ok := strings.Cut(id, "/")
			if !ok || epoch != s.StoreEpoch || requestID == "" {
				return errors.New("invalid consent receipt epoch")
			}
		}
	}
	return nil
}

func storeReceipts(s *State) error {
	// Copy the map: finalization must replace the first receipt, and callers'
	// in-memory Hinted map must not accumulate stale copies of the same ID.
	hinted := map[string]bool{}
	for key, value := range s.Hinted {
		if !strings.HasPrefix(key, receiptPrefix) {
			hinted[key] = value
		}
	}
	s.Hinted = hinted
	return nil
}
