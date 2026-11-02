// SPDX-License-Identifier: MIT
import AppKit

@MainActor private final class FirstRunDocument: NSView { override var isFlipped: Bool { true } }

/// Keep long localized checkbox labels visible after the scroll document narrows.
@MainActor private final class FirstRunWrappingCheckbox: NSButton {
    override var intrinsicContentSize: NSSize {
        let baseline = super.intrinsicContentSize
        guard bounds.width > 1, let cell else { return baseline }
        let measured = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: bounds.width, height: 10_000))
        return NSSize(width: NSView.noIntrinsicMetric, height: max(baseline.height, ceil(measured.height)))
    }
    override func setFrameSize(_ newSize: NSSize) {
        let oldWidth = frame.width
        super.setFrameSize(newSize)
        if abs(oldWidth - newSize.width) > 0.5 { invalidateIntrinsicContentSize() }
    }
}

/// One-page setup over the app's existing editor. Navigation/help effects go to its one host receiver.
@MainActor public final class SettingsFirstRunController: NSWindowController, NSWindowDelegate {
    public let editor: SettingsEditor
    public let host: FirstRunHost
    private let scopeConsentEntry: ScopeConsentEntry?
    private let scopePresentation: FirstRunConsentPresentation?
    private var scopeObserver: UUID?
    private var scopeUnavailable = false
    public private(set) var errorMessage: String?
    let doneButton = NSButton(), helpButton = NSButton()
    let loginButton: NSButton = FirstRunWrappingCheckbox(checkboxWithTitle: "", target: nil, action: nil)
    private(set) var readerButtons: [OptionalReaderID: NSButton] = [:]
    private let titleLabel = NSTextField(wrappingLabelWithString: "")
    private let privacy = NSTextField(wrappingLabelWithString: "")
    private let subscriptions = NSTextField(wrappingLabelWithString: "")
    private let readerStack = NSStackView()
    private lazy var connectionsView = SettingsConnectionsView(editor: editor, firstRun: true)
    private let loginSubtitle = NSTextField(wrappingLabelWithString: "")
    private let status = NSTextField(wrappingLabelWithString: "")
    private var options: OnboardingOptions?
    private var baseRevision: UInt64?
    private var touchedLogin = false, touchedReaders = Set<OptionalReaderID>()
    private var active = false, busy = false, pageValid = false
    private var generation: UInt64 = 0
    private var observer: UUID?
    private var connectionObserver: UUID?
    private var saveTask: Task<Void, Never>?

