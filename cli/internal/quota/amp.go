package quota

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

// AmpPool contains returned money, never an inferred percentage/reset/subscription.
// Distinct free, included and paid pools must not be summed.
type AmpPool struct {
	Kind      string   `json:"kind"`
	Currency  string   `json:"currency"`
	Remaining float64  `json:"remaining"`
	Limit     *float64 `json:"limit,omitempty"`
}
type AmpResult struct {
	Availability  string    `json:"availability"`
	Freshness     string    `json:"freshness"`
	Confidence    string    `json:"confidence"`
	Beta          bool      `json:"beta"`
	NextStep      string    `json:"nextStep"`
	ObservedAt    time.Time `json:"observedAt,omitempty"`
	NextAttemptAt time.Time `json:"nextAttemptAt,omitempty"`
	Pools         []AmpPool `json:"pools"`
}

// AmpAccess is supplied by CLIJIT after consent. Only a provider/source audit can
// admit a binary digest. A path/version alone never establishes side-effect safety.
type AmpAccess struct {
	Allowed, Denied                                     bool
	Privacy, LoginState, LoginGeneration, AuditedSHA256 string
}
type ampAccessKey struct{}

func WithAmpAccess(ctx context.Context, a AmpAccess) context.Context {
	return context.WithValue(ctx, ampAccessKey{}, a)
}

var ampBin = func() string {
	if p := os.Getenv("MODELPLAN_AMP"); filepath.IsAbs(p) {
		return p
	}
	home, _ := os.UserHomeDir()
	return toolcli.Find(home, "amp")
}
var ampCommand = runAmpUsage
var ampArtifact = ampVerifiedArtifact

type ampArtifactKey struct{}

func runAmpUsage(ctx context.Context, bin string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	artifact, ok := ctx.Value(ampArtifactKey{}).(*os.File)
	if !ok || artifact == nil || ampExecPath() == "" {
		return nil, errors.New("verified Amp execution unavailable")
	}
	cmd := exec.CommandContext(ctx, ampExecPath(), "usage", "--no-color")
	cmd.Args[0] = bin
	var err error
	// Read the verified descriptor, never a replacement at the installed path.
	if toolcli.EnvNode(io.NewSectionReader(artifact, 0, 4096)) {
		cmd, err = toolcli.NodeCommandContext(ctx, ampExecPath(), bin, "usage", "--no-color")
	}
	if err != nil {
		return nil, err
	}
	cmd.ExtraFiles = []*os.File{artifact}
	cmd.Stdin = nil
	cmd.Stderr = io.Discard
	cmd.WaitDelay = time.Second
	cmd.Env = append(os.Environ(), "AMP_SKIP_UPDATE_CHECK=1", "NO_COLOR=1", "TERM=dumb", "LANG=C", "LC_ALL=C")
	var out bytes.Buffer
	cmd.Stdout = &limited{w: &out, n: 64 << 10}
	err = cmd.Run()
	if err != nil {
		return out.Bytes(), err
	}
	return out.Bytes(), nil
}

var ampMoney = regexp.MustCompile(`^(Amp Free|Free|Individual|Paid|Balance|Credits|Included):\s*\$([0-9]+(?:\.[0-9]{1,2})?)(?:\s*(?:/|of)\s*\$([0-9]+(?:\.[0-9]{1,2})?))?\s+remaining(?:\s+\(\+\$[0-9]+(?:\.[0-9]{1,2})?/(?:hour|day)\))?$`)
var ampANSI = regexp.MustCompile("\x1b\\[[0-9;]*m")

