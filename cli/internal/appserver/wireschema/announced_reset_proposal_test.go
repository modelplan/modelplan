// SPDX-License-Identifier: MIT
package wireschema_test

import (
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"runtime"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/appserver/wireschema"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/santhosh-tekuri/jsonschema/v6"
)

// These types are test-only examples of the draft, not a production producer.
type proposedResetSource struct {
	Kind          string `json:"kind"`
	PublicationID string `json:"publicationId"`
	URL           string `json:"url,omitempty"`
}
type proposedResetSchedule struct {
	Precision string    `json:"precision"`
	From      time.Time `json:"from"`
	Through   time.Time `json:"through"`
}
type proposedResetEvent struct {
	Version     int                    `json:"version"`
	ID          string                 `json:"id"`
	Provider    string                 `json:"provider"`
	Confirms    string                 `json:"confirms,omitempty"`
	PlanIDs     []string               `json:"planIds,omitempty"`
	RowID       string                 `json:"rowId"`
	Status      string                 `json:"status"`
	PublishedAt time.Time              `json:"publishedAt"`
	Schedule    *proposedResetSchedule `json:"schedule,omitempty"`
	ExpiresAt   time.Time              `json:"expiresAt"`
	Source      proposedResetSource    `json:"source"`
}
type proposedRowsProjection struct {
	wire.RowsProjection
	ResetEvents *[]proposedResetEvent `json:"resetEvents,omitempty"`
}
type proposedRowsSnapshot struct {
	Sequence   uint64                 `json:"sequence"`
	Projection proposedRowsProjection `json:"projection"`
}

func proposalRoot() string {
	_, file, _, _ := runtime.Caller(0)
	return filepath.Clean(filepath.Join(filepath.Dir(file), "../../../.."))
}

func proposalSchema(t *testing.T) *jsonschema.Schema {
	t.Helper()
	root := proposalRoot()
	raw, err := wireschema.Generate(root)
	if err != nil {
		t.Fatal(err)
	}
	var base map[string]any
	if err = json.Unmarshal(raw, &base); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(root, "schema/app-cli/proposals/announced-reset-events.schema.json"))
	if err != nil {
		t.Fatal(err)
	}
	var overlay map[string]any
	if err = json.Unmarshal(data, &overlay); err != nil {
		t.Fatal(err)
	}
	defs := base["$defs"].(map[string]any)
	for key, value := range overlay["$defs"].(map[string]any) {
		if _, exists := defs[key]; exists {
			t.Fatalf("schema definition collision: %s", key)
		}
		defs[key] = value
	}
	props := defs["RowsProjection"].(map[string]any)["properties"].(map[string]any)
	if _, exists := props["resetEvents"]; exists {
		t.Fatal("production schema already has resetEvents")
	}
	props["resetEvents"] = overlay["properties"].(map[string]any)["resetEvents"]
	encoded, err := json.Marshal(base)
	if err != nil {
		t.Fatal(err)
	}
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(encoded))
	if err != nil {
		t.Fatal(err)
	}
	c := jsonschema.NewCompiler()
	c.AssertFormat()
	const id = "https://modelplan.ai/schema/app-cli/app-server.json"
	if err = c.AddResource(id, doc); err != nil {
		t.Fatal(err)
	}
	compiled, err := c.Compile(id + "#/$defs/Response")
	if err != nil {
		t.Fatal(err)
	}
	return compiled
}

