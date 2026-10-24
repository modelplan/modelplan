package localusage

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

var testNow = time.Date(2026, 10, 23, 12, 0, 0, 0, time.UTC)

func setup(t *testing.T) (string, string) {
	t.Helper()
	home := t.TempDir()
	root := filepath.Join(home, ".gemini")
	t.Setenv("MODELPLAN_GEMINI_HOME", "")
	t.Setenv("MODELPLAN_GEMINI", "")
	t.Setenv("MODELPLAN_HISTORY", "")
	if err := SetGemini(home, true); err != nil {
		t.Fatal(err)
	}
	return home, root
}
func fixtureFile(t *testing.T, path, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(path, testNow, testNow); err != nil {
		t.Fatal(err)
	}
}

const messageOne = `{"id":"message-secret-1","type":"gemini","timestamp":"2026-10-23T10:00:00Z","model":"gemini-test-pro","tokens":{"input":100,"output":30,"cached":20,"thoughts":5,"tool":0,"total":135},"content":"PRIVATE REPLY","thoughts":[{"text":"PRIVATE THOUGHT"}],"toolCalls":[{"args":{"key":"PRIVATE TOOL"}}]}`

func sessionJSON(msgs string) string {
	return `{"sessionId":"session-secret","projectHash":"project-secret","startTime":"2026-10-23T09:00:00Z","tokens":{"total":99999},"messages":[` + msgs + `]}`
}

func TestGeminiDefaultOffAndIndependentConsent(t *testing.T) {
	home := t.TempDir()
	t.Setenv("MODELPLAN_GEMINI_HOME", filepath.Join(home, "absent"))
	if r := ReadGemini(home, testNow); r.Status != "off" || r.Coverage.FilesSeen != 0 || r.Enabled {
		t.Fatalf("%+v", r)
	}
	if err := SetGemini(home, true); err != nil {
		t.Fatal(err)
	}
	if r := ReadGemini(home, testNow); r.Status != "unavailable" {
		t.Fatalf("%+v", r)
	}
	for _, env := range []string{"MODELPLAN_HISTORY", "MODELPLAN_GEMINI"} {
		t.Setenv(env, "off")
		r := ReadGemini(home, testNow)
		if r.Status != "off" || r.Coverage.FilesSeen != 0 {
			t.Fatalf("%+v", r)
		}
		t.Setenv(env, "")
	}
	if err := SetGemini(home, false); err != nil {
		t.Fatal(err)
	}
	if r := ReadGemini(home, testNow); r.Enabled || r.Status != "off" {
		t.Fatalf("%+v", r)
	}
	fi, err := os.Stat(SettingsPath(home))
	if err != nil || fi.Mode().Perm() != 0600 {
		t.Fatalf("%v %v", fi, err)
	}
}

