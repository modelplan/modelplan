package render

import (
	"testing"

	"github.com/modelplan/modelplan/cli/internal/advise"
)

func TestHintNamesReserve(t *testing.T) {
	e := advise.Event{Source: "codex", Window: "weekly", Limit: "reserve"}
	if got := (Style{T: ZH}).who(e); got != "Codex 每周 Reserve" {
		t.Errorf("zh who = %q", got)
	}
}
