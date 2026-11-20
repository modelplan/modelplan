package render

import (
	"bytes"
	"encoding/json"
	"os"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/digest"
)

// A client-v1.6 pending row has no efforts and no ★; every view prints it without one.
func TestPendingModelRendersWithoutEfforts(t *testing.T) {
	data, err := os.ReadFile("../../../testdata/client-v1.6/example.json")
	if err != nil {
		t.Fatal(err)
	}
	b, _ := json.Marshal(map[string]any{"schemaVersion": 1, "kind": "client", "data": json.RawMessage(data)})
	d, err := digest.Parse("client", b)
	if err != nil {
		t.Fatal(err)
	}
	m := d.Model("astra-6.2")
	if m == nil || m.Rec() != nil {
		t.Fatal("pending row missing or recommended")
	}
	for _, s := range []Style{{T: EN}, {T: ZH, Color: true}} {
		var out bytes.Buffer
		s.Effort(&out, m)
		if !strings.Contains(out.String(), m.Name) {
			t.Fatalf("effort view = %q", out.String())
		}
		for _, effort := range []string{"", "medium"} {
			if line := s.Statusline(d, m, effort, false, "gpt-6.2-astra", false); !strings.Contains(line, Short(m.Name)) {
				t.Fatalf("statusline = %q", line)
			}
		}
		out.Reset()
		if err := s.Lineup(&out, d, "openai"); err != nil {
			t.Fatal(err)
		}
	}
}
