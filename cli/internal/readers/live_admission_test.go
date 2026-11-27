// SPDX-License-Identifier: MIT
package readers_test

import (
	"context"
	"errors"
	"net/http"
	"sync/atomic"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/readers"
	"github.com/modelplan/modelplan/cli/internal/readers/readertest"
)

// Review 11-24 #3: a denial committed by another process between two successful stages of one
// saved-login read stops the second credentialed request; the final publication fence alone
// would only discard its outcome after the token was sent again.
func TestLiveAdmissionStopsSecondStageAfterExternalRevoke(t *testing.T) {
	record := readertest.NewTransport(readertest.Response{StatusCode: 200}, readertest.Response{StatusCode: 200})
	client := &http.Client{Transport: readers.NewReadTransport(consent.ScopeGrokAccountUsageSavedLogin, record)}
	var allowed atomic.Bool
	allowed.Store(true)
	ctx := readers.WithLiveAdmission(context.Background(), allowed.Load)
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
		t.Fatal(err)
	}
	allowed.Store(false) // the saved-login denial commits after stage one succeeded
	if err := get("/v1/models"); !errors.Is(err, readers.ErrAdmissionWithdrawn) {
		t.Fatalf("second stage after revoke: %v", err)
	}
	allowed.Store(true) // a withdrawn read stays stopped
	if err := get("/v1/models"); err == nil {
		t.Fatal("stopped read dispatched again")
	}
	if got := len(record.Requests()); got != 1 {
		t.Fatalf("dispatched %d requests, want 1", got)
	}
}
