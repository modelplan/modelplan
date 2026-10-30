// SPDX-License-Identifier: MIT
package testenv

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"reflect"
	"regexp"
	"strings"
	"testing"
)

// Keep this positive vocabulary independent of the production normalizer: an
// accidental identity implementation of ReaderErrorCode must not weaken tests.
func ReaderReasonCode(value string) bool {
	switch value {
	case "policy_pending", "file_missing", "file_unreadable", "parse_error", "schema_changed", "http_401", "http_403", "http_429", "http_5xx", "network", "timeout", "runtime_missing", "unsupported_login", "other":
		return true
	default:
		return false
	}
}
func reasonCode(value any) error {
	if value == nil || value == "" {
		return nil
	}
	code, ok := value.(string)
	if !ok || !ReaderReasonCode(code) {
		return errors.New("reader reason is not a fixed code")
	}
	return nil
}

// FetchReason is the actual retained marker, including its version/state framing.
// No separately supplied reason or copy of the payload participates in checking it.
type FetchReason string

var fetchVersion = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+$`)

func CheckFetchReason(value string) error {
	version, state, ok := strings.Cut(strings.TrimSpace(value), " ")
	if value == "" {
		return nil
	}
	if !ok || !fetchVersion.MatchString(version) {
		return errors.New("invalid fetch result framing")
	}
	if state == "started" || state == "ok" {
		return nil
	}
	code, ok := strings.CutPrefix(state, "failed: ")
	if !ok || !ReaderReasonCode(code) {
		return errors.New("fetch failure is not a fixed code")
	}
	return nil
}

// CheckReaderReasons inspects the artifact itself, including actual JSON field
// values and error.Error(). A wrapped error is validated in full, not unwrapped
// to a safe cause. Non-reason metadata (counts, labels, timestamps) is untouched.
func CheckReaderReasons(value any) error {
	switch v := value.(type) {
	case nil:
		return nil
	case error:
		if !ReaderReasonCode(v.Error()) {
			return errors.New("returned error is not a fixed code")
		}
		return nil
	case FetchReason:
		return CheckFetchReason(string(v))
	case string:
		return reasonCode(v)
	case []byte:
		var data any
		decoder := json.NewDecoder(strings.NewReader(string(v)))
		decoder.UseNumber()
		if err := decoder.Decode(&data); err != nil {
			return errors.New("reader artifact is not JSON")
		}
		if err := decoder.Decode(new(any)); err != io.EOF {
			return errors.New("reader artifact has trailing data")
		}
		return checkReasonJSON(data, true)
	default:
		if err := checkNestedErrors(reflect.ValueOf(value)); err != nil {
			return err
		}
		b, err := json.Marshal(value)
		if err != nil {
			return err
		}
		return CheckReaderReasons(b)
	}
}
func checkReasonJSON(value any, failure bool) error {
	switch v := value.(type) {
	case string:
		if failure {
			return reasonCode(v)
		}
	case map[string]any:
		for key, item := range v {
			field := strings.ToLower(key)
			switch field {
			case "reason", "errorcode", "lasterror":
				if err := reasonCode(item); err != nil {
					return err
				}
			case "error":
				if _, ok := item.(map[string]any); !ok {
					if err := reasonCode(item); err != nil {
						return err
					}
				}
			case "message", "msg":
				if failure {
					if err := reasonCode(item); err != nil {
						return err
					}
				}
			case "code":
				if failure {
					code, ok := item.(string)
					if !ok || !retainedFailureCode(code) {
						return errors.New("retained failure is not a fixed code")
					}
				}
			case "fetchresult", "fetch":
				text, ok := item.(string)
				if !ok {
					return errors.New("fetch result is not a string")
				}
				if err := CheckFetchReason(text); err != nil {
					return err
				}
			}
			if err := checkReasonJSON(item, field == "lastfailure" || field == "error" || field == "failure"); err != nil {
				return err
			}
		}
	case []any:
		for _, item := range v {
			if err := checkReasonJSON(item, failure); err != nil {
				return err
			}
		}
	}
	return nil
}
func checkNestedErrors(v reflect.Value) error {
	if !v.IsValid() {
		return nil
	}
	if v.CanInterface() {
		if err, ok := v.Interface().(error); ok {
			return CheckReaderReasons(err)
		}
	}
	switch v.Kind() {
	case reflect.Interface, reflect.Pointer:
		if !v.IsNil() {
			return checkNestedErrors(v.Elem())
		}
	case reflect.Struct:
		for i := 0; i < v.NumField(); i++ {
			if v.Field(i).CanInterface() {
				if err := checkNestedErrors(v.Field(i)); err != nil {
					return err
				}
			}
		}
	case reflect.Map:
		for _, key := range v.MapKeys() {
			if err := checkNestedErrors(v.MapIndex(key)); err != nil {
				return err
			}
		}
	case reflect.Slice, reflect.Array:
		for i := 0; i < v.Len(); i++ {
			if err := checkNestedErrors(v.Index(i)); err != nil {
				return err
			}
		}
	}
	return nil
}

// CheckReasonLog accepts code-only records. It never searches for a particular
// secret: helper prose and %w wrappers fail even with no canary present.
func CheckReasonLog(output string) error {
	for _, line := range strings.Split(strings.TrimSuffix(output, "\n"), "\n") {
		line = strings.TrimSuffix(line, "\r")
		if line != "" && !ReaderReasonCode(line) {
			return errors.New("reader log record is not a fixed code")
		}
	}
	return nil
}

// CaptureReasonLogs captures standard logging AND incidental stdout/stderr for
// every exercised reader path. Call the returned check in a defer. Tests using
// process-wide streams must not run in parallel.
func CaptureReasonLogs(t *testing.T) func() error {
	t.Helper()
	file, err := os.CreateTemp(t.TempDir(), "reader-logs")
	if err != nil {
		t.Fatal(err)
	}
	stdout, stderr := os.Stdout, os.Stderr
	writer, flags, prefix := log.Writer(), log.Flags(), log.Prefix()
	os.Stdout, os.Stderr = file, file
	log.SetOutput(file)
	log.SetFlags(0)
	log.SetPrefix("")
	var finished bool
	var result error
	finish := func() error {
		if finished {
			return result
		}
		finished = true
		os.Stdout, os.Stderr = stdout, stderr
		log.SetOutput(writer)
		log.SetFlags(flags)
		log.SetPrefix(prefix)
		if err := file.Close(); err != nil {
			result = err
			return result
		}
		b, err := os.ReadFile(file.Name())
		if err != nil {
			result = err
			return result
		}
		result = CheckReasonLog(string(b))
		return result
	}
	t.Cleanup(func() { _ = finish() })
	return finish
}

// CheckCLIReasonLog checks the fixed CLI error context, then validates the
// entire remaining error as one code. Arbitrary prefixes/wrappers cannot pass.
func CheckCLIReasonLog(output string) error {
	for _, line := range strings.Split(strings.TrimSuffix(output, "\n"), "\n") {
		if line == "" {
			continue
		}
		code, ok := strings.CutPrefix(line, "codex account: ")
		if !ok || !ReaderReasonCode(code) {
			return fmt.Errorf("CLI reader log is not a fixed code")
		}
	}
	return nil
}

// readerAttemptCode has an additional closed state vocabulary for retained
// profile failures. These are semantic state codes, never notices or prose.
func retainedFailureCode(code string) bool {
	if ReaderReasonCode(code) {
		return true
	}
	switch code {
	case "keychain_unset", "keychain_denied", "keychain_canceled", "keychain_not_found", "keychain_unavailable", "keychain_confirmation_needed", "reader_busy",
		"expired", "expired_login", "login_expired", "busy", "consent_required", "denied", "off", "privacy_blocked":
		return true
	default:
		return false
	}
}
