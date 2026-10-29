// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
	"net"
)

// ReaderErrorCode is the complete public vocabulary. Never return input text,
// even when a cache, subprocess or provider invents a new code.
func ReaderErrorCode(code string) string {
	switch code {
	case "file_missing", "file_unreadable", "parse_error", "schema_changed", "http_401", "http_403", "http_429", "http_5xx", "network", "timeout", "runtime_missing", "unsupported_login", "other":
		return code
	default:
		return "other"
	}
}
func fileErrorCode(status string) string {
	if status == "missing" {
		return "file_missing"
	}
	return "file_unreadable"
}
func httpErrorCode(status int) string {
	switch status {
	case 401:
		return "http_401"
	case 403:
		return "http_403"
	case 429:
		return "http_429"
	case 404:
		return "schema_changed"
	}
	if status >= 500 && status <= 599 {
		return "http_5xx"
	}
	return "other"
}
func transportErrorCode(err error) string {
	if errors.Is(err, context.Canceled) {
		return "other"
	}
	var n net.Error
	if errors.Is(err, context.DeadlineExceeded) || (errors.As(err, &n) && n.Timeout()) {
		return "timeout"
	}
	return "network"
}

type nativeReadError struct{ code, message string }

func (e nativeReadError) Error() string    { return e.message }
func codeError(code, message string) error { return nativeReadError{ReaderErrorCode(code), message} }
func errorCode(err error) string {
	if errors.Is(err, toolcli.ErrRuntimeMissing) {
		return "runtime_missing"
	}
	var coded nativeReadError
	if errors.As(err, &coded) {
		return ReaderErrorCode(coded.code)
	}
	return "other"
}
func nativeDiagnosticState(status, code string) string {
	if status == toolcli.RuntimeMissing {
		return diagnosticState(status)
	}
	if code != "" && status != "ok" {
		return "unavailable:reader_error:" + ReaderErrorCode(code)
	}
	state := diagnosticState(status)
	if state == "unavailable:reader_error" {
		return state + ":other"
	}
	return state
}

func statusErrorCode(status string) string {
	switch status {
	case "unsupported_schema", "not-supported", "not_supported_yet", "upstream_changed":
		return "schema_changed"
	case "expired", "expired_login", "login_expired":
		return "unsupported_login"
	case "rate-limited", "rate_limited":
		return "http_429"
	case "network_error":
		return "network"
	case "not_detected", toolcli.RuntimeMissing:
		return "runtime_missing"
	default:
		return "other"
	}
}
func failureCode(status string, codes []string) string {
	if len(codes) > 0 {
		return ReaderErrorCode(codes[0])
	}
	if status == "consent_required" || status == "denied" || status == "off" || status == "privacy_blocked" {
		return ""
	}
	return statusErrorCode(status)
}

func jsonErrorCode(err error) string {
	var syntax *json.SyntaxError
	if errors.As(err, &syntax) {
		return "parse_error"
	}
	return "schema_changed"
}
