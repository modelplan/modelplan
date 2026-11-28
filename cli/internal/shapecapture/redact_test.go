// SPDX-License-Identifier: MIT
package shapecapture

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

var now = time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)

const fakeJWT = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.abcdefghijklmnop"

var poison = []string{"alice@example.com", "sk-ant-api03-SECRETSECRETSECRET", fakeJWT, "/home/alice/secret-project", "C:\\Users\\alice\\x", "https://evil.example/hook", "Bearer abcdef123456", "11111111-2222-3333-4444-555555555555", "ghp_abcdefghijklmnopqrstuvwxyz0123456789", "my private prompt text", "Acme-Internal"}

func shape(t *testing.T, a Allow, in string) string {
	t.Helper()
	v, err := decode([]byte(in))
	if err != nil {
		t.Fatal(err)
	}
	b, _ := marshal(NewRedactor(a, now).Shape(v), false)
	b = bytes.TrimSpace(b)
	if err := Verify(b); err != nil {
		t.Fatalf("verify: %v in %s", err, b)
	}
	return string(b)
}

func TestNoPoisonSurvivesEvenWhenAllowListedAsEnum(t *testing.T) {
	a := Allow{}
	obj := map[string]any{}
	for i, p := range poison {
		k := "k" + string(rune('a'+i))
		a[k] = Enum
		obj[k] = p
		a["email"] = Enum
		obj["email"] = p
		a["access_token"] = Enum
		obj["access_token"] = p
	}
	obj["unlisted"] = "alice@example.com"
	obj["path/with/slash"] = 1
	b, _ := json.Marshal(obj)
	out := shape(t, a, string(b))
	for _, p := range poison {
		if strings.Contains(out, p) {
			t.Fatalf("%q survived: %s", p, out)
		}
	}
	if strings.Contains(out, "unlisted") || strings.Contains(out, "slash") {
		t.Fatalf("unlisted key kept: %s", out)
	}
}

func TestEnumKeptOnlyWhenClean(t *testing.T) {
	a := Allow{"status": Enum, "model": Enum}
	got := shape(t, a, `{"status":"ok","model":"gpt-5.5","extra":1}`)
	if got != `{"model":"gpt-5.5","status":"ok"}` {
		t.Fatal(got)
	}
	if got := shape(t, a, `{"model":"Alice's laptop"}`); got != `{"model":"<string>"}` {
		t.Fatal(got)
	}
	if got := shape(t, a, `{"model":"claude-opus-4-1-20250805"}`); !strings.Contains(got, "claude-opus") {
		t.Fatal(got)
	}
}

func TestNumbersKeepTypeAndSign(t *testing.T) {
	a := Allow{"n": Struct}
	got := shape(t, a, `{"n":[0,7,-3,0.25,-2.5,0.0,null,true,"x",""]}`)
	if got != `{"n":[0,1,-1,1.5,-1.5,0,null,true,"\u003cstring\u003e",""]}` && got != `{"n":[0,1,-1,1.5,-1.5,0,null,true,"<string>",""]}` {
		t.Fatal(got)
	}
}

func TestTimesBecomeRelativeOffsets(t *testing.T) {
	a := Allow{"at": Time, "ms": Time, "sec": Time}
	ts := now.Add(-time.Hour).Format(time.RFC3339)
	in := `{"at":"` + ts + `","ms":` + itoa(now.Add(-2*time.Minute).UnixMilli()) + `,"sec":` + itoa(now.Add(time.Hour).Unix()) + `}`
	got := shape(t, a, in)
	if got != `{"at":"-3600s","ms":-120000,"sec":3600}` {
		t.Fatal(got)
	}
	if strings.Contains(got, "2026") {
		t.Fatal("absolute date leaked")
	}
}

func itoa(i int64) string { b, _ := json.Marshal(i); return string(b) }

func TestArraysCappedAndDepthBounded(t *testing.T) {
	a := Allow{"a": Struct}
	var sb strings.Builder
	sb.WriteString(`{"a":[`)
	for i := 0; i < 50; i++ {
		if i > 0 {
			sb.WriteString(",")
		}
		sb.WriteString("1")
	}
	sb.WriteString("]}")
	var v map[string][]int
	_ = json.Unmarshal([]byte(shape(t, a, sb.String())), &v)
	if len(v["a"]) != maxArray {
		t.Fatal(len(v["a"]))
	}
}

