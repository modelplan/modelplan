package localusage

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"path/filepath"
	"strings"
	"time"
)

const projectionTool = "claude-projection"

// ProjectionInterval is a local-state floor, independent of network quota and
// token-history schedules. Failed attempts back off up to one minute.
const ProjectionInterval = 5 * time.Second

const projectionBootstrapBytes int64 = 4 << 20
const projectionRecordLimit = 4096

// ProjectionState is trusted reducer output, persisted with the engine cursor in
// one atomic commit. Snapshot contains only approved presentation fields; Decoder
// contains only bounded sanitized frontier state with keyed IDs. Neither may
// contain raw IDs, paths, record bodies, messages or credentials. ObservedAt is a
// source timestamp. CapturedAt is engine-owned and advances only on a changed,
// complete snapshot. The provider reducer is responsible for sanitization.
type ProjectionState struct {
	Snapshot   json.RawMessage `json:"snapshot,omitempty"`
	Decoder    json.RawMessage `json:"decoder,omitempty"`
	ObservedAt time.Time       `json:"observedAt,omitempty"`
	CapturedAt time.Time       `json:"capturedAt,omitempty"`
	// Incomplete lets the reducer report missing ancestry or malformed records
	// even when discovery and byte recovery completed. Clear only with evidence.
	Incomplete bool `json:"incomplete,omitempty"`
}

// ProjectionBatch is transient: never persist or log it. Each data batch holds
// <=256 complete lines and <=1 MiB, including newlines. Offset is the first
// line's byte offset.
// Reset is initial/replacement/truncation/rewrite on the first batch for a reset
// file (possibly its empty EndFile batch). Drop that file's old decoder frontier.
// EndFile is also delivered for unchanged files, without reading their contents.
// Only Final establishes transaction-wide RecoveryComplete. LiveFileRefs is the
// bounded discovery manifest; prune missing files only if DiscoveryComplete.
// SessionID is the filename stem; reducers must verify any header agreement.
// PrefixOmitted reports a bounded tail bootstrap; missing ancestry/headers must
// stay unknown. On Final it means at least one file omitted an earlier prefix.
type ProjectionBatch struct {
	FileRef, SessionID string   `json:"-"`
	Lines              [][]byte `json:"-"`
	Offset             int64    `json:"-"`
	Reset              string   `json:"-"`
	EndFile, Unchanged bool     `json:"-"`
	Final              bool     `json:"-"`
	DiscoveryComplete  bool     `json:"-"`
	RecoveryComplete   bool     `json:"-"`
	PrefixOmitted      bool     `json:"-"`
	LiveFileRefs       []string `json:"-"`
}

// ProjectionReducer must be deterministic and perform no I/O. It receives prior
// sanitized state; raw batches are valid only during the call. Errors abort the
// whole state+cursor transaction and are never stored. Final is called even on
// unchanged or incomplete discovery. Incomplete transactions commit decoder
// progress but retain the last good Snapshot, ObservedAt and CapturedAt. A later
// complete Final can publish the accumulated sanitized decoder. Never infer
// recency from incomplete input.
type ProjectionReducer func(context.Context, ProjectionState, ProjectionBatch) (ProjectionState, error)

type ProjectionResult struct {
	Snapshot        json.RawMessage `json:"snapshot,omitempty"`
	ObservedAt      time.Time       `json:"observedAt,omitempty"`
	CapturedAt      time.Time       `json:"capturedAt,omitempty"`
	NextAttemptAt   time.Time       `json:"nextAttemptAt,omitempty"`
	Availability    string          `json:"availability"`
	Freshness       string          `json:"freshness"`
	NextStep        string          `json:"nextStep"`
	Complete        bool            `json:"complete"`
	Beta            bool            `json:"beta"`
	BytesRead       int64           `json:"bytesRead"`
	ValidationBytes int64           `json:"validationBytes"`
}

