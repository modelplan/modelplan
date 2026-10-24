package main

import (
	"github.com/modelplan/modelplan/cli/internal/testenv"
	"testing"
)

func isolateHome(t *testing.T) {
	t.Helper()
	testenv.IsolateHome(t)
}