func TestVerifyRefusesLeaks(t *testing.T) {
	for _, bad := range []string{`{"a":"alice@example.com"}`, `{"a":"/home/x/y"}`, `{"alice@example.com":1}`, `{"a":["` + fakeJWT + `"]}`} {
		if Verify([]byte(bad)) == nil {
			t.Fatalf("accepted %s", bad)
		}
	}
	if Verify([]byte(`{"a":"<string>","b":"-3600s","c":"ok"}`)) != nil {
		t.Fatal("rejected clean sample")
	}
}

func fakeHome(t *testing.T) string {
	home := t.TempDir()
	w := func(rel, body string) {
		p := filepath.Join(home, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	w(".codex/auth.json", `{"auth_mode":"chatgpt","OPENAI_API_KEY":"sk-proj-SECRETSECRETSECRET","tokens":{"access_token":"`+fakeJWT+`","refresh_token":"rt_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789","account_id":"11111111-2222-3333-4444-555555555555"},"email":"alice@example.com","last_refresh":"2026-11-10T00:00:00Z"}`)
	w(".codex/sessions/2026/11/12/a.jsonl",
		`{"timestamp":"2026-11-12T11:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":120,"output_tokens":0},"model_context_window":200000},"rate_limits":{"primary":{"used_percent":12.5,"window_minutes":300,"resets_at":`+itoa(now.Add(time.Hour).Unix())+`},"plan_type":"pro"}},"cwd":"/home/alice/secret-project","text":"my private prompt text","user":"alice@example.com"}`+"\n"+
			`{"timestamp":"2026-11-12T11:01:00Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"my private prompt text"}]}}`+"\n")
	w(".claude/projects/p1/s.jsonl", `{"type":"assistant","timestamp":"2026-11-12T11:00:00Z","cwd":"/home/alice/secret-project","message":{"model":"claude-opus-4-1","usage":{"input_tokens":5,"output_tokens":9,"cache_read_input_tokens":0},"content":[{"type":"text","text":"my private prompt text"}]}}`+"\n")
	w(".claude/.credentials.json", `{"claudeAiOauth":{"accessToken":"sk-ant-oat01-SECRETSECRETSECRET","refreshToken":"sk-ant-ort01-SECRETSECRETSECRET","expiresAt":`+itoa(now.Add(time.Hour).UnixMilli())+`,"subscriptionType":"max","scopes":["user:inference"]}}`)
	w(".gemini/oauth_creds.json", `{"access_token":"ya29.SECRETSECRETSECRETSECRETSECRETSECRET","refresh_token":"1//SECRETSECRETSECRETSECRETSECRETSECRET","token_type":"Bearer","expiry_date":`+itoa(now.Add(time.Hour).UnixMilli())+`}`)
	w(".gemini/tmp/h1/chats/c.json", `{"sessionId":"s","projectHash":"abc","startTime":"2026-11-12T10:00:00Z","messages":[{"id":"m","type":"gemini","content":"my private prompt text","tokens":{"input":3,"output":4,"cached":0},"model":"gemini-3-pro"}]}`)
	w(".grok/auth.json", `{"key":"xai-SECRETSECRETSECRETSECRET","auth_mode":"oidc","user_id":"alice","expires_at":"2026-11-13T00:00:00Z","oidc_issuer":"https://evil.example"}`)

	dbp := filepath.Join(home, ".zcode/cli/db/db.sqlite")
	_ = os.MkdirAll(filepath.Dir(dbp), 0o755)
	db, err := sql.Open("sqlite", dbp)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	for _, q := range []string{
		`CREATE TABLE model_usage(id TEXT, session_id TEXT, model_id TEXT, started_at INTEGER, completed_at INTEGER, output_tokens INTEGER, input_tokens INTEGER, prompt TEXT)`,
		`INSERT INTO model_usage VALUES('11111111-2222-3333-4444-555555555555','s','glm-5',` + itoa(now.Add(-time.Hour).UnixMilli()) + `,` + itoa(now.UnixMilli()) + `,42,0,'my private prompt text')`,
		`CREATE TABLE session(id TEXT, directory TEXT)`,
		`INSERT INTO session VALUES('s','/home/alice/secret-project')`,
	} {
		if _, err := db.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	ocp := filepath.Join(home, ".local/share/opencode/opencode.db")
	_ = os.MkdirAll(filepath.Dir(ocp), 0o755)
	oc, err := sql.Open("sqlite", ocp)
	if err != nil {
		t.Fatal(err)
	}
	defer oc.Close()
	for _, q := range []string{
		`CREATE TABLE session_message(id TEXT, session_id TEXT, type TEXT, seq INTEGER, time_created INTEGER, time_updated INTEGER, data TEXT)`,
		`INSERT INTO session_message VALUES('msg_7kf3k9d2qxapz1wa','ses_canary','assistant',1,` + itoa(now.Add(-time.Hour).UnixMilli()) + `,` + itoa(now.UnixMilli()) + `,'{"id":"part_canary","role":"assistant","modelID":"glm-5","providerID":"zai","tokens":{"input":3,"output":7},"text":"my private prompt text"}')`,
	} {
		if _, err := oc.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	return home
}

func TestEndToEndNoFakeSecretsSurvive(t *testing.T) {
	home := fakeHome(t)
	out := t.TempDir()
	var ms []Manifest
	for _, tool := range Tools() {
		m, err := Capture(tool, Env{Home: home, CacheDir: filepath.Join(home, "cache"), Getenv: func(string) string { return "" }}, out, now)
		if err != nil {
			t.Fatal(err)
		}
		ms = append(ms, m)
	}
	if err := WriteManifest(out, ms); err != nil {
		t.Fatal(err)
	}
	files := 0
	_ = filepath.Walk(out, func(p string, fi os.FileInfo, err error) error {
		if err != nil || fi.IsDir() {
			return nil
		}
		files++
		b, _ := os.ReadFile(p)
		for _, bad := range append(poison, "alice", "SECRET", "msg_7kf3k9d2qxapz1wa", "part_canary", "ses_canary", "secret-project", "xai-", "ya29", "2026-11", "evil.example") {
			if strings.Contains(string(b), bad) {
				t.Errorf("%s leaked %q:\n%s", p, bad, b)
			}
		}
		return nil
	})
	if files < 8 {
		t.Fatalf("expected samples for codex, claude, gemini, grok, zcode; got %d files", files)
	}
	b, _ := os.ReadFile(filepath.Join(out, "zcode", "db-1.shape.json"))
	if !strings.Contains(string(b), `"model_id": "glm-5"`) || !strings.Contains(string(b), `"output_tokens": 1`) || !strings.Contains(string(b), `"input_tokens": 0`) {
		t.Fatalf("zcode shape lost structure: %s", b)
	}
	if strings.Contains(string(b), "prompt") && strings.Contains(string(b), "my private") {
		t.Fatal("prompt column value leaked")
	}
	b, _ = os.ReadFile(filepath.Join(out, "opencode", "db-1.shape.json"))
	if !strings.Contains(string(b), `"modelID": "glm-5"`) || !strings.Contains(string(b), `"output": 1`) {
		t.Fatalf("opencode shape lost structure: %s", b)
	}
}

// The capture samples the same tree the readers consume when their override is set.
func TestReaderOverridesAreHonoured(t *testing.T) {
	home := fakeHome(t)
	alt := t.TempDir()
	if err := os.MkdirAll(filepath.Join(alt, "g", "tmp", "h", "chats"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(alt, "g", "tmp", "h", "chats", "c.json"), []byte(`{"messages":[{"type":"gemini","model":"gemini-redirected"}]}`), 0o600); err != nil {
		t.Fatal(err)
	}
	zdb := filepath.Join(alt, "custom.sqlite")
	db, err := sql.Open("sqlite", zdb)
	if err != nil {
		t.Fatal(err)
	}
	for _, q := range []string{`CREATE TABLE model_usage(model_id TEXT, output_tokens INTEGER)`, `INSERT INTO model_usage VALUES('glm-redirected', 5)`} {
		if _, err := db.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	db.Close()
	vars := map[string]string{"MODELPLAN_GEMINI_HOME": filepath.Join(alt, "g"), "MODELPLAN_ZCODE_DB": zdb}
	env := Env{Home: home, Getenv: func(k string) string { return vars[k] }}
	out := t.TempDir()
	for _, tool := range Tools() {
		if tool.Name != "gemini" && tool.Name != "zcode" {
			continue
		}
		if _, err := Capture(tool, env, out, now); err != nil {
			t.Fatal(err)
		}
	}
	if b, _ := os.ReadFile(filepath.Join(out, "gemini", "chats-1.shape.json")); !strings.Contains(string(b), "gemini-redirected") {
		t.Fatalf("gemini override ignored: %s", b)
	}
	if b, _ := os.ReadFile(filepath.Join(out, "zcode", "db-1.shape.json")); !strings.Contains(string(b), "glm-redirected") {
		t.Fatalf("zcode override ignored: %s", b)
	}
}
