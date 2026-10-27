package main

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
)

const browserExplanation = "Advanced browser-session access is separate from standard consent. CodexBar reads this provider's browser sign-in. On macOS it may ask for the browser's Safe Storage key, which unlocks that browser's saved sign-ins. CodexBar keeps the session cookie in its own Keychain item. Forget readings revokes access, deletes ModelPlan readings and runs CodexBar's cookie-cache clear for this provider. No token refresh is allowed."

func consentHosts(provider, region string) []string {
	// Native destinations are compiled reader capabilities. Helper destinations
	// follow the pinned CodexBar provider docs at ee890b5, not remote URLs to run.
	switch provider {
	case "claude":
		return []string{"https://api.anthropic.com"}
	case "codex":
		return []string{"https://chatgpt.com (Codex runtime)"}
	case "cursor":
		return []string{"https://cursor.com", "https://api2.cursor.sh"}
	case "zai":
		if region == "bigmodel-cn" {
			return []string{"https://open.bigmodel.cn"}
		}
		return []string{"https://api.z.ai"}
	case "kimi":
		if region == "" {
			region = "china"
		}
		return []string{quota.KimiHost(region)}
	case "minimax":
		if region == "" {
			region = "international"
		}
		return []string{quota.MiniMaxHost(region)}
	case "opencodego":
		return []string{"https://opencode.ai"}
	case "copilot":
		return []string{"https://api.github.com (Copilot runtime; enterprise host follows runtime configuration)"}
	case "gemini":
		return []string{"https://cloudcode-pa.googleapis.com"}
	case "qwen":
		return []string{"none (local records only)"}
	case "kiro":
		return []string{"https://codewhisperer.us-east-1.amazonaws.com", "https://q.eu-central-1.amazonaws.com (Kiro runtime/profile region)"}
	case "windsurf":
		return []string{"https://windsurf.com"}
	case "devin":
		return []string{"https://app.devin.ai"}
	case "augment":
		return []string{"https://app.augmentcode.com"}
	case "qoder":
		return []string{"https://qoder.com", "https://qoder.com.cn (selected region)"}
	case "perplexity":
		return []string{"https://www.perplexity.ai"}
	case "manus":
		return []string{"https://api.manus.im"}
	case "mistral":
		return []string{"https://admin.mistral.ai", "https://console.mistral.ai"}
	}
	return nil
}

func catalogueEntry(st *store.Store, id string) (detect.Entry, bool) {
	cat := detect.Fallback()
	if d, _, err := publication.Load(st); err == nil && d.Catalogue != nil {
		cat = d.Catalogue
	}
	for _, e := range cat.Detectors {
		if e.ProviderID == id {
			return e, true
		}
	}
	return detect.Entry{}, false
}

func setChoiceRegion(row *consentChoice, region, keyEnv string) {
	row.Access = strings.TrimSuffix(row.Access, " Destinations / 凭据接收主机: "+strings.Join(row.Hosts, ", "))
	row.Hosts = consentHosts(row.Tool, region)
	row.Region = region
	row.KeyEnv = keyEnv
	if region != "" {
		row.Access += " Region / 地区: " + region
	}
	if keyEnv != "" {
		row.Access += " Explicit key variable / 显式 key 变量: " + keyEnv
	}
	row.Access += " Destinations / 凭据接收主机: " + strings.Join(row.Hosts, ", ")
}

