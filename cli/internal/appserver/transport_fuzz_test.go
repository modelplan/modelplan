// SPDX-License-Identifier: MIT
package appserver

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"
	"unicode/utf8"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// Read the producer-owned Go captures in place; do not fork a wire fixture schema.
func transportCapture(tb testing.TB, name string) []byte {
	tb.Helper()
	_, source, _, _ := runtime.Caller(0)
	data, err := os.ReadFile(filepath.Join(filepath.Dir(source), "../../../schema/app-cli/captures", name+".json"))
	if err != nil {
		tb.Fatal(err)
	}
	var compact bytes.Buffer
	if err := json.Compact(&compact, data); err != nil {
		tb.Fatal(err)
	}
	return compact.Bytes()
}

type fragmentedFuzzReader struct {
	data  []byte
	chunk int
}

func (r *fragmentedFuzzReader) Read(p []byte) (int, error) {
	if len(r.data) == 0 {
		return 0, io.EOF
	}
	n := min(len(p), len(r.data), r.chunk)
	copy(p, r.data[:n])
	r.data = r.data[n:]
	return n, nil
}

func FuzzReadFrame(f *testing.F) {
	for _, name := range []string{"WireRequest", "WireSuccess", "WireNotification", "WireFailure", "production-rows"} {
		f.Add(append(transportCapture(f, name), '\n'), uint16(4096), uint8(0))
	}
	for _, data := range [][]byte{nil, []byte("{}"), []byte("{}\n{}\n"), {0xff, '\n'}, {0xc3, 0x28, '\n'}} {
		f.Add(data, uint16(16), uint8(0))
	}
	// Compact boundary seeds expand in the harness, avoiding multi-MiB corpus files.
	for mode := uint8(1); mode <= 6; mode++ {
		f.Add([]byte("x"), uint16(32768), mode)
	}
	f.Fuzz(func(t *testing.T, data []byte, size uint16, mode uint8) {
		if len(data) > 1<<20 {
			return
		}
		switch mode % 7 {
		case 1, 2, 3, 4, 5, 6:
			length := wire.MaxFrameBytes + int(mode%7) - 4
			fill := byte('x')
			if len(data) > 0 && data[0]&1 != 0 {
				fill = 0xff
			}
			data = bytes.Repeat([]byte{fill}, length)
			if mode%2 == 1 {
				data = append(data, '\n')
			}
		}
		// A short reader and varying bufio sizes exercise ReadSlice and cap fallback.
		chunk := 1 + int(size)%8192
		reader := bufio.NewReaderSize(&fragmentedFuzzReader{data: data, chunk: chunk}, 16+int(size))
		remaining := data
		for {
			frame, err := readFrame(reader)
			newline := bytes.IndexByte(remaining, '\n')
			switch {
			case len(remaining) == 0:
				if !errors.Is(err, io.EOF) || frame != nil {
					t.Fatal("empty stream did not finish at EOF")
				}
				return
			case newline < 0 || newline+1 > wire.MaxFrameBytes || !utf8.Valid(remaining[:newline]):
				if err == nil || frame != nil {
					t.Fatal("invalid/unterminated frame was accepted")
				}
				return
			default:
				if err != nil || !bytes.Equal(frame, remaining[:newline]) {
					t.Fatal("valid frame changed or was rejected")
				}
				if len(frame)+1 > wire.MaxFrameBytes || cap(frame) > wire.MaxFrameBytes {
					t.Fatal("frame backing storage exceeded cap")
				}
				remaining = remaining[newline+1:]
			}
		}
	})
}

