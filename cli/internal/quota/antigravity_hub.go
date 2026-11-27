package quota

import (
	"context"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Antigravity 2.34 hub mode. Reference: Token Monitor@417f84d2 src/shared/providers/antigravity/probe.js
// (descriptor 187-210, process match 179-245, socket-owner check 409-444). The language server runs
// with --read_host_bridge_token_from_stdin and no --csrf_token; it writes ~/.gemini/antigravity/daemon/
// hub_<port>.json = {pid, httpPort, csrfToken} for its own user. Only ps and lsof run; no stdin is read
// and nothing inside Antigravity.app is executed. The token never reaches logs, errors or output.

// antigravityHome is where the descriptor lives; tests replace it.
var antigravityHome = func() string { h, _ := os.UserHomeDir(); return h }

var antigravityHubToken = regexp.MustCompile(`^[a-fA-F0-9-]{32,}$`)
var antigravityHubName = regexp.MustCompile(`^hub_([0-9]{1,5})\.json$`)

// readAntigravityHubDescriptor returns the descriptor of pid. Files must be regular, owned by this
// user, at most 4 KB and consistent (pid, port equal to the file name, token shape); the newest wins.
func readAntigravityHubDescriptor(pid int) (port int, token string, ok bool) {
	dir := filepath.Join(antigravityHome(), ".gemini", "antigravity", "daemon")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0, "", false
	}
	var newest time.Time
	for _, de := range entries {
		m := antigravityHubName.FindStringSubmatch(de.Name())
		if m == nil {
			continue
		}
		path := filepath.Join(dir, de.Name())
		fi, err := os.Lstat(path)
		if err != nil || !fi.Mode().IsRegular() || fi.Size() > 4096 || !antigravityOwnedByUser(fi) || fi.Mode().Perm()&0o022 != 0 {
			continue
		}
		f, err := os.Open(path)
		if err != nil {
			continue
		}
		b, err := io.ReadAll(io.LimitReader(f, 4097))
		f.Close()
		if err != nil || len(b) > 4096 {
			continue
		}
		var d struct {
			PID   int    `json:"pid"`
			Port  int    `json:"httpPort"`
			Token string `json:"csrfToken"`
		}
		filePort, _ := strconv.Atoi(m[1])
		if json.Unmarshal(b, &d) != nil || d.PID != pid || d.Port != filePort || d.Port < 1 || d.Port > 65535 || !antigravityHubToken.MatchString(d.Token) || !antigravityCSRF(d.Token) {
			continue
		}
		if !ok || fi.ModTime().After(newest) {
			port, token, ok, newest = d.Port, d.Token, true, fi.ModTime()
		}
	}
	return
}

// antigravitySocketOwned: the connection we just opened is a socket of pid, so the token goes to the
// verified process only. One retry after 20 ms, as the reference does.
func antigravitySocketOwned(ctx context.Context, s AntigravityServer, localPort int) bool {
	want := "n127.0.0.1:" + strconv.Itoa(s.Port) + "->127.0.0.1:" + strconv.Itoa(localPort)
	for try := 0; try < 2; try++ {
		if try > 0 {
			time.Sleep(20 * time.Millisecond)
		}
		raw, err := antigravityCommand(ctx, antigravityLsof(), "-nP", "-a", "-p", strconv.Itoa(s.PID), "-i4TCP", "-sTCP:ESTABLISHED", "-Fn")
		if err != nil {
			continue
		}
		for _, line := range strings.Split(string(raw), "\n") {
			if strings.TrimSpace(line) == want {
				return true
			}
		}
	}
	return false
}
