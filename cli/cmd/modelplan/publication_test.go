package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/desktopcontract"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// Independently written public graph; no producer, private fixture or account is needed.
const publicationClientFixture = `{
  "schemaVersion":1,"kind":"client",
  "dependencies":{"models":"HASH","registry":"HASH","rules":"HASH","calendar":"HASH"},
  "data":{
    "publicationId":"untrusted-component-id","publishedAt":"untrusted-component-time",
    "units":{"ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"},
    "models":[
      {"id":"z-model","name":"Synthetic Z","developerId":"z-dev","recommended":"medium","harnessIds":{"codex":["native-z"]},"efforts":[{"effort":"medium","label":"Med","ability":50,"cost":2,"time":null},{"effort":"high","label":"High","ability":null,"cost":null,"time":null}]},
      {"id":"a-model","name":"Synthetic A","developerId":"a-dev","recommended":"high","harnessIds":{"claude-code":["native-a"]},"efforts":[{"effort":"high","label":"High","ability":60,"cost":3,"time":1.2}]}
    ],
    "lineups":[
      {"developerId":"z-dev","costBasisId":"test","method":"lineup-v1","tie":1,"baseline":"z-model","frontier":["z-model"],"steps":[],"members":[{"id":"z-model","status":"incomplete","ability":null,"cost":null,"costRelative":null,"tags":[],"dominatedBy":null}]},
      {"developerId":"a-dev","costBasisId":"test","method":"lineup-v1","tie":1,"baseline":"a-model","frontier":["a-model"],"steps":[],"members":[]}
    ],
    "speedTiers":[
      {"id":"z-fast","harness":"codex","tier":"fast","label":"Fast","toggle":"/fast","eligibility":{"plans":["synthetic-plan"],"note":"published eligibility only"},"models":[{"vendorModelId":"native-z","modelId":"z-model","speed":{"ratio":2,"qualifier":"up-to"}}],"billing":[{"account":"subscription","billsTo":"plan-quota","basis":"included-usage","ratio":2.5}],"caveats":["not-task-time"],"sources":["https://example.test/fast"]},
      {"id":"a-fast","harness":"claude-code","tier":"fast","models":[{"vendorModelId":"native-a","modelId":"a-model","speed":{"ratio":1.5,"qualifier":"approximate"}}],"billing":[]},
      {"id":"unknown","harness":"codex","tier":"ultrafast","models":[{"vendorModelId":"unreviewed","modelId":null,"speed":{"ratio":null,"qualifier":"unstated"}}],"billing":[{"account":"subscription","billsTo":"plan-quota","basis":"included-usage","ratio":null}]}
    ],
    "resets":[],"windows":[],"accounts":[{"secret":"must not export"}],"measured":[{"secret":"must not export"}]
  }
}`

type publicationFixture struct {
	id, objectHash    string
	pointer, manifest []byte
	object            []byte
	data              map[string]json.RawMessage
}

func publicationHash(b []byte) string { return fmt.Sprintf("%x", sha256.Sum256(b)) }

