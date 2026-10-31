// SPDX-License-Identifier: MIT
package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
)

const (
	adviceStateBusy       = "advice_state_busy"
	adviceStateSaveFailed = "advice_state_save_failed"
)

// saveAdviceState retries only lock contention, once. No filesystem error text,
// quota values or identifiers enter the diagnostic record or fallback stderr.
func saveAdviceState(state *advise.State, cache string, now time.Time) {
	err := state.Save(cache, now)
	if errors.Is(err, advise.ErrStateBusy) {
		err = state.Save(cache, now)
	}
	if err == nil {
		return
	}
	code := adviceStateSaveFailed
	if errors.Is(err, advise.ErrStateBusy) {
		code = adviceStateBusy
	}
	reportAdviceSaveError(cache, code, os.Stderr)
}

func reportAdviceSaveError(cache, code string, fallback io.Writer) {
	if recordAdviceSaveError(cache, code) != nil {
		fmt.Fprintln(fallback, code)
	}
}

// One bounded record replaces the previous one; only the two compiled codes
// can be written, and rename never follows a final-component symlink.
func recordAdviceSaveError(cache, code string) error {
	if code != adviceStateBusy && code != adviceStateSaveFailed {
		return errors.New("invalid advice save code")
	}
	dir := filepath.Join(cache, "observed")
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
	}
	f, err := os.CreateTemp(dir, ".advice-error-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	_, err = fmt.Fprintf(f, "{\"code\":\"%s\"}\n", code)
	if closeErr := f.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	return os.Rename(f.Name(), filepath.Join(dir, "advice-save-error.json"))
}
