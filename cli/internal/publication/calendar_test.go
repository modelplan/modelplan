// SPDX-License-Identifier: MIT
package publication_test

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func calJSON(t *testing.T, v any) []byte {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return b
}
func calHash(b []byte) string { return fmt.Sprintf("%x", sha256.Sum256(b)) }

func calendarServer(t *testing.T, mode string) (*httptest.Server, time.Time, string, *atomic.Int32) {
	t.Helper()
	d, at := contracttest.WeekdayCalendar()
	placeholder := strings.Repeat("a", 64)
	ruleData := contracttest.WeekdayRules
	if mode == "aliases" || mode == "unscoped" {
		ruleData = strings.ReplaceAll(ruleData, `"planIds":["synthetic-pro"],`, "")
	}
	if mode == "aliases" {
		d.Multipliers[0].Generations = []string{"legacy-v2"}
		d.PlanMetering = &digest.PlanMetering{Revision: "synthetic", Plans: []digest.MeteredPlan{{PlanID: "synthetic-pro", Generation: "legacy-v2", Basis: digest.BasisRequest, TimeRules: []string{"base", "weekday-peak"}}}}
	}
	rules := calJSON(t, map[string]any{"schemaVersion": 1, "kind": "rules", "dependencies": map[string]string{"plans": placeholder}, "data": json.RawMessage(ruleData)})
	ruleHash := calHash(rules)
	dependency := ruleHash
	if mode == "dependency" {
		dependency = placeholder
	}
	calendar := calJSON(t, map[string]any{"schemaVersion": 1, "kind": "calendar", "dependencies": map[string]string{"plans": placeholder, "rules": dependency}, "data": json.RawMessage(contracttest.WeekdayIntervals)})
	calendarHash := calHash(calendar)
	client := calJSON(t, map[string]any{"schemaVersion": 1, "kind": "client", "dependencies": map[string]string{"models": placeholder, "registry": placeholder, "rules": ruleHash, "calendar": calendarHash}, "data": d})
	clientHash := calHash(client)
	type reference struct {
		SchemaVersion int    `json:"schemaVersion"`
		Hash          string `json:"hash"`
		Bytes         int    `json:"bytes"`
	}
	refs := map[string]reference{}
	for _, name := range []string{"methods", "registry", "models", "plans", "rules", "news", "calendar", "client"} {
		refs[name] = reference{1, placeholder, 2}
	}
	refs["client"], refs["rules"], refs["calendar"] = reference{1, clientHash, len(client)}, reference{1, ruleHash, len(rules)}, reference{1, calendarHash, len(calendar)}
	if mode == "budget" {
		refs["calendar"] = reference{1, calendarHash, (8 << 20) + 1}
	}
	core := struct {
		SchemaVersion     int                  `json:"schemaVersion"`
		ComparisonVersion string               `json:"comparisonVersion"`
		Methods           map[string]string    `json:"methods"`
		Components        map[string]reference `json:"components"`
	}{1, "synthetic-calendar", map[string]string{"index": "unified-v03-estimator-0.1.0-internal", "recommendation": "balanced-coding-absolute-v4"}, refs}
	coreBody := calJSON(t, core)
	id := calHash(coreBody)[:24]
	manifest := append(append([]byte(nil), coreBody[:len(coreBody)-1]...), []byte(`,"publicationId":"`+id+`","publishedAt":"2026-10-31T02:00:00Z"}`)...)
	pointer := calJSON(t, map[string]any{"schemaVersion": 1, "publicationId": id, "manifestHash": calHash(manifest)})
	if mode == "hash" {
		calendar = []byte(strings.ReplaceAll(string(calendar), `"multiplier":3`, `"multiplier":9`))
	}
	objects := map[string][]byte{clientHash: client, ruleHash: rules, calendarHash: calendar}
	hits := &atomic.Int32{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		if r.Header.Get("Authorization") != "" || r.Header.Get("Cookie") != "" || r.URL.RawQuery != "" {
			t.Error("public request included account data")
		}
		switch r.URL.Path {
		case "/publications/current.json":
			if r.Header.Get("If-None-Match") == `"calendar"` {
				w.WriteHeader(http.StatusNotModified)
				return
			}
			w.Header().Set("ETag", `"calendar"`)
			_, _ = w.Write(pointer)
		case "/publications/releases/" + id + "/manifest.json":
			_, _ = w.Write(manifest)
		default:
			hash := strings.TrimSuffix(strings.TrimPrefix(r.URL.Path, "/publications/objects/"), ".json")
			if body, ok := objects[hash]; ok {
				_, _ = w.Write(body)
			} else {
				http.NotFound(w, r)
			}
		}
	}))
	t.Cleanup(srv.Close)
	return srv, at, calendarHash, hits
}

