// SPDX-License-Identifier: MIT
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/url"
	"os"
	"regexp"
	"runtime"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/store"
)

type consentTool struct {
	ID          string              `json:"id"`
	DisplayName string              `json:"displayName"`
	AccessClass string              `json:"accessClass"`
	Detected    bool                `json:"detected"`
	Allowed     bool                `json:"allowed"`
	Backend     string              `json:"backend"`
	ReaderID    string              `json:"readerId"`
	Keychain    string              `json:"keychain"`
	Hosts       []string            `json:"hosts"`
	HostDetails []consentHostDetail `json:"hostDetails"`
	Notice      string              `json:"notice,omitempty"`
	NextStep    string              `json:"nextStep,omitempty"`
}

type consentHostDetail struct {
	Host string `json:"host"`
	Note string `json:"note"`
}

var consentDNSName = regexp.MustCompile(`^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]([a-z0-9-]{0,61}[a-z0-9])?$`)

// Hosts remain display labels for existing callers. Only compiled HTTPS DNS
// destinations enter the structured field; local-only/loopback labels stay in
// hosts. This parses metadata and performs no resolution or network access.
func consentHostDetails(labels []string) []consentHostDetail {
	details := []consentHostDetail{}
	for _, label := range labels {
		endpoint, note, _ := strings.Cut(label, " (")
		u, err := url.Parse(endpoint)
		if err != nil || u.Scheme != "https" || len(u.Hostname()) > 253 || !consentDNSName.MatchString(u.Hostname()) {
			continue
		}
		details = append(details, consentHostDetail{Host: u.Hostname(), Note: strings.TrimSuffix(note, ")")})
	}
	return details
}

type consentView struct {
	Generation         uint64            `json:"generation"`
	ConsentTextVersion int               `json:"consentTextVersion"`
	Mode               string            `json:"mode"`
	ConsentText        map[string]string `json:"consentText"`
	Tools              []consentTool     `json:"tools"`
}

type consentRequest struct {
	RequestID          string            `json:"requestId"`
	ExpectGeneration   *uint64           `json:"expectGeneration"`
	ConsentTextVersion *int              `json:"consentTextVersion"`
	Allow              []string          `json:"allow"`
	Deny               []string          `json:"deny"`
	Keychain           map[string]string `json:"keychain"`
}

type consentResult struct {
	OK            bool          `json:"ok"`
	Error         string        `json:"error,omitempty"`
	RequestID     string        `json:"requestId"`
	Generation    uint64        `json:"generation"`
	Tools         []consentTool `json:"tools"`
	PendingForget []string      `json:"pendingForget,omitempty"`
}

var consentRequestID = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func consentMode(s consent.State) string {
	return s.Effective(os.Getenv("MODELPLAN_READERS"))
}

func consentNativeOff() bool {
	switch strings.ToLower(os.Getenv("MODELPLAN_NATIVE")) {
	case "off", "0", "false":
		return true
	}
	return false
}

// Access classes describe the selected route, not a disabled helper fallback
// for a native reader. Unknown/unaudited helper classes fail closed.
func consentAccess(t detect.Tool) string {
	if t.Preferred == "native" && strings.HasPrefix(t.ReaderID, "native:") {
		return "standard"
	}
	if t.CodexBar.AccessClass == "browser-session" {
		return "browser-session"
	}
	if t.Preferred == "codexbar" && t.HelperStatus() == "" && t.CodexBar.AccessClass == "standard" {
		return "standard"
	}
	return "not-read"
}

