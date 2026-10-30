// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import ModelPlanCockpitWeb
import ModelPlanEngineClient
import ModelPlanSettings
import ModelPlanWire

/// The one Dock/menu console action calls this retained, lazy product binding.
/// No engine or WKWebView is created until that permitted user action.
@MainActor public final class CommunityCockpitEntry {
    private static var retained: CommunityCockpitEntry?
    private let coordinator: EngineCockpitCoordinator
    private let canPresent: () -> Bool
    private let settings: (() -> Void)?
    private let status: (() -> Void)?
    private var startTask: Task<Void, Never>?
    private var termination: NSObjectProtocol?
    private var stopping = false
    private var stopTask: Task<Void, Never>?
    #if DEBUG
    static var actionProbe: (() -> Void)?
    #endif
    #if MODELPLAN_TEST_ONLY_SPI
    public static var verificationPage: ((CockpitWindowController) -> Void)?
    #endif

    // Canonical #355 build output, not a self-asserted runtime approval flag.
    public static let webSource = "d437a7f94729da4f1ea108692b8602b7a6e2788c"
    public static let manifestPins = ["community":"1e8022118f25d4593f4cb575702948c23aa1faa11c7a10358754ece248b30558", "official":"5dd26b770d8491ff3661f54f4e86aa576cc9dbb05a13200a0d0238e2097122bd"]

    public static func open(bundle: URL, preferences: SettingsPreferences?,
                            canPresent: @escaping () -> Bool,
                            showSettings: (() -> Void)?, showStatus: (() -> Void)?) {
        guard canPresent() else { return }
        #if DEBUG
        if let actionProbe { actionProbe(); return }
        #endif
        if let retained {
            if retained.stopping {
                Task { @MainActor in
                    await retained.stop()
                    Self.open(bundle:bundle, preferences:preferences, canPresent:canPresent, showSettings:showSettings, showStatus:showStatus)
                }
            } else { retained.present() }
            return
        }
        do {
            let entry = try CommunityCockpitEntry(bundle: bundle, preferences: preferences,
                canPresent: canPresent, showSettings: showSettings, showStatus: showStatus)
            retained = entry; entry.present()
        } catch {
            showUnavailable(canPresent: canPresent, settings: showSettings, status: showStatus)
        }
    }
    private init(bundle: URL, preferences: SettingsPreferences?, canPresent: @escaping () -> Bool,
                 showSettings: (() -> Void)?, showStatus: (() -> Void)?) throws {
        guard CommunityConsentBundleIdentity.matches(bundle: bundle) else { throw CockpitBridgeError.unavailable }
        let editionURL = bundle.appendingPathComponent("Contents/Resources/build-edition.json")
        let edition: String
        if let bytes = try? Data(contentsOf: editionURL), bytes.count <= 1024,
           let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String:Any],
           value["edition"] as? String == "official" { edition = "official" } else { edition = "community" }
        let root = bundle.appendingPathComponent("Contents/Resources/Cockpit", isDirectory:true)
        let verified = try VerifiedCockpitBundle(root:root,manifestSHA256:Self.manifestPins[edition]!,allowOfficial:edition == "official")
        let theme: CockpitAppearance.Theme
        switch preferences?.theme ?? .system {
        case .day: theme = .day
        case .night: theme = .night
        case .system: theme = NSApp.effectiveAppearance.bestMatch(from:[.aqua,.darkAqua]) == .darkAqua ? .night : .day
        }
        let appearance = CockpitAppearance(theme:theme,locale:preferences?.language == .english ? .en : .zhCN,profile:.full)
        coordinator = EngineCockpitCoordinator { context in
            let page = CockpitWindowController(bundle:verified,context:context,appearance:appearance)
            #if MODELPLAN_TEST_ONLY_SPI
            Self.verificationPage?(page)
            #endif
            return page
        }
        self.canPresent = canPresent; settings = showSettings; status = showStatus
        var environment = ProcessInfo.processInfo.environment.filter { WireChildEnvironment.allowedKeys.contains($0.key) }
        environment["HOME"] = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        environment["TMPDIR"] = ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory()
        #if MODELPLAN_TEST_ONLY_SPI
        let offline = true
        #else
        let offline = false
        #endif
        coordinator.makeClient(configuration:.init(executableURL:bundle.appendingPathComponent("Contents/Helpers/modelplan"),
            applicationVersion:"ModelPlan-cockpit-u11",allowedEnvironment:environment,offline:offline,readOnly:true))
        coordinator.onUnavailable = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                Self.showUnavailable(canPresent:self.canPresent,settings:self.settings,status:self.status)
            }
        }
        coordinator.onIntent = { [weak self] intent in
            guard let self, self.canPresent() else { return }
            switch intent {
            case .chooseSetup, .openSettings: self.settings?()
            case .openHistory:
                Self.showUnavailable(canPresent:self.canPresent,settings:self.settings,status:self.status,
                    text:"History is unavailable in this candidate. Open Settings to check connected tools. / 当前候选版尚无历史窗口，请打开设置查看已连接工具。")
            }
        }
        coordinator.onClosed = { [weak self] in
            // Mark retirement in this turn before any repeat click can start.
            self?.stopping = true
            Task { @MainActor [weak self] in await self?.stop() }
        }
        termination = NotificationCenter.default.addObserver(forName:NSApplication.willTerminateNotification,object:NSApplication.shared,queue:.main) { [weak self] _ in
            MainActor.assumeIsolated { self?.coordinator.close() }
        }
    }
    private func present() {
        guard canPresent(), !stopping, startTask == nil else { return }
        startTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await coordinator.start()
                guard !Task.isCancelled, canPresent(), !stopping else { startTask = nil; await stop(); return }
                coordinator.open(); startTask = nil
            } catch {
                startTask = nil
                Self.showUnavailable(canPresent:canPresent,settings:settings,status:status)
                await stop()
            }
        }
    }
    private static func showUnavailable(canPresent: () -> Bool, settings: (() -> Void)?, status: (() -> Void)?,
        text:String = "The cockpit is not available yet. Check tool access in Settings, or reinstall this candidate if its bundled content is missing. / 驾驶舱暂不可用，请在设置中检查工具授权；若缺少随附内容，请重新安装候选版。") {
        guard canPresent() else { return }
        let alert=NSAlert();alert.messageText="Cockpit unavailable / 驾驶舱暂不可用";alert.informativeText=text
        if settings != nil { alert.addButton(withTitle:"Open Settings / 打开设置") }
        if status != nil { alert.addButton(withTitle:"Open Status / 打开状态") }
        alert.addButton(withTitle:"Cancel / 取消")
        let selected=alert.runModal()
        if settings != nil && selected == .alertFirstButtonReturn { settings?() }
        else if status != nil && selected == (settings == nil ? .alertFirstButtonReturn : .alertSecondButtonReturn) { status?() }
    }
    private func stop() async {
        if let stopTask { await stopTask.value; if Self.retained === self { Self.retained=nil }; return }
        stopping = true; startTask?.cancel(); startTask=nil
        if let termination { NotificationCenter.default.removeObserver(termination); self.termination=nil }
        let task = Task { @MainActor in await coordinator.shutdown() }
        stopTask = task; await task.value
        if Self.retained === self { Self.retained=nil }
    }
    public static func closeWindow() { retained?.coordinator.close() }
    public static func shutdown() async { await retained?.stop() }
}
