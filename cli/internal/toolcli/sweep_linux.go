// SPDX-License-Identifier: MIT
//go:build linux

package toolcli

import (
	"bytes"
	"os"
	"strconv"
	"syscall"
)

// killTagged kills every process of this user whose environment carries tag ("NAME=value").
// Other users' environments are unreadable, so only this user's processes are considered.
func killTagged(tag string) {
	needle := append([]byte(tag), 0)
	for pass := 0; pass < 3; pass++ {
		entries, err := os.ReadDir("/proc")
		if err != nil {
			return
		}
		found := false
		self := os.Getpid()
		for _, e := range entries {
			pid, err := strconv.Atoi(e.Name())
			if err != nil || pid <= 1 || pid == self {
				continue
			}
			env, err := os.ReadFile("/proc/" + e.Name() + "/environ")
			if err != nil || !bytes.Contains(append([]byte{0}, env...), append([]byte{0}, needle...)) {
				continue
			}
			found = true
			_ = syscall.Kill(pid, syscall.SIGKILL)
		}
		if !found {
			return
		}
	}
}
