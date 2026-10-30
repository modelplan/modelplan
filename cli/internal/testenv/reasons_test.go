// SPDX-License-Identifier: MIT
package testenv

import (
	"errors"
	"fmt"
	"log"
	"os"
	"testing"
)

var readerLog = log.New(os.Stderr, "", 0)
var readerStdout = os.Stdout

func TestReaderReasonPositiveVocabulary(t *testing.T) {
	for _, value := range []any{
		struct{ Reason string }{"arbitrary vendor prose"},
		errors.New("arbitrary vendor prose"),
		fmt.Errorf("reader failed: %w", errors.New("other")),
		[]byte(`{"reason":"unrelated prose"}`),
		[]byte(`"unrelated prose"`), []byte(`["unrelated prose"]`),
		[]byte(`{"errorCode":"other","error":"unrelated prose"}`),
		[]byte(`{"lastFailure":{"code":"unrelated prose"}}`),
		[]byte(`{"error":{"code":"other","message":"unrelated prose"}}`),
		map[string]any{"error": fmt.Errorf("reader failed: %w", errors.New("other"))},
		FetchReason("0.81.0 failed: download failed: unrelated prose"),
		map[string]string{"fetchResult": "0.81.0 failed: unrelated prose"},
	} {
		if CheckReaderReasons(value) == nil {
			t.Fatal("accepted non-code artifact")
		}
	}
	for _, value := range []any{
		struct{ Reason string }{"other"}, errors.New("other"),
		[]byte(`{"reason":"http_403","error":"other","lastFailure":{"code":"network"}}`),
		[]byte(`{"lastFailure":{"code":"expired"}}`),
		FetchReason("0.81.0 failed: other"), map[string]string{"fetchResult": "0.81.0 ok"},
	} {
		if err := CheckReaderReasons(value); err != nil {
			t.Fatal(err)
		}
	}
}
func TestReaderReasonActualLogging(t *testing.T) {
	for name, emit := range map[string]func(){
		"macrev-prebound":    func() { readerLog.Print(fmt.Errorf("reader wrapper: %w", errors.New("arbitrary vendor prose"))) },
		"prebound-stdout":    func() { fmt.Fprintln(readerStdout, "arbitrary helper prose") },
		"macrev-wrapped":     func() { log.Print(fmt.Errorf("reader wrapper: %w", errors.New("arbitrary vendor prose"))) },
		"safe-cause-wrapped": func() { log.Print(fmt.Errorf("reader wrapper: %w", errors.New("other"))) },
		"helper-prose":       func() { log.Print("arbitrary helper prose") },
		"stderr":             func() { fmt.Fprintln(os.Stderr, "arbitrary helper prose") },
		"stdout":             func() { fmt.Fprintln(os.Stdout, "arbitrary helper prose") },
	} {
		t.Run(name, func(t *testing.T) {
			check := CaptureReasonLogs(t)
			emit()
			if check() == nil {
				t.Fatal("helper logging escaped the positive guard")
			}
		})
	}
	t.Run("codes", func(t *testing.T) {
		check := CaptureReasonLogs(t)
		log.Print("other")
		fmt.Fprintln(os.Stderr, "network")
		if err := check(); err != nil {
			t.Fatal(err)
		}
	})
}
