// SPDX-License-Identifier: MIT
package readers_test

import (
	"errors"
	"net/http"
	"sync"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/readers"
	"github.com/modelplan/modelplan/cli/internal/readers/readertest"
)

// Red line: no inference or paid calls, including another path on an official
// host, cross-region fallback, changed parameters or a third call in one read.
func TestAdmissionRedLineFixedRequestSet(t *testing.T) {
	record := readertest.NewTransport(readertest.Response{StatusCode: 404}, readertest.Response{StatusCode: 200})
	client := &http.Client{Transport: readers.NewReadTransport(consent.ScopeMiniMaxAccountUsageAPIKey, record)}
	for _, endpoint := range []string{
		"https://api.minimax.io/v1/chat/completions",
		"https://api.minimax.io/v1/token_plan/remains?model=changed",
		"https://api.minimax.io:8443/v1/token_plan/remains",
		"http://api.minimax.io/v1/token_plan/remains",
		"https://unreviewed.invalid/v1/token_plan/remains",
		"https://api.minimax.io/v1/api/openplatform/coding_plan/remains",
	} {
		if err := send(client, "GET", endpoint); !errors.Is(err, readers.ErrRequestNotAllowed) {
			t.Fatalf("unlisted request accepted: %s: %v", endpoint, err)
		}
	}
	if err := checkRequests(record.Requests(), nil); err != nil {
		t.Fatal(err)
	}
	current := "https://api.minimax.io/v1/token_plan/remains"
	legacy := "https://api.minimax.io/v1/api/openplatform/coding_plan/remains"
	if err := send(client, "GET", current); err != nil {
		t.Fatal(err)
	}
	for _, endpoint := range []string{current, "https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains"} {
		if err := send(client, "GET", endpoint); !errors.Is(err, readers.ErrRequestNotAllowed) {
			t.Fatal(err)
		}
	}
	if err := send(client, "GET", legacy); err != nil {
		t.Fatal(err)
	}
	if err := send(client, "GET", legacy); !errors.Is(err, readers.ErrReadExhausted) {
		t.Fatal(err)
	}
	want := []readertest.Request{{Method: "GET", Host: "api.minimax.io", Path: "/v1/token_plan/remains"}, {Method: "GET", Host: "api.minimax.io", Path: "/v1/api/openplatform/coding_plan/remains"}}
	if err := checkRequests(record.Requests(), want); err != nil {
		t.Fatal(err)
	}
}

func TestAdmissionUnknownScopeFailsClosed(t *testing.T) {
	record := readertest.NewTransport()
	client := &http.Client{Transport: readers.NewReadTransport("gemini.future_scope", record)}
	if err := send(client, "GET", "https://api.minimax.io/v1/token_plan/remains"); !errors.Is(err, readers.ErrUnsupportedScope) {
		t.Fatal(err)
	}
	if err := checkRequests(record.Requests(), nil); err != nil {
		t.Fatal(err)
	}
}

// The recording seam must include attempted unexpected calls and return copies.
func TestRecordingTransportRecordsUnexpectedCalls(t *testing.T) {
	record := readertest.NewTransport()
	if err := send(&http.Client{Transport: record}, "POST", "https://synthetic.invalid/unexpected"); err == nil {
		t.Fatal("unscripted request accepted")
	}
	want := []readertest.Request{{Method: "POST", Host: "synthetic.invalid", Path: "/unexpected"}}
	if err := checkRequests(record.Requests(), want); err != nil {
		t.Fatal(err)
	}
	copy := record.Requests()
	copy[0].Host = "changed.invalid"
	if err := checkRequests(record.Requests(), want); err != nil {
		t.Fatal(err)
	}
}

// Red line: even a redirect onto another allowed path cannot forward a credential.
func TestAdmissionRedLineNoCredentialCarryingRedirect(t *testing.T) {
	record := readertest.NewTransport(readertest.Response{StatusCode: 307, Header: http.Header{"Location": []string{"https://api.minimax.io/v1/api/openplatform/coding_plan/remains"}}})
	client := &http.Client{Transport: readers.NewReadTransport(consent.ScopeMiniMaxAccountUsageAPIKey, record)}
	req, err := http.NewRequest("GET", "https://api.minimax.io/v1/token_plan/remains", nil)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Authorization", "Bearer synthetic-key")
	resp, err := client.Do(req)
	if resp != nil {
		resp.Body.Close()
	}
	if !errors.Is(err, readers.ErrRequestNotAllowed) {
		t.Fatalf("redirect accepted: %v", err)
	}
	if err := checkRequests(record.Requests(), []readertest.Request{{Method: "GET", Host: "api.minimax.io", Path: "/v1/token_plan/remains"}}); err != nil {
		t.Fatal(err)
	}
}

func TestAdmissionConcurrentRequestsCannotPassAuthorizationStop(t *testing.T) {
	record := readertest.NewTransport(readertest.Response{StatusCode: 401})
	client := &http.Client{Transport: readers.NewReadTransport(consent.ScopeMiniMaxAccountUsageAPIKey, record)}
	var wg sync.WaitGroup
	start := make(chan struct{})
	for range 8 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			if err := send(client, "GET", "https://api.minimax.io/v1/token_plan/remains"); err != nil && !errors.Is(err, readers.ErrAuthorizationStopped) {
				t.Error(err)
			}
		}()
	}
	close(start)
	wg.Wait()
	if err := checkRequests(record.Requests(), []readertest.Request{{Method: "GET", Host: "api.minimax.io", Path: "/v1/token_plan/remains"}}); err != nil {
		t.Fatal(err)
	}
}
