// SPDX-License-Identifier: MIT
package rows

import "time"

type ResetSource struct {
	Kind          string      `json:"kind"`
	PublicationID string      `json:"publicationId"`
	URL           string      `json:"url,omitempty" null:"coalesced"`
	Links         []ResetLink `json:"links,omitempty" null:"coalesced"`
}

// ResetLink is one typed citation. Display order is the client's choice; the
// producer publishes links in a stable type order.
type ResetLink struct {
	Type string `json:"type"`
	URL  string `json:"url"`
}
type ResetSchedule struct {
	Precision string    `json:"precision"`
	From      time.Time `json:"from"`
	Through   time.Time `json:"through"`
}
type ResetEvent struct {
	Version  int    `json:"version"`
	ID       string `json:"id"`
	Provider string `json:"provider"`
	RowID    string `json:"rowId"`
	Status   string `json:"status"`
	// Kind is "reset_credit" (extra resets issued) or "direct_reset" (usage
	// limits reset). Absent from older producers; clients treat it as direct_reset.
	Kind string `json:"kind,omitempty" null:"coalesced"`
	// ConfirmedAt is present only on a confirmed event: the publication's own
	// confirmation time when it has one, otherwise when this CLI first read the
	// confirmation (ConfirmedAtBasis "observed" after it had read the
	// announcement, "firstSeen" otherwise, which is an upper bound).
	ConfirmedAt      *time.Time     `json:"confirmedAt,omitempty" null:"coalesced"`
	ConfirmedAtBasis string         `json:"confirmedAtBasis,omitempty" null:"coalesced"`
	Confirms         string         `json:"confirms,omitempty" null:"coalesced"`
	PlanIDs          []string       `json:"planIds,omitempty" null:"coalesced"`
	PublishedAt      time.Time      `json:"publishedAt"`
	Schedule         *ResetSchedule `json:"schedule,omitempty" null:"coalesced"`
	ExpiresAt        time.Time      `json:"expiresAt"`
	Source           ResetSource    `json:"source"`
}
