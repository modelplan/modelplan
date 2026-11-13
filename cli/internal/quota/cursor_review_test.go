package quota

import (
	"context"
	"os"
	"testing"
	"time"
)

func TestCursorChangedUnsupportedBindingNeverInheritsQuota(t *testing.T) {
	for _, replacement := range []string{"expired", "sealed", "malformed", "missing", "invalid-subject"} {
		t.Run(replacement, func(t *testing.T) {
			p, token := cursorAdmittedPaths(t)
			mode := "ok"
			paths := []string{}
			cursorPeriodServer(t, token, &mode, &paths)
			if err := RefreshNative(context.Background(), p, cursorNow); err != nil {
				t.Fatal(err)
			}
			next := "sealed:synthetic-account-B"
			switch replacement {
			case "expired":
				next = syntheticCursorToken("synthetic-account-B", cursorNow)
			case "malformed":
				next = "bad.?.bad"
			case "invalid-subject":
				next = syntheticCursorToken("bad;subject-B", cursorNow.Add(time.Hour))
			}
			if replacement == "missing" {
				home, _ := os.UserHomeDir()
				if err := os.Remove(CursorReadPath(home)); err != nil {
					t.Fatal(err)
				}
			} else {
				cursorDB(t, next, false)
			}
			// A source/account switch cannot bypass the provider floor.
			if err := RefreshNative(context.Background(), p, cursorNow.Add(time.Minute)); err != nil {
				t.Fatal(err)
			}
			if len(paths) != 2 {
				t.Fatal("changed login bypassed floor")
			}
			if err := RefreshNative(context.Background(), p, cursorNow.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			s, err := loadReaderState(p.Cache, "cursor")
			if err != nil {
				t.Fatal(err)
			}
			if len(paths) != 2 || len(s.Entries) != 1 || s.Entries[0].Account != nil || s.Entries[0].Metadata.CredentialKey != "" {
				t.Fatal("unsupported B inherited A or made a request")
			}
			r := Report{}
			applyManaged(&r, p, "cursor", cursorNow.Add(6*time.Minute))
			if len(r.Accounts) != 0 {
				t.Fatal("old account numbers exposed")
			}
		})
	}
}

func TestCursorSameExpiredBindingRetainsCaptureAndFloor(t *testing.T) {
	p, _ := cursorAdmittedPaths(t)
	token := syntheticCursorToken("synthetic-cursor-account", cursorNow.Add(6*time.Minute))
	cursorDB(t, token, false)
	mode := "ok"
	paths := []string{}
	cursorPeriodServer(t, token, &mode, &paths)
	if err := RefreshNative(context.Background(), p, cursorNow); err != nil {
		t.Fatal(err)
	}
	if err := RefreshNative(context.Background(), p, cursorNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "cursor")
	if len(paths) != 2 || s.Entries[0].Status != "expired" || s.Entries[0].Account == nil || !s.Entries[0].Account.ObservedAt.Equal(cursorNow) || NativeDue(p, cursorNow.Add(6*time.Minute)) {
		t.Fatal("same-binding expiry lost capture age or spacing")
	}
}

func TestCursorMembershipRequiresExplicitConsistentFlag(t *testing.T) {
	for _, tc := range []struct {
		flag, period string
		unified      bool
	}{
		{"", "WEEKLY", false}, {`"isMerged":null,`, "WEEKLY", false},
		{`"isMerged":false,`, "WEEKLY", false}, {`"isMerged":"true",`, "WEEKLY", false},
		{`"isMerged":true,`, "MONTHLY", false}, {`"isMerged":true,`, "WEEKLY", true},
	} {
		raw := []byte(`{` + tc.flag + `"planInfo":{"includedUsagePeriod":"INCLUDED_USAGE_PERIOD_` + tc.period + `"}}`)
		plan, details := parseCursorPlan(raw)
		minutes := 10080
		if tc.period == "MONTHLY" {
			minutes = 43200
		}
		if details == nil || details.Minutes != minutes || details.Unified != tc.unified || (plan == "The X Subscription") != tc.unified {
			t.Fatal("membership fabricated or observed cadence lost", string(raw))
		}
		if ws, ok := parseCursorPeriod([]byte(`{"planUsage":{"totalPercentUsed":12}}`), details, cursorNow); !ok || len(ws) != 1 || ws[0].WindowMinutes != minutes {
			t.Fatal("cadence lost")
		}
	}
}
