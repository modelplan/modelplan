// SPDX-License-Identifier: MIT
package main

import (
	"flag"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/releaseguard"
	"os"
)

func main() {
	root := flag.String("root", "..", "repository root")
	flag.Parse()
	hits, err := releaseguard.CheckApple(*root)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	for _, hit := range hits {
		fmt.Fprintln(os.Stderr, hit)
	}
	if len(hits) > 0 {
		os.Exit(1)
	}
	fmt.Println("private Apple SPI: no release-source hits")
}
