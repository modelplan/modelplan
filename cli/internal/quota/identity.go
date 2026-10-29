package quota

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Subscriptions are known by random local references. When a reader sees which account a meter
// belongs to (Codex's account reading, Claude Code's own account metadata, CodexBar's account id,
// the API key of a native reader), the collecting run maps a keyed hash of that identity to a
// reference in <cache>/observed/subscriptions.json, made at random the first time. The identity
// itself is never stored, and the hash never leaves that file: the snapshot and the ledgers carry
// only the reference, which says nothing about the account. Reading never writes: a read-only run
// shows only references made before.

// Binding: which subscription an account's meters belong to. Status is verified: the reader saw
// the account. Basis names how: codex-account, claude-config, codexbar or api-key.
type Binding struct {
	Ref        string    `json:"subscriptionRef"`
	Status     string    `json:"status"`
	Basis      string    `json:"basis"`
	ObservedAt time.Time `json:"observedAt"`
}

const maxSubscriptions = 200

type subscriptionMap struct {
	SchemaVersion int                         `json:"schemaVersion"`
	Key           string                      `json:"key"`
	Refs          map[string]subscriptionItem `json:"refs"` // keyed hash of basis and identity
}

type subscriptionItem struct {
	Ref    string    `json:"ref"`
	Basis  string    `json:"basis"`
	LastAt time.Time `json:"lastAt"`
}

func subscriptionsPath(cache string) string {
	return filepath.Join(cache, "observed", "subscriptions.json")
}

// assignSubscription: the reference for an identity seen by basis, made the first time. "" when
// the identity is empty or the map cannot be read or written (it is then left as it is).
func assignSubscription(cache, basis, identity string, now time.Time) string {
	identity = strings.TrimSpace(identity)
	if cache == "" || identity == "" {
		return ""
	}
	unlock, ok := lockFile(filepath.Join(cache, "observed", "subscriptions.lock"), now, 10*time.Second)
	if !ok {
		return ""
	}
	defer unlock()
	m := subscriptionMap{SchemaVersion: 1, Refs: map[string]subscriptionItem{}}
	b, status := readBounded(subscriptionsPath(cache), 256<<10)
	switch status {
	case "":
		if json.Unmarshal(b, &m) != nil || m.SchemaVersion != 1 || m.Refs == nil {
			return "" // not ours to replace: every reference would change
		}
	case "missing":
	default:
		return ""
	}
	key, err := hex.DecodeString(m.Key)
	if err != nil || len(key) != 32 {
		if len(m.Refs) > 0 {
			return ""
		}
		key = randomBytes(32)
		if key == nil {
			return ""
		}
		m.Key = hex.EncodeToString(key)
	}
	h := hmac.New(sha256.New, key)
	h.Write([]byte(basis + "\x00" + identity))
	id := hex.EncodeToString(h.Sum(nil))
	it, seen := m.Refs[id]
	if !seen {
		r := randomBytes(8)
		if r == nil {
			return ""
		}
		it = subscriptionItem{Ref: hex.EncodeToString(r), Basis: basis}
	}
	if seen && now.Sub(it.LastAt) < time.Hour {
		return it.Ref // fresh enough; no write
	}
	it.LastAt = now.UTC().Truncate(time.Minute)
	m.Refs[id] = it
	for len(m.Refs) > maxSubscriptions { // the one seen longest ago goes first
		var oldest string
		for k, v := range m.Refs {
			if oldest == "" || v.LastAt.Before(m.Refs[oldest].LastAt) {
				oldest = k
			}
		}
		delete(m.Refs, oldest)
	}
	out, _ := json.MarshalIndent(m, "", "  ")
	if os.MkdirAll(filepath.Dir(subscriptionsPath(cache)), 0o700) != nil || writeAtomic(subscriptionsPath(cache), append(out, '\n')) != nil {
		return ""
	}
	return it.Ref
}

func randomBytes(n int) []byte {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return nil
	}
	return b
}