func projectionSessionName(name string) bool {
	if !strings.HasSuffix(name, ".jsonl") {
		return false
	}
	id := strings.TrimSuffix(name, ".jsonl")
	if len(id) == 0 || len(id) > 200 {
		return false
	}
	for i, c := range id {
		if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || (i > 0 && strings.ContainsRune("._-", c)) {
			continue
		}
		return false
	}
	return true
}
func projectionAdmission(kind string, a HistoryAccess) string {
	if blocked := historyAdmission(projectionTool, a); blocked != "" {
		return blocked
	}
	if kind != "claude" {
		return "not_supported_yet"
	}
	return ""
}
func projectionNext(state string) string {
	switch state {
	case "ok":
		return "Refresh local session state when needed"
	case "not_detected":
		return "Open Claude Code to record a main session"
	case "partial", "stale":
		return "Wait for a complete local session read"
	default:
		return historyNext("claude", state)
	}
}

// ReadProjectionCache reads ModelPlan's derived cache and scheduling gate only.
// It never discovers, opens, stats or reads a source transcript.
func ReadProjectionCache(cache, kind string, a HistoryAccess, now time.Time) ProjectionResult {
	r := ProjectionResult{Beta: true, Freshness: "unknown"}
	if blocked := projectionAdmission(kind, a); blocked != "" {
		r.Availability, r.NextStep = blocked, projectionNext(blocked)
		return r
	}
	if !filepath.IsAbs(cache) {
		r.Availability, r.NextStep = "stale", projectionNext("stale")
		return r
	}
	s := historyReadState(cache, projectionTool, a)
	r.Availability = s.Availability
	if r.Availability == "" {
		r.Availability = "stale"
	}
	r.Complete = s.Complete
	r.BytesRead, r.ValidationBytes = s.BytesRead, s.ValidationBytes
	if s.Projection != nil && validProjection(*s.Projection, now) {
		r.Snapshot = append(json.RawMessage(nil), s.Projection.Snapshot...)
		r.ObservedAt, r.CapturedAt = s.Projection.ObservedAt, s.Projection.CapturedAt
		if len(r.Snapshot) > 0 {
			r.Freshness = "stale"
			if r.Availability == "ok" && now.Sub(r.CapturedAt) <= time.Minute {
				r.Freshness = "fresh"
			}
		}
	}
	gatePath, _ := historyGatePaths(cache, projectionTool)
	var gate historyGate
	historyLoad(gatePath, &gate, 4096)
	r.NextAttemptAt = gate.Next
	r.NextStep = projectionNext(r.Availability)
	return r
}

// RefreshProjection shares history's bounded discovery, complete-line scanner,
// keyed checkpoints, locking and atomic cursor+state commit. Only kind "claude"
// is supported: <root>/projects/<project>/<session>.jsonl main files. The caller
// supplies the authorized root and trusted provider reducer; Claude decoding
// belongs to that reducer. No credential, subprocess or network I/O occurs.
func RefreshProjection(ctx context.Context, kind, root, cache string, a HistoryAccess, now time.Time, reduce ProjectionReducer) ProjectionResult {
	if projectionAdmission(kind, a) != "" {
		return ReadProjectionCache(cache, kind, a, now)
	}
	if reduce == nil || !filepath.IsAbs(root) || !filepath.IsAbs(cache) {
		r := ReadProjectionCache(cache, kind, a, now)
		r.Availability, r.Complete, r.Freshness = "not_supported_yet", false, "stale"
		r.NextStep = projectionNext(r.Availability)
		return r
	}
	p := &projectionRun{ctx: ctx, reduce: reduce, now: now}
	hr := refreshHistory(ctx, projectionTool, root, cache, a, now, p)
	r := ReadProjectionCache(cache, kind, a, now)
	if hr.Availability != r.Availability {
		r.Availability, r.Complete, r.Freshness = hr.Availability, false, "stale"
		r.NextStep = projectionNext(r.Availability)
	}
	return r
}

// ForgetProjectionProfile removes this profile's snapshot, frontier and cursors
// even after consent revocation. Scheduling reservations remain. Callers cancel
// and join in-flight work before cleanup, as for ForgetHistoryProfile.
func ForgetProjectionProfile(cache, kind string, a HistoryAccess) error {
	if kind != "claude" {
		return fmt.Errorf("local projection unavailable")
	}
	return ForgetHistoryProfile(cache, projectionTool, a)
}

func validProjection(s ProjectionState, now time.Time) bool {
	valid := func(b json.RawMessage, limit int) bool { return len(b) == 0 || (len(b) <= limit && json.Valid(b)) }
	return valid(s.Snapshot, 64<<10) && valid(s.Decoder, 2<<20) && !s.ObservedAt.After(now) && !s.CapturedAt.After(now)
}