func consentTools(s consent.State, report detect.Report) []consentTool {
	rows := []consentTool{}
	for _, t := range report.Tools {
		if !t.Detected {
			continue
		}
		r := s.Tools[t.ProviderID]
		hosts := consentHosts(t.ProviderID, r.Region)
		if hosts == nil {
			hosts = []string{}
		}
		row := consentTool{ID: t.ProviderID, DisplayName: t.DisplayName,
			AccessClass: consentAccess(t), Detected: true,
			Allowed: r.Allowed && r.ConsentTextVersion == consent.TextVersion,
			Backend: t.Preferred, ReaderID: t.ReaderID, Keychain: s.KeychainStatus(t.ProviderID, consentMode(s)), Hosts: hosts,
			HostDetails: consentHostDetails(hosts)}
		if runtime.GOOS == "darwin" && row.Allowed && row.Keychain == "unset" && consentMode(s) == consent.Automatic &&
			consent.KeychainSupported(t.ProviderID, t.Preferred, t.ReaderID) && r.KeyEnv == "" && !r.BrowserSession {
			row.Notice, row.NextStep = consent.ClaudeKeychainUnsetNotice, consent.ClaudeKeychainNextStep
		}
		rows = append(rows, row)
	}
	return rows
}

func consentFailure(stdout io.Writer, code string) int {
	if printJSON(stdout, map[string]any{"ok": false, "error": code}) != 0 {
		return exitErr
	}
	return exitErr
}

func consentCmd(args []string, stdin io.Reader, stdout io.Writer, st *store.Store, c common) int {
	if !c.json || len(args) > 1 || (len(args) == 1 && args[0] != "grant") {
		return consentFailure(stdout, "invalid_request")
	}
	if len(args) == 0 {
		s, err := consent.Load(consent.Path())
		if err != nil {
			return consentFailure(stdout, "consent_unavailable")
		}
		return printJSON(stdout, consentView{Generation: s.Generation, ConsentTextVersion: consent.TextVersion,
			Mode: consentMode(s), ConsentText: map[string]string{"en": consent.Text, "zh": consent.TextZH}, Tools: consentTools(s, detection(st))})
	}
	request, err := decodeConsentRequest(stdin)
	if err != nil {
		return consentFailure(stdout, "invalid_request")
	}
	return grantConsent(request, stdout, st)
}

func decodeConsentRequest(stdin io.Reader) (consentRequest, error) {
	var r consentRequest
	if stdin == nil {
		return r, errors.New("invalid_request")
	}
	b, err := io.ReadAll(io.LimitReader(stdin, (64<<10)+1))
	if err != nil || len(b) > 64<<10 {
		return r, errors.New("invalid_request")
	}
	d := json.NewDecoder(strings.NewReader(string(b)))
	d.DisallowUnknownFields()
	if d.Decode(&r) != nil || d.Decode(new(any)) != io.EOF || !consentRequestID.MatchString(r.RequestID) || r.ExpectGeneration == nil || r.ConsentTextVersion == nil {
		return r, errors.New("invalid_request")
	}
	r.RequestID = strings.ToLower(r.RequestID)
	seen := map[string]bool{}
	for _, ids := range [][]string{r.Allow, r.Deny} {
		for _, id := range ids {
			if seen[id] {
				return r, errors.New("invalid_request")
			}
			seen[id] = true
		}
	}
	for _, v := range r.Keychain {
		if v != "allow" && v != "deny" {
			return r, errors.New("invalid_request")
		}
	}
	return r, nil
}