func parseAmpUsage(raw []byte) ([]AmpPool, bool) {
	if len(raw) > 64<<10 {
		return nil, false
	}
	var pools []AmpPool
	seen := map[string]bool{}
	sc := bufio.NewScanner(bytes.NewReader(raw))
	sc.Buffer(make([]byte, 4096), 8192)
	for sc.Scan() {
		line := strings.TrimSpace(strings.ReplaceAll(ampANSI.ReplaceAllString(sc.Text(), ""), "**", ""))
		m := ampMoney.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		kind := "paid"
		if m[1] == "Free" || m[1] == "Amp Free" {
			kind = "free"
		}
		if m[1] == "Included" {
			kind = "included"
		}
		if seen[kind] {
			return nil, false
		}
		seen[kind] = true
		remaining, err := strconv.ParseFloat(m[2], 64)
		if err != nil || remaining > 1e9 {
			return nil, false
		}
		p := AmpPool{Kind: kind, Currency: "USD", Remaining: remaining}
		if m[3] != "" {
			limit, err := strconv.ParseFloat(m[3], 64)
			if err != nil || limit < remaining || limit > 1e9 {
				return nil, false
			}
			p.Limit = &limit
		}
		pools = append(pools, p)
	}
	return pools, sc.Err() == nil && len(pools) > 0
}
func ampNext(state string) string {
	switch state {
	case "ok":
		return "Refresh when needed and allowed"
	case toolcli.RuntimeMissing:
		return toolcli.RuntimeNextStep
	case "not_detected":
		return "Open Amp"
	case "denied":
		return "Retry Amp in Settings"
	case "expired_login":
		return "Open Amp to refresh its sign-in"
	case "not_supported_yet":
		return "Report the Amp runtime version for a read-only audit"
	case "off", "privacy_blocked", "consent_required":
		return "Review Amp consent and privacy settings"
	case "upstream_changed":
		return "Wait for an Amp reader compatibility update"
	default:
		return "Wait until the next eligible Amp read"
	}
}
func ampAdmission(ctx context.Context) (AmpAccess, string) {
	a, _ := ctx.Value(ampAccessKey{}).(AmpAccess)
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
	case a.LoginState == "expired":
		return a, "expired_login"
	case a.LoginState == "unsupported":
		return a, "not_supported_yet"
	case mode == "passive" || a.Privacy == "passive":
		return a, "privacy_blocked"
	case mode != "" && mode != "automatic":
		return a, "privacy_blocked"
	}
	return a, ""
}

type ampState struct {
	GoodGeneration  string    `json:"goodGeneration,omitempty"`
	LoginGeneration string    `json:"loginGeneration,omitempty"`
	SchemaVersion   int       `json:"schemaVersion"`
	AttemptAt       time.Time `json:"attemptAt"`
	NextAt          time.Time `json:"nextAt"`
	Failures        int       `json:"failures"`
	Availability    string    `json:"availability"`
	ObservedAt      time.Time `json:"observedAt"`
	Pools           []AmpPool `json:"pools"`
}

func ampPath(cache string) string { return filepath.Join(cache, "observed", "amp-v1.json") }
func loadAmp(cache string) ampState {
	var s ampState
	b, status := readBounded(ampPath(cache), 64<<10)
	if status != "" || json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 {
		return ampState{SchemaVersion: 1}
	}
	return s
}
func saveAmp(cache string, s ampState) bool {
	path := ampPath(cache)
	if os.MkdirAll(filepath.Dir(path), 0700) != nil {
		return false
	}
	b, err := json.Marshal(s)
	return err == nil && writeAtomic(path, append(b, '\n')) == nil
}

// ReadAmpCache never launches Amp or reads its credentials. USD balances have no
// inferred reset/expiry: stale money remains explicitly aged at its capture time.
func ReadAmpCache(ctx context.Context, cache string, now time.Time) AmpResult {
	r := AmpResult{Beta: true, Confidence: "exact", Freshness: "unknown", Pools: []AmpPool{}}
	access, blocked := ampAdmission(ctx)
	if blocked != "" {
		r.Availability = blocked
		r.NextStep = ampNext(blocked)
		return r
	}
	s := loadAmp(cache)
	r.Availability = s.Availability
	if r.Availability == "" || s.LoginGeneration != access.LoginGeneration {
		r.Availability = "stale"
	}
	r.NextAttemptAt = s.NextAt
	if s.GoodGeneration != access.LoginGeneration {
		if r.Availability == "ok" {
			r.Availability = "stale"
		}
		r.NextStep = ampNext(r.Availability)
		return r
	}
	r.NextStep = ampNext(r.Availability)
	if !s.ObservedAt.IsZero() && !s.ObservedAt.After(now) {
		r.ObservedAt = s.ObservedAt
		r.Pools = s.Pools
		r.Freshness = "fresh"
		if r.Availability != "ok" || now.Sub(s.ObservedAt) > staleAfter {
			r.Freshness = "stale"
		}
	}
	return r
}

var ampAttempts sync.Map