func TestGeminiJSONJSONLDeduplicationAndPrivacy(t *testing.T) {
	home, root := setup(t)
	original := filepath.Join(root, "tmp", "project-folder-secret", "chats", "session-one.json")
	fixtureFile(t, original, sessionJSON(messageOne))
	// A copied legacy snapshot, a modern JSONL checkpoint and a repeated message do not
	// create extra usage. Session-level cumulative totals and user text are ignored.
	fixtureFile(t, filepath.Join(root, "legacy", "chats", "session-copy.json"), sessionJSON(messageOne))
	body := `{"sessionId":"session-secret","projectHash":"project-secret"}` + "\n" + messageOne + "\n" + `{"$set":{"messages":[` + messageOne + `]}}` + "\n" + messageOne + "\n" + `{"$rewindTo":"message-secret-1"}` + "\n"
	fixtureFile(t, filepath.Join(root, "tmp", "project-folder-secret", "chats", "session-copy.jsonl"), body)
	// Files outside chat history must never become usage sources.
	fixtureFile(t, filepath.Join(root, "oauth_creds.json"), "CREDENTIAL CONTENT")
	fixtureFile(t, filepath.Join(root, "antigravity", "conversations", "session-foreign.json"), sessionJSON(messageOne))
	fixtureFile(t, filepath.Join(root, "antigravity-cli", "chats", "session-foreign.json"), sessionJSON(strings.ReplaceAll(messageOne, "message-secret-1", "foreign-message")))
	before := fileTree(t, home)
	r := ReadGemini(home, testNow)
	if r.Status != "ok" || len(r.Rows) != 1 || len(r.Sessions) != 1 || r.Rows[0].Messages != 1 {
		t.Fatalf("%+v", r)
	}
	row := r.Rows[0]
	if *row.Input != 100 || *row.Cached != 20 || *row.Output != 30 || *row.Thoughts != 5 || *row.Total != 135 {
		t.Fatalf("%+v", row)
	}
	if len(r.Hosts) != 0 || r.Scope == "" {
		t.Fatal(r)
	}
	b, _ := json.Marshal(r)
	for _, private := range []string{"session-secret", "message-secret", "project-secret", "project-folder-secret", "PRIVATE", "CREDENTIAL CONTENT", "oauth_creds"} {
		if strings.Contains(string(b), private) {
			t.Fatalf("leaked %q: %s", private, b)
		}
	}
	again := ReadGemini(home, testNow)
	if r.Sessions[0].Ref != again.Sessions[0].Ref {
		t.Fatal("unstable keyed reference")
	}
	if !reflect.DeepEqual(before, fileTree(t, home)) {
		t.Fatal("read rewrote a source or cached token data")
	}
	otherHome, _ := setup(t)
	fixtureFile(t, filepath.Join(otherHome, ".gemini", "tmp", "p", "chats", "session-one.json"), sessionJSON(messageOne))
	if ReadGemini(otherHome, testNow).Sessions[0].Ref == r.Sessions[0].Ref {
		t.Fatal("references must not match across installations")
	}
}

func TestGeminiModelDayHistoryAndUnknownFields(t *testing.T) {
	home, root := setup(t)
	second := `{"id":"m2","type":"gemini","timestamp":"2026-10-22T23:00:00Z","model":"gemini-test-flash","tokens":{"input":200,"output":50,"cached":40,"total":250}}`
	third := `{"id":"m3","type":"gemini","timestamp":"2026-10-23T11:00:00Z","model":"gemini-test-pro"}`
	user := `{"id":"u1","type":"user","timestamp":"2026-10-23T11:00:00Z","model":"gemini-test-pro","tokens":{"output":99999}}`
	fixtureFile(t, filepath.Join(root, "tmp", "p", "chats", "session-one.json"), sessionJSON(strings.Join([]string{messageOne, second, third, user}, ",")))
	r := ReadGemini(home, testNow)
	if len(r.Rows) != 2 || len(r.Sessions) != 1 || r.Sessions[0].Messages != 3 || r.Sessions[0].Output != nil || r.Coverage.MessagesWithoutTokens != 1 {
		t.Fatalf("%+v", r)
	}
	if row := r.Rows[0]; row.Model != "gemini-test-pro" || row.Output != nil || row.Messages != 2 {
		t.Fatalf("%+v", row)
	}
	if row := r.Rows[1]; row.Model != "gemini-test-flash" || *row.Output != 50 || row.Thoughts != nil || row.Tool != nil {
		t.Fatalf("%+v", row)
	}
}

func TestGeminiJSONLUsageUpdates(t *testing.T) {
	home, root := setup(t)
	initial := strings.Replace(messageOne, `"tokens":{"input":100,"output":30,"cached":20,"thoughts":5,"tool":0,"total":135}`, `"tokens":null`, 1)
	fixtureFile(t, filepath.Join(root, "tmp", "p", "chats", "session-new.jsonl"), `{"$set":{"sessionId":"session-secret","projectHash":"project-secret"}}`+"\n"+initial+"\n"+messageOne+"\n")
	r := ReadGemini(home, testNow)
	if r.Status != "ok" || r.Rows[0].Messages != 1 || r.Rows[0].Output == nil || *r.Rows[0].Output != 30 {
		t.Fatalf("%+v", r)
	}
}

