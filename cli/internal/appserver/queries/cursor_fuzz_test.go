// SPDX-License-Identifier: MIT
package queries

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

func FuzzHistoryCursor(f *testing.F) {
	_, source, _, _ := runtime.Caller(0)
	capture := func(name string) []byte {
		b, err := os.ReadFile(filepath.Join(filepath.Dir(source), "../../../../schema/app-cli/captures", name+".json"))
		if err != nil {
			f.Fatal(err)
		}
		return b
	}
	var envelope wire.Envelope[json.RawMessage]
	if err := json.Unmarshal(capture("WireEnvelope"), &envelope); err != nil {
		f.Fatal(err)
	}
	var query wire.HistoryQueryParams
	if err := json.Unmarshal(capture("WireHistoryQueryParams"), &query); err != nil {
		f.Fatal(err)
	}
	binding := cursorBinding{Session: envelope.SessionID, Stamp: appserver.Stamp{Epoch: envelope.StoreEpoch, Generation: envelope.ConsentGeneration}, Scopes: envelope.Scopes, Account: query.Ref, Tool: query.Tool, Kind: query.Kind}
	codec, err := newCursorCodec()
	if err != nil {
		f.Fatal(err)
	}
	other, err := newCursorCodec()
	if err != nil {
		f.Fatal(err)
	}
	token, err := codec.encode(binding, "synthetic-position")
	if err != nil {
		f.Fatal(err)
	}
	bindingSeed, err := json.Marshal(binding)
	if err != nil {
		f.Fatal(err)
	}
	f.Add(bindingSeed, token)
	for _, name := range []string{"WireHistoryQueryParams", "WireHistoryPage", "WireEnvelope"} {
		f.Add(capture(name), token)
	}
	for _, s := range []string{"", "next", "c1.", "c1.YQ", "c1.??", "c1.abc\n", strings.Repeat("x", 4097)} {
		f.Add([]byte(s), s)
	}
	f.Fuzz(func(t *testing.T, data []byte, rawToken string) {
		if len(data) > 16<<10 || len(rawToken) > 16<<10 {
			return
		}
		stale := func(next string, err error) {
			t.Helper()
			var p appserver.ProtocolError
			if next != "" || !errors.As(err, &p) || p.Code != wire.CodeCursorStale {
				t.Fatal("invalid cursor returned data or non-stale failure")
			}
		}
		next, err := codec.decode(binding, rawToken)
		if err != nil {
			stale(next, err)
		} else {
			if len(next) == 0 || len(next) > 4096 {
				t.Fatal("unbounded decoded page position")
			}
			foreign := binding
			foreign.Session += "-other"
			stale(codec.decode(foreign, rawToken))
		}
		var arbitrary cursorBinding
		if json.Unmarshal(data, &arbitrary) == nil {
			originalScopes := append([]string(nil), arbitrary.Scopes...)
			bound, err := codec.encode(arbitrary, "page")
			if err == nil {
				value, err := codec.decode(arbitrary, bound)
				if err != nil || value != "page" {
					t.Fatal("admitted binding did not round trip")
				}
				stale(other.decode(arbitrary, bound))
			}
			if !slices.Equal(originalScopes, arbitrary.Scopes) {
				t.Fatal("codec changed caller's scope ordering")
			}
		}
		encoded, err := codec.encode(binding, string(data))
		if len(data) == 0 || len(data) > 4096 {
			if err == nil {
				t.Fatal("unbounded position encoded")
			}
			return
		}
		if err != nil {
			t.Fatal(err)
		}
		decoded, err := codec.decode(binding, encoded)
		if err != nil || decoded != string(data) {
			t.Fatal("position round trip changed bytes")
		}
		if len(encoded) > 8192 {
			t.Fatal("cursor exceeds wire bound")
		}
		stale(other.decode(binding, encoded))
		changed := binding
		changed.Scopes = append([]string(nil), binding.Scopes...)
		var selector byte
		if len(data) > 0 {
			selector = data[0]
		}
		switch selector % 7 {
		case 0:
			changed.Session += "-other"
		case 1:
			changed.Stamp.Epoch += "-other"
		case 2:
			changed.Stamp.Generation++
		case 3:
			changed.Account += "-other"
		case 4:
			changed.Scopes = append(changed.Scopes, "different.scope")
		case 5:
			changed.Tool += "-other"
		case 6:
			changed.Kind = wire.HistoryKind("different")
		}
		stale(codec.decode(changed, encoded))
		tampered := []byte(encoded)
		if tampered[len(tampered)-1] == 'A' {
			tampered[len(tampered)-1] = 'B'
		} else {
			tampered[len(tampered)-1] = 'A'
		}
		stale(codec.decode(binding, string(tampered)))
	})
}
