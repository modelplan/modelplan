package quota

// Claude field decoding and selection for the shared localusage projection engine.
// Discovery, incremental I/O and atomic cursor/snapshot commits belong to READERS.
// Protocol evidence: Anthropic SDK Python 717cea0 sessions.py and TypeScript SDK
// 0.3.301, read-only; independently implemented. The owner confirmed field shapes
// on 2026-10-27. No source, transcript body or raw identity is persisted here.

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"os"
	"regexp"
	"sort"
	"strings"
	"time"
)

type ClaudeSessionFields struct {
	Model    string `json:"model,omitempty"`
	Effort   string `json:"effort,omitempty"`
	FastMode *bool  `json:"fastMode"`
}

// ClaudeSessionBatch is transient output from bounded discovery/read in READERS.
// ExpectedSessionID is the main filename stem, never a path. CompleteDiscovery
// means the shared bounded index can establish recency; false cannot claim recent.
type ClaudeSessionBatch struct {
	ExpectedSessionID string
	Records           [][]byte
	CompleteDiscovery bool
}

type ClaudeSessionObservation struct {
	ClaudeSessionFields
	SessionKey  string    `json:"sessionKey"`
	ObservedAt  time.Time `json:"observedAt"`
	Attribution string    `json:"attribution,omitempty"`
	Origin      string    `json:"origin,omitempty"`
}

type ClaudeSessionProjection struct {
	Availability  string                     `json:"availability"`
	Beta          bool                       `json:"beta"`
	CallerMissing bool                       `json:"callerMissing,omitempty"`
	Sessions      []ClaudeSessionObservation `json:"sessions"`
	Selected      *ClaudeSessionObservation  `json:"selected,omitempty"`
}

var claudeSessionModel = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$`)
var claudeSessionOpaque = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._-]{0,199}$`)

func claudeFieldString(b json.RawMessage) string {
	var s string
	if len(b) > 512 || json.Unmarshal(b, &s) != nil {
		return ""
	}
	return s
}

// Every field is decoded independently: an older/null/unknown effort never
// discards a present model or causes inheritance from a different turn.
func parseClaudeSessionFields(b []byte) ClaudeSessionFields {
	var row struct {
		Effort  json.RawMessage `json:"effort"`
		Message json.RawMessage `json:"message"`
	}
	var fields ClaudeSessionFields
	if json.Unmarshal(b, &row) != nil {
		return fields
	}
	switch effort := claudeFieldString(row.Effort); effort {
	case "low", "medium", "high", "xhigh", "max":
		fields.Effort = effort
	}
	var message struct {
		Model json.RawMessage `json:"model"`
		Usage json.RawMessage `json:"usage"`
	}
	if json.Unmarshal(row.Message, &message) != nil {
		return fields
	}
	if model := claudeFieldString(message.Model); claudeSessionModel.MatchString(model) {
		fields.Model = model
	}
	var usage struct {
		Speed json.RawMessage `json:"speed"`
	}
	if json.Unmarshal(message.Usage, &usage) != nil {
		return fields
	}
	switch claudeFieldString(usage.Speed) {
	case "standard":
		v := false
		fields.FastMode = &v
	case "fast":
		v := true
		fields.FastMode = &v
	}
	return fields
}

// Only keyed graph references and whitelisted fields enter the decoder frontier.
// Sequence breaks equal source timestamps without persisting byte offsets.
type claudeSessionNode struct {
	ID       string              `json:"id"`
	Parent   string              `json:"parent,omitempty"`
	Message  string              `json:"message,omitempty"`
	Kind     string              `json:"kind"`
	At       time.Time           `json:"at"`
	Fields   ClaudeSessionFields `json:"fields"`
	Complete bool                `json:"complete,omitempty"`
	Index    int                 `json:"index"`
}
type claudeSessionFile struct {
	SessionKey string              `json:"sessionKey"`
	Origin     string              `json:"origin,omitempty"`
	Excluded   bool                `json:"excluded,omitempty"`
	Invalid    bool                `json:"invalid,omitempty"`
	Omitted    bool                `json:"omitted,omitempty"`
	Nodes      []claudeSessionNode `json:"nodes"`
}
type claudeSessionCandidate struct {
	observation ClaudeSessionObservation
	interactive bool
}

