package render

import (
	"bytes"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestQuotaSaysWhatARefreshDidAndWhenAReadingIsOld(t *testing.T) {
	for _, c := range []struct {
		refresh *quota.AccountRefresh
		want    string
	}{
		{&quota.AccountRefresh{Source: "codex", Status: "too_soon"}, "it can be asked again in"},
		{&quota.AccountRefresh{Source: "codex", Status: "failed", Reason: "codex not found"}, "not refreshed (codex not found)"},
		{&quota.AccountRefresh{Source: "codex", Status: "not_allowed"}, "not allowed"},
	} {
		var out bytes.Buffer
		Style{T: EN}.Quota(&out, quota.Report{Refresh: c.refresh})
		if !strings.Contains(out.String(), c.want) {
			t.Fatalf("%s: %q", c.refresh.Status, out.String())
		}
	}
	var out bytes.Buffer
	Style{T: EN}.Quota(&out, quota.Report{Refresh: &quota.AccountRefresh{Source: "codex", Status: "refreshed"}, Accounts: []quota.Account{
		{Source: "codex", Stale: true}, {Source: "claude-code", Windows: []quota.Window{{Kind: "weekly", Stale: true}}}}})
	if s := out.String(); !strings.Contains(s, "--refresh-account refreshes it") || strings.Count(s, "old reading") != 2 || strings.Contains(s, "asked") {
		t.Fatalf("stale lines: %q", s)
	}
}
