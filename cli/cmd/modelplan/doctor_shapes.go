// SPDX-License-Identifier: MIT
package main

import (
	"fmt"
	"io"
	"os"
	"slices"
	"time"

	"github.com/modelplan/modelplan/cli/internal/shapecapture"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// doctorShapes writes structure-only samples (keys, value types, relative times) of the files
// the readers consume. Local only: no network, no credential value is ever written.
func doctorShapes(stdout, stderr io.Writer, tool, out string) int {
	if tool != "all" && !slices.Contains(shapecapture.ToolNames(), tool) {
		fmt.Fprintln(stderr, "doctor shapes: unknown tool; one of "+fmt.Sprint(shapecapture.ToolNames())+" or all")
		return exitUsage
	}
	if ents, err := os.ReadDir(out); err == nil && len(ents) > 0 {
		fmt.Fprintln(stderr, "doctor shapes: output directory must be empty")
		return exitUsage
	}
	home, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintln(stderr, "doctor shapes: home_unavailable")
		return exitErr
	}
	env := shapecapture.Env{Home: home}
	if st, err := store.Locate(); err == nil {
		env.CacheDir = st.Dir
	}
	now := time.Now().UTC()
	var ms []shapecapture.Manifest
	for _, t := range shapecapture.Tools() {
		if tool != "all" && t.Name != tool {
			continue
		}
		m, err := shapecapture.Capture(t, env, out, now)
		if err != nil {
			fmt.Fprintln(stderr, "doctor shapes: write_failed")
			return exitErr
		}
		ms = append(ms, m)
		written := 0
		for _, f := range m.Files {
			if f.Output != "" {
				written++
			}
		}
		fmt.Fprintf(stdout, "%s  samples=%d  files=%d\n", t.Name, written, len(m.Files))
	}
	if err := shapecapture.WriteManifest(out, ms); err != nil {
		fmt.Fprintln(stderr, "doctor shapes: write_failed")
		return exitErr
	}
	fmt.Fprintln(stdout, "Wrote structure-only samples and manifest.json. Review manifest.json before sharing.")
	return 0
}
