// SPDX-License-Identifier: MIT
package speed

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"testing"
)

// The reduced line must decode exactly as the whole line did: same refusal, same values, same
// content block kinds, same accounting record.
var reduceSeeds = []string{
	`{"type":"user","timestamp":"2026-11-01T10:00:00.000Z","message":{"role":"user","content":"hi"},"cwd":"/x"}`,
	`{"type":"user","timestamp":"2026-11-01T10:00:00.000Z","message":{"role":"user","content":[{"tool_use_id":"t","type":"tool_result","content":"a \"quoted\" \\ é 😀 out\n"}]}}`,
	`{"type":"assistant","requestId":"req_1","thinkingDurationMs":1200.5,"effort":"high","message":{"id":"msg_1","model":"claude-x","content":[{"type":"thinking","thinking":"t"},{"type":"text","text":"x"}],"stop_reason":"end_turn","usage":{"input_tokens":3,"cache_read_input_tokens":10,"cache_creation_input_tokens":4,"cache_creation":{"ephemeral_1h_input_tokens":4},"output_tokens":7,"speed":"fast"}},"timestamp":"2026-11-01T10:00:02.000Z","sessionId":"s"}`,
	// Case-folded, escaped and duplicate member names; encoding/json matches them all.
	`{"Type":"assistant","TIMESTAMP":"2026-11-01T10:00:02.000Z","message":{"Model":"m","usage":{"input_tokens":1,"output_tokens":2}}}`,
	`{"type":"assistant","timestamp":"2026-11-01T10:00:02.000Z","message":{"model":"m","usage":{"input_tokens":1,"output_tokens":2}}}`,
	`{"type":"user","type":"assistant","timestamp":"2026-11-01T10:00:02.000Z","message":{"model":"a","model":"b","usage":{"input_tokens":1,"output_tokens":2}}}`,
	`{"type":"assistant","timestamp":"2026-11-01T10:00:02.000Z","message":{"content":[1,"x",null,{"type":7}],"model":"m","usage":{"input_tokens":1,"output_tokens":2}}}`,
	// Wrong kinds: decoding fails or keeps zero values the same way.
	`{"type":"assistant","timestamp":"2026-11-01T10:00:02.000Z","message":"not an object"}`,
	`{"type":"assistant","isSidechain":"yes","timestamp":"2026-11-01T10:00:02.000Z","message":{"model":"m","usage":{"input_tokens":1,"output_tokens":2}}}`,
	`{"type":"assistant","timestamp":"2026-11-01T10:00:02.000Z","message":{"model":"m","usage":{"input_tokens":1e400,"output_tokens":2}}}`,
	`{"type":"assistant","timestamp":null,"message":null}`,
	`[{"type":"assistant"}]`,
	`"type":"user"`,
	// Not JSON: refused.
	`{"type":"user","timestamp":"2026-11-01T10:00:00.000Z","message":{"content":"cut`,
	`{"type":"user","message":{"content":"bad \x escape"}}`,
	"{\"type\":\"user\",\"message\":{\"content\":\"raw \x01 control\"}}",
	`{"type":"user","n":01}`,
	`{"type":"user","n":1.}`,
	`{"type":"user","n":-}`,
	`{"type":"user","n":tru}`,
	`{"type":"user",}`,
	`{"type":"user"} trailing`,
	`{"type":"user","a":[1,]}`,
	`{"type":"user","a":{"b":1,}}`,
	`{"type":"user" "a":1}`,
	`{"type":"user","u":"\u12G4"}`,
	"{\"type\":\"user\",\"bad\":\"\xff\xfe\"}",
	"",
	"   \n",
	"{\"type\":\"assistant\"}\r\n",
}

func decodeBoth(t *testing.T, b []byte) {
	t.Helper()
	doc, ok := reduceLine(b, claudeLineSpec)
	if ok != json.Valid(b) {
		t.Fatalf("valid %v, reduced %v: %q", json.Valid(b), ok, b)
	}
	if !ok {
		return
	}
	var whole, reduced ccLine
	errW, errR := json.Unmarshal(b, &whole), json.Unmarshal(doc, &reduced)
	if (errW == nil) != (errR == nil) {
		t.Fatalf("errors differ %v / %v: %q -> %q", errW, errR, b, doc)
	}
	if errW != nil {
		return
	}
	for _, kind := range []string{"tool_result", "thinking", "text"} {
		if blockIs(whole.Message.Content, kind) != blockIs(reduced.Message.Content, kind) {
			t.Fatalf("block %s differs: %q -> %q", kind, b, doc)
		}
	}
	whole.Message.Content, reduced.Message.Content = nil, nil
	if !reflect.DeepEqual(whole, reduced) {
		t.Fatalf("decoded differ:\n%+v\n%+v\n%q -> %q", whole, reduced, b, doc)
	}
}

