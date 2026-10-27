package quota

import (
	"context"
	"net/http"
	"time"
)

// The owner-requested OAuth prepaid route is /api/oauth/organizations/{org}/prepaid/credits.
// Its amount/currency units are not established by a sanitised OAuth response.
// CodexBar 0.81.0's web parser is evidence for a different authentication route,
// not permission to guess an OAuth wallet's scale. Keep this component unsupported
// and make no request until that evidence gate is satisfied. Usage/profile remain
// independently available; no credential, browser or inference fallback exists.
func readClaudeCredits(_ context.Context, _ *http.Client, _ string, _ string, _ time.Time) (*Credits, string, time.Time) {
	return nil, "not-supported", time.Time{}
}
