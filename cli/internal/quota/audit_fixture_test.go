package quota

import (
	"github.com/modelplan/modelplan/cli/internal/detect"
	"testing"
)

// Only synthetic helper processes used by these unit tests are audited here.
// This does not certify the upstream helper or alter the bundled catalogue.
func auditFixtureHelpers(t *testing.T, p *Paths) {
	t.Helper()
	p.CLIVersion = "1.0.0"
	cat := &detect.Catalogue{SchemaVersion: 1, Revision: 1}
	for id := range CodexBarProviders {
		e := detect.Entry{ProviderID: id, ReaderID: "codexbar:" + id, Preferred: "codexbar", MinCLI: "0.0.0", Beta: true}
		e.CodexBar.Audited = true
		e.CodexBar.AccessClass = "standard"
		cat.Detectors = append(cat.Detectors, e)
	}
	old := loadReaderCatalogue
	loadReaderCatalogue = func(cache string) *detect.Catalogue {
		if cache == p.Cache {
			return cat
		}
		return old(cache)
	}
	t.Cleanup(func() { loadReaderCatalogue = old })
}
