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
	"strings"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

type Source = rows.ResetSource
type Link = rows.ResetLink
type Schedule = rows.ResetSchedule
type Event = rows.ResetEvent
type record struct {
	ID             string     `json:"id"`
	Provider       string     `json:"provider"`
	EventType      string     `json:"eventType"`
	Status         string     `json:"status"`
	At             *time.Time `json:"at"`
	URL            string     `json:"url"`
	ObservationURL string     `json:"observationUrl"`
	PublishedAt    time.Time  `json:"publishedAt"`
	Schedule       *Schedule  `json:"schedule"`
	PlanIDs        *[]string  `json:"planIds"`
	Scope          *string    `json:"scope"`
	Confirms       string     `json:"confirms"`
	ConfirmedAt    *time.Time `json:"confirmedAt"`
}

// Kinds on the wire. A reset credit ("extra resets issued") is news about
// redeemable resets, never evidence that a quota window restarted.
const (
	KindResetCredit = "reset_credit"
	KindDirectReset = "direct_reset"
)

// Bases for ConfirmedAt when the publication does not carry its own time.
const (
	BasisPublished = "published"
	BasisObserved  = "observed"
	BasisFirstSeen = "firstSeen"
)

// confirmedLifetime bounds a confirmed event on the wire; the client decides
// how long its dot stays within it.
const confirmedLifetime = 24 * time.Hour

// awaitingLifetime keeps a scheduled forecast after its window ends, so the
// client can show it awaiting confirmation; a confirmation replaces it sooner.
const awaitingLifetime = 24 * time.Hour

// memoRetention outlasts the publication's 14-day reset horizon, so a
// remembered confirmation is never forgotten while its record is still
// published and can never be re-dated as a fresh one.
const memoRetention = 15 * 24 * time.Hour

func kindOf(eventType string) string {
	if eventType == "reset_credit_issued" {
		return KindResetCredit
	}
	return KindDirectReset
}

// Memo remembers, for this process only, when an event was first read as
// announced and when as confirmed, so a confirmation that carries no time of
// its own keeps one stable instant across refreshes. Nil disables it.
type Memo struct {
	mu        sync.Mutex
	announced map[string]time.Time
	confirmed map[string]memoConfirmation
}

type memoConfirmation struct {
	at    time.Time
	basis string
}

func NewMemo() *Memo {
	return &Memo{announced: map[string]time.Time{}, confirmed: map[string]memoConfirmation{}}
}

