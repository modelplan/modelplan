// SPDX-License-Identifier: MIT
package consent

import (
	"path/filepath"
	"testing"
	"time"
)

func TestAdmissionIsImmutable(t *testing.T) {
	state := Empty()
	state.Generation = 7
	state.Tools["claude"] = Record{Allowed: true, ConsentTextVersion: TextVersion, Profiles: []string{"default"}, DeniedSources: map[string]bool{"keychain": true}}
	state.Requests = map[string]Receipt{"request": {PendingForget: []string{"claude"}}}
	admission := NewAdmission(state, Automatic)
	state.Requests["request"].PendingForget[0] = "codex"
	record := state.Tools["claude"]
	record.Profiles[0] = "changed"
	record.DeniedSources[Local] = true
	delete(state.Tools, "claude")
	copy := admission.State()
	if !admission.CleanupPending("claude") || admission.CleanupPending("codex") || copy.Requests != nil || copy.Tools["claude"].Profiles[0] != "default" || !admission.Allows("claude", Local) || admission.Generation() != 7 {
		t.Fatalf("input mutation reached admission: %+v", copy)
	}
	record = copy.Tools["claude"]
	record.Profiles[0] = "changed again"
	record.DeniedSources[Local] = true
	delete(copy.Tools, "claude")
	if !admission.Allows("claude", Local) || admission.State().Tools["claude"].Profiles[0] != "default" {
		t.Fatal("projection mutation reached admission")
	}
	if (Admission{}).Allows("claude", Local) || NewAdmission(Empty(), "invalid").Allows("claude", Local) {
		t.Fatal("uninitialized admission did not fail closed")
	}
}

func TestBuildStableDiscardsRevokedPublication(t *testing.T) {
	for _, changes := range []int{1, 2} {
		t.Run(map[int]string{1: "retry", 2: "fail-closed"}[changes], func(t *testing.T) {
			home := t.TempDir()
			t.Setenv("HOME", home)
			t.Setenv("MODELPLAN_READERS", "automatic")
			if err := Change(Path(), func(s *State) error { return Set(s, "claude", true, "native:claude", "native", time.Now()) }); err != nil {
				t.Fatal(err)
			}
			type publication struct {
				Generation         uint64
				ToolValue, Pending bool
			}
			attempts, failures := 0, 0
			result := BuildStable(func(a Admission) publication {
				attempts++
				// Represents a reader value already copied into the full snapshot.
				value := publication{Generation: a.Generation(), ToolValue: a.Allows("claude", Credential)}
				if attempts <= changes {
					if err := Change(filepath.Join(home, ".config", "modelplan", "consent.json"), func(s *State) error { return Set(s, "claude", false, "", "", time.Now()) }); err != nil {
						t.Fatal(err)
					}
				}
				return value
			}, func(a Admission) publication {
				failures++
				return publication{Generation: a.Generation(), Pending: true}
			})
			if attempts != 2 || result.ToolValue || result.Generation != uint64(1+changes) || result.Pending != (changes == 2) || failures != changes-1 {
				t.Fatalf("discarded result escaped: attempts=%d failures=%d result=%+v", attempts, failures, result)
			}
		})
	}
}
