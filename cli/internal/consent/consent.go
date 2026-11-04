// Package consent owns shared, versioned reader permissions. It reads no tool
// credentials and invokes no readers. All CLI/App/plugin copies use one file.
package consent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const TextVersion = 2
const Text = "Allow ModelPlan on this user account—App, plugins and all CLI copies—to read usage for the selected tools using their existing sign-in, through native readers or audited standard CodexBar access. CodexBar is downloaded automatically with a verified checksum; you do not install it. Your credential is sent only to the provider hosts shown for that tool; it is never sent to ModelPlan servers or stored by ModelPlan. macOS may ask for Keychain access for our own readers; standard CodexBar access has Keychain and browser-cookie import disabled. Browser-session access is excluded and requires separate per-provider consent. You can turn this off in Settings."
const TextZH = "允许此用户账户下的 ModelPlan App、插件和所有 CLI 副本，使用所选工具已有的登录，通过原生读取器或经审计的标准 CodexBar 访问读取用量。CodexBar 会自动下载并校验校验和，无需自行安装。凭据仅发送至各工具所列的服务商主机，绝不发送至 ModelPlan 服务器，也不由 ModelPlan 保存。macOS 可能为原生读取器请求钥匙串访问权限；标准 CodexBar 访问禁用钥匙串和浏览器 Cookie 导入。浏览器会话访问不在本次授权范围内，须按服务商单独授权。可随时在设置中关闭。"

const (
	Automatic   = "automatic"
	Passive     = "passive"
	Off         = "off"
	Local       = "local"
	Runtime     = "runtime"
	ExplicitKey = "explicit-key"
	Credential  = "credential"
	Bridge      = "codexbar"
)

type Record struct {
	Allowed            bool      `json:"allowed"`
	ConsentTextVersion int       `json:"consentTextVersion"`
	At                 time.Time `json:"at"`
	ReaderID           string    `json:"readerId,omitempty"`
	Backend            string    `json:"backend,omitempty"`
	Region             string    `json:"region,omitempty"`
	KeyEnv             string    `json:"keyEnv,omitempty"`
	BrowserSession     bool      `json:"browserSession,omitempty"`
	BrowserCookieCache bool      `json:"browserCookieCache,omitempty"`
	// Empty preserves pre-API grants; new API records explicitly start unset.
	Keychain string `json:"keychain,omitempty"`
	// Profiles are opaque descriptors, never account identities or token paths.
	Profiles      []string        `json:"profiles,omitempty"`
	DeniedSources map[string]bool `json:"deniedSources,omitempty"`
}
type State struct {
	SchemaVersion  int               `json:"schemaVersion"`
	StoreEpoch     string            `json:"storeEpoch"`
	Scopes         map[string]Record `json:"scopes"`
	RequireConsent bool              `json:"requireConsent,omitempty"`
	Revoked        map[string]uint64 `json:"revokeWatermarks,omitempty"`
	Generation     uint64            `json:"generation"`
	Privacy        string            `json:"privacy"`
	Tools          map[string]Record `json:"tools"`
	Hinted         map[string]bool   `json:"hinted,omitempty"`
	// Requests is keyed by (storeEpoch, requestId). Schema-1 receipts migrate
	// from their reserved Hinted namespace without changing their hashes/results.
	Requests map[string]Receipt `json:"requests,omitempty"`
}

// Receipt is committed with permissions. Results contain only public consent
// DTOs, never credentials. PendingForget survives interrupted/failed cleanup.
type Receipt struct {
	RequestHash   string          `json:"requestHash"`
	Result        json.RawMessage `json:"result"`
	PendingForget []string        `json:"pendingForget,omitempty"`
	ForgetScopes  map[string]bool `json:"forgetScopes,omitempty"`
}

var toolID = regexp.MustCompile(`^[a-z][a-z0-9-]{0,47}$`)

