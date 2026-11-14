// SPDX-License-Identifier: MIT
//go:build !modelplan_test_cadence

package main

// applyTestCadence is a no-op outside test builds.
func applyTestCadence(*appPublication) {}

// testCadenceOn is false outside test builds.
func testCadenceOn() bool { return false }