// RefreshAmp runs only an audited existing binary; no prompt, input, thread,
// login, token import, credential file read or unaudited automatic execution.
func RefreshAmp(ctx context.Context, cache string, now time.Time) AmpResult {
	access, blocked := ampAdmission(ctx)
	if blocked != "" {
		return ReadAmpCache(ctx, cache, now)
	}
	if cache == "" {
		return AmpResult{Availability: "not_supported_yet", Beta: true, NextStep: ampNext("not_supported_yet")}
	}
	unlock, ok := lockFile(filepath.Join(cache, "observed", "amp.lock"), time.Now(), 20*time.Second)
	if !ok {
		return ReadAmpCache(ctx, cache, now)
	}
	defer unlock()
	s := loadAmp(cache)
	if last, ok := ampAttempts.Load(cache); ok && now.Sub(last.(time.Time)) < 5*time.Minute {
		return ReadAmpCache(ctx, cache, now)
	}
	if now.Before(s.NextAt) || now.Before(s.AttemptAt.Add(5*time.Minute)) {
		return ReadAmpCache(ctx, cache, now)
	}
	if s.Availability == "expired_login" && access.LoginGeneration != "" && s.LoginGeneration == access.LoginGeneration {
		return ReadAmpCache(ctx, cache, now)
	}
	s.LoginGeneration = access.LoginGeneration
	s.AttemptAt = now.UTC()
	s.NextAt = now.Add(5 * time.Minute).UTC()
	if !saveAmp(cache, s) {
		return AmpResult{Availability: "stale", Beta: true, NextStep: ampNext("stale")}
	}
	ampAttempts.Store(cache, now)
	bin := ampBin()
	s.Availability = "not_detected"
	if bin != "" {
		s.Availability = "not_supported_yet"
		// SHA binds the audited executable, not an account identity. Bound hashing;
		// credential files and their digests never enter this check or the cache.
		if artifact, err := ampArtifact(bin, access.AuditedSHA256); err == nil {
			defer artifact.Close()
			commandCtx := context.WithValue(ctx, ampArtifactKey{}, artifact)
			raw, err := ampCommand(commandCtx, bin)
			text := strings.ToLower(string(raw))
			if strings.Contains(text, "not logged in") || strings.Contains(text, "please log in") || strings.Contains(text, "unauthorized") {
				s.Availability = "expired_login"
			} else if errors.Is(err, toolcli.ErrRuntimeMissing) {
				s.Availability = toolcli.RuntimeMissing
			} else if err == nil {
				if pools, valid := parseAmpUsage(raw); valid {
					s.Pools = pools
					s.ObservedAt = now.UTC()
					s.GoodGeneration = access.LoginGeneration
					s.Availability = "ok"
				} else {
					s.Availability = "upstream_changed"
				}
			}
		}
	}
	if _, blocked := ampAdmission(ctx); ctx.Err() != nil || blocked != "" {
		return ReadAmpCache(ctx, cache, now)
	}
	if s.Availability == "ok" {
		s.Failures = 0
		s.NextAt = now.Add(10 * time.Minute).UTC()
	} else {
		s.Failures = min(s.Failures+1, 4)
		wait := time.Duration(10*(1<<(s.Failures-1))) * time.Minute
		if s.Failures == 4 {
			wait = time.Hour
		}
		s.NextAt = now.Add(wait).UTC()
	}
	if !saveAmp(cache, s) {
		return AmpResult{Availability: "stale", Beta: true, NextStep: ampNext("stale")}
	}
	return ReadAmpCache(ctx, cache, now)
}

// Seal a private anonymous snapshot before hashing, then execute that exact
// descriptor. Replacing or modifying the installed path cannot alter these bytes.
func ampVerifiedArtifact(path, want string) (*os.File, error) {
	expected, err := hex.DecodeString(want)
	if err != nil || len(expected) != sha256.Size {
		return nil, errors.New("Amp artifact unaudited")
	}
	source, err := os.Open(path)
	if err != nil {
		return nil, errors.New("Amp artifact unavailable")
	}
	defer source.Close()
	info, err := source.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Size() > 256<<20 {
		return nil, errors.New("Amp artifact unavailable")
	}
	artifact, err := ampSealedArtifact(source)
	if err != nil {
		return nil, errors.New("sealed Amp execution unavailable")
	}
	fail := func() (*os.File, error) {
		artifact.Close()
		return nil, errors.New("Amp artifact does not match audit")
	}
	var magic [4]byte
	if _, err := artifact.ReadAt(magic[:], 0); err != nil || (magic != [4]byte{0x7f, 'E', 'L', 'F'} && !toolcli.EnvNode(io.NewSectionReader(artifact, 0, 4096))) {
		return fail()
	}
	h := sha256.New()
	n, err := io.Copy(h, io.LimitReader(artifact, 256<<20+1))
	if err != nil || n > 256<<20 || !bytes.Equal(h.Sum(nil), expected) {
		return fail()
	}
	if _, err := artifact.Seek(0, io.SeekStart); err != nil {
		return fail()
	}
	return artifact, nil
}
func ampAuditedBinary(path, want string) bool {
	artifact, err := ampVerifiedArtifact(path, want)
	if err != nil {
		return false
	}
	artifact.Close()
	return true
}
