// SPDX-License-Identifier: MIT
package publication

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/netproxy"
	"github.com/modelplan/modelplan/cli/internal/store"
)

const canary = "CANARY-PROXY-PASSWORD"

func closedPort(t *testing.T) string {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	return l.Addr().String()
}

// syncThrough runs one failing sync of a host that does not exist, through the given proxy environment.
func syncThrough(t *testing.T, env map[string]string, system, source string) (string, string) {
	t.Helper()
	r := &netproxy.Resolver{Getenv: func(k string) string { return env[k] }, ReadSystem: func() string { return system }, Now: time.Now}
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.Proxy = r.Proxy
	st := &store.Store{Dir: t.TempDir()}
	c, err := New("https://publication.invalid", st, "test")
	if err != nil {
		t.Fatal(err)
	}
	c.HTTP = &http.Client{Timeout: 2 * time.Second, Transport: transport}
	c.ProxySource = func() string { return source }
	_, err = c.Sync(context.Background(), true)
	if err == nil {
		t.Fatal("sync of a missing host succeeded")
	}
	s, serr := st.State()
	if serr != nil {
		t.Fatal(serr)
	}
	raw, _ := os.ReadFile(filepath.Join(st.Dir, "state.json"))
	if strings.Contains(string(raw), canary) || strings.Contains(err.Error(), canary) {
		t.Fatalf("canary leaked: %s %v", raw, err)
	}
	return s.LastError, Explain(err, "en")
}

func TestSyncFailureIsAFixedClass(t *testing.T) {
	refused := func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusProxyAuthRequired) }
	authProxy := httptest.NewServer(http.HandlerFunc(refused))
	defer authProxy.Close()
	closed := "http://user:" + canary + "@" + closedPort(t)
	for _, c := range []struct {
		name   string
		env    map[string]string
		source string
		want   string
		says   string
	}{
		{"malformed value never goes direct", map[string]string{"HTTPS_PROXY": "http://user:" + canary + "%zz@127.0.0.1:1"}, netproxy.SourceInvalid, store.LastErrorProxyInvalid, "proxy setting"},
		{"dead proxy", map[string]string{"HTTPS_PROXY": closed}, netproxy.SourceEnv, store.LastErrorProxyUnreachable, "proxy"},
		{"proxy asks for a sign-in", map[string]string{"HTTPS_PROXY": "http://user:" + canary + "@" + strings.TrimPrefix(authProxy.URL, "http://")}, netproxy.SourceEnv, store.LastErrorProxyAuth, "sign-in"},
		{"no proxy, no network", nil, netproxy.SourceNone, store.LastErrorNetwork, "network"},
		{"PAC cannot be followed", nil, netproxy.SourcePAC, store.LastErrorPAC, "PAC"},
	} {
		t.Run(c.name, func(t *testing.T) {
			got, reason := syncThrough(t, c.env, "", c.source)
			if got != c.want {
				t.Fatalf("class %q want %q", got, c.want)
			}
			if !strings.Contains(reason, c.says) {
				t.Fatalf("reason %q", reason)
			}
		})
	}
}

func TestHTTPAndVerificationFailuresAreClassesToo(t *testing.T) {
	status := http.StatusInternalServerError
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(status)
		_, _ = w.Write([]byte(`{}`))
	}))
	defer srv.Close()
	st := &store.Store{Dir: t.TempDir()}
	c, err := New(srv.URL, st, "test")
	if err != nil {
		t.Fatal(err)
	}
	_, _ = c.Sync(context.Background(), true)
	if s, _ := st.State(); s.LastError != store.LastErrorHTTP {
		t.Fatalf("http: %q", s.LastError)
	}
	status = http.StatusOK
	_, _ = c.Sync(context.Background(), true)
	if s, _ := st.State(); s.LastError != store.LastErrorSync {
		t.Fatalf("verification: %q", s.LastError)
	}
}

func TestEveryClassHasAPlainReasonInBothLanguages(t *testing.T) {
	for _, class := range []string{store.LastErrorProxyInvalid, store.LastErrorProxyAuth, store.LastErrorProxyUnreachable, store.LastErrorPAC, store.LastErrorNetwork, store.LastErrorTimeout, store.LastErrorHTTP, store.LastErrorSync} {
		if store.CleanLastError(class) != class {
			t.Fatalf("%s is not a known class", class)
		}
		en, zh := Reason(class, "en"), Reason(class, "zh")
		if en == "" || zh == "" || en == zh || strings.Contains(en, class) {
			t.Fatalf("%s: %q %q", class, en, zh)
		}
	}
	if store.CleanLastError("") != "" || store.CleanLastError("request failed: https://u:"+canary+"@x") != store.LastErrorSync {
		t.Fatal("an old saved error must not pass through")
	}
}
