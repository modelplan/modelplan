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

func TestHistoryProviderRequiresSyntheticBaselineAndCannotReplaceBackend(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	source := NewHistorySource(appserver.UnavailableBackend{}, nil).(*fixture)
	if source.valid {
		t.Fatal("provider without baseline admitted")
	}
	if err := os.WriteFile(filepath.Join(home, ".u14-baseline.json"), []byte(`{"shapeSha256":"synthetic"}`), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, ConfigFile), []byte(`{"modelMode":"omitted"}`), 0600); err != nil {
		t.Fatal(err)
	}
	source = NewHistorySource(appserver.UnavailableBackend{}, nil).(*fixture)
	if !source.valid {
		t.Fatal("synthetic provider unavailable")
	}
	if _, ok := any(source).(appserver.Backend); ok {
		t.Fatal("history provider must not implement consent Backend")
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