func proposalFixtures(t *testing.T) map[string][]byte {
	t.Helper()
	published := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	in := rows.Input{Now: published, ConsentGeneration: 7,
		Catalogue: []rows.CatalogueEntry{{ToolID: "codex", Detected: true, ReaderExists: true}},
		Consents:  []rows.ConsentRecord{{ToolID: "codex", Generation: 7, State: rows.ConsentAllowed}}}
	ref1, ref2 := "0123456789abcdef", "fedcba9876543210"
	observed, fresh := published.Add(-time.Minute), published.Add(time.Hour)
	in.Profiles = []rows.ProfileState{{ToolID: "codex", ProfileKey: "a", LatestAttempt: rows.AttemptResultSucceeded, ObservedAt: &observed, WithinFreshness: true, FreshUntil: &fresh}, {ToolID: "codex", ProfileKey: "b", LatestAttempt: rows.AttemptResultSucceeded, ObservedAt: &observed, WithinFreshness: true, FreshUntil: &fresh}}
	in.Accounts = []rows.AccountInput{{ToolID: "codex", ProfileKey: "a", Route: rows.RouteRuntimeRPC, SubscriptionRef: &ref1, PlanID: "pro"}, {ToolID: "codex", ProfileKey: "b", Route: rows.RouteRuntimeRPC, SubscriptionRef: &ref2, PlanID: "plus"}}
	projection := rows.Build(in)
	if err := rows.Validate(in, projection); err != nil {
		t.Fatal(err)
	}
	if len(projection.Rows) != 1 || projection.Rows[0].ID != "codex" {
		t.Fatal("fixture must contain the affected tool row")
	}
	source := proposedResetSource{Kind: "publication", PublicationID: "0123456789abcdef01234567", URL: "https://example.test/reset"}
	id, err := proposalID("openai", published.Add(3*time.Hour), source.URL, "r-scheduled")
	if err != nil {
		t.Fatal(err)
	}
	scheduled := proposedResetEvent{Version: 1, ID: id, Provider: "openai", PlanIDs: []string{"pro"}, RowID: "codex", Status: "announced", PublishedAt: published,
		Schedule: &proposedResetSchedule{Precision: "window", From: published.Add(time.Hour), Through: published.Add(3 * time.Hour)}, ExpiresAt: published.Add(3 * time.Hour), Source: source}
	unscheduledID, err := proposalID("openai", time.Time{}, "", "r-unscheduled")
	if err != nil {
		t.Fatal(err)
	}
	unscheduled := proposedResetEvent{Version: 1, ID: unscheduledID, Provider: "openai", RowID: "codex", Status: "announced", PublishedAt: published,
		ExpiresAt: published.Add(48 * time.Hour), Source: proposedResetSource{Kind: source.Kind, PublicationID: source.PublicationID}}
	confirmed := proposedResetEvent{Version: 1, ID: id, Provider: "openai", Confirms: id, PlanIDs: []string{"pro"}, RowID: "codex", Status: "confirmed", PublishedAt: published,
		ExpiresAt: published.Add(24 * time.Hour), Source: source}
	empty := []proposedResetEvent{}
	one := func(e proposedResetEvent) *[]proposedResetEvent { a := []proposedResetEvent{e}; return &a }
	cases := map[string]*[]proposedResetEvent{"legacy-omitted.json": nil, "known-empty.json": &empty,
		"scheduled-announcement.json": one(scheduled), "unscheduled-announcement.json": one(unscheduled), "confirmed.json": one(confirmed), "app-journey-plan-scoped.json": one(scheduled)}
	result := make(map[string][]byte, len(cases))
	for name, events := range cases {
		message := wire.Success[proposedRowsSnapshot]{JSONRPC: wire.JSONRPC, ID: json.RawMessage(`7`),
			Result: wire.Envelope[proposedRowsSnapshot]{SessionID: "s-synthetic", StoreEpoch: "e-synthetic", ConsentGeneration: 7,
				Data: proposedRowsSnapshot{Sequence: 1, Projection: proposedRowsProjection{RowsProjection: wire.Project(projection), ResetEvents: events}}}}
		data, err := json.MarshalIndent(message, "", "  ")
		if err != nil {
			t.Fatal(err)
		}
		result[name] = append(data, '\n')
	}
	return result
}

func TestAnnouncedResetProposalGeneratedFixturesAndCompatibility(t *testing.T) {
	proposed, current := proposalSchema(t), schema(t, "Response")
	for name, generated := range proposalFixtures(t) {
		t.Run(name, func(t *testing.T) {
			path := filepath.Join(proposalRoot(), "schema/app-cli/proposals/fixtures", name)
			if os.Getenv("UPDATE_RESET_PROPOSAL") == "1" {
				if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(path, generated, 0644); err != nil {
					t.Fatal(err)
				}
			}
			stored, err := os.ReadFile(path)
			if err != nil {
				t.Fatal(err)
			}
			if !bytes.Equal(stored, generated) {
				t.Fatal("proposal fixture drift; regenerate with UPDATE_RESET_PROPOSAL=1")
			}
			doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(stored))
			if err != nil {
				t.Fatal(err)
			}
			if err := proposed.Validate(doc); err != nil {
				t.Fatalf("proposed schema: %v", err)
			}
			oldErr := current.Validate(doc)
			if name == "legacy-omitted.json" && oldErr != nil {
				t.Fatalf("legacy message rejected: %v", oldErr)
			}
			if name != "legacy-omitted.json" && oldErr == nil {
				t.Fatal("strict old schema accepted the new field; capability gate is required")
			}
		})
	}
}

