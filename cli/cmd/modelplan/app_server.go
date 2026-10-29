// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"fmt"
	"io"

	"github.com/modelplan/modelplan/cli/internal/appserver"
)

func appServerCmd(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	if len(args) != 0 {
		fmt.Fprintln(stderr, "app-server: no command arguments accepted")
		return exitUsage
	}
	in, ok := stdin.(io.ReadCloser)
	if !ok {
		fmt.Fprintln(stderr, "app-server: anonymous input pipe required")
		return exitUsage
	}
	out, ok := stdout.(io.WriteCloser)
	if !ok {
		fmt.Fprintln(stderr, "app-server: anonymous output pipe required")
		return exitUsage
	}
	// U2 supplies the schema-2 backend. The inert constructor fails closed until
	// that integration is available; no legacy tool-level grant is consulted.
	server := appserver.New(appserver.Config{Version: version, Backend: appserver.UnavailableBackend{}})
	if err := server.Serve(context.Background(), in, out); err != nil {
		fmt.Fprintln(stderr, "app-server: internal")
		return exitErr
	}
	return 0
}
