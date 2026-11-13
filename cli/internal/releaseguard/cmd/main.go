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
	binary := flag.String("binary", "", "built release binary to scan for known private SPI names")
	flag.Parse()
	if *binary != "" {
		hits, err := releaseguard.CheckBinary(*binary)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		for _, name := range hits {
			fmt.Fprintf(os.Stderr, "%s: denylisted Apple SPI %s\n", *binary, name)
		}
		if len(hits) > 0 {
			os.Exit(1)
		}
		fmt.Println("release binary SPI: no denylisted names")
		return
	}
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
