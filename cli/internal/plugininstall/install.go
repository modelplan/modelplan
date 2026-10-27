// Package plugininstall runs fixed, documented host marketplace commands.
// It does not inspect credentials or edit a host's configuration directly.
package plugininstall

import (
	"context"
	"errors"
	"io"
	"os/exec"
)

var ErrTool = errors.New("supported tools are claude-code and codex")

type Result struct {
	SchemaVersion int        `json:"schemaVersion"`
	Tool          string     `json:"tool"`
	Status        string     `json:"status"` // installed | instructions | planned | failed
	Commands      [][]string `json:"commands"`
	Completed     int        `json:"completed"`
	Docs          string     `json:"docs"`
}

// Environment lets tests use fixture CLIs without installing real plugins.
type Environment struct {
	LookPath func(string) (string, error)
	Run      func(context.Context, string, []string, io.Reader, io.Writer, io.Writer) error
}

func Install(ctx context.Context, tool string, execute bool, stdin io.Reader, stdout, stderr io.Writer, env Environment) (Result, error) {
	r := Result{SchemaVersion: 1, Tool: tool, Status: "instructions"}
	switch tool {
	case "claude-code":
		r.Commands = [][]string{
			{"claude", "plugin", "marketplace", "add", "modelplan/modelplan"},
			{"claude", "plugin", "install", "modelplan@modelplan"},
		}
		r.Docs = "https://github.com/modelplan/modelplan/tree/main/claude-code"
	case "codex":
		r.Commands = [][]string{
			{"codex", "plugin", "marketplace", "add", "modelplan/modelplan", "--sparse", ".agents", "--sparse", "codex"},
			{"codex", "plugin", "add", "modelplan-codex@modelplan"},
		}
		r.Docs = "https://github.com/modelplan/modelplan/tree/main/codex"
	default:
		return r, ErrTool
	}
	if !execute {
		r.Status = "planned"
		return r, nil
	}
	if env.LookPath == nil {
		env.LookPath = exec.LookPath
	}
	path, err := env.LookPath(r.Commands[0][0])
	if err != nil {
		return r, nil // missing host: print the same commands instead
	}
	if env.Run == nil {
		env.Run = func(ctx context.Context, path string, args []string, stdin io.Reader, stdout, stderr io.Writer) error {
			cmd := exec.CommandContext(ctx, path, args...)
			cmd.Stdin, cmd.Stdout, cmd.Stderr = stdin, stdout, stderr
			// Inherit the App's supplied environment, including system proxy settings.
			return cmd.Run()
		}
	}
	for _, command := range r.Commands {
		if err := env.Run(ctx, path, command[1:], stdin, stdout, stderr); err != nil {
			r.Status = "failed"
			return r, errors.New("host plugin installation failed; the next step was not run")
		}
		r.Completed++
	}
	r.Status = "installed"
	return r, nil
}
