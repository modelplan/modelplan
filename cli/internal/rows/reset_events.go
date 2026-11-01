// SPDX-License-Identifier: MIT
package rows

import "time"

type ResetSource struct {
	Kind          string `json:"kind"`
	PublicationID string `json:"publicationId"`
	URL           string `json:"url,omitempty" null:"coalesced"`
}
type ResetSchedule struct {
	Precision string    `json:"precision"`
	From      time.Time `json:"from"`
	Through   time.Time `json:"through"`
}
type ResetEvent struct {
	Version     int            `json:"version"`
	ID          string         `json:"id"`
	Provider    string         `json:"provider"`
	RowID       string         `json:"rowId"`
	Status      string         `json:"status"`
	Confirms    string         `json:"confirms,omitempty" null:"coalesced"`
	PlanIDs     []string       `json:"planIds,omitempty" null:"coalesced"`
	PublishedAt time.Time      `json:"publishedAt"`
	Schedule    *ResetSchedule `json:"schedule,omitempty" null:"coalesced"`
	ExpiresAt   time.Time      `json:"expiresAt"`
	Source      ResetSource    `json:"source"`
}
