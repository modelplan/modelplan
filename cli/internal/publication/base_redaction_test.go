// SPDX-License-Identifier: MIT
package publication

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestPublicationBaseAndRedirectErrorsDoNotExposeCredentials(t *testing.T) {
	const secret = "SYNTHETIC-SECRET-568"
	for _, input := range []string{"https://user:" + secret + "@example.invalid/path?token=" + secret, "https://example.invalid/?token=" + secret, "https://" + secret + "%ZZ/"} {
		_, err := New(input, nil, "test")
		if err == nil || strings.Contains(err.Error(), secret) {
			t.Fatalf("unsafe validation error: %v", err)
		}
	}
	if got := DisplayBase("https://user:" + secret + "@example.invalid/path?token=" + secret + "#" + secret); got != "https://example.invalid/path" {
		t.Fatalf("unexpected URL display: %q", got)
	}
	if got := DisplayBase("https://" + secret + "%ZZ/"); got != "[invalid URL]" {
		t.Fatalf("unsafe malformed URL display: %q", got)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/next?token="+secret, http.StatusFound)
	}))
	defer server.Close()
	client, err := New(server.URL, nil, "test")
	if err != nil {
		t.Fatal(err)
	}
	_, _, _, err = client.get(context.Background(), "/", "")
	if err == nil || strings.Contains(err.Error(), secret) {
		t.Fatalf("unsafe redirect error: %v", err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	_, _, _, err = client.get(ctx, "/", "")
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("cancellation not preserved: %v", err)
	}
}
