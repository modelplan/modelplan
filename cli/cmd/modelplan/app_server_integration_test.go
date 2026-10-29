// SPDX-License-Identifier: MIT
package main

import (
	"bufio"
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"os"
	"testing"
	"time"
)

func TestAppServerUsesSharedConsentConstructor(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", home+"/config")
	t.Setenv("MODELPLAN_CACHE", home+"/cache")
	inR, inW, _ := os.Pipe()
	outR, outW, _ := os.Pipe()
	stderr, _ := os.CreateTemp(t.TempDir(), "stderr")
	defer stderr.Close()
	defer inW.Close()
	defer outR.Close()
	done := make(chan int, 1)
	go func() { done <- appServerCmd(nil, inR, outW, stderr) }()
	_, _ = inW.Write([]byte(`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"1.0","sessionId":"integration-test","appVersion":"test","capabilities":["rows","consent","history","refresh","publication"]}}` + "\n"))
	frames := make(chan []byte, 1)
	go func() {
		s := bufio.NewScanner(outR)
		if s.Scan() {
			frames <- append([]byte{}, s.Bytes()...)
		}
	}()
	select {
	case raw := <-frames:
		var result struct {
			Result wire.Envelope[wire.InitializeResult] `json:"result"`
		}
		if err := json.Unmarshal(raw, &result); err != nil {
			t.Fatal(err)
		}
		if result.Result.StoreEpoch == "unavailable" || result.Result.StoreEpoch == "" {
			t.Fatalf("inert constructor: %s", raw)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("initialize timed out")
	}
	inW.Close()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("server did not stop")
	}
}
