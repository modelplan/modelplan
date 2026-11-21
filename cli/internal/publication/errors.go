// SPDX-License-Identifier: MIT
package publication

import (
	"context"
	"errors"
	"net"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/netproxy"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// fetchError names why a request failed. The cause is classified and dropped, never kept as text.
type fetchError struct{ class string }

func (e *fetchError) Error() string { return Reason(e.class, "en") }

func classifyRequest(err error) *fetchError {
	var op *net.OpError
	switch {
	case errors.Is(err, netproxy.ErrInvalid):
		return &fetchError{store.LastErrorProxyInvalid}
	case strings.Contains(err.Error(), "Proxy Authentication Required"): // net/http keeps only the status text of a refused CONNECT
		return &fetchError{store.LastErrorProxyAuth}
	case errors.As(err, &op) && op.Op == "proxyconnect":
		return &fetchError{store.LastErrorProxyUnreachable}
	case isTimeout(err):
		return &fetchError{store.LastErrorTimeout}
	}
	return &fetchError{store.LastErrorNetwork}
}

func isTimeout(err error) bool {
	var timeout interface{ Timeout() bool }
	return errors.Is(err, context.DeadlineExceeded) || errors.As(err, &timeout) && timeout.Timeout()
}

// Class is the saved form of a sync error. proxySource tells a plain network failure on a PAC Mac from any other:
// the request went direct because the CLI cannot run the PAC script.
func Class(err error, proxySource string) string {
	var fetch *fetchError
	class := store.LastErrorSync
	switch {
	case errors.As(err, &fetch):
		class = fetch.class
	case errors.Is(err, context.DeadlineExceeded):
		class = store.LastErrorTimeout
	}
	if proxySource == netproxy.SourcePAC && (class == store.LastErrorNetwork || class == store.LastErrorTimeout) {
		return store.LastErrorPAC
	}
	return class
}

// Explain is the line a person reads when a sync fails. Only the fixed reasons appear.
func Explain(err error, lang string) string {
	var classed *syncError
	if errors.As(err, &classed) {
		return Reason(classed.class, lang)
	}
	return Reason(Class(err, netproxy.SourceNone), lang)
}

// syncError carries the class Sync saved, so what is printed matches what doctor shows.
type syncError struct {
	class string
	err   error
}

func (e *syncError) Error() string { return Reason(e.class, "en") }
func (e *syncError) Unwrap() error { return e.err }

// Reason says what happened and what to do, in plain words.
func Reason(class, lang string) string {
	text := reasons[class]
	if text == [2]string{} {
		return ""
	}
	if lang == "en" {
		return text[0]
	}
	return text[1]
}

var reasons = map[string][2]string{
	store.LastErrorProxyInvalid: {"The proxy setting is not valid, so nothing was fetched. Check HTTPS_PROXY and ALL_PROXY.",
		"代理设置的格式不对，所以没有联网。请检查 HTTPS_PROXY 和 ALL_PROXY。"},
	store.LastErrorProxyAuth: {"The proxy asked for a sign-in. Put the user name and password in HTTPS_PROXY; ModelPlan does not read saved proxy passwords.",
		"代理要求登录。请把用户名和密码写进 HTTPS_PROXY；ModelPlan 不读取系统保存的代理密码。"},
	store.LastErrorProxyUnreachable: {"The proxy could not be reached. Check that it is running.",
		"连不上代理。请确认代理正在运行。"},
	store.LastErrorPAC: {"This Mac uses an automatic proxy file (PAC), which ModelPlan cannot follow yet, so it connected directly and failed. Set a manual proxy in System Settings, or set HTTPS_PROXY.",
		"这台 Mac 用的是自动代理文件（PAC），ModelPlan 暂时不支持，所以直接联网并失败了。请在系统设置里改用手动代理，或设置 HTTPS_PROXY。"},
	store.LastErrorNetwork: {"The network could not be reached. If you need a proxy here, set one in System Settings or in HTTPS_PROXY.",
		"连不上网络。如果这里需要代理，请在系统设置里设置，或设置 HTTPS_PROXY。"},
	store.LastErrorTimeout: {"The network timed out. It will be tried again.", "联网超时，稍后会再试。"},
	store.LastErrorHTTP:    {"The data server did not answer normally. It will be tried again.", "数据服务器没有正常响应，稍后会再试。"},
	store.LastErrorSync:    {"The last data update failed. The saved data stays in use.", "上次数据更新失败，继续使用已保存的数据。"},
}
