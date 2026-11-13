//go:build !darwin && !linux && !windows

// SPDX-License-Identifier: MIT
package cliupdate

import "errors"

func lockPlatform(string) (func(), error) { return nil, errors.New("CLI update locking unavailable") }
