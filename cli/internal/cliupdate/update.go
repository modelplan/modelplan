// Package cliupdate replaces an unmanaged CLI only on an explicit update command.
// Its pin is supplied by the already-verified publication, never a latest-release API.
package cliupdate

import (
	"archive/tar"
	"archive/zip"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"time"
)

var (
	ErrNoPin           = errors.New("verified publication has no CLI update pin yet")
	ErrPin             = errors.New("invalid CLI update pin in the verified publication")
	ErrManaged         = errors.New("plugin- or App-managed CLI copies must be updated by their owner")
	ErrPlatform        = errors.New("no published CLI checksum for this platform")
	ErrChecksum        = errors.New("CLI archive checksum mismatch; current binary kept")
	ErrArchive         = errors.New("invalid CLI release archive; current binary kept")
	ErrBusy            = errors.New("another CLI update is running")
	ErrTargetVersion   = errors.New("cannot verify the installed CLI version; current binary kept")
	ErrTargetChanged   = errors.New("CLI destination changed during update; current binary kept")
	versionRE          = regexp.MustCompile(`^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})$`)
	installedVersionRE = regexp.MustCompile(`^v?(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$`)
	hashRE             = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

const (
	maxArchive  = 64 << 20
	maxBinary   = 128 << 20
	maxUnpacked = 160 << 20
)

// Pin follows FEEDFIX's design note: cli.latest and sha256 keyed by "os/arch".
type Pin struct {
	Latest string            `json:"latest"`
	SHA256 map[string]string `json:"sha256"`
}

func ParsePin(raw json.RawMessage) (Pin, error) {
	var pin Pin
	if len(raw) == 0 || string(raw) == "null" {
		return pin, ErrNoPin
	}
	if len(raw) > 16<<10 || json.Unmarshal(raw, &pin) != nil || !versionRE.MatchString(pin.Latest) || len(pin.SHA256) == 0 || len(pin.SHA256) > 32 {
		return Pin{}, ErrPin
	}
	for _, sum := range pin.SHA256 {
		if !hashRE.MatchString(sum) {
			return Pin{}, ErrPin
		}
	}
	return pin, nil
}

// Target rejects both lexical and resolved managed paths, including the plugin's
// stable symlink. A standalone/Skill copy may live outside ~/.local/bin.
func Target(executable, home string) (string, error) {
	managed := func(p string) bool {
		for _, part := range strings.Split(filepath.ToSlash(p), "/") {
			if strings.HasSuffix(strings.ToLower(part), ".app") {
				return true
			}
		}
		root := filepath.Join(home, ".cache", "modelplan-cli")
		within := func(root string) bool {
			rel, err := filepath.Rel(root, p)
			return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
		}
		if within(root) {
			return true
		}
		if real, err := filepath.EvalSymlinks(root); err == nil && within(real) {
			return true
		}
		return false
	}
	if managed(executable) {
		return "", ErrManaged
	}
	real, err := filepath.EvalSymlinks(executable)
	if err != nil {
		return "", errors.New("cannot resolve this CLI executable")
	}
	if managed(real) {
		return "", ErrManaged
	}
	info, err := os.Stat(real)
	if err != nil || !info.Mode().IsRegular() {
		return "", errors.New("CLI executable is not a regular file")
	}
	return real, nil
}

type Result struct {
	SchemaVersion int    `json:"schemaVersion"`
	Status        string `json:"status"`
	Current       string `json:"current"`
	Target        string `json:"target,omitempty"`
}

type Fetch func(context.Context, string) (io.ReadCloser, error)

// HTTPFetch honours HTTP(S)_PROXY/NO_PROXY passed by the App. Redirects remain
// HTTPS and within GitHub's release-asset hosts; no GitHub API is queried.
func HTTPFetch(ctx context.Context, releaseURL string) (io.ReadCloser, error) {
	u, err := url.Parse(releaseURL)
	if err != nil || u.Scheme != "https" || u.Host != "github.com" || u.User != nil || u.RawQuery != "" || !strings.HasPrefix(u.Path, "/modelplan/modelplan/releases/download/v") {
		return nil, errors.New("CLI release URL refused")
	}
	c := &http.Client{Timeout: 2 * time.Minute, CheckRedirect: func(req *http.Request, via []*http.Request) error {
		if len(via) >= 10 {
			return errors.New("too many CLI release redirects")
		}
		switch req.URL.Hostname() {
		case "github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com":
			if req.URL.Scheme == "https" && req.URL.User == nil && (req.URL.Port() == "" || req.URL.Port() == "443") {
				return nil
			}
		}
		return errors.New("CLI release redirect refused")
	}}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, releaseURL, nil)
	if err != nil {
		return nil, errors.New("invalid CLI release request")
	}
	resp, err := c.Do(req)
	if err != nil {
		return nil, errors.New("CLI archive download failed")
	}
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		return nil, errors.New("CLI release archive unavailable")
	}
	return resp.Body, nil
}

