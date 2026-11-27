// SPDX-License-Identifier: MIT
package quota

import (
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/detect"
)

// ZCode sign-in generation (owner build-6 #1, review macrev2-1284-1/-2/-4).
//
// Invariant: a retained ZCode reading is dropped only when the signed-in account changes.
//
// The account is decided the way Token Monitor decides it (zcodeDiscovery.js storedProfileIdentity
// and the credential it then selects; limits.js keys an account by its credential, here by the
// JWT's subject instead so the token itself never enters anything): the selected family and
// provider entry, the stored profile's identity, a Start Plan JWT's subject, and the plaintext
// mirror only where the read itself would use it. Nothing else counts: not telemetry-state.json,
// not modification times, not other provider entries, not a reseal of the same value with a new
// nonce, not a refreshed token with the same subject.
//
// A 3.11-3.18 (enc:v1) store opens with ZCode's machine secret, so the identity is resolved here,
// in memory. A 3.19+ Keychain-bound (enc:v2:os) store opens only inside a read; that read records
// which sealed values named which account (zcodeRememberSeal), and the projection looks them up.
// Sealed values the projection has not seen resolved are "unresolved": the previous reading is
// held back (never shown for a possibly different account) until the next read settles it.
//
// Everything persisted or emitted is an HMAC under the installation key (readerHash). When that key
// is not available yet the stamp is "" and the route is skipped for this projection (never an
// unkeyed digest, never memoized). A file that exists but cannot be read or parsed (ZCode writing
// it) keeps the last stamp.

// zcodeStampFiles decide the selected account. telemetry-state.json is deliberately absent.
var zcodeStampFiles = []string{"setting.json", "config.json", "credentials.json"}

const zcodeUnresolved = "unresolved:"

type zcodeStampMemoEntry struct{ meta, stamp, seal string }

// zcodeStampMemo: per cache and folder, the last stamp and the file metadata it was computed for.
var zcodeStampMemo sync.Map

// zcodeLoginStamp is the account part of the sign-in route's generation; "" when it cannot be
// keyed now.
func zcodeLoginStamp(cache, dir string) string {
	stamp, _ := zcodeLoginStampSeal(cache, dir)
	return stamp
}

// zcodeLoginStampSeal also returns the keyed seal: the stored values as they are, which a read in
// flight checks to know that nothing it opened was replaced meanwhile.
func zcodeLoginStampSeal(cache, dir string) (stamp, seal string) {
	meta := zcodeLoginMeta(dir)
	key := cache + "\x00" + dir
	var last zcodeStampMemoEntry
	if m, ok := zcodeStampMemo.Load(key); ok {
		last = m.(zcodeStampMemoEntry)
		if last.meta == meta {
			return last.stamp, last.seal
		}
	}
	in, transient := zcodeStampInputs(dir)
	if transient {
		if last.stamp == "" {
			last.stamp = zcodeLastStamp(cache)
		}
		// Mid-write: keep the last stamp; do not memoize, the next projection looks again.
		return last.stamp, "transient"
	}
	seal = zcodeKeyed(cache, "zcode-login-seal", in.sealKey())
	if seal == "" {
		return "", ""
	}
	switch {
	case in.material != "":
		stamp = zcodeKeyed(cache, "zcode-login-stamp", in.material)
	default:
		stamp = zcodeSealStamp(cache, seal)
		if stamp == "" {
			stamp = zcodeUnresolved + seal
		}
	}
	if stamp == "" {
		return "", ""
	}
	zcodeStampMemo.Store(key, zcodeStampMemoEntry{meta: meta, stamp: stamp, seal: seal})
	if !strings.HasPrefix(stamp, zcodeUnresolved) {
		zcodeSaveLastStamp(cache, stamp)
	}
	return stamp, seal
}

