//go:build unix

// SPDX-License-Identifier: MIT
package testenv

import (
	"errors"
	"io"
	"os"
	"testing"
	"time"

	"golang.org/x/sys/unix"
)

// Dup2 changes fd 1/2 themselves, so previously bound *os.File/log.Logger
// writers and child processes use the capture too. Drain concurrently so an
// ordinary burst of output cannot fill the pipe and block the reader.
func captureProcessOutput(t *testing.T) func() (string, error) {
	t.Helper()
	stdout, err := unix.FcntlInt(1, unix.F_DUPFD_CLOEXEC, 3)
	if err != nil {
		t.Fatal(err)
	}
	stderr, err := unix.FcntlInt(2, unix.F_DUPFD_CLOEXEC, 3)
	if err != nil {
		unix.Close(stdout)
		t.Fatal(err)
	}
	reader, writer, err := os.Pipe()
	if err != nil {
		unix.Close(stdout)
		unix.Close(stderr)
		t.Fatal(err)
	}
	if err := unix.Dup2(int(writer.Fd()), 1); err != nil {
		reader.Close()
		writer.Close()
		unix.Close(stdout)
		unix.Close(stderr)
		t.Fatal(err)
	}
	if err := unix.Dup2(int(writer.Fd()), 2); err != nil {
		unix.Dup2(stdout, 1)
		reader.Close()
		writer.Close()
		unix.Close(stdout)
		unix.Close(stderr)
		t.Fatal(err)
	}
	writer.Close()
	type captured struct {
		output string
		err    error
	}
	done := make(chan captured, 1)
	go func() { b, err := io.ReadAll(reader); done <- captured{string(b), err} }()
	var finished bool
	var output string
	var result error
	finish := func() (string, error) {
		if finished {
			return output, result
		}
		finished = true
		restoreOut := unix.Dup2(stdout, 1)
		restoreErr := unix.Dup2(stderr, 2)
		unix.Close(stdout)
		unix.Close(stderr)
		// A leaked child descriptor is a capture failure, not an indefinite hang.
		reader.SetReadDeadline(time.Now().Add(2 * time.Second))
		capture := <-done
		reader.Close()
		output = capture.output
		result = errors.Join(restoreOut, restoreErr, capture.err)
		return output, result
	}
	t.Cleanup(func() { _, _ = finish() })
	return finish
}
