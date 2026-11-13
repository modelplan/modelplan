// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/desktopcontract"
)

func TestPublicationLineagePassthroughOnlineAndOffline(t *testing.T) {
	for _, mode := range []string{"present", "absent", "partial"} {
		t.Run(mode, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_CACHE", filepath.Join(t.TempDir(), "cache"))
			f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
				var data map[string]json.RawMessage
				if err := json.Unmarshal(doc["data"], &data); err != nil {
					t.Fatal(err)
				}
				var models []map[string]json.RawMessage
				if err := json.Unmarshal(data["models"], &models); err != nil {
					t.Fatal(err)
				}
				if mode == "present" {
					data["selectionRevision"] = publicationJSON(t, "synthetic-selection-v1")
					for i, m := range models {
						m["lineageId"] = publicationJSON(t, "synthetic:line")
						m["lineageStatus"] = publicationJSON(t, []string{"current", "older"}[i])
						m["defaultSelected"] = publicationJSON(t, i == 0)
					}
				} else if mode == "partial" {
					models[0]["lineageId"] = json.RawMessage("null")
					models[0]["lineageStatus"] = json.RawMessage("null")
					models[0]["defaultSelected"] = json.RawMessage("false")
					models[1]["lineageId"] = publicationJSON(t, "synthetic:line")
					models[1]["defaultSelected"] = json.RawMessage("null")
				}
				data["models"] = publicationJSON(t, models)
				doc["data"] = publicationJSON(t, data)
			})
			srv, hits := publicationServer(t, &f)
			t.Setenv("MODELPLAN_BASE", srv.URL)
			for _, args := range [][]string{{"--json"}, {"--json", "--offline"}} {
				code, out, stderr := publicationRun(args...)
				if code != 0 || stderr != "" {
					t.Fatalf("%v: exit=%d stderr=%s", args, code, stderr)
				}
				if err := contracttest.ValidateOutput("publication", []byte(out)); err != nil {
					t.Fatal(err)
				}
				var got map[string]json.RawMessage
				if err := json.Unmarshal([]byte(out), &got); err != nil {
					t.Fatal(err)
				}
				var gotModels, wantModels any
				_ = json.Unmarshal(got["models"], &gotModels)
				_ = json.Unmarshal(f.data["models"], &wantModels)
				if !reflect.DeepEqual(gotModels, wantModels) {
					t.Fatalf("lineage metadata/order/nulls changed: %s", out)
				}
				if string(got["selectionRevision"]) != string(f.data["selectionRevision"]) {
					t.Fatalf("revision added, dropped or changed: %s", out)
				}
				var caps map[string]desktopcontract.Capability
				if err := json.Unmarshal(got["capabilities"], &caps); err != nil {
					t.Fatal(err)
				}
				if caps["lineageSelection"].Status != "publication-dependent" || string(got["contractVersion"]) != "1" {
					t.Fatalf("lineage selection must stay publication-dependent in v1: %s", out)
				}
			}
			if len(*hits) != 3 {
				t.Fatalf("offline passthrough fetched data: %v", *hits)
			}
		})
	}
}
