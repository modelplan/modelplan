// SPDX-License-Identifier: MIT
// Synthetic owning runtime: no credential, network, file scan or paid operation.
package main

import (
	"bufio"
	"encoding/json"
	"os"
	"time"
)

func main() {
	if len(os.Args) != 2 || os.Args[1] != "app-server" {
		os.Exit(2)
	}
	log, err := os.OpenFile(os.Getenv("MODELPLAN_U3B_RUNTIME_CALLS"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		os.Exit(3)
	}
	defer log.Close()
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		var request struct {
			JSONRPC string          `json:"jsonrpc"`
			ID      json.RawMessage `json:"id"`
			Method  string          `json:"method"`
			Params  json.RawMessage `json:"params"`
		}
		if json.Unmarshal(scanner.Bytes(), &request) != nil {
			os.Exit(4)
		}
		record, _ := json.Marshal(map[string]any{"method": request.Method, "params": request.Params})
		_, _ = log.Write(append(record, '\n'))
		if len(request.ID) == 0 {
			if request.Method != "initialized" {
				os.Exit(5)
			}
			continue
		}
		var result any
		switch request.Method {
		case "initialize":
			result = map[string]any{"userAgent": "synthetic-runtime"}
		case "account/rateLimits/read":
			result = map[string]any{"rateLimitsByLimitId": map[string]any{"codex": map[string]any{"limitId": "codex", "planType": "pro", "primary": map[string]any{"usedPercent": 12, "windowDurationMins": 300, "resetsAt": time.Now().Add(3 * time.Hour).Unix()}}}}
		case "account/read":
			var p map[string]any
			if json.Unmarshal(request.Params, &p) != nil || p["refreshToken"] != false {
				os.Exit(6)
			}
			result = map[string]any{"account": map[string]any{"type": "chatgpt", "email": "runtime-identity-canary@example.test", "planType": "pro"}}
		default:
			os.Exit(7)
		}
		encoded, _ := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": request.ID, "result": result})
		if _, err := os.Stdout.Write(append(encoded, '\n')); err != nil {
			return
		}
	}
}