func publicationJSON(t *testing.T, v any) []byte {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func newPublicationFixture(t *testing.T, change func(map[string]json.RawMessage)) publicationFixture {
	t.Helper()
	var doc map[string]json.RawMessage
	if err := json.Unmarshal([]byte(strings.ReplaceAll(publicationClientFixture, "HASH", strings.Repeat("a", 64))), &doc); err != nil {
		t.Fatal(err)
	}
	if change != nil {
		change(doc)
	}
	f := publicationFixture{object: publicationJSON(t, doc)}
	if err := json.Unmarshal(doc["data"], &f.data); err != nil {
		t.Fatal(err)
	}
	f.objectHash = publicationHash(f.object)
	type reference struct {
		SchemaVersion int    `json:"schemaVersion"`
		Hash          string `json:"hash"`
		Bytes         int    `json:"bytes"`
	}
	refs := map[string]reference{}
	for _, name := range []string{"methods", "registry", "models", "plans", "rules", "news", "calendar"} {
		refs[name] = reference{1, strings.Repeat("a", 64), 2}
	}
	refs["client"] = reference{1, f.objectHash, len(f.object)}
	core := struct {
		SchemaVersion     int                  `json:"schemaVersion"`
		ComparisonVersion string               `json:"comparisonVersion"`
		Methods           map[string]string    `json:"methods"`
		Components        map[string]reference `json:"components"`
	}{1, "synthetic-test", map[string]string{"index": "unified-v03-estimator-0.1.0-internal", "recommendation": "balanced-coding-absolute-v4"}, refs}
	coreJSON := publicationJSON(t, core)
	f.id = publicationHash(coreJSON)[:24]
	f.manifest = []byte(strings.TrimSuffix(string(coreJSON), "}") + `,"publicationId":"` + f.id + `","publishedAt":"2026-10-24T12:00:00Z"}`)
	f.pointer = publicationJSON(t, map[string]any{"schemaVersion": 1, "publicationId": f.id, "manifestHash": publicationHash(f.manifest)})
	return f
}

func publicationServer(t *testing.T, f *publicationFixture) (*httptest.Server, *[]string) {
	t.Helper()
	hits := []string{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits = append(hits, r.URL.Path)
		if r.Header.Get("Authorization") != "" || r.Header.Get("Cookie") != "" || r.URL.RawQuery != "" {
			t.Error("public request contains account data")
		}
		switch r.URL.Path {
		case "/publications/current.json":
			_, _ = w.Write(f.pointer)
		case "/publications/releases/" + f.id + "/manifest.json":
			_, _ = w.Write(f.manifest)
		case "/publications/objects/" + f.objectHash + ".json":
			_, _ = w.Write(f.object)
		default:
			t.Errorf("unexpected request %s", r.URL.Path)
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(srv.Close)
	return srv, &hits
}

func publicationRun(args ...string) (int, string, string) {
	var out, stderr bytes.Buffer
	code := run(append([]string{"publication"}, args...), nil, &out, &stderr)
	return code, out.String(), stderr.String()
}

func TestPublicationPublicOnlyOnlineAndOffline(t *testing.T) {
	isolateHome(t)
	cache := filepath.Join(t.TempDir(), "cache")
	t.Setenv("MODELPLAN_CACHE", cache)
	f := newPublicationFixture(t, nil)
	srv, hits := publicationServer(t, &f)
	t.Setenv("MODELPLAN_BASE", srv.URL)
	defer func(original func(...string) error) { startDetached = original }(startDetached)
	startDetached = func(...string) error { t.Error("publication started a subprocess"); return nil }

	code, out, stderr := publicationRun("--json")
	if code != 0 || stderr != "" || len(*hits) != 3 {
		t.Fatalf("online: exit=%d stderr=%s requests=%v", code, stderr, *hits)
	}
	var got map[string]json.RawMessage
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatal(err)
	}
	want := map[string]json.RawMessage{
		"contractVersion": json.RawMessage("1"), "capabilities": publicationJSON(t, desktopcontract.PublicationCapabilities()),
		"resets": f.data["resets"], "windows": f.data["windows"], "multipliers": json.RawMessage("null"), "multiplierHorizon": json.RawMessage("null"), "planMetering": json.RawMessage("null"),
		"schemaVersion": json.RawMessage("1"), "publicationId": publicationJSON(t, f.id),
		"publishedAt": json.RawMessage(`"2026-10-24T12:00:00Z"`),
		"units":       f.data["units"], "models": f.data["models"], "lineups": f.data["lineups"], "speedTiers": f.data["speedTiers"],
	}
	// Whole-array comparison covers order, harness aliases, null scores/billing,
	// null model IDs/ratios, qualifiers, eligibility and every published tier.
	var gotValue, wantValue any
	_ = json.Unmarshal(publicationJSON(t, got), &gotValue)
	_ = json.Unmarshal(publicationJSON(t, want), &wantValue)
	if !reflect.DeepEqual(gotValue, wantValue) {
		t.Fatalf("publication projection differs:\ngot %s\nwant %s", out, publicationJSON(t, want))
	}

	// Personal files must not affect the output or be changed by this command.
	for _, path := range []string{filepath.Join(cache, "observed", "speed.json"), filepath.Join(cache, "observed", "codex-account.json"), filepath.Join(os.Getenv("CODEX_HOME"), "auth.json"), filepath.Join(os.Getenv("CODEX_HOME"), "sessions", "private.jsonl"), filepath.Join(os.Getenv("HOME"), ".config", "modelplan", "local.json")} {
		if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(`{"personal":"never export"}`), 0600); err != nil {
			t.Fatal(err)
		}
	}
	beforeCache, beforeHome := tree(t, cache), tree(t, os.Getenv("HOME"))
	for i := 0; i < 2; i++ {
		code, offline, stderr := publicationRun("--json", "--offline")
		if code != 0 || offline != out || stderr != "" || len(*hits) != 3 {
			t.Fatalf("offline: exit=%d stderr=%s requests=%v output=%s", code, stderr, *hits, offline)
		}
	}
	if !reflect.DeepEqual(beforeCache, tree(t, cache)) || !reflect.DeepEqual(beforeHome, tree(t, os.Getenv("HOME"))) {
		t.Fatal("offline publication changed local files")
	}

	// Cache timestamps are not authoritative publication metadata.
	st := &store.Store{Dir: cache}
	state, err := st.State()
	if err != nil {
		t.Fatal(err)
	}
	state.PublishedAt = "unverified-state-time"
	state.CheckedAt = time.Now().Add(-time.Hour)
	if err := st.SaveState(state); err != nil {
		t.Fatal(err)
	}
	code, offline, stderr := publicationRun("--json", "--offline")
	if code != 0 || offline != out || stderr != "" || len(*hits) != 3 {
		t.Fatalf("offline stale cache: exit=%d stderr=%s output=%s", code, stderr, offline)
	}

	// Failed refresh retains a verified last-good publication, as other readers do.
	f.pointer = []byte(`{"schemaVersion":99}`)
	code, lastGood, stderr := publicationRun("--json")
	if code != 0 || lastGood != out || !strings.Contains(stderr, "using cached data") || len(*hits) != 4 {
		t.Fatalf("last good: exit=%d stderr=%s requests=%v output=%s", code, stderr, *hits, lastGood)
	}
}

func TestPublicationRejectsInvalidData(t *testing.T) {
	for _, tc := range []struct {
		name, message string
		change        func(*testing.T, *publicationFixture, *store.Store)
	}{
		{"component hash", "hash or size mismatch", func(t *testing.T, f *publicationFixture, st *store.Store) {
			if err := os.WriteFile(st.ObjectPath(f.objectHash), []byte(`{}`), 0600); err != nil {
				t.Fatal(err)
			}
		}},
		{"component index", "client component mismatch", func(t *testing.T, f *publicationFixture, st *store.Store) {
			s, err := st.State()
			if err != nil {
				t.Fatal(err)
			}
			s.ComponentHash = strings.Repeat("b", 64)
			if err := st.PutObject(s.ComponentHash, f.object); err != nil {
				t.Fatal(err)
			}
			if err := st.SaveState(s); err != nil {
				t.Fatal(err)
			}
		}},
		{"manifest hash", "manifest hash mismatch", func(t *testing.T, f *publicationFixture, st *store.Store) {
			if err := os.WriteFile(st.ManifestPath(f.id), []byte(`{}`), 0600); err != nil {
				t.Fatal(err)
			}
		}},
		{"publication mismatch", "publication mismatch", func(t *testing.T, f *publicationFixture, st *store.Store) {
			s, err := st.State()
			if err != nil {
				t.Fatal(err)
			}
			s.PublicationID = strings.Repeat("0", 24)
			if err := st.PutManifest(s.PublicationID, f.manifest); err != nil {
				t.Fatal(err)
			}
			if err := st.SaveState(s); err != nil {
				t.Fatal(err)
			}
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_CACHE", t.TempDir())
			f := newPublicationFixture(t, nil)
			srv, hits := publicationServer(t, &f)
			t.Setenv("MODELPLAN_BASE", srv.URL)
			if code, _, stderr := publicationRun("--json"); code != 0 {
				t.Fatal(stderr)
			}
			st, err := store.Locate()
			if err != nil {
				t.Fatal(err)
			}
			tc.change(t, &f, st)
			code, out, stderr := publicationRun("--json", "--offline")
			if code != exitNoData || out != "" || !strings.Contains(stderr, tc.message) || len(*hits) != 3 {
				t.Fatalf("exit=%d output=%s stderr=%s requests=%v", code, out, stderr, *hits)
			}
		})
	}
}

func TestPublicationRejectsUnverifiedGraph(t *testing.T) {
	for _, mode := range []string{"component corruption", "manifest corruption", "identity mismatch", "dependency mismatch", "schema", "units"} {
		t.Run(mode, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_CACHE", t.TempDir())
			f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
				switch mode {
				case "schema":
					doc["schemaVersion"] = json.RawMessage("99")
				case "dependency mismatch":
					doc["dependencies"] = json.RawMessage(`{}`)
				case "units":
					doc["data"] = bytes.ReplaceAll(doc["data"], []byte("websiteAbility"), []byte("unknown"))
				}
			})
			switch mode {
			case "component corruption":
				f.object = []byte(`{}`)
			case "manifest corruption":
				f.manifest = []byte(`{}`)
			case "identity mismatch":
				oldID := f.id
				f.id = strings.Repeat("0", 24)
				f.manifest = bytes.ReplaceAll(f.manifest, publicationJSON(t, oldID), publicationJSON(t, f.id))
				f.pointer = publicationJSON(t, map[string]any{"schemaVersion": 1, "publicationId": f.id, "manifestHash": publicationHash(f.manifest)})
			}
			srv, _ := publicationServer(t, &f)
			t.Setenv("MODELPLAN_BASE", srv.URL)
			code, out, stderr := publicationRun("--json")
			if code != exitNoData || out != "" || !strings.Contains(stderr, "sync:") {
				t.Fatalf("unverified data: exit=%d output=%s stderr=%s", code, out, stderr)
			}
		})
	}
}

