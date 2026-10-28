// SPDX-License-Identifier: MIT
import AppKit

@MainActor final class ConnectionButton: NSButton {
    var invoke: (() -> Void)?
    init(title: String, identifier: String, invoke: @escaping () -> Void) {
        super.init(frame: .zero)
        self.title = title; self.invoke = invoke; bezelStyle = .rounded
        target = self; action = #selector(pressed); setAccessibilityIdentifier(identifier)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    @objc private func pressed() {
        guard isEnabled, !isHiddenOrHasHiddenAncestor, window?.isVisible == true else { return }
        invoke?()
    }
    func retire() { isEnabled = false; invoke = nil; target = nil; action = nil }
}

/// Shared one-page surface. Construction/rendering never invokes a service, clipboard or URL.
@MainActor final class SettingsConnectionsView: NSStackView {
    private let controller: SettingsConnectionController
    private let editor: SettingsEditor
    private let firstRun: Bool
    private var intent: SettingsConnectionIntent?
    private var language: SettingsLanguage = .chinese
    private var observer: UUID?
    private var buttons: [ConnectionButton] = []
    private var task: Task<Void, Never>?
    private var preferenceSaving = false
    private var preferenceFailed = false
    weak var followingKeyView: NSView? { didSet { buttons.last?.nextKeyView = followingKeyView } }
    var firstControl: NSView? { buttons.first { $0.isEnabled } }
    init(editor: SettingsEditor, firstRun: Bool = false) {
        self.editor = editor; self.controller = editor.connections
        self.firstRun = firstRun
        super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 10
        setAccessibilityIdentifier("settings.connections")
        observer = controller.observe { [weak self] in self?.render() }
        render()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    deinit {
        if let observer { let controller = controller; Task { @MainActor in controller.removeObserver(observer) } }
    }
    func apply(language: SettingsLanguage) { self.language = language; render() }
    func suspend() { task?.cancel(); task = nil; controller.cancel() }
    private func label(_ text: SettingsText, heading: Bool = false) {
        let field = NSTextField(wrappingLabelWithString: text.value(language))
        field.font = .systemFont(ofSize: heading ? 14 : 12, weight: heading ? .semibold : .regular)
        addArrangedSubview(field); field.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }
    private func button(_ text: SettingsText, id: String, enabled: Bool, action: @escaping () -> Void) -> ConnectionButton {
        let button = ConnectionButton(title: text.value(language), identifier: id, invoke: action)
        button.isEnabled = enabled; buttons.append(button); return button
    }
    private func render() {
        let focusedID = (window?.firstResponder as? ConnectionButton)?.accessibilityIdentifier()
        for button in buttons { button.retire() }; buttons = []
        for view in arrangedSubviews { removeArrangedSubview(view); view.removeFromSuperview() }
        label(.init("Tools and connections", "工具与连接"), heading: true)
        if let reason = SettingsConnectionPresentation.availability(controller.availability) {
            label(reason)
            addArrangedSubview(button(.init("Check component in About", "在关于中检查组件"), id: "connections.componentHelp",
                enabled: editor.canPresentConnectionHelp) { [weak self] in try? self?.editor.requestConnectionHelp() })
        } else { label(SettingsConnectionPresentation.status(controller.phase)) }
        if preferenceFailed { label(.init("Could not save visibility. The previous setting is retained.", "无法保存可见性；已保留原设置。")) }
        addArrangedSubview(button(.init("Check detected tools", "检查已检测工具"), id: "connections.detect",
                                  enabled: controller.availability.canInspect && !controller.isBusy) { [weak self] in
            guard let self else { return }; self.task = Task { await self.controller.refresh() }
        })
        if let snapshot = controller.snapshot {
            label(.init("Canonical reading mode: " + snapshot.mode.rawValue, "规范读取模式：" + snapshot.mode.rawValue))
            if let preview = snapshot.consentPreview { label(preview.notice) }
            if intent?.basis != snapshot { intent = .init(snapshot: snapshot) }
            if snapshot.tools.isEmpty && snapshot.unrecognizedTools.isEmpty { label(.init("No tools reported. Authorization and subscription ownership remain unknown.", "未报告工具；授权及订阅归属仍未知。")) }
            toolGroup(snapshot.standardTools, advanced: false)
            if firstRun {
                label(.init("Checked tools are intentions only. Use Allow and confirm to request shared permission.", "勾选仅代表意向；点击授权并确认后才会请求共享权限。"))
                let title = SettingsText("Allow selected tools…", "授权所选工具…")
                addArrangedSubview(button(title, id: "connections.allowSelected",
                    enabled: intent.map { controller.canAllow($0) } ?? false) { [weak self] in
                    guard let self, let intent = self.intent else { return }; self.controller.requestAllow(intent)
                })
            }
            unrecognized(snapshot.unrecognizedTools.filter { $0.access == .standard })
            toolGroup(snapshot.advancedTools, advanced: true)
            unrecognized(snapshot.unrecognizedTools.filter { $0.access == .browserSession })
            subscriptions(snapshot.subscriptions)
        } else {
            label(.init("Tool presence and shared consent have not been checked.", "尚未检查工具及共享授权。"))
            toolGroup([], advanced: true)
        }
        label(.init("ModelPlan plugins", "ModelPlan 插件"), heading: true)
        if controller.availability.pluginTools.isEmpty {
            label(.init("Plugin installation is unavailable in this build.", "此构建暂不支持插件安装。"))
        }
        for tool in SettingsPluginTool.allCases {
            addArrangedSubview(button(.init("Install for " + tool.title + "…", "为 " + tool.title + " 安装…"),
                id: "connections.plugin." + tool.rawValue, enabled: controller.availability.pluginTools.contains(tool) && !controller.isBusy) { [weak self] in
                self?.controller.request(.installPlugin(tool))
            })
        }
        if case .awaitingConfirmation(let confirmation) = controller.phase {
            let confirm = button(.init("Confirm request", "确认请求"), id: "connections.confirm", enabled: true) { [weak self] in
                guard let self else { return }; self.task = Task { await self.controller.confirm(confirmation.id) }
            }
            let cancel = button(.init("Cancel", "取消"), id: "connections.cancel", enabled: true) { [weak self] in self?.controller.cancel() }
            addArrangedSubview(NSStackView(views: [confirm, cancel]))
        } else if controller.isBusy {
            addArrangedSubview(button(.init("Cancel request", "取消请求"), id: "connections.cancel", enabled: true) { [weak self] in
                self?.task?.cancel(); self?.controller.cancel()
            })
        }
        for (first, second) in zip(buttons, buttons.dropFirst()) { first.nextKeyView = second }
        buttons.last?.nextKeyView = followingKeyView
        if let focusedID, let next = buttons.first(where: { $0.accessibilityIdentifier() == focusedID && $0.isEnabled }) {
            window?.makeFirstResponder(next)
        }
    }
    private func subscriptions(_ subscriptions: [SettingsVerifiedSubscription]) {
        label(.init("Verified subscriptions", "已验证订阅"), heading: true)
        if subscriptions.isEmpty { label(.init("No verified subscription references reported.", "尚未报告已验证的订阅引用。")) }
        for sub in subscriptions {
            label(sub.name, heading: true)
            if !sub.plan.isEmpty { label(.init(sub.plan, sub.plan)) }
            let visible = !(editor.snapshot?.preferences.subscriptions.hiddenIDs.contains(sub.reference) ?? false)
            let known = editor.context.subscriptions.contains { $0.id == sub.reference }
            let toggle = button(visible ? .init("Visible in Dock and Cockpit", "在挂件与驾驶舱显示") : .init("Hidden in Dock and Cockpit", "在挂件与驾驶舱隐藏"),
                id: "connections.visibility." + sub.reference,
                enabled: known && !editor.isSaving && !preferenceSaving && !controller.isBusy) { [weak self] in
                guard let self, !self.preferenceSaving else { return }
                self.preferenceSaving = true; self.preferenceFailed = false; self.render()
                self.task = Task { @MainActor in
                    defer { self.preferenceSaving = false; self.render() }
                    do { try await self.editor.commit(.visible(sub.reference, !visible)) }
                    catch { self.preferenceFailed = true }
                }
            }
            addArrangedSubview(toggle)
            if !known { label(.init("Visibility is unavailable until this subscription appears in the app snapshot.", "此订阅出现在应用快照后才能更改可见性。")) }
        }
    }
    private func unrecognized(_ tools: [SettingsUnrecognizedTool]) {
        for tool in tools {
            label(.init(tool.title, tool.title), heading: true)
            label(SettingsConnectionPresentation.presence(tool.presence))
            label(.init("Authorization, connection, quota and subscription remain unknown. Actions are unavailable for this tool in this app version.",
                        "授权、连接、额度及订阅均未知。此应用版本暂不支持此工具的操作。"))
        }
    }
    private func toolGroup(_ tools: [SettingsConnectionToolState], advanced: Bool) {
        // The advanced group remains visibly separate even when no provider is reported.
        if !advanced && tools.isEmpty { return }
        label(advanced ? .init("Advanced browser sessions — off by default", "高级浏览器会话——默认关闭") : .init("Standard tools", "标准工具"), heading: true)
        if advanced { label(.init("Separate explicit consent is required. A detected or selected tool is not authorized.", "需要单独明确授权；已检测到或已选择均不代表已授权。")) }
        for value in tools {
            let suffix = value.beta ? " · beta" : ""
            label(.init(value.tool.title + suffix, value.tool.title + suffix), heading: true)
            label(SettingsConnectionPresentation.summary(value))
            let hosts = value.providerHosts.isEmpty ? SettingsText("None reported", "未报告")
                : SettingsText(value.providerHosts.joined(separator: ", "), value.providerHosts.joined(separator: ", "))
            label(.init("Provider hosts: " + hosts.english, "服务商主机：" + hosts.chinese))
            label(.init("Recorded Keychain permission: " + value.keychain.rawValue, "已记录钥匙串权限：" + value.keychain.rawValue))
            if !advanced && value.keychainEligible {
                let keychain = button(.init("Allow Claude Code Keychain access", "允许 Claude Code 访问钥匙串"),
                    id: "connections.keychain.claude", enabled: controller.canConnect(.claude, access: .standard)
                        && intent?.selected.contains(.claude) == true) { [weak self] in
                    guard let self, var intent = self.intent else { return }
                    intent.selectKeychain(.claude, enabled: !intent.keychainAllowedTools.contains(.claude))
                    self.intent = intent; self.controller.invalidateConfirmation(); self.render()
                }
                keychain.setButtonType(.switch)
                keychain.state = intent?.keychainAllowedTools.contains(.claude) == true ? .on : .off
                addArrangedSubview(keychain)
                label(.init("Optional. macOS may ask for approval when reading Claude Code usage. Leaving this unchecked keeps the recorded Keychain choice.",
                            "可选。读取 Claude Code 用量时 macOS 可能请求批准；不勾选会保留已记录的钥匙串选择。"))
            }
            if firstRun && !advanced {
                let choice = button(.init("Choose " + value.tool.title, "选择 " + value.tool.title),
                    id: "connections.choose." + value.tool.rawValue, enabled: !controller.isBusy && value.canRequestConnection) { [weak self] in
                    guard let self, var intent = self.intent else { return }
                    intent.select(value.tool, enabled: !intent.selected.contains(value.tool)); self.intent = intent; self.controller.invalidateConfirmation(); self.render()
                }
                choice.setButtonType(.switch); choice.state = intent?.selected.contains(value.tool) == true ? .on : .off
                addArrangedSubview(choice)
                if value.authorization == .allowed { addArrangedSubview(forgetButton(value.tool)) }
                continue
            }
            let connect = button(advanced ? .init("Enable browser session…", "开启浏览器会话…") : .init("Connect…", "连接…"),
                id: "connections.connect." + value.tool.rawValue,
                enabled: controller.canConnect(value.tool, access: value.access)) { [weak self] in
                guard let self else { return }
                if value.keychainEligible {
                    self.controller.request(.applyStandardConsent(allow: [value.tool], deny: [],
                        keychainAllow: self.intent?.orderedKeychainTools.filter { $0 == value.tool } ?? []))
                } else { self.controller.request(.connect(value.tool, value.access)) }
            }
            let disconnect = forgetButton(value.tool)
            addArrangedSubview(NSStackView(views: [connect, disconnect]))
        }
    }
    private func forgetButton(_ tool: SettingsConnectionTool) -> ConnectionButton {
        button(.init("Forget readings…", "忘记读数…"), id: "connections.disconnect." + tool.rawValue,
               enabled: controller.canForget(tool)) { [weak self] in self?.controller.requestForget(tool) }
    }
}
