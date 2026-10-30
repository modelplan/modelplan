// SPDX-License-Identifier: MIT
package readers_test

import (
	"errors"
	"fmt"
	"net/http"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/readers"
	"github.com/modelplan/modelplan/cli/internal/readers/readertest"
)

type approvedPOST struct {
	endpoint, body string
	headers        http.Header
}
type approvedRead struct {
	name, scope string
	requests    []approvedPOST
}

func approvedPOSTReads() []approvedRead {
	return []approvedRead{
		{"gemini", consent.ScopeGeminiAccountUsageSavedLogin, []approvedPOST{
			{"https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist", `{"mode":"HEALTH_CHECK","metadata":{"ideType":"GEMINI_CLI","pluginType":"GEMINI"}}`, http.Header{"Authorization": {"Bearer synthetic-access"}}},
			{"https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota", `{"project":"synthetic-project"}`, http.Header{"Authorization": {"Bearer synthetic-access"}}},
		}},
		{"cursor", consent.ScopeCursorAccountUsageSavedLogin, []approvedPOST{
			{"https://cursor.com/api/dashboard/get-plan-info", `{}`, http.Header{"Cookie": {"WorkosCursorSessionToken=synthetic-session"}, "Origin": {"https://cursor.com"}}},
			{"https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage", `{}`, http.Header{"Authorization": {"Bearer synthetic-access"}, "Connect-Protocol-Version": {"1"}}},
		}},
	}
}
func (p approvedPOST) request(t *testing.T) *http.Request {
	t.Helper()
	r, err := http.NewRequest("POST", p.endpoint, strings.NewReader(p.body))
	if err != nil {
		t.Fatal(err)
	}
	r.Header = p.headers.Clone()
	r.Header.Set("Accept", "application/json")
	r.Header.Set("Content-Type", "application/json")
	r.Header.Set("User-Agent", "modelplan")
	return r
}
func doApprovedPOST(c *http.Client, r *http.Request) error {
	resp, err := c.Do(r)
	if resp != nil {
		resp.Body.Close()
	}
	return err
}

