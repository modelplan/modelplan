// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"fmt"
	"io"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func doctorReaders(stdout, stderr io.Writer, c common, refresh bool) int {
	st, err := store.Locate()
	if err != nil {
		fmt.Fprintln(stderr, "doctor readers: cache_unavailable")
		return exitErr
	}
	p := quotaPaths(st)
	if refresh {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()
		// Per-reader errors stay in the cached state. Never print raw errors, and
		// always produce the complete inventory even with no admitted readers.
		_ = quota.RefreshReaderDiagnostics(ctx, p, time.Now().UTC())
		p = quotaPaths(st)
	}
	rows := quota.ReaderDiagnostics(p, time.Now().UTC())
	message := "Paste this whole output back to the coordinator; it contains no personal data."
	if c.lang == "zh" {
		message += "\n请将完整输出粘贴给协调者；其中不含个人数据。"
	}
	if c.json {
		return printJSON(stdout, struct {
			Readers []quota.ReaderDiagnostic `json:"readers"`
			Message string                   `json:"message"`
		}{rows, message})
	}
	for _, r := range rows {
		fmt.Fprintf(stdout, "%s  detected=%s  consent=%s  admitted=%s  state=%s  windows=%d  last=%s  beta=%t\n", r.Provider, r.Detected, r.Consent, r.Admitted, r.State, r.Windows, r.Last, r.Beta)
	}
	fmt.Fprintln(stdout, message)
	return 0
}
