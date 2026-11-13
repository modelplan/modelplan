package localusage

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func setupQwen(t *testing.T) (string, string) {
	t.Helper()
	home := t.TempDir()
	t.Setenv("MODELPLAN_QWEN_HOME", "")
	t.Setenv("MODELPLAN_QWEN", "")
	t.Setenv("MODELPLAN_HISTORY", "")
	if e := SetQwen(home, true); e != nil {
		t.Fatal(e)
	}
	return home, QwenHome(home)
}
func qwenFixture(t *testing.T) string {
	t.Helper()
	b, e := os.ReadFile("testdata/qwen-session.jsonl")
	if e != nil {
		t.Fatal(e)
	}
	return string(b)
}

func TestQwenNativeJSONLPrivacyDedupeAndIndependentConsent(t *testing.T) {
	home, root := setupQwen(t)
	body := qwenFixture(t)
	path := filepath.Join(root, "projects", "private-project-folder", "chats", "private-session.jsonl")
	fixtureFile(t, path, body)
	// Branch/copy records preserve UUID, so copied historical usage counts once.
	fixtureFile(t, filepath.Join(root, "projects", "copy", "chats", "fork.jsonl"), strings.ReplaceAll(body, "private-session", "copied-session"))
	// Credentials and arbitrary trees must not be opened (invalid JSON is deliberate).
	fixtureFile(t, filepath.Join(root, "oauth_creds.json"), "PRIVATE CREDENTIAL")
	fixtureFile(t, filepath.Join(root, "settings.json"), "PRIVATE SETTINGS")
	fixtureFile(t, filepath.Join(root, "logs", "not-history.jsonl"), body)
	before := fileTree(t, home)
	r := ReadQwen(home, testNow)
	if r.Status != "ok" || len(r.Rows) != 1 || len(r.Sessions) != 1 || r.Rows[0].Messages != 1 {
		t.Fatalf("%+v", r)
	}
	row := r.Rows[0]
	if *row.Input != 120 || *row.Output != 30 || *row.Cached != 40 || *row.Thoughts != 5 || *row.Total != 155 {
		t.Fatalf("%+v", row)
	}
	if !reflect.DeepEqual(before, fileTree(t, home)) {
		t.Fatal("reader wrote source/settings/cache")
	}
	b, _ := json.Marshal(r)
	for _, secret := range []string{"PRIVATE PROMPT", "PRIVATE REPLY", "PRIVATE THOUGHT", "PRIVATE TOOL", "private-session", "private-message", "/private/project", "private-project-folder"} {
		if strings.Contains(string(b), secret) {
			t.Fatalf("raw private value escaped: %s", secret)
		}
	}
	if len(r.Hosts) != 0 || len(r.Sessions[0].Ref) != 32 {
		t.Fatal("network/raw identity", r)
	}
	if other := ReadGemini(home, testNow); other.Status != "off" || other.Enabled {
		t.Fatal("Qwen consent enabled Gemini")
	}
	ref := r.Sessions[0].Ref
	if e := SetGemini(home, true); e != nil {
		t.Fatal(e)
	}
	if r = ReadQwen(home, testNow); r.Sessions[0].Ref != ref {
		t.Fatal("enabling Gemini changed Qwen identity/consent")
	}
	if e := SetQwen(home, false); e != nil {
		t.Fatal(e)
	}
	if r = ReadQwen(home, testNow); r.Status != "off" || r.Coverage.FilesSeen != 0 {
		t.Fatal(r)
	}
	if r = GeminiStatus(home, testNow); !r.Enabled {
		t.Fatal("disabling Qwen disabled Gemini")
	}
}