// Positive control fails while the compiled owner gate still says pending.
// Policy approval never changes saved-login consent or its unchecked default.
func TestApprovedPOSTReadPinsAndOptIn(t *testing.T) {
	for _, read := range approvedPOSTReads() {
		t.Run(read.name, func(t *testing.T) {
			if err := readers.CheckAdmission(read.scope); err != nil {
				t.Fatalf("approved scope blocked: %v", err)
			}
			d, ok := consent.Definition(read.scope)
			if !ok || d.Class != consent.Credential || d.DefaultCheck || d.Route != "saved_login_api" {
				t.Fatalf("approval promoted O-class/default: %+v", d)
			}
			for _, warm := range []bool{false, true} {
				t.Run(fmt.Sprint("warm=", warm), func(t *testing.T) {
					record := readertest.NewTransport(readertest.Response{StatusCode: 200}, readertest.Response{StatusCode: 200})
					client := readers.NewReadClient(read.scope, &http.Client{Transport: record})
					want := []readertest.Request{}
					for i, p := range read.requests {
						if warm && i == 0 {
							continue
						}
						r := p.request(t)
						want = append(want, readertest.Request{Method: r.Method, Host: r.URL.Host, Path: r.URL.EscapedPath()})
						if err := doApprovedPOST(client, r); err != nil {
							t.Fatal(err)
						}
					}
					if err := checkRequests(record.Requests(), want); err != nil {
						t.Fatal(err)
					}
					for range 3 {
						if err := doApprovedPOST(client, read.requests[1].request(t)); err == nil {
							t.Fatal("extra request accepted")
						}
					}
					if err := checkRequests(record.Requests(), want); err != nil {
						t.Fatal(err)
					}
				})
			}
		})
	}
}
func TestApprovedPOSTRejectsUnpinnedRequests(t *testing.T) {
	mutations := []struct {
		name   string
		change func(*http.Request)
	}{
		{"get", func(r *http.Request) { r.Method = "GET" }},
		{"off-host", func(r *http.Request) { r.URL.Host = "unreviewed.invalid" }},
		{"wrong-port", func(r *http.Request) { r.URL.Host += ":443" }},
		{"http", func(r *http.Request) { r.URL.Scheme = "http" }},
		{"off-path", func(r *http.Request) { r.URL.Path = "/v1internal:generateContent" }},
		{"query", func(r *http.Request) { r.URL.RawQuery = "extra=1" }},
		{"empty-query", func(r *http.Request) { r.URL.ForceQuery = true }},
		{"host-override", func(r *http.Request) { r.Host = "unreviewed.invalid" }},
		{"extra-header", func(r *http.Request) { r.Header.Set("X-Unreviewed", "synthetic") }},
		{"duplicate-header", func(r *http.Request) { r.Header.Add("User-Agent", "extra") }},
		{"missing-header", func(r *http.Request) { r.Header.Del("Accept") }},
		{"missing-body", func(r *http.Request) { r.Body = http.NoBody; r.ContentLength = 0 }},
	}
	for _, read := range approvedPOSTReads() {
		for slot, p := range read.requests {
			for _, mutation := range mutations {
				t.Run(fmt.Sprintf("%s/%d/%s", read.name, slot, mutation.name), func(t *testing.T) {
					record := readertest.NewTransport(readertest.Response{StatusCode: 200})
					client := readers.NewReadClient(read.scope, &http.Client{Transport: record})
					r := p.request(t)
					mutation.change(r)
					if err := doApprovedPOST(client, r); !errors.Is(err, readers.ErrRequestNotAllowed) {
						t.Fatalf("unpinned request escaped: %v", err)
					}
					if err := checkRequests(record.Requests(), nil); err != nil {
						t.Fatal(err)
					}
				})
			}
			bodies := []string{`null`, `[]`, `{"refresh":true}`, p.body + `{}`, `{"project":"p","project":"q"}`, strings.Repeat("x", 4097)}
			if read.name == "gemini" && slot == 0 {
				bodies = append(bodies, `{"mode":"HEALTH_CHECK","mode":"HEALTH_CHECK","metadata":{"ideType":"GEMINI_CLI","pluginType":"GEMINI"}}`, `{"mode":"ONBOARD","metadata":{"ideType":"GEMINI_CLI","pluginType":"GEMINI"}}`, `{"mode":"HEALTH_CHECK","metadata":{"ideType":"GEMINI_CLI","pluginType":"GEMINI","extra":true}}`)
			}
			for i, body := range bodies {
				t.Run(fmt.Sprintf("%s/%d/body-%d", read.name, slot, i), func(t *testing.T) {
					record := readertest.NewTransport(readertest.Response{StatusCode: 200})
					client := readers.NewReadClient(read.scope, &http.Client{Transport: record})
					bad := p
					bad.body = body
					if err := doApprovedPOST(client, bad.request(t)); !errors.Is(err, readers.ErrRequestNotAllowed) {
						t.Fatalf("unapproved body escaped: %v", err)
					}
					if err := checkRequests(record.Requests(), nil); err != nil {
						t.Fatal(err)
					}
				})
			}
			if read.name == "cursor" {
				t.Run(fmt.Sprintf("cursor/%d/credential-separation", slot), func(t *testing.T) {
					record := readertest.NewTransport(readertest.Response{StatusCode: 200})
					client := readers.NewReadClient(read.scope, &http.Client{Transport: record})
					r := p.request(t)
					if slot == 0 {
						r.Header.Set("Authorization", "Bearer synthetic-access")
					} else {
						r.Header.Set("Cookie", "WorkosCursorSessionToken=synthetic-session")
					}
					if err := doApprovedPOST(client, r); !errors.Is(err, readers.ErrRequestNotAllowed) {
						t.Fatal("cross-authority credential accepted", err)
					}
					if err := checkRequests(record.Requests(), nil); err != nil {
						t.Fatal(err)
					}
				})
			}
		}
	}
	// The same malformed request without the production guard trips the zero-call oracle.
	record := readertest.NewTransport(readertest.Response{StatusCode: 200})
	p := approvedPOSTReads()[0].requests[0]
	p.body = `{"refresh":true}`
	if err := doApprovedPOST(&http.Client{Transport: record}, p.request(t)); err != nil {
		t.Fatal(err)
	}
	if checkRequests(record.Requests(), nil) == nil {
		t.Fatal("unguarded negative control escaped recorder")
	}
}
func TestApprovedPOSTStopsAfterAuthOrRedirect(t *testing.T) {
	for _, read := range approvedPOSTReads() {
		for _, slot := range []int{0, 1} {
			for _, status := range []int{401, 403, 301, 302, 303, 307, 308} {
				t.Run(fmt.Sprintf("%s/%d/%d", read.name, slot, status), func(t *testing.T) {
					responses := []readertest.Response{}
					for i := 0; i < slot; i++ {
						responses = append(responses, readertest.Response{StatusCode: 200})
					}
					responses = append(responses, readertest.Response{StatusCode: status, Header: http.Header{"Location": {"https://unreviewed.invalid/credential-target"}}}, readertest.Response{StatusCode: 200})
					record := readertest.NewTransport(responses...)
					// Even a default redirect-following client cannot forward the rejected request.
					client := &http.Client{Transport: readers.NewReadTransport(read.scope, record)}
					for i := 0; i <= slot; i++ {
						err := doApprovedPOST(client, read.requests[i].request(t))
						if err != nil && status < 300 {
							t.Fatal(err)
						}
					}
					expected := readers.ErrAuthorizationStopped
					if status >= 300 && status < 400 {
						expected = readers.ErrRequestNotAllowed
					}
					for range 3 {
						if err := doApprovedPOST(client, read.requests[1].request(t)); !errors.Is(err, expected) {
							t.Fatalf("request after terminal response: %v", err)
						}
					}
					if len(record.Requests()) != slot+1 {
						t.Fatalf("request/redirect after terminal response: %v", record.Requests())
					}
				})
			}
		}
	}
}
