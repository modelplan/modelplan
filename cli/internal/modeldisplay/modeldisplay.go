// SPDX-License-Identifier: MIT

// Package modeldisplay turns a raw model ID that the verified publication does not list into a readable name
// (G3-134). It is the one raw-to-display function: the session strip and the faders both read it, so an unlisted
// model never gets two spellings. It only shapes a name that already looks like a model ID; anything else is
// refused, so a key, a path or free text never reaches a screen.
package modeldisplay

import (
	"regexp"
	"strings"
)

var (
	safe    = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._:/@-]*$`)
	secret  = regexp.MustCompile(`(?i)(^|[-_./])(sk|key|token|secret|pk)([-_./]|$)`)
	numeric = regexp.MustCompile(`^[0-9]+(\.[0-9]+)*$`)
	stamp   = regexp.MustCompile(`^(20[0-9]{2}[0-9]{2}[0-9]{2}|[0-9]{6}|[0-9]{4}-[0-9]{2}-[0-9]{2})$`)
	lead    = regexp.MustCompile(`^(claude|gpt|openai|anthropic)$`)
)

// maxRaw bounds what is read; a longer name is not a model ID.
const maxRaw = 64

// MaxDisplay is the longest display name returned; the wire field carries the same bound (modelDisplay maxLength).
const MaxDisplay = 48

// Display returns the readable name of an unlisted raw model ID ("gpt-6.2-sol" reads "Sol 6.2", "claude-opus-5-6"
// reads "Opus 5.6") and whether the name was readable at all. The vendor lead word (Claude, GPT) is dropped and the
// version follows the name; other families keep their words in order ("gemini-3-pro" reads "Gemini 3 Pro").
func Display(raw string) (string, bool) {
	raw = strings.TrimSpace(raw)
	if raw == "" || len(raw) > maxRaw || !safe.MatchString(raw) || secret.MatchString(raw) || strings.EqualFold(raw, "unknown") {
		return "", false
	}
	if i := strings.LastIndex(raw, "/"); i >= 0 {
		raw = raw[i+1:]
	}
	var words, version []string
	vendor, at := false, -1
	for i, part := range strings.FieldsFunc(strings.ToLower(raw), func(r rune) bool { return r == '-' || r == '_' || r == ':' || r == '@' }) {
		switch {
		case part == "latest" || stamp.MatchString(part):
		case i == 0 && lead.MatchString(part):
			vendor = true
		case numeric.MatchString(part):
			if at < 0 {
				at = len(words)
			}
			version = append(version, part)
		default:
			words = append(words, strings.ToUpper(part[:1])+part[1:])
		}
	}
	if len(words) == 0 {
		return "", false
	}
	if len(version) == 0 {
		return bound(strings.Join(words, " ")), true
	}
	v := strings.Join(version, ".")
	// A vendor lead word or a leading version puts the version after the name; otherwise it stays where it was.
	if vendor || at == 0 {
		at = len(words)
	}
	return bound(strings.Join(append(append(append([]string{}, words[:at]...), v), words[at:]...), " ")), true
}

// bound cuts a name to MaxDisplay (the name is ASCII by construction) so the wire field is never refused for length.
func bound(name string) string {
	if len(name) <= MaxDisplay {
		return name
	}
	return strings.TrimRight(name[:MaxDisplay], " .")
}
