// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"github.com/modelplan/modelplan/cli/internal/appserver/wireschema"
)

func main() {
	check := flag.Bool("check", false, "check generated schema without writing")
	flag.Parse()
	root, err := filepath.Abs("..")
	if err != nil {
		panic(err)
	}
	data, err := wireschema.Generate(root)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	path := filepath.Join(root, "schema/app-cli/app-server.json")
	if *check {
		old, err := os.ReadFile(path)
		if err != nil || !bytes.Equal(data, old) {
			fmt.Fprintln(os.Stderr, "app-server schema drift; regenerate from cli/")
			os.Exit(1)
		}
		return
	}
	if err := os.WriteFile(path, data, 0644); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