func TestGeminiBoundsUnsafeAndMalformedData(t *testing.T) {
	home, root := setup(t)
	chats := filepath.Join(root, "tmp", "p", "chats")
	fixtureFile(t, filepath.Join(chats, "session-valid.json"), sessionJSON(messageOne))
	fixtureFile(t, filepath.Join(chats, "session-bad.jsonl"), "{incomplete\n")
	fixtureFile(t, filepath.Join(chats, "session-schema.json"), `{"futureSchema":true}`)
	fixtureFile(t, filepath.Join(home, "outside.json"), sessionJSON(messageOne))
	if err := os.Symlink(filepath.Join(home, "outside.json"), filepath.Join(chats, "session-link.json")); err != nil {
		t.Fatal(err)
	}
	f, err := os.Create(filepath.Join(chats, "session-large.json"))
	if err != nil {
		t.Fatal(err)
	}
	_ = f.Truncate(maxFileBytes + 1)
	_ = f.Close()
	r := ReadGemini(home, testNow)
	if r.Status != "partial" || r.Coverage.FilesSkipped < 4 || len(r.Rows) != 1 || r.Rows[0].Messages != 1 {
		t.Fatalf("%+v", r)
	}
	t.Setenv("MODELPLAN_GEMINI_HOME", filepath.Join(home, "link"))
	if err := os.Symlink(root, filepath.Join(home, "link")); err != nil {
		t.Fatal(err)
	}
	if r := ReadGemini(home, testNow); r.Status != "unavailable" {
		t.Fatalf("%+v", r)
	}
}

func TestGeminiHistoryAndFileLimits(t *testing.T) {
	home, root := setup(t)
	chats := filepath.Join(root, "tmp", "p", "chats")
	for i := 0; i < maxFiles+1; i++ {
		fixtureFile(t, filepath.Join(chats, fmt.Sprintf("session-%03d.json", i)), sessionJSON(messageOne))
	}
	r := ReadGemini(home, testNow)
	if !r.Coverage.Truncated || r.Coverage.FilesRead != maxFiles || r.Rows[0].Messages != 1 {
		t.Fatalf("%+v", r)
	}
	old := strings.ReplaceAll(messageOne, "2026-10-23T10:00:00Z", "2020-01-01T10:00:00Z")
	if err := os.RemoveAll(root); err != nil {
		t.Fatal(err)
	}
	fixtureFile(t, filepath.Join(chats, "session-old.json"), sessionJSON(old))
	if r := ReadGemini(home, testNow); r.Status != "empty" || r.LastObservedAt != nil || len(r.Rows) != 0 {
		t.Fatalf("%+v", r)
	}
}

func TestGeminiInvalidSettingsAndInvalidCounts(t *testing.T) {
	home, root := setup(t)
	bad := strings.ReplaceAll(messageOne, `"output":30`, `"output":-1`)
	fixtureFile(t, filepath.Join(root, "tmp", "p", "chats", "session-one.json"), sessionJSON(bad))
	if r := ReadGemini(home, testNow); r.Rows[0].Output != nil {
		t.Fatal("negative token count treated as known")
	}
	fixtureFile(t, SettingsPath(home), `{"schemaVersion":1,"gemini":true,"identityKey":"bad"}`)
	if r := ReadGemini(home, testNow); r.Status != "invalid" || r.Coverage.FilesSeen != 0 {
		t.Fatalf("%+v", r)
	}
	if err := SetGemini(home, true); err == nil {
		t.Fatal("invalid settings overwritten")
	}
}

func fileTree(t *testing.T, root string) map[string]string {
	t.Helper()
	out := map[string]string{}
	err := filepath.WalkDir(root, func(p string, d os.DirEntry, e error) error {
		if e != nil {
			return e
		}
		if d.IsDir() {
			return nil
		}
		b, e := os.ReadFile(p)
		if e != nil {
			return e
		}
		fi, e := d.Info()
		if e != nil {
			return e
		}
		out[p] = fmt.Sprintf("%d:%s", fi.ModTime().UnixNano(), b)
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return out
}
