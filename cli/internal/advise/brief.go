package advise

import (
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Brief is what the model is handed at the start of a task (the first prompt of a thread): the
// models it could suggest, the current model's effort ladder and the quota headroom. The model
// judges the task; the rules only supply the closed set of published options and their
// arithmetic. Nothing here changes a setting.
type Brief struct {
	Model     string       `json:"model,omitempty"` // current model name, when resolved
	Effort    string       `json:"effort,omitempty"`
	AtRec     bool         `json:"atRecommended"`
	Headroom  string       `json:"headroom,omitempty"`
	Window    string       `json:"window,omitempty"`
	Remaining *float64     `json:"remainingPercent,omitempty"`
	ResetsIn  *int         `json:"resetsInMinutes,omitempty"`
	Models    []BriefModel `json:"models"`
	Ladder    []BriefStep  `json:"ladder,omitempty"`
	// Default is the configuration for ordinary tasks: the published best value at ★, unless
	// it scores more than defaultFloor below the strongest, then the strongest at ★.
	Default       *BriefModel `json:"default,omitempty"`
	DefaultReason string      `json:"defaultReason,omitempty"` // best_value | strongest
	AtDefault     bool        `json:"atDefault,omitempty"`
	DefaultLadder []BriefStep `json:"defaultLadder,omitempty"` // when the thread is on another model
	Speed         *Speed      `json:"speed,omitempty"`
}

type BriefModel struct {
	Name         string   `json:"name"`
	Rec          string   `json:"rec"`
	Ability      float64  `json:"ability"`
	CostRelative float64  `json:"costRelative"`
	Tags         []string `json:"tags,omitempty"`
	Skip         bool     `json:"skip,omitempty"` // dominated or equivalent but costlier
}

// defaultFloor: how far below the strongest the best value may score and still be the default.
const defaultFloor = 3.0

type BriefStep struct {
	Label        string   `json:"label"`
	Recommended  bool     `json:"recommended,omitempty"`
	Current      bool     `json:"current,omitempty"`
	AbilityDelta *float64 `json:"abilityDelta"`
	CostRatio    *float64 `json:"costRatio"`
}

// TaskStart builds the brief for a harness account; nil without publication data for it.
func TaskStart(a *quota.Account, d *digest.Digest, now time.Time) *Brief {
	hn := harnessOf(a.Source)
	if d == nil || hn == "" {
		return nil
	}
	b := &Brief{Headroom: a.Headroom}
	if w := deciding(a); w != nil {
		b.Window, b.Remaining, b.ResetsIn = w.Kind, w.RemainingPercent, w.ResetsInMinutes
	}
	dev := "openai"
	if hn == "claude-code" {
		dev = "anthropic"
	}
	var models []*digest.Model
	if l := d.Lineup(dev); l != nil {
		for _, r := range l.Members {
			m := d.Model(r.ID)
			if m == nil || r.Status != "" || len(m.HarnessIDs[hn]) == 0 {
				continue
			}
			rec := m.Rec()
			label := m.Recommended
			if rec != nil {
				label = rec.Label
			}
			b.Models = append(b.Models, BriefModel{Name: m.Name, Rec: label, Ability: r.Ability, CostRelative: r.CostRelative, Tags: r.Tags,
				Skip: r.DominatedBy != nil || r.Has("dominated") || r.Has("equivalent_costlier")})
			models = append(models, m)
		}
	}
	if len(b.Models) == 0 {
		return nil
	}
	best, strong := -1, -1
	for i, m := range b.Models {
		if m.Skip {
			continue
		}
		if best < 0 && contains(m.Tags, "best_value") {
			best = i
		}
		if strong < 0 && contains(m.Tags, "strongest") {
			strong = i
		}
	}
	def := best
	b.DefaultReason = "best_value"
	if best < 0 || (strong >= 0 && b.Models[strong].Ability-b.Models[best].Ability > defaultFloor) {
		def, b.DefaultReason = strong, "strongest"
	}
	var defModel *digest.Model
	if def >= 0 {
		x := b.Models[def]
		b.Default, defModel = &x, models[def]
	} else {
		b.DefaultReason = ""
	}
	cfg := current(a, d)
	if cfg.model != nil && cfg.cur != nil {
		b.Model, b.Effort, b.AtRec = cfg.model.Name, cfg.cur.Label, cfg.cur == cfg.rec
		b.Ladder = ladder(cfg.model, cfg.rec, cfg.cur)
		b.AtDefault = defModel != nil && cfg.model.ID == defModel.ID && cfg.cur == cfg.rec
		if a.Headroom == "spend" {
			b.Speed = quotaSpeed(cfg, d, a.Source)
		}
	}
	if defModel != nil && (cfg.model == nil || cfg.model.ID != defModel.ID) {
		b.DefaultLadder = ladder(defModel, defModel.Rec(), defModel.Rec())
	}
	return b
}

// ladder: every effort of m against base.
func ladder(m *digest.Model, rec, base *digest.Effort) []BriefStep {
	var out []BriefStep
	for i := range m.Efforts {
		e := &m.Efforts[i]
		s := BriefStep{Label: e.Label, Recommended: e == rec, Current: e == base}
		s.AbilityDelta, s.CostRatio = ratio(e, base)
		out = append(out, s)
	}
	return out
}

// Once reports whether key is new, and remembers it (for "once per thread" context).
func (s *State) Once(key string, now time.Time) bool {
	if _, ok := s.Seen[key]; ok {
		return false
	}
	s.Seen[key] = now.UTC()
	s.changed = true
	return true
}