func claudeSessionHash(key []byte, profile, id string) string {
	h := hmac.New(sha256.New, key)
	_, _ = h.Write([]byte("claude-session-v1\x00" + profile + "\x00" + id))
	return hex.EncodeToString(h.Sum(nil))
}

func decodeClaudeSessionLine(a localusage.HistoryAccess, file *claudeSessionFile, session string, data []byte, now time.Time) {
	keyed := func(domain, id string) string {
		if id == "" {
			return ""
		}
		return claudeSessionHash(a.Key, a.ProfileRef, domain+"\x00"+session+"\x00"+id)
	}
	var row struct {
		Type        string          `json:"type"`
		ID          string          `json:"uuid"`
		Parent      string          `json:"parentUuid"`
		Session     string          `json:"sessionId"`
		Timestamp   string          `json:"timestamp"`
		Sidechain   bool            `json:"isSidechain"`
		Meta        bool            `json:"isMeta"`
		Compact     bool            `json:"isCompactSummary"`
		APIError    bool            `json:"isApiErrorMessage"`
		Agent       string          `json:"agentId"`
		Team        string          `json:"teamName"`
		Entrypoint  string          `json:"entrypoint"`
		SessionKind string          `json:"sessionKind"`
		Error       json.RawMessage `json:"error"`
		Message     struct {
			ID    string          `json:"id"`
			Model json.RawMessage `json:"model"`
			Role  string          `json:"role"`
			Stop  json.RawMessage `json:"stop_reason"`
		} `json:"message"`
	}
	if json.Unmarshal(data, &row) != nil {
		file.Invalid = true
		return
	}
	if row.Sidechain || row.Meta || row.Compact || row.Agent != "" || row.Team != "" || row.APIError || (len(row.Error) > 0 && string(row.Error) != "null") || claudeFieldString(row.Message.Model) == "<synthetic>" {
		return
	}
	switch row.Type {
	case "user", "assistant", "progress", "system", "attachment":
	default:
		return
	}
	// Progress is retained only as a keyed ancestry link for eligible children.
	// Its timestamp and classification cannot select/reclassify a conversation.
	if row.Type != "progress" {
		if row.Session != "" && row.Session != session {
			file.Invalid = true
			return
		}
		switch row.Entrypoint {
		case "sdk-cli", "sdk-ts", "sdk-py":
			file.Excluded = true
		case "cli", "claude-vscode", "claude-desktop":
			value := "cli"
			if row.Entrypoint == "claude-vscode" {
				value = "vscode"
			}
			if row.Entrypoint == "claude-desktop" {
				value = "desktop"
			}
			if file.Origin != "" && file.Origin != value {
				file.Invalid = true
				file.Excluded = true
			}
			file.Origin = value
		}
		if row.SessionKind == "daemon" || row.SessionKind == "daemon-worker" {
			file.Excluded = true
		}
	} else if row.Session != "" && row.Session != session {
		return
	}
	if !claudeSessionOpaque.MatchString(row.ID) || (row.Parent != "" && !claudeSessionOpaque.MatchString(row.Parent)) {
		if row.Type == "progress" {
			return
		}
		file.Invalid = true
		return
	}
	var at time.Time
	if row.Type != "progress" {
		parsed, err := time.Parse(time.RFC3339Nano, row.Timestamp)
		if err != nil || parsed.After(now) {
			file.Invalid = true
			return
		}
		at = parsed.UTC()
	}
	node := claudeSessionNode{ID: keyed("node", row.ID), Parent: keyed("node", row.Parent), Message: keyed("message", row.Message.ID), Kind: row.Type, At: at.UTC(), Index: len(file.Nodes)}
	if row.Type == "assistant" {
		if row.Message.Role != "" && row.Message.Role != "assistant" {
			file.Invalid = true
			return
		}
		node.Fields = parseClaudeSessionFields(data)
		switch claudeFieldString(row.Message.Stop) {
		case "end_turn", "tool_use", "max_tokens", "stop_sequence", "pause_turn", "refusal", "model_context_window_exceeded":
			node.Complete = true
		}
	}

	for _, old := range file.Nodes {
		if old.ID != node.ID {
			continue
		}
		if node.Kind == "progress" && (old.Kind != "progress" || old.Parent != node.Parent) {
			return
		}
		if old.Parent != node.Parent {
			file.Invalid = true
			return
		}
		sameFast := old.Fields.FastMode == nil && node.Fields.FastMode == nil
		if old.Fields.FastMode != nil && node.Fields.FastMode != nil {
			sameFast = *old.Fields.FastMode == *node.Fields.FastMode
		}
		if old.Message == node.Message && old.Kind == node.Kind && old.At.Equal(node.At) && old.Complete == node.Complete && old.Fields.Model == node.Fields.Model && old.Fields.Effort == node.Fields.Effort && sameFast {
			return
		}
	}
	file.Nodes = append(file.Nodes, node)
}

