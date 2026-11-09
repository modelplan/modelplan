// SPDX-License-Identifier: MIT
package appserver

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

const readerKeyFake = "fake-appserver-key-0005"

func callReaderKey(t *testing.T, h map[string]Handler, method, body string) (ReaderKeyResult, string, error) {
	t.Helper()
	reply, err := h[method].Handle(context.Background(), json.RawMessage(body), Stamp{})
	if err != nil {
		return ReaderKeyResult{}, "", err
	}
	out, _ := json.Marshal(reply.Data)
	return reply.Data.(ReaderKeyResult), string(out), nil
}

func TestReaderKeySetRemoveAndNeverEchoTheKey(t *testing.T) {
	dir := t.TempDir()
	h := ReaderKeyHandlers(ReaderKeyConfig{Dir: dir})
	r, out, err := callReaderKey(t, h, "readerkey/set", `{"provider":"zai","region":"china","key":"`+readerKeyFake+`"}`)
	if err != nil || r.Outcome != "saved" || !r.Present || r.Region != "china" || r.Provider != "zai" {
		t.Fatalf("set = %+v %v", r, err)
	}
	if strings.Contains(out, readerKeyFake) {
		t.Fatal("the result carries the key")
	}
	if fi, err := os.Stat(quota.ManualKeyPath(dir)); err != nil || fi.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %v %v", fi, err)
	}
	r, _, _ = callReaderKey(t, h, "readerkey/set", `{"provider":"zai","key":"bad key"}`)
	if r.Outcome != quota.ManualKeyNotAccepted || !r.Present {
		t.Fatalf("a rejected key must leave the stored one alone: %+v", r)
	}
	r, _, _ = callReaderKey(t, h, "readerkey/remove", `{"provider":"zai"}`)
	if r.Outcome != "removed" || r.Present {
		t.Fatalf("remove = %+v", r)
	}
	if _, err := os.Stat(quota.ManualKeyPath(dir)); !os.IsNotExist(err) {
		t.Fatal("file must be gone")
	}
}

func TestReaderKeyRejectsUnknownProviderAndFields(t *testing.T) {
	h := ReaderKeyHandlers(ReaderKeyConfig{Dir: t.TempDir()})
	for _, body := range []string{`{"provider":"cursor","key":"x"}`, `{"provider":"zai","url":"https://relay.example.test"}`, `null`} {
		_, _, err := callReaderKey(t, h, "readerkey/set", body)
		var pe ProtocolError
		if !errors.As(err, &pe) || pe.Code != wire.CodeInvalidParams {
			t.Fatalf("%s: err = %v", body, err)
		}
	}
}

func TestReaderKeyReadOnlyAndOffline(t *testing.T) {
	dir := t.TempDir()
	h := ReaderKeyHandlers(ReaderKeyConfig{Dir: dir, ReadOnly: true, Offline: true})
	if r, _, _ := callReaderKey(t, h, "readerkey/set", `{"provider":"zai","key":"`+readerKeyFake+`"}`); r.Present {
		t.Fatal("read-only must not write")
	}
	if r, _, _ := callReaderKey(t, h, "readerkey/test", `{"provider":"zai","key":"`+readerKeyFake+`"}`); r.Outcome != quota.ManualKeyUnreachable {
		t.Fatalf("offline test = %+v", r)
	}
}

func TestReaderKeyParamsRedactEverywhere(t *testing.T) {
	var p ReaderKeyParams
	if err := json.Unmarshal([]byte(`{"provider":"zai","key":"`+readerKeyFake+`"}`), &p); err != nil {
		t.Fatal(err)
	}
	var buf bytes.Buffer
	slog.New(slog.NewTextHandler(&buf, nil)).Info("call", "params", p, "key", p.Key)
	for _, s := range []string{fmt.Sprint(p), fmt.Sprintf("%+v", p), fmt.Sprintf("%#v", p), fmt.Sprintf("%v", p.Key), buf.String()} {
		if strings.Contains(s, readerKeyFake) {
			t.Fatalf("leak: %s", s)
		}
	}
}
