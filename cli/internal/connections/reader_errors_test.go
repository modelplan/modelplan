// SPDX-License-Identifier: MIT
package connections

import (
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/testenv"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestNativeConnectionReasonsAreCodesIncludingLastGood(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "")
	home, _ := os.UserHomeDir()
	file := filepath.Join(home, "connections.json")
	for _, hidden := range []string{"person@example.invalid", "acct_private_12345", "/Users/Private/credentials", `C:\Users\Private\token`, strings.Repeat("ab", 32)} {
		for _, lastGood := range []bool{false, true} {
			if err := quota.SetConnection(file, quota.QuotaSource{Provider: "kiro", Backend: quota.BackendNative, Enabled: true}); err != nil {
				t.Fatal(err)
			}
			report := quota.Report{Sources: []quota.SourceStatus{{Source: "native:kiro", Status: "unavailable", Reason: hidden, ErrorCode: "http_403"}}}
			if lastGood {
				used := 20.0
				report.Accounts = []quota.Account{{Source: "native:kiro", ObservedAt: time.Now(), Windows: []quota.Window{{UsedPercent: &used}}}}
			}
			for _, code := range []string{"http_403", hidden} {
				report.Sources[0].ErrorCode = code
				found := false
				for _, connection := range Diagnose(Env{Home: home, ConnectionsFile: file}, report) {
					if connection.ID != "native:kiro" {
						continue
					}
					found = true
					want := "http_403"
					if code == hidden {
						want = "other"
					}
					if connection.Quota.Reason != want {
						t.Fatal(connection)
					}
					data, _ := json.Marshal(connection.Quota)
					if strings.Contains(string(data), hidden) {
						t.Fatal("connection reason leaked provider/cache text")
					}
				}
				if !found {
					t.Fatal("native connection missing")
				}
			}
		}
	}
}