// Apply keeps the old binary until archive verification and extraction succeed.
// A successful replacement retains the previous binary at <executable>.previous.
func Apply(ctx context.Context, executable, home, current, platform string, pin Pin, fetch Fetch) (Result, error) {
	r := Result{SchemaVersion: 1, Status: "failed", Current: current, Target: pin.Latest}
	if err := ctx.Err(); err != nil {
		return r, err
	}
	target, err := Target(executable, home)
	if err != nil {
		return r, err
	}
	raw, _ := json.Marshal(pin)
	if _, err := ParsePin(raw); err != nil {
		return r, err
	}
	ext := ".tar.gz"
	switch platform {
	case "darwin/arm64", "darwin/amd64", "linux/arm64", "linux/amd64":
	case "windows/arm64", "windows/amd64":
		ext = ".zip"
	default:
		return r, ErrPlatform
	}
	want, ok := pin.SHA256[platform]
	if !ok {
		return r, ErrPlatform
	}
	if !newer(pin.Latest, current) {
		r.Status = "up_to_date"
		return r, nil
	}
	lock, err := os.OpenFile(target+".update.lock", os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if errors.Is(err, os.ErrExist) {
		return r, ErrBusy
	}
	if err != nil {
		return r, errors.New("cannot lock CLI for updating")
	}
	lock.Close()
	defer os.Remove(target + ".update.lock")
	// The running process can be older than the file another updater installed
	// while it discovered its pin. Inspect the destination under the shared lock.
	resolved, err := Target(executable, home)
	if err != nil {
		return r, err
	}
	if resolved != target {
		return r, ErrTargetChanged
	}
	installedInfo, err := os.Stat(target)
	if err != nil {
		return r, ErrTargetChanged
	}
	installed, err := targetVersion(ctx, target)
	if err != nil {
		return r, err
	}
	if !unchanged(target, installedInfo) {
		return r, ErrTargetChanged
	}
	r.Current = installed
	if !newer(pin.Latest, installed) {
		r.Status = "up_to_date"
		return r, nil
	}
	stage, err := os.MkdirTemp(filepath.Dir(target), ".modelplan-update-")
	if err != nil {
		return r, errors.New("cannot stage CLI update")
	}
	defer os.RemoveAll(stage)
	if fetch == nil {
		fetch = HTTPFetch
	}
	name := "modelplan_" + strings.ReplaceAll(platform, "/", "_")
	url := "https://github.com/modelplan/modelplan/releases/download/v" + pin.Latest + "/" + name + ext
	body, err := fetch(ctx, url)
	if err != nil {
		return r, err
	}
	archive, err := os.Create(filepath.Join(stage, "archive"))
	if err != nil {
		body.Close()
		return r, errors.New("cannot stage CLI archive")
	}
	hash := sha256.New()
	n, copyErr := io.Copy(io.MultiWriter(archive, hash), io.LimitReader(body, maxArchive+1))
	body.Close()
	closeErr := archive.Close()
	if copyErr != nil || closeErr != nil || n > maxArchive {
		return r, ErrArchive
	}
	if hex.EncodeToString(hash.Sum(nil)) != want {
		return r, ErrChecksum
	}
	if err := ctx.Err(); err != nil {
		return r, err
	}
	candidate := filepath.Join(stage, "modelplan")
	if err := extract(filepath.Join(stage, "archive"), candidate, name, ext); err != nil {
		return r, err
	}
	if err := ctx.Err(); err != nil {
		return r, err
	}
	// Cooperating installers hold the same lock. Also refuse an unexpected
	// replacement by an older installer that does not yet implement the lock.
	if !unchanged(target, installedInfo) {
		return r, ErrTargetChanged
	}
	backup := filepath.Join(stage, "previous")
	if err := copyBinary(target, backup); err != nil {
		return r, errors.New("cannot preserve previous CLI")
	}
	if err := os.Rename(backup, target+".previous"); err != nil {
		return r, errors.New("cannot preserve previous CLI")
	}
	if err := ctx.Err(); err != nil {
		return r, err
	}
	if runtime.GOOS == "windows" {
		// Windows cannot replace a running image directly. Keep a second, verified
		// copy before moving it aside and restore it if activation fails.
		if err := os.Rename(target, filepath.Join(stage, "running")); err != nil {
			return r, errors.New("cannot move running CLI; previous binary kept")
		}
		if err := os.Rename(candidate, target); err != nil {
			_ = os.Rename(filepath.Join(stage, "running"), target)
			return r, errors.New("cannot activate CLI; previous binary kept")
		}
	} else if err := os.Rename(candidate, target); err != nil {
		return r, errors.New("cannot activate CLI; current binary kept")
	}
	r.Status = "updated"
	return r, nil
}

func newer(target, current string) bool {
	// SemVer build metadata has no precedence, even when it contains a hyphen.
	current = strings.SplitN(strings.TrimPrefix(current, "v"), "+", 2)[0]
	prerelease := strings.Contains(current, "-")
	current = strings.SplitN(current, "-", 2)[0]
	if !versionRE.MatchString(current) {
		return true
	}
	a, b := strings.Split(target, "."), strings.Split(current, ".")
	for i := range a {
		x, _ := strconv.Atoi(a[i])
		y, _ := strconv.Atoi(b[i])
		if x != y {
			return x > y
		}
	}
	return prerelease
}

func unchanged(target string, before os.FileInfo) bool {
	after, err := os.Stat(target)
	return err == nil && os.SameFile(before, after) && before.Size() == after.Size() && before.ModTime().Equal(after.ModTime())
}

// Only the installed CLI is executed, with the fixed version command. Bound
// time/output, discard stderr and never execute an unactivated archive candidate.
func targetVersion(ctx context.Context, target string) (string, error) {
	probeCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	cmd := exec.CommandContext(probeCtx, target, "version")
	var out versionOutput
	cmd.Stdout = &out
	cmd.Stderr = io.Discard
	cmd.WaitDelay = 100 * time.Millisecond
	if err := cmd.Run(); err != nil {
		if ctx.Err() != nil {
			return "", ctx.Err()
		}
		return "", ErrTargetVersion
	}
	fields := strings.Fields(out.String())
	if len(fields) != 2 || fields[0] != "modelplan" || !installedVersionRE.MatchString(fields[1]) {
		return "", ErrTargetVersion
	}
	return strings.TrimPrefix(fields[1], "v"), nil
}

type versionOutput struct{ data bytes.Buffer }

func (b *versionOutput) String() string { return b.data.String() }
func (b *versionOutput) Write(p []byte) (int, error) {
	if len(p) > 512-b.data.Len() {
		return 0, ErrTargetVersion
	}
	return b.data.Write(p)
}

func copyBinary(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0755)
	if err != nil {
		return err
	}
	n, err := io.Copy(out, io.LimitReader(in, maxBinary+1))
	if err == nil && n > maxBinary {
		err = errors.New("previous binary too large")
	}
	if err == nil {
		err = out.Sync()
	}
	if e := out.Close(); err == nil {
		err = e
	}
	return err
}

