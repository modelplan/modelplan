package main

import (
	"fmt"
	"io"
	"os"
	"strconv"
	"time"

	"github.com/modelplan/modelplan/cli/internal/localusage"
)

// Local accounting has its own consent and output. It never enables an account reader.
func usageCmd(args []string, stdout, stderr io.Writer, c common) int {
	if len(args) < 1 || args[0] != "gemini" || len(args) > 2 {
		fmt.Fprintln(stderr, "usage: modelplan usage gemini [enable|disable|status] [--json]")
		return exitUsage
	}
	home, _ := os.UserHomeDir()
	sub := "read"
	if len(args) == 2 {
		sub = args[1]
	}
	switch sub {
	case "enable", "disable":
		if err := localusage.SetGemini(home, sub == "enable"); err != nil {
			fmt.Fprintln(stderr, err)
			return exitErr
		}
	case "status", "read":
	default:
		fmt.Fprintln(stderr, "usage: modelplan usage gemini [enable|disable|status] [--json]")
		return exitUsage
	}
	r := localusage.GeminiStatus(home, time.Now())
	if sub == "read" {
		r = localusage.ReadGemini(home, time.Now())
	}
	if c.json {
		return printJSON(stdout, r)
	}
	fmt.Fprintf(stdout, "Gemini CLI · %s", r.Status)
	if r.Reason != "" {
		fmt.Fprintf(stdout, " · %s", r.Reason)
	}
	fmt.Fprintln(stdout)
	for _, p := range r.ReadPaths {
		fmt.Fprintln(stdout, "  "+p)
	}
	if c.lang == "en" {
		fmt.Fprintln(stdout, "  Local tokens/model/history only; no host called. Credentials are never read, printed or stored. Prompts, replies and raw identifiers are never printed or stored.")
		fmt.Fprintln(stdout, "  Input includes cached tokens; output excludes thoughts. Available local history only, no remaining quota.")
		if r.Status == "off" {
			fmt.Fprintln(stdout, "  Enable: modelplan usage gemini enable")
		}
		fmt.Fprintln(stdout, "day         model                     messages  input  output  cached  thoughts  total")
	} else {
		fmt.Fprintln(stdout, "  仅读取本机 token、模型和历史；不访问任何主机，不读取、打印或保存凭据，不打印或保存提问、回复及原始标识。")
		fmt.Fprintln(stdout, "  输入包含缓存 token，输出不含思考 token。仅统计可用本机历史，不代表剩余额度。")
		if r.Status == "off" {
			fmt.Fprintln(stdout, "  启用：modelplan usage gemini enable")
		}
		fmt.Fprintln(stdout, "日期        模型                      消息数    输入   输出    缓存    思考      总计")
	}
	n := func(v *int64) string {
		if v == nil {
			return "--"
		}
		return strconv.FormatInt(*v, 10)
	}
	for _, row := range r.Rows {
		fmt.Fprintf(stdout, "%-10s  %-24s  %d  %s  %s  %s  %s  %s\n", row.Day, row.Model, row.Messages, n(row.Input), n(row.Output), n(row.Cached), n(row.Thoughts), n(row.Total))
	}
	return 0
}
