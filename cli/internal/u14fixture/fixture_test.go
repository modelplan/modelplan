// SPDX-License-Identifier: MIT
package u14fixture

import (
	"context"
	"net/http"
	"os"
	"path/filepath"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver"
)

func TestFixtureRequiresSyntheticBaselineAndLeavesProductionTimeouts(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	config := Config("synthetic")
	if _, ok := config.Backend.(appserver.UnavailableBackend); !ok {
		t.Fatal("fixture without baseline did not fail closed")
	}
	if err := os.WriteFile(filepath.Join(home, ".u14-baseline.json"), []byte(`{"shapeSha256":"synthetic"}`), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, ConfigFile), []byte(`{"modelMode":"omitted","emptyState":""}`), 0600); err != nil {
		t.Fatal(err)
	}
	config = Config("synthetic")
	if _, ok := config.Backend.(*fixture); !ok {
		t.Fatal("synthetic fixture unavailable")
	}
	if config.WriteTimeout != 0 || config.RequestTimeout != 0 {
		t.Fatal("fixture replaced production timeout defaults")
	}
}
func TestRecordingTransportRefusesAnyUnlistedDestinationOrMethod(t *testing.T) {
	f := &fixture{home: t.TempDir()}
	transport := &recordingTransport{fixture: f}
	for _, target := range []struct{ method, url string }{
		{"POST", "https://provider.invalid/history"},
		{"GET", "https://other.invalid/history"},
		{"GET", "https://provider.invalid/inference"},
		{"GET", "https://provider.invalid/history?refresh=true"},
		{"GET", "http://provider.invalid/history"},
	} {
		request, err := http.NewRequestWithContext(context.Background(), target.method, target.url, nil)
		if err != nil {
			t.Fatal(err)
		}
		if _, err = transport.RoundTrip(request); err == nil {
			t.Fatal("unlisted provider call admitted")
		}
	}
	if _, err := os.Stat(filepath.Join(f.home, EventsFile)); !os.IsNotExist(err) {
		t.Fatal("refused request was recorded as an admitted call")
	}
}
