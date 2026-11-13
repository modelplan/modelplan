// SPDX-License-Identifier: MIT
package appcontract

import (
	"os"
	"path/filepath"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Per-scope requests and receipts pass the same real-binary decoder/schema seam
// as the legacy lifecycle. Tightening runs with readers off and a retired scope.
func (s *suite) captureScopedConsent(tmp string) error {
	s.state = "scoped"
	s.home = filepath.Join(tmp, s.state)
	if err := s.setup(); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Join(s.home, ".copilot"), 0700); err != nil {
		return err
	}
	if _, err := s.grant("grant", 0, []string{consent.ScopeCopilotRuntimeUsage}, nil); err != nil {
		return err
	}
	if err := s.capture("consent", "consent", []string{"consent", "--json"}, nil, true, ""); err != nil {
		return err
	}
	s.env = append(s.env, "MODELPLAN_READERS=off")
	if _, err := s.grant("revoke", 1, nil, []string{consent.ScopeCopilotRuntimeUsage}); err != nil {
		return err
	}
	if _, err := s.grant("forget", 2, nil, nil, []string{"retired.old_path"}); err != nil {
		return err
	}
	return s.capture("readback", "consent", []string{"consent", "--json"}, nil, true, "")
}
