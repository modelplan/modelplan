// SPDX-License-Identifier: MIT
package shapecapture

import (
	"fmt"
	"os"
	"sort"
	"strings"
	"testing"
)

// TestWriteFieldList renders the human-readable field list when MODELPLAN_FIELD_LIST names a file.
func TestWriteFieldList(t *testing.T) {
	out := os.Getenv("MODELPLAN_FIELD_LIST")
	if out == "" {
		t.Skip("set MODELPLAN_FIELD_LIST to render the field list")
	}
	var b strings.Builder
	b.WriteString("# Shape capture: field list for owner approval\n\n")
	b.WriteString("Command: `modelplan doctor shapes --tool NAME|all --out DIR` (local only, no network, never automatic).\n\n")
	b.WriteString("## Rules for every tool\n\n")
	b.WriteString("- Only keys on the per-tool allow-list below are written; every other key is dropped (the manifest counts drops, never names them). Map keys that hold paths, ids or project names are therefore always dropped.\n")
	b.WriteString("- Kept kinds: `struct` = key kept, scalar value replaced by a type placeholder, objects and arrays walked (arrays cut at 20 elements); `enum` = a short lowercase token kept only if it passes the pattern guard (no digits run of 9+, no @, slash, URL, uuid, long hex or opaque string), otherwise `<string>`; `time` = replaced by an offset from capture time in whole minutes (`-3600s`, or a number in the source unit).\n")
	b.WriteString("- Numbers: 0 stays 0, other integers become 1 or -1, fractions 1.5 or -1.5, null and booleans unchanged, empty string stays empty, other strings `<string>`.\n")
	b.WriteString("- A key whose name suggests a secret, account, path, prompt or content (token, secret, email, path, cwd, text, content, account, uuid, name, user, ...) is forced to `struct` even if listed as `enum`.\n")
	b.WriteString("- Last guard: the written sample is re-scanned, and the whole file is withheld if any key or string looks like an email, path, URL, JWT, vendor key, bearer value, uuid, PEM block or long hex/opaque string.\n")
	b.WriteString("- Sources are logical names; real paths are never written. JSONL: up to 20 lines with distinct shapes from the first 2000 lines of the 3 newest files. SQLite: opened read-only; allow-listed tables only; column names and declared types, plus 3 newest rows of allow-listed columns only; JSON text cells are parsed and shaped by the same allow-list.\n")
	b.WriteString("- Output goes to an empty directory you name; `manifest.json` lists every kept field per sample.\n\n")
	for _, t := range Tools() {
		fmt.Fprintf(&b, "## %s\n\n", t.Name)
		if t.Note != "" {
			fmt.Fprintf(&b, "%s\n\n", t.Note)
		}
		if len(t.Sources) == 0 {
			b.WriteString("Nothing is captured for this tool.\n\n")
			continue
		}
		for _, s := range t.Sources {
			fmt.Fprintf(&b, "### source `%s` (%s; globs under the tool home: `%s`)\n\n", s.Label, s.Format, strings.Join(s.Glob, "`, `"))
			if len(s.Tables) > 0 {
				fmt.Fprintf(&b, "Tables: `%s`.\n\n", strings.Join(s.Tables, "`, `"))
			}
			var kinds = map[Kind][]string{}
			for k, kind := range s.Allow {
				if kind == Enum && denyKey.MatchString(k) {
					kind = Struct
				}
				kinds[kind] = append(kinds[kind], k)
			}
			for _, kind := range []Kind{Struct, Enum, Time} {
				ks := kinds[kind]
				sort.Strings(ks)
				if len(ks) > 0 {
					fmt.Fprintf(&b, "- %s: `%s`\n", kind, strings.Join(ks, "`, `"))
				}
			}
			b.WriteString("- dropped: every other key, column or table (prompts, message text, paths, ids, names, project keys, account values).\n\n")
		}
	}
	if err := os.WriteFile(out, []byte(b.String()), 0o644); err != nil {
		t.Fatal(err)
	}
}
