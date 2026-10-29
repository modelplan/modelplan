// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
)

// No installer, shell, credentials or network: this executable is symlinked as
// the two host tools solely to record the real CLI's fixed argv and return a status.
func pluginHost() int {
	host := filepath.Base(os.Args[0])
	var commands [][]string
	switch host {
	case "claude":
		commands = [][]string{{"plugin", "marketplace", "add", "modelplan/modelplan"}, {"plugin", "install", "modelplan@modelplan"}}
	case "codex":
		commands = [][]string{{"plugin", "marketplace", "add", "modelplan/modelplan", "--sparse", ".agents", "--sparse", "codex"}, {"plugin", "add", "modelplan-codex@modelplan"}}
	default:
		return 99
	}
	path := os.Getenv("MODELPLAN_CONTRACT_PLUGIN_CALLS")
	old, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return 99
	}
	step := bytes.Count(old, []byte{'\n'})
	if step >= len(commands) || !reflect.DeepEqual(os.Args[1:], commands[step]) {
		return 99
	}
	log, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return 99
	}
	raw, err := json.Marshal(append([]string{host}, os.Args[1:]...))
	if err == nil {
		_, err = log.Write(append(raw, '\n'))
	}
	closeErr := log.Close()
	if err != nil || closeErr != nil {
		return 99
	}
	// The JSON CLI must forward host stdout to stderr, keeping its own stdout clean.
	fmt.Fprintln(os.Stdout, "synthetic host progress")
	switch os.Getenv("MODELPLAN_CONTRACT_PLUGIN_MODE") {
	case "failed-first":
		fmt.Fprintln(os.Stderr, "synthetic host command error")
		return 17
	case "failed-manual-step":
		if step == 1 {
			fmt.Fprintln(os.Stderr, "synthetic host requires a manual step")
			return 17
		}
	case "installed":
	default:
		return 99 // Planned/missing-host captures must never launch this helper.
	}
	return 0
}
