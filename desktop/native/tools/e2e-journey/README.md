# Real CLI and app journey in CI

The `e2e-journey` workflow builds the CLI and Community app from the same checkout. Both CLI architectures carry the checked-in version plus `+e2e.<source>` metadata. Packaging explicitly uses an unverified identity. The synthetic Codex installation uses the existing `MODELPLAN_CODEX` and `CODEX_HOME` seams and answers the real stdio app-server protocol. HOME and all tool directories are synthetic; runtime network access is denied.

Two separate hosted macOS jobs run the same assertions:

- `headless` uses the existing `createsNativePanels: false` factory option and ordinary desktop polling. No account-refresh command may be observed.
- `native` calls the normal `ProductionDockFactory.community()` branch used by `CommunityApp`. Actual native panels must be enabled and visible at every checkpoint. Normal visible-account refresh must execute successfully through the real transport, and the app must receive a later snapshot. The driver waits through the normal five-minute refresh cadence if necessary.

Both start through `CommunityApp` → `CommunityApplicationFactory.makeDelegate` → the retained runtime, Settings backend and Dock. The driver uses real first-run `SettingsConnectionController` request/confirmation methods. It does not override clocks or floors, call refresh, seed observed caches, replace transports or supply canned app snapshots.

## Eleven checkpoints

1. Detect the synthetic tools in real first-run controls before any provider reads.
2. Confirm Codex consent through the retained controller.
3. Inspect a connection before its first account read: actual `quota.reason == no-reading`, no account, and a mounted Dock card saying “Waiting for first reading”.
4. Observe a real CLI provider invocation followed by a later app snapshot; native mode additionally requires a successful normal visible-account refresh.
5. Find the fixture's 37% value on the same actual rendered Codex account row, with or without reported subscription membership.
6. Open a fresh subscription-bound row's actual card and require age in minutes/hours, never empty or raw seconds.
7. Confirm revoke and wait for withdrawal of the value.
8. Make the synthetic provider unreadable; require human reason and next step, press the actual card button, and observe presentation of the retained Settings destination.
9. Allow Grok and observe its first native parse error with no account or connection, but exactly one Dock row.
10. Allow Claude with Keychain permission **unset**, default `.claude` directory and no `.credentials.json`. Require no account/value and actual card guidance directing the user to Keychain settings. The driver never grants Keychain access.
11. Allow Z.ai with `Z_AI_API_KEY` absent. Require the actual CLI reason, `Z_AI_API_KEY is not set where modelplan runs`, on the mounted card instead of an endless wait.

Every checkpoint compares the real canonical allowed-tools readback with actual AX rows: each allowed tool must have exactly one row. Every non-fresh allowed row must open its actual card and show human reason and next-step text. Missing/duplicate rows, unknown consent state, raw codes and empty guidance fail. The driver continues through all eleven checkpoints after failures. Artifacts contain bounded observations and fixed human UI copy, not raw CLI/provider output, credentials, emails or account/subscription identifiers.

The H38 extension remains **draft** pending M0's respin6 presentation repairs. Checkpoints 3 and 11 are expected to fail on the starting main revision: the presenter misses connection `quota.reason=no-reading` and hides the missing-key CLI reason behind pending copy. These assertions have no expected-failure waiver. H37's age and native-only first-failure regressions remain covered at checkpoints 6 and 9.

## Runtime isolation and review hooks

The runner reconstructs the environment with a fresh HOME, empty `.claude`/`.zcode` directories, no Claude config override and no API key. Grok's synthetic `auth.json` is malformed and contains no credentials. The inherited sandbox denies all network access, `/usr/bin/security` execution, Keychain file reads/writes and security daemon Mach lookups. No real Keychain probe is performed. The watchdog is twenty minutes to cover normal refresh cadence and later reader stages.

All app hooks require `#if DEBUG && MODELPLAN_E2E_JOURNEY` and both `MODELPLAN_APP_SMOKE=1` and `MODELPLAN_E2E_JOURNEY=1`:

