// SPDX-License-Identifier: MIT
package rows

// Per-tool sign-in and install commands (D232). The commands are the tools' own, as
// CodexBar's provider messages name them (steipete/CodexBar
// 7447bc77c2497323d9c41e40164ce705533493c8, MIT; notice in desktop/third-party/NOTICES.md):
// "Run `codex login`", "Run `claude` to authenticate", "Run 'gemini' in Terminal",
// "Run `grok login`", "Run 'kiro-cli login'", and the install lines for npm, the Grok
// install script and kiro.dev. ModelPlan never runs them; the app offers them to copy.
type toolCommands struct {
	signIn, install, installURL string
}

var commands = map[string]toolCommands{
	"codex":  {signIn: "codex login", install: "npm i -g @openai/codex"},
	"claude": {signIn: "claude", install: "npm i -g @anthropic-ai/claude-code", installURL: "https://code.claude.com/docs/en/overview"},
	"gemini": {signIn: "gemini", install: "npm i -g @google/gemini-cli"},
	"grok":   {signIn: "grok login", install: "curl -fsSL https://x.ai/cli/install.sh | bash"},
	"kiro":   {signIn: "kiro-cli login", installURL: "https://kiro.dev"},
}

// toolHint returns the sign-in hint for a signed-out or rejected login and the install hint
// for a missing tool; any other cause, or a tool without a known command, has none.
func toolHint(tool string, code Code) *Hint {
	c, ok := commands[tool]
	if !ok {
		return nil
	}
	switch code {
	case CodeNotSignedIn, CodeLoginExpired, CodeHTTP401:
		if c.signIn == "" {
			return nil
		}
		return &Hint{SignInCommand: c.signIn, Text: Text{EN: "To sign in, run this in Terminal", ZH: "在终端运行这条命令登录"}}
	case CodeNotFound, CodeToolNotFound, CodeRuntimeMissing:
		switch {
		case c.install != "":
			return &Hint{InstallCommand: c.install, InstallURL: c.installURL, Text: Text{EN: "To install it, run this in Terminal", ZH: "在终端运行这条命令安装"}}
		case c.installURL != "":
			return &Hint{InstallURL: c.installURL, Text: Text{EN: "Install it from its website", ZH: "从官网下载安装"}}
		}
	}
	return nil
}