func (m *Memo) sawAnnounced(id string, now time.Time) {
	if m == nil {
		return
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.announced[id]; !ok {
		m.announced[id] = now
	}
}

// remembered returns the confirmation instant already recorded for id.
func (m *Memo) remembered(id string) (time.Time, string, bool) {
	if m == nil {
		return time.Time{}, "", false
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	c, ok := m.confirmed[id]
	return c.at, c.basis, ok
}

// confirmation returns the first instant this process read id as confirmed.
func (m *Memo) confirmation(id string, now time.Time) (time.Time, string) {
	if m == nil {
		return now, BasisFirstSeen
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if c, ok := m.confirmed[id]; ok {
		return c.at, c.basis
	}
	c := memoConfirmation{at: now, basis: BasisFirstSeen}
	if _, ok := m.announced[id]; ok {
		c.basis = BasisObserved
	}
	m.confirmed[id] = c
	return c.at, c.basis
}

// prune drops entries older than any event lifetime; the maps stay small.
func (m *Memo) prune(now time.Time) {
	if m == nil {
		return
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	for id, at := range m.announced {
		if now.Sub(at) > memoRetention {
			delete(m.announced, id)
		}
	}
	for id, c := range m.confirmed {
		if now.Sub(c.at) > memoRetention {
			delete(m.confirmed, id)
		}
	}
}

var publicID = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$`)
var publicationID = regexp.MustCompile(`^[a-f0-9]{24}$`)
var safePlan = map[string]bool{"free": true, "plus": true, "pro": true, "team": true, "teams": true, "business": true, "enterprise": true}
var planID = regexp.MustCompile(`^[a-z][a-z0-9-]{0,47}$`)

// Typed source-link admission: the AIhot event page, the original X post and an
// optional official vendor page. Exact hosts only; a failing candidate link is
// omitted without dropping the event or changing its times or identity.
var originalLinkHosts = map[string]bool{"x.com": true, "twitter.com": true}
var originalStatusPath = regexp.MustCompile(`^/[A-Za-z0-9_]{1,15}/status/[0-9]{1,19}$`)
var officialLinkHosts = map[string]bool{
	"openai.com": true, "help.openai.com": true, "status.openai.com": true,
	"platform.openai.com": true, "developers.openai.com": true,
	"anthropic.com": true, "www.anthropic.com": true, "support.anthropic.com": true,
	"status.anthropic.com": true, "docs.anthropic.com": true,
}

// Paths must be plain public page paths, not account, credential, or encoded data.
var publicPath = regexp.MustCompile(`^/[A-Za-z0-9][A-Za-z0-9/_-]*$`)

// AIhot citations are public reset article slugs; official citations use
// public documentation, news or incident paths, never arbitrary profiles.
var aihotArticlePath = regexp.MustCompile(`(?i)^/[a-z0-9-]*reset[a-z0-9-]*$`)
var officialPublicPath = regexp.MustCompile(`(?i)^/(incidents|docs|en/docs|articles|news|index|research|blog|updates|releases)(/[a-z0-9_-]+)*$`)
var privatePathPart = regexp.MustCompile(`(?i)(^|[/_-])(user|users|profile|profiles|account|accounts|member|members|personal|private|settings|login|session|auth|token|secret|password|credential|api|key|email|me)([/_-]|$)`)

func admittedLink(kind, raw string) (Link, bool) {
	if raw == "" || len(raw) > 2048 || strings.ContainsAny(raw, "?#%") {
		return Link{}, false
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.User != nil || u.Opaque != "" || u.ForceQuery || u.RawQuery != "" || u.Fragment != "" || u.RawFragment != "" {
		return Link{}, false
	}
	if u.Host != u.Hostname() {
		return Link{}, false
	}
	host := strings.ToLower(u.Hostname())
	switch kind {
	case "aihot":
		if host != "aihot.news" || !aihotArticlePath.MatchString(u.Path) || !publicPath.MatchString(u.Path) || privatePathPart.MatchString(u.Path) {
			return Link{}, false
		}
	case "original":
		if !originalLinkHosts[host] || !originalStatusPath.MatchString(u.Path) || privatePathPart.MatchString(u.Path) {
			return Link{}, false
		}
	case "official":
		if !officialLinkHosts[host] || !officialPublicPath.MatchString(u.Path) || !publicPath.MatchString(u.Path) || privatePathPart.MatchString(u.Path) {
			return Link{}, false
		}
	default:
		return Link{}, false
	}
	return Link{Type: kind, URL: raw}, true
}

// Only the publication's reviewed URL fields are candidates. Classify by
// admitted host and path, never by an upstream-supplied link type.
func sourceLinks(r record) []Link {
	var out []Link
	for _, kind := range []string{"aihot", "official", "original"} {
		for _, raw := range []string{r.URL, r.ObservationURL} {
			if link, ok := admittedLink(kind, raw); ok {
				out = append(out, link)
				break
			}
		}
	}
	return out
}

func eventID(r record) (string, bool) {
	if r.At == nil || r.URL == "" {
		return r.ID, publicID.MatchString(r.ID)
	}
	u, err := url.Parse(r.URL)
	if r.At.IsZero() {
		return "", false
	}
	if err != nil || u.Scheme != "https" || u.Hostname() == "" || u.User != nil {
		return r.ID, publicID.MatchString(r.ID)
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
// it does not include record IDs and is not sent to telemetry. The server
// supplies an already verified publication and capability-gates the result.
func Project(d *digest.Digest, projection rows.Projection, now time.Time) ([]Event, int) {
	return ProjectWithMemo(d, projection, now, nil)
}

// ProjectWithMemo is Project with a process memo for confirmation times.
func ProjectWithMemo(d *digest.Digest, projection rows.Projection, now time.Time, memo *Memo) ([]Event, int) {
	memo.prune(now)
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
	var confirmations, standalone []record
	for _, raw := range d.Resets {
		var r record
		if json.Unmarshal(raw, &r) != nil || r.Provider != "openai" || r.PublishedAt.IsZero() || r.PublishedAt.After(now) {
			continue
		}
		switch r.EventType {
		case "reset_credit_issued", "direct_reset_announced", "direct_reset_reported_complete":
		default:
			continue
		}
		if r.Status == "upstream-confirmed" {
			// A confirmation linked to a separate announcement replaces it; one
			// without a link is the same record whose status moved (AIhot keeps
			// its identity when it confirms a reset or a reset credit).
			if r.EventType == "direct_reset_reported_complete" && r.Confirms != "" {
				confirmations = append(confirmations, r)
			} else {
				standalone = append(standalone, r)
			}
			continue
		}
		if r.Status != "upstream-announced" || r.EventType == "direct_reset_reported_complete" {
			continue
		}
		// V1 has no reviewed mapping for free-form scope. The coordinator's
		// explicit fallback is row-wide; never export or parse the raw text.
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
			if r.Schedule.Through.Before(r.Schedule.From) ||
				(r.Schedule.Through.Equal(r.Schedule.From) && r.Schedule.Precision != "deadline") {
				continue
			}
			if !r.Schedule.Through.After(r.PublishedAt) {
				continue
			}
			expiry = r.Schedule.Through.Add(awaitingLifetime)
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
		memo.sawAnnounced(id, now)
		known[id] = Event{Version: 1, ID: id, Provider: r.Provider, RowID: row.ID, Status: "announced", Kind: kindOf(r.EventType), PlanIDs: plans, PublishedAt: r.PublishedAt, Schedule: r.Schedule, ExpiresAt: expiry, Source: Source{Kind: "publication", PublicationID: d.PublicationID, Links: sourceLinks(r)}}
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
		at := r.PublishedAt
		e.ConfirmedAt, e.ConfirmedAtBasis = &at, BasisPublished
		e.ExpiresAt = r.PublishedAt.Add(confirmedLifetime)
		// A confirmation's own admitted links supersede the announcement's;
		// a confirmation without links keeps the original citations.
		if links := sourceLinks(r); len(links) > 0 {
			e.Source.Links = links
		}
		known[e.ID] = e
	}
	for _, r := range standalone {
		if e, ok := confirmedEvent(r, byTool, d.PublicationID, now, memo); ok {
			known[e.ID] = e
		}
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

// confirmedEvent admits a confirmed record that is its own event. Without a
// published confirmation time it is admitted only while it is recent: within
// confirmedLifetime of the later of its post and its announced window end.
func confirmedEvent(r record, byTool map[string]rows.Row, publicationID string, now time.Time, memo *Memo) (Event, bool) {
	row, ok := byTool["codex"]
	if !ok {
		return Event{}, false
	}
	plans, ok := knownPlan(r.PlanIDs, row)
	if !ok {
		return Event{}, false
	}
	id, ok := eventID(r)
	if !ok {
		return Event{}, false
	}
	var at time.Time
	var basis string
	if r.ConfirmedAt != nil && !r.ConfirmedAt.IsZero() && !r.ConfirmedAt.After(now) && !r.ConfirmedAt.Before(r.PublishedAt) {
		at, basis = r.ConfirmedAt.UTC(), BasisPublished
	} else if remembered, rememberedBasis, ok := memo.remembered(id); ok {
		// Once remembered, the instant is fixed: the event lives exactly
		// confirmedLifetime after it and is never re-dated or re-admitted.
		at, basis = remembered, rememberedBasis
	} else {
		reference := r.PublishedAt
		if r.Schedule != nil && r.Schedule.Through.After(reference) {
			reference = r.Schedule.Through
		}
		if !now.Before(reference.Add(confirmedLifetime)) {
			return Event{}, false
		}
		at, basis = memo.confirmation(id, now)
	}
	expiry := at.Add(confirmedLifetime)
	if !expiry.After(r.PublishedAt) {
		return Event{}, false
	}
	return Event{Version: 1, ID: id, Provider: r.Provider, RowID: row.ID, Status: "confirmed", Kind: kindOf(r.EventType),
		ConfirmedAt: &at, ConfirmedAtBasis: basis, Confirms: id, PlanIDs: plans, PublishedAt: r.PublishedAt, ExpiresAt: expiry,
		Source: Source{Kind: "publication", PublicationID: publicationID, Links: sourceLinks(r)}}, true
}
