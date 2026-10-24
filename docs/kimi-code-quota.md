# Kimi Code quota: documented-only boundary

Kimi Code quota via a user-supplied plan API key is **not supported** in this change. The October 23, 2026 coverage research identified `GET /coding/v1/usages` from monitor implementations, but did **not** verify a public documented plan-key quota-read contract. Its official limits-document candidate could not be accessed during research. This is a verification gap, not a claim that the API does not exist.

Following the documented-only boundary, `modelplan connect kimi` explains this limitation and exits without enabling a provider. There is no opt-in account reader to enable yet: no environment variable is read for a Kimi key, no credential/session/config file is opened, no host is called, and no account identity or key is printed or stored. No Kimi quota account or percentage is synthesized. Unknown quota remains unknown (`--`); the desktop snapshot schema is unchanged. Model Plan does not rewrite or refresh Kimi credentials, send inference requests to probe a limit, or switch models.

The [official Kimi Code overview](https://www.kimi.com/code/docs/) distinguishes the mainland inference base `https://api.kimi.com/coding/v1` from the international base `https://api.kimi.ai/coding/v1`. Those inference base URLs do **not** document `/usages` as a supported plan-key quota API. Neither regional host is called. Kimi Code subscription quota is also distinct from Moonshot Open Platform API cash balance; no Moonshot balance endpoint is substituted.

A different, [officially documented local server API](https://www.kimi.com/code/docs/en/kimi-code-cli/reference/server-api.html) has `GET /api/v1/oauth/usage` on an already-running `kimi web` server. It uses the server's bearer token, not a user-supplied coding-plan API key, and delegates to the managed OAuth account. It is experimental and follows the server's live OpenAPI schema. That is a possible separate runtime integration, outside this requested plan-key adapter; this change does not start it, discover its token, or call it.

To implement a plan-key reader later, first establish a first-party documented passive usage response and regional credential boundary. Then follow the existing native z.ai adapter: explicit per-tool opt-in, fixed region-scoped hosts, user-named environment key, bounded read-only GET, keyed-hash identity only, sanitized cache/errors, and unknown/stale quota handling. Tests must remain handwritten synthetic fixtures and local fake transports. No third-party code or monitor structure was copied for this change, and no real account or vendor endpoint was tested.

## 中文

此改动不支持用用户提供的套餐 API key 读取 Kimi Code 额度。2026-10-23 的研究报告从监控工具实现中找到 `GET /coding/v1/usages`，但未核实有公开文档支持该套餐 key 的额度读取协议；报告尝试的官方限额文档无法访问。这是核实缺口，不表示该接口不存在。

遵循“只实现有文档支持的内容”的边界，`modelplan connect kimi` 明确说明限制并退出，不启用任何来源。不读取 key 环境变量、凭据、会话或配置文件，不调用任何主机，不打印或存储 key/账号身份，不构造额度百分比，未知额度保持 `--`，桌面快照协议不变。不刷新、改写 Kimi 凭据，不调用推理来探测额度，不自动切换模型。

官方文档区分国内 `api.kimi.com` 与国际 `api.kimi.ai` 的推理地址，但这不等于公开承诺 `/usages` 套餐 key 额度接口；两者均不调用。Kimi Code 订阅额度与 Moonshot 开放平台余额不同，不以余额代替。官方本地 `kimi web` 服务另有实验性 `GET /api/v1/oauth/usage`，需要服务令牌并使用托管 OAuth 账号，不属于本次套餐 key 适配；此改动不发现令牌、不启动或调用该服务。将来应先核实第一方文档、地区及凭据边界，再使用显式启用、固定主机、环境变量 key、带密钥哈希身份和合成测试的适配方式。
