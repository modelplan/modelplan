// SPDX-License-Identifier: MIT
package main

import (
	"testing"

	"github.com/modelplan/modelplan/cli/internal/digest"
)

func TestAllCockpitModelsListsThePublicationBeyondTheLineup(t *testing.T) {
	if got := allCockpitModels(nil); len(got) != 0 {
		t.Fatalf("no publication: %+v", got)
	}
	foreign := &digest.Digest{Source: "other", Models: []digest.Model{{ID: "a"}}}
	if got := allCockpitModels(foreign); len(got) != 0 {
		t.Fatalf("unverified source: %+v", got)
	}
	ability := 40.0
	models := []digest.Model{}
	for _, id := range []string{"a", "b", "c", "d", "a"} {
		models = append(models, digest.Model{ID: id, Name: "Synthetic " + id, DeveloperID: "openai", Recommended: "medium", Efforts: []digest.Effort{{Effort: "medium", Label: "Med", Ability: &ability}}})
	}
	models = append(models, digest.Model{ID: "e", Name: "", DeveloperID: "openai"})
	got := allCockpitModels(&digest.Digest{Source: digest.ComponentClient, Models: models})
	if len(got) != 4 || got[0].ID != "a" || got[3].ID != "d" {
		t.Fatalf("models = %+v", got)
	}
}
