// SPDX-License-Identifier: MIT
package queries

import (
	"bytes"
	"encoding/base64"
	"errors"
	"reflect"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

func cursorFixture() cursorBinding {
	return cursorBinding{Session: "session-one", Stamp: appserver.Stamp{Epoch: "epoch-one", Generation: 41}, Scopes: []string{"claude.local_history", "codex.local_history"}, Account: "0123456789abcdef", Tool: "claude", Kind: wire.HistoryTokens}
}

func staleCursor(t *testing.T, next string, err error) {
	t.Helper()
	var protocol appserver.ProtocolError
	if next != "" || !errors.As(err, &protocol) || protocol.Code != wire.CodeCursorStale {
		t.Fatalf("cursor returned data or a non-stale error: %q, %v", next, err)
	}
}

// Red line: a cursor cannot authorize another session, scope, identity or consent
// context. Failing example: base64 of an offset accepted without a binding.
func TestCursorRedLineSessionScopeAccountFence(t *testing.T) {
	codec, err := newCursorCodec()
	if err != nil {
		t.Fatal(err)
	}
	original := cursorFixture()
	token, err := codec.encode(original, "synthetic-position")
	if err != nil {
		t.Fatal(err)
	}
	for name, change := range map[string]func(*cursorBinding){
		"session":    func(b *cursorBinding) { b.Session = "session-two" },
		"epoch":      func(b *cursorBinding) { b.Stamp.Epoch = "epoch-two" },
		"generation": func(b *cursorBinding) { b.Stamp.Generation++ },
		"account":    func(b *cursorBinding) { b.Account = "fedcba9876543210" },
		"scope":      func(b *cursorBinding) { b.Scopes = []string{"claude.account_usage.saved_login"} },
		"tool":       func(b *cursorBinding) { b.Tool = "codex" },
		"kind":       func(b *cursorBinding) { b.Kind = wire.HistorySessions },
	} {
		t.Run(name, func(t *testing.T) {
			binding := cursorFixture()
			change(&binding)
			next, err := codec.decode(binding, token)
			staleCursor(t, next, err)
		})
	}
	reordered := cursorFixture()
	reordered.Scopes = []string{"codex.local_history", "claude.local_history"}
	next, err := codec.decode(reordered, token)
	if err != nil || next != "synthetic-position" {
		t.Fatalf("scope-set ordering changed the binding: %q %v", next, err)
	}
	if !reflect.DeepEqual(original.Scopes, []string{"claude.local_history", "codex.local_history"}) {
		t.Fatal("binding mutated")
	}
}

func TestCursorOpaqueTamperBoundsAndFreshKey(t *testing.T) {
	codec, err := newCursorCodec()
	if err != nil {
		t.Fatal(err)
	}
	binding := cursorFixture()
	const position = "synthetic-private-history-position"
	token, err := codec.encode(binding, position)
	if err != nil {
		t.Fatal(err)
	}
	raw, err := base64.RawURLEncoding.DecodeString(strings.TrimPrefix(token, "c1."))
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(raw, []byte(position)) || bytes.Contains(raw, []byte(binding.Account)) {
		t.Error("cursor disclosed its payload")
	}
	second, err := codec.encode(binding, position)
	if err != nil {
		t.Fatal(err)
	}
	if second == token {
		t.Error("cursor reused a nonce")
	}
	other, err := newCursorCodec()
	if err != nil {
		t.Fatal(err)
	}
	next, err := other.decode(binding, token)
	staleCursor(t, next, err)
	raw[len(raw)-1] ^= 1
	next, err = codec.decode(binding, "c1."+base64.RawURLEncoding.EncodeToString(raw))
	staleCursor(t, next, err)
	for _, bad := range []string{"", "c2." + token[3:], "c1.??", "c1.YQ", strings.Repeat("x", 8193)} {
		next, err := codec.decode(binding, bad)
		staleCursor(t, next, err)
	}
	if _, err := codec.encode(binding, strings.Repeat("x", 4097)); err == nil {
		t.Error("unbounded page position")
	}
}

func TestCursorRejectsAmbiguousAdmission(t *testing.T) {
	codec, err := newCursorCodec()
	if err != nil {
		t.Fatal(err)
	}
	for _, change := range []func(*cursorBinding){
		func(b *cursorBinding) { b.Session = "" }, func(b *cursorBinding) { b.Stamp.Epoch = "" },
		func(b *cursorBinding) { b.Scopes = nil }, func(b *cursorBinding) { b.Scopes = []string{""} },
		func(b *cursorBinding) { b.Scopes = []string{"claude.local_history", "claude.local_history"} },
		func(b *cursorBinding) { b.Tool = "" }, func(b *cursorBinding) { b.Kind = "unknown" },
	} {
		binding := cursorFixture()
		change(&binding)
		if _, err := codec.encode(binding, "position"); err == nil {
			t.Errorf("ambiguous admission accepted: %+v", binding)
		}
	}
}
