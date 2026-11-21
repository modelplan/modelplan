// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"testing"
	"time"
)

// S6 (#1031 sampling, GLM-2): with ZCode installed without provider_config.json, a selected and
// admitted pasted GLM key is a working route. After the key is replaced, the status before the next
// due request is "missing / not read yet"; ZCode's missing-file fallback must not rewrite it to
// unsupported_login.
func TestS6PastedKeyKeepsNotReadYetBesideZCodeWithoutProviderFile(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeDesktopLayout(t, home)
	ks := &keyServer{body: zaiOKBody}
	useClient(t, ks.serve(t), "api.z.ai")
	p := nativePaths(t)
	p.ZCodeNoProviderFile = true // what production sets for this layout
	if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil {
		t.Fatal(err)
	}
	refreshWith(t, p, "zai")
	if err := SetManualKey(p.Cache, "zai", "replacement-key", "global"); err != nil {
		t.Fatal(err)
	}
	entry := loadNative(p.Cache).Providers[0]
	if entry.NativeNextAttemptAt == nil {
		t.Fatalf("fixture has no deadline: %+v", entry)
	}
	var r Report
	applyNative(&r, p, entry.NativeNextAttemptAt.Add(-time.Minute))
	s, ok := zaiSource(r)
	if !ok || s.Status != "missing" || s.Reason != "not read yet" || s.ErrorCode == "unsupported_login" {
		t.Fatalf("pasted-key route reported as %+v (found=%t)", s, ok)
	}
}