func connectProvider(args []string, stdin io.Reader, stdout, stderr io.Writer, st *store.Store, c common, backend, region, keyEnv, privacy string, browser bool) int {
	if len(args) != 1 || !consent.ValidTool(strings.ToLower(args[0])) {
		fmt.Fprintln(stderr, "usage: modelplan connect <tool> [--browser-session] [--json]")
		return exitUsage
	}
	id := strings.ToLower(args[0])
	if id == "claude-code" {
		id = "claude"
	}
	state, err := consent.Load(consent.Path())
	if err != nil {
		fmt.Fprintln(stderr, err)
		return exitErr
	}
	if privacy != "" {
		if privacy != consent.Automatic && privacy != consent.Passive {
			fmt.Fprintln(stderr, "privacy must be automatic or passive")
			return exitUsage
		}
		state.Privacy = privacy
	}
	mode := state.Effective(env("MODELPLAN_READERS", ""))
	e, known := catalogueEntry(st, id)
	if known && e.Preferred == "off" {
		fmt.Fprintln(stderr, "connect: provider is disabled by the catalogue")
		return exitUsage
	}
	if browser || backend == "codexbar" || backend == quota.BackendCodexBar {
		if !known || e.Preferred != "codexbar" || e.HelperStatus() != "" {
			fmt.Fprintln(stderr, "connect: no audited, supported CodexBar route for this provider")
			return exitUsage
		}
		if (e.CodexBar.Access == "browser-session") != browser {
			fmt.Fprintln(stderr, "connect: browser-session providers require --browser-session explicitly")
			return exitUsage
		}
		if !detect.Compatible(version, e.MinCLI) {
			fmt.Fprintln(stderr, "update to read", e.DisplayName)
			return exitUsage
		}
		backend = "codexbar"
		if region != "" || keyEnv != "" {
			fmt.Fprintln(stderr, "connect: region/key-env select native readers only")
			return exitUsage
		}
	} else {
		if backend != "native" {
			fmt.Fprintln(stderr, "connect: --backend is native or codexbar")
			return exitUsage
		}
		if _, _, ok := quota.NativeReader(id); !ok && (!known || e.Preferred != "native") {
			fmt.Fprintln(stderr, "connect: unsupported provider")
			return exitUsage
		}
		e.ProviderID = id
		e.ReaderID = "native:" + id
		e.Preferred = "native"
		if e.DisplayName == "" {
			e.DisplayName = quota.ProviderName(id)
		}
	}
	source := quota.QuotaSource{Provider: id, Backend: quota.BackendNative, Enabled: true, Region: region, KeyEnv: keyEnv}
	if backend == "native" && quota.ProviderName(id) != "" {
		if err := quota.ValidateSource(source); err != nil {
			fmt.Fprintln(stderr, err)
			return exitUsage
		}
	}
	row := choice(detect.Tool{Entry: e, Detected: true}, mode)
	row.Access = strings.TrimSuffix(row.Access, " Destinations / 凭据接收主机: "+strings.Join(row.Hosts, ", "))
	row.Hosts = consentHosts(id, region)
	row.Region = region
	row.KeyEnv = keyEnv
	if region != "" {
		row.Access += " Region / 地区: " + region
	}
	if keyEnv != "" {
		row.Access += " Explicit key variable / 显式 key 变量: " + keyEnv
	}
	if id == "kimi" {
		row.Access += " " + quota.KimiEndpointNotice + " No key was read or request sent; docs/kimi-code-quota.md."
	}
	if id == "minimax" {
		row.Access += " " + quota.MiniMaxEndpointNotice + " Missing keys remain no-key; no key was read."
	}
	row.Access += " Selected destinations / 本次主机: " + strings.Join(row.Hosts, ", ")
	if browser {
		row.Access = browserExplanation + " Destinations / 主机: " + strings.Join(row.Hosts, ", ")
		row.Group = "advanced"
		row.Status = "available"
	}
	if len(row.Hosts) == 0 {
		row.Status = "provider-hosts-unknown"
	}
	if mode == consent.Off || (backend == "codexbar" && mode != consent.Automatic) {
		row.Status = "privacy-blocked"
	}
	row.Selected = row.Status == "available"
	if c.json {
		return printJSON(stdout, map[string]any{"schemaVersion": 1, "dryRun": true, "consentTextVersion": consent.TextVersion, "consentText": consent.Text, "privacy": state.Privacy, "effectivePrivacy": mode, "tools": []consentChoice{row}, "browserSession": browser})
	}
	if !row.Selected {
		fmt.Fprintln(stderr, "connect:", row.Status)
		return exitUsage
	}
	fmt.Fprintln(stdout, consent.Text)
	fmt.Fprintln(stdout, row.Name, "·", row.Access)
	if browser {
		fmt.Fprintln(stdout, "高级浏览器会话：macOS 可能请求浏览器 Safe Storage 密钥，可解锁该浏览器保存的登录；CodexBar 会把会话 cookie 保存在自己的钥匙串项目中。忘记读数时会清除此提供商的 cookie 缓存。")
	}
	fmt.Fprint(stdout, "Allow this provider? / 允许此提供商？ [y/N]: ")
	if stdin == nil {
		fmt.Fprintln(stdout, "Not now; no permissions changed.")
		return 0
	}
	scan := bufio.NewScanner(io.LimitReader(stdin, 8192))
	if !scan.Scan() {
		return 0
	}
	answer := strings.ToLower(strings.TrimSpace(scan.Text()))
	if answer != "y" && answer != "yes" {
		return 0
	}
	err = consent.Change(consent.Path(), func(current *consent.State) error {
		if current.Generation != state.Generation {
			return errors.New("consent changed while choosing; retry")
		}
		current.Privacy = state.Privacy
		// Keep existing API-key/region configuration, without starting a reader.
		if err := consent.Set(current, id, true, e.ReaderID, backend, time.Now()); err != nil {
			return err
		}
		record := current.Tools[id]
		record.Region = region
		record.KeyEnv = keyEnv
		record.BrowserSession = browser
		record.BrowserCookieCache = record.BrowserCookieCache || browser
		current.Tools[id] = record
		return nil
	})
	if err != nil {
		fmt.Fprintln(stderr, err)
		return exitErr
	}
	if backend == "native" && quota.ProviderName(id) != "" {
		if err := quota.SetConnection(quotaPaths(st).ConnectionsFile, source); err != nil {
			fmt.Fprintln(stderr, err)
			return exitErr
		}
	}
	fmt.Fprintln(stdout, "Consent saved; no reader was run. / 已保存授权；未运行读取器。")
	return 0
}