func ValidTool(id string) bool { return toolID.MatchString(id) }
func Path() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "modelplan", "consent.json")
}
func Empty() State {
	return State{SchemaVersion: 2, Privacy: Automatic, Tools: map[string]Record{}, Scopes: map[string]Record{}, Revoked: map[string]uint64{}, Hinted: map[string]bool{}}
}
func loadRaw(file string) (State, []byte, error) {
	s := Empty()
	f, err := os.Open(file)
	if errors.Is(err, os.ErrNotExist) {
		return s, nil, nil
	}
	if err != nil {
		return s, nil, errors.New("consent unavailable")
	}
	defer f.Close()
	b, err := io.ReadAll(io.LimitReader(f, (256<<10)+1))
	if err != nil || len(b) > 256<<10 {
		return s, nil, errors.New("consent too large or unreadable")
	}
	if json.Unmarshal(b, &s) != nil || (s.SchemaVersion != 1 && s.SchemaVersion != 2) || (s.Privacy != Automatic && s.Privacy != Passive) || s.Tools == nil {
		return Empty(), nil, errors.New("invalid consent state")
	}
	if s.SchemaVersion == 2 && (!validEpoch(s.StoreEpoch) || s.Scopes == nil) {
		return Empty(), nil, errors.New("invalid consent epoch or scopes")
	}
	for scope, generation := range s.Revoked {
		if !ValidScope(scope) || generation > s.Generation {
			return Empty(), nil, errors.New("invalid revoke watermark")
		}
	}
	for id, r := range s.Scopes {
		if !ValidScope(id) || r.ConsentTextVersion < 1 {
			return Empty(), nil, errors.New("invalid consent scope")
		}
	}
	for id, r := range s.Tools {
		if !ValidTool(id) || r.ConsentTextVersion < 1 || (r.Keychain != "" && r.Keychain != "allowed" && r.Keychain != "denied" && r.Keychain != "unset") {
			return Empty(), nil, errors.New("invalid consent record")
		}
	}
	if s.Hinted == nil {
		s.Hinted = map[string]bool{}
	}
	if err := loadReceipts(&s, b); err != nil {
		return Empty(), nil, err
	}
	for id, r := range s.Tools {
		r.restoreKeychain()
		s.Tools[id] = r
	}
	return s, b, nil
}

// Effective lets environment settings only restrict a persisted privacy choice.
// An unknown nonempty override fails closed, rather than enabling imports.
func (s State) Effective(override string) string {
	switch strings.ToLower(strings.TrimSpace(override)) {
	case "off":
		return Off
	case "passive":
		return Passive
	case "", "automatic":
		return s.Privacy
	default:
		return Off
	}
}
func Current() (State, string) {
	s, err := Load(Path())
	if err != nil {
		return Empty(), Off
	}
	return s, s.Effective(os.Getenv("MODELPLAN_READERS"))
}

// Allows preserves legacy explicit grants when no new decision exists. A
// persisted refusal/revocation always wins. Passive permits only credential-free
// local/runtime reads and explicitly configured environment keys.
func (s State) Allows(tool, class, mode string) bool {
	if s.SchemaVersion == 2 {
		id := s.scopeFor(tool, class)
		if class == "keychain" {
			return s.AllowsScope(id, mode) && s.keychainStatus(tool) == "allowed"
		}
		if id != "" {
			return s.AllowsScope(id, mode)
		}
	}
	return s.legacyAllows(tool, class, mode)
}

// legacyAllows preserves direct in-memory v1 adapters; persisted v2 scopes
// always take precedence for every compiled read path.
func (s State) legacyAllows(tool, class, mode string) bool {
	if mode == Off {
		return false
	}
	if r, ok := s.Tools[tool]; ok {
		if !r.Allowed || r.ConsentTextVersion != TextVersion || r.DeniedSources[class] {
			return false
		}
		if class == "keychain" && s.keychainStatus(tool) != "allowed" {
			return false
		}
	} else if class == Credential || class == Bridge || class == "keychain" {
		return false
	}
	if mode == Passive {
		return class == Local || class == Runtime || class == ExplicitKey
	}
	return mode == Automatic
}
func Allowed(tool, class string) bool { s, mode := Current(); return s.Allows(tool, class, mode) }