func TestAnnouncedResetProposalRejectsMalformedOrPrivateFields(t *testing.T) {
	compiled := proposalSchema(t)
	raw := proposalFixtures(t)["scheduled-announcement.json"]
	tests := []struct {
		name   string
		change func(map[string]any)
	}{
		{"version", func(e map[string]any) { e["version"] = 2 }},
		{"unknown status", func(e map[string]any) { e["status"] = "acknowledged" }},
		{"private account", func(e map[string]any) { e["accountId"] = "secret" }},
		{"invalid event id", func(e map[string]any) { e["id"] = "account@example.test" }},
		{"source not publication", func(e map[string]any) { e["source"].(map[string]any)["kind"] = "local" }},
		{"bad publication id", func(e map[string]any) { e["source"].(map[string]any)["publicationId"] = "unknown" }},
		{"credential url", func(e map[string]any) { e["source"].(map[string]any)["url"] = "https://user:pass@example.test/reset" }},
		{"invalid time", func(e map[string]any) { e["expiresAt"] = "soon" }},
		{"unknown precision", func(e map[string]any) { e["schedule"].(map[string]any)["precision"] = "exact" }},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var doc map[string]any
			if err := json.Unmarshal(raw, &doc); err != nil {
				t.Fatal(err)
			}
			projection := doc["result"].(map[string]any)["data"].(map[string]any)["projection"].(map[string]any)
			tc.change(projection["resetEvents"].([]any)[0].(map[string]any))
			if err := validate(t, compiled, doc); err == nil {
				t.Fatal("invalid event accepted")
			}
		})
	}
}

// Reference semantics for review: this is test-only, not an engine implementation.
func proposalPhase(event proposedResetEvent, now time.Time) string {
	if !now.Before(event.ExpiresAt) {
		return "expired"
	}
	if event.Status == "confirmed" {
		return "confirmed"
	}
	if event.Schedule != nil && !now.Before(event.Schedule.From) {
		return "active"
	}
	return "announced"
}
func checkProposalSemantics(event proposedResetEvent, rowIDs map[string]bool, verifiedPublication string) error {
	if event.Source.PublicationID != verifiedPublication || !rowIDs[event.RowID] {
		return fmt.Errorf("unverified source or unmatched row")
	}
	if event.PublishedAt.IsZero() || !event.ExpiresAt.After(event.PublishedAt) {
		return fmt.Errorf("invalid lifetime")
	}
	if event.Schedule != nil && !event.Schedule.Through.After(event.Schedule.From) {
		return fmt.Errorf("invalid window")
	}
	if event.Status == "announced" && event.Schedule != nil && !event.ExpiresAt.Equal(event.Schedule.Through) {
		return fmt.Errorf("scheduled expiry")
	}
	if event.Status == "announced" && event.Schedule == nil && !event.ExpiresAt.Equal(event.PublishedAt.Add(48*time.Hour)) {
		return fmt.Errorf("unscheduled expiry")
	}
	if event.Status == "confirmed" && !event.ExpiresAt.Equal(event.PublishedAt.Add(24*time.Hour)) {
		return fmt.Errorf("confirmed expiry")
	}
	return nil
}

func checkProposalSet(events []proposedResetEvent, rowIDs map[string]bool, publication string) error {
	seen := map[string]bool{}
	for _, event := range events {
		if err := checkProposalSemantics(event, rowIDs, publication); err != nil {
			return err
		}
		key := event.RowID + "\x00" + event.ID
		if seen[key] {
			return fmt.Errorf("duplicate row/event identity")
		}
		seen[key] = true
	}
	return nil
}

