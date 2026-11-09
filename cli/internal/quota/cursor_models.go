package quota

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
)

// D102: an opt-in lane that runs the user's own `cursor-agent models` and keeps the model ids it prints.
// It runs a third-party binary, so it is off until the user enables the cursor.runtime_models scope.
// Safeguards: an absolute path found by toolcli.Find (or $MODELPLAN_CURSOR_AGENT when absolute; never a
// binary we install), fixed argv `models`, no shell, a minimal environment, a 15 s kill timeout, output
// capped at 64 KiB and parsed strictly to ids, a 24 h cache keyed by the account, and no read at all while
// the scope is off. A failure, timeout or odd output keeps the previous list and never changes the quota
// read. UNVERIFIED against a real install: see docs/readers/cursor.md for the recording run.
const cursorModelsEvery = 24 * time.Hour
const cursorModelsMaxOutput = 64 << 10

// A var only so tests can shorten the cap.
var cursorModelsTimeout = 15 * time.Second

type cursorModelsCache struct {
	AttemptedAt time.Time `json:"attemptedAt"`
	AccountKey  string    `json:"accountKey"`
	Models      []string  `json:"models,omitempty"`
}

func cursorModelsPath(cache string) string {
	return filepath.Join(cache, "observed", "cursor-models.json")
}

func cursorAgentBin() string {
	if p := os.Getenv("MODELPLAN_CURSOR_AGENT"); p != "" {
		if filepath.IsAbs(p) {
			return p
		}
		return ""
	}
	home, _ := os.UserHomeDir()
	return toolcli.Find(home, "cursor-agent")
}

// cursorModelsEnv is deliberately small: where the tool finds its own sign-in, and nothing else.
func cursorModelsEnv() []string {
	env := []string{"NO_COLOR=1", "TERM=dumb"}
	for _, k := range []string{"HOME", "PATH", "USER", "LANG", "TMPDIR", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "APPDATA", "LOCALAPPDATA"} {
		if v := os.Getenv(k); v != "" {
			env = append(env, k+"="+v)
		}
	}
	return env
}

// cursorReportedModels returns the cached ids while fresh, else runs the lane once. Called only when the
// opt-in scope is allowed; nothing is started otherwise.
func cursorReportedModels(ctx context.Context, p Paths, accountKey string, now time.Time) []string {
	if p.Cache == "" || accountKey == "" || !consentAllowsCursorModels(p) {
		return nil
	}
	var old cursorModelsCache
	if b, err := os.ReadFile(cursorModelsPath(p.Cache)); err == nil {
		_ = json.Unmarshal(b, &old)
	}
	if old.AccountKey != accountKey { // sign-in changed: never show the previous account's list
		old = cursorModelsCache{AccountKey: accountKey}
	}
	old.Models = cleanReportedModels(old.Models)
	if !old.AttemptedAt.IsZero() && !old.AttemptedAt.After(now) && now.Sub(old.AttemptedAt) < cursorModelsEvery {
		return old.Models
	}
	next := cursorModelsCache{AttemptedAt: now.UTC(), AccountKey: accountKey, Models: old.Models}
	if bin := cursorAgentBin(); bin != "" && filepath.IsAbs(bin) {
		if ids := runCursorModels(ctx, bin); ids != nil {
			next.Models = ids
		}
	}
	if b, err := json.Marshal(next); err == nil {
		_ = os.MkdirAll(filepath.Dir(cursorModelsPath(p.Cache)), 0o700)
		_ = os.WriteFile(cursorModelsPath(p.Cache), b, 0o600)
	}
	return next.Models
}

func consentAllowsCursorModels(p Paths) bool {
	a := admissionFor(p)
	return a.State().AllowsScope(consent.ScopeCursorRuntimeModels, a.Mode()) && consent.CurrentFence(a.Fence())
}

func runCursorModels(ctx context.Context, bin string) []string {
	ctx, cancel := context.WithTimeout(ctx, cursorModelsTimeout)
	defer cancel()
	cmd, err := toolcli.CommandContext(ctx, bin, "models")
	if err != nil {
		return nil
	}
	cmd.Env = cursorModelsEnv()
	cmd.Dir = os.TempDir()
	cmd.Stderr = io.Discard
	// A buffer, not a pipe: when the tool is killed at the deadline, a child still holding the pipe cannot
	// keep us waiting (WaitDelay closes it).
	out := &cappedBuffer{limit: cursorModelsMaxOutput}
	cmd.Stdout = out
	cmd.WaitDelay = time.Second
	if cmd.Run() != nil || ctx.Err() != nil || out.over {
		return nil
	}
	return parseCursorModels(out.Bytes())
}

// cappedBuffer fails the write (and so the process) once the output exceeds limit.
type cappedBuffer struct {
	bytes.Buffer
	limit int
	over  bool
}

func (c *cappedBuffer) Write(p []byte) (int, error) {
	if c.Len()+len(p) > c.limit {
		c.over = true
		return 0, io.ErrShortWrite
	}
	return c.Buffer.Write(p)
}

var (
	cursorANSI  = regexp.MustCompile(`\x1b\[[0-9;?]*[ -/]*[@-~]`)
	cursorModel = regexp.MustCompile(`^[a-z0-9][a-z0-9._-]{0,63}$`)
)

// parseCursorModels takes ids only. A JSON array/object is read as a model list; otherwise each line must be
// an id alone or an id followed by " - description"; headers, tips, prose and anything else are skipped.
func parseCursorModels(raw []byte) []string {
	raw = bytes.TrimSpace(cursorANSI.ReplaceAll(raw, nil))
	if len(raw) == 0 {
		return nil
	}
	if raw[0] == '[' || raw[0] == '{' {
		if ids := reportedModelIDs(raw); len(ids) > 0 {
			return ids
		}
		return nil
	}
	var ids []string
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(line), "*"))
		id, rest, _ := strings.Cut(line, " ")
		rest = strings.TrimSpace(rest)
		if !cursorModel.MatchString(id) || (rest != "" && !strings.HasPrefix(rest, "-")) {
			continue
		}
		ids = append(ids, id)
	}
	return cleanReportedModels(ids)
}
