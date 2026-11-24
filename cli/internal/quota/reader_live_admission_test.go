// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"errors"
	"net/http"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/readers"
	"github.com/modelplan/modelplan/cli/internal/readers/readertest"
)

// Review 11-24 #3: the managed read hands its reader a context whose transport rechecks the
// captured grant before every dispatch. A denial committed between two successful stages
// leaves zero second-stage requests.
func TestManagedReadStopsSecondStageAfterExternalRevoke(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "")
	p := nativePaths(t)
	now := time.Date(2026, 11, 24, 12, 0, 0, 0, time.UTC)
	const provider = "synthetic-live-admission"
	record := readertest.NewTransport(readertest.Response{StatusCode: 200}, readertest.Response{StatusCode: 200})
	valid := true
	var second error
	nativeReaders[provider] = &nativeReader{Managed: func(ctx context.Context, _ *http.Client, _ readerContext) readerOutcome {
		client := readers.NewReadClient(consent.ScopeGrokAccountUsageSavedLogin, &http.Client{Transport: record})
		get := func(path string) error {
			req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://cli-chat-proxy.grok.com"+path, nil)
			if err != nil {
				return err
			}
			resp, err := client.Do(req)
			if resp != nil {
				resp.Body.Close()
			}
			return err
		}
		if err := get("/v1/billing?format=credits"); err != nil {
			t.Error(err)
		}
		valid = false // another process commits the saved-login denial
		second = get("/v1/models")
		return readerOutcome{Entry: readerEntry{Status: "unavailable"}}
	}}
	defer delete(nativeReaders, provider)
	p.ReaderAccess = &ReaderAccess{Grants: map[string]ReaderGrant{provider: {SavedLogin: true, Generation: "grant-A", Profiles: []ReaderProfile{{Root: t.TempDir()}}, StillValid: func() bool { return valid }}}}
	_ = refreshManaged(context.Background(), p, provider, now)
	if !errors.Is(second, readers.ErrAdmissionWithdrawn) {
		t.Fatalf("second stage after revoke: %v", second)
	}
	if got := len(record.Requests()); got != 1 {
		t.Fatalf("dispatched %d requests, want 1", got)
	}
}
