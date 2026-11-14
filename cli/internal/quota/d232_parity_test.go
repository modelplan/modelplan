// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// D232: Codex set to Bedrock or a custom provider has its own cause, read-only from config.toml.
func TestD232CodexCustomProviderIsItsOwnCause(t *testing.T) {
	rpcError := `[ "$1" = app-server ] || exit 2
while IFS= read -r line; do
  echo '{"id":1,"error":{"message":"codex account authentication required to read rate limits"}}'
done
`
	cases := []struct{ name, config, want string }{
		{"no config", "", "rpc_error"},
		{"openai provider", "model_provider = \"openai\"\n", "rpc_error"},
		{"bedrock", "model_provider = \"amazon-bedrock\"\n", "codex_custom_provider"},
		{"custom provider", "model = \"m\"\nmodel_provider = \"corp\"\n\n[model_providers.corp]\nname = \"Corp gateway\"\nbase_url = \"https://gateway.example.invalid/v1\"\n", "codex_custom_provider"},
		{"custom provider with ChatGPT login", "model_provider = \"proxy\"\n[model_providers.proxy]\nrequires_openai_auth = true\n", "rpc_error"},
		{"provider only inside a profile table", "[profiles.work]\nmodel_provider = \"corp\"\n", "rpc_error"},
		{"malformed", "model_provider = [\n", "rpc_error"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			isolateHome(t)
			home := os.Getenv("CODEX_HOME")
			if c.config != "" {
				if err := os.MkdirAll(home, 0o700); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(home, "config.toml"), []byte(c.config), 0o600); err != nil {
					t.Fatal(err)
				}
			}
			before, _ := os.ReadFile(filepath.Join(home, "config.toml"))
			cache := t.TempDir()
			_ = RefreshCodexAccount(context.Background(), cache, codexScript(t, rpcError), acctNow)
			s := loadAccount(cache)
			if s == nil || s.Status == "ok" || s.ErrorCode != c.want || s.failureCode() != c.want {
				t.Fatalf("snapshot %+v, want cause %q", s, c.want)
			}
			if got := codexFailureState(s); got != "unavailable:reader_error:"+c.want {
				t.Fatalf("state %q", got)
			}
			after, _ := os.ReadFile(filepath.Join(home, "config.toml"))
			if string(before) != string(after) {
				t.Fatal("config.toml changed")
			}
			b, _ := os.ReadFile(accountPath(cache))
			for _, canary := range []string{"corp", "gateway.example.invalid", "amazon-bedrock", "authentication required"} {
				if strings.Contains(string(b), canary) {
					t.Fatalf("snapshot keeps config or provider text %q", canary)
				}
			}
		})
	}
	if codexUsesCustomProvider("relative/.codex") {
		t.Fatal("relative CODEX_HOME accepted")
	}
}

// D232: a Grok team login whose usage the billing endpoint does not report says so; an auth
// refusal or a transient failure keeps its own code, and a personal login is unchanged.
func TestD232GrokTeamLoginSaysTeamUsageIsUnsupported(t *testing.T) {
	cases := []struct{ name, principal, mode, want string }{
		{"team refused", "team", "refused", "team_unsupported"},
		{"team empty billing", "Team", "empty", "team_unsupported"},
		{"team rejected keeps auth code", "team", "rejected", "http_401"},
		{"team rate limited keeps its code", "team", "limited", "http_429"},
		{"personal refused stays generic", "user", "refused", "other"},
		{"personal empty stays schema", "", "empty", "schema_changed"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p := grokTestPaths(t)
			writeGrokAuth(t, os.Getenv("GROK_HOME"), grokAuth{Key: "synthetic-grok-access", Mode: "oidc", User: "synthetic-grok-user", Issuer: "https://auth.x.ai", Client: grokDefaultClient, Expires: grokNow.Add(48 * time.Hour).Format(time.RFC3339), PrincipalType: c.principal, Principal: "synthetic-principal", Team: "synthetic-team"})
			mode, hits := c.mode, 0
			grokTestServer(t, &mode, &hits)
			if err := RefreshNative(context.Background(), p, grokNow); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "grok")
			if hits != 1 || len(s.Entries) != 1 || s.Entries[0].Status == "ok" || s.Entries[0].ErrorCode != c.want {
				t.Fatalf("hits %d entry %+v, want %q", hits, s.Entries, c.want)
			}
			assertGrokPrivate(t, p.Cache)
		})
	}
}
