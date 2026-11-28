// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
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
	storeCode := ""
	if _, err := consent.Load(consent.Path()); err != nil {
		storeCode = "consent_store_unreadable"
		message += "\nConsent store unreadable. Reset in Settings after confirmation. / 授权存储无法读取，请在设置中确认后重置。"
	}
	if c.json {
		return printJSON(stdout, struct {
			Readers      []quota.ReaderDiagnostic `json:"readers"`
			Message      string                   `json:"message"`
			ConsentStore string                   `json:"consentStore,omitempty"`
		}{rows, message, storeCode})
	}
	for _, r := range rows {
		cause := ""
		if r.Cause != "" {
			cause = "  cause=" + r.Cause
		}
		fmt.Fprintf(stdout, "%s  detected=%s  consent=%s  admitted=%s  state=%s%s  windows=%d  last=%s  beta=%t\n", r.Provider, r.Detected, r.Consent, r.Admitted, r.State, cause, r.Windows, r.Last, r.Beta)
		if line := codexCLILine(r.CodexCLI, c.lang); line != "" {
			fmt.Fprintf(stdout, "  %s cli  %s\n", r.Provider, line)
		}
		for _, f := range r.Failures {
			fmt.Fprintf(stdout, "  %s failure  code=%s  at=%s  streak=%ds\n", r.Provider, f.Code, f.At, f.StreakSeconds)
		}
	}
	fmt.Fprintln(stdout, message)
	return 0
}

// codexCLILine names the source of the Codex CLI in the reader's language (owner decision D487);
// the note carries a source word and a version, never a path.
func codexCLILine(note, lang string) string {
	source, version, _ := strings.Cut(note, " ")
	en := map[string]string{"override": "explicit path", "app": "desktop app", "homebrew": "Homebrew", "npm": "npm", "path": "PATH"}
	zh := map[string]string{"override": "指定路径", "app": "桌面应用内置", "homebrew": "Homebrew", "npm": "npm", "path": "PATH"}
	names := en
	if lang == "zh" {
		names = zh
	}
	name, ok := names[source]
	if !ok {
		return ""
	}
	if version == "" {
		return name
	}
	return name + "  " + version
}
