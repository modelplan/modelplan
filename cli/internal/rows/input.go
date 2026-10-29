// SPDX-License-Identifier: MIT
package rows

import "time"

// Input is a single command's immutable projection facts. Adapters own the I/O
// and generation fence. Callers must finish populating these slices before
// building and must not mutate them until the build completes. All fields are
// excluded from JSON: raw adapter facts must never be exported as display rows.
type Input struct {
	Now               time.Time `json:"-"`
	ConsentGeneration uint64    `json:"-"`
	// ConsentChanged requests the fail-closed shape after the publication retry: declared rows only.
	ConsentChanged bool             `json:"-"`
	ReadersOff     bool             `json:"-"`
	PrivacyBlocked bool             `json:"-"`
	ReadOnly       bool             `json:"-"`
	Offline        bool             `json:"-"`
	IdentityOff    bool             `json:"-"`
	Catalogue      []CatalogueEntry `json:"-"`
	Consents       []ConsentRecord  `json:"-"`
	Profiles       []ProfileState   `json:"-"`
	Accounts       []AccountInput   `json:"-"`
	Sources        []SourceState    `json:"-"`
	Admissions     []Admission      `json:"-"`
	// Union of keys from local.json plans, windows and resetCards, not array positions.
	DeclaredPlanIDs []string        `json:"-"`
	KeychainBlocks  []KeychainBlock `json:"-"`
}

// CatalogueEntry contains evaluated catalogue facts, not remote display text,
// paths, signals or hosts. Output names/art keys come from the CLI's title table.
type CatalogueEntry struct {
	ToolID       string
	ReaderID     string
	Backend      string
	Detected     bool
	Retired      bool
	ReaderExists bool
	Status       string
}

// ConsentRecord includes persisted allow/deny decisions and computed implicit
// facts from the same captured consent view used by admission. Omit an absent
// decision unless an adapter established implicit local/runtime permission.
// State must never be inferred from a reader's status string.
type ConsentRecord struct {
	ToolID         string
	Generation     uint64
	State          Consent
	Outdated       bool
	CleanupPending bool
}

// Admission describes a veto independently of saved consent. Veto is a raw
// compiled blocked value for the mapping table, not a message or credential.
// Empty Veto means there is no admission veto; reader existence is separate.
type Admission struct {
	ToolID string
	Veto   string
}

// ProfileState comes from READERS, or a corresponding cache-only adapter for a
// legacy/local source. (ToolID, DeclaredPlanID, ProfileKey) joins an AccountInput.
// ProfileKey is an internal correlation key, never a row/window id or locator.
// A declared account sets DeclaredPlanID and leaves ToolID empty.
type ProfileState struct {
	ToolID         string
	DeclaredPlanID string
	ProfileKey     string
	LatestAttempt  AttemptResult
	AttemptedAt    *time.Time
	// Keep raw time, including nil/future: the classifier must distinguish it.
	ObservedAt      *time.Time
	WithinFreshness bool
	FreshUntil      *time.Time
	LastFailure     *FailureInput
	// LoginChanged/GenerationChanged discard old numbers, not retain them.
	LoginChanged      bool
	GenerationChanged bool
	AccountLocator    *string
	Busy              bool
	CoolingDown       bool
	// NextAttemptAt is a known lower bound, not permission to bypass CoolingDown/Busy.
	NextAttemptAt *time.Time
}

type FailureInput struct {
	// Compiled status/error value, mapped and validated before export.
	Code string
	At   *time.Time
}

// AccountInput carries measurements only. ProfileState is authoritative for
// attempts, freshness, discards and locators. SubscriptionRef is an already
// allocated, verified random local reference; no hash or positional substitute.
type AccountInput struct {
	// Route is the reviewed read path; never infer it from provider text.
	Route           Route
	ToolID          string
	DeclaredPlanID  string
	ProfileKey      string
	Source          string
	SubscriptionRef *string
	PlanID          string
	Beta            bool
	Estimated       bool
	Credits         *CreditsInput
	Windows         []WindowInput
}

type CreditsInput struct {
	Balance *float64
	Unit    string
}

// WindowInput keys/roles/plans may contain raw provider values. The projection
// applies allow-lists and generic fallbacks before forming any exported field.
type WindowInput struct {
	Kind             string
	DurationSeconds  *int64
	Limit            string
	Pool             string
	ResetMode        string
	RemainingPercent *float64
	ResetsAt         *time.Time
	ObservedAt       *time.Time
}

// SourceState preserves distinct emitting channels so exhaustive mapping tests
// can cover status/reason/errorCode/blocked independently. No raw text is copied
// into an exported message. Source is internal, never a row identity.
type SourceState struct {
	ToolID    string
	Source    string
	Status    string
	Reason    string
	ErrorCode string
	Blocked   string
}

// KeychainBlock is READERS' actual credential-read-blocked fact. A saved unset
// or denied choice alone is insufficient: Blocked is false when a readable
// credentials file supplied the read. Status maps the closed Keychain vocabulary.
type KeychainBlock struct {
	ToolID  string
	Blocked bool
	Status  string
}
