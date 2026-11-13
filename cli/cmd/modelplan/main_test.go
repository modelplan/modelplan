package main

import (
	"github.com/modelplan/modelplan/cli/internal/testenv"
	"testing"
)

func isolateHome(t *testing.T) {
	t.Helper()
	testenv.IsolateHome(t)
	old := startNativeDetached
	t.Cleanup(func() { startNativeDetached = old })
	startNativeDetached = func(string, ...string) error {
		t.Fatal("unexpected detached native refresh; install a test launcher")
		return nil
	}
}
