// SPDX-License-Identifier: MIT
package netproxy

import (
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func fixture(t *testing.T, name string) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("testdata", name))
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func resolver(env map[string]string, system string) *Resolver {
	return &Resolver{
		Getenv:     func(k string) string { return env[k] },
		ReadSystem: func() string { return system },
		Now:        time.Now,
	}
}

func proxyFor(t *testing.T, r *Resolver, target string) string {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, target, nil)
	if err != nil {
		t.Fatal(err)
	}
	u, err := r.Proxy(req)
	if err != nil {
		t.Fatalf("%s: %v", target, err)
	}
	if u == nil {
		return ""
	}
	return u.String()
}

func TestParseScutilReadsTopLevelSettingsOnly(t *testing.T) {
	s := ParseScutil(fixture(t, "scutil-manual.txt"))
	if s.HTTP != "127.0.0.1:7890" || s.HTTPS != "proxy.example.com:7891" || s.SOCKS != "" || s.PAC {
		t.Fatalf("settings: %+v", s)
	}
	if !s.ExcludeSimple || strings.Join(s.Exceptions, ",") != "*.local,169.254/16,intranet.example.com" {
		t.Fatalf("exceptions: %+v", s)
	}
	if strings.Contains(strings.ToLower(strings.Join([]string{s.HTTP, s.HTTPS, s.SOCKS}, " ")), "fixture-user") {
		t.Fatal("a proxy user name was kept")
	}
	if s := ParseScutil(fixture(t, "scutil-pac.txt")); !s.PAC || s.HTTPS != "" {
		t.Fatalf("pac: %+v", s)
	}
	if s := ParseScutil(fixture(t, "scutil-socks.txt")); s.SOCKS != "127.0.0.1:7891" {
		t.Fatalf("socks: %+v", s)
	}
	if s := ParseScutil(fixture(t, "scutil-off.txt")); s.HTTP != "" || s.HTTPS != "" || s.SOCKS != "" || s.PAC {
		t.Fatalf("off: %+v", s)
	}
	for _, text := range []string{"", "No proxies\n", "<dictionary> {\n  HTTPSEnable : 1\n  HTTPSProxy : x\n}\n", "<dictionary> {\n  HTTPSEnable : 1\n  HTTPSPort : 99999\n  HTTPSProxy : x\n}\n"} {
		if s := ParseScutil(text); s.HTTPS != "" {
			t.Fatalf("incomplete setting used: %q %+v", text, s)
		}
	}
}

func TestSystemProxySelection(t *testing.T) {
	r := resolver(nil, fixture(t, "scutil-manual.txt"))
	if got := proxyFor(t, r, "https://modelplan.ai/x"); got != "http://proxy.example.com:7891" {
		t.Fatalf("https: %q", got)
	}
	if got := proxyFor(t, r, "http://example.org/x"); got != "http://127.0.0.1:7890" {
		t.Fatalf("http: %q", got)
	}
	for _, direct := range []string{"https://printer.local/", "https://169.254.1.2/", "https://intranet.example.com/", "https://a.intranet.example.com/", "https://simplehost/", "http://localhost:1234/", "http://127.0.0.1:1234/", "http://[::1]:1234/"} {
		if got := proxyFor(t, r, direct); got != "" {
			t.Fatalf("%s must go direct, got %q", direct, got)
		}
	}
	socks := resolver(nil, fixture(t, "scutil-socks.txt"))
	if got := proxyFor(t, socks, "https://modelplan.ai/"); got != "socks5://127.0.0.1:7891" {
		t.Fatalf("socks: %q", got)
	}
	if got := proxyFor(t, resolver(map[string]string{"NO_PROXY": "*"}, fixture(t, "scutil-socks.txt")), "https://modelplan.ai/"); got != "" {
		t.Fatalf("NO_PROXY applies to the system proxy too: %q", got)
	}
	if got := proxyFor(t, resolver(nil, fixture(t, "scutil-off.txt")), "https://modelplan.ai/"); got != "" {
		t.Fatalf("off: %q", got)
	}
}

func TestEnvironmentWinsAndAllProxyIsRead(t *testing.T) {
	system := fixture(t, "scutil-manual.txt")
	for _, c := range []struct {
		env    map[string]string
		target string
		want   string
	}{
		{map[string]string{"HTTPS_PROXY": "http://env.example:1"}, "https://a.example/", "http://env.example:1"},
		{map[string]string{"https_proxy": "http://lower.example:1"}, "https://a.example/", "http://lower.example:1"},
		{map[string]string{"HTTPS_PROXY": "http://upper.example:1", "https_proxy": "http://lower.example:1"}, "https://a.example/", "http://upper.example:1"},
		{map[string]string{"HTTP_PROXY": "http://plain.example:1"}, "http://a.example/", "http://plain.example:1"},
		{map[string]string{"HTTP_PROXY": "http://plain.example:1"}, "https://a.example/", ""},
		{map[string]string{"ALL_PROXY": "socks5://all.example:1"}, "https://a.example/", "socks5://all.example:1"},
		{map[string]string{"all_proxy": "socks5://all.example:1"}, "http://a.example/", "socks5://all.example:1"},
		{map[string]string{"ALL_PROXY": "socks5://all.example:1", "HTTPS_PROXY": "http://env.example:1"}, "https://a.example/", "http://env.example:1"},
		{map[string]string{"HTTPS_PROXY": "127.0.0.1:7890"}, "https://a.example/", "http://127.0.0.1:7890"},
		{map[string]string{"HTTPS_PROXY": "http://env.example:1", "NO_PROXY": "a.example"}, "https://a.example/", ""},
		{map[string]string{"HTTPS_PROXY": "http://env.example:1", "no_proxy": ".example"}, "https://a.example/", ""},
		{map[string]string{"HTTPS_PROXY": "http://env.example:1", "NO_PROXY": "10.0.0.0/8"}, "https://10.1.2.3/", ""},
		{map[string]string{"HTTPS_PROXY": "http://env.example:1", "NO_PROXY": "a.example:444"}, "https://a.example/", "http://env.example:1"},
		{map[string]string{"HTTPS_PROXY": "http://env.example:1", "NO_PROXY": "a.example:443"}, "https://a.example/", ""},
		{map[string]string{"HTTPS_PROXY": "http://env.example:1", "NO_PROXY": "other.example"}, "https://a.example/", "http://env.example:1"},
		{map[string]string{"HTTPS_PROXY": "http://env.example:1"}, "http://127.0.0.1:9/", ""},
	} {
		if got := proxyFor(t, resolver(c.env, system), c.target); got != c.want {
			t.Fatalf("%v %s: got %q want %q", c.env, c.target, got, c.want)
		}
	}
}