// IdentityOff: MODELPLAN_IDENTITY=off stops reading account identities; no reference is made or
// shown.
func IdentityOff() bool {
	v := strings.ToLower(os.Getenv("MODELPLAN_IDENTITY"))
	return v == "off" || v == "0" || v == "false"
}

// claudeIdentity: the previous snapshot's identity while the config file is unchanged, else the
// account read again from it. Nil when off, unreadable or signed out.
func claudeIdentity(cache string, prev *ccSnapshot, now time.Time) *ccIdentity {
	if IdentityOff() {
		return nil
	}
	home, _ := os.UserHomeDir()
	file := ClaudeConfigFile(home)
	fi, err := os.Stat(file)
	if err != nil {
		return nil
	}
	if prev != nil && prev.Identity != nil && prev.Identity.FileSize == fi.Size() && prev.Identity.FileTime.Equal(fi.ModTime().UTC()) {
		return prev.Identity
	}
	id, err := claudeAccount(file)
	if err != nil {
		return nil
	}
	ref := assignSubscription(cache, "claude-config", id, now)
	if ref == "" {
		return nil
	}
	return &ccIdentity{Ref: ref, FileSize: fi.Size(), FileTime: fi.ModTime().UTC(), ObservedAt: now.UTC().Truncate(time.Second)}
}

// CodexSubscription: the reference of the account in the recent Codex account reading, "" when
// unknown. ClaudeSubscription: the one the status line recorded for Claude Code.
func CodexSubscription(cache string, now time.Time) string {
	s := loadAccount(cache)
	if s == nil || s.Status != "ok" || now.Sub(s.ObservedAt) > accountKeep || IdentityOff() {
		return ""
	}
	return s.SubscriptionRef
}

func ClaudeSubscription(cache string) string {
	b, status := readBounded(snapshotPath(cache), 64<<10)
	var s ccSnapshot
	if status != "" || json.Unmarshal(b, &s) != nil || s.Identity == nil || IdentityOff() {
		return ""
	}
	return s.Identity.Ref
}

// ---- Claude Code: the account metadata Claude Code keeps beside its settings. Only
// oauthAccount.accountUuid and organizationUuid are read, never the e-mail, names or any token
// (tokens are not in this file); the owner agreed to this on 2026-10-22.

// ClaudeConfigFile: $CLAUDE_CONFIG_DIR/.claude.json, else ~/.claude.json.
func ClaudeConfigFile(home string) string {
	if d := os.Getenv("CLAUDE_CONFIG_DIR"); d != "" && filepath.IsAbs(d) {
		return filepath.Join(d, ".claude.json")
	}
	return filepath.Join(home, ".claude.json")
}

const maxClaudeConfig = 64 << 20

// claudeAccount reads the account and organization ids from the file, decoding nothing else
// into memory.
func claudeAccount(file string) (string, error) {
	fi, err := os.Lstat(file)
	if err != nil {
		return "", err
	}
	if !fi.Mode().IsRegular() || fi.Size() > maxClaudeConfig {
		return "", errors.New("not a regular file of a usable size")
	}
	f, err := os.Open(file)
	if err != nil {
		return "", err
	}
	defer f.Close()
	d := json.NewDecoder(io.LimitReader(f, maxClaudeConfig))
	if t, err := d.Token(); err != nil || t != json.Delim('{') {
		return "", errors.New("not a JSON object")
	}
	for d.More() {
		t, err := d.Token()
		if err != nil {
			return "", err
		}
		if k, _ := t.(string); k == "oauthAccount" {
			var a struct {
				Account string `json:"accountUuid"`
				Org     string `json:"organizationUuid"`
			}
			if err := d.Decode(&a); err != nil || a.Account == "" {
				return "", errors.New("no account")
			}
			return a.Account + "/" + a.Org, nil
		}
		var skip json.RawMessage
		if err := d.Decode(&skip); err != nil {
			return "", err
		}
	}
	return "", errors.New("no account")
}

