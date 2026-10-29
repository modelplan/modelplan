// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"flag"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/swiftwire"
	"os"
	"path/filepath"
)

func main() {
	write := flag.Bool("write", false, "write generated Swift and captures")
	check := flag.Bool("check", false, "reject generated drift")
	root := flag.String("root", "..", "repository root")
	flag.Parse()
	if *write == *check {
		fmt.Fprintln(os.Stderr, "choose --write or --check")
		os.Exit(2)
	}
	generated, err := swiftwire.Generate(*root)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	files, err := swiftwire.Captures(*root)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	environment, err := swiftwire.ChildEnvironmentContract()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	outputs := map[string][]byte{
		filepath.Join(*root, "clients/swift/ModelPlanWire/Sources/ModelPlanWire/Generated.swift"): generated,
		filepath.Join(*root, "schema/app-cli/child-environment.json"):                             environment,
	}
	for name, data := range files {
		path := filepath.Join(*root, "schema/app-cli/captures", name)
		if name == "CaptureTypes.swift" {
			path = filepath.Join(*root, "clients/swift/ModelPlanWire/Tests/ModelPlanWireTests/CaptureTypes.swift")
		}
		outputs[path] = data
	}
	for path, generated := range outputs {
		if *write {
			err = os.WriteFile(path, generated, 0644)
		} else {
			var stored []byte
			stored, err = os.ReadFile(path)
			if err == nil && !bytes.Equal(stored, generated) {
				err = fmt.Errorf("Swift drift: regenerate")
			}
		}
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	}
}
