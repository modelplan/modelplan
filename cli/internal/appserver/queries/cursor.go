// SPDX-License-Identifier: MIT
package queries

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"io"
	"sort"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// The backend supplies the admitted scope set and resolved account locator.
// No consent, source path, credential or store is inferred by the cursor codec.
type cursorBinding struct {
	Session string
	Stamp   appserver.Stamp
	Scopes  []string
	Account string
	Tool    string
	Kind    wire.HistoryKind
}

// A new key belongs to one handler set. It stays in memory, so a restarted child
// rejects old cursors even if the caller repeats an earlier session identifier.
type cursorCodec struct{ aead cipher.AEAD }

func newCursorCodec() (*cursorCodec, error) {
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return nil, appserver.ProtocolError{Code: wire.CodeInternal}
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, appserver.ProtocolError{Code: wire.CodeInternal}
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, appserver.ProtocolError{Code: wire.CodeInternal}
	}
	return &cursorCodec{aead: aead}, nil
}

func cursorStale() error { return appserver.ProtocolError{Code: wire.CodeCursorStale} }

func (b cursorBinding) additionalData() ([]byte, error) {
	if b.Session == "" || b.Stamp.Epoch == "" || b.Tool == "" || len(b.Scopes) == 0 || len(b.Scopes) > 64 {
		return nil, cursorStale()
	}
	switch b.Kind {
	case wire.HistoryTokens, wire.HistoryQuotaCycles, wire.HistorySessions:
	default:
		return nil, cursorStale()
	}
	b.Scopes = append([]string(nil), b.Scopes...)
	sort.Strings(b.Scopes)
	for i, scope := range b.Scopes {
		if scope == "" || i > 0 && scope == b.Scopes[i-1] {
			return nil, cursorStale()
		}
	}
	data, err := json.Marshal(b)
	if err != nil || len(data) > 8192 {
		return nil, cursorStale()
	}
	return data, nil
}

func (c *cursorCodec) encode(binding cursorBinding, next string) (string, error) {
	if next == "" || len(next) > 4096 {
		return "", appserver.ProtocolError{Code: wire.CodeInternal}
	}
	aad, err := binding.additionalData()
	if err != nil {
		return "", err
	}
	nonce := make([]byte, c.aead.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", appserver.ProtocolError{Code: wire.CodeInternal}
	}
	sealed := c.aead.Seal(nonce, nonce, []byte(next), aad)
	return "c1." + base64.RawURLEncoding.EncodeToString(sealed), nil
}

func (c *cursorCodec) decode(binding cursorBinding, token string) (string, error) {
	if len(token) > 8192 || !strings.HasPrefix(token, "c1.") || strings.ContainsAny(token, "\r\n") {
		return "", cursorStale()
	}
	aad, err := binding.additionalData()
	if err != nil {
		return "", cursorStale()
	}
	raw, err := base64.RawURLEncoding.Strict().DecodeString(token[3:])
	if err != nil || len(raw) < c.aead.NonceSize()+c.aead.Overhead() {
		return "", cursorStale()
	}
	nonce, sealed := raw[:c.aead.NonceSize()], raw[c.aead.NonceSize():]
	next, err := c.aead.Open(nil, nonce, sealed, aad)
	if err != nil || len(next) == 0 || len(next) > 4096 {
		return "", cursorStale()
	}
	return string(next), nil
}
