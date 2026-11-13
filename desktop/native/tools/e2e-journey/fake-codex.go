// SPDX-License-Identifier: MIT
// Synthetic Codex app-server fixture. No network or credential access.
package main

import (
	"bufio"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	if len(os.Args) != 2 || os.Args[1] != "app-server" {
		os.Exit(2)
	}
	profile := os.Getenv("CODEX_HOME")
	if !strings.HasPrefix(profile, os.Getenv("HOME")+string(os.PathSeparator)) {
		os.Exit(3)
	}
	scanner, output := bufio.NewScanner(os.Stdin), json.NewEncoder(os.Stdout)
	for scanner.Scan() {
		var request struct {
			ID     any    `json:"id"`
			Method string `json:"method"`
		}
		if json.Unmarshal(scanner.Bytes(), &request) != nil || request.ID == nil {
			continue
		}
		response := map[string]any{"id": request.ID}
		switch request.Method {
		case "initialize":
			response["result"] = map[string]any{"userAgent": "synthetic-codex"}
		case "account/read":
			response["result"] = map[string]any{"account": map[string]any{"type": "chatgpt", "email": "journey@example.invalid", "planType": "pro"}}
		case "account/rateLimits/read":
			mode, _ := os.ReadFile(filepath.Join(profile, "e2e-mode"))
			failed := strings.TrimSpace(string(mode)) != "readable"
			log, err := os.OpenFile(filepath.Join(profile, "e2e-calls.jsonl"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
			if err != nil {
				os.Exit(4)
			}
			_ = json.NewEncoder(log).Encode(map[string]any{"failed": failed, "at": time.Now().UnixMilli()})
			_ = log.Close()
			if failed {
				response["error"] = map[string]any{"message": "synthetic provider unreadable"}
			} else {
				response["result"] = map[string]any{"rateLimits": map[string]any{"planType": "pro", "limitId": "codex", "primary": map[string]any{
					"usedPercent": 63, "windowDurationMins": 300, "resetsAt": time.Now().Add(time.Hour).Unix()}}}
			}
		default:
			response["error"] = map[string]any{"message": "unsupported synthetic method"}
		}
		if output.Encode(response) != nil {
			os.Exit(5)
		}
	}
}
