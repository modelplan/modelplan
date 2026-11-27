package speed

import (
	"database/sql"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// A Codex thread's title is threads.name in its state database, the app-generated or user-set name. Its title
// column is the first message, which is conversation content and never read (Token Monitor's titleForRow and
// isGeneratedTitle make the same split). The database is opened read-only; only the name of a thread this ledger
// already tracks is read.

var codexRolloutThread = regexp.MustCompile(`(?i)([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.jsonl(?:\.zst)?$`)

// codexThreadOfPath: the thread id a rollout file name ends with.
func codexThreadOfPath(p string) string {
	if m := codexRolloutThread.FindStringSubmatch(filepath.Base(p)); m != nil {
		return strings.ToLower(m[1])
	}
	return ""
}

// codexStateDBs: the state databases of the Codex home, the newest version first.
func codexStateDBs() []string {
	home := codexHomeDir()
	if home == "" {
		return nil
	}
	type v struct {
		p string
		n int
	}
	var found []v
	for _, dir := range []string{home, filepath.Join(home, "sqlite")} {
		ents, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, e := range ents {
			name := e.Name()
			if strings.HasPrefix(name, "state_") && strings.HasSuffix(name, ".sqlite") {
				if n, err := strconv.Atoi(strings.TrimSuffix(strings.TrimPrefix(name, "state_"), ".sqlite")); err == nil {
					found = append(found, v{filepath.Join(dir, name), n})
				}
			}
		}
	}
	sort.Slice(found, func(i, j int) bool { return found[i].n > found[j].n })
	out := make([]string, len(found))
	for i, f := range found {
		out[i] = f.p
	}
	return out
}

// codexTitle: the thread's generated or user-set name, "" when it has none. Read once per thread per run.
func (l *PerfLedger) codexTitle(thread string) string {
	if t, ok := l.codexNames[thread]; ok {
		return t
	}
	if l.codexNames == nil {
		l.codexNames = map[string]string{}
	}
	name := ""
	for _, path := range codexStateDBs() {
		db, err := openRO(path)
		if err != nil {
			continue
		}
		if hasColumns(db, "threads", "id", "name") {
			var n sql.NullString
			if db.QueryRow(`SELECT name FROM threads WHERE id = ?`, thread).Scan(&n) == nil && strings.TrimSpace(n.String) != "" {
				name = n.String
			}
		}
		db.Close()
		if name != "" {
			break
		}
	}
	l.codexNames[thread] = name
	return name
}
