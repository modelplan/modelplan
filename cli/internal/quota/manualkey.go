// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Manual key (owner decision D90, 2026-11-09). A key the user pastes for a key-only provider is
// kept in one 0600 JSON file in the app support directory, one entry per provider. It is the
// first source for that provider; auto-detected sources follow. The key is sent only to the
// compiled official host of the chosen region (zaiHosts, opencodegoHosts), never to a host taken
// from a tool's configuration. It never appears in a log, row, diagnostic or error: every
// function here returns fixed outcome words, not the key or any text that could contain it.

const manualKeyFileName = "reader-keys-v1.json"

// ManualKeyRegions: the region names the user sees (Global / China) and the compiled reader
// region each one selects.
var manualKeyRegions = map[string]string{"global": "global", "china": "bigmodel-cn"}

// manualKeyProviders: providers that take a pasted key, and whether they have a region choice.
var manualKeyProviders = map[string]bool{"zai": true, "opencodego": false}

// ManualKey is one stored entry. Region is "global" or "china" (zai only).
type ManualKey struct {
	Key    string `json:"key"`
	Region string `json:"region,omitempty"`
}

type manualKeyFile struct {
	SchemaVersion int                  `json:"schemaVersion"`
	Providers     map[string]ManualKey `json:"providers"`
}

// ManualKeyPath is the file; the caller passes the app support directory.
func ManualKeyPath(dir string) string { return filepath.Join(dir, manualKeyFileName) }

// ManualKeyProvider reports whether provider accepts a pasted key.
func ManualKeyProvider(provider string) bool { _, ok := manualKeyProviders[provider]; return ok }

func validManualKey(key string) bool {
	if key == "" || len(key) > 4096 {
		return false
	}
	for _, r := range key {
		if r <= 0x20 || r >= 0x7f {
			return false
		}
	}
	return true
}

// normalizeManualKey trims surrounding space (a paste usually brings a newline) and applies the
// provider's region rule. ok is false for an unusable key or region.
func normalizeManualKey(provider, key, region string) (ManualKey, bool) {
	haveRegion, known := manualKeyProviders[provider]
	key = strings.TrimSpace(key)
	if !known || !validManualKey(key) {
		return ManualKey{}, false
	}
	if !haveRegion {
		return ManualKey{Key: key}, true
	}
	if region == "" {
		region = "global"
	}
	if _, ok := manualKeyRegions[region]; !ok {
		return ManualKey{}, false
	}
	return ManualKey{Key: key, Region: region}, true
}