func claudeSessionFileProjection(file claudeSessionFile) (*claudeSessionCandidate, bool) {
	partial := file.Invalid || file.Omitted
	nodes := map[string]claudeSessionNode{}
	all := file.Nodes
	for _, node := range all {
		nodes[node.ID] = node
	}
	parents := map[string]bool{}
	mainNodes := 0
	for _, node := range nodes {
		if node.Kind == "progress" {
			continue
		}
		mainNodes++
		// Only an eligible main child removes an ancestor from leaf candidacy.
		// Follow neutral progress links without letting background progress
		// suppress a conversation leaf on another branch.
		parent := node.Parent
		seen := map[string]bool{}
		for parent != "" && !seen[parent] {
			seen[parent] = true
			ancestor, ok := nodes[parent]
			if !ok || ancestor.Kind != "progress" {
				parents[parent] = true
				break
			}
			parent = ancestor.Parent
		}
	}
	var leaf *claudeSessionNode
	for id, node := range nodes {
		if node.Kind == "progress" || parents[id] {
			continue
		}
		if leaf == nil || node.At.After(leaf.At) || (node.At.Equal(leaf.At) && node.Index > leaf.Index) {
			n := node
			leaf = &n
		}
	}
	if leaf == nil {
		return nil, mainNodes == 0 && !partial
	}
	var selected *claudeSessionNode
	seen := map[string]bool{}
	for node := leaf; node != nil; {
		if seen[node.ID] {
			return nil, false
		}
		seen[node.ID] = true
		if node.Kind == "assistant" && node.Complete {
			if selected == nil {
				selected = node
			}
		}
		if node.Parent == "" {
			break
		}
		parent, ok := nodes[node.Parent]
		if !ok {
			partial = true
			break
		}
		node = &parent
	}
	if selected == nil {
		return nil, !partial
	}
	fields := selected.Fields
	if selected.Message != "" {
		model, effort := "", ""
		var fast *bool
		modelConflict, effortConflict, fastConflict := false, false, false
		for _, node := range all {
			if node.Kind != "assistant" || !node.Complete || node.Message != selected.Message {
				continue
			}
			if node.Fields.Model != "" {
				if model != "" && model != node.Fields.Model {
					modelConflict = true
				}
				model = node.Fields.Model
			}
			if node.Fields.Effort != "" {
				if effort != "" && effort != node.Fields.Effort {
					effortConflict = true
				}
				effort = node.Fields.Effort
			}
			if node.Fields.FastMode != nil {
				if fast != nil && *fast != *node.Fields.FastMode {
					fastConflict = true
				}
				fast = node.Fields.FastMode
			}
			if node.Index > selected.Index {
				fields = node.Fields
			}
		}
		if modelConflict {
			fields.Model = ""
		}
		if effortConflict {
			fields.Effort = ""
		}
		if fastConflict {
			fields.FastMode = nil
		}
	}
	candidate := &claudeSessionCandidate{
		interactive: file.Origin != "" && !file.Excluded,
		observation: ClaudeSessionObservation{ClaudeSessionFields: fields, SessionKey: file.SessionKey, ObservedAt: selected.At, Origin: file.Origin},
	}
	return candidate, !partial
}

