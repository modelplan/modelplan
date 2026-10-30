// SPDX-License-Identifier: MIT
package diagnostics

import (
	"encoding/xml"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"runtime"
	"sort"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Feedback contains only compiled names, constrained versions and fixed codes.
// It intentionally contains no raw status, identifier, path or vendor message.
type Feedback struct {
	SchemaVersion   int      `json:"schemaVersion"`
	AppVersion      string   `json:"appVersion"`
	CLIVersion      string   `json:"cliVersion"`
	OS              string   `json:"os"`
	OSVersion       string   `json:"osVersion"`
	OSVersionSource string   `json:"osVersionSource"`
	Arch            string   `json:"arch"`
	ReaderMode      string   `json:"readerMode"`
	EnabledScopes   []string `json:"enabledScopes"`
	RecentErrors    []string `json:"recentErrors"`
}

var safeVersionRE = regexp.MustCompile(`^[vV]?[0-9]{1,6}(?:\.[0-9]{1,6}){1,3}(?:-(?:dev|alpha|beta|rc)(?:[.-]?[0-9]{1,6})?)?$`)
var safeOSVersionRE = regexp.MustCompile(`^[0-9]{1,6}(?:\.[0-9]{1,6}){0,3}$`)

func safeOSVersion(value string) string {
	if !safeOSVersionRE.MatchString(value) {
		return "unknown"
	}
	return value
}

var numericPrefixRE = regexp.MustCompile(`^[0-9]{1,6}(?:\.[0-9]{1,6}){1,3}`)

func numericVersionPrefix(value string) string { return numericPrefixRE.FindString(value) }
func safeVersion(value string) string {
	if !safeVersionRE.MatchString(value) {
		return "unknown"
	}
	return strings.TrimPrefix(strings.TrimPrefix(value, "v"), "V")
}

// CollectFeedback is cache-only. It never migrates consent, opens harness files,
// starts a reader or emits a path. The scope/error snapshot is discarded if the
// consent state changes during collection.
func CollectFeedback(cache, cliVersion, appVersion string, now time.Time) Feedback {
	if appVersion == "" {
		appVersion = bundleVersion()
	}
	osVersion, versionSource := hostOSVersion()
	result := Feedback{SchemaVersion: 1, AppVersion: safeVersion(appVersion), CLIVersion: safeVersion(cliVersion), OS: runtime.GOOS, OSVersion: safeOSVersion(osVersion), OSVersionSource: versionSource, Arch: runtime.GOARCH, ReaderMode: "unknown", EnabledScopes: []string{}, RecentErrors: []string{}}
	if result.OSVersion == "unknown" {
		result.OSVersionSource = "unknown"
	}
	for attempt := 0; attempt < 2; attempt++ {
		state, err := consent.ReadOnly(consent.Path())
		if err != nil {
			return result
		}
		mode := state.Effective(os.Getenv("MODELPLAN_READERS"))
		scopes := enabledScopes(state, mode)
		codes := recentErrorCodes(cache, scopes, now)
		current, err := consent.ReadOnly(consent.Path())
		if err == nil && reflect.DeepEqual(state, current) && mode == current.Effective(os.Getenv("MODELPLAN_READERS")) {
			result.ReaderMode, result.EnabledScopes, result.RecentErrors = mode, scopes, codes
			return result
		}
	}
	return result
}

// enabledScopes names scopes enabled by consent and compiled admission. This is
// not a claim that a tool is installed, configured, or was contacted.
func enabledScopes(state consent.State, mode string) []string {
	scopes := []string{}
	tools := map[string]bool{}
	admission := consent.NewAdmission(state, mode)
	for _, d := range consent.Definitions() {
		tools[d.Tool] = true
		pending, pendingPolicy := quota.PolicyPending(d.Tool)
		if !admission.CleanupPending(d.Tool) && !admission.CleanupPending(d.ID) && state.AllowsScope(d.ID, mode) && (!pendingPolicy || pending != d.ID) {
			scopes = append(scopes, d.ID)
		}
	}
	// Helper scopes are dynamic definitions but tool names come from the compiled
	// definitions, never from stored provider or account names.
	for tool := range tools {
		for _, browser := range []bool{false, true} {
			id := consent.HelperScope(tool, browser)
			if !admission.CleanupPending(tool) && !admission.CleanupPending(id) && state.AllowsScope(id, mode) {
				scopes = append(scopes, id)
			}
		}
	}
	sort.Strings(scopes)
	return scopes
}

type failureEvent struct {
	code string
	at   time.Time
}

func recentErrorCodes(cache string, scopes []string, now time.Time) []string {
	enabled := map[string]bool{}
	nativeTools := map[string]bool{}
	bridgeTools := map[string]bool{}
	for _, id := range scopes {
		enabled[id] = true
		d, ok := consent.Definition(id)
		if !ok {
			continue
		}
		if d.Class == consent.Bridge {
			bridgeTools[d.Tool] = true
		} else if d.Class != consent.Local {
			nativeTools[d.Tool] = true
		}
	}
	var events []failureEvent
	add := func(code string, at time.Time) {
		if at.IsZero() || at.After(now) || at.Before(now.Add(-7*24*time.Hour)) {
			return
		}
		events = append(events, failureEvent{quota.ReaderErrorCode(code), at})
	}
	if enabled[consent.ScopeCodexRuntimeUsage] {
		var s struct {
			SchemaVersion int `json:"schemaVersion"`
			Status, Error string
			ObservedAt    time.Time `json:"observedAt"`
		}
		if readJSON(cache, filepath.Join("observed", "codex-account.json"), &s) == "cached" && s.SchemaVersion == 1 && s.Status != "" && s.Status != "ok" {
			if s.Status == "binary_found_but_runtime_missing" {
				s.Error = "runtime_missing"
			}
			add(s.Error, s.ObservedAt)
		}
	}
	for _, item := range []struct {
		file  string
		tools map[string]bool
	}{{"native.json", nativeTools}, {"codexbar.json", bridgeTools}} {
		var s struct {
			SchemaVersion int `json:"schemaVersion"`
			Providers     []struct {
				Provider, Status, Error, ErrorCode string
				ObservedAt                         time.Time `json:"observedAt"`
			} `json:"providers"`
		}
		if readJSON(cache, filepath.Join("observed", item.file), &s) != "cached" || s.SchemaVersion != 1 {
			continue
		}
		for _, p := range s.Providers {
			if item.tools[p.Provider] && p.Status != "" && p.Status != "ok" && p.Status != "estimated" {
				code := p.ErrorCode
				if code == "" {
					code = p.Error
				}
				add(code, p.ObservedAt)
			}
		}
	}
	for tool := range nativeTools {
		var s struct {
			SchemaVersion int `json:"schemaVersion"`
			Entries       []struct {
				Status, ErrorCode string
				AttemptedAt       time.Time `json:"attemptedAt"`
				LastFailure       *struct {
					Code string    `json:"code"`
					At   time.Time `json:"at"`
				} `json:"lastFailure"`
			} `json:"entries"`
		}
		if readJSON(cache, filepath.Join("observed", "readers", tool+".json"), &s) != "cached" || s.SchemaVersion != 1 {
			continue
		}
		for _, entry := range s.Entries {
			if entry.LastFailure != nil {
				add(entry.LastFailure.Code, entry.LastFailure.At)
			} else if entry.Status != "" && entry.Status != "ok" {
				add(entry.ErrorCode, entry.AttemptedAt)
			}
		}
	}
	sort.Slice(events, func(i, j int) bool {
		if events[i].at.Equal(events[j].at) {
			return events[i].code < events[j].code
		}
		return events[i].at.After(events[j].at)
	})
	result := []string{}
	seen := map[string]bool{}
	for _, event := range events {
		if !seen[event.code] {
			result = append(result, event.code)
			seen[event.code] = true
			if len(result) == 8 {
				break
			}
		}
	}
	return result
}

// A bundled CLI can read its own enclosing app's version. Standalone installs
// report unknown. No path or other Info.plist field is returned.
func bundleVersion() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	dir := filepath.Dir(exe)
	if filepath.Base(dir) != "Helpers" && filepath.Base(dir) != "MacOS" {
		return ""
	}
	contents := filepath.Dir(dir)
	if filepath.Base(contents) != "Contents" || !strings.HasSuffix(filepath.Base(filepath.Dir(contents)), ".app") {
		return ""
	}
	return bundleVersionFile(filepath.Join(contents, "Info.plist"))
}
func bundleVersionFile(file string) string {
	info, err := os.Lstat(file)
	if err != nil || !info.Mode().IsRegular() || info.Size() > 64<<10 {
		return ""
	}
	f, err := os.Open(file)
	if err != nil {
		return ""
	}
	defer f.Close()
	d := xml.NewDecoder(io.LimitReader(f, 64<<10+1))
	key := ""
	fallback := ""
	for {
		tok, err := d.Token()
		if err != nil {
			break
		}
		start, ok := tok.(xml.StartElement)
		if !ok {
			continue
		}
		if start.Name.Local == "key" {
			if d.DecodeElement(&key, &start) != nil {
				return ""
			}
			continue
		}
		if start.Name.Local == "string" && (key == "CFBundleShortVersionString" || key == "CFBundleVersion") {
			var value string
			if d.DecodeElement(&value, &start) != nil {
				return ""
			}
			if key == "CFBundleShortVersionString" {
				return value
			}
			fallback = value
		}
		key = ""
	}
	return fallback
}