func FuzzDecodeRequest(f *testing.F) {
	f.Add(transportCapture(f, "WireRequest"))
	for _, entry := range []struct{ method, capture string }{
		{"initialize", "WireInitializeParams"}, {"consent/grant", "WireConsentGrantParams"},
		{"history/query", "WireHistoryQueryParams"}, {"credentials/result", "WireCredentialResult"}, {"$/cancel", "WireCancelParams"},
	} {
		data, err := json.Marshal(wire.Request{JSONRPC: wire.JSONRPC, ID: wire.ID(`9007199254740993`), Method: entry.method, Params: transportCapture(f, entry.capture)})
		if err != nil {
			f.Fatal(err)
		}
		f.Add(data)
	}
	for _, data := range []string{`{}`, `[]`, `{"jsonrpc":"2.0","id":1,"id":2,"method":"consent/grant"}`, `{"jsonrpc":"2.0","id":18446744073709551615,"method":"rows/subscribe"}`, `{"jsonrpc":"2.0","id":"a\\u0062","method":"rows/subscribe"}`, `{"jsonrpc":"2.0","method":"shutdown"} {}`} {
		f.Add([]byte(data))
	}
	f.Fuzz(func(t *testing.T, data []byte) {
		if len(data) > 1<<20 {
			return
		}
		request, err := decodeRequest(data)
		if err != nil {
			return
		}
		if !json.Valid(data) || request.JSONRPC != wire.JSONRPC || request.Method == "" {
			t.Fatal("accepted invalid JSON-RPC request")
		}
		if len(request.ID) > 0 && !validID(request.ID) {
			t.Fatal("accepted invalid identifier")
		}
		encoded, err := json.Marshal(request)
		if err != nil {
			t.Fatal("accepted request could not be encoded")
		}
		again, err := decodeRequest(encoded)
		if err != nil || requestKey(request.ID) != requestKey(again.ID) || request.Method != again.Method {
			t.Fatal("request round trip changed exact identity")
		}
		// Exercise the actual strict parameter decoders too, without executing methods.
		_, _ = params[wire.InitializeParams](request.Params)
		_, _ = params[wire.ConsentGrantParams](request.Params)
		_, _ = params[wire.HistoryQueryParams](request.Params)
		_, _ = params[wire.CredentialResult](request.Params)
		_, _ = params[wire.CancelParams](request.Params)
	})
}

func FuzzEnvelopeSession(f *testing.F) {
	var captured wire.Envelope[json.RawMessage]
	if err := json.Unmarshal(transportCapture(f, "WireEnvelope"), &captured); err != nil {
		f.Fatal(err)
	}
	for _, name := range []string{"WireEnvelope", "WireSuccess", "WireNotification", "WireFailure", "WireInitializeParams"} {
		f.Add(transportCapture(f, name), captured.SessionID, uint64(7))
	}
	f.Add([]byte(`{}`), "other-session", ^uint64(0))
	f.Add([]byte(`null`), "\xff", uint64(0))
	f.Fuzz(func(t *testing.T, data []byte, candidate string, generation uint64) {
		if len(data) > 64<<10 || len(candidate) > 1024 {
			return
		}
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		server := New(Config{})
		server.ctx = ctx
		server.stop = cancel
		server.initialized = true
		server.session = captured.SessionID
		server.view.Stamp = Stamp{Epoch: captured.StoreEpoch, Generation: captured.ConsentGeneration}
		server.out = newOutbound(ctx, cancel, nil, time.Second, nil)
		id := wire.ID(`9007199254740993`)
		for _, raw := range [][]byte{data, func() []byte {
			b, _ := json.Marshal(wire.InitializeParams{SessionID: candidate, ProtocolVersion: "1.0", AppVersion: "fuzz", Capabilities: []string{}})
			return b
		}()} {
			server.initialize(wire.Request{JSONRPC: wire.JSONRPC, ID: id, Method: "initialize", Params: raw})
			message, ok := server.out.next()
			if !ok {
				t.Fatal("re-initialization had no terminal error")
			}
			var failure wire.Failure
			if json.Unmarshal(message.bytes, &failure) != nil || failure.Error.Data.SessionID != captured.SessionID || !bytes.Equal(failure.ID, id) {
				t.Fatal("re-initialization escaped session/ID fence")
			}
			switch failure.Error.Code {
			case wire.CodeInvalidParams, wire.CodeInvalidRequest, wire.CodeWrongSession:
			default:
				t.Fatal("re-initialization produced a success or unrelated error")
			}
			if server.session != captured.SessionID || server.view.Stamp.Generation != captured.ConsentGeneration {
				t.Fatal("re-initialization changed active context")
			}
		}
		var input wire.Envelope[json.RawMessage]
		if json.Unmarshal(data, &input) != nil {
			return
		}
		stamp := Stamp{Epoch: input.StoreEpoch, Generation: generation}
		if server.isCurrent(stamp) && stamp != server.view.Stamp {
			t.Fatal("foreign epoch/generation admitted")
		}
		session := candidate
		if !validSession(session) {
			session = captured.SessionID
		}
		encoded, err := encode(success(session, id, stamp, input.Scopes, input.Data), stamp, true)
		if err != nil {
			return
		}
		if len(encoded.bytes) > wire.MaxFrameBytes || encoded.bytes[len(encoded.bytes)-1] != '\n' {
			t.Fatal("outbound envelope escaped frame cap")
		}
		var result wire.Success[json.RawMessage]
		if json.Unmarshal(encoded.bytes, &result) != nil || result.Result.SessionID != session || result.Result.StoreEpoch != stamp.Epoch || result.Result.ConsentGeneration != generation {
			t.Fatal("envelope context changed in round trip")
		}
	})
}
