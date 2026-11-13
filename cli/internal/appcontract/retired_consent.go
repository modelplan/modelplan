// SPDX-License-Identifier: MIT
package appcontract

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// These captures use the same compiled CLI and raw schema validation as the
// other lifecycle captures. Only legacy permission input is seeded by hand;
// every view, mutation receipt and failure reply comes from the real binary.
func (s *suite) captureRetiredConsent(tmp string) error {
	for _, legacy := range []bool{false, true} {
		s.state = "retired"
		if legacy {
			s.state = "retired-legacy"
		}
		s.home = filepath.Join(tmp, s.state)
		if err := s.setup(); err != nil {
			return err
		}
		tool := "codex"
		if legacy {
			tool = "retired-tool"
			file := filepath.Join(s.home, ".config", "modelplan", "consent.json")
			if err := consent.Change(file, func(state *consent.State) error {
				// A previously allowed tool from an older catalogue, with no saved route.
				return consent.Set(state, tool, true, "", "", time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC))
			}); err != nil {
				return err
			}
		} else {
			if err := os.MkdirAll(filepath.Join(s.home, ".codex"), 0700); err != nil {
				return err
			}
			if _, err := s.grant("grant", 0, []string{tool}, []string{}); err != nil {
				return err
			}
			// The grant is real. Now publish a separately verified synthetic catalogue
			// without its entry, rather than just deleting the local tool directory.
			if err := seedPublication(s.home, tool); err != nil {
				return err
			}
		}
		if err := s.capture("consent", "consent", []string{"consent", "--json"}, nil, true, ""); err != nil {
			return err
		}
		if err := s.checkRetiredTool("consent", tool, true); err != nil {
			return err
		}
		// Display-only fallback metadata must never authorize a new grant.
		if _, err := s.grant("unknown-tool", 1, []string{tool}, []string{}); err != nil {
			return err
		}
		if _, err := s.grant("revoke", 1, []string{}, []string{tool}); err != nil {
			return err
		}
		if err := s.checkRetiredTool("revoke", tool, false); err != nil {
			return err
		}
		if err := s.capture("readback", "consent", []string{"consent", "--json"}, nil, true, ""); err != nil {
			return err
		}
		if err := s.checkRetiredTool("readback", tool, false); err != nil {
			return err
		}
		stored, err := consent.Load(filepath.Join(s.home, ".config", "modelplan", "consent.json"))
		if err != nil {
			return err
		}
		if stored.Generation != 2 || stored.Tools[tool].Allowed || stored.Tools[tool].ReaderID != "" || stored.Tools[tool].Backend != "" {
			return fmt.Errorf("%s: display metadata changed revoked permission state", s.state)
		}
	}
	return nil
}

func (s *suite) checkRetiredTool(name, tool string, allowed bool) error {
	var view struct {
		Tools []struct {
			ID, ReaderID, AccessClass string
			Allowed, Detected         bool
		}
	}
	if err := json.Unmarshal(s.files[s.state+"-"+name+".json"], &view); err != nil {
		return err
	}
	for _, row := range view.Tools {
		if row.ID != tool {
			continue
		}
		if row.Allowed != allowed || row.Detected || row.AccessClass != "not-read" || row.ReaderID == "" {
			return fmt.Errorf("%s/%s: retired consent lost permission/detection/display invariants", s.state, name)
		}
		return nil
	}
	return fmt.Errorf("%s/%s: retired consent record disappeared", s.state, name)
}
