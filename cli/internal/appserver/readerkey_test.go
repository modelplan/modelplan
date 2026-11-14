// SPDX-License-Identifier: MIT
package appserver

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"sync"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

const readerKeyFake = "fake-appserver-key-0005"

type ReaderKeyResult = wire.ReaderKeyResult

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
	if err != nil || r.Outcome != wire.ReaderKeySaved || !r.Present || r.Region != wire.ReaderKeyRegionChina || r.Provider != "zai" {
		t.Fatalf("set = %+v %v", r, err)
	}
	if strings.Contains(out, readerKeyFake) {
		t.Fatal("the result carries the key")
	}
	if fi, err := os.Stat(quota.ManualKeyPath(dir)); err != nil || fi.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %v %v", fi, err)
	}
	r, _, _ = callReaderKey(t, h, "readerkey/set", `{"provider":"zai","region":"global","key":"bad key"}`)
	if r.Outcome != wire.ReaderKeyNotAccepted || !r.Present {
		t.Fatalf("a rejected key must leave the stored one alone: %+v", r)
	}
	r, _, _ = callReaderKey(t, h, "readerkey/remove", `{"provider":"zai","region":"none","key":""}`)
	if r.Outcome != wire.ReaderKeyRemoved || r.Present {
		t.Fatalf("remove = %+v", r)
	}
	if _, err := os.Stat(quota.ManualKeyPath(dir)); !os.IsNotExist(err) {
		t.Fatal("file must be gone")
	}
}

