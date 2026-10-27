package main

import (
	"context"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/plugininstall"
)

func pluginCmd(args []string, stdin io.Reader, stdout, stderr io.Writer, c common) int {
	if len(args) != 2 || args[0] != "install" || (args[1] != "claude-code" && args[1] != "codex") {
		fmt.Fprintln(stderr, "usage: modelplan plugin install claude-code|codex [--json] [--offline]")
		return exitUsage
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	commandOut := stdout
	if c.json {
		commandOut = stderr // keep the App's JSON channel machine-readable
	}
	result, err := plugininstall.Install(ctx, args[1], !c.offline, stdin, commandOut, stderr, plugininstall.Environment{})
	if c.json {
		if code := printJSON(stdout, result); code != 0 {
			return code
		}
	} else {
		if result.Status == "instructions" || result.Status == "planned" {
			if c.lang == "en" {
				fmt.Fprintln(stdout, "Run these commands in the host tool's terminal:")
			} else {
				fmt.Fprintln(stdout, "在宿主工具的终端运行以下命令：")
			}
			for _, command := range result.Commands {
				fmt.Fprintln(stdout, strings.Join(command, " "))
			}
			fmt.Fprintln(stdout, result.Docs)
		} else if result.Status == "installed" {
			fmt.Fprintln(stdout, "ModelPlan plugin installed / 插件安装完成:", result.Tool)
		}
	}
	if err != nil {
		fmt.Fprintln(stderr, "plugin install:", err)
		return exitErr
	}
	return 0
}