func TestQwenUnknownHistoryBoundsAndStops(t *testing.T) {
	home, root := setupQwen(t)
	path := filepath.Join(root, "projects", "p", "chats", "session.jsonl")
	// Missing/negative fields remain unknown, and one unknown makes that sum unknown.
	body := qwenFixture(t) + `{"uuid":"unknown-message","sessionId":"private-session","cwd":"/private/project","timestamp":"2026-10-23T11:00:00Z","type":"assistant","model":"qwen3-coder","usageMetadata":{"candidatesTokenCount":0,"promptTokenCount":-1}}` + "\n"
	fixtureFile(t, path, body)
	r := ReadQwen(home, testNow)
	if r.Status != "ok" || len(r.Rows) != 1 || r.Rows[0].Messages != 2 || r.Rows[0].Input != nil || r.Rows[0].Total != nil || *r.Rows[0].Output != 30 {
		t.Fatalf("%+v", r)
	}
	// Unknown is distinct from explicit zero.
	fixtureFile(t, path, `{"uuid":"zero","sessionId":"s","cwd":"p","timestamp":"2026-10-23T11:00:00Z","type":"assistant","model":"qwen-test","usageMetadata":{"candidatesTokenCount":0}}`+"\n")
	r = ReadQwen(home, testNow)
	if r.Rows[0].Output == nil || *r.Rows[0].Output != 0 || r.Rows[0].Input != nil {
		t.Fatal(r.Rows)
	}
	for _, env := range []string{"MODELPLAN_QWEN", "MODELPLAN_HISTORY"} {
		t.Setenv(env, "off")
		if r = ReadQwen(home, testNow); r.Status != "off" || r.Coverage.FilesSeen != 0 {
			t.Fatal("read after stop", r)
		}
		t.Setenv(env, "")
	}
	fixtureFile(t, path, qwenFixture(t)+"{unfinished\n")
	if r = ReadQwen(home, testNow); r.Status != "partial" || len(r.Rows) != 0 {
		t.Fatal("partial file treated as complete", r)
	}
	fixtureFile(t, path, qwenFixture(t))
	if r = ReadQwen(home, testNow.AddDate(0, 0, HistoryDays+1)); r.Status != "empty" || len(r.Rows) != 0 {
		t.Fatal("history did not age out", r)
	}
	if r = ReadQwen(home, testNow.Add(-24*time.Hour)); len(r.Rows) != 0 {
		t.Fatal("future history accepted", r)
	}
	link := filepath.Join(root, "projects", "p", "chats", "linked.jsonl")
	if e := os.Symlink(path, link); e != nil {
		t.Fatal(e)
	}
	if r = ReadQwen(home, testNow); r.Status != "partial" || r.Coverage.FilesSkipped == 0 {
		t.Fatal("symlink accepted", r)
	}
	// The shared size limit applies to Qwen too.
	fixtureFile(t, path, strings.Repeat(" ", maxFileBytes+1))
	if r = ReadQwen(home, testNow); r.Status != "partial" || len(r.Rows) != 0 {
		t.Fatal("oversized history accepted", r)
	}
}

func TestQwenDefaultOffOverrideAndLegacySnapshot(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, "chosen-qwen-root")
	t.Setenv("MODELPLAN_QWEN_HOME", root)
	t.Setenv("MODELPLAN_QWEN", "")
	t.Setenv("MODELPLAN_HISTORY", "")
	fixtureFile(t, filepath.Join(root, "tmp", "legacy-project", "chats", "session-old.json"), sessionJSON(strings.ReplaceAll(messageOne, "gemini-test-pro", "qwen-old")))
	if r := ReadQwen(home, testNow); r.Status != "off" || r.Coverage.FilesSeen != 0 {
		t.Fatal(r)
	}
	if e := SetQwen(home, true); e != nil {
		t.Fatal(e)
	}
	r := ReadQwen(home, testNow)
	if r.Status != "ok" || r.Rows[0].Model != "qwen-old" || *r.Rows[0].Output != 30 || !strings.HasPrefix(r.ReadPaths[0], root) {
		t.Fatal(r)
	}
	otherHome := t.TempDir()
	if e := SetQwen(otherHome, true); e != nil {
		t.Fatal(e)
	}
	if other := ReadQwen(otherHome, testNow); other.Sessions[0].Ref == r.Sessions[0].Ref {
		t.Fatal("identities not locally keyed")
	}
}
