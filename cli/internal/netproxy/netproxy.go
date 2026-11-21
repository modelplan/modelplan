// SPDX-License-Identifier: MIT

// Package netproxy decides which proxy the CLI's HTTP requests use. Go reads only HTTP_PROXY, HTTPS_PROXY and
// NO_PROXY, ignores ALL_PROXY and a malformed value, and never sees the macOS system proxy, which is the only
// setting an app opened from Finder has. Install replaces that policy on http.DefaultTransport, so every client
// built on it follows this one.
//
// Order: the environment, when any proxy variable is set; then the macOS system proxy from `scutil --proxy`, read
// only when a request needs it. PAC is reported, not evaluated: Go cannot run the script.
//
// No credentials: a proxy address never reaches an error, status or log. The system settings are read for host,
// port, switches and exceptions only; proxy user names and the Keychain are not touched.
package netproxy

import (
	"context"
	"errors"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Status sources. They are the only proxy facts reported anywhere.
const (
	SourceNone    = "none"
	SourceEnv     = "env"
	SourceSystem  = "system"
	SourcePAC     = "pac-unsupported"
	SourceInvalid = "invalid"
)

// ErrInvalid is a proxy setting that cannot be used. The request fails rather than going direct, because a user
// who needs a proxy may not want traffic to leave without it. The value is deliberately not part of the error.
var ErrInvalid = errors.New("proxy setting is not usable")

const cacheFor = 30 * time.Second

// Settings are the macOS system proxy values the CLI uses. Addresses are host:port.
type Settings struct {
	HTTP, HTTPS, SOCKS string
	PAC                bool
	ExcludeSimple      bool
	Exceptions         []string
}

type Status struct {
	Source string `json:"source"`
}

type Resolver struct {
	Getenv     func(string) string
	ReadSystem func() string // the text of `scutil --proxy`; empty when there is none
	Now        func() time.Time

	mu      sync.Mutex
	read    bool
	readAt  time.Time
	settled Settings
}

// Default is the policy of this process.
var Default = &Resolver{
	Getenv:     os.Getenv,
	ReadSystem: func() string { return readSystem(runtime.GOOS, command) },
	Now:        time.Now,
}

// Install must run before the first request. Clones of the default transport keep the policy; code that must not
// use a proxy clears it on its own clone.
func Install() {
	if t, ok := http.DefaultTransport.(*http.Transport); ok {
		t.Proxy = Default.Proxy
	}
}

func readSystem(goos string, run func(string, ...string) string) string {
	if goos != "darwin" {
		return ""
	}
	return run("/usr/sbin/scutil", "--proxy")
}

// command runs a fixed path with a fixed environment. A failure reads as no system proxy.
func command(name string, args ...string) string {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = []string{"PATH=/usr/bin:/bin", "LANG=C"}
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return string(out)
}

func (r *Resolver) env(upper, lower string) string {
	if v := strings.TrimSpace(r.Getenv(upper)); v != "" {
		return v
	}
	return strings.TrimSpace(r.Getenv(lower))
}

type environment struct{ http, https, all, no string }

func (r *Resolver) environment() environment {
	return environment{r.env("HTTP_PROXY", "http_proxy"), r.env("HTTPS_PROXY", "https_proxy"), r.env("ALL_PROXY", "all_proxy"), r.env("NO_PROXY", "no_proxy")}
}

func (e environment) set() bool { return e.http != "" || e.https != "" || e.all != "" }

func (r *Resolver) system() Settings {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.read && r.Now().Sub(r.readAt) < cacheFor {
		return r.settled
	}
	r.settled, r.read, r.readAt = ParseScutil(r.ReadSystem()), true, r.Now()
	return r.settled
}

// Proxy has the signature of http.Transport.Proxy.
func (r *Resolver) Proxy(req *http.Request) (*url.URL, error) {
	host := strings.ToLower(req.URL.Hostname())
	if loopback(host) {
		return nil, nil
	}
	port := req.URL.Port()
	if port == "" {
		port = map[string]string{"http": "80", "https": "443"}[req.URL.Scheme]
	}
	e := r.environment()
	if matches(host, port, strings.FieldsFunc(e.no, func(c rune) bool { return c == ',' || c == ' ' })) {
		return nil, nil
	}
	if e.set() {
		value := e.http
		if req.URL.Scheme == "https" {
			value = e.https
		}
		if value == "" {
			value = e.all
		}
		if value == "" {
			return nil, nil
		}
		return parse(value)
	}
	s := r.system()
	if s.ExcludeSimple && !strings.Contains(host, ".") && net.ParseIP(host) == nil {
		return nil, nil
	}
	if matches(host, port, s.Exceptions) {
		return nil, nil
	}
	address := s.HTTP
	if req.URL.Scheme == "https" {
		address = s.HTTPS
	}
	if address != "" {
		return parse("http://" + address)
	}
	if s.SOCKS != "" {
		return parse("socks5://" + s.SOCKS)
	}
	return nil, nil
}

// Status reads the system proxy on macOS when the environment sets none.
func (r *Resolver) Status() Status {
	if e := r.environment(); e.set() {
		for _, v := range []string{e.http, e.https, e.all} {
			if v != "" {
				if _, err := parse(v); err != nil {
					return Status{SourceInvalid}
				}
			}
		}
		return Status{SourceEnv}
	}
	s := r.system()
	switch {
	case s.HTTP != "" || s.HTTPS != "" || s.SOCKS != "":
		return Status{SourceSystem}
	case s.PAC:
		return Status{SourcePAC}
	}
	return Status{SourceNone}
}

func parse(value string) (*url.URL, error) {
	if !strings.Contains(value, "://") {
		value = "http://" + value
	}
	u, err := url.Parse(value)
	if err != nil || u.Hostname() == "" {
		return nil, ErrInvalid
	}
	switch u.Scheme {
	case "http", "https", "socks5", "socks5h":
		return u, nil
	}
	return nil, ErrInvalid
}

func loopback(host string) bool {
	if host == "localhost" || strings.HasSuffix(host, ".localhost") {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

// matches reads NO_PROXY and macOS exception entries: *, a host, .suffix, *.suffix, an IP, a CIDR block (macOS writes
// 169.254/16), each host with an optional :port. A plain host also covers its subdomains.
func matches(host, port string, patterns []string) bool {
	ip := net.ParseIP(host)
	for _, raw := range patterns {
		p := strings.ToLower(strings.TrimSpace(raw))
		if p == "" {
			continue
		}
		if p == "*" {
			return true
		}
		if strings.Contains(p, "/") {
			if _, block, err := net.ParseCIDR(fullBlock(p)); err == nil && ip != nil && block.Contains(ip) {
				return true
			}
			continue
		}
		if h, pp, err := net.SplitHostPort(p); err == nil {
			if pp != port {
				continue
			}
			p = h
		}
		p = strings.Trim(p, "[]")
		if ip != nil {
			if other := net.ParseIP(p); other != nil && other.Equal(ip) {
				return true
			}
			continue
		}
		p = strings.TrimPrefix(p, "*")
		if strings.HasPrefix(p, ".") {
			if strings.HasSuffix(host, p) {
				return true
			}
			continue
		}
		if host == p || strings.HasSuffix(host, "."+p) {
			return true
		}
	}
	return false
}

func fullBlock(p string) string {
	address, bits, _ := strings.Cut(p, "/")
	if !strings.Contains(address, ":") {
		for strings.Count(address, ".") < 3 {
			address += ".0"
		}
	}
	return address + "/" + bits
}

// ParseScutil reads the text of `scutil --proxy`. Only the top-level dictionary counts; __SCOPED__ holds
// per-interface copies. Keys outside this list, the proxy user names among them, are dropped as they are read.
func ParseScutil(text string) Settings {
	wanted := map[string]bool{"HTTPEnable": true, "HTTPPort": true, "HTTPProxy": true, "HTTPSEnable": true, "HTTPSPort": true, "HTTPSProxy": true,
		"SOCKSEnable": true, "SOCKSPort": true, "SOCKSProxy": true, "ProxyAutoConfigEnable": true, "ProxyAutoDiscoveryEnable": true, "ExcludeSimpleHostnames": true}
	values := map[string]string{}
	var s Settings
	depth, inExceptions := 0, false
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if line == "}" {
			depth--
			inExceptions = inExceptions && depth >= 2
			continue
		}
		key, value, ok := strings.Cut(line, " : ")
		if strings.HasSuffix(line, "{") {
			inExceptions = depth == 1 && key == "ExceptionsList"
			depth++
			continue
		}
		if !ok {
			continue
		}
		if inExceptions && depth == 2 {
			s.Exceptions = append(s.Exceptions, value)
		} else if depth == 1 && wanted[key] {
			values[key] = value
		}
	}
	address := func(kind string) string {
		port, err := strconv.Atoi(values[kind+"Port"])
		if values[kind+"Enable"] != "1" || values[kind+"Proxy"] == "" || err != nil || port < 1 || port > 65535 {
			return ""
		}
		return net.JoinHostPort(values[kind+"Proxy"], strconv.Itoa(port))
	}
	s.HTTP, s.HTTPS, s.SOCKS = address("HTTP"), address("HTTPS"), address("SOCKS")
	s.PAC = values["ProxyAutoConfigEnable"] == "1" || values["ProxyAutoDiscoveryEnable"] == "1"
	s.ExcludeSimple = values["ExcludeSimpleHostnames"] == "1"
	return s
}
