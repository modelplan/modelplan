package main

import (
	"fmt"
	"io"

	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func detection(st *store.Store) detect.Report {
	cat, source := detect.Fallback(), "built-in"
	if d, _, err := publication.Load(st); err == nil && d.Catalogue != nil {
		cat, source = d.Catalogue, "publication"
	}
	return detect.Run(cat, detect.Local(), version, source)
}
func detectCmd(args []string, stdout, stderr io.Writer, st *store.Store, c common) int {
	if len(args) != 0 {
		fmt.Fprintln(stderr, "usage: modelplan detect [--json]")
		return exitUsage
	}
	r := detection(st)
	if c.json {
		return printJSON(stdout, r)
	}
	for _, tool := range r.Tools {
		fmt.Fprintf(stdout, "%s · %s", tool.DisplayName, tool.Status)
		if tool.Beta {
			fmt.Fprint(stdout, " · beta")
		}
		if tool.NextStep != "" {
			fmt.Fprint(stdout, " · ", tool.NextStep)
		}
		fmt.Fprintln(stdout)
	}
	if c.lang == "en" {
		fmt.Fprintln(stdout, "Presence only; sign-in and subscription are unknown. No credentials read or network calls.")
	} else {
		fmt.Fprintln(stdout, "仅检测是否存在；登录状态和订阅未知。不读取凭据，不访问网络。")
	}
	fmt.Fprintf(stdout, "%s\n", "Missing your tool? https://github.com/modelplan/modelplan/issues/new?template=feature.yml&title=Tool%20detection%20request")
	return 0
}
