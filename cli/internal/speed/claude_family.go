package speed

import (
	"path/filepath"
	"sort"
	"time"
)

// Claude subagents have their own transcript below <parent>/subagents. Inline sidechain copies
// stay excluded, because there is no reliable distinct session in that case. Only the known
// current transcript and its directly associated subagent files are opened, never arbitrary data.
func (l *PerfLedger) scanClaudeFamily(path string, now time.Time) bool {
	changed := l.scan(path, "claude-code", ParserClaude, newClaude(now), now)
	dir := filepath.Join(filepath.Dir(path), pathBase(path), "subagents")
	files, _ := filepath.Glob(filepath.Join(dir, "*.jsonl"))
	sort.Strings(files)
	if len(files) > maxLive {
		files = files[len(files)-maxLive:]
	}
	for _, f := range files {
		p := newClaude(now)
		p.sidechain = true
		changed = l.scan(f, "claude-code", ParserClaude, p, now) || changed
	}
	return changed
}
func pathBase(path string) string { return filepath.Base(path[:len(path)-len(filepath.Ext(path))]) }