// ProjectClaudeSessions is a pure batch convenience wrapper around the same
// reducer used by RefreshClaudeSessions. It owns no discovery or cursor state.
func ProjectClaudeSessions(a localusage.HistoryAccess, batches []ClaudeSessionBatch, caller string, now time.Time) ClaudeSessionProjection {
	result := ClaudeSessionProjection{Availability: "unknown", Beta: true, Sessions: []ClaudeSessionObservation{}}
	if blocked := claudeSessionAdmission(a); blocked != "" {
		result.Availability = blocked
		return result
	}
	if len(batches) > 256 {
		result.Availability = "partial"
		return result
	}
	reduce := ClaudeSessionReducer(a, now)
	state := localusage.ProjectionState{}
	refs := []string{}
	complete := true
	for _, b := range batches {
		ref := claudeSessionHash(a.Key, a.ProfileRef, "file\x00"+b.ExpectedSessionID)
		refs = append(refs, ref)
		complete = complete && b.CompleteDiscovery
		var err error
		state, err = reduce(context.Background(), state, localusage.ProjectionBatch{FileRef: ref, SessionID: b.ExpectedSessionID, Reset: "initial", Lines: b.Records})
		if err != nil {
			result.Availability = "partial"
			return result
		}
	}
	state, err := reduce(context.Background(), state, localusage.ProjectionBatch{Final: true, DiscoveryComplete: complete, RecoveryComplete: complete, LiveFileRefs: refs})
	if err != nil {
		result.Availability = "partial"
		return result
	}
	result = selectClaudeSessions(state.Snapshot, a, caller)
	if state.Incomplete {
		result.Availability = "partial"
		result.Selected = nil
	}
	return result
}

func claudeSessionAdmission(a localusage.HistoryAccess) string {
	if a.StillValid != nil && !a.StillValid() {
		return "consent_required"
	}
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("MODELPLAN_READERS")))
	if mode == "off" || a.Privacy == "off" {
		return "off"
	}
	if a.Denied {
		return "denied"
	}
	if !a.Allowed {
		return "consent_required"
	}
	profile, err := hex.DecodeString(a.ProfileRef)
	if len(a.Key) != 32 || err != nil || len(profile) != 32 || (a.Privacy != "" && a.Privacy != "automatic" && a.Privacy != "passive") || (mode != "" && mode != "automatic" && mode != "passive") {
		return "privacy_blocked"
	}
	return ""
}

// The selected native projection replaces optional snapshots as one unit;
// missing values remain unknown. An optional hook never fills the holes.
func applyClaudeSessionProjection(account *Account, projection ClaudeSessionProjection) {
	account.Harness = &Harness{}
	if selected := projection.Selected; selected != nil {
		account.Harness = &Harness{Model: selected.Model, Effort: selected.Effort, FastMode: selected.FastMode, SessionKey: selected.SessionKey, ObservedAt: &selected.ObservedAt, Attribution: selected.Attribution, Origin: selected.Origin}
	}
}

// The persisted snapshot is independent of the invocation's caller. Selection is
// repeated from this sanitized snapshot even when all source files are unchanged.
type claudeSessionSnapshot struct {
	Sessions []claudeSessionSnapshotEntry `json:"sessions"`
}
type claudeSessionSnapshotEntry struct {
	ClaudeSessionObservation
	Interactive bool `json:"interactive,omitempty"`
}

