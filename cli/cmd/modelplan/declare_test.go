package main

import (
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/digest"
)

func TestDeclareNoticeNamesOnlyWhatTheEndpointCanBill(t *testing.T) {
	isolateHome(t)
	m := &digest.Model{ID: "glm", Name: "GLM-5.3"}
	plans := []digest.MeteredPlan{{PlanID: "opencode-go"}, {PlanID: "zhipu-cn-pro", Generation: "legacy-v2"},
		{PlanID: "zhipu-global-pro", Generation: "credits-2026"}, {PlanID: "zhipu-global-pro", Generation: "legacy-v2"}}
	got := declareNotice(m, plans, "https://api.z.ai/api/anthropic/", "/x/modelplan", true)
	if !strings.Contains(got, "in a terminal: zhipu-global-pro (credits-2026 or legacy-v2) (") || strings.Contains(got, "opencode") || strings.Contains(got, "zhipu-cn") {
		t.Fatalf("notice = %s", got)
	}
	if !strings.HasPrefix(got, "ModelPlan: ") || !strings.Contains(got, "run `/x/modelplan declare <plan> <generation>`") {
		t.Fatalf("notice = %s", got)
	}
	if got := declareNotice(m, plans, "https://api.z.ai/api/anthropic", "modelplan", false); !strings.Contains(got, "说明：zhipu-global-pro（credits-2026 或 legacy-v2）（") {
		t.Fatalf("zh notice = %s", got)
	}
	if got := declareNotice(m, plans, "https://proxy.example", "modelplan", true); !strings.Contains(got, "opencode-go; zhipu-cn-pro (legacy-v2); zhipu-global-pro") {
		t.Fatalf("unknown endpoint keeps every option: %s", got)
	}
}
