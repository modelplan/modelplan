// SPDX-License-Identifier: MIT
// Package resetevents normalizes verified public reset records for rows.
package resetevents

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"net/url"
	"regexp"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

type Source = rows.ResetSource
type Schedule = rows.ResetSchedule
type Event = rows.ResetEvent
type record struct {
	ID          string     `json:"id"`
	Provider    string     `json:"provider"`
	EventType   string     `json:"eventType"`
	Status      string     `json:"status"`
	At          *time.Time `json:"at"`
	URL         string     `json:"url"`
	PublishedAt time.Time  `json:"publishedAt"`
	Schedule    *Schedule  `json:"schedule"`
	PlanIDs     *[]string  `json:"planIds"`
	Scope       *string    `json:"scope"`
	Confirms    string     `json:"confirms"`
}

var publicID = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$`)
var publicationID = regexp.MustCompile(`^[a-f0-9]{24}$`)
var safePlan = map[string]bool{"free": true, "plus": true, "pro": true, "team": true, "teams": true, "business": true, "enterprise": true}
var planID = regexp.MustCompile(`^[a-z][a-z0-9-]{0,47}$`)

func eventID(r record) (string, bool) {
	if r.At == nil || r.URL == "" {
		return r.ID, publicID.MatchString(r.ID)
	}
	u, err := url.Parse(r.URL)
	if err != nil || u.Scheme != "https" || u.Hostname() == "" || u.User != nil || r.At.IsZero() {
		return "", false
	}
	h := sha256.New()
	for _, part := range []string{"modelplan-reset-event-v1", r.Provider, r.At.UTC().Format(time.RFC3339Nano), r.URL} {
		var n [8]byte
		binary.BigEndian.PutUint64(n[:], uint64(len(part)))
		h.Write(n[:])
		h.Write([]byte(part))
	}
	return fmt.Sprintf("%x", h.Sum(nil)), true
}
func knownPlan(ids *[]string, row rows.Row) ([]string, bool) {
	if ids == nil {
		return nil, true
	}
	if len(*ids) == 0 || len(*ids) > 32 {
		return nil, false
	}
	out := append([]string(nil), (*ids)...)
	sort.Strings(out)
	matched := false
	for i, id := range out {
		if !planID.MatchString(id) || !safePlan[id] || i > 0 && out[i-1] == id {
			return nil, false
		}
		for _, account := range row.Accounts {
			if account.Plan.ID == id {
				matched = true
			}
		}
	}
	return out, matched
}

// Project requires an already verified digest. Dropped is an in-memory aggregate;
// it does not include record IDs and is not sent to telemetry. This is not yet
// wired to the server: upstream plan/link and official-host interfaces need review.
func Project(d *digest.Digest, projection rows.Projection, now time.Time) ([]Event, int) {
	if d == nil || !publicationID.MatchString(d.PublicationID) {
		return nil, 0
	}
	byTool := map[string]rows.Row{}
	for _, row := range projection.Rows {
		if row.Kind == rows.KindTool {
			byTool[row.ID] = row
		}
	}
	known := map[string]Event{}
	blocked := map[string]bool{}
	var confirmations []record
	for _, raw := range d.Resets {
		var r record
		if json.Unmarshal(raw, &r) != nil || r.Provider != "openai" || r.PublishedAt.IsZero() || r.PublishedAt.After(now) {
			continue
		}
		if r.EventType == "direct_reset_reported_complete" && r.Status == "upstream-confirmed" {
			confirmations = append(confirmations, r)
			continue
		}
		if r.EventType != "direct_reset_announced" || r.Status != "upstream-announced" {
			continue
		}
		// The current publication has a free-form scope but no reviewed plan
		// mapping. Never silently promote such a record to row-wide.
		if r.Scope != nil && *r.Scope != "" {
			continue
		}
		row, ok := byTool["codex"]
		if !ok {
			continue
		}
		plans, ok := knownPlan(r.PlanIDs, row)
		if !ok {
			continue
		}
		id, ok := eventID(r)
		if !ok {
			continue
		}
		expiry := r.PublishedAt.Add(48 * time.Hour)
		if r.Schedule != nil {
			switch r.Schedule.Precision {
			case "window", "date", "approximate", "deadline":
			default:
				continue
			}
			if !r.Schedule.Through.After(r.Schedule.From) {
				continue
			}
			expiry = r.Schedule.Through
		}
		if !expiry.After(r.PublishedAt) {
			continue
		}
		if blocked[id] {
			continue
		}
		if _, exists := known[id]; exists {
			delete(known, id)
			blocked[id] = true
			continue
		}
		known[id] = Event{Version: 1, ID: id, Provider: r.Provider, RowID: row.ID, Status: "announced", PlanIDs: plans, PublishedAt: r.PublishedAt, Schedule: r.Schedule, ExpiresAt: expiry, Source: Source{Kind: "publication", PublicationID: d.PublicationID}}
	}
	dropped := 0
	for _, r := range confirmations {
		e, ok := known[r.Confirms]
		if !ok || r.Confirms == "" {
			dropped++
			continue
		}
		if r.PublishedAt.Before(e.PublishedAt) {
			dropped++
			continue
		}
		e.Status = "confirmed"
		e.Confirms = e.ID
		e.PublishedAt = r.PublishedAt
		e.Schedule = nil
		e.ExpiresAt = r.PublishedAt.Add(24 * time.Hour)
		known[e.ID] = e
	}
	out := make([]Event, 0, len(known))
	for _, e := range known {
		if now.Before(e.ExpiresAt) {
			out = append(out, e)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	if len(out) > 64 {
		out = out[:64]
	}
	return out, dropped
}