// ClaudeSessionReducer implements localusage.ProjectionReducer without I/O. Only
// keyed graph references, enum classification, timestamps and approved fields are
// retained. A lost prefix or frontier bound cannot establish complete ancestry.
func ClaudeSessionReducer(a localusage.HistoryAccess, now time.Time) localusage.ProjectionReducer {
	// Do not retain a caller-owned mutable key buffer across reducer calls.
	a.Key = append([]byte(nil), a.Key...)
	return func(ctx context.Context, state localusage.ProjectionState, batch localusage.ProjectionBatch) (localusage.ProjectionState, error) {
		if ctx.Err() != nil || claudeSessionAdmission(a) != "" {
			return state, errors.New("Claude session read unavailable")
		}
		files := map[string]claudeSessionFile{}
		if len(state.Decoder) > 0 {
			if err := json.Unmarshal(state.Decoder, &files); err != nil {
				return state, errors.New("Claude session frontier invalid")
			}
		}
		if batch.Final {
			if batch.DiscoveryComplete {
				live := map[string]bool{}
				for _, ref := range batch.LiveFileRefs {
					live[ref] = true
				}
				for ref := range files {
					if !live[ref] {
						delete(files, ref)
					}
				}
			}
			state.Incomplete = !batch.DiscoveryComplete || !batch.RecoveryComplete
			snapshot := claudeSessionSnapshot{Sessions: []claudeSessionSnapshotEntry{}}
			state.ObservedAt = time.Time{}
			for _, file := range files {
				candidate, complete := claudeSessionFileProjection(file)
				state.Incomplete = state.Incomplete || !complete
				if candidate == nil {
					continue
				}
				snapshot.Sessions = append(snapshot.Sessions, claudeSessionSnapshotEntry{ClaudeSessionObservation: candidate.observation, Interactive: candidate.interactive})
				if candidate.observation.ObservedAt.After(state.ObservedAt) {
					state.ObservedAt = candidate.observation.ObservedAt
				}
			}
			sort.Slice(snapshot.Sessions, func(i, j int) bool {
				left, right := snapshot.Sessions[i], snapshot.Sessions[j]
				if left.ObservedAt.Equal(right.ObservedAt) {
					return left.SessionKey < right.SessionKey
				}
				return left.ObservedAt.After(right.ObservedAt)
			})
			if !state.Incomplete {
				state.Snapshot, _ = json.Marshal(snapshot)
				if len(state.Snapshot) > 64<<10 {
					state.Incomplete = true
					state.Snapshot = nil
				}
			}
		} else {
			if !claudeSessionOpaque.MatchString(batch.SessionID) || !claudeKeyedRef(batch.FileRef) {
				return state, errors.New("Claude session batch invalid")
			}
			if batch.Reset != "" {
				delete(files, batch.FileRef)
			}
			file := files[batch.FileRef]
			sessionKey := claudeSessionHash(a.Key, a.ProfileRef, batch.SessionID)
			if file.SessionKey != "" && file.SessionKey != sessionKey {
				return state, errors.New("Claude session scope invalid")
			}
			file.SessionKey = sessionKey
			file.Omitted = file.Omitted || batch.PrefixOmitted
			total := 0
			for _, f := range files {
				total += len(f.Nodes)
			}
			// Bound the semantic frontier separately from the engine's byte budgets.
			// Reaching this limit stays unknown until replacement/reset; it never guesses.
			priorNodes := len(file.Nodes)
			batchBytes := 0
			if len(batch.Lines) > 4096 {
				return state, errors.New("Claude session batch too large")
			}
			for _, line := range batch.Lines {
				if ctx.Err() != nil {
					return state, ctx.Err()
				}
				batchBytes += len(line)
				if len(line) > 1<<20 || batchBytes > 8<<20 {
					return state, errors.New("Claude session batch too large")
				}
				if total >= 4096 {
					file.Invalid = true
					continue
				}
				count := len(file.Nodes)
				decodeClaudeSessionLine(a, &file, batch.SessionID, line, now)
				total += len(file.Nodes) - count
			}
			files[batch.FileRef] = file
			if len(files) > 256 {
				return state, errors.New("Claude session frontier too large")
			}
			encoded, _ := json.Marshal(files)
			if len(encoded) > 1800<<10 {
				file.Nodes, file.Invalid = file.Nodes[:priorNodes], true
				files[batch.FileRef] = file
			}
		}
		state.Decoder, _ = json.Marshal(files)
		return state, nil
	}
}
func claudeKeyedRef(ref string) bool {
	b, err := hex.DecodeString(ref)
	return err == nil && len(b) == 32
}

