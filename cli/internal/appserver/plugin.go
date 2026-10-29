// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"io"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/plugininstall"
)

// PluginInstallHandler wraps the same fixed implementation used by the CLI.
// Host stdout/stderr are untrusted and discarded; the host never reads the
// engine's JSON-RPC stdin. Failure remains the ordinary installation Result.
func PluginInstallHandler(offline, readOnly bool) Handler {
	return Handler{Capability: "plugin_install", Timeout: wire.PluginInstallTimeout, Handle: func(ctx context.Context, raw json.RawMessage, stamp Stamp) (Reply, error) {
		p, err := params[wire.PluginInstallParams](raw)
		if err != nil || (p.Tool != wire.PluginClaudeCode && p.Tool != wire.PluginCodex) {
			return Reply{}, ProtocolError{wire.CodeInvalidParams}
		}
		result, err := plugininstall.Install(ctx, string(p.Tool), !offline && !readOnly && !p.Offline, nil, io.Discard, io.Discard, plugininstall.Environment{})
		if err != nil && result.Status != "failed" {
			return Reply{}, ProtocolError{wire.CodeInternal}
		}
		return Reply{Stamp: stamp, Data: result, Receipt: true}, nil
	}}
}
