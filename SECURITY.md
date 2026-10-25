# Security

ModelPlan's clients are read-only: they download a public, content-hashed publication anonymously and read quota files that Claude Code and Codex already write on your machine. They hold no credentials and upload nothing. Two optional readers go further, each only after you turn it on: a native quota reader (`modelplan connect`) sends the API key you keep in an environment variable to that vendor's usage endpoint and never stores it, and the CodexBar bridge runs CodexBar, which keeps its own sign-ins. To tell subscriptions apart, the CLI reads which account Codex and Claude Code are signed in to (Codex's `account/read`; the account and organization ids in Claude Code's `.claude.json`, which holds no tokens) and keeps only a random local reference for it; `MODELPLAN_IDENTITY=off` turns this off.

## Reporting a vulnerability

Please report security issues privately, not in a public issue: use **Report a vulnerability** on this repository's [Security tab](https://github.com/modelplan/modelplan/security). Include the affected client and version, the impact, and steps to reproduce. You will get a reply within a few days.

Supported versions: the latest release of the CLI and the plugins on `main`.

## 安全问题

请不要在公开 issue 里报告安全问题，使用本仓库 [Security 页](https://github.com/modelplan/modelplan/security) 的 **Report a vulnerability** 私下提交，写明受影响的客户端和版本、影响和复现步骤。
