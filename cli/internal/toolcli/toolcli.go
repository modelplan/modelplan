// SPDX-License-Identifier: MIT
// Package toolcli finds installed tool CLIs and their Node runtime without a shell.
package toolcli

import (
	"bufio"
	"context"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

const RuntimeMissing = "binary_found_but_runtime_missing"
const RuntimeNextStep = "Install Node.js, or make node available beside the tool CLI, then retry in Settings"

var ErrRuntimeMissing = errors.New(RuntimeMissing + ": " + RuntimeNextStep)

// SearchDirs also serves presence-only discovery. No executable is run or sourced.
func SearchDirs(home string) []string {
	dirs := []string{filepath.Join(home, ".local", "bin"), filepath.Join(home, "bin"), filepath.Join(home, ".npm-global", "bin"), filepath.Join(home, ".volta", "bin"), filepath.Join(home, ".bun", "bin"), "/opt/homebrew/bin", "/usr/local/bin"}
	return append(dirs, nvmDirs(home)...)
}
func nvmDirs(home string) []string {
	dirs, _ := filepath.Glob(filepath.Join(home, ".nvm", "versions", "node", "*", "bin"))
	sort.Slice(dirs, func(i, j int) bool {
		return newerVersion(filepath.Base(filepath.Dir(dirs[i])), filepath.Base(filepath.Dir(dirs[j])))
	})
	return dirs
}
func newerVersion(a, b string) bool {
	parts := func(s string) []int {
		var out []int
		for _, p := range strings.Split(strings.TrimPrefix(s, "v"), ".") {
			n, _ := strconv.Atoi(p)
			out = append(out, n)
		}
		return out
	}
	x, y := parts(a), parts(b)
	for i := 0; i < len(x) || i < len(y); i++ {
		u, v := 0, 0
		if i < len(x) {
			u = x[i]
		}
		if i < len(y) {
			v = y[i]
		}
		if u != v {
			return u > v
		}
	}
	return a > b
}
func executable(path string) bool {
	s, e := os.Stat(path)
	return e == nil && s.Mode().IsRegular() && s.Mode()&0111 != 0
}
func Find(home, name string, extra ...string) string {
	if p, e := exec.LookPath(name); e == nil {
		return p
	}
	for _, d := range SearchDirs(home) {
		p := filepath.Join(d, name)
		if executable(p) {
			return p
		}
	}
	for _, p := range extra {
		if executable(p) {
			return p
		}
	}
	return ""
}

// EnvNode recognizes only a direct env-node shebang, including env -S node.
// It never interprets assignments, shell expressions, or arbitrary env arguments.
func EnvNode(r io.Reader) bool {
	line, _ := bufio.NewReader(io.LimitReader(r, 4096)).ReadString('\n')
	fields := strings.Fields(strings.TrimSpace(line))
	if len(fields) < 2 || fields[0] != "#!/usr/bin/env" {
		return false
	}
	fields = fields[1:]
	if len(fields) > 0 && fields[0] == "-S" {
		fields = fields[1:]
	}
	return len(fields) == 1 && fields[0] == "node"
}

var resolveNode = findNode

func findNode(home, script string) string {
	return locateNode(home, script, exec.LookPath, executable)
}
func locateNode(home, script string, lookPath func(string) (string, error), exists func(string) bool) string {
	dirs := []string{filepath.Dir(script)}
	// npm bin symlinks can point into a package; inspect both adjacent locations.
	if target, e := filepath.EvalSymlinks(script); e == nil {
		dirs = append(dirs, filepath.Dir(target))
	}
	for _, d := range dirs {
		p := filepath.Join(d, "node")
		if exists(p) {
			return p
		}
	}
	if p, e := lookPath("node"); e == nil {
		return p
	}
	dirs = []string{"/opt/homebrew/bin", "/usr/local/bin"}
	dirs = append(dirs, nvmDirs(home)...)
	dirs = append(dirs, filepath.Join(home, ".volta", "bin"), filepath.Join(home, ".local", "bin"), filepath.Join(home, ".bun", "bin"))
	for _, d := range dirs {
		p := filepath.Join(d, "node")
		if exists(p) {
			return p
		}
	}
	if p, e := lookPath("bun"); e == nil {
		return p
	}
	for _, d := range append([]string{filepath.Join(home, ".bun", "bin")}, dirs...) {
		p := filepath.Join(d, "bun")
		if exists(p) {
			return p
		}
	}
	return ""
}

// NodeCommandContext also supports a verified artifact descriptor: script is the
// exact artifact to execute, nearby is the installed path used only to find node.
func NodeCommandContext(ctx context.Context, script, nearby string, args ...string) (*exec.Cmd, error) {
	home, _ := os.UserHomeDir()
	node := resolveNode(home, nearby)
	if node == "" {
		return nil, ErrRuntimeMissing
	}
	argv := []string{script}
	// Node otherwise realpaths Linux memfd descriptors to a non-existent /memfd path.
	if strings.HasPrefix(script, "/proc/self/fd/") && filepath.Base(node) != "bun" {
		argv = append([]string{"--preserve-symlinks-main"}, argv...)
	}
	return exec.CommandContext(ctx, node, append(argv, args...)...), nil
}
func CommandContext(ctx context.Context, bin string, args ...string) (*exec.Cmd, error) {
	info, e := os.Stat(bin)
	if e != nil || !info.Mode().IsRegular() {
		return exec.CommandContext(ctx, bin, args...), nil
	}
	f, e := os.Open(bin)
	if e == nil {
		s, err := f.Stat()
		isNode := err == nil && s.Mode().IsRegular() && EnvNode(f)
		_ = f.Close()
		if isNode {
			return NodeCommandContext(ctx, bin, bin, args...)
		}
	}
	return exec.CommandContext(ctx, bin, args...), nil
}