func safeName(name string) bool {
	trimmed := strings.TrimSuffix(name, "/")
	return trimmed != "" && !strings.ContainsAny(trimmed, "\\:\x00") && path.Clean(trimmed) == trimmed && !path.IsAbs(trimmed) && trimmed != ".." && !strings.HasPrefix(trimmed, "../")
}

func extract(archive, candidate, name, ext string) error {
	out, err := os.OpenFile(candidate, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0755)
	if err != nil {
		return ErrArchive
	}
	defer out.Close()
	found := false
	copyEntry := func(reader io.Reader, size int64) error {
		if found || size <= 0 || size > maxBinary {
			return ErrArchive
		}
		found = true
		n, err := io.Copy(out, io.LimitReader(reader, size+1))
		if err != nil || n != size {
			return ErrArchive
		}
		return nil
	}
	if ext == ".zip" {
		z, err := zip.OpenReader(archive)
		if err != nil {
			return ErrArchive
		}
		defer z.Close()
		var total uint64
		for _, f := range z.File {
			if f.UncompressedSize64 > maxUnpacked-total {
				return ErrArchive
			}
			total += f.UncompressedSize64
			if !safeName(f.Name) || total > maxUnpacked || f.Mode()&os.ModeSymlink != 0 {
				return ErrArchive
			}
			if f.Name != name+"/modelplan.exe" {
				continue
			}
			if !f.Mode().IsRegular() {
				return ErrArchive
			}
			reader, err := f.Open()
			if err != nil {
				return ErrArchive
			}
			err = copyEntry(reader, int64(f.UncompressedSize64))
			reader.Close()
			if err != nil {
				return err
			}
		}
	} else {
		f, err := os.Open(archive)
		if err != nil {
			return ErrArchive
		}
		defer f.Close()
		gz, err := gzip.NewReader(f)
		if err != nil {
			return ErrArchive
		}
		defer gz.Close()
		limit := &io.LimitedReader{R: gz, N: maxUnpacked + 1}
		reader := tar.NewReader(limit)
		for {
			h, err := reader.Next()
			if err == io.EOF {
				break
			}
			if err != nil || limit.N <= 0 || !safeName(h.Name) || (h.Typeflag != tar.TypeReg && h.Typeflag != tar.TypeDir) {
				return ErrArchive
			}
			if h.Name == name+"/modelplan" {
				if h.Typeflag != tar.TypeReg {
					return ErrArchive
				}
				if err := copyEntry(reader, h.Size); err != nil {
					return err
				}
			}
		}
		if _, err := io.Copy(io.Discard, limit); err != nil || limit.N <= 0 {
			return ErrArchive
		}
	}
	if !found {
		return ErrArchive
	}
	if out.Sync() != nil {
		return ErrArchive
	}
	if out.Close() != nil {
		return ErrArchive
	}
	return nil
}
