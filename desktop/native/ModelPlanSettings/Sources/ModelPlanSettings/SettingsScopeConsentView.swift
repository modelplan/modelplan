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
    private let language: SettingsLanguage
    private var observer: UUID?
    private var buttons: [NSButton] = []
    public init(controller: ScopeConsentController, language: SettingsLanguage = .chinese) {
        self.controller = controller; self.language = language; super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 8
        setAccessibilityIdentifier("settings.scopeConsent")
        observer = controller.observe { [weak self] in self?.render() }; render()
    }
    /// Retire this presentation before detaching it from the accepted-event sink.
    public func suspend() {
        if let observer { controller.removeObserver(observer); self.observer = nil }
        for button in buttons {
            (button as? ScopeConsentButton)?.retire(); (button as? ConnectionButton)?.retire()
        }
        buttons = []
        for view in arrangedSubviews { removeArrangedSubview(view); view.removeFromSuperview() }
        controller.clearAcceptedPrivateState()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    deinit {
        if let observer { let controller = controller; Task { @MainActor in controller.removeObserver(observer) } }
    }
    private func label(_ text: SettingsText) { addArrangedSubview(NSTextField(wrappingLabelWithString: text.value(language))) }
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
        case .apiKeyApi: route = .init("Configured API-key usage", "已配置 API 密钥的用量")
        case .statusLine: route = .init("Tool status-line readings", "工具状态栏读数")
        case .browserSession: route = .init("Browser-session usage", "浏览器会话用量")
        case .manual: route = .init("Manually supplied readings", "手动提供的读数")
        case .knownUnknown, .unknown: route = .init("Unrecognized reading path", "尚不识别的读取路径")
        }
        return .init(tool.english + " · " + route.english, tool.chinese + " · " + route.chinese)
    }
    private func render() {
        for button in buttons {
            (button as? ScopeConsentButton)?.retire(); (button as? ConnectionButton)?.retire()
        }
        buttons = []
        for view in arrangedSubviews { removeArrangedSubview(view); view.removeFromSuperview() }
        label(.init("Reading permissions", "读取权限"))
        switch controller.notice {
        case .none: break
        case .outcomeUnknown: label(.init("The change outcome is unknown. Check current permissions before trying again.", "这次变更结果未知，请先检查当前权限，再决定是否重试。"))
        case .committedAwaitingFacts: label(.init("The engine recorded the change. Check current permissions to verify its visible result.", "引擎已记录变更，请检查当前权限核验显示结果。"))
        case .requestFailed: label(.init("The request could not finish. Check the engine connection and current permissions.", "请求未能完成，请检查引擎连接和当前权限。"))
        case .checking: label(.init("Checking current permissions…", "正在检查当前权限…"))
        case .waitingForFacts: label(.init("Waiting for current permission facts. No change has been assumed.", "等待当前权限信息；尚未假定变更成功。"))
        case .cleanupPending: label(.init("Permission cleanup is pending. Check current permissions to follow progress.", "权限清理尚未完成，可检查当前权限查看进度。"))
        }
        addArrangedSubview(button(.init("Check current permissions", "检查当前权限"), id: "scope.inspect", enabled: controller.canInspect) { [weak self] in await self?.controller.inspectConsent() })
        addArrangedSubview(button(.init("Request sanitized diagnostics", "获取脱敏诊断"), id: "scope.diagnostics", enabled: controller.canRequestDiagnostics) { [weak self] in await self?.controller.requestDiagnostics() })
        if let report = controller.diagnosticsSummary { label(.init(report, report)) }
        addArrangedSubview(synchronousButton(.init("Copy diagnostics", "复制诊断"), id: "scope.copyDiagnostics", enabled: controller.canCopyDiagnostics) { [weak self] in self?.controller.copyDiagnostics() })
        label(.init("Tool plugins", "工具插件"))
        addArrangedSubview(synchronousButton(.init("Install Codex plugin…", "安装 Codex 插件…"), id: "scope.plugin.codex", enabled: controller.canRequestPlugin) { [weak self] in self?.controller.requestPluginInstall(.codex) })
        addArrangedSubview(synchronousButton(.init("Install Claude Code plugin…", "安装 Claude Code 插件…"), id: "scope.plugin.claude", enabled: controller.canRequestPlugin) { [weak self] in self?.controller.requestPluginInstall(.claudeCode) })
        switch controller.pluginPhase {
        case .idle: break
        case .confirmation(let id, let tool):
            let name = tool == .codex ? "Codex" : "Claude Code"
            label(.init("Confirm installing the plugin for " + name + "? This does not grant reading permissions.", "确认安装 " + name + " 插件？这不会授予读取权限。"))
            addArrangedSubview(button(.init("Confirm plugin installation", "确认安装插件"), id: "scope.plugin.confirm") { [weak self] in await self?.controller.confirmPluginInstall(id) })
            addArrangedSubview(synchronousButton(.init("Cancel", "取消"), id: "scope.plugin.cancel") { [weak self] in self?.controller.cancelPluginConfirmation() })
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
            label(title)
            if scope.route == .savedLoginApi {
                label(.init("This reading path needs a signed build.", "此读取路径需要签名版本。"))
            }
            if !scope.route.isKnown {
                label(.init("Update the app to allow this new reading path. Revoke and Forget remain available.", "请更新应用后再授权这种新读取路径；仍可撤销或忘记已保存权限。"))
            } else if scope.retired || !scope.detected {
                label(.init("This tool is no longer detected. Saved permissions can still be revoked or forgotten.", "未检测到该工具；仍可撤销或忘记已保存权限。"))
            } else if scope.disabledReason != nil {
                label(.init("This path cannot be newly allowed under the engine's current policy. Existing permissions can still be revoked.", "引擎当前策略不允许新增授权；仍可撤销已有权限。"))
            }
            label(controller.isAllowed(id) ? .init("Allowed", "已授权") : .init("Not granted. Select this path and confirm to allow it.", "尚未授权；选择该读取路径并确认后才会授权。"))
            let selected = controller.selectedIDs.contains(id)
            let box = synchronousButton(.init("Allow this path", "授权此读取路径"), id: "scope.allow." + id, enabled: controller.canChoose(id)) { [weak self] in
                self?.controller.choose(id, selected: !selected)
            }
            box.setButtonType(.switch); box.state = selected ? .on : .off; addArrangedSubview(box)
            addArrangedSubview(synchronousButton(.init("Revoke this path…", "撤销此路径授权…"), id: "scope.revoke." + id, enabled: controller.canMutate) { [weak self] in self?.controller.requestRevoke(id) })
            addArrangedSubview(synchronousButton(.init("Forget saved permission…", "忘记已保存权限…"), id: "scope.forget." + id, enabled: controller.canMutate) { [weak self] in self?.controller.requestForget(id) })
        }
        addArrangedSubview(synchronousButton(.init("Select all available paths", "全选可授权路径"), id: "scope.selectAll", enabled: controller.canMutate) { [weak self] in self?.controller.selectAll() })
        addArrangedSubview(synchronousButton(.init("Allow selected paths…", "授权所选路径…"), id: "scope.allowSelected", enabled: controller.canRequestAllow) { [weak self] in self?.controller.requestAllow() })
        if case .confirmation(let confirmation) = controller.phase {
            let ids = Set(confirmation.intent.allowIDs + confirmation.intent.denyIDs + confirmation.intent.forgetIDs)
            for scope in facts.scopes where ids.contains(scope.scope) { label(scopeTitle(scope)) }
            switch confirmation.intent.mutation {
            case .allow: label(.init("Confirm the selected reading paths?", "确认授权所选读取路径？"))
            case .revoke: label(.init("Revoke this specific reading permission?", "撤销这一项读取授权？"))
            case .forget: label(.init("Forget this saved decision and request cleanup?", "忘记这一项已保存的决定并请求清理？"))
            }
            addArrangedSubview(button(.init("Confirm", "确认"), id: "scope.confirm") { [weak self] in await self?.controller.confirm(confirmation.id) })
            addArrangedSubview(synchronousButton(.init("Cancel", "取消"), id: "scope.cancel") { [weak self] in self?.controller.cancelConfirmation() })
        }
    }
}
