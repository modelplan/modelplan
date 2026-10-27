package main

import (
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/qwenusage"
	"io"
	"time"
)

func qwenSnapshot(now time.Time) *qwenusage.Report {
	if qwenusage.Configured() == "" || !consent.Allowed("qwen", consent.Local) {
		return nil
	}
	r := qwenusage.Read(qwenusage.Configured(), now)
	return &r
}

func qwenUsageCmd(out io.Writer, c common, path string) int {
	if path == "" {
		path = qwenusage.Configured()
	}
	var r qwenusage.Report
	if consent.Allowed("qwen", consent.Local) {
		r = qwenusage.Read(path, time.Now())
	} else {
		r.Status = "off"
	}
	if c.json {
		return printJSON(out, r)
	}
	if c.lang == "en" {
		fmt.Fprintf(out, "Qwen Code local export: %s\nCalendar usage only; remaining quota: --. No network calls or credential reads.\n", r.Status)
	} else {
		fmt.Fprintf(out, "Qwen Code 本地导出：%s\n仅日历用量；剩余额度：--。不联网，不读取凭据。\n", r.Status)
	}
	for _, p := range r.Periods {
		stale := ""
		if p.Stale {
			stale = " (stale export / 导出已过期)"
		}
		fmt.Fprintf(out, "%s %s · total %s · exported %s%s\n", p.Period, p.Value, tokenCount(p.Totals.TotalTokens), p.GeneratedAt.Format(time.RFC3339), stale)
		for _, m := range p.Models {
			fmt.Fprintf(out, "  %s · input %s · output %s · cached %s · total %s\n", m.Model, tokenCount(m.InputTokens), tokenCount(m.OutputTokens), tokenCount(m.CachedTokens), tokenCount(m.TotalTokens))
		}
	}
	return 0
}
func tokenCount(n *int64) string {
	if n == nil {
		return "--"
	}
	return fmt.Sprint(*n)
}