func TestPublicationMissingCacheAndUsage(t *testing.T) {
	isolateHome(t)
	cache := filepath.Join(t.TempDir(), "missing")
	t.Setenv("MODELPLAN_CACHE", cache)
	f := newPublicationFixture(t, nil)
	srv, hits := publicationServer(t, &f)
	t.Setenv("MODELPLAN_BASE", srv.URL)
	code, out, stderr := publicationRun("--json", "--offline")
	if code != exitNoData || out != "" || !strings.Contains(stderr, "no verified publication") || len(*hits) != 0 {
		t.Fatalf("empty cache: exit=%d output=%s stderr=%s requests=%v", code, out, stderr, *hits)
	}
	for _, args := range [][]string{nil, {"--offline"}, {"--json", "unexpected"}} {
		code, out, stderr := publicationRun(args...)
		if code != exitUsage || out != "" || !strings.Contains(stderr, "usage:") {
			t.Fatalf("args=%v exit=%d output=%s stderr=%s", args, code, out, stderr)
		}
	}
	if _, err := os.Stat(cache); !os.IsNotExist(err) {
		t.Fatalf("created cache: %v", err)
	}
	var help bytes.Buffer
	if run([]string{"--help"}, nil, &help, io.Discard) != 0 || !strings.Contains(help.String(), "modelplan publication --json") {
		t.Fatal("publication missing from help")
	}
}

