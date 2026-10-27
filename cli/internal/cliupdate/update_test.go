package cliupdate

import (
	"archive/tar"
	"archive/zip"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type fixtureTransport func(*http.Request) (*http.Response, error)

func (f fixtureTransport) RoundTrip(req *http.Request) (*http.Response, error) { return f(req) }

func TestReleaseRedirectsStayHTTPSAndOnAssetHosts(t *testing.T) {
	original := http.DefaultTransport
	t.Cleanup(func() { http.DefaultTransport = original })
	for _, destination := range []string{"http://github.com/plaintext", "https://unexpected.invalid/cli", "https://github.com:8080/cli"} {
		calls := 0
		http.DefaultTransport = fixtureTransport(func(req *http.Request) (*http.Response, error) {
			calls++
			return &http.Response{StatusCode: 302, Header: http.Header{"Location": []string{destination}}, Body: io.NopCloser(strings.NewReader("")), Request: req}, nil
		})
		if _, err := HTTPFetch(context.Background(), "https://github.com/modelplan/modelplan/releases/download/v9.9.9/modelplan_linux_arm64.tar.gz"); err == nil || calls != 1 {
			t.Fatalf("unsafe redirect followed: %s calls=%d err=%v", destination, calls, err)
		}
	}
	http.DefaultTransport = fixtureTransport(func(*http.Request) (*http.Response, error) { t.Fatal("non-release URL requested"); return nil, nil })
	if _, err := HTTPFetch(context.Background(), "https://api.github.com/repos/modelplan/modelplan/releases/latest"); err == nil {
		t.Fatal("latest-release API accepted")
	}
}

func fixtureArchive(t *testing.T, platform string, names ...string) []byte {
	t.Helper()
	var out bytes.Buffer
	if strings.HasPrefix(platform, "windows/") {
		w := zip.NewWriter(&out)
		for _, name := range names {
			f, err := w.Create(name)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := f.Write([]byte("verified new CLI fixture")); err != nil {
				t.Fatal(err)
			}
		}
		if err := w.Close(); err != nil {
			t.Fatal(err)
		}
	} else {
		gz := gzip.NewWriter(&out)
		w := tar.NewWriter(gz)
		for _, name := range names {
			body := []byte("verified new CLI fixture")
			if err := w.WriteHeader(&tar.Header{Name: name, Typeflag: tar.TypeReg, Mode: 0755, Size: int64(len(body))}); err != nil {
				t.Fatal(err)
			}
			if _, err := w.Write(body); err != nil {
				t.Fatal(err)
			}
		}
		if err := w.Close(); err != nil {
			t.Fatal(err)
		}
		if err := gz.Close(); err != nil {
			t.Fatal(err)
		}
	}
	return out.Bytes()
}

func fixturePin(platform string, archive []byte) Pin {
	h := sha256.Sum256(archive)
	return Pin{Latest: "9.9.9", SHA256: map[string]string{platform: hex.EncodeToString(h[:])}}
}

func fixtureTarget(t *testing.T) (string, string) {
	t.Helper()
	home := t.TempDir()
	exe := filepath.Join(home, ".local", "bin", "modelplan")
	if err := os.MkdirAll(filepath.Dir(exe), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(exe, []byte("previous verified CLI"), 0700); err != nil {
		t.Fatal(err)
	}
	return home, exe
}

func TestUpdateUsesPublishedPinAndKeepsPreviousBinary(t *testing.T) {
	for _, platform := range []string{"linux/arm64", "darwin/amd64", "windows/amd64"} {
		t.Run(platform, func(t *testing.T) {
			home, exe := fixtureTarget(t)
			file := "modelplan_" + strings.ReplaceAll(platform, "/", "_") + "/modelplan"
			ext := ".tar.gz"
			if strings.HasPrefix(platform, "windows/") {
				file += ".exe"
				ext = ".zip"
			}
			archive := fixtureArchive(t, platform, file)
			calls := 0
			result, err := Apply(context.Background(), exe, home, "0.5.40", platform, fixturePin(platform, archive), func(_ context.Context, url string) (io.ReadCloser, error) {
				calls++
				want := "https://github.com/modelplan/modelplan/releases/download/v9.9.9/modelplan_" + strings.ReplaceAll(platform, "/", "_") + ext
				if url != want {
					t.Fatalf("unexpected URL: %s", url)
				}
				return io.NopCloser(bytes.NewReader(archive)), nil
			})
			if err != nil || result.Status != "updated" || calls != 1 {
				t.Fatalf("update: %+v %v calls=%d", result, err, calls)
			}
			b, err := os.ReadFile(exe)
			if err != nil || string(b) != "verified new CLI fixture" {
				t.Fatalf("wrong binary: %q %v", b, err)
			}
			b, err = os.ReadFile(exe + ".previous")
			if err != nil || string(b) != "previous verified CLI" {
				t.Fatalf("previous binary lost: %q %v", b, err)
			}
			if _, err := os.Stat(exe + ".update.lock"); !os.IsNotExist(err) {
				t.Fatalf("lock left behind: %v", err)
			}
		})
	}
}

func TestFailedUpdateKeepsBinaryAndCatalogue(t *testing.T) {
	for _, kind := range []string{"checksum", "traversal", "duplicate", "wrong-file", "bad-gzip", "download"} {
		t.Run(kind, func(t *testing.T) {
			home, exe := fixtureTarget(t)
			catalogue := filepath.Join(home, "last-verified-catalogue.json")
			if err := os.WriteFile(catalogue, []byte("verified catalogue fixture"), 0600); err != nil {
				t.Fatal(err)
			}
			name := "modelplan_linux_arm64/modelplan"
			names := []string{name}
			switch kind {
			case "traversal":
				names = []string{name, "../escape"}
			case "duplicate":
				names = []string{name, name}
			case "wrong-file":
				names = []string{"unexpected/modelplan"}
			}
			archive := fixtureArchive(t, "linux/arm64", names...)
			if kind == "bad-gzip" {
				archive[len(archive)-1] ^= 1
			}
			pin := fixturePin("linux/arm64", archive)
			if kind == "checksum" {
				pin.SHA256["linux/arm64"] = strings.Repeat("0", 64)
			}
			_, err := Apply(context.Background(), exe, home, "0.5.40", "linux/arm64", pin, func(context.Context, string) (io.ReadCloser, error) {
				if kind == "download" {
					return nil, errors.New("fixture network failure")
				}
				return io.NopCloser(bytes.NewReader(archive)), nil
			})
			if err == nil {
				t.Fatal("bad update accepted")
			}
			for file, want := range map[string]string{exe: "previous verified CLI", catalogue: "verified catalogue fixture"} {
				b, e := os.ReadFile(file)
				if e != nil || string(b) != want {
					t.Fatalf("last verified file changed: %s %q %v", file, b, e)
				}
			}
			entries, e := os.ReadDir(filepath.Dir(exe))
			if e != nil || len(entries) != 1 {
				t.Fatalf("failed update left staging files: %v %v", entries, e)
			}
		})
	}
}

func TestManagedCopiesNeverFetch(t *testing.T) {
	home := t.TempDir()
	for _, exe := range []string{
		filepath.Join(home, ".cache/modelplan-cli/0.5.40/modelplan"),
		filepath.Join(home, "Applications/ModelPlan.app/Contents/MacOS/modelplan"),
	} {
		_, err := Apply(context.Background(), exe, home, "0.5.40", "linux/arm64", Pin{}, func(context.Context, string) (io.ReadCloser, error) { t.Fatal("managed copy fetched"); return nil, nil })
		if !errors.Is(err, ErrManaged) {
			t.Fatalf("managed copy accepted: %s %v", exe, err)
		}
	}
	managed := filepath.Join(home, ".cache/modelplan-cli/0.5.40/modelplan")
	if err := os.MkdirAll(filepath.Dir(managed), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(managed, []byte("plugin"), 0700); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(home, "modelplan")
	if err := os.Symlink(managed, link); err != nil {
		t.Skip(err)
	}
	if _, err := Target(link, home); !errors.Is(err, ErrManaged) {
		t.Fatalf("managed symlink accepted: %v", err)
	}
}

func TestPinValidationVersionSkewCancellationAndLock(t *testing.T) {
	for _, raw := range []string{`{}`, `{"latest":"../../escape","sha256":{}}`, `{"latest":"1.2.3","sha256":{"linux/arm64":"bad"}}`} {
		if _, err := ParsePin([]byte(raw)); !errors.Is(err, ErrPin) {
			t.Fatalf("malformed pin accepted: %s %v", raw, err)
		}
	}
	if _, err := ParsePin(nil); !errors.Is(err, ErrNoPin) {
		t.Fatal(err)
	}
	home, exe := fixtureTarget(t)
	archive := fixtureArchive(t, "linux/arm64", "modelplan_linux_arm64/modelplan")
	pin := fixturePin("linux/arm64", archive)
	noFetch := func(context.Context, string) (io.ReadCloser, error) { t.Fatal("unexpected fetch"); return nil, nil }
	if result, err := Apply(context.Background(), exe, home, "9.9.9", "linux/arm64", pin, noFetch); err != nil || result.Status != "up_to_date" {
		t.Fatalf("current pin: %+v %v", result, err)
	}
	if _, err := Apply(context.Background(), exe, home, "0.5.40", "darwin/arm64", pin, noFetch); !errors.Is(err, ErrPlatform) {
		t.Fatalf("missing platform guessed: %v", err)
	}
	if err := os.WriteFile(exe+".update.lock", nil, 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := Apply(context.Background(), exe, home, "0.5.40", "linux/arm64", pin, noFetch); !errors.Is(err, ErrBusy) {
		t.Fatalf("lock ignored: %v", err)
	}
	if err := os.Remove(exe + ".update.lock"); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	_, err := Apply(ctx, exe, home, "0.5.40", "linux/arm64", pin, func(context.Context, string) (io.ReadCloser, error) {
		return io.NopCloser(bytes.NewReader(archive)), nil
	})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("cancellation ignored: %v", err)
	}
	if !newer("0.5.40", "0.5.40-dev") || newer("0.5.39", "0.5.40") {
		t.Fatal("version comparison failed")
	}
}
