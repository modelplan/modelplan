// LOCAL ONLY - do not commit.
package main

import (
	"os"
	"os/signal"
	"runtime/pprof"
	"syscall"
)

func init() {
	path := os.Getenv("MP_LOCAL_CPUPROFILE")
	if path == "" {
		return
	}
	f, err := os.Create(path)
	if err != nil {
		return
	}
	_ = pprof.StartCPUProfile(f)
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGUSR1)
	go func() { <-ch; pprof.StopCPUProfile(); f.Close() }()
}
