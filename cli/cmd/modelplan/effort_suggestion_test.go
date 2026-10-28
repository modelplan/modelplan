// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/render"
	"github.com/modelplan/modelplan/cli/internal/snapshot"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func effortTestCache(t *testing.T, at time.Time) *store.Store {
	t.Helper()
	isolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "")
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	st := &store.Store{Dir: t.TempDir()}
	t.Setenv("MODELPLAN_CACHE", st.Dir)
	f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		var v map[string]json.RawMessage
		_ = json.Unmarshal([]byte(contracttest.Client), &v)
		doc["data"] = v["data"]
	})
	if err := os.MkdirAll(filepath.Join(st.Dir, "objects"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(st.ManifestPath(f.id)), 0700); err != nil {
		t.Fatal(err)
	}
	if err := st.PutObject(f.objectHash, f.object); err != nil {
		t.Fatal(err)
	}
	if err := st.PutManifest(f.id, f.manifest); err != nil {
		t.Fatal(err)
	}
	if err := st.SaveState(store.State{PublicationID: f.id, ManifestHash: publicationHash(f.manifest), Component: "client", ComponentHash: f.objectHash}); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(history.Path(st.Dir)), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(history.Path(st.Dir), publicationJSON(t, contracttest.EffortLedger(at, "medium", false, 40, 45, 50)), 0600); err != nil {
		t.Fatal(err)
	}
	original := startDetached
	startDetached = func(...string) error { t.Fatal("unexpected subprocess"); return nil }
	t.Cleanup(func() { startDetached = original })
	return st
}

func TestEffortSuggestionHookIsUserOnly(t *testing.T) {
	for _, harness := range []string{"codex", "claude-code"} {
		for _, brief := range []string{"", "off"} {
			for _, lang := range []string{"en", "zh"} {
				t.Run(harness+"/"+brief+"/"+lang, func(t *testing.T) {
					at := contracttest.Now
					st := effortTestCache(t, at)
					t.Setenv("MODELPLAN_TASK_BRIEF", brief)
					style := render.Style{T: render.EN}
					needle := "past 3 weeks averaged 45%"
					if lang == "zh" {
						style.T = render.ZH
						needle = "过去 3 周平均用了 45%"
					}
					for i := 0; i < 2; i++ {
						var out bytes.Buffer
						adviseHookAt(strings.NewReader(`{"session_id":"synthetic-thread","model":"native-z"}`), &out, style, st, nil, common{offline: true}, harness, "existing user notice", "Synthetic public agent context.", at)
						var result struct {
							System string `json:"systemMessage"`
							Hook   struct {
								Context string `json:"additionalContext"`
							} `json:"hookSpecificOutput"`
						}
						if err := json.Unmarshal(out.Bytes(), &result); err != nil {
							t.Fatal(err, out.String())
						}
						if strings.Contains(result.Hook.Context, needle) || strings.Contains(result.Hook.Context, "effortSuggestion") || strings.Contains(result.Hook.Context, "past 3 weeks") || strings.Contains(result.Hook.Context, "过去 3 周") {
							t.Fatalf("personal suggestion leaked to model: %s", out.String())
						}
						if strings.Contains(result.System, needle) != (i == 0) {
							t.Fatalf("wrong user notification/throttle: %s", out.String())
						}
						if !strings.Contains(result.Hook.Context, "Synthetic public agent context.") {
							t.Fatal("test must cover real agent context too")
						}
					}
				})
			}
		}
	}
}

