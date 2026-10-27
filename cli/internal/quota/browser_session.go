package quota

import (
	"context"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func codexBarEnvironment(access string) []string {
	env := []string{}
	for _, value := range os.Environ() {
		if !strings.HasPrefix(value, "CODEXBAR_DISABLE_KEYCHAIN_ACCESS=") {
			env = append(env, value)
		}
	}
	disabled := "1"
	if access == "browser-session" {
		disabled = "0"
	}
	return append(env, "CODEXBAR_DISABLE_KEYCHAIN_ACCESS="+disabled, "LANG=en_US.UTF-8", "LC_ALL=en_US.UTF-8")
}

// ClearBrowserCookies is an explicit Forget operation, never a usage read. The
// fixed, provider-scoped CLI is documented by pinned CLICacheCommand.swift at
// ee890b5f392e70d6e20162d3e95cf9f1be265b60. No --all, login or helper fetch.
func ClearBrowserCookies(ctx context.Context, p Paths, provider string) error {
	admission, err := consent.ReaderLock()
	if err != nil {
		return err
	}
	defer admission()
	if !consent.ValidTool(provider) {
		return errors.New("invalid cookie-cache provider")
	}
	home, _ := os.UserHomeDir()
	bin := CodexBarBin(p.Cache, home)
	if bin == "" {
		pinned := filepath.Join(codexbarPinnedDir(p.Cache), "CodexBarCLI")
		if executable(pinned) {
			bin = pinned
		}
	}
	if bin == "" {
		return errors.New("CodexBar cookie cleanup unavailable; retain cleanup marker and retry")
	}
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, "cache", "clear", "--cookies", "--provider", provider, "--format", "json")
	cmd.Env = codexBarEnvironment("browser-session")
	cmd.Stdin = nil
	cmd.Stdout = &limited{w: io.Discard, n: 64 << 10}
	cmd.Stderr = io.Discard
	if err := cmd.Run(); err != nil {
		return errors.New("provider cookie-cache cleanup failed; retry Forget readings")
	}
	return nil
}