func TestAnnouncedResetProposalLifecycleAndTrust(t *testing.T) {
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	source := proposedResetSource{Kind: "publication", PublicationID: "0123456789abcdef01234567"}
	id, err := proposalID("openai", now.Add(3*time.Hour), "https://example.test/reset", "r-scheduled")
	if err != nil {
		t.Fatal(err)
	}
	event := proposedResetEvent{Version: 1, ID: id, Provider: "openai", RowID: "codex", Status: "announced", PublishedAt: now,
		Schedule: &proposedResetSchedule{Precision: "window", From: now.Add(time.Hour), Through: now.Add(3 * time.Hour)}, ExpiresAt: now.Add(3 * time.Hour), Source: source}
	rows := map[string]bool{"codex": true}
	if err := checkProposalSemantics(event, rows, source.PublicationID); err != nil {
		t.Fatal(err)
	}
	for _, test := range []struct {
		at   time.Time
		want string
	}{{now, "announced"}, {now.Add(time.Hour), "active"}, {now.Add(3 * time.Hour), "expired"}} {
		if got := proposalPhase(event, test.at); got != test.want {
			t.Fatalf("phase at %v = %s, want %s", test.at, got, test.want)
		}
	}
	// Acknowledgement belongs to each surface and does not change source status.
	acknowledged := map[string]bool{"sliver": true, "menu": false}
	if !acknowledged["sliver"] || acknowledged["menu"] || proposalPhase(event, now) != "announced" {
		t.Fatal("surface acknowledgements were conflated")
	}
	unscheduled := event
	unscheduled.Schedule = nil
	unscheduled.ExpiresAt = now.Add(48 * time.Hour)
	confirmed := event
	confirmed.Status = "confirmed"
	confirmed.Confirms = confirmed.ID
	confirmed.Schedule = nil
	confirmed.ExpiresAt = now.Add(24 * time.Hour)
	for _, e := range []proposedResetEvent{unscheduled, confirmed} {
		if err := checkProposalSemantics(e, rows, source.PublicationID); err != nil {
			t.Fatal(err)
		}
	}
	if proposalPhase(unscheduled, now.Add(48*time.Hour)) != "expired" || proposalPhase(confirmed, now) != "confirmed" || proposalPhase(confirmed, now.Add(24*time.Hour)) != "expired" {
		t.Fatal("lifecycle boundary")
	}
	if checkProposalSemantics(event, rows, "unverified") == nil || checkProposalSemantics(event, map[string]bool{}, source.PublicationID) == nil {
		t.Fatal("unverified source or unknown row accepted")
	}
	invalid := event
	invalid.ExpiresAt = now.Add(2 * time.Hour)
	if checkProposalSemantics(invalid, rows, source.PublicationID) == nil {
		t.Fatal("wrong scheduled expiry accepted")
	}
	if checkProposalSet([]proposedResetEvent{event, event}, rows, source.PublicationID) == nil {
		t.Fatal("duplicate row/event identity accepted")
	}
	if checkProposalSet([]proposedResetEvent{event, confirmed}, rows, source.PublicationID) == nil {
		t.Fatal("same row/event with different status accepted twice")
	}
	invalid = event
	invalid.Schedule = &proposedResetSchedule{Precision: "window", From: now.Add(3 * time.Hour), Through: now.Add(time.Hour)}
	if checkProposalSemantics(invalid, rows, source.PublicationID) == nil {
		t.Fatal("reversed window accepted")
	}
	// Publication refresh changes provenance, not the stable event or notification key.
	updated := event
	updated.Source.PublicationID = "fedcba9876543210fedcba98"
	if !reflect.DeepEqual([]string{event.Source.Kind, event.ID}, []string{updated.Source.Kind, updated.ID}) {
		t.Fatal("publication refresh changed event identity")
	}
}

