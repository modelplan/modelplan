// SPDX-License-Identifier: MIT
package localusage

import (
	"path/filepath"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

// accounting applies ccusage's per-tool accounting (tokenacct) to the files
// readHistory has already read within its bounds. It follows ccusage's own
// scope: Gemini files under <root>/tmp (ccusage reads ~/.gemini/tmp), and
// Qwen projects/<project>/chats/*.jsonl (ccusage's discover_chat_files).
type accounting struct {
	root, source string
	gemini       []tokenacct.Entry
	qwen         [][]tokenacct.QwenEntry
}

func (a *accounting) read(f candidate, b []byte) {
	rel, err := filepath.Rel(a.root, f.path)
	if err != nil {
		return
	}
	parts := strings.Split(filepath.ToSlash(rel), "/")
	switch {
	case a.source == "gemini" && len(parts) > 1 && parts[0] == "tmp":
		a.gemini = append(a.gemini, tokenacct.Gemini(b, strings.HasSuffix(f.path, ".jsonl"), f.at)...)
	case a.source == "qwen" && len(parts) == 4 && parts[0] == "projects" && parts[2] == "chats" && strings.HasSuffix(parts[3], ".jsonl"):
		a.qwen = append(a.qwen, tokenacct.Qwen(b, parts[1], strings.TrimSuffix(parts[3], ".jsonl"), f.at))
	}
}

// windows is nil when no file held countable usage, so reports without local
// usage keep their earlier shape.
func (a *accounting) windows(now time.Time) *tokenacct.Windows {
	entries := a.gemini
	if a.source == "qwen" {
		entries = tokenacct.DedupeQwen(a.qwen...)
	}
	if len(entries) == 0 {
		return nil
	}
	w := tokenacct.Summarize(entries, now)
	return &w
}
