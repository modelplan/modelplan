# Real CLI and app journey in CI

The `e2e-journey` workflow builds the CLI and Community app from one clean checkout. Both CLI architectures carry the checked-in version plus `+e2e.<source>` build metadata. The packager uses unverified identity metadata; it does not mint a reviewed release identity. The provider is a synthetic Codex installation behind the existing `MODELPLAN_CODEX` and `CODEX_HOME` seams, answering the real stdio app-server protocol. Runtime network access is denied, HOME and tool directories are synthetic, and no login/credential is needed.

The app starts through `CommunityApp` → `CommunityApplicationFactory.makeDelegate` → the retained normal runtime/Settings backend/Dock. The driver uses the actual first-run `SettingsConnectionController` request/confirmation methods. Native panels are disabled through the existing production factory argument, so the normal store uses its ordinary desktop poll rather than its visible-account refresh shortcut. No clock/floor override, direct refresh command, observed-cache write, alternate transport or canned app snapshot makes the journey pass.

The eight `e2e step N PASS|FAIL <facts>` lines cover detection in real first-run controls, confirmed consent, CLI background provider invocation followed by a later app snapshot, the actual rendered Codex account row with the fixture's 37% value (with or without a reported subscription reference), fresh bound-card observation age in minutes/hours, confirmed revoke and value withdrawal, unreadable-provider presentation with a human reason, a press of its real card button, and a new presentation of the retained Settings/first-run destination. The final stage grants Grok and waits for its first native parse failure without any account or connection. Every checkpoint also requires exactly one rendered Dock row per tool in the last actual canonical allowed-tools readback. Failures remain failures, including on current main. Artifacts contain bounded aggregate observations and fixed human UI copy, not raw provider/CLI responses, emails or subscription identifiers.

## Hooks requiring M4/M0 review

All app hooks are inside `#if DEBUG && MODELPLAN_E2E_JOURNEY` and require both `MODELPLAN_APP_SMOKE=1` and `MODELPLAN_E2E_JOURNEY=1`:

- `CommunityJourneyCI` and `CommunityApplicationFactory.makeConsentPort` admit the real consent port only in this explicit debug CI build. Release identity verification is unchanged.
- `CommunityApp` selects the production factory's existing headless panel option, keeps the real first-run controller hidden through its existing surface factory, and starts the driver alongside normal app startup.
- `StaticDockPreviewHost` additionally observes canonical provider associations per rendered row, fixed native-only first-failure counts and the actual mounted card age label. It exposes the retained model/timestamp and per-row AX readout joined to that row’s reported account windows. Disabled flags return no observations. Its card driver uses the retained row action and actual card enter button; it never installs an action or destination.
- `CommunityCLIConsentPort` observes allowed logical tool IDs from its existing successful canonical readback, retaining the last observation across read failures for cardinality checks. It also exposes the actual read command's exit code or fixed transport-error category. It keeps the same single invocation and error behavior; no output, path or provider data is captured.
- `E2EJourney` drives only the retained UI controller and changes only the synthetic provider's mode file. It never asks the CLI to refresh or edits a ModelPlan cache.

`package-neutral.sh --e2e-journey` explicitly builds debug with the macro and unverified metadata. Ordinary release and ordinary debug builds do not include the hooks. Even a release build accidentally receiving the macro excludes them because `DEBUG` is false. The existing release app-smoke launcher deliberately sets the journey environment flag as a negative control: its real unverified consent API must stay disabled and the existing 13 assertions must pass.

The normal entry now gives consent its own real `BundledCLI` transport. Its startup inspection used to share the runtime poll’s single active-process slot and failed `busy` before detection. No admission rule, command, JSON field or identity check changes. The actual first-run journey guards this production fix. Macro-enabled Swift tests additionally cover each missing runtime flag, absent subscription membership, a broken card `onEnter`, and a disabled retained Settings item; Python negative controls reject unrelated row/value combinations.

## Run on an arm64 Mac