func TestMalformedProxyFailsInsteadOfGoingDirectAndHidesTheValue(t *testing.T) {
	const canary = "CANARY-PROXY-PASSWORD"
	for _, value := range []string{
		"http://user:" + canary + "%zz@127.0.0.1:1",
		"http://user:" + canary + "@bad host:1",
		"http://user:" + canary + "@[::1:80",
		"ftp://user:" + canary + "@example.com:1",
		"http://",
	} {
		r := resolver(map[string]string{"HTTPS_PROXY": value}, "")
		req, _ := http.NewRequest(http.MethodGet, "https://a.example/", nil)
		u, err := r.Proxy(req)
		if u != nil || !errors.Is(err, ErrInvalid) {
			t.Fatalf("%q: %v %v", value, u, err)
		}
		if strings.Contains(err.Error(), canary) {
			t.Fatalf("value leaked: %v", err)
		}
		if got := r.Status().Source; got != SourceInvalid {
			t.Fatalf("%q status %q", value, got)
		}
	}
	// A bad value for the other scheme does not stop this request, but the status still says so.
	r := resolver(map[string]string{"HTTP_PROXY": "ftp://x:1", "HTTPS_PROXY": "http://env.example:1"}, "")
	if got := proxyFor(t, r, "https://a.example/"); got != "http://env.example:1" {
		t.Fatal(got)
	}
	if got := r.Status().Source; got != SourceInvalid {
		t.Fatal(got)
	}
}

func TestStatusNamesTheSourceOnly(t *testing.T) {
	for _, c := range []struct {
		env    map[string]string
		system string
		want   string
	}{
		{nil, "", SourceNone},
		{nil, fixture(t, "scutil-off.txt"), SourceNone},
		{nil, fixture(t, "scutil-manual.txt"), SourceSystem},
		{nil, fixture(t, "scutil-socks.txt"), SourceSystem},
		{nil, fixture(t, "scutil-pac.txt"), SourcePAC},
		{map[string]string{"ALL_PROXY": "socks5://a.example:1"}, fixture(t, "scutil-pac.txt"), SourceEnv},
	} {
		if got := resolver(c.env, c.system).Status().Source; got != c.want {
			t.Fatalf("%v: %q want %q", c.env, got, c.want)
		}
	}
	// PAC alone goes direct: it is reported, never evaluated.
	if got := proxyFor(t, resolver(nil, fixture(t, "scutil-pac.txt")), "https://a.example/"); got != "" {
		t.Fatal(got)
	}
}

func TestSystemReadIsCachedAndFollowsChanges(t *testing.T) {
	now := time.Unix(1000, 0)
	reads := 0
	text := fixture(t, "scutil-off.txt")
	r := &Resolver{Getenv: func(string) string { return "" }, Now: func() time.Time { return now }, ReadSystem: func() string { reads++; return text }}
	proxyFor(t, r, "https://a.example/")
	text = fixture(t, "scutil-manual.txt")
	if got := proxyFor(t, r, "https://a.example/"); got != "" || reads != 1 {
		t.Fatalf("cache: %q %d", got, reads)
	}
	now = now.Add(cacheFor + time.Second)
	if got := proxyFor(t, r, "https://a.example/"); got != "http://proxy.example.com:7891" || reads != 2 {
		t.Fatalf("change not seen: %q %d", got, reads)
	}
}

func TestSystemIsReadOnlyOnMacAndFromAFixedPath(t *testing.T) {
	var ran []string
	run := func(name string, args ...string) string {
		ran = append(ran, name+" "+strings.Join(args, " "))
		return ""
	}
	if readSystem("linux", run) != "" || len(ran) != 0 {
		t.Fatalf("ran off macOS: %v", ran)
	}
	readSystem("darwin", run)
	if len(ran) != 1 || ran[0] != "/usr/sbin/scutil --proxy" {
		t.Fatalf("ran: %v", ran)
	}
}

func TestInstallKeepsOneProxyFunctionOnDefaultTransport(t *testing.T) {
	transport := http.DefaultTransport.(*http.Transport)
	old := transport.Proxy
	t.Cleanup(func() { transport.Proxy = old })
	Install()
	if transport.Clone().Proxy == nil {
		t.Fatal("clones must keep the proxy function")
	}
}
