// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"net"
	"reflect"
	"regexp"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
)

func TestConsentHostDetailsAlwaysContainBareDNSNames(t *testing.T) {
	consentAPIHome(t)
	providers := []string{"antigravity", "minimax", "windsurf", "devin", "augment", "qoder", "perplexity", "manus", "mistral", "unknown"}
	for _, e := range detect.Fallback().Detectors {
		providers = append(providers, e.ProviderID)
	}
	label := regexp.MustCompile(`^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$`)
	for _, id := range providers {
		for _, region := range []string{"", "china", "international", "bigmodel-cn"} {
			t.Run(id+"/"+region, func(t *testing.T) {
				s := consent.Empty()
				s.Tools[id] = consent.Record{Region: region}
				report := detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: id}, Detected: true}}}
				row := consentTools(s, report)[0]
				legacy := consentHosts(id, region)
				if legacy == nil {
					legacy = []string{}
				}
				if !reflect.DeepEqual(row.Hosts, legacy) {
					t.Fatal("legacy hosts changed", row.Hosts, legacy)
				}
				wantCount := 0
				for _, host := range legacy {
					if strings.HasPrefix(host, "https://") {
						wantCount++
					}
				}
				if len(row.HostDetails) != wantCount {
					t.Fatal("structured destinations missing", row)
				}
				for _, detail := range row.HostDetails {
					parts := strings.Split(detail.Host, ".")
					if len(parts) < 2 || len(detail.Host) > 253 || net.ParseIP(detail.Host) != nil {
						t.Fatal("not a bare DNS name", detail)
					}
					for _, part := range parts {
						if !label.MatchString(part) {
							t.Fatal("URL or annotation leaked into host", detail)
						}
					}
				}
				b, err := json.Marshal(row)
				if err != nil {
					t.Fatal(err)
				}
				var wire map[string]json.RawMessage
				if err := json.Unmarshal(b, &wire); err != nil {
					t.Fatal(err)
				}
				if string(wire["hostDetails"]) == "null" || len(wire["hostDetails"]) == 0 {
					t.Fatal("hostDetails must always be an array", string(b))
				}
				var details []map[string]string
				if err := json.Unmarshal(wire["hostDetails"], &details); err != nil {
					t.Fatal(err)
				}
				for i, detail := range details {
					if _, ok := detail["note"]; !ok || len(detail) != 2 || detail["host"] != row.HostDetails[i].Host || detail["note"] != row.HostDetails[i].Note {
						t.Fatal("host/note schema changed", detail)
					}
				}
			})
		}
	}
}

func TestConsentAPIHostDetailsReadGrantAndReplay(t *testing.T) {
	consentAPIHome(t)
	check := func(rows []consentTool) {
		t.Helper()
		tools := apiTools(rows)
		for _, tc := range []struct{ id, legacy, host, note string }{
			{"claude", "https://api.anthropic.com", "api.anthropic.com", ""},
			{"codex", "https://chatgpt.com (Codex runtime)", "chatgpt.com", "Codex runtime"},
		} {
			row := tools[tc.id]
			if !reflect.DeepEqual(row.Hosts, []string{tc.legacy}) || !reflect.DeepEqual(row.HostDetails, []consentHostDetail{{Host: tc.host, Note: tc.note}}) {
				t.Fatal("host details lost compatibility or context", row)
			}
		}
	}
	check(readConsentAPI(t).Tools)
	request := apiRequest(t, 1, 0, []string{"claude", "codex"}, nil, nil)
	result := grantConsentAPI(t, request)
	check(result.Tools)
	check(readConsentAPI(t).Tools)
	if replay := grantConsentAPI(t, request); !reflect.DeepEqual(replay, result) {
		t.Fatal("replay changed structured hosts", replay, result)
	}
}
