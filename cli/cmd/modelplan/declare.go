package main

import (
	"fmt"
	"io"
	"slices"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// declareCmd: `modelplan declare <planId> [generation]` records which plan the user has in
// ~/.config/modelplan/local.json (--remove takes it out). With the publication at hand, the plan
// and generation must be ones it meters, and a plan metered more than one way needs the
// generation, so advice never runs on a guess.
func declareCmd(args []string, stdout, stderr io.Writer, st *store.Store, c common, remove bool) int {
	if len(args) < 1 || len(args) > 2 {
		fmt.Fprintln(stderr, "usage: modelplan declare <planId> [generation]   |   modelplan declare --remove <planId>")
		return exitUsage
	}
	plan, gen := args[0], ""
	if len(args) == 2 {
		gen = args[1]
	}
	en := c.lang == "en"
	if d, _, _ := publication.Load(st); d != nil && d.PlanMetering != nil && !remove {
		gens := d.Generations(plan)
		switch {
		case len(gens) == 0:
			fmt.Fprintf(stderr, "declare: %s is not a plan with published metering\n", plan)
			return exitUsage
		case gen == "" && len(gens) > 1:
			fmt.Fprintf(stderr, "declare: %s is metered %d ways; add one of: %s\n", plan, len(gens), strings.Join(gens, ", "))
			return exitUsage
		case gen != "" && !slices.Contains(gens, gen):
			fmt.Fprintf(stderr, "declare: %s has no generation %q; published: %s\n", plan, gen, strings.Join(gens, ", "))
			return exitUsage
		}
	}
	p := quotaPaths(st)
	if err := quota.DeclarePlan(p.LocalFile, plan, gen, remove); err != nil {
		fmt.Fprintln(stderr, "declare:", err)
		return exitErr
	}
	switch {
	case remove && en:
		fmt.Fprintf(stdout, "Removed %s from %s.\n", plan, p.LocalFile)
	case remove:
		fmt.Fprintf(stdout, "已从 %s 移除 %s。\n", p.LocalFile, plan)
	case en:
		fmt.Fprintf(stdout, "Recorded %s%s in %s; advice for sessions on its models follows how it counts usage.\n", plan, genText(gen), p.LocalFile)
	default:
		fmt.Fprintf(stdout, "已在 %s 记下 %s%s；用它的模型时，建议按这个套餐的计量方式给出。\n", p.LocalFile, plan, genText(gen))
	}
	return 0
}

func genText(g string) string {
	if g == "" {
		return ""
	}
	return " (" + g + ")"
}

// declareNotice: shown to the user (never the model), once per model, when a session runs
// another vendor's model on a plan the user has not declared: which plans meter it, and the
// command that records it. Nothing is guessed.
func declareNotice(m *digest.Model, plans []digest.MeteredPlan, endpoint, cli string, en bool) string {
	plans = byEndpoint(plans, endpoint)
	gens := map[string][]string{}
	var ids []string
	for _, p := range plans {
		if _, ok := gens[p.PlanID]; !ok {
			ids = append(ids, p.PlanID)
		}
		if p.Generation != "" {
			gens[p.PlanID] = append(gens[p.PlanID], p.Generation)
		}
	}
	or, open, close, sep := " 或 ", "（", "）", "；"
	if en {
		or, open, close, sep = " or ", " (", ")", "; "
	}
	var opts []string
	for _, id := range ids {
		if g := gens[id]; len(g) > 0 {
			opts = append(opts, id+open+strings.Join(g, or)+close)
		} else {
			opts = append(opts, id)
		}
	}
	if en {
		return "ModelPlan: this session runs " + m.Name + " on your plan with its vendor, not on Claude's. Which plan is not declared, so there are no quota hints for it. " +
			"To declare it, run `" + cli + " declare <plan> <generation>` in a terminal: " + strings.Join(opts, sep) + " (legacy plans count prompts per 5 hours and week; credit plans count credits)."
	}
	return "ModelPlan：这个会话用的 " + m.Name + " 走你在那家厂商的套餐，不是 Claude 的。还不知道是哪个套餐，所以没有它的额度提示。" +
		"在终端运行 `" + cli + " declare <套餐> <代际>` 说明：" + strings.Join(opts, sep) + "（legacy 按 5 小时和每周的次数计，credits 按积分计）。"
}

// endpointPlans: which plan ids a known vendor endpoint can bill, to keep the question short
// (Z.ai's global endpoint is never a China or OpenCode plan). Only the question uses it; the
// user's answer is recorded as given.
var endpointPlans = map[string]string{
	"https://api.z.ai/api/anthropic":         "zhipu-global-",
	"https://open.bigmodel.cn/api/anthropic": "zhipu-cn-",
}

func byEndpoint(plans []digest.MeteredPlan, endpoint string) []digest.MeteredPlan {
	prefix := endpointPlans[digest.Endpoint(endpoint)]
	if prefix == "" {
		return plans
	}
	var out []digest.MeteredPlan
	for _, p := range plans {
		if strings.HasPrefix(p.PlanID, prefix) {
			out = append(out, p)
		}
	}
	if len(out) == 0 {
		return plans
	}
	return out
}
