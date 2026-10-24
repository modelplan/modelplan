package localusage

import (
	"os"
	"path/filepath"
	"strings"
	"time"
)

// The same consent, bounds, privacy, HMAC identities and aggregation serve both
// CLI families. Only discovery roots and record normalization differ.
type historyTool struct {
	source, stopEnv, messageType string
	home                         func(string) string
	paths                        func(string) []string
	bases                        []string
	filename                     func(string) bool
	parse                        func([]byte, bool) ([]record, error)
}

var geminiTool = historyTool{
	source: "gemini", stopEnv: "MODELPLAN_GEMINI", messageType: "gemini", home: GeminiHome,
	paths: func(root string) []string {
		return []string{filepath.Join(root, "tmp", "*", "chats", "session-*.{json,jsonl}"), filepath.Join(root, "*", "chats", "session-*.{json,jsonl}")}
	},
	bases: []string{"tmp", ""},
	filename: func(name string) bool {
		return strings.HasPrefix(name, "session-") && (strings.HasSuffix(name, ".json") || strings.HasSuffix(name, ".jsonl"))
	},
	parse: parseRecords,
}
var qwenTool = historyTool{
	source: "qwen", stopEnv: "MODELPLAN_QWEN", messageType: "assistant", home: QwenHome,
	paths: func(root string) []string {
		return []string{filepath.Join(root, "projects", "*", "chats", "{*.jsonl,session-*.json}"), filepath.Join(root, "tmp", "*", "chats", "{*.jsonl,session-*.json}"), filepath.Join(root, "*", "chats", "{*.jsonl,session-*.json}")}
	},
	bases: []string{"projects", "tmp", ""},
	filename: func(name string) bool {
		return strings.HasSuffix(name, ".jsonl") || (strings.HasPrefix(name, "session-") && strings.HasSuffix(name, ".json"))
	},
	parse: parseQwenRecords,
}

func QwenHome(home string) string {
	if p := os.Getenv("MODELPLAN_QWEN_HOME"); p != "" && filepath.IsAbs(p) {
		return filepath.Clean(p)
	}
	return filepath.Join(home, ".qwen")
}
func SetQwen(home string, on bool) error           { return setSource(home, "qwen", on) }
func QwenStatus(home string, now time.Time) Report { return sourceStatus(home, now, qwenTool) }
func ReadQwen(home string, now time.Time) Report   { return readHistory(home, now, qwenTool) }

type qwenTokens struct {
	Input    *int64 `json:"promptTokenCount"`
	Output   *int64 `json:"candidatesTokenCount"`
	Cached   *int64 `json:"cachedContentTokenCount"`
	Thoughts *int64 `json:"thoughtsTokenCount"`
	Tool     *int64 `json:"toolUsePromptTokenCount"`
	Total    *int64 `json:"totalTokenCount"`
}

// First-party Qwen ChatRecord stores uuid/type=assistant/usageMetadata; modern
// Storage.getProjectDir()/chats/<sessionId>.jsonl differs from Gemini snapshots.
// Early Gemini-style Qwen snapshots/checkpoints retain id/type=gemini/tokens.
// Conversation content/tool payloads are never decoded into the selected types.
func parseQwenRecords(b []byte, jsonl bool) ([]record, error) {
	records, err := parseRecords(b, jsonl)
	if err != nil {
		return nil, err
	}
	normalize := func(m *message) {
		if m.Type == "gemini" {
			m.Type = "assistant"
		}
	}
	for i := range records {
		r := &records[i]
		if r.Project == "" {
			r.Project = r.CWD
		}
		if r.UUID != "" {
			r.ID = r.UUID
			// User/tool/system records remain distinct and cannot become usage.
			if u := r.UsageMetadata; u != nil && r.Type == "assistant" {
				r.Tokens = &tokens{u.Input, u.Output, u.Cached, u.Thoughts, u.Tool, u.Total}
			}
		} else {
			normalize(&r.message)
		}
		for j := range r.Messages {
			normalize(&r.Messages[j])
		}
		if r.Set != nil {
			for j := range r.Set.Messages {
				normalize(&r.Set.Messages[j])
			}
		}
	}
	return records, nil
}