func TestReaderKeyRejectsUnknownProviderAndFields(t *testing.T) {
	h := ReaderKeyHandlers(ReaderKeyConfig{Dir: t.TempDir()})
	for _, body := range []string{`{"provider":"cursor","region":"none","key":"x"}`, `{"provider":"zai","region":"none","key":"","url":"https://relay.example.test"}`, `null`} {
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
	if r, _, _ := callReaderKey(t, h, "readerkey/set", `{"provider":"zai","region":"global","key":"`+readerKeyFake+`"}`); r.Present {
		t.Fatal("read-only must not write")
	}
	if r, _, _ := callReaderKey(t, h, "readerkey/test", `{"provider":"zai","region":"global","key":"`+readerKeyFake+`"}`); r.Outcome != wire.ReaderKeyUnreachable {
		t.Fatalf("offline test = %+v", r)
	}
}

func TestReaderKeyParamsRedactEverywhere(t *testing.T) {
	var p wire.ReaderKeyParams
	if err := json.Unmarshal([]byte(`{"provider":"zai","region":"global","key":"`+readerKeyFake+`"}`), &p); err != nil {
		t.Fatal(err)
	}
	var buf bytes.Buffer
	slog.New(slog.NewTextHandler(&buf, nil)).Info("call", "params", p)
	for _, s := range []string{fmt.Sprint(p), fmt.Sprintf("%+v", p), fmt.Sprintf("%#v", p), buf.String()} {
		if strings.Contains(s, readerKeyFake) {
			t.Fatalf("leak: %s", s)
		}
	}
}

func TestReaderKeyStatusReportsPresenceWithoutAKey(t *testing.T) {
	dir := t.TempDir()
	h := ReaderKeyHandlers(ReaderKeyConfig{Dir: dir})
	r, _, err := callReaderKey(t, h, "readerkey/status", `{"provider":"zai","region":"none","key":""}`)
	if err != nil || r.Present || r.Region != wire.ReaderKeyRegionNone {
		t.Fatalf("empty status = %+v %v", r, err)
	}
	callReaderKey(t, h, "readerkey/set", `{"provider":"zai","region":"china","key":"`+readerKeyFake+`"}`)
	r, out, _ := callReaderKey(t, h, "readerkey/status", `{"provider":"zai","region":"none","key":""}`)
	if !r.Present || r.Region != wire.ReaderKeyRegionChina || strings.Contains(out, readerKeyFake) {
		t.Fatalf("status = %+v", r)
	}
}

// Owner decision 2026-11-14: status says when the entered key is in use and a different key was also detected
// (the flag on the last GLM reading), so Settings can show it on the row; no key is in the result.
func TestReaderKeyStatusReportsAnotherDetectedKey(t *testing.T) {
	dir := t.TempDir()
	h := ReaderKeyHandlers(ReaderKeyConfig{Dir: dir})
	callReaderKey(t, h, "readerkey/set", `{"provider":"zai","region":"china","key":"`+readerKeyFake+`"}`)
	if r, _, _ := callReaderKey(t, h, "readerkey/status", `{"provider":"zai","region":"none","key":""}`); r.OtherKeyFound {
		t.Fatal("no reading yet, no flag")
	}
	if err := os.MkdirAll(dir+"/observed", 0o700); err != nil {
		t.Fatal(err)
	}
	snap := `{"schemaVersion":1,"providers":[{"provider":"zai","status":"ok","otherKeyFound":true,"observedAt":"2026-11-14T00:00:00Z"}]}`
	if err := os.WriteFile(dir+"/observed/native.json", []byte(snap), 0o600); err != nil {
		t.Fatal(err)
	}
	r, out, _ := callReaderKey(t, h, "readerkey/status", `{"provider":"zai","region":"none","key":""}`)
	if !r.OtherKeyFound || !strings.Contains(out, `"otherKeyFound":true`) || strings.Contains(out, readerKeyFake) {
		t.Fatalf("status = %s", out)
	}
	if r, _, _ := callReaderKey(t, h, "readerkey/status", `{"provider":"opencodego","region":"none","key":""}`); r.OtherKeyFound {
		t.Fatal("another provider is not flagged")
	}
}

func TestReaderKeySetAndRemoveRefuseAnUnsafeKeyFile(t *testing.T) {
	dir := t.TempDir()
	if err := quota.SetManualKey(dir, "opencodego", "fake-other-provider-key-1", ""); err != nil {
		t.Fatal(err)
	}
	h := ReaderKeyHandlers(ReaderKeyConfig{Dir: dir})
	path := quota.ManualKeyPath(dir)
	for _, mode := range []string{"loose", "garbage"} {
		if mode == "loose" {
			if err := os.Chmod(path, 0o644); err != nil {
				t.Fatal(err)
			}
		} else {
			if err := os.Chmod(path, 0o600); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(path, []byte("not json"), 0o600); err != nil {
				t.Fatal(err)
			}
		}
		before, _ := os.ReadFile(path)
		set, setJSON, err := callReaderKey(t, h, "readerkey/set", `{"provider":"zai","region":"global","key":"`+readerKeyFake+`"}`)
		if err != nil || set.Outcome != wire.ReaderKeyFileUnsafe {
			t.Fatalf("%s set = %v %v", mode, set.Outcome, err)
		}
		rem, _, err := callReaderKey(t, h, "readerkey/remove", `{"provider":"opencodego","region":"none","key":""}`)
		if err != nil || rem.Outcome != wire.ReaderKeyFileUnsafe {
			t.Fatalf("%s remove = %v %v", mode, rem.Outcome, err)
		}
		after, _ := os.ReadFile(path)
		if !bytes.Equal(before, after) {
			t.Fatalf("%s: the unsafe file was rewritten", mode)
		}
		if strings.Contains(setJSON, readerKeyFake) {
			t.Fatal("key echoed")
		}
	}
}

// Each mode refuses on its own (the app-server passes them independently): no write, no delete, no outbound request.
func TestReaderKeyEachModeRefusesWithoutAnyEffect(t *testing.T) {
	for _, cfg := range []ReaderKeyConfig{{ReadOnly: true}, {Offline: true}} {
		dir := t.TempDir()
		requests := 0
		cfg.Dir = dir
		cfg.Client = &http.Client{Transport: roundTripFunc(func(*http.Request) (*http.Response, error) { requests++; return nil, errors.New("no network") })}
		h := ReaderKeyHandlers(cfg)
		if r, _, _ := callReaderKey(t, h, "readerkey/set", `{"provider":"zai","region":"global","key":"`+readerKeyFake+`"}`); r.Outcome != wire.ReaderKeyFailed || r.Present {
			t.Fatalf("%+v set = %+v", cfg, r)
		}
		if _, err := os.Stat(quota.ManualKeyPath(dir)); err == nil {
			t.Fatalf("%+v: set wrote the file", cfg)
		}
		if err := quota.SetManualKey(dir, "zai", readerKeyFake, "global"); err != nil {
			t.Fatal(err)
		}
		if r, _, _ := callReaderKey(t, h, "readerkey/remove", `{"provider":"zai","region":"none","key":""}`); r.Outcome != wire.ReaderKeyFailed || !r.Present {
			t.Fatalf("%+v remove = %+v", cfg, r)
		}
		if r, _, _ := callReaderKey(t, h, "readerkey/test", `{"provider":"zai","region":"global","key":"`+readerKeyFake+`"}`); r.Outcome != wire.ReaderKeyUnreachable {
			t.Fatalf("%+v test = %+v", cfg, r)
		}
		if r, _, _ := callReaderKey(t, h, "readerkey/test", `{"provider":"zai","region":"none","key":""}`); r.Outcome != wire.ReaderKeyUnreachable {
			t.Fatalf("%+v stored test = %+v", cfg, r)
		}
		if requests != 0 {
			t.Fatalf("%+v: %d outbound requests", cfg, requests)
		}
	}
}

// Two providers saved at the same time both survive (the whole read-modify-replace is one transaction).
func TestReaderKeyConcurrentSavesKeepEveryProvider(t *testing.T) {
	for i := 0; i < 30; i++ {
		dir := t.TempDir()
		h := ReaderKeyHandlers(ReaderKeyConfig{Dir: dir})
		var wg sync.WaitGroup
		for _, body := range []string{`{"provider":"zai","region":"global","key":"` + readerKeyFake + `"}`, `{"provider":"opencodego","region":"none","key":"` + readerKeyFake + `2"}`} {
			wg.Add(1)
			go func(body string) {
				defer wg.Done()
				method := "readerkey/set"
				h[method].Handle(context.Background(), json.RawMessage(body), Stamp{})
			}(body)
		}
		wg.Wait()
		if !quota.ManualKeyPresent(dir, "zai") || !quota.ManualKeyPresent(dir, "opencodego") {
			t.Fatalf("iteration %d: a concurrent save was lost (zai=%v opencodego=%v)", i, quota.ManualKeyPresent(dir, "zai"), quota.ManualKeyPresent(dir, "opencodego"))
		}
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