// lookupSubscription checks a cached binding without creating or updating it.
func lookupSubscription(cache, basis, identity string) string {
	b, status := readBounded(subscriptionsPath(cache), 256<<10)
	var m subscriptionMap
	if status != "" || json.Unmarshal(b, &m) != nil || m.SchemaVersion != 1 {
		return ""
	}
	key, err := hex.DecodeString(m.Key)
	if err != nil || len(key) != 32 || strings.TrimSpace(identity) == "" {
		return ""
	}
	h := hmac.New(sha256.New, key)
	h.Write([]byte(basis + "\x00" + strings.TrimSpace(identity)))
	return m.Refs[hex.EncodeToString(h.Sum(nil))].Ref
}

// lookupReaderHash uses the existing installation key without creating a key,
// reference, lock or directory. Profile matching in read-only commands must not
// call readerHash, which initializes the identity store during collection.
func lookupReaderHash(cache, domain, value string) string {
	if cache == "" || value == "" {
		return ""
	}
	b, status := readBounded(subscriptionsPath(cache), 256<<10)
	var m subscriptionMap
	if status != "" || json.Unmarshal(b, &m) != nil || m.SchemaVersion != 1 {
		return ""
	}
	key, err := hex.DecodeString(m.Key)
	if err != nil || len(key) != 32 {
		return ""
	}
	h := hmac.New(sha256.New, key)
	_, _ = h.Write([]byte("reader:" + domain + "\x00" + value))
	return hex.EncodeToString(h.Sum(nil))
}

// readerProfileLocator returns only a reference already bound to this exact
// profile in the existing identity store. Profile hashes never leave the cache.
func readerProfileLocator(cache, provider, profileKey string) string {
	if IdentityOff() || profileKey == "" {
		return ""
	}
	basis := readerProfileBasis(provider)
	b, status := readBounded(subscriptionsPath(cache), 256<<10)
	var m subscriptionMap
	if status != "" || json.Unmarshal(b, &m) != nil || m.SchemaVersion != 1 {
		return ""
	}
	key, err := hex.DecodeString(m.Key)
	if err != nil || len(key) != 32 {
		return ""
	}
	h := hmac.New(sha256.New, key)
	_, _ = h.Write([]byte(basis + "\x00" + profileKey))
	item, ok := m.Refs[hex.EncodeToString(h.Sum(nil))]
	if !ok || item.Basis != basis {
		return ""
	}
	ref := item.Ref
	// Syntax is supplementary to the exact identity-store membership above;
	// a profile hash is never a reference.
	raw, err := hex.DecodeString(ref)
	if err != nil || len(raw) != 8 || hex.EncodeToString(raw) != ref {
		return ""
	}
	return ref
}

// existingReaderSubscription verifies provenance in the local reference table;
// accepting an arbitrary hex string from a reading is not a privacy boundary.
func existingReaderSubscription(cache, provider string, binding *Binding) string {
	if IdentityOff() || binding == nil || binding.Status != "verified" {
		return ""
	}
	// Gemini's verified Binding and identity store intentionally use different
	// existing vocabularies. Validate both independently; changing either one
	// would alter legacy quota output or lose the already allocated reference.
	bases := map[string]struct{ binding, stored string }{
		"claude": {"claude-oauth", "claude-oauth"},
		"cursor": {"cursor-auth", "cursor-auth"},
		"gemini": {"gemini-cli-local-account-project", "gemini-cli-account-project"},
		"grok":   {"grok-auth-principal", "grok-auth-principal"},
		"kimi":   {"kimi-code-login:china", "kimi-code-login:china"},
	}[provider]
	if bases.binding == "" || binding.Basis != bases.binding {
		return ""
	}
	b, status := readBounded(subscriptionsPath(cache), 256<<10)
	var m subscriptionMap
	if status != "" || json.Unmarshal(b, &m) != nil || m.SchemaVersion != 1 {
		return ""
	}
	key, err := hex.DecodeString(m.Key)
	if err != nil || len(key) != 32 {
		return ""
	}
	raw, err := hex.DecodeString(binding.Ref)
	if err != nil || len(raw) != 8 || hex.EncodeToString(raw) != binding.Ref {
		return ""
	}
	for _, item := range m.Refs {
		if item.Ref == binding.Ref && item.Basis == bases.stored {
			return binding.Ref
		}
	}
	return ""
}
