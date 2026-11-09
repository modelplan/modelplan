// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanWire

@MainActor final class ScopeConsentButton: NSButton {
    var invoke: (@MainActor () async -> Void)?
    init(title: String, id: String, invoke: @escaping @MainActor () async -> Void) {
        self.invoke = invoke; super.init(frame: .zero)
        self.title = title; bezelStyle = .rounded; setAccessibilityIdentifier(id)
        target = self; action = #selector(pressed)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    @objc private func pressed() {
        guard isEnabled, !isHiddenOrHasHiddenAncestor, window?.isVisible == true, let invoke else { return }
        Task { await invoke() }
    }
    func retire() { invoke = nil; target = nil; action = nil; isEnabled = false }
}

/// Native scope surface. Constructing or rerendering it never sends a command.
@MainActor public final class SettingsScopeConsentView: NSStackView {
    private let controller: ScopeConsentController
    private var language: SettingsLanguage
    private let buildSigning:ScopeConsentBuildSigning
    /// G3-25: the first-run page shows only what FR-9 lists (paths, select all, allow);
    /// diagnostics, plugins and revoke/forget stay in Settings.
    public let firstRun: Bool
    /// G3-45: the vendor mark for a tool id, supplied by the app (the same checked marks as the Dock).
    private let markImage: (@MainActor (String) -> NSImage?)?
    private var observer: UUID?
    private var buttons: [NSButton] = []
    private var wrappingLabels: [NSTextField] = []
    public init(controller: ScopeConsentController, language: SettingsLanguage = .chinese,
                buildSigning:ScopeConsentBuildSigning = .current, firstRun: Bool = false,
                markImage: (@MainActor (String) -> NSImage?)? = nil) {
        self.controller = controller; self.language = language;self.buildSigning=buildSigning; self.firstRun = firstRun
        self.markImage = markImage
        super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 8
        setAccessibilityIdentifier("settings.scopeConsent")
        observer = controller.observe { [weak self] in self?.render() }; render()
    }
    /// Follow the shared Settings editor language without changing any draft.
    public func apply(language: SettingsLanguage) {
        guard self.language != language else { return }
        self.language = language; render()
    }
    /// Retire this presentation before detaching it from the accepted-event sink.
    public func retirePresentation() {
        if let observer { controller.removeObserver(observer); self.observer = nil }
        for button in buttons {
            (button as? ScopeConsentButton)?.retire(); (button as? ConnectionButton)?.retire()
        }
        buttons = []
        for view in arrangedSubviews { removeArrangedSubview(view); view.removeFromSuperview() }
    }
    public func suspend() { retirePresentation();controller.clearAcceptedPrivateState() }
    /// Wrapping labels take the column width so long copy wraps instead of spilling (G3-25/26).
    public override func layout() {
        super.layout()
        for label in wrappingLabels {
            let width = label.bounds.width
            if width > 0, abs(label.preferredMaxLayoutWidth - width) > 0.5 {
                label.preferredMaxLayoutWidth = width; label.invalidateIntrinsicContentSize()
            }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    deinit {
        if let observer { let controller = controller; Task { @MainActor in controller.removeObserver(observer) } }
    }
    private func label(_ text: SettingsText, secondary: Bool = false, heading: Bool = false) {
        let field = NSTextField(wrappingLabelWithString: text.value(language))
        field.font = heading ? .systemFont(ofSize: 13, weight: .semibold) : .systemFont(ofSize: secondary ? 12 : 13)
        if secondary { field.textColor = .secondaryLabelColor }
        field.lineBreakMode = .byWordWrapping; field.maximumNumberOfLines = 0
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addArrangedSubview(field); wrappingLabels.append(field)
        field.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }
    /// One horizontal line of related buttons, in reading order.
    private func line(_ views: [NSView]) {
        let row = NSStackView(views: views); row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 8
        addArrangedSubview(row)
    }
    private func gap() { if let last = arrangedSubviews.last { setCustomSpacing(16, after: last) } }
    private func button(_ text: SettingsText, id: String, enabled: Bool = true,
                        action: @escaping @MainActor () async -> Void) -> ScopeConsentButton {
        let value = ScopeConsentButton(title: text.value(language), id: id, invoke: action)
        value.isEnabled = enabled; buttons.append(value); return value
    }
    private func synchronousButton(_ text: SettingsText, id: String, enabled: Bool = true,
                                   action: @escaping @MainActor () -> Void) -> ConnectionButton {
        let value = ConnectionButton(title: text.value(language), identifier: id, invoke: action)
        value.isEnabled = enabled; buttons.append(value); return value
    }
    private func scopeTitle(_ scope: WireConsentScope) -> SettingsText {
        let name = ["gemini": "Gemini", "cursor": "Cursor", "codex": "Codex", "claude": "Claude Code",
                    "zai": "Z.ai", "opencode": "OpenCode", "minimax": "MiniMax", "kimi": "Kimi"][scope.tool]
        let tool = name.map { SettingsText($0, $0) } ?? .init("Other tool", "其他工具")
        let route: SettingsText
        switch scope.route {
        case .savedLoginApi: route = .init("Existing sign-in usage", "使用已有登录读取用量")
        case .runtimeRpc: route = .init("Owning-tool runtime usage", "所属工具运行时用量")
        case .localLog, .localSqlite: route = .init("Local history", "本地历史")
        case .apiKeyApi: route = .init("Configured API-key usage", "已配置密钥的用量")
        case .statusLine: route = .init("Tool status-line readings", "工具状态栏读数")
        case .browserSession: route = .init("Browser-session usage", "浏览器会话用量")
        case .manual: route = .init("Manually supplied readings", "手动提供的读数")
        case .knownUnknown, .unknown: route = .init("Unrecognized reading path", "尚不识别的读取路径")
        }
        return .init(tool.english + " · " + route.english, tool.chinese + " · " + route.chinese)
    }
    /// Activity reading is separate from usage reading and is always disclosed (D27).
    private static let activityDisclosure = SettingsText("Local session files are read to show tool activity. Their contents are not uploaded.",
                                                         "读取本地会话文件以显示工具活动状态，文件内容不会上传。")
    /// G3-45 (owner 2026-11-08, Pulse reference): the first-run page lists each tool found on this
    /// Mac with a checkbox, says what is read and whether macOS may ask for the Keychain, and shows
    /// why a tool cannot be read. Done sends the choices as the one first-run consent.
    private func renderFirstRunChooser() {
        label(.init("Choose which tools ModelPlan reads", "选择要读取的工具"), heading: true)
        arrangedSubviews.last?.setAccessibilityIdentifier("scope.firstRun.heading")
        label(.init("Your choice is saved when you press Done; you can change it later in Settings › Data & Privacy.",
                    "点“完成”后保存选择，之后可在 设置 › 数据与隐私 中更改。"), secondary: true)
        arrangedSubviews.last?.setAccessibilityIdentifier("scope.firstRun.notice")
        let tools = controller.firstRunTools
        if controller.facts == nil {
            label(.init("Looking for tools on this Mac…", "正在查找本机的工具…"), secondary: true)
            arrangedSubviews.last?.setAccessibilityIdentifier("scope.firstRun.looking")
        } else if tools.isEmpty {
            label(.init("No supported tools were found on this Mac. You can finish now.", "本机没有找到支持的工具，可以直接完成。"), secondary: true)
            arrangedSubviews.last?.setAccessibilityIdentifier("scope.firstRun.none")
        }
        for (index, tool) in tools.enumerated() {
            if index > 0 { separator() }
            toolRow(tool)
        }
        if !controller.firstRunChoiceSatisfied {
            label(.init("Tick at least one tool to continue.", "请至少勾选一个工具。"))
            arrangedSubviews.last?.setAccessibilityIdentifier("scope.firstRun.pickOne")
        }
        gap()
        label(.init("Tools you install later are read by default. Turn any of them off in Settings › Data & Privacy.",
                    "之后安装的工具默认会读取，可在 设置 › 数据与隐私 中关闭。"), secondary: true)
        arrangedSubviews.last?.setAccessibilityIdentifier("scope.firstRun.later")
        label(Self.activityDisclosure, secondary: true)
    }
    private func separator() {
        let line = NSBox(); line.boxType = .separator
        addArrangedSubview(line)
        line.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }
    private static let markSize: CGFloat = 20, boxWidth: CGFloat = 18
    private func toolRow(_ tool: FirstRunTool) {
        let id = tool.tool
        let box = synchronousButton(.init("", ""), id: "scope.firstRun.tool." + id, enabled: controller.canMutate && tool.canRead) { [weak self] in
            guard let self else { return }
            self.controller.chooseFirstRunTool(id, chosen: !self.controller.isFirstRunToolChosen(id))
        }
        box.setButtonType(.switch); box.title = ""; box.state = controller.isFirstRunToolChosen(id) ? .on : .off
        box.setAccessibilityLabel(Self.toolName(id).value(language))
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: Self.boxWidth).isActive = true
        let mark = markView(id)
        let name = NSTextField(labelWithString: Self.toolName(id).value(language))
        name.font = .systemFont(ofSize: 14, weight: .semibold)
        name.setAccessibilityIdentifier("scope.firstRun.name." + id)
        let tag = NSTextField(labelWithString: SettingsText("Detected on this Mac", "本机已检测到").value(language))
        tag.font = .systemFont(ofSize: 11); tag.textColor = .secondaryLabelColor
        let title = NSStackView(views: [name, tag]); title.orientation = .horizontal; title.alignment = .firstBaseline; title.spacing = 8
        let column = NSStackView(views: [title]); column.orientation = .vertical; column.alignment = .leading; column.spacing = 3
        func line(_ text: SettingsText, id lineID: String, color: NSColor = .secondaryLabelColor) {
            let field = NSTextField(wrappingLabelWithString: text.value(language))
            field.font = .systemFont(ofSize: 12); field.textColor = color
            field.lineBreakMode = .byWordWrapping; field.maximumNumberOfLines = 0
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            field.setAccessibilityIdentifier(lineID)
            column.addArrangedSubview(field); wrappingLabels.append(field)
            field.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }
        // An unsupported login is not read at all, so its row says only why (D52).
        if tool.canRead { line(Self.readLine(tool), id: "scope.firstRun.reads." + id) }
        if let block = tool.block {
            line(Self.blockLine(block, tool: id), id: "scope.firstRun.status." + id, color: .systemOrange)
        } else if !tool.canRead {
            // Only browser-session or unrecognised paths: never describe a read that will not happen.
            line(Self.unreadableLine, id: "scope.firstRun.status." + id)
        }
        let row = NSStackView(views: [box, mark, column]); row.orientation = .horizontal; row.alignment = .top; row.spacing = 10
        row.setAccessibilityIdentifier("scope.firstRun.row." + id)
        addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        column.widthAnchor.constraint(equalTo: row.widthAnchor, constant: -(Self.boxWidth + Self.markSize + 2 * row.spacing)).isActive = true
    }
    /// The vendor's own mark, drawn in the label colour like the rest of the page; two letters
    /// when no checked mark is available (as on the Quota Widget, G3-32).
    private func markView(_ tool: String) -> NSView {
        let view: NSView
        if let image = markImage?(tool) {
            image.isTemplate = true
            let imageView = NSImageView(image: image); imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.contentTintColor = .labelColor
            view = imageView
        } else {
            let letters = NSTextField(labelWithString: String(Self.toolName(tool).english.prefix(2)))
            letters.font = .systemFont(ofSize: 10, weight: .semibold); letters.alignment = .center
            letters.textColor = .secondaryLabelColor
            view = letters
        }
        view.setAccessibilityElement(false)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: Self.markSize).isActive = true
        view.heightAnchor.constraint(equalToConstant: Self.markSize).isActive = true
        return view
    }
    /// Display names follow the engine's row titles.
    static func toolName(_ tool: String) -> SettingsText {
        let names = ["claude": "Claude Code", "codex": "Codex", "cursor": "Cursor", "copilot": "GitHub Copilot", "gemini": "Gemini CLI",
                     "grok": "Grok Build", "kimi": "Kimi Code", "zai": "ZCode / GLM", "qwen": "Qwen", "opencodego": "OpenCode Go",
                     "opencode": "OpenCode", "kiro": "Kiro", "amp": "Amp", "droid": "Droid", "antigravity": "Antigravity", "minimax": "MiniMax"]
        return names[tool].map { SettingsText($0, $0) } ?? .init("Other tool", "其他工具")
    }
    static let unreadableLine = SettingsText("ModelPlan can't read this tool's sign-in on this Mac yet.", "暂不支持读取这个工具在本机的登录。")
    private static let noKeychain = SettingsText(" No Keychain prompt.", "不会弹出钥匙串授权。")
    private static let mayAskKeychain = SettingsText(" macOS may ask once for Keychain access; choose \u{201C}Always Allow\u{201D}.",
                                                     "macOS 可能会询问一次钥匙串权限，请选“始终允许”。")
    /// One plain line per tool: what is read, then whether macOS may ask for the Keychain. The
    /// Keychain part follows the paths' access class (D61), not the vendor.
    static func readLine(_ tool: FirstRunTool) -> SettingsText {
        let base: SettingsText
        switch tool.tool {
        case "claude":
            base = .init("Reads the Claude Code sign-in saved in its credentials file or the Keychain, and its local history.",
                         "读取 Claude Code 保存在凭据文件或钥匙串里的登录，以及本机历史记录。")
        case "codex":
            base = .init("Asks Codex's own app server for usage with the sign-in Codex saved, and reads its local history.",
                         "通过 Codex 自带的后台服务，用它已保存的登录查询用量，并读取本机历史记录。")
        case "cursor":
            base = .init("Reads the sign-in Cursor saved in its local database, and its local history.",
                         "读取 Cursor 本地数据库里保存的登录，以及本机历史记录。")
        case "grok":
            base = .init("Reads the sign-in Grok saved in ~/.grok, and its local history.",
                         "读取 Grok 保存在本机的登录，以及本机历史记录。")
        case "kiro":
            base = .init("Asks the Kiro CLI for usage with the sign-in Kiro saved. ModelPlan does not read or keep Kiro's credentials.",
                         "调用 Kiro 命令行工具查询用量，沿用它已保存的登录。ModelPlan 不读取也不保存 Kiro 的凭据。")
        case "zai":
            base = .init("Reads the GLM Coding Plan key you saved in ZCode, and its local history.",
                         "读取你在 ZCode 里保存的 GLM 编程套餐密钥，以及本机历史记录。")
        default:
            var english: [String] = [], chinese: [String] = []
            let routes = Set(tool.routes.map(\.rawValue))
            if routes.contains("saved_login_api") { english.append("the sign-in it saved on this Mac"); chinese.append("它在本机保存的登录") }
            if routes.contains("runtime_rpc") { english.append("usage from its own runtime"); chinese.append("它自带运行时提供的用量") }
            if routes.contains("api_key_api") { english.append("the API key you configured for it"); chinese.append("你为它配置的接口密钥") }
            if routes.contains("local_log") || routes.contains("local_sqlite") { english.append("its local history"); chinese.append("本机历史记录") }
            base = english.isEmpty ? .init("Reads its usage on this Mac.", "读取它在本机的用量。")
                : .init("Reads " + english.joined(separator: " and ") + ".", "读取" + chinese.joined(separator: "和") + "。")
        }
        let keychain = tool.promptsKeychain ? mayAskKeychain : noKeychain
        return .init(base.english + keychain.english, base.chinese + keychain.chinese)
    }
    static func blockLine(_ block: ScopeToolBlock, tool: String, firstRun: Bool = true) -> SettingsText {
        let name = toolName(tool)
        switch block {
        case .notSignedIn where firstRun:
            return .init("Not signed in. Sign in to " + name.english + ", then turn it on in Settings › Data & Privacy.",
                         "未登录。登录 " + name.chinese + " 后，可在 设置 › 数据与隐私 中打开。")
        case .notSignedIn:
            return .init("Not signed in to " + name.english + ". ModelPlan reads it after you sign in.",
                         "未登录 " + name.chinese + "。登录后 ModelPlan 会读取。")
        case .unsupportedLogin:
            return .init("Signed in with an account ModelPlan cannot read yet, so nothing is read.",
                         "这种账号登录方式暂不支持读取，因此不读取。")
        }
    }
    private func keychainAllowButton() -> ScopeConsentButton {
        button(.init("Allow reading", "允许读取"), id: "scope.keychain.allow", enabled: controller.canMutate) { [weak self] in await self?.controller.allowKeychain() }
    }
    private func render() {
        for button in buttons {
            (button as? ScopeConsentButton)?.retire(); (button as? ConnectionButton)?.retire()
        }
        buttons = []
        for view in arrangedSubviews { removeArrangedSubview(view); view.removeFromSuperview() }
        wrappingLabels = []
        if firstRun { renderFirstRunChooser(); return }
        label(.init("Reading permissions", "读取权限"), heading: true)
        label(Self.activityDisclosure, secondary: true)
        if controller.needsKeychainAccess {
            label(.init("Keychain access needed to read Claude Code", "需要允许读取钥匙串"))
            arrangedSubviews.last?.setAccessibilityIdentifier("scope.keychain.needed")
            line([keychainAllowButton()])
        }
        switch controller.notice {
        case .none: break
        case .outcomeUnknown: label(.init("The change outcome is unknown. Check current permissions before trying again.", "这次变更结果未知，请先检查当前权限，再决定是否重试。"))
        case .committedAwaitingFacts: label(.init("The engine recorded the change. Check current permissions to verify its visible result.", "引擎已记录变更，请检查当前权限核验显示结果。"))
        case .requestFailed: label(.init("The request could not finish. Check the engine connection and current permissions.", "请求未能完成，请检查引擎连接和当前权限。"))
        case .checking: label(.init("Checking current permissions…", "正在检查当前权限…"))
        case .waitingForFacts: label(.init("Waiting for current permission facts. No change has been assumed.", "等待当前权限信息；尚未假定变更成功。"))
        case .cleanupPending: label(.init("Permission cleanup is pending. Check current permissions to follow progress.", "权限清理尚未完成，可检查当前权限查看进度。"))
        }
        let inspect = button(.init("Check current permissions", "检查当前权限"), id: "scope.inspect", enabled: controller.canInspect) { [weak self] in await self?.controller.inspectConsent() }
        if firstRun { line([inspect]) }
        else {
            line([inspect, button(.init("Request sanitized diagnostics", "获取脱敏诊断"), id: "scope.diagnostics", enabled: controller.canRequestDiagnostics) { [weak self] in await self?.controller.requestDiagnostics() }])
        }
        if !firstRun, let report = controller.diagnosticsPresentation { label(report, secondary: true) }
        // SET-9-20: Copy diagnostics belongs to About, not this consent surface.
        if !firstRun {
            gap()
            label(.init("Tool plugins", "工具插件"), heading: true)
            line([synchronousButton(.init("Install Codex plugin…", "安装 Codex 插件…"), id: "scope.plugin.codex", enabled: controller.canRequestPlugin) { [weak self] in self?.controller.requestPluginInstall(.codex) },
                  synchronousButton(.init("Install Claude Code plugin…", "安装 Claude Code 插件…"), id: "scope.plugin.claude", enabled: controller.canRequestPlugin) { [weak self] in self?.controller.requestPluginInstall(.claudeCode) }])
            switch controller.pluginPhase {
            case .idle: break
            case .confirmation(let id, let tool):
                let name = tool == .codex ? "Codex" : "Claude Code"
                label(.init("Confirm installing the plugin for " + name + "? This does not grant reading permissions.", "确认安装 " + name + " 插件？这不会授予读取权限。"))
                line([button(.init("Confirm plugin installation", "确认安装插件"), id: "scope.plugin.confirm") { [weak self] in await self?.controller.confirmPluginInstall(id) },
                      synchronousButton(.init("Cancel", "取消"), id: "scope.plugin.cancel") { [weak self] in self?.controller.cancelPluginConfirmation() }])
            case .sending: label(.init("Sending the plugin request…", "正在提交插件请求…"))
            case .unverified: label(.init("Plugin installation could not be verified. Check the plugin in the target tool; no installation success is assumed.", "无法核验插件安装结果，请在目标工具中检查插件；尚未假定安装成功。"))
            case .result(let status):
                switch status {
                case .installed: label(.init("The engine reports the plugin installed. Check it in the target tool.", "引擎报告插件已安装，请在目标工具中检查。"))
                case .planned: label(.init("The plugin installation plan is ready. Follow the target tool's plugin setup instructions.", "插件安装计划已就绪，请按照目标工具的插件设置说明操作。"))
                case .instructions: label(.init("The host tool needs manual plugin setup. Follow its plugin setup instructions.", "宿主工具需要手动设置插件，请按照其插件设置说明操作。"))
                case .failed: label(.init("The plugin installation did not finish. Check the target tool and try again.", "插件安装未完成，请检查目标工具后重试。"))
                case .unknown: label(.init("The plugin result is not recognized. Check the target tool.", "无法识别插件结果，请在目标工具中检查。"))
                }
            }
        }
        gap()
        guard let facts = controller.facts else {
            label(.init("Permission details are not ready. Check the engine connection.", "权限信息尚未就绪，请检查引擎连接。")); return
        }
        if !controller.isMutationServiceReady {
            label(.init("Permission changes are unavailable. Check the engine connection and current permission details before trying again.", "权限变更暂不可用，请先检查引擎连接和当前权限信息，再决定是否重试。"))
        }
        switch controller.phase {
        case .sending: label(.init("Submitting the confirmed change…", "正在提交已确认的变更…"))
        case .waitingForFacts: label(.init("Current permissions still need verification. Use Check current permissions.", "当前权限仍需核验，请使用“检查当前权限”。"))
        default: break
        }
        if facts.scopes.isEmpty {
            label(.init("No saved or detected reading paths are available. Choose Check current permissions after connecting the engine.", "暂无已保存或已检测的读取路径，连接引擎后可点“检查当前权限”。"))
        }
        for scope in facts.scopes {
            let id = scope.scope
            let title = scopeTitle(scope)
            if let last = arrangedSubviews.last { setCustomSpacing(14, after: last) }
            label(title, heading: true)
            if scope.route == .savedLoginApi && buildSigning == .unsigned {
                label(.init("This reading path needs a signed build.", "此读取路径需要签名版本。"))
            }
            if !scope.route.isKnown || scope.route == .knownUnknown {
                label(.init("This reading path is not recognized. Update the app or check the tool connection; Revoke and Forget remain available.", "尚不识别此读取路径。请更新应用或检查工具连接；仍可撤销或忘记已保存权限。"))
            } else if scope.retired || !scope.detected {
                label(.init("This tool is no longer detected. Saved permissions can still be revoked or forgotten.", "未检测到该工具；仍可撤销或忘记已保存权限。"))
            } else if scope.disabledReason != nil {
                label(.init("This path cannot be newly allowed under the engine's current policy. Existing permissions can still be revoked.", "引擎当前策略不允许新增授权；仍可撤销已有权限。"))
            }
            // G3-38 (owner D52): say why a detected tool has no reading, e.g. Claude Code signed out.
            if scope.detected, let block = controller.block(forTool: scope.tool) {
                label(Self.blockLine(block, tool: scope.tool, firstRun: false))
                arrangedSubviews.last?.setAccessibilityIdentifier("scope.status." + id)
            }
            // D27: a standard reader is on by default; its row says so and its switch is on.
            let status: SettingsText
            if controller.isAllowed(id) { status = .init("On", "已开启") }
            else if controller.isOnByDefault(id) { status = .init("On by default. Turn it off to stop reading this path.", "默认开启；关闭后不再读取此路径。") }
            else if scope.state == .denied { status = .init("Off. Turn it on to read this path.", "已关闭；打开后才会读取此路径。") }
            else { status = .init("Not granted. Select this path and confirm to allow it.", "尚未授权；选择该读取路径并确认后才会授权。") }
            label(status, secondary: true)
            let box: ConnectionButton
            if controller.isReading(id) {
                // Turning a reading path off is a confirmed revoke (the engine records the refusal).
                let switchable = controller.canMutate && scope.detected && !scope.retired && !scope.cleanupPending
                box = synchronousButton(.init("Read this path", "读取此路径"), id: "scope.allow." + id, enabled: switchable) { [weak self] in
                    self?.controller.requestRevoke(id)
                }
                box.setButtonType(.switch); box.state = .on
            } else {
                let selected = controller.selectedIDs.contains(id)
                box = synchronousButton(.init("Allow this path", "授权此读取路径"), id: "scope.allow." + id, enabled: controller.canChoose(id)) { [weak self] in
                    self?.controller.choose(id, selected: !selected)
                }
                box.setButtonType(.switch); box.state = selected ? .on : .off
            }
            // One line per path: the choice, then its saved-permission actions (Settings only).
            if firstRun { line([box]) }
            else {
                line([box,
                      synchronousButton(.init("Revoke this path…", "撤销此路径授权…"), id: "scope.revoke." + id, enabled: controller.canMutate) { [weak self] in self?.controller.requestRevoke(id) },
                      synchronousButton(.init("Forget saved permission…", "忘记已保存权限…"), id: "scope.forget." + id, enabled: controller.canMutate) { [weak self] in self?.controller.requestForget(id) }])
            }
        }
        gap()
        line([synchronousButton(.init("Select all available paths", "全选可授权路径"), id: "scope.selectAll", enabled: controller.canMutate) { [weak self] in self?.controller.selectAll() },
              synchronousButton(.init("Allow selected paths…", "授权所选路径…"), id: "scope.allowSelected", enabled: controller.canRequestAllow) { [weak self] in self?.controller.requestAllow() }])
        if case .confirmation(let confirmation) = controller.phase {
            let ids = Set(confirmation.intent.allowIDs + confirmation.intent.denyIDs + confirmation.intent.forgetIDs)
            for scope in facts.scopes where ids.contains(scope.scope) { label(scopeTitle(scope)) }
            switch confirmation.intent.mutation {
            case .allow: label(.init("Confirm the selected reading paths?", "确认授权所选读取路径？"))
            case .revoke: label(.init("Revoke this specific reading permission?", "撤销这一项读取授权？"))
            case .forget: label(.init("Forget this saved decision and request cleanup?", "忘记这一项已保存的决定并请求清理？"))
            case .choose: label(.init("Save these reading choices?", "保存这些读取选择？"))
            }
            line([button(.init("Confirm", "确认"), id: "scope.confirm") { [weak self] in await self?.controller.confirm(confirmation.id) },
                  synchronousButton(.init("Cancel", "取消"), id: "scope.cancel") { [weak self] in self?.controller.cancelConfirmation() }])
        }
    }
}
