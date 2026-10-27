package quota

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestKimiChangedInvalidBindingNeverInheritsQuota(t *testing.T) {
	for _, mode := range []string{"expired-B", "jwt-expired-B", "jwt-malformed-B", "missing-device-B", "invalid-device-B", "unsupported-token-B", "malformed-B", "missing-B"} {
		t.Run(mode, func(t *testing.T) {
			p, token := kimiLoginTestPaths(t)
			serverMode := "ok"
			hits := 0
			kimiLoginServer(t, token, &serverMode, &hits)
			if err := RefreshNative(context.Background(), p, kimiNow); err != nil {
				t.Fatal(err)
			}
			root := p.ReaderAccess.Grants["kimi"].Profiles[0].Root
			path := filepath.Join(root, "credentials", "kimi-code.json")
			next := "synthetic-B-access"
			expiry := kimiNow.Add(time.Hour).Unix()
			switch mode {
			case "expired-B":
				expiry = 1
			case "jwt-expired-B":
				claims, _ := json.Marshal(map[string]any{"sub": "synthetic-B-account", "exp": 1})
				next = "e30." + base64.RawURLEncoding.EncodeToString(claims) + ".synthetic-signature"
			case "jwt-malformed-B":
				next = "e30.ew.synthetic-signature"
			case "unsupported-token-B":
				next = "synthetic B unsafe token"
			case "missing-device-B":
				if err := os.Remove(filepath.Join(root, "device_id")); err != nil {
					t.Fatal(err)
				}
			case "invalid-device-B":
				if err := os.WriteFile(filepath.Join(root, "device_id"), []byte("bad/device/B"), 0600); err != nil {
					t.Fatal(err)
				}
			}
			b, _ := json.Marshal(map[string]any{"access_token": next, "expires_at": expiry})
			if err := os.WriteFile(path, b, 0600); err != nil {
				t.Fatal(err)
			}
			if mode == "malformed-B" {
				if err := os.WriteFile(path, []byte(`{"access_token":`), 0600); err != nil {
					t.Fatal(err)
				}
			}
			if mode == "missing-B" {
				if err := os.Remove(path); err != nil {
					t.Fatal(err)
				}
			}
			if err := RefreshNative(context.Background(), p, kimiNow.Add(time.Minute)); err != nil {
				t.Fatal(err)
			}
			if hits != 1 {
				t.Fatal("changed binding bypassed floor")
			}
			if err := RefreshNative(context.Background(), p, kimiNow.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "kimi")
			if hits != 1 || s.Entries[0].Account != nil || s.Entries[0].Metadata.CredentialKey != "" {
				t.Fatal("invalid B inherited A or made request")
			}
			r := Report{}
			applyManaged(&r, p, "kimi", kimiNow.Add(6*time.Minute))
			if len(r.Accounts) != 0 {
				t.Fatal("A numbers still projected")
			}
			if mode == "missing-device-B" {
				if _, err := os.Stat(filepath.Join(root, "device_id")); !os.IsNotExist(err) {
					t.Fatal("missing device recreated")
				}
			}
		})
	}
}

func TestKimiSameGenerationEarlyFailuresRetainCaptureAndBudget(t *testing.T) {
	for _, mode := range []string{"expired", "missing-device"} {
		t.Run(mode, func(t *testing.T) {
			p, token := kimiLoginTestPaths(t)
			serverMode := "ok"
			hits := 0
			kimiLoginServer(t, token, &serverMode, &hits)
			if err := RefreshNative(context.Background(), p, kimiNow); err != nil {
				t.Fatal(err)
			}
			root := p.ReaderAccess.Grants["kimi"].Profiles[0].Root
			if mode == "expired" {
				b, _ := json.Marshal(map[string]any{"access_token": token, "expires_at": 1})
				if err := os.WriteFile(filepath.Join(root, "credentials", "kimi-code.json"), b, 0600); err != nil {
					t.Fatal(err)
				}
			} else if err := os.Remove(filepath.Join(root, "device_id")); err != nil {
				t.Fatal(err)
			}
			if err := RefreshNative(context.Background(), p, kimiNow.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "kimi")
			if hits != 1 || s.Entries[0].Account == nil || !s.Entries[0].Account.ObservedAt.Equal(kimiNow) || NativeDue(p, kimiNow.Add(14*time.Minute)) || kimiBudgetDue(p.Cache, kimiNow.Add(14*time.Minute)) {
				t.Fatal("same-generation capture age or shared timing lost")
			}
		})
	}
}

func TestKimiForgetReconnectRestartRetainsUnionOfGates(t *testing.T) {
	p, token := kimiLoginTestPaths(t)
	mode := "ok"
	hits := 0
	kimiLoginServer(t, token, &mode, &hits)
	if err := RefreshNative(context.Background(), p, kimiNow); err != nil {
		t.Fatal(err)
	}
	if err := ForgetReader(p.Cache, "kimi"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(readerPath(p.Cache, "kimi")); !os.IsNotExist(err) {
		t.Fatal("personal reading not purged")
	}
	g := p.ReaderAccess.Grants["kimi"]
	g.Generation = "reconnected-grant-B"
	p = Paths{Cache: p.Cache, ConnectionsFile: p.ConnectionsFile, ReaderAccess: &ReaderAccess{Grants: map[string]ReaderGrant{"kimi": g}}}
	if NativeDue(p, kimiNow.Add(time.Minute)) || readerAttemptDue(p.Cache, "kimi", kimiNow.Add(time.Minute)) || kimiBudgetDue(p.Cache, kimiNow.Add(time.Minute)) {
		t.Fatal("Forget reset a provider gate")
	}
	if err := RefreshNative(context.Background(), p, kimiNow.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if hits != 1 {
		t.Fatal("Forget/reconnect dispatched early")
	}
	if err := RefreshNative(context.Background(), p, kimiNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if hits != 2 {
		t.Fatal("union of gates never released")
	}
}
