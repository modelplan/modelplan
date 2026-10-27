package quota

// Projection only. File discovery, incremental I/O and atomic checkpoint/snapshot
// commit belong to READERS (PR228). Its public API currently lacks this seam;
// this adapter deliberately does not implement a second cursor.
// Protocol evidence: Anthropic SDK Python 717cea0 sessions.py and TypeScript SDK
// 0.3.301, read-only; independently implemented. The owner confirmed field shapes
// on 2026-10-27. No source, transcript body or raw identity is persisted here.

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
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

type claudeSessionNode struct {
	id, parent, message string
	kind                string
	at                  time.Time
	fields              ClaudeSessionFields
	complete            bool
	index               int
}

type claudeSessionCandidate struct {
	observation       ClaudeSessionObservation
	rawID             string // transient caller matching only; never returned or cached
	interactive       bool
	completeDiscovery bool
}

func claudeSessionHash(key []byte, profile, id string) string {
	h := hmac.New(sha256.New, key)
	_, _ = h.Write([]byte("claude-session-v1\x00" + profile + "\x00" + id))
	return hex.EncodeToString(h.Sum(nil))
}

func claudeSessionBatchProjection(a localusage.HistoryAccess, batch ClaudeSessionBatch, now time.Time) (*claudeSessionCandidate, bool) {
	if !claudeSessionOpaque.MatchString(batch.ExpectedSessionID) || len(batch.Records) > 4096 {
		return nil, false
	}
	nodes := map[string]claudeSessionNode{}
	all := []claudeSessionNode{}
	origin := ""
	excluded := false
	partial := !batch.CompleteDiscovery
	total := 0
	for index, data := range batch.Records {
		total += len(data)
		if len(data) > 1<<20 || total > 8<<20 {
			return nil, false
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
			partial = true
			continue
		}
		if row.Session != "" && row.Session != batch.ExpectedSessionID {
			return nil, false
		}
		switch row.Entrypoint {
		case "sdk-cli", "sdk-ts", "sdk-py":
			excluded = true
		case "cli", "claude-vscode", "claude-desktop":
			value := "cli"
			if row.Entrypoint == "claude-vscode" {
				value = "vscode"
			}
			if row.Entrypoint == "claude-desktop" {
				value = "desktop"
			}
			if origin != "" && origin != value {
				partial = true
				excluded = true
			}
			origin = value
		}
		if row.SessionKind == "daemon" || row.SessionKind == "daemon-worker" {
			excluded = true
		}
		if row.Sidechain || row.Meta || row.Compact || row.Agent != "" || row.Team != "" || row.APIError || (len(row.Error) > 0 && string(row.Error) != "null") || claudeFieldString(row.Message.Model) == "<synthetic>" {
			continue
		}
		switch row.Type {
		case "user", "assistant", "progress", "system", "attachment":
		default:
			continue
		}
		if !claudeSessionOpaque.MatchString(row.ID) || (row.Parent != "" && !claudeSessionOpaque.MatchString(row.Parent)) {
			partial = true
			continue
		}
		at, err := time.Parse(time.RFC3339Nano, row.Timestamp)
		if err != nil || at.After(now.Add(5*time.Minute)) {
			partial = true
			continue
		}
		node := claudeSessionNode{id: row.ID, parent: row.Parent, message: row.Message.ID, kind: row.Type, at: at.UTC(), index: index}
		if row.Type == "assistant" {
			if row.Message.Role != "" && row.Message.Role != "assistant" {
				partial = true
				continue
			}
			node.fields = parseClaudeSessionFields(data)
			switch claudeFieldString(row.Message.Stop) {
			case "end_turn", "tool_use", "max_tokens", "stop_sequence", "pause_turn", "refusal", "model_context_window_exceeded":
				node.complete = true
			}
		}
		if old, ok := nodes[node.id]; ok && old.parent != node.parent {
			return nil, false
		}
		nodes[node.id] = node
		all = append(all, node)
	}
	parents := map[string]bool{}
	for _, node := range nodes {
		if node.parent != "" {
			parents[node.parent] = true
		}
	}
	var leaf *claudeSessionNode
	for id, node := range nodes {
		if parents[id] {
			continue
		}
		if leaf == nil || node.at.After(leaf.at) || (node.at.Equal(leaf.at) && node.index > leaf.index) {
			n := node
			leaf = &n
		}
	}
	if leaf == nil {
		return nil, false
	}
	var selected *claudeSessionNode
	seen := map[string]bool{}
	for node := leaf; node != nil; {
		if seen[node.id] {
			return nil, false
		}
		seen[node.id] = true
		if node.kind == "assistant" && node.complete {
			selected = node
			break
		}
		if node.parent == "" {
			break
		}
		parent, ok := nodes[node.parent]
		if !ok {
			partial = true
			break
		}
		node = &parent
	}
	if selected == nil {
		return nil, !partial
	}
	fields := selected.fields
	if selected.message != "" {
		model, effort := "", ""
		var fast *bool
		modelConflict, effortConflict, fastConflict := false, false, false
		for _, node := range all {
			if node.kind != "assistant" || !node.complete || node.message != selected.message {
				continue
			}
			if node.fields.Model != "" {
				if model != "" && model != node.fields.Model {
					modelConflict = true
				}
				model = node.fields.Model
			}
			if node.fields.Effort != "" {
				if effort != "" && effort != node.fields.Effort {
					effortConflict = true
				}
				effort = node.fields.Effort
			}
			if node.fields.FastMode != nil {
				if fast != nil && *fast != *node.fields.FastMode {
					fastConflict = true
				}
				fast = node.fields.FastMode
			}
			if node.index > selected.index {
				fields = node.fields
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
		rawID: batch.ExpectedSessionID, interactive: origin != "" && !excluded, completeDiscovery: batch.CompleteDiscovery && !partial,
		observation: ClaudeSessionObservation{ClaudeSessionFields: fields, SessionKey: claudeSessionHash(a.Key, a.ProfileRef, batch.ExpectedSessionID), ObservedAt: selected.at, Origin: origin},
	}
	return candidate, !partial
}

// ProjectClaudeSessions performs no file, credential, Keychain, process or network
// I/O. READERS must supply bounded records and atomically commit this sanitized
// result together with its cursor; that exported seam is the PR228 dependency.
func ProjectClaudeSessions(a localusage.HistoryAccess, batches []ClaudeSessionBatch, caller string, now time.Time) ClaudeSessionProjection {
	result := ClaudeSessionProjection{Availability: "unknown", Beta: true, Sessions: []ClaudeSessionObservation{}}
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("MODELPLAN_READERS")))
	if mode == "off" || a.Privacy == "off" {
		result.Availability = "off"
		return result
	}
	if a.Denied {
		result.Availability = "denied"
		return result
	}
	if !a.Allowed {
		result.Availability = "consent_required"
		return result
	}
	profile, err := hex.DecodeString(a.ProfileRef)
	if len(a.Key) != 32 || err != nil || len(profile) != 32 || (a.Privacy != "" && a.Privacy != "automatic" && a.Privacy != "passive") || (mode != "" && mode != "automatic" && mode != "passive") {
		result.Availability = "privacy_blocked"
		return result
	}
	if len(batches) > 128 {
		result.Availability = "partial"
		return result
	}
	candidates := []claudeSessionCandidate{}
	complete := true
	for _, batch := range batches {
		candidate, ok := claudeSessionBatchProjection(a, batch, now)
		complete = complete && ok
		if candidate != nil {
			candidates = append(candidates, *candidate)
		}
	}
	sort.SliceStable(candidates, func(i, j int) bool {
		if candidates[i].observation.ObservedAt.Equal(candidates[j].observation.ObservedAt) {
			return candidates[i].observation.SessionKey < candidates[j].observation.SessionKey
		}
		return candidates[i].observation.ObservedAt.After(candidates[j].observation.ObservedAt)
	})
	by := map[string]bool{}
	var current, recent *ClaudeSessionObservation
	for _, candidate := range candidates {
		observation := candidate.observation
		if by[observation.SessionKey] {
			continue
		}
		by[observation.SessionKey] = true
		result.Sessions = append(result.Sessions, observation)
		if caller != "" && caller == candidate.rawID {
			value := observation
			value.Attribution = "current-thread"
			current = &value
		}
		if recent == nil && candidate.interactive && candidate.completeDiscovery {
			value := observation
			value.Attribution = "recent-thread"
			recent = &value
		}
	}
	result.Selected = current
	if current == nil {
		result.Selected = recent
		result.CallerMissing = caller != ""
	}
	if result.Selected != nil {
		result.Availability = "ok"
	}
	if !complete {
		result.Availability = "partial"
		if current == nil {
			result.Selected = nil
		}
	}
	return result
}

// The selected native projection replaces optional snapshots as one unit;
// missing values remain unknown. An optional hook never fills the holes.
func applyClaudeSessionProjection(account *Account, projection ClaudeSessionProjection) {
	account.Harness = &Harness{}
	if selected := projection.Selected; selected != nil {
		account.Harness = &Harness{Model: selected.Model, Effort: selected.Effort, FastMode: selected.FastMode, SessionKey: selected.SessionKey, ObservedAt: &selected.ObservedAt, Attribution: selected.Attribution, Origin: selected.Origin}
	}
}