func TestPublicationMissingOptionalFields(t *testing.T) {
	for _, speed := range []string{"absent", "null", "[]"} {
		t.Run(speed, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_CACHE", t.TempDir())
			f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
				var data map[string]json.RawMessage
				if err := json.Unmarshal(doc["data"], &data); err != nil {
					t.Fatal(err)
				}
				if speed == "absent" {
					delete(data, "speedTiers")
				} else {
					data["speedTiers"] = json.RawMessage(speed)
				}
				data["models"], data["lineups"] = json.RawMessage("[]"), json.RawMessage("[]")
				doc["data"] = publicationJSON(t, data)
			})
			f.manifest = bytes.ReplaceAll(f.manifest, []byte(`,"publishedAt":"2026-10-24T12:00:00Z"`), nil)
			f.pointer = publicationJSON(t, map[string]any{"schemaVersion": 1, "publicationId": f.id, "manifestHash": publicationHash(f.manifest)})
			srv, _ := publicationServer(t, &f)
			t.Setenv("MODELPLAN_BASE", srv.URL)
			code, out, stderr := publicationRun("--json")
			var got map[string]any
			if code != 0 || stderr != "" || json.Unmarshal([]byte(out), &got) != nil {
				t.Fatalf("exit=%d output=%s stderr=%s", code, out, stderr)
			}
			if got["publishedAt"] != nil {
				t.Fatalf("missing publishedAt = %v", got["publishedAt"])
			}
			for _, key := range []string{"models", "lineups", "speedTiers"} {
				if a, ok := got[key].([]any); !ok || len(a) != 0 {
					t.Fatalf("%s = %v", key, got[key])
				}
			}
		})
	}
}