func accountingBoth(t *testing.T, lines [][]byte) {
	t.Helper()
	run := func(reduce bool) []usageRecord {
		old := reduceClaudeLines
		reduceClaudeLines = reduce
		defer func() { reduceClaudeLines = old }()
		p := newAccountingParser("claude-code", "file")
		for _, l := range lines {
			p.line(0, 0, l)
		}
		return p.records
	}
	if a, b := run(false), run(true); !reflect.DeepEqual(a, b) {
		t.Fatalf("accounting records differ:\n%+v\n%+v", a, b)
	}
}

func TestReduceLineDecodesAsWholeLine(t *testing.T) {
	var lines [][]byte
	for _, s := range reduceSeeds {
		decodeBoth(t, []byte(s))
		lines = append(lines, []byte(s))
		// Every cut of a seed: a line torn by a crash or a partial write.
		for i := 0; i < len(s); i += 7 {
			decodeBoth(t, []byte(s[:i]))
		}
	}
	accountingBoth(t, lines)
}

func FuzzReduceLine(f *testing.F) {
	for _, s := range reduceSeeds {
		f.Add([]byte(s))
	}
	f.Fuzz(func(t *testing.T, b []byte) {
		decodeBoth(t, b)
		accountingBoth(t, [][]byte{b})
	})
}

// The first-run import with reduced lines writes byte for byte what decoding whole lines wrote, on a
// generated month of Claude Code and Codex history with damaged lines mixed in.
func TestImportReducedMatchesWholeLines(t *testing.T) {
	utc(t)
	root := t.TempDir()
	claude, codex := filepath.Join(root, "claude"), filepath.Join(root, "codex")
	genImportFixture(t, claude, codex, fixtureNow, 2, 7)
	// Damage: a torn line, a control character, a folded member name, in a recent transcript.
	var victim string
	filepath.WalkDir(filepath.Join(claude, "projects"), func(p string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() && victim == "" {
			if fi, _ := d.Info(); fi != nil && fi.ModTime().After(fixtureNow.AddDate(0, 0, -20)) {
				victim = p
			}
		}
		return nil
	})
	if victim == "" {
		t.Fatal("no recent transcript")
	}
	fi, _ := os.Stat(victim)
	b, _ := os.ReadFile(victim)
	lines := bytes.Split(bytes.TrimSuffix(b, []byte("\n")), []byte("\n"))
	for i := range lines {
		switch i % 9 {
		case 2:
			lines[i] = lines[i][:len(lines[i])/2]
		case 5:
			lines[i] = bytes.Replace(lines[i], []byte(`"type":"`), []byte(`"Type":"`), 1)
		case 7:
			lines[i] = bytes.Replace(lines[i], []byte(`"timestamp":"`), []byte("\"timestamp\":\"\x01"), 1)
		}
	}
	os.WriteFile(victim, append(bytes.Join(lines, []byte("\n")), '\n'), 0o600)
	os.Chtimes(victim, fi.ModTime(), fi.ModTime())

	run := func(reduce bool) map[string]string {
		old := reduceClaudeLines
		reduceClaudeLines = reduce
		defer func() { reduceClaudeLines = old }()
		cache := importFixtureRun(t, claude, codex, fixtureNow)
		out := map[string]string{}
		filepath.WalkDir(cache, func(p string, d os.DirEntry, err error) error {
			if err == nil && !d.IsDir() && !strings.HasSuffix(p, ".lock") {
				b, _ := os.ReadFile(p)
				rel, _ := filepath.Rel(cache, p)
				out[rel] = string(b)
			}
			return nil
		})
		return out
	}
	whole, reduced := run(false), run(true)
	if len(whole) < 2 {
		t.Fatalf("import wrote too little: %v", fileNames(whole))
	}
	if !reflect.DeepEqual(fileNames(whole), fileNames(reduced)) {
		t.Fatalf("files differ: %v / %v", fileNames(whole), fileNames(reduced))
	}
	for k := range whole {
		if whole[k] != reduced[k] {
			t.Fatalf("%s differs (%d / %d bytes)", k, len(whole[k]), len(reduced[k]))
		}
	}
}

func fileNames(m map[string]string) []string {
	var out []string
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
