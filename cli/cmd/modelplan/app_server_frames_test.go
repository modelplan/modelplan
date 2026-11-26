// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

type discardCloser struct{ io.Writer }

func (discardCloser) Close() error { return nil }

// fakeSession is a queryBinary over a fixed server output and exit, without a process.
func fakeSession(t *testing.T, output string, exit error, stderr string) *queryBinary {
	t.Helper()
	errFile := filepath.Join(t.TempDir(), "stderr")
	if err := os.WriteFile(errFile, []byte(stderr), 0600); err != nil {
		t.Fatal(err)
	}
	p := &queryBinary{t: t, in: discardCloser{io.Discard}, frames: make(chan []byte, 8), done: make(chan error, 1), stderr: errFile}
	p.done <- exit
	go p.readFrames(context.Background(), strings.NewReader(output))
	return p
}

// macrevc-1240-1: a frame is committed by its newline. At a clean end of stream only terminated
// records are delivered; complete or truncated JSON without its newline is never parsed.
func TestBinaryHarnessDeliversOnlyCommittedFrames(t *testing.T) {
	const private = `"privateValue":"synthetic-secret"`
	terminated := fakeSession(t, `{"jsonrpc":"2.0","id":1,"result":{}}`+"\n", nil, "")
	if msg, open := terminated.callUnlessEnded("consent/get", map[string]any{}); !open || msg["result"] == nil {
		t.Fatalf("a terminated record was not delivered: %v %s", open, msg)
	}
	for name, output := range map[string]string{
		"complete unterminated JSON": `{"jsonrpc":"2.0","id":1,"result":{` + private + `}}`,
		"truncated JSON":             `{"jsonrpc":"2.0","id":1,"result":{` + private,
	} {
		t.Run(name, func(t *testing.T) {
			p := fakeSession(t, output, nil, "")
			msg, open := p.callUnlessEnded("consent/get", map[string]any{})
			if open || msg != nil {
				t.Fatalf("an uncommitted frame was delivered: %s", msg)
			}
			if !strings.Contains(string(p.dropped), "synthetic-secret") || len(p.notifications) != 0 {
				t.Fatalf("the uncommitted tail was not set aside: dropped %q, notifications %d", p.dropped, len(p.notifications))
			}
		})
	}
}

// A clean end is exit 0 with nothing on stderr; anything else, and a malformed terminated
// record, still fails the test. Each case runs in a child test process that must fail.
func TestBinaryHarnessStillFailsOnCrashStderrAndMalformedFrames(t *testing.T) {
	if c := os.Getenv("MODELPLAN_FRAMES_CHILD"); c != "" {
		var p *queryBinary
		switch c {
		case "exit":
			p = fakeSession(t, "", errors.New("exit status 7"), "")
		case "stderr":
			p = fakeSession(t, "", nil, "panic: synthetic")
		case "malformed":
			p = fakeSession(t, "{not json}\n", nil, "")
		}
		p.callUnlessEnded("consent/get", map[string]any{})
		return // reaching here means the case was accepted
	}
	for c, want := range map[string]string{"exit": "app-server exited: exit status 7", "stderr": "app-server ended with stderr: panic: synthetic", "malformed": "invalid server frame"} {
		cmd := exec.Command(os.Args[0], "-test.run=^TestBinaryHarnessStillFailsOnCrashStderrAndMalformedFrames$", "-test.count=1")
		cmd.Env = append(os.Environ(), "MODELPLAN_FRAMES_CHILD="+c)
		out, err := cmd.CombinedOutput()
		var exit *exec.ExitError
		if !errors.As(err, &exit) || !strings.Contains(string(out), "--- FAIL") || !strings.Contains(string(out), want) {
			t.Errorf("%s: the harness accepted it: %v\n%s", c, err, out)
		}
	}
}