func selectClaudeSessions(snapshot []byte, a localusage.HistoryAccess, caller string) ClaudeSessionProjection {
	r := ClaudeSessionProjection{Availability: "unknown", Beta: true, Sessions: []ClaudeSessionObservation{}}
	if blocked := claudeSessionAdmission(a); blocked != "" {
		r.Availability = blocked
		return r
	}
	var s claudeSessionSnapshot
	if len(snapshot) == 0 {
		r.CallerMissing = caller != ""
		return r
	}
	if json.Unmarshal(snapshot, &s) != nil {
		return r
	}
	callerKey := ""
	if caller != "" {
		callerKey = claudeSessionHash(a.Key, a.ProfileRef, caller)
	}
	var current, recent *ClaudeSessionObservation
	for _, entry := range s.Sessions {
		observation := entry.ClaudeSessionObservation
		r.Sessions = append(r.Sessions, observation)
		if callerKey != "" && observation.SessionKey == callerKey {
			value := observation
			value.Attribution = "current-thread"
			current = &value
		}
		if recent == nil && entry.Interactive {
			value := observation
			value.Attribution = "recent-thread"
			recent = &value
		}
	}
	r.Selected = current
	if current == nil {
		r.Selected = recent
		r.CallerMissing = caller != ""
	}
	if r.Selected != nil {
		r.Availability = "ok"
	}
	return r
}

// RefreshClaudeSessions is the explicit local ingestion entry point. CLIJIT
// supplies the consent-scoped root/access and suspends scheduling while asleep
// or hidden. No network quota schedule or provider account reader is involved.
func RefreshClaudeSessions(ctx context.Context, root, cache string, a localusage.HistoryAccess, now time.Time) localusage.ProjectionResult {
	return localusage.RefreshProjection(ctx, "claude", root, cache, a, now, ClaudeSessionReducer(a, now))
}

// ReadClaudeSessions reads only ModelPlan's cache, then selects the caller from
// keyed sessions. A caller change never requires a source reread or cache write.
func ReadClaudeSessions(cache string, a localusage.HistoryAccess, caller string, now time.Time) (ClaudeSessionProjection, localusage.ProjectionResult) {
	result := localusage.ReadProjectionCache(cache, "claude", a, now)
	projection := selectClaudeSessions(result.Snapshot, a, caller)
	if result.Availability != "ok" {
		projection.Availability = result.Availability
	}
	return projection, result
}

// ForgetClaudeSessions is called after cancellation/join, including after consent
// revocation. The engine retains the local reservation and touches no tool files.
func ForgetClaudeSessions(cache string, a localusage.HistoryAccess) error {
	return localusage.ForgetProjectionProfile(cache, "claude", a)
}

// An admitted native projection replaces optional hook metadata as one unit,
// including unknown fields. A session-only source requires no plugin or account.
func applyClaudeSessions(r *Report, p Paths, now time.Time) {
	if p.ClaudeSessionAccess == nil {
		return
	}
	projection, _ := ReadClaudeSessions(p.Cache, *p.ClaudeSessionAccess, p.ClaudeSession, now)
	r.Sources = append(r.Sources, SourceStatus{Source: "claude-session", Status: projection.Availability, Beta: true})
	found := false
	for i := range r.Accounts {
		if r.Accounts[i].Source == "claude-code" {
			applyClaudeSessionProjection(&r.Accounts[i], projection)
			found = true
		}
	}
	if !found && projection.Selected != nil {
		account := Account{Source: "claude-code", Via: "local", ObservedAt: projection.Selected.ObservedAt, Windows: []Window{}}
		applyClaudeSessionProjection(&account, projection)
		r.Accounts = append(r.Accounts, account)
	}
}