func grantConsent(request consentRequest, stdout io.Writer, st *store.Store) int {
	b, _ := json.Marshal(request)
	hash := sha256.Sum256(b)
	requestHash := hex.EncodeToString(hash[:])
	var result json.RawMessage
	var report detect.Report
	var finalize func(*consent.State) error
	// Cleanup is deliberately after durable revocation, with a durable failure
	// receipt already in place. A crash/failure cannot lose the Forget obligation.
	if len(request.Deny) != 0 {
		finalize = func(s *consent.State) error {
			receipt := s.Requests[request.RequestID]
			pending := []string{}
			for _, id := range request.Deny {
				r := s.Tools[id]
				// Cookie-cache deletion may need Keychain access. This API never
				// starts that helper; keep the advanced Forget action pending.
				if err := forgetConsentTool(st, id, false); err != nil || r.BrowserCookieCache {
					pending = append(pending, id)
					continue
				}
				r.BrowserCookieCache = false
				s.Tools[id] = r
			}
			receipt.PendingForget = pending
			response := consentResult{OK: len(pending) == 0, RequestID: request.RequestID, Generation: s.Generation,
				Tools: consentTools(*s, report), PendingForget: pending}
			if len(pending) != 0 {
				response.Error = "cleanup_pending"
			}
			receipt.Result, _ = json.Marshal(response)
			s.Requests[request.RequestID] = receipt
			result = receipt.Result
			return nil
		}
	}
	err := consent.Transaction(consent.Path(), func(s *consent.State) error {
		mode := consentMode(*s)
		if mode == consent.Off {
			return errors.New("readers_off")
		}
		if receipt, exists := s.Requests[request.RequestID]; exists {
			if receipt.RequestHash != requestHash {
				return errors.New("request_id_conflict")
			}
			result = receipt.Result
			return consent.ErrUnchanged
		}
		if s.Generation != *request.ExpectGeneration {
			return errors.New("stale_generation")
		}
		if *request.ConsentTextVersion != consent.TextVersion {
			return errors.New("stale_consent_text")
		}
		report = detection(st)
		tools := map[string]detect.Tool{}
		for _, t := range report.Tools {
			if t.Detected {
				tools[t.ProviderID] = t
			}
		}
		for _, ids := range [][]string{request.Allow, request.Deny} {
			for _, id := range ids {
				if _, exists := tools[id]; !exists {
					return errors.New("unknown_tool")
				}
			}
		}
		for id := range request.Keychain {
			t, exists := tools[id]
			if !exists {
				return errors.New("unknown_tool")
			}
			if !consent.KeychainSupported(id, t.Preferred, t.ReaderID) {
				return errors.New("keychain_not_supported")
			}
			touched := false
			for _, ids := range [][]string{request.Allow, request.Deny} {
				for _, selected := range ids {
					touched = touched || selected == id
				}
			}
			if !touched {
				return errors.New("invalid_request")
			}
		}
		for _, id := range request.Allow {
			t := tools[id]
			if t.Preferred == "off" || (t.Preferred == "native" && consentNativeOff()) || (t.Preferred == "codexbar" && os.Getenv("MODELPLAN_CODEXBAR") == "off") {
				return errors.New("readers_off")
			}
			if consentAccess(t) != "standard" {
				return errors.New("access_class_forbidden")
			}
			if choice(t, consent.Automatic).Status != "available" {
				return errors.New("reader_unavailable")
			}
		}
		for _, ids := range [][]string{request.Allow, request.Deny} {
			for _, id := range ids {
				t := tools[id]
				allowed := false
				for _, a := range request.Allow {
					allowed = allowed || a == id
				}
				r := s.Tools[id]
				if consent.KeychainSupported(id, t.Preferred, t.ReaderID) &&
					(request.Keychain[id] != "" || s.KeychainStatus(id, consent.Automatic) != "allowed") {
					consent.SetKeychain(&r, request.Keychain[id])
				}
				s.Tools[id] = r
				reader, backend := t.ReaderID, t.Preferred
				if !allowed {
					reader, backend = "", ""
				}
				if err := consent.Set(s, id, allowed, reader, backend, time.Now()); err != nil {
					return err
				}
			}
		}
		response := consentResult{OK: true, RequestID: request.RequestID, Generation: s.Generation + 1, Tools: consentTools(*s, report)}
		if len(request.Deny) != 0 {
			response.OK, response.Error, response.PendingForget = false, "cleanup_pending", request.Deny
		}
		result, _ = json.Marshal(response)
		if s.Requests == nil {
			s.Requests = map[string]consent.Receipt{}
		}
		s.Requests[request.RequestID] = consent.Receipt{RequestHash: requestHash, Result: result, PendingForget: request.Deny}
		return nil
	}, finalize)
	if err != nil {
		code := err.Error()
		switch code {
		case "invalid_request", "readers_off", "stale_generation", "stale_consent_text", "unknown_tool", "keychain_not_supported", "access_class_forbidden", "reader_unavailable", "request_id_conflict":
		default:
			code = "consent_unavailable"
		}
		return consentFailure(stdout, code)
	}
	var response consentResult
	if json.Unmarshal(result, &response) != nil {
		return consentFailure(stdout, "consent_unavailable")
	}
	if printJSON(stdout, json.RawMessage(result)) != 0 || !response.OK {
		return exitErr
	}
	return 0
}