    public init(editor: SettingsEditor, host: FirstRunHost = .popup, scopeConsentEntry: ScopeConsentEntry? = nil) {
        self.editor = editor; self.host = host; self.scopeConsentEntry = scopeConsentEntry
        self.scopePresentation = scopeConsentEntry.map { FirstRunConsentPresentation(entry: $0) }
        _ = NSApplication.shared
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 980, height: 720),
                              styleMask: [.titled,.closable,.resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentMinSize = .init(width: FirstRunLayoutMetrics.minimumWindowWidth, height: FirstRunLayoutMetrics.minimumWindowHeight)
        super.init(window: window); window.delegate = self
        build(window); refreshEnabled()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    deinit {
        if let observer {
            let editor = self.editor
            Task { @MainActor in editor.removeChangeObserver(observer) }
        }
        if let connectionObserver {
            let editor = self.editor
            Task { @MainActor in editor.connections.removeObserver(connectionObserver) }
        }
        if let scopeObserver, let controller = scopeConsentEntry?.controller {
            Task { @MainActor in controller.removeObserver(scopeObserver) }
        }
    }
    public func prepare() async {
        active = true; generation &+= 1; let token = generation; errorMessage = nil
        scopeUnavailable = scopeConsentEntry != nil
        options = nil; baseRevision = nil; touchedLogin = false; touchedReaders = []; pageValid = false
        if observer == nil { observer = editor.observeChanges { [weak self] in self?.refresh() } }
        if connectionObserver == nil { connectionObserver = editor.connections.observe { [weak self] in self?.refreshEnabled() } }
        await editor.reload()
        guard active, generation == token, !Task.isCancelled else { return }
        if let scopeConsentEntry {
            do {
                try scopePresentation?.prepare(language: editor.snapshot?.preferences.language ?? .english)
                scopeUnavailable = false; errorMessage = nil
                if scopeObserver == nil { scopeObserver = scopeConsentEntry.controller.observe { [weak self] in
                    self?.refreshEnabled()
                    Task { @MainActor [weak self] in
                        await Task.yield()
                        guard let self, self.active else { return }
                        self.scopePresentation?.refreshLayoutAndFocus(followedBy: self.loginButton)
                    }
                } }
            } catch { scopeUnavailable = true }
        }
        refresh()
        connectionsView.followingKeyView = loginButton
        if scopeConsentEntry != nil {
            scopePresentation?.refreshLayoutAndFocus(followedBy: loginButton)
            window?.initialFirstResponder = scopePresentation?.firstEnabledControl ?? loginButton
        } else if editor.connections.isAvailable { window?.initialFirstResponder = connectionsView.firstControl ?? loginButton }
    }
    public func present() async { await prepare(); showWindow(nil); window?.makeKeyAndOrderFront(nil) }
    public func suspend() {
        active = false; pageValid = false; generation &+= 1
        if let observer { editor.removeChangeObserver(observer); self.observer = nil }
        if let connectionObserver { editor.connections.removeObserver(connectionObserver); self.connectionObserver = nil }
        connectionsView.suspend()
        if let scopeObserver { scopeConsentEntry?.controller.removeObserver(scopeObserver); self.scopeObserver = nil }
        scopePresentation?.suspend(); scopeUnavailable = false
        refreshEnabled()
    }
    public func windowWillClose(_ notification: Notification) { suspend() }

    private func build(_ window: NSWindow) {
        let root = NSView(); window.contentView = root
        let scroll = NSScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = false; scroll.autohidesScrollers = true
        scroll.setAccessibilityIdentifier("firstRun.scroll"); root.addSubview(scroll)
        let document = FirstRunDocument(); document.translatesAutoresizingMaskIntoConstraints = false; scroll.documentView = document
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false; stack.setAccessibilityIdentifier("firstRun.content"); document.addSubview(stack)
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        privacy.font = .systemFont(ofSize: 14); subscriptions.font = .systemFont(ofSize: 13)
        titleLabel.setAccessibilityIdentifier("firstRun.title");privacy.setAccessibilityIdentifier("firstRun.privacy")
        subscriptions.setAccessibilityIdentifier("firstRun.subscriptions")
        readerStack.orientation = .vertical; readerStack.alignment = .leading; readerStack.spacing = 10
        for id in OptionalReaderID.allCases {
            let button = FirstRunWrappingCheckbox(checkboxWithTitle: "", target: self, action: #selector(readerChanged(_:)))
            button.identifier = .init(id.rawValue); button.setAccessibilityIdentifier("firstRun.reader." + id.rawValue)
            button.cell?.wraps = true; button.cell?.isScrollable = false
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            readerButtons[id] = button; readerStack.addArrangedSubview(button)
            button.widthAnchor.constraint(lessThanOrEqualTo: readerStack.widthAnchor).isActive = true
        }
        loginButton.cell?.wraps = true; loginButton.cell?.isScrollable = false
        loginButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        loginButton.target = self; loginButton.action = #selector(loginChanged)
        loginButton.setAccessibilityIdentifier("firstRun.login")
        loginSubtitle.font = .systemFont(ofSize: 12); loginSubtitle.textColor = .secondaryLabelColor
        let login = NSStackView(views: [loginButton,loginSubtitle]); login.orientation = .vertical; login.alignment = .leading; login.spacing = 5
        loginButton.widthAnchor.constraint(lessThanOrEqualTo: login.widthAnchor).isActive = true
        loginSubtitle.widthAnchor.constraint(equalTo: login.widthAnchor).isActive = true
        for label in [titleLabel, privacy, subscriptions, loginSubtitle, status] {
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        status.font = .systemFont(ofSize: 12); status.textColor = .systemRed
        status.setAccessibilityIdentifier("firstRun.status")
        doneButton.bezelStyle = .rounded; doneButton.target = self; doneButton.action = #selector(done)
        doneButton.keyEquivalent = "\r"; doneButton.setAccessibilityIdentifier("firstRun.done")
        helpButton.isBordered = false; helpButton.target = self; helpButton.action = #selector(seeWhatsHere)
        helpButton.isHidden = editor.context.v1NormalEntry
        helpButton.setAccessibilityIdentifier("firstRun.help")
        let focusOrder=OptionalReaderID.allCases.compactMap{readerButtons[$0]}+[loginButton,doneButton,helpButton]
        for (a,b) in zip(focusOrder,focusOrder.dropFirst()) {a.nextKeyView=b}
        window.initialFirstResponder=focusOrder.first
        let buttons = NSStackView(views: [doneButton,helpButton]); buttons.spacing = 12
        let firstRunScopes = scopePresentation?.container ?? NSStackView()
        for view in [titleLabel,privacy,subscriptions,firstRunScopes,connectionsView,readerStack,login,status,buttons] {
            stack.addArrangedSubview(view)
            if view !== buttons { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        }
        let fillWidth = stack.widthAnchor.constraint(equalTo: document.widthAnchor, constant: -2 * FirstRunLayoutMetrics.horizontalInset)
        fillWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            fillWidth,
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: root.topAnchor), scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: FirstRunLayoutMetrics.preferredWidth),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: document.leadingAnchor, constant: FirstRunLayoutMetrics.horizontalInset),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: document.trailingAnchor, constant: -FirstRunLayoutMetrics.horizontalInset),
            stack.centerXAnchor.constraint(equalTo: document.centerXAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 28), stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -28),
        ])
    }
    private func refresh() {
        guard active, let snapshot = editor.snapshot else { refreshEnabled(); return }
        let p = snapshot.preferences, language = p.language
        pageValid = false
        do {
            let page = try FirstRunPage(preferences: p, context: editor.context)
            pageValid = true
            let latest = OnboardingOptions(preferences: p)
            if options == nil { options = latest; baseRevision = snapshot.revision }
            if !touchedLogin { options?.openAtLogin = latest.openAtLogin }
            for id in OptionalReaderID.allCases where !touchedReaders.contains(id) { options?.readerConsent[id] = latest.readerConsent[id] }
            if !touchedLogin && touchedReaders.isEmpty { baseRevision = snapshot.revision }
            window?.title = SettingsWords.text("First run", "首次运行", language)
            titleLabel.stringValue = SettingsWords.text("Set up ModelPlan", "设置 ModelPlan", language)
            privacy.stringValue = page.privacy.value(language)
            connectionsView.apply(language: language)
            connectionsView.isHidden = scopeConsentEntry != nil
            scopePresentation?.apply(language: language)
            scopePresentation?.refreshLayoutAndFocus(followedBy: loginButton)
            readerStack.isHidden = scopeConsentEntry != nil || editor.connections.isAvailable
            subscriptions.isHidden = editor.connections.isAvailable
            subscriptions.stringValue = page.subscriptions.isEmpty
                ? SettingsWords.text("No subscriptions detected yet. You can finish now.", "尚未检测到订阅，可以直接完成。", language)
                : SettingsWords.text("Subscriptions detected", "已检测到的订阅", language) + "\n" + page.subscriptions.map { [$0.name.value(language),$0.plan].filter { !$0.isEmpty }.joined(separator: " · ") }.joined(separator: "\n")
            for id in OptionalReaderID.allCases {
                guard let reader = page.readers.first(where: { $0.id.rawValue == id.rawValue }) else { continue }
                readerButtons[id]?.title = reader.title + " — " + SettingsWords.text("Local choice only; not shared authorization", "仅为本地选择，不代表共享授权", language)
                readerButtons[id]?.state = options?.readerConsent[id] == true ? .on : .off
            }
            loginButton.title = LoginSetting.title.value(language)
            loginButton.state = options?.openAtLogin == true ? .on : .off
            loginSubtitle.stringValue = page.loginSubtitle.value(language)
            loginButton.setAccessibilityHelp(loginSubtitle.stringValue)
            doneButton.title = page.done.value(language); helpButton.title = page.seeWhatsHere.value(language)
            helpButton.isHidden = !page.showsExploration
            if scopeUnavailable { errorMessage = SettingsWords.text("Reading permissions are busy. Close and try again.", "读取权限正在处理，请关闭后重试。", language) }
            status.stringValue = errorMessage ?? ""; status.isHidden = errorMessage == nil
            let appearance: NSAppearance.Name? = p.theme == .system ? nil : p.theme == .night ? .darkAqua : .aqua
            if window?.appearance?.name != appearance { window?.appearance = appearance.flatMap(NSAppearance.init(named:)) }
        } catch {
            errorMessage = SettingsWords.text("First run is unavailable. Check the subscription data.", "首次运行页暂不可用，请检查订阅数据。", language)
            status.stringValue = errorMessage!; status.isHidden = false
        }
        refreshEnabled()
    }
    private func refreshEnabled() {
        let scopeIdle: Bool
        if let scopeConsentEntry { if case .idle = scopeConsentEntry.controller.phase { scopeIdle = true } else { scopeIdle = false } }
        else { scopeIdle = true }
        let enabled = active && pageValid && !busy && !editor.isSaving && !editor.connections.isBusy && options != nil && !scopeUnavailable && scopeIdle
        loginButton.isEnabled = enabled
        for button in readerButtons.values { button.isEnabled = enabled && !editor.connections.isAvailable }
        doneButton.isEnabled = enabled
        helpButton.isEnabled = enabled && !helpButton.isHidden && editor.context.capabilities.helpMapAvailable && editor.onHostRequest != nil
    }
    @objc private func loginChanged() {
        guard active, !busy, loginButton.isEnabled else { return }
        touchedLogin = true; options?.openAtLogin = loginButton.state == .on
    }
    @objc private func readerChanged(_ sender: NSButton) {
        guard active, !busy, sender.isEnabled, let id = sender.identifier.flatMap({ OptionalReaderID(rawValue: $0.rawValue) }),
              readerButtons[id] === sender else { return }
        touchedReaders.insert(id); options?.readerConsent[id] = sender.state == .on
    }
    @objc private func done() { finish(.done) }
    @objc private func seeWhatsHere() { guard helpButton.isEnabled else { return }; finish(.seeWhatsHere) }
    private func finish(_ action: FirstRunAction) {
        guard active, pageValid, !busy, !editor.isSaving, let options, let revision = baseRevision else { return }
        busy = true; errorMessage = nil; refreshEnabled(); let expectedGeneration = generation
        saveTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.busy = false; self.refresh() }
            do {
                _ = try await self.editor.completeFirstRun(options: options, action: action, host: self.host, expectedRevision: revision)
                if self.generation == expectedGeneration { self.suspend(); self.close() }
            } catch {
                guard self.active, self.generation == expectedGeneration else { return }
                self.errorMessage = (error as? SettingsError) == .staleRevision
                    ? SettingsWords.text("Settings changed. Review these choices and try again.", "设置已更改，请检查这些选项后重试。", self.editor.snapshot?.preferences.language ?? .chinese)
                    : SettingsWords.text("Could not save. Your choices are kept here; try again.", "无法保存。此处保留了你的选择，请重试。", self.editor.snapshot?.preferences.language ?? .chinese)
                await self.editor.reload(); self.baseRevision = self.editor.snapshot?.revision
            }
        }
    }
    /// Observation only; a prepared/offscreen controller cannot establish real keyboard or VoiceOver input.
    @_spi(SettingsAcceptance) public func acceptanceCheckpoint() async -> SettingsAcceptanceCheckpoint {
        let before=editor.snapshot?.revision,stored=await editor.store.snapshot()
        var controls:[(String,NSView)]=OptionalReaderID.allCases.enumerated().compactMap{index,id in
            readerButtons[id].map{("firstRun.reader.\(index)",$0 as NSView)}
        }
        controls += [("firstRun.login",loginButton),("firstRun.done",doneButton),("firstRun.help",helpButton)]
        let chain=zip(controls,controls.dropFirst()).allSatisfy{$0.0.1.nextKeyView === $0.1.1}
        let current=editor.snapshot?.revision
        return .init(surface:.firstRun,editorRevision:current,storeRevision:stored.revision,
            consistentRevision:before==current && current==stored.revision,isSaving:editor.isSaving,
            windowVisible:window?.isVisible ?? false,windowKey:window?.isKeyWindow ?? false,
            focus:settingsAcceptanceFocus(window:window,controls:controls),settings:nil,
            firstRun:.init(active:active,pageValid:pageValid,busy:busy,subscriptionCount:editor.context.subscriptions.count,
                readerCount:readerButtons.count,checkedReaders:readerButtons.values.filter{$0.state == .on}.count,
                loginChecked:loginButton.state == .on,doneEnabled:doneButton.isEnabled,helpEnabled:helpButton.isEnabled,
                focusOrder:controls.map{$0.0},keyChainMatches:chain),loginStateFromContext:editor.context.capabilities.login.rawValue)
    }
    func waitForCompletion() async { await saveTask?.value }
}
