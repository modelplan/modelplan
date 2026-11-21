// SPDX-License-Identifier: MIT
//go:build modelplan_test_cadence

package main

import (
	"os"
	"strconv"
	"time"

	"github.com/modelplan/modelplan/cli/internal/publication"
)

// Test-only: a binary built with -tags modelplan_test_cadence reads MODELPLAN_TEST_PUBLICATION_RECHECK_SECONDS and
// uses it for the publication loop's wake-up and its reset-notice interval, so a real-binary test can observe the
// re-checks in seconds. Release builds do not carry this file and never read the variable.
var testCadenceActive bool

func testCadenceOn() bool { return testCadenceActive }

func applyTestCadence(a *appPublication) {
	if n, err := strconv.Atoi(os.Getenv("MODELPLAN_TEST_PUBLICATION_RECHECK_SECONDS")); err == nil && n > 0 {
		testCadenceActive = true
		a.testCadence = time.Duration(n) * time.Second
		publication.SetTestMinCheckInterval(a.testCadence)
	}
}