// zcodeLoginMeta: size, modification time and mode of the files the stamp reads; a cache key only.
func zcodeLoginMeta(dir string) string {
	var meta strings.Builder
	for _, name := range zcodeStampFiles {
		if fi, err := os.Lstat(filepath.Join(dir, name)); err == nil {
			meta.WriteString(strconv.FormatInt(fi.Size(), 10) + "." + strconv.FormatInt(fi.ModTime().UnixNano(), 10) + "." + strconv.FormatUint(uint64(fi.Mode()), 10))
		}
		meta.WriteByte(':')
	}
	meta.WriteString(strconv.FormatBool(detect.ZCodeKeychainMarkerPresent(dir)))
	return meta.String()
}

// zcodeStampInput holds, in memory only, what decides the account. material is set when the account
// is resolved (or the folder names no account); otherwise only the sealed values are known.
type zcodeStampInput struct {
	state    string // the selection's own refusal, or a missing file
	sel      zcodeSelected
	format   string
	sealed   [2]string // the stored profile and the Start Plan JWT, still sealed
	material string
}

func (in zcodeStampInput) sealKey() string {
	b, _ := json.Marshal(map[string]any{"state": in.state, "family": in.sel.family, "provider": in.sel.providerID, "kind": in.sel.kind,
		"mirror": in.sel.provider.Options.APIKey, "format": in.format, "sealed": in.sealed})
	return string(b)
}

// zcodeStampInputs reads the three files. transient: one exists but cannot be read or parsed.
func zcodeStampInputs(dir string) (zcodeStampInput, bool) {
	var in zcodeStampInput
	read := func(name string, into any) (present, transient bool) {
		b, err := zcodeLoginRead(filepath.Join(dir, name))
		if err != nil {
			if errorCode(err) == "file_missing" {
				return false, false
			}
			return false, true
		}
		if json.Unmarshal(b, into) != nil {
			return false, true
		}
		return true, false
	}
	var settings zcodeSettings
	var registry struct {
		Provider map[string]zcodeProvider `json:"provider"`
	}
	var store map[string]any
	for _, f := range []struct {
		name string
		into any
	}{{"setting.json", &settings}, {"config.json", &registry}, {"credentials.json", &store}} {
		present, transient := read(f.name, f.into)
		if transient {
			return in, true
		}
		if !present && f.name != "credentials.json" {
			in.state = "missing:" + f.name
		}
	}
	if in.state == "" {
		in.sel, in.state = zcodeSelect(settings, registry.Provider)
	}
	if in.state != "" {
		in.material = zcodeMaterial(map[string]any{"state": in.state})
		return in, false
	}
	in.format = zcodeStoreFormat(detect.ZCodeKeychainMarkerPresent(dir), store)
	in.sealed[0], _ = store["oauth:"+in.sel.family+":user_info"].(string)
	in.sealed[1], _ = store["zcodejwttoken"].(string)
	switch in.format {
	case "unsupported":
		in.material = zcodeMaterial(map[string]any{"state": "unsupported_login"})
	case "os":
		// Opens only inside a read (Keychain); resolved through zcodeRememberSeal.
	default:
		secret := zcodeCredentialSecret()
		in.material = zcodeAccountMaterial(in.sel, in.format, store, func(v string) string { return zcodeDecrypt(v, secret) })
	}
	return in, false
}

// zcodeAccountMaterial names the account the read would use, in memory only. It follows
// readZCodeLogin's choice of credential, without its time checks.
func zcodeAccountMaterial(sel zcodeSelected, format string, store map[string]any, open func(string) string) string {
	identity := ""
	if store != nil {
		identity = zcodeIdentity(store, open, sel.family)
	}
	mirror := strings.TrimSpace(sel.provider.Options.APIKey)
	subject, useMirror := "", false
	if sel.start {
		raw, _ := store["zcodejwttoken"].(string)
		token := open(raw)
		subject = zcodeJWTSubject(token)
		useMirror = token == "" && identity == "" && format != "os"
	} else {
		useMirror = identity == "" && format != "os"
	}
	if !useMirror {
		mirror = ""
	}
	return zcodeMaterial(map[string]any{"family": sel.family, "provider": sel.providerID, "kind": sel.kind,
		"identity": identity, "subject": subject, "mirror": mirror})
}

func zcodeMaterial(v map[string]any) string {
	b, _ := json.Marshal(v) // map keys sort: equal content, equal bytes
	return string(b)
}