// loadManualKeys reads the file. A missing file is no keys. A file that other users can read or
// write, or one that is not a plain file, is refused (fail closed) and reported as unreadable.
func loadManualKeys(dir string) (map[string]ManualKey, error) {
	if dir == "" {
		return nil, nil
	}
	path := ManualKeyPath(dir)
	info, err := os.Lstat(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil || !info.Mode().IsRegular() || info.Mode().Perm()&0o077 != 0 {
		return nil, errors.New("manual key file unreadable")
	}
	b, status := readBounded(path, 64<<10)
	if status != "" {
		return nil, errors.New("manual key file unreadable")
	}
	var f manualKeyFile
	if json.Unmarshal(b, &f) != nil || f.SchemaVersion != 1 {
		return nil, errors.New("manual key file unreadable")
	}
	out := map[string]ManualKey{}
	for provider, entry := range f.Providers {
		if k, ok := normalizeManualKey(provider, entry.Key, entry.Region); ok {
			out[provider] = k
		}
	}
	return out, nil
}

// loadManualKey: the stored key for provider, if there is a usable one.
func loadManualKey(dir, provider string) (ManualKey, bool) {
	keys, err := loadManualKeys(dir)
	if err != nil {
		return ManualKey{}, false
	}
	k, ok := keys[provider]
	return k, ok
}

// ManualKeyPresent: whether a key is stored for provider. It never returns the key.
func ManualKeyPresent(dir, provider string) bool {
	_, ok := loadManualKey(dir, provider)
	return ok
}

// ManualKeyRegion: the stored region name ("global" or "china") for provider, "" when none.
func ManualKeyRegion(dir, provider string) string {
	k, _ := loadManualKey(dir, provider)
	return k.Region
}

// writeManualKeys replaces the file atomically with mode 0600 in a 0700 directory. An empty set
// removes the file.
func writeManualKeys(dir string, keys map[string]ManualKey) error {
	if len(keys) == 0 {
		if err := os.Remove(ManualKeyPath(dir)); err != nil && !errors.Is(err, os.ErrNotExist) {
			return errors.New("manual key file not written")
		}
		return nil
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return errors.New("manual key file not written")
	}
	b, err := json.Marshal(manualKeyFile{SchemaVersion: 1, Providers: keys})
	if err != nil {
		return errors.New("manual key file not written")
	}
	f, err := os.CreateTemp(dir, ".keys-*")
	if err != nil {
		return errors.New("manual key file not written")
	}
	tmp := f.Name()
	fail := func() error {
		f.Close()
		os.Remove(tmp)
		return errors.New("manual key file not written")
	}
	if err := f.Chmod(0o600); err != nil {
		return fail()
	}
	if _, err := f.Write(append(b, '\n')); err != nil {
		return fail()
	}
	if err := f.Sync(); err != nil {
		return fail()
	}
	if err := f.Close(); err != nil {
		os.Remove(tmp)
		return errors.New("manual key file not written")
	}
	if err := os.Rename(tmp, ManualKeyPath(dir)); err != nil {
		os.Remove(tmp)
		return errors.New("manual key file not written")
	}
	return nil
}

// SetManualKey stores (replaces) the key for provider. The error never contains the key.
func SetManualKey(dir, provider, key, region string) error {
	k, ok := normalizeManualKey(provider, key, region)
	if !ok {
		return errors.New("manual key not accepted")
	}
	keys, err := loadManualKeys(dir)
	if err != nil {
		// An unreadable or unsafe file is replaced, not trusted: it may hold other providers'
		// keys, but a file other users could write cannot be relied on.
		keys = nil
	}
	if keys == nil {
		keys = map[string]ManualKey{}
	}
	keys[provider] = k
	return writeManualKeys(dir, keys)
}

// RemoveManualKey deletes the key for provider; removing an absent key succeeds.
func RemoveManualKey(dir, provider string) error {
	if !ManualKeyProvider(provider) {
		return errors.New("manual key not accepted")
	}
	keys, err := loadManualKeys(dir)
	if err != nil {
		keys = nil
	}
	if _, ok := keys[provider]; !ok && err == nil {
		return nil
	}
	delete(keys, provider)
	return writeManualKeys(dir, keys)
}

// Outcomes of a manual key test. Fixed words only.
const (
	ManualKeyOK             = "ok"
	ManualKeyRefused        = "key_refused" // the host does not accept this key (wrong key or wrong region)
	ManualKeyPlanLapsed     = "plan_lapsed" // the key is good but the account has no active plan
	ManualKeyNoKey          = "no_key"
	ManualKeyUnreachable    = "unreachable"
	ManualKeyFailed         = "failed"
	ManualKeyNotAccepted    = "not_accepted" // the text cannot be a key, or the provider/region is unknown
	manualKeyPlanLapsedText = "plan_lapsed"
)

// fetchManualKey reads quota with a stored key, through the same official-host fetchers the
// other sources use. The host comes from the compiled region table alone.
func fetchManualKey(ctx context.Context, c *http.Client, provider string, k ManualKey, now time.Time) codexbarEntry {
	switch provider {
	case "zai":
		return fetchZai(ctx, c, manualKeyRegions[k.Region], k.Key, now)
	case "opencodego":
		return fetchOpenCodeGo(ctx, c, "global", k.Key, now)
	}
	return codexbarEntry{Status: "error", ErrorCode: "other", ObservedAt: now.UTC()}
}

// manualKeyOutcome turns a reader entry into one outcome word.
func manualKeyOutcome(provider string, e codexbarEntry) string {
	if e.Status == "ok" {
		return ManualKeyOK
	}
	switch {
	case e.Error == manualKeyPlanLapsedText:
		return ManualKeyPlanLapsed
	case e.ErrorCode == "http_401":
		return ManualKeyRefused
	case e.ErrorCode == "http_403":
		// z.ai answers a lapsed plan with a body code (handled above) and a refused key with 401;
		// OpenCode Go answers a good key whose workspace has no Go plan with 403.
		return ManualKeyPlanLapsed
	case e.ErrorCode == "no_key":
		return ManualKeyNoKey
	case e.ErrorCode == "network" || e.ErrorCode == "timeout":
		return ManualKeyUnreachable
	}
	return ManualKeyFailed
}

// TestManualKey asks the official host once with the candidate key, without storing it.
func TestManualKey(ctx context.Context, c *http.Client, provider, key, region string, now time.Time) string {
	k, ok := normalizeManualKey(provider, key, region)
	if !ok {
		if strings.TrimSpace(key) == "" && ManualKeyProvider(provider) {
			return ManualKeyNoKey
		}
		return ManualKeyNotAccepted
	}
	if c == nil {
		c = nativeClient
	}
	client := *c
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	return manualKeyOutcome(provider, fetchManualKey(ctx, &client, provider, k, now))
}

// TestStoredManualKey tests the key already saved for provider.
func TestStoredManualKey(ctx context.Context, c *http.Client, dir, provider string, now time.Time) string {
	k, ok := loadManualKey(dir, provider)
	if !ok {
		return ManualKeyNoKey
	}
	return TestManualKey(ctx, c, provider, k.Key, k.Region, now)
}