// Change serialises read/modify/rename across every CLI copy. Generation is the
// reader handoff fence: work started under an older generation is not admitted.
func Change(file string, change func(*State) error) error {
	return transaction(file, change, nil, false)
}

// ErrUnchanged returns a saved receipt without writing or bumping generation.
var ErrUnchanged = errors.New("consent unchanged")

// Transaction waits briefly for competing consent writers, then commits all
// permissions and the replay receipt in one rename. An optional finalize step
// runs after revocation is durable, under the same lock; it may only complete
// receipt/cleanup metadata, never permissions or generation. This keeps replays
// deterministic even when Forget cannot finish. Existing writers stay fail-fast.
func Transaction(file string, change, finalize func(*State) error) error {
	return transaction(file, change, finalize, true)
}

func transaction(file string, change, finalize func(*State) error, wait bool) error {
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		return err
	}
	unlock, err := lockFile(file + ".lock")
	deadline := time.Now().Add(2 * time.Second)
	for wait && err != nil && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
		unlock, err = lockFile(file + ".lock")
	}
	if err != nil {
		return errors.New("consent busy; retry")
	}
	defer unlock()
	s, err := loadLocked(file)
	if err != nil {
		return err
	}
	if err = change(&s); err != nil {
		if errors.Is(err, ErrUnchanged) {
			return nil
		}
		return err
	}
	if s.StoreEpoch == "" {
		s.StoreEpoch = newEpoch()
	}
	if s.Generation == ^uint64(0) {
		return errors.New("consent generation exhausted")
	}
	s.Generation++
	if err = save(file, s); err != nil {
		return err
	}
	if finalize != nil {
		committed := &FinalizationError{fence: s.Fence(), receipts: map[string]Receipt{}}
		for key, receipt := range s.Requests {
			committed.receipts[key] = copyReceipt(receipt)
		}
		err = finalize(&s)
		if errors.Is(err, ErrUnchanged) {
			return nil
		}
		if err == nil {
			err = save(file, s)
		}
		if err != nil {
			committed.cause = err
			return committed
		}
	}
	return nil
}

func save(file string, s State) error {
	if err := storeReceipts(&s); err != nil {
		return err
	}
	b, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	// Never write state that Load would reject. Receipts are retained rather
	// than evicted, so request IDs cannot silently become reusable.
	if len(b)+1 > 256<<10 {
		return errors.New("consent state full")
	}
	f, err := os.CreateTemp(filepath.Dir(file), ".consent-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	if err = f.Chmod(0600); err == nil {
		_, err = f.Write(append(b, '\n'))
	}
	if err == nil {
		err = f.Sync()
	}
	closeErr := f.Close()
	if err == nil {
		err = closeErr
	}
	if err == nil {
		err = os.Rename(f.Name(), file)
	}
	return err
}
func Set(s *State, id string, allowed bool, reader, backend string, now time.Time) error {
	if !ValidTool(id) {
		return fmt.Errorf("invalid tool ID")
	}
	r := s.Tools[id]
	r.Allowed = allowed
	r.ConsentTextVersion = TextVersion
	r.At = now.UTC()
	r.ReaderID = reader
	r.Backend = backend
	r.BrowserSession = false
	// Reconnecting does not clear a Keychain Deny. Only explicit Settings Retry
	// may clear that source after informing the user; no retry is offered here.
	s.Tools[id] = r
	setToolScopes(s, id, r)
	return nil
}
func Deny(file, tool, source string) error {
	return Change(file, func(s *State) error {
		r, ok := s.Tools[tool]
		if !ok {
			return errors.New("tool has no consent")
		}
		if r.DeniedSources == nil {
			r.DeniedSources = map[string]bool{}
		}
		r.DeniedSources[source] = true
		if source == "keychain" {
			delete(r.DeniedSources, keychainUnset)
			r.Keychain = "denied"
		}
		s.Tools[tool] = r
		for id, record := range s.Scopes {
			d, ok := Definition(id)
			if ok && d.Tool == tool && (d.Class == source || source == "keychain" && d.Keychain) {
				record.DeniedSources = cloneRecord(record).DeniedSources
				if record.DeniedSources == nil {
					record.DeniedSources = map[string]bool{}
				}
				record.DeniedSources[source] = true
				if source != "keychain" {
					s.RevokeScope(id)
				}
				if source == "keychain" {
					record.Keychain = "denied"
				}
				s.Scopes[id] = record
			}
		}
		return nil
	})
}

