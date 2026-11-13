// SPDX-License-Identifier: MIT
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"

	"github.com/modelplan/modelplan/cli/internal/appcontract"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

func main() {
	if len(os.Args) != 2 {
		os.Exit(2)
	}
	validator, err := appcontract.NewValidator(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, "schema-compile-failed")
		os.Exit(1)
	}
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 4096), wire.MaxFrameBytes)
	count := 0
	for scanner.Scan() {
		if validator.Validate("app-server", scanner.Bytes()) != nil {
			fmt.Fprintln(os.Stderr, "invalid-wire-frame")
			os.Exit(1)
		}
		count++
	}
	if scanner.Err() != nil {
		fmt.Fprintln(os.Stderr, "frame-read-failed")
		os.Exit(1)
	}
	_ = json.NewEncoder(os.Stdout).Encode(map[string]int{"validatedFrames": count})
}