func TestVerifiedCalendarSyncAndCacheOnlySaturday(t *testing.T) {
	for _, mode := range []string{"direct", "aliases"} {
		t.Run(mode, func(t *testing.T) {
			t.Setenv("MODELPLAN_CACHE", t.TempDir())
			st, err := store.Open()
			if err != nil {
				t.Fatal(err)
			}
			srv, at, calendarHash, hits := calendarServer(t, mode)
			client, err := publication.New(srv.URL, st, "test")
			if err != nil {
				t.Fatal(err)
			}
			client.Now = func() time.Time { return at }
			client.Jitter = func() time.Duration { return 0 }
			if _, err := client.Sync(context.Background(), true); err != nil {
				t.Fatal(err)
			}
			before := hits.Load()
			normal, _, err := publication.Load(st)
			if err != nil || len(normal.CalendarIntervals) != 0 {
				t.Fatal("ordinary reads parsed the supplement", err)
			}
			d, state, err := publication.LoadWindows(st)
			if err != nil || d.PublicationID != state.PublicationID || len(d.CalendarIntervals) != 1 {
				t.Fatal("verified calendar unavailable", err)
			}
			groups := advise.Windows(d, advise.WindowFilter{Provider: "zai"}, at)
			if len(groups) != 1 || len(groups[0].Series) != 1 || groups[0].Series[0].Next == nil || *groups[0].Series[0].Next.Multiplier != 3 {
				t.Fatal(groups)
			}
			if hits.Load() != before {
				t.Fatal("cache-only calendar view used the network")
			}
			// A migrated cache can backfill its optional calendar on a 304 response.
			if err := os.Remove(st.ObjectPath(calendarHash)); err != nil {
				t.Fatal(err)
			}
			missing, _, err := publication.LoadWindows(st)
			if err != nil || len(missing.CalendarIntervals) != 0 {
				t.Fatal("missing calendar did not abstain", err)
			}
			if _, err := client.Sync(context.Background(), true); err != nil {
				t.Fatal(err)
			}
			d, _, err = publication.LoadWindows(st)
			if err != nil || len(d.CalendarIntervals) != 1 {
				t.Fatal("304 did not backfill calendar", err)
			}
			// Locally altered future data cannot bypass the hash binding.
			if err := os.WriteFile(st.ObjectPath(calendarHash), []byte(`{"altered":true}`), 0600); err != nil {
				t.Fatal(err)
			}
			d, _, err = publication.LoadWindows(st)
			if err != nil || len(d.CalendarIntervals) != 0 {
				t.Fatal("corrupt calendar was trusted", err)
			}

		})
	}
}

func TestCalendarSupplementFailureKeepsVerifiedClient(t *testing.T) {
	for _, mode := range []string{"hash", "dependency", "budget", "unscoped"} {
		t.Run(mode, func(t *testing.T) {
			t.Setenv("MODELPLAN_CACHE", t.TempDir())
			st, err := store.Open()
			if err != nil {
				t.Fatal(err)
			}
			srv, at, _, _ := calendarServer(t, mode)
			client, err := publication.New(srv.URL, st, "test")
			if err != nil {
				t.Fatal(err)
			}
			client.Now = func() time.Time { return at }
			if _, err := client.Sync(context.Background(), true); err != nil {
				t.Fatal("optional failure discarded client", err)
			}
			d, _, err := publication.LoadWindows(st)
			if err != nil || len(d.CalendarIntervals) != 0 {
				t.Fatal("invalid calendar trusted", err)
			}
			groups := advise.Windows(d, advise.WindowFilter{Provider: "zai"}, at)
			if len(groups) != 1 || groups[0].Series[0].Next != nil || *groups[0].Series[0].Now.Multiplier != 1 {
				t.Fatal("current verified rate lost or future invented", groups)
			}
		})
	}
}