// Fence identifies one admission across resets as well as ordinary mutations.
type Fence struct {
	StoreEpoch string
	Generation uint64
}

func (s State) Fence() Fence    { return Fence{s.StoreEpoch, s.Generation} }
func CurrentFence(f Fence) bool { s, err := Load(Path()); return err == nil && s.Fence() == f }

// ReaderLock coordinates refresh/snapshot writers with Forget readings. A
// revoked provider is reselected only after this lock, never from a stale list.
func ReaderLock() (func(), error) {
	file := Path() + ".readers.lock"
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		return nil, err
	}
	return lockFile(file)
}

// ErrReaderBusy distinguishes admission contention from collection failures.
var ErrReaderBusy = errors.New("reader admission busy")

// Detached refreshes may briefly wait for a local snapshot/history commit. Do
// not make the foreground caller wait or let a fresh child starve on that race.
func ReaderLockContext(ctx context.Context) (func(), error) {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	for {
		unlock, err := ReaderLock()
		if err == nil {
			return unlock, nil
		}
		select {
		case <-ctx.Done():
			return nil, errors.Join(ErrReaderBusy, err)
		case <-time.After(50 * time.Millisecond):
		}
	}
}

func LocalWrite(tool string, write func() error) error {
	unlock, err := ReaderLock()
	if err != nil {
		return err
	}
	defer unlock()
	s, mode := Current()
	if !s.Allows(tool, Local, mode) {
		return errors.New("local reader not permitted")
	}
	return Publish(s.Fence(), write)
}

// ErrBusy means the consent lock is held; ErrChanged means the consent state
// could not be loaded or no longer matches the admission fence.
var (
	ErrBusy    = errors.New("consent/reader admission busy; retry")
	ErrChanged = errors.New("consent changed; reading not published")
)

// Publish serializes generation validation and the short cache commit with
// consent changes. No credential or provider I/O belongs inside this callback.
func Publish(f Fence, write func() error) error {
	return publish(context.Background(), f, write, false)
}

// PublishContext waits at most one second for the lock, without retrying write.
// A caller's shorter deadline or cancellation takes precedence over that bound.
func PublishContext(ctx context.Context, f Fence, write func() error) error {
	return publish(ctx, f, write, true)
}

func publish(ctx context.Context, f Fence, write func() error, wait bool) error {
	file := Path() + ".lock"
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		return err
	}
	var timer *time.Timer
	if wait {
		timer = time.NewTimer(time.Second)
		defer timer.Stop()
	}
	var unlock func()
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		var err error
		unlock, err = lockFile(file)
		if err == nil {
			break
		}
		if !wait || !errors.Is(err, ErrBusy) {
			return err
		}
		pause := time.NewTimer(10 * time.Millisecond)
		select {
		case <-ctx.Done():
			pause.Stop()
			return ctx.Err()
		case <-timer.C:
			pause.Stop()
			if err := ctx.Err(); err != nil {
				return err
			}
			return ErrBusy
		case <-pause.C:
		}
	}
	defer unlock()
	if err := ctx.Err(); err != nil {
		return err
	}
	s, err := Load(Path())
	if err != nil || s.Fence() != f {
		return ErrChanged
	}
	return write()
}