// proposalID is a review-only reference: length framing avoids ambiguous tuples.
func proposalID(provider string, instant time.Time, sourceURL, verifiedEventID string) (string, error) {
	if provider == "" {
		return "", fmt.Errorf("missing provider")
	}
	if instant.IsZero() || sourceURL == "" {
		if !regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$`).MatchString(verifiedEventID) {
			return "", fmt.Errorf("missing or invalid verified event id")
		}
		return verifiedEventID, nil
	}
	u, err := url.Parse(sourceURL)
	if err != nil || u.Scheme != "https" || u.Hostname() == "" || u.User != nil {
		return "", fmt.Errorf("missing or invalid identity input")
	}
	h := sha256.New()
	for _, part := range []string{"modelplan-reset-event-v1", provider, instant.UTC().Format(time.RFC3339Nano), sourceURL} {
		var size [8]byte
		binary.BigEndian.PutUint64(size[:], uint64(len(part)))
		h.Write(size[:])
		h.Write([]byte(part))
	}
	return fmt.Sprintf("%x", h.Sum(nil)), nil
}

// resolveConfirmations requires an explicit reference to an already-known announcement.
func resolveConfirmations(events []proposedResetEvent, known map[string]bool) ([]proposedResetEvent, int) {
	var out []proposedResetEvent
	dropped := 0
	for _, e := range events {
		if e.Status == "confirmed" && (e.Confirms == "" || e.Confirms != e.ID || !known[e.Confirms]) {
			dropped++
			continue
		}
		if e.Status != "announced" && e.Status != "confirmed" {
			continue
		}
		out = append(out, e)
	}
	return out, dropped
}

// safeProposalLink demonstrates exact host membership, not a production registry.
func safeProposalLink(raw string, official map[string]bool) string {
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.User != nil || !official[u.Hostname()] {
		return ""
	}
	return raw
}
func TestAnnouncedResetProposalIdentityAndDecisions(t *testing.T) {
	instant := time.Date(2026, 11, 1, 15, 0, 0, 0, time.UTC)
	id, err := proposalID("openai", instant, "https://example.test/reset", "r-fallback")
	if err != nil {
		t.Fatal(err)
	}
	same, _ := proposalID("openai", instant.In(time.FixedZone("other", 3600)), "https://example.test/reset", "r-fallback")
	if id != same {
		t.Fatal("instant must be normalized")
	}
	for _, in := range []struct {
		provider string
		when     time.Time
		source   string
	}{{"other", instant, "https://example.test/reset"}, {"openai", instant.Add(time.Second), "https://example.test/reset"}, {"openai", instant, "https://example.test/other"}} {
		other, err := proposalID(in.provider, in.when, in.source, "r-fallback")
		if err != nil || other == id {
			t.Fatal("identity tuple collision")
		}
	}
	for _, input := range []struct {
		when   time.Time
		source string
	}{{time.Time{}, "https://example.test/reset"}, {instant, ""}, {time.Time{}, ""}} {
		got, err := proposalID("openai", input.when, input.source, "r-unscheduled")
		if err != nil || got != "r-unscheduled" {
			t.Fatal("verified publication fallback not used")
		}
		if _, err := proposalID("openai", input.when, input.source, ""); err == nil {
			t.Fatal("missing verified event ID accepted")
		}
	}
	linked := proposedResetEvent{ID: id, Status: "confirmed", Confirms: id}
	unlinked := linked
	unlinked.Confirms = "unknown"
	got, dropped := resolveConfirmations([]proposedResetEvent{linked, unlinked}, map[string]bool{id: true})
	if len(got) != 1 || dropped != 1 {
		t.Fatal("unlinked confirmation not counted and dropped")
	}
	if safeProposalLink("https://example.test/reset", map[string]bool{"example.test": true}) == "" || safeProposalLink("https://evil.test/reset", map[string]bool{"example.test": true}) != "" {
		t.Fatal("source host policy")
	}
}

// The consumer fixture includes two same-route members; only the named plan matches.
func TestAnnouncedResetProposalAppJourneyFixture(t *testing.T) {
	var message struct {
		Result struct {
			Data struct {
				Projection struct {
					Rows []struct {
						ID       string `json:"id"`
						Accounts []struct {
							Route           string `json:"route"`
							SubscriptionRef string `json:"subscriptionRef"`
							Plan            struct {
								ID string `json:"id"`
							} `json:"plan"`
						} `json:"accounts"`
					} `json:"rows"`
					ResetEvents []proposedResetEvent `json:"resetEvents"`
				} `json:"projection"`
			} `json:"data"`
		} `json:"result"`
	}
	if err := json.Unmarshal(proposalFixtures(t)["app-journey-plan-scoped.json"], &message); err != nil {
		t.Fatal(err)
	}
	p := message.Result.Data.Projection
	if len(p.Rows) != 1 || len(p.Rows[0].Accounts) != 2 || len(p.ResetEvents) != 1 {
		t.Fatal("fixture missing row, members or event")
	}
	event := p.ResetEvents[0]
	if p.Rows[0].ID != event.RowID || event.Provider != "openai" || len(event.PlanIDs) != 1 {
		t.Fatal("event not mapped to row or plan")
	}
	matches := 0
	for _, account := range p.Rows[0].Accounts {
		if account.Plan.ID == event.PlanIDs[0] {
			matches++
			if account.SubscriptionRef != "0123456789abcdef" {
				t.Fatal("wrong matching member")
			}
		}
	}
	if matches != 1 || p.Rows[0].Accounts[0].Route != p.Rows[0].Accounts[1].Route {
		t.Fatal("plan-scoped fixture does not distinguish same-route members")
	}
}
