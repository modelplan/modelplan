package main

import (
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/digest"
)

func TestDeclareAskNamesOnlyWhatTheEndpointCanBill(t *testing.T) {
	m := &digest.Model{ID: "glm", Name: "GLM-5.3"}
	plans := []digest.MeteredPlan{{PlanID: "opencode-go"}, {PlanID: "zhipu-cn-pro", Generation: "legacy-v2"},
		{PlanID: "zhipu-global-pro", Generation: "credits-2026"}, {PlanID: "zhipu-global-pro", Generation: "legacy-v2"}}
	got := declareAsk(m, plans, "https://api.z.ai/api/anthropic/", "/x/modelplan")
	if !strings.Contains(got, "which of these they have: zhipu-global-pro (credits-2026 or legacy-v2).") || strings.Contains(got, "opencode") || strings.Contains(got, "zhipu-cn") {
		t.Fatalf("ask = %s", got)
	}
	if !strings.Contains(got, "run `/x/modelplan declare <planId> <generation>`") || !strings.Contains(got, "Never guess the plan.") {
		t.Fatalf("ask = %s", got)
	}
	if got := declareAsk(m, plans, "https://proxy.example", "modelplan"); !strings.Contains(got, "opencode-go; zhipu-cn-pro (legacy-v2); zhipu-global-pro") {
		t.Fatalf("unknown endpoint keeps every option: %s", got)
	}
}