With Go from `cli/go.mod` and a supported Xcode selected, use fresh output directories:

```sh
journey_root=$(mktemp -d)
python3 desktop/native/tools/e2e-journey/build.py "$journey_root/build"
python3 desktop/native/tools/e2e-journey/run.py "$journey_root/build" "$journey_root/report"
```

The build command explicitly chooses debug CI packaging; release packaging remains the default everywhere else. The runner creates its own synthetic HOME and denies all runtime network access.

CLIJIT owns the app–CLI schemas/generated fixtures. Coordination is in the shared integration discussion; this harness consumes actual binary output rather than hand-written CLI snapshots. Updating the CLI contract belongs with its schema/fixture changes. This CI path qualifies synthetic data flow only; it does not certify owner accounts, official art or physical interactions.


## 简体中文

`e2e-journey` 在同一干净提交上编译真实 CLI 和 Community App；两个 CLI 架构的版本使用已锁定版本加 `+e2e.<source>`。封装仍明确标为未核验，绝不伪造已审核的发行身份。假 Codex 安装仅通过已有 `MODELPLAN_CODEX`、`CODEX_HOME` 接口回答真实 stdio app-server 协议。运行时禁用全部网络，HOME 与工具目录均为新建合成目录，不需要登录或凭据。

测试运行正常 `CommunityApp` → `CommunityApplicationFactory.makeDelegate` → 实际保留的运行时、Settings 后端与 Dock。授权和忘记读数使用真实首启控制器的请求／确认方法。仅通过工厂已有参数关闭原生面板，让实际 store 使用普通 desktop 轮询，而非可见账户的直接刷新捷径。不预填读数缓存、不替换传输／快照、不手动刷新、不改时钟或速率下限。

八条 `e2e step N PASS|FAIL <facts>` 依次验证：首启界面检测并列出工具；真实确认授权；CLI 后台访问假提供方并被后续 App 快照接收；同一个实际渲染的 Codex 账户行显示 37%；新鲜且有订阅绑定的真实卡片以分钟／小时显示观测年龄；确认撤销并移除数值；提供方不可读时显示人类可读的原因和下一步，点击该行实际卡片按钮后确实再次呈现同一 Settings／首启目的地。账户没有 `subscriptionRef` 是合法状态，不会为通过测试而捏造订阅关系，也不能把无关订阅与另一个行的数值拼成通过。最后一阶段授权 Grok 并等待首次原生解析失败，期间没有 Grok 账户或 connection。每个检查点还从真实 canonical 回读取得全部已允许工具，严格验证每个工具恰有一条实际渲染的 Dock 行。失败始终保持红色。产物仅含有界聚合事实、枚举类别及固定界面文案，不含原始提供方／CLI 响应、邮箱、凭据或账户／订阅标识。

### 需 M4/M0 审阅的测试入口

所有 App 测试入口必须同时满足编译条件 `DEBUG && MODELPLAN_E2E_JOURNEY`，并同时设置 `MODELPLAN_APP_SMOKE=1`、`MODELPLAN_E2E_JOURNEY=1`：

- `CommunityJourneyCI` 与 `makeConsentPort` 仅在此显式 debug CI 构建中开放真实 consent API；发行身份验证保持严格。
- `CommunityApp` 使用已有无面板工厂选项，通过已有 surface 工厂隐藏真实首启窗口，并与正常启动并行运行驱动。
- `StaticDockPreviewHost` 还观察每条实际渲染行的工具关联、仅原生来源首次失败的固定计数，以及真实卡片挂载的年龄文案；读取实际保留的模型、时间戳、每行 AX 数值和账户窗口关联；任一运行标志缺失时不返回观察结果。卡片驱动走保留的行回调及实际 enter 按钮，不安装替代动作或目的地。
- `CommunityCLIConsentPort` 从原有成功 canonical 回读观察已允许的逻辑工具 ID，并保留上次观察用于行数检查；还报告原有单次调用的退出码或固定传输错误类别，不保存输出、路径或提供方数据，也不改变错误行为。
- `E2EJourney` 仅驱动已保留的真实控制器／卡片，并修改假提供方自己的模式文件，从不直接刷新 CLI 或编辑 ModelPlan 缓存。