func TestEffortSuggestionDesktopReadOnlyAndHistory(t *testing.T) {
	st := effortTestCache(t, time.Now())
	before := tree(t, st.Dir)
	var out, stderr bytes.Buffer
	if code := run([]string{"desktop", "--json", "--read-only", "--offline", "--lang", "en"}, nil, &out, &stderr); code != 0 {
		t.Fatal(code, stderr.String())
	}
	if err := contracttest.ValidateOutput("desktop", out.Bytes()); err != nil {
		t.Fatal(err)
	}
	var got snapshot.Snapshot
	if err := json.Unmarshal(out.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got.ContractVersion != 1 || got.EffortSuggestion == nil || !strings.Contains(got.EffortSuggestion.Message, "past 3 weeks averaged 45%") {
		t.Fatalf("desktop suggestion missing: %s", out.String())
	}
	if !reflect.DeepEqual(before, tree(t, st.Dir)) {
		t.Fatal("read-only desktop wrote local state")
	}
	out.Reset()
	if code := run([]string{"history", "--offline", "--lang", "en"}, nil, &out, &stderr); code != 0 || !strings.Contains(out.String(), "Default effort suggestion (local only)") {
		t.Fatal(code, out.String(), stderr.String())
	}
	out.Reset()
	if code := run([]string{"history", "--json", "--offline"}, nil, &out, &stderr); code != 0 || strings.Contains(out.String(), "effortSuggestion") || strings.Contains(out.String(), "past 3 weeks") {
		t.Fatal("plugin measurement feed gained private derived advice", code, out.String())
	}
	out.Reset()
	if code := run([]string{"history", "--effort-suggestion", "off", "--json"}, nil, &out, &stderr); code != 0 {
		t.Fatal(code, stderr.String())
	}
	if history.ReadEffortSuggestion(st.Dir, mustEffortDigest(t), time.Now()).Suggestion != nil {
		t.Fatal("CLI off did not persist")
	}
}

func mustEffortDigest(t *testing.T) *digest.Digest {
	t.Helper()
	d, err := contracttest.Public()
	if err != nil {
		t.Fatal(err)
	}
	return d
}

// These fixtures are handwritten; no installed quota files or sessions are read.
func claudeEffortFixture(t *testing.T, at time.Time) (*store.Store, quota.Report) {
	t.Helper()
	st := effortTestCache(t, at)
	t.Setenv("MODELPLAN_READERS", "passive")
	t.Setenv("ANTHROPIC_BASE_URL", "")
	l := contracttest.EffortLedger(at, "medium", false, 40, 45, 50)
	for i := range l.Cycles {
		l.Cycles[i].Source = "claude-code"
	}
	if err := os.WriteFile(history.Path(st.Dir), publicationJSON(t, l), 0600); err != nil {
		t.Fatal(err)
	}
	used, reset := 20.0, at.Add(6*24*time.Hour)
	r := quota.Report{Accounts: []quota.Account{{Source: "claude-code", Plan: "synthetic-plan", ObservedAt: at,
		Harness: &quota.Harness{Model: "native-z", Effort: "medium"},
		Windows: []quota.Window{{Kind: "weekly", WindowMinutes: 10080, UsedPercent: &used, ResetsAt: &reset, ObservedAt: at}}}}}
	quota.Evaluate(&r.Accounts[0], at)
	return st, r
}

func TestEffortSuggestionStatuslineSharesWeeklyNotice(t *testing.T) {
	at := time.Now()
	st, report := claudeEffortFixture(t, at)
	d := mustEffortDigest(t)
	style := render.Style{T: render.EN}
	hint := statuslineHint(style, st, d, report, at, true)
	if !strings.Contains(hint, "default: 3wk 45% ★Med→High ref ×1.50") {
		t.Fatalf("hint: %q", hint)
	}
	if second := statuslineHint(style, st, d, report, at.Add(time.Minute), true); strings.Contains(second, "default:") {
		t.Fatalf("repeated hint: %q", second)
	}
	var out, stderr bytes.Buffer
	if code := run([]string{"history", "--offline", "--lang", "en"}, nil, &out, &stderr); code != 0 || strings.Contains(out.String(), "Default effort suggestion") {
		t.Fatal("history repeated status-line notice", code, out.String(), stderr.String())
	}
	if history.NotifyEffortSuggestion(st.Dir, d, at.Add(time.Hour)) != nil {
		t.Fatal("hook repeated status-line notice")
	}
}

func TestEffortSuggestionHistoryClaimsWeeklyNotice(t *testing.T) {
	at := time.Now()
	st := effortTestCache(t, at)
	for i := 0; i < 2; i++ {
		var out, stderr bytes.Buffer
		code := run([]string{"history", "--offline", "--lang", "en"}, nil, &out, &stderr)
		if code != 0 || strings.Contains(out.String(), "Default effort suggestion") != (i == 0) {
			t.Fatal(code, out.String(), stderr.String())
		}
	}
	if history.NotifyEffortSuggestion(st.Dir, mustEffortDigest(t), at.Add(time.Hour)) != nil {
		t.Fatal("hook repeated history notice")
	}
}

func TestEffortSuggestionStatuslineSilentPathsDoNotClaim(t *testing.T) {
	for _, mode := range []string{"preview", "record-only", "no meter", "urgent", "unknown effort", "endpoint", "history off", "other plan", "no history"} {
		t.Run(mode, func(t *testing.T) {
			at := time.Now()
			st, report := claudeEffortFixture(t, at)
			d := mustEffortDigest(t)
			style := render.Style{T: render.EN}
			switch mode {
			case "preview", "record-only", "no meter":
				var in quota.StatuslineInput
				input := `{"model":{"id":"native-z"},"effort":{"level":"medium"},"rate_limits":{"seven_day":{"used_percentage":20,"resets_at":` + fmt.Sprint(at.Add(6*24*time.Hour).Unix()) + `}}}`
				if mode == "no meter" {
					input = `{"model":{"id":"native-z"},"effort":{"level":"medium"}}`
				}
				if err := json.Unmarshal([]byte(input), &in); err != nil {
					t.Fatal(err)
				}
				var out bytes.Buffer
				var w io.Writer = &out
				if mode == "record-only" {
					w = io.Discard
				}
				statuslineInput(in, w, style, st, common{offline: true}, "claude-code", "native-z", "medium", mode == "preview")
				if strings.Contains(out.String(), "default:") {
					t.Fatal("silent path rendered notice", out.String())
				}
			default:
				switch mode {
				case "urgent":
					used := 100.0
					report.Accounts[0].Windows[0].UsedPercent = &used
					quota.Evaluate(&report.Accounts[0], at)
				case "unknown effort":
					report.Accounts[0].Harness.Effort = ""
				case "endpoint":
					report.Accounts[0].Harness.Endpoint = "https://example.test"
				case "history off":
					t.Setenv("MODELPLAN_HISTORY", "off")
				case "other plan":
					report.Accounts[0].Plan = "other"
				case "no history":
					if err := os.Remove(history.Path(st.Dir)); err != nil {
						t.Fatal(err)
					}
				}
				if hint := statuslineHint(style, st, d, report, at, true); strings.Contains(hint, "default:") {
					t.Fatalf("silent path rendered notice: %q", hint)
				}
			}
			if _, err := os.Stat(history.EffortSuggestionPath(st.Dir)); !os.IsNotExist(err) {
				t.Fatal("silent path consumed notice", err)
			}
		})
	}
}

func TestEffortSuggestionFullStatusline(t *testing.T) {
	for _, lang := range []string{"en", "zh"} {
		t.Run(lang, func(t *testing.T) {
			at := time.Now()
			st, _ := claudeEffortFixture(t, at)
			// Real status-line cycles have no plan label; do not invent one.
			l := contracttest.EffortLedger(at, "medium", false, 40, 45, 50)
			for i := range l.Cycles {
				l.Cycles[i].Source, l.Cycles[i].Plan = "claude-code", ""
			}
			if err := os.WriteFile(history.Path(st.Dir), publicationJSON(t, l), 0600); err != nil {
				t.Fatal(err)
			}
			input := `{"model":{"id":"native-z"},"rate_limits":{"seven_day":{"used_percentage":20,"resets_at":` + fmt.Sprint(at.Add(6*24*time.Hour).Unix()) + `}}}`
			// The current default is provided explicitly by the status-line flag.
			needle := "default: 3wk 45% ★Med→High ref ×1.50"
			if lang == "zh" {
				needle = "默认：3周 45% ★Med→High 参考 ×1.50"
			}
			for i := 0; i < 2; i++ {
				var out, stderr bytes.Buffer
				code := run([]string{"statusline", "--effort", "medium", "--offline", "--lang", lang}, strings.NewReader(input), &out, &stderr)
				if code != 0 || strings.Contains(out.String(), needle) != (i == 0) {
					t.Fatal(code, out.String(), stderr.String())
				}
			}
			if history.NotifyEffortSuggestion(st.Dir, mustEffortDigest(t), at.Add(time.Hour)) != nil {
				t.Fatal("full status line did not persist claim")
			}
		})
	}
}

func TestEffortSuggestionUnknownPlanMatchesOnlyUnlabelledCycles(t *testing.T) {
	for _, path := range []string{"helper", "statusline-command"} {
		for _, unlabelled := range []bool{false, true} {
			scope := "labelled-only"
			if unlabelled {
				scope = "eligible-unlabelled-with-unrelated-labelled"
			}
			for _, lang := range []string{"en", "zh"} {
				t.Run(path+"/"+scope+"/"+lang, func(t *testing.T) {
					at := time.Now()
					st, report := claudeEffortFixture(t, at)
					// Real status-line accounts have no plan label. This must be
					// a distinct pool, including when labelled cycles coexist.
					report.Accounts[0].Plan = ""
					if unlabelled {
						l := history.Load(st.Dir)
						cycles := contracttest.EffortLedger(at, "medium", false, 40, 45, 50).Cycles
						for i := range cycles {
							cycles[i].Source, cycles[i].Plan = "claude-code", ""
						}
						l.Cycles = append(l.Cycles, cycles...)
						if err := os.WriteFile(history.Path(st.Dir), publicationJSON(t, l), 0600); err != nil {
							t.Fatal(err)
						}
					}
					d := mustEffortDigest(t)
					style := render.Style{T: render.EN}
					marker, needle := "default:", "default: 3wk 45% ★Med→High ref ×1.50"
					if lang == "zh" {
						style.T = render.ZH
						marker, needle = "默认：", "默认：3周 45% ★Med→High 参考 ×1.50"
					}
					input := `{"model":{"id":"native-z"},"rate_limits":{"seven_day":{"used_percentage":20,"resets_at":` + fmt.Sprint(at.Add(6*24*time.Hour).Unix()) + `}}}`
					var claimed []byte
					for attempt := 0; attempt < 2; attempt++ {
						var output string
						if path == "helper" {
							output = defaultEffortHint(style, st, d, report, at.Add(time.Duration(attempt)*time.Minute))
						} else {
							var out, stderr bytes.Buffer
							if code := run([]string{"statusline", "--effort", "medium", "--offline", "--lang", lang}, strings.NewReader(input), &out, &stderr); code != 0 {
								t.Fatal(code, out.String(), stderr.String())
							}
							output = out.String()
						}
						wantHint := unlabelled && attempt == 0
						if strings.Contains(output, marker) != wantHint || (wantHint && !strings.Contains(output, needle)) {
							t.Fatalf("wrong unknown-plan hint on attempt %d: %q", attempt, output)
						}
						stamp, err := os.ReadFile(history.EffortSuggestionPath(st.Dir))
						if !unlabelled {
							if !os.IsNotExist(err) {
								t.Fatal("labelled-only history consumed unknown-plan notice", err)
							}
						} else {
							if err != nil {
								t.Fatal("eligible unlabelled history did not claim notice", err)
							}
							if attempt == 0 {
								claimed = stamp
							} else if !bytes.Equal(stamp, claimed) {
								t.Fatal("second attempt changed the shared weekly stamp")
							}
						}
					}
					// Other user-facing paths retain the notice when the current
					// pool is ineligible, and share its claim after a valid hint.
					wantNotice := !unlabelled
					if got := history.NotifyEffortSuggestion(st.Dir, d, at.Add(time.Hour)); (got != nil) != wantNotice {
						t.Fatal("wrong shared notice eligibility after status-line attempts", got)
					}
				})
			}
		}
	}
}
