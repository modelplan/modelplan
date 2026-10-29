// SPDX-License-Identifier: MIT
package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/appcontract"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--headless" {
		if err := copilot(); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}
	write := flag.Bool("write", false, "update reviewed generated fixtures")
	flag.Bool("check", false, "check regenerated fixtures against committed files (default)")
	rootFlag := flag.String("root", "..", "repository root")
	flag.Parse()
	root, err := filepath.Abs(*rootFlag)
	if err != nil {
		panic(err)
	}
	helper, err := os.Executable()
	if err != nil {
		panic(err)
	}
	files, err := appcontract.Generate(root, helper)
	if err == nil {
		err = appcontract.Check(root, files, *write)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Printf("app–CLI binary conformance and %d generated fixture files verified\n", len(files))
}

func copilot() error {
	log, err := os.OpenFile(os.Getenv("MODELPLAN_CONTRACT_CALLS"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	defer log.Close()
	r := bufio.NewReader(os.Stdin)
	for {
		n := -1
		for {
			line, err := r.ReadString('\n')
			if err != nil {
				return nil
			}
			if line == "\r\n" {
				break
			}
			if strings.HasPrefix(line, "Content-Length: ") {
				n, err = strconv.Atoi(strings.TrimSpace(strings.TrimPrefix(line, "Content-Length: ")))
				if err != nil {
					return err
				}
			}
		}
		if n < 0 || n > 65536 {
			return fmt.Errorf("invalid synthetic frame")
		}
		raw := make([]byte, n)
		if _, err := io.ReadFull(r, raw); err != nil {
			return err
		}
		var request struct {
			ID     int    `json:"id"`
			Method string `json:"method"`
		}
		if err := json.Unmarshal(raw, &request); err != nil {
			return err
		}
		fmt.Fprintln(log, request.Method)
		var result any
		switch request.Method {
		case "connect":
			result = map[string]any{"protocolVersion": 3}
		case "auth.getStatus":
			result = map[string]any{"isAuthenticated": true, "authType": "user"}
		case "account.getQuota":
			result = map[string]any{"quotaSnapshots": map[string]any{"premium_interactions": map[string]any{"usedRequests": 75, "entitlementRequests": 300, "remainingPercentage": 75, "resetDate": "2099-01-01T00:00:00Z"}}}
			if os.Getenv("MODELPLAN_CONTRACT_UNREADABLE") == "1" {
				result = map[string]any{"quotaSnapshots": "unreadable-synthetic-shape"}
			}
		default:
			return fmt.Errorf("synthetic runtime refuses %s", request.Method)
		}
		body, _ := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": request.ID, "result": result})
		fmt.Printf("Content-Length: %d\r\n\r\n%s", len(body), body)
	}
}