type projectionRun struct {
	ctx                       context.Context
	reduce                    ProjectionReducer
	state, prior              ProjectionState
	failed, discoveryComplete bool
	live                      []string
	resetReason               string
	now                       time.Time
	omitted, anyOmitted       bool
	records                   int
	pending                   [][]byte
	pendingBytes              int
	pendingOffset             int64
	pendingRel, pendingRef    string
}

func (p *projectionRun) start(prior *ProjectionState) {
	if prior != nil {
		if !validProjection(*prior, p.now) {
			p.failed = true
			return
		}
		p.state, p.prior = *prior, *prior
		// A reducer may mutate its buffers; keep the rollback copy independent.
		p.state.Snapshot = append(json.RawMessage(nil), prior.Snapshot...)
		p.state.Decoder = append(json.RawMessage(nil), prior.Decoder...)
	}
}
func (p *projectionRun) discovery(files []string, complete bool, a HistoryAccess) {
	p.discoveryComplete = complete
	for _, rel := range files {
		p.live = append(p.live, historyHash(a.Key, "history/path/"+a.ProfileRef+"/"+projectionTool, rel))
	}
}
func (p *projectionRun) call(b ProjectionBatch) bool {
	if p.failed || p.ctx.Err() != nil {
		p.failed = true
		return false
	}
	b.DiscoveryComplete = p.discoveryComplete
	s, err := p.reduce(p.ctx, p.state, b)
	// Capture time belongs to the engine, not the decoder.
	s.CapturedAt = p.prior.CapturedAt
	if err != nil || !validProjection(s, p.now) {
		p.failed = true
		return false
	}
	p.state = s
	return true
}
func (p *projectionRun) reset(reason string, omitted bool) {
	p.resetReason, p.omitted = reason, omitted
	p.anyOmitted = p.anyOmitted || omitted
}
func (p *projectionRun) batch(rel, ref string) ProjectionBatch {
	b := ProjectionBatch{FileRef: ref, SessionID: strings.TrimSuffix(filepath.Base(rel), ".jsonl"), Reset: p.resetReason, PrefixOmitted: p.omitted}
	p.resetReason = ""
	return b
}
func (p *projectionRun) line(rel, ref string, line []byte, offset int64) bool {
	if len(p.pending) > 0 && (p.pendingBytes+len(line) > 1<<20 || len(p.pending) >= 256) {
		if !p.flush() {
			return false
		}
	}
	if len(p.pending) == 0 {
		p.pendingRel, p.pendingRef, p.pendingOffset = rel, ref, offset
	}
	p.pending = append(p.pending, line)
	p.pendingBytes += len(line)
	p.records++
	return true
}
func (p *projectionRun) flush() bool {
	if len(p.pending) == 0 {
		return !p.failed
	}
	b := p.batch(p.pendingRel, p.pendingRef)
	b.Lines, b.Offset = p.pending, p.pendingOffset
	p.pending, p.pendingBytes = nil, 0
	return p.call(b)
}
func (p *projectionRun) file(rel, ref string, complete, unchanged bool) {
	if !p.flush() {
		return
	}
	b := p.batch(rel, ref)
	b.EndFile, b.Unchanged, b.RecoveryComplete = true, unchanged, complete
	p.call(b)
}
func (p *projectionRun) finish(s *historyState, now time.Time) bool {
	complete := p.discoveryComplete && s.Availability == "ok"
	if !p.call(ProjectionBatch{Final: true, RecoveryComplete: complete, LiveFileRefs: p.live, PrefixOmitted: p.anyOmitted}) || !validProjection(p.state, now) {
		return false
	}
	complete = complete && !p.state.Incomplete
	if p.state.Incomplete && s.Availability == "ok" {
		s.Availability = "partial"
	}
	p.state.CapturedAt = p.prior.CapturedAt
	if !complete {
		p.state.Snapshot, p.state.ObservedAt = p.prior.Snapshot, p.prior.ObservedAt
	} else if !bytes.Equal(p.state.Snapshot, p.prior.Snapshot) || !p.state.ObservedAt.Equal(p.prior.ObservedAt) {
		p.state.CapturedAt = now.UTC()
	}
	s.Projection, s.Complete = &p.state, complete
	return true
}