- `CommunityJourneyCI` and `CommunityApplicationFactory.makeConsentPort` admit the real consent port only in this explicit debug CI build. `MODELPLAN_E2E_NATIVE_PANELS=1` selects the native variant. Release identity verification is unchanged.
- `CommunityApp` retains its normal native factory branch; only headless selects the existing no-panel option. The real first-run controller stays hidden through the existing surface factory.
- `StaticDockPreviewHost` observes actual panel capability, canonical provider associations, fixed source/connection states, and mounted card age/reason/next-step labels. Card actions use retained callbacks; no action or destination is installed. Only the fixed missing-key reason is exported by the source observer.
- `ConsentGatedDesktopTransport` counts existing account-refresh attempts/successes and records the last success time. It does not dispatch extra commands or change admission, scheduling or errors.
- `CommunityCLIConsentPort` retains allowed tool IDs from its existing canonical readback and exposes the existing read's exit code/fixed transport category. It captures no output or provider data.
- `E2EJourney` drives retained UI controllers/cards and changes only the synthetic provider's mode file.

`package-neutral.sh --e2e-journey` explicitly selects debug packaging with the macro and unverified metadata. Ordinary release/debug builds exclude the hooks. Even release with the macro excludes them because `DEBUG` is false. Release app-smoke sets the journey environment flag as a negative control: its real unverified consent API must remain unavailable and its thirteen assertions must pass. Macro-enabled Swift tests cover runtime gates, native factory selection, observation shapes and retained card routing; Python tests reject missing evidence and misleading copy.

## Run on an arm64 Mac

Select a supported Xcode and Go from `cli/go.mod`, then use fresh output directories:

```sh
journey_root=$(mktemp -d)
python3 desktop/native/tools/e2e-journey/build.py "$journey_root/build"
python3 desktop/native/tools/e2e-journey/run.py "$journey_root/build" "$journey_root/headless" --variant headless
python3 desktop/native/tools/e2e-journey/run.py "$journey_root/build" "$journey_root/native" --variant native
```

CI uploads `e2e-journey-report-headless` and `e2e-journey-report-native`. CLIJIT owns app–CLI schemas/generated fixtures; this harness consumes actual binary output. This CI qualifies synthetic data flow, not owner accounts, official art or physical interactions.

## 简体中文

`e2e-journey` 在同一提交编译真实 CLI 和 Community App。两个 CLI 架构使用已锁定版本加 `+e2e.<source>` 元数据；封装明确标为未核验。假 Codex 安装仅通过已有 `MODELPLAN_CODEX`、`CODEX_HOME` 接口回答真实 stdio app-server 协议。HOME 和工具目录均为合成目录，运行时拒绝全部网络访问。

两个独立的托管 macOS 作业执行同样的断言：`headless` 使用已有 `createsNativePanels: false` 选项，走普通 desktop 轮询，且不得观察到账户刷新命令；`native` 使用 `CommunityApp` 正常的 `ProductionDockFactory.community()` 分支，每个检查点都要求实际原生面板已启用且可见。正常可见账户刷新必须通过真实传输成功执行，并由 App 接收后续快照；必要时等待正常五分钟刷新间隔。

两者均经过正常入口、实际保留的运行时、Settings 后端和 Dock。驱动调用真实首启控制器的请求／确认方法，不改时钟或速率下限、不直接刷新、不预填读数缓存、不替换传输或 App 快照。

### 十一个检查点

