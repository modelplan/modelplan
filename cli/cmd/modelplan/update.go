package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"runtime"
	"time"

	"github.com/modelplan/modelplan/cli/internal/cliupdate"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/store"
)

var updateExecutable = os.Executable
var fetchCLIUpdate cliupdate.Fetch = cliupdate.HTTPFetch

func updateCmd(args []string, stdout, stderr io.Writer, c common) int {
	if len(args) != 0 {
		fmt.Fprintln(stderr, "usage: modelplan update [--json]")
		return exitUsage
	}
	executable, err := updateExecutable()
	if err != nil {
		fmt.Fprintln(stderr, "update: cannot locate this CLI / 无法定位当前 CLI")
		return exitErr
	}
	home, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintln(stderr, "update: cannot locate home directory / 无法定位主目录")
		return exitErr
	}
	if _, err := cliupdate.Target(executable, home); err != nil {
		fmt.Fprintln(stderr, "update:", err, "/ 插件或 App 管理的副本请通过其管理方更新")
		return exitErr
	}
	if c.offline {
		fmt.Fprintln(stderr, "update: requires an explicit online command / 更新需要显式在线命令")
		return exitErr
	}
	st, err := store.Open()
	if err != nil {
		fmt.Fprintln(stderr, "update: cannot open publication cache / 无法打开发布缓存")
		return exitErr
	}
	client, err := publication.New(c.base, st, version)
	if err != nil {
		fmt.Fprintln(stderr, "update: invalid publication base / 发布地址无效")
		return exitUsage
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	client.NoCheckDelay = true
	if _, err := client.Sync(ctx, true); err != nil {
		fmt.Fprintln(stderr, "update: refresh failed; checking the last verified publication / 刷新失败，检查上次已校验发布")
	}
	d, _, err := publication.Load(st)
	if err != nil {
		fmt.Fprintln(stderr, "update: no verified publication available / 没有已校验的发布")
		return exitNoData
	}
	pin, err := cliupdate.ParsePin(d.CLIUpdate)
	if err != nil {
		fmt.Fprintln(stderr, "update:", err, "/ 没有可用的已校验 CLI 更新元数据")
		return exitNoData
	}
	result, err := cliupdate.Apply(ctx, executable, home, version, runtime.GOOS+"/"+runtime.GOARCH, pin, fetchCLIUpdate)
	if c.json {
		if code := printJSON(stdout, result); code != 0 {
			return code
		}
	} else if err == nil {
		if result.Status == "updated" {
			fmt.Fprintln(stdout, "Updated CLI; previous binary kept / CLI 已更新并保留上一个副本:", result.Target)
		} else {
			fmt.Fprintln(stdout, "CLI is current or newer / CLI 已是当前或更新版本:", result.Current)
		}
	}
	if err != nil {
		fmt.Fprintln(stderr, "update:", err)
		return exitErr
	}
	return 0
}