// zcodeJWTSubject: the token's sub claim, "" when it is not a JWT or has none. Only the subject is
// used; the token is never hashed or kept.
func zcodeJWTSubject(token string) string {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return ""
	}
	payload, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(parts[1], "="))
	if err != nil {
		return ""
	}
	var claims struct {
		Sub any `json:"sub"`
	}
	if json.Unmarshal(payload, &claims) != nil {
		return ""
	}
	switch v := claims.Sub.(type) {
	case string:
		return strings.TrimSpace(v)
	case float64:
		return strconv.FormatFloat(v, 'f', -1, 64)
	}
	return ""
}

// zcodeKeyed is readerHash, given a moment if the installation key is being created; "" otherwise.
var zcodeKeyed = func(cache, domain, value string) string {
	for i := 0; i < 5; i++ {
		if h := readerHash(cache, domain, value); h != "" || cache == "" {
			return h
		}
		time.Sleep(40 * time.Millisecond)
	}
	return ""
}

// ---- Seals a read resolved, and the last stamp (observed/zcode-login.json; keyed hashes only).

type zcodeStampFile struct {
	Seals []struct{ Seal, Stamp string } `json:"seals"`
	Last  string                         `json:"last,omitempty"`
}

const zcodeSealsKept = 8

var zcodeStampFileMu sync.Mutex

func zcodeStampPath(cache string) string { return filepath.Join(cache, "observed", "zcode-login.json") }

func loadZCodeStampFile(cache string) zcodeStampFile {
	var f zcodeStampFile
	if b, status := readBounded(zcodeStampPath(cache), 64<<10); status == "" {
		_ = json.Unmarshal(b, &f)
	}
	return f
}

func saveZCodeStampFile(cache string, f zcodeStampFile) {
	b, _ := json.Marshal(f)
	_ = writeAtomic(zcodeStampPath(cache), append(b, '\n'))
}

func zcodeSealStamp(cache, seal string) string {
	for _, s := range loadZCodeStampFile(cache).Seals {
		if s.Seal == seal {
			return s.Stamp
		}
	}
	return ""
}

func zcodeLastStamp(cache string) string { return loadZCodeStampFile(cache).Last }

func zcodeSaveLastStamp(cache, stamp string) {
	if cache == "" {
		return
	}
	zcodeStampFileMu.Lock()
	defer zcodeStampFileMu.Unlock()
	f := loadZCodeStampFile(cache)
	if f.Last == stamp {
		return // unchanged: no write, so no watcher wake-up (G3-147)
	}
	f.Last = stamp
	saveZCodeStampFile(cache, f)
}

// zcodeRememberSeal records, after a read opened the store, which account its sealed values name.
// The projection then resolves the same sealed values to the same stamp without opening anything.
func zcodeRememberSeal(cache, dir string, sel zcodeSelected, format string, store map[string]any, material string) {
	if cache == "" {
		return
	}
	in := zcodeStampInput{sel: sel, format: format}
	in.sealed[0], _ = store["oauth:"+sel.family+":user_info"].(string)
	in.sealed[1], _ = store["zcodejwttoken"].(string)
	seal := zcodeKeyed(cache, "zcode-login-seal", in.sealKey())
	stamp := zcodeKeyed(cache, "zcode-login-stamp", material)
	if seal == "" || stamp == "" {
		return
	}
	zcodeStampFileMu.Lock()
	f := loadZCodeStampFile(cache)
	kept := f.Seals[:0]
	for _, s := range f.Seals {
		if s.Seal != seal {
			kept = append(kept, s)
		}
	}
	f.Seals = append(kept, struct{ Seal, Stamp string }{seal, stamp})
	if len(f.Seals) > zcodeSealsKept {
		f.Seals = f.Seals[len(f.Seals)-zcodeSealsKept:]
	}
	f.Last = stamp
	saveZCodeStampFile(cache, f)
	zcodeStampFileMu.Unlock()
	zcodeStampMemo.Delete(cache + "\x00" + dir)
}