`package-neutral.sh --e2e-journey` 才会选择带宏的 debug 构建和未核验元数据。普通 release、普通 debug 均不包含测试入口；即使 release 意外收到该宏，也因 `DEBUG` 为假而排除。原有 release app-smoke 故意设置 journey 标志作反向验证，未核验的 consent API 必须仍不可用，原有 13 条断言必须通过。带宏的 Swift 回归覆盖两个缺失标志、无订阅账户行、断开的卡片 `onEnter` 与禁用的实际 Settings 菜单；Python 反例覆盖错误的跨行数值关联。

正常入口另为 consent 构造一个真实 `BundledCLI`，修复首启检查与运行时轮询争用单进程槽、以 `busy` 失败的问题。它不修改授权规则、命令、JSON 字段或身份校验；真实首启 CI 为此生产修复提供防复发检查。

### 在 arm64 Mac 上运行

选择支持的 Xcode，并安装 `cli/go.mod` 要求的 Go 后，使用全新输出目录：

```sh
journey_root=$(mktemp -d)
python3 desktop/native/tools/e2e-journey/build.py "$journey_root/build"
python3 desktop/native/tools/e2e-journey/run.py "$journey_root/build" "$journey_root/report"
```

该 build 命令显式选择 debug CI 封装；其他场景的默认封装仍为 release。运行器自行创建合成 HOME 并拒绝所有运行时网络访问。

CLIJIT 负责 App–CLI schema 与真实二进制生成的夹具；本测试直接消费同提交真实 CLI 的输出，不另造 App 快照。合同变动需连同其 schema／夹具一起更新。此 CI 仅证明合成数据路径，不代表真实账户、官方视觉或物理交互验收。


## H37 draft regression coverage / H37 草稿回归

This extension deliberately remains draft while the respin5 presentation repairs are pending. Stage 5 fails if the fresh subscription-bound Codex card omits age or prints seconds. Stage 8 uses the real CLI's existing Grok profile seam with malformed, credential-free `auth.json`; it requires an error-class `native:grok` source (`parse_error`), zero Grok accounts/connections, and exactly one rendered Grok row with human reason and next step. It never adds an account, connection, subscription reference or observed cache. The normal app poll and background native reader create the evidence. The runtime watchdog is 13 minutes to include the extra normal-poll stage; provider floors and clocks are unchanged.

The one-row invariant runs independently at all eight checkpoints against the actual canonical allowed-tools readback and actual AX rows. Missing rows, duplicate rows or unknown consent observations fail. The driver continues collecting all eight stages after a failure. No expected-failure exemption or assertion waiver is used; production presenters and age formatting remain owned by M0/M4. These failures on main are the purpose of this draft.

此扩展在 respin5 呈现修复到位前明确保持草稿。第5阶段检查真实、新鲜且有订阅绑定的 Codex 卡片：年龄为空或使用原始秒数均失败。第8阶段通过真实 CLI 已有的 Grok profile 接口读取不含凭据的损坏 `auth.json`，要求 `native:grok` 出现错误状态（`parse_error`）、Grok 账户／connection 均为零，同时实际 Dock 恰有一条带人类可读原因和下一步的 Grok 行。不会添加账户、connection、订阅引用或读数缓存；证据必须由正常 App 轮询和 CLI 后台原生读取产生。运行看门狗扩为13分钟以容纳新增普通轮询阶段，不改提供方速率下限或时钟。

八个检查点分别以真实 canonical 已允许工具回读和实际 AX 行检查一工具一行；缺行、重复行或未知授权观察均失败。失败后仍继续收集全部八阶段结果。不设置预期失败豁免，也不放宽断言；生产呈现及年龄格式修复仍由 M0/M4 负责。暴露 main 上的这些失败正是本草稿的目的。