1. 首启控件检测合成工具，此时尚未读取提供方。
2. 通过实际控制器确认 Codex 授权。
3. 首次账户读取前，真实 connection 的 `quota.reason` 为 `no-reading`、账户为零，挂载的 Dock 卡片应显示“等待首次读取”。
4. 真实 CLI 调用提供方后，App 收到更新的快照；原生模式还要求正常可见账户刷新成功。
5. 同一个实际 Codex 账户行显示 37%；未报告订阅关系是合法情况，不会伪造绑定。
6. 打开新鲜且有订阅绑定的真实卡片，年龄必须为分钟／小时，不能留空或输出原始秒数。
7. 确认撤销，等待数值消失。
8. 将假提供方改为不可读，要求原因及下一步，点击实际卡片按钮后，观察到保留的 Settings 目的地再次呈现。
9. 授权 Grok，首次原生解析失败时没有账户或 connection，但实际 Dock 必须恰有一行。
10. 授权 Claude，Keychain 权限保持**未设置**，使用默认 `.claude` 目录且没有 `.credentials.json`。不得产生账户或数值，实际卡片下一步应指向 Keychain 设置。驱动绝不授予 Keychain 权限。
11. 授权 Z.ai，环境中没有 `Z_AI_API_KEY`。实际卡片必须显示 CLI 原因 `Z_AI_API_KEY is not set where modelplan runs`，不能无限等待。

每个检查点均以真实 canonical 已允许工具回读与实际 AX 行对照：每个允许工具恰有一行。所有非新鲜的已允许行都必须能打开实际卡片，并显示人类可读的原因和下一步。缺行、重复行、未知授权状态、原始错误码或空文案均失败。失败后继续收集全部十一阶段；产物只含有界观察与固定界面文案，不含原始 CLI／提供方响应、凭据、邮箱或账户／订阅标识。

H38 扩展在 M0 respin6 修复前保持**草稿**。起始 main 的第3、11阶段预计失败：呈现层漏读 connection 的 `quota.reason=no-reading`，并将缺少密钥的 CLI 原因隐藏为等待文案。不设置预期失败豁免。H37 的年龄与仅原生来源首次失败回归分别保留在第6、9阶段。

### 隔离与测试入口

运行器重建环境，使用新 HOME、空 `.claude`／`.zcode` 目录，不设置 Claude 配置覆盖或 API 密钥。Grok 的损坏合成 `auth.json` 不含凭据。子进程继承沙箱：拒绝全部网络、执行 `/usr/bin/security`、读写 Keychain 文件及查询 security daemon Mach 服务。不执行真实 Keychain 探测。看门狗为二十分钟，以容纳正常刷新间隔及后续阶段。

所有 App 入口均受 `DEBUG && MODELPLAN_E2E_JOURNEY` 编译条件和两个运行标志共同保护：`MODELPLAN_APP_SMOKE=1`、`MODELPLAN_E2E_JOURNEY=1`。`MODELPLAN_E2E_NATIVE_PANELS=1` 选择原生模式。`CommunityApp` 保留正常原生工厂分支，仅 headless 模式选择已有无面板选项；通过已有 surface 工厂隐藏真实首启窗口。Host 观察实际面板能力、行关联、固定来源／connection 状态和真实挂载卡片的年龄／原因／下一步，不安装替代动作。来源观察仅导出固定缺密钥原因。传输观察器仅对已有刷新调用计数并记录成功时间，不增加命令，不改授权、调度或错误行为。consent 观察器只读取已有 canonical 结果；驱动仅使用保留的控制器／卡片并修改假提供方模式文件。

只有 `package-neutral.sh --e2e-journey` 选择带宏的 debug 构建和未核验元数据。普通 debug／release 不含入口；即使 release 意外收到宏，也因 `DEBUG` 为假而排除。release app-smoke 设置 journey 标志作反向验证，未核验 consent API 必须仍不可用，十三条断言保持通过。带宏 Swift 测试覆盖运行标志、原生工厂选择、观察数据形状和实际卡片路由；Python 反例检查缺失证据与误导文案。

### 在 arm64 Mac 上运行

选择支持的 Xcode 和 `cli/go.mod` 指定的 Go 后，执行上方命令；两个 variant 使用不同输出目录。CI 分别上传 `e2e-journey-report-headless`、`e2e-journey-report-native`。CLIJIT 负责 App–CLI schema／生成夹具，本测试消费真实二进制输出。此 CI 仅验证合成数据流，不代表真实账户、官方视觉或物理交互验收。
