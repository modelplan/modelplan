// SPDX-License-Identifier: MIT
package publication

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"slices"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/store"
)

const calendarBudget = 8 << 20

func supplement(m manifest, name string, b []byte) (json.RawMessage, error) {
	ref := m.Components[name]
	if ref.SchemaVersion != 1 || len(b) > calendarBudget || int64(len(b)) != ref.Bytes || sum(b) != ref.Hash {
		return nil, errors.New("calendar: hash or size mismatch")
	}
	var envelope struct {
		SchemaVersion int               `json:"schemaVersion"`
		Kind          string            `json:"kind"`
		Dependencies  map[string]string `json:"dependencies"`
		Data          json.RawMessage   `json:"data"`
	}
	if json.Unmarshal(b, &envelope) != nil || envelope.SchemaVersion != 1 || envelope.Kind != name || len(envelope.Data) == 0 {
		return nil, errors.New("calendar: invalid envelope")
	}
	expected := []string{"plans"}
	if name == "calendar" {
		expected = append(expected, "rules")
	}
	if len(envelope.Dependencies) != len(expected) {
		return nil, errors.New("calendar: incompatible dependencies")
	}
	for _, dependency := range expected {
		if envelope.Dependencies[dependency] != m.Components[dependency].Hash {
			return nil, errors.New("calendar: dependency mismatch")
		}
	}
	return envelope.Data, nil
}

func readSupplement(s *store.Store, m manifest, name string) ([]byte, error) {
	ref := m.Components[name]
	if ref.Bytes <= 2 || ref.Bytes > calendarBudget || ref.SchemaVersion != 1 {
		return nil, errors.New("calendar: unavailable")
	}
	f, err := os.Open(s.ObjectPath(ref.Hash))
	if err != nil {
		return nil, err
	}
	defer f.Close()
	b, err := io.ReadAll(io.LimitReader(f, calendarBudget+1))
	if err != nil {
		return nil, err
	}
	_, err = supplement(m, name, b)
	return b, err
}

// syncCalendar is best effort. An unavailable optional calendar never discards
// a valid client; it simply leaves the next rate unknown outside its horizon.
func (c *Client) syncCalendar(ctx context.Context, m manifest, keep map[string]bool) {
	data := map[string]json.RawMessage{}
	objects := map[string][]byte{}
	for _, name := range []string{"rules", "calendar"} {
		ref := m.Components[name]
		if ref.Bytes <= 2 || ref.Bytes > calendarBudget || ref.SchemaVersion != 1 {
			return
		}
		b, err := readSupplement(c.Store, m, name)
		if err != nil {
			b, _, _, err = c.getLimit(ctx, "/publications/objects/"+ref.Hash+".json", "", calendarBudget)
			if err != nil {
				return
			}
		}
		payload, err := supplement(m, name, b)
		if err != nil {
			return
		}
		data[name], objects[name] = payload, b
	}
	if _, _, _, err := digest.CalendarIntervals(data["rules"], data["calendar"]); err != nil {
		return
	}
	for name, b := range objects {
		ref := m.Components[name]
		if c.Store.PutObject(ref.Hash, b) == nil {
			keep[ref.Hash] = true
		}
	}
}

func attachCalendar(s *store.Store, m manifest, d *digest.Digest) {
	rules, err := readSupplement(s, m, "rules")
	if err != nil {
		return
	}
	calendar, err := readSupplement(s, m, "calendar")
	if err != nil {
		return
	}
	r, _ := supplement(m, "rules", rules)
	c, _ := supplement(m, "calendar", calendar)
	intervals, from, to, err := digest.CalendarIntervals(r, c)
	if err != nil {
		return
	}
	scoped := []digest.MultiplierWindow{}
	for _, interval := range intervals {
		if len(interval.PlanIDs) > 0 {
			scoped = append(scoped, interval)
			continue
		}
		// Raw calendar rules may name plans only through published timeRules.
		// Keep each generation separate rather than inventing an all-plan scope.
		if d.PlanMetering == nil {
			continue
		}
		for _, plan := range d.PlanMetering.Plans {
			if !slices.Contains(plan.TimeRules, interval.RuleID) || len(interval.Generations) > 0 && !slices.Contains(interval.Generations, plan.Generation) {
				continue
			}
			bound := interval
			bound.PlanIDs = []string{plan.PlanID}
			if plan.Generation != "" {
				bound.Generations = []string{plan.Generation}
			}
			scoped = append(scoped, bound)
		}
	}
	d.CalendarIntervals, d.CalendarFrom, d.CalendarTo = scoped, from, to
}

// Backfill an older cache on an explicit/interval sync even if the pointer did
// not change. Cache-only Load never fetches or writes a missing supplement.
func (c *Client) syncCachedCalendar(ctx context.Context, st store.State) {
	mb, err := os.ReadFile(c.Store.ManifestPath(st.PublicationID))
	if err != nil || sum(mb) != st.ManifestHash {
		return
	}
	var m manifest
	if json.Unmarshal(mb, &m) != nil || m.PublicationID != st.PublicationID {
		return
	}
	c.syncCalendar(ctx, m, map[string]bool{})
}

// LoadWindows is the cache-only public calendar view. Ordinary publication,
// quota, hook and status-line reads do not parse the larger supplement.
func LoadWindows(s *store.Store) (*digest.Digest, store.State, error) {
	d, st, err := Load(s)
	if err != nil {
		return d, st, err
	}
	mb, err := os.ReadFile(s.ManifestPath(st.PublicationID))
	if err != nil || sum(mb) != st.ManifestHash {
		return d, st, nil
	}
	var m manifest
	if json.Unmarshal(mb, &m) == nil && m.PublicationID == d.PublicationID {
		attachCalendar(s, m, d)
	}
	return d, st, nil
}
