// SPDX-License-Identifier: MIT
package main

import (
	"errors"
	"flag"
	"io"
)

type appServerOptions struct{ Offline, ReadOnly bool }

// Do not echo arbitrary arguments onto the protocol's allow-listed stderr.
func parseAppServerOptions(args []string) (appServerOptions, error) {
	var options appServerOptions
	flags := flag.NewFlagSet("app-server", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	flags.BoolVar(&options.Offline, "offline", false, "keep refresh and plugin installation offline")
	flags.BoolVar(&options.ReadOnly, "read-only", false, "disable reader and installation writes")
	if flags.Parse(args) != nil || flags.NArg() != 0 {
		return appServerOptions{}, errors.New("invalid_arguments")
	}
	return options, nil
}
