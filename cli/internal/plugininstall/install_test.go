package plugininstall

import (
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"testing"
)

func TestDocumentedCommandsOnly(t *testing.T) {
	for _, tc := range []struct {
		tool string
		want [][]string
	}{
		{"claude-code", [][]string{{"plugin", "marketplace", "add", "modelplan/modelplan"}, {"plugin", "install", "modelplan@modelplan"}}},
		{"codex", [][]string{{"plugin", "marketplace", "add", "modelplan/modelplan", "--sparse", ".agents", "--sparse", "codex"}, {"plugin", "add", "modelplan-codex@modelplan"}}},
	} {
		t.Run(tc.tool, func(t *testing.T) {
			var calls [][]string
			r, err := Install(context.Background(), tc.tool, true, nil, io.Discard, io.Discard, Environment{
				LookPath: func(name string) (string, error) { return "/fixture/" + name, nil },
				Run: func(_ context.Context, path string, args []string, _ io.Reader, _, _ io.Writer) error {
					if path != "/fixture/"+rHost(tc.tool) {
						t.Fatalf("unexpected host: %s", path)
					}
					calls = append(calls, append([]string(nil), args...))
					return nil
				},
			})
			if err != nil || r.Status != "installed" || r.Completed != 2 || !reflect.DeepEqual(calls, tc.want) {
				t.Fatalf("install: %+v err=%v calls=%v", r, err, calls)
			}
		})
	}
}

func rHost(tool string) string {
	if tool == "claude-code" {
		return "claude"
	}
	return "codex"
}

func TestMissingOfflineUnsupportedAndFailedInstalls(t *testing.T) {
	env := Environment{
		LookPath: func(string) (string, error) { return "", errors.New("not installed") },
		Run: func(context.Context, string, []string, io.Reader, io.Writer, io.Writer) error {
			t.Fatal("unexpected command")
			return nil
		},
	}
	if r, err := Install(context.Background(), "codex", true, nil, io.Discard, io.Discard, env); err != nil || r.Status != "instructions" || len(r.Commands) != 2 {
		t.Fatalf("missing host: %+v %v", r, err)
	}
	env.LookPath = func(string) (string, error) { t.Fatal("offline lookup"); return "", nil }
	if r, err := Install(context.Background(), "codex", false, nil, io.Discard, io.Discard, env); err != nil || r.Status != "planned" {
		t.Fatalf("offline: %+v %v", r, err)
	}
	if _, err := Install(context.Background(), "codex; unexpected", true, nil, io.Discard, io.Discard, env); !errors.Is(err, ErrTool) {
		t.Fatalf("unrecognised tool accepted: %v", err)
	}
	calls := 0
	env.LookPath = func(string) (string, error) { return "/fixture/codex", nil }
	env.Run = func(context.Context, string, []string, io.Reader, io.Writer, io.Writer) error {
		calls++
		return errors.New("fixture failure")
	}
	if r, err := Install(context.Background(), "codex", true, nil, io.Discard, io.Discard, env); err == nil || r.Status != "failed" || calls != 1 || r.Completed != 0 {
		t.Fatalf("did not stop after failure: %+v %v calls=%d", r, err, calls)
	}
}

func TestHostInheritsAppProxyEnvironment(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("POSIX fixture host")
	}
	dir := t.TempDir()
	fixture := filepath.Join(dir, "codex")
	output := filepath.Join(dir, "proxy")
	if err := os.WriteFile(fixture, []byte("#!/bin/sh\nprintf '%s' \"$HTTPS_PROXY\" > \"$FIXTURE_PROXY_OUTPUT\"\n"), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HTTPS_PROXY", "http://fixture-proxy.invalid:8080")
	t.Setenv("FIXTURE_PROXY_OUTPUT", output)
	if _, err := Install(context.Background(), "codex", true, nil, io.Discard, io.Discard, Environment{LookPath: func(string) (string, error) { return fixture, nil }}); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(output)
	if err != nil || string(b) != "http://fixture-proxy.invalid:8080" {
		t.Fatalf("App proxy was not inherited: %q %v", b, err)
	}
}
