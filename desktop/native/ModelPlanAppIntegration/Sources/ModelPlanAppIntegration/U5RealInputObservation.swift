// SPDX-License-Identifier: MIT
#if DEBUG && MODELPLAN_U5_REAL_INPUT
import AppKit
import CryptoKit
import ModelPlanShell
import ModelPlanDock
import ModelPlanSettings

/// Test-build only. Observes this candidate's retained production Dock. No
/// process discovery, credentials, real login service or input synthesis.
@MainActor enum U5RealInputObservation {
    private static var installed: U5Observer?
    static func install(_ host: StaticDockPreviewHost, panel: NSPanel) {
        guard installed == nil, let path = ProcessInfo.processInfo.environment["MODELPLAN_U5_RUN_CONFIG"],
              let config = try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as? [String: Any],
              config["profile"] as? String == "synthetic" else { return }
        guard ["home","lease","stop","control","output","runID","epoch"].allSatisfy({ (config[$0] as? String)?.isEmpty == false }) else { return }
        installed = U5Observer(host: host, panel: panel, config: config)
    }
}
@MainActor private final class U5Backdrop: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
@MainActor private final class U5FakeWindow: PulsePresenceWindow {
    var isVisible = true, isMiniaturized = false
    func close() { isVisible = false; isMiniaturized = false }
}
@MainActor private final class U5FakeLogin: PulseLoginService {
    var state: PulseLoginState = .off, calls = 0
    func register() throws { calls += 1; state = .needsApproval }
    func unregister() throws { calls += 1; state = .off }
}
@MainActor private final class U5Observer {
    weak var host: StaticDockPreviewHost?
    weak var panel: NSPanel?
    let config: [String: Any]
    var timer: Timer?, backdrops: [NSPanel] = [], commandID: String?, busy = false
    init(host: StaticDockPreviewHost, panel: NSPanel, config: [String: Any]) {
        self.host = host; self.panel = panel; self.config = config
        guard NSHomeDirectory() == config["home"] as? String else {
            emit("isolation-failed", ["homeBound":false]); finish(); return
        }
        emit("isolation", ["homeBound":true])
        for screen in NSScreen.screens {
            let background = U5Backdrop(contentRect: screen.frame, styleMask: [.borderless,.nonactivatingPanel], backing: .buffered, defer: false)
            background.backgroundColor = NSColor(calibratedWhite: 0.16, alpha: 1); background.isOpaque = true
            background.level = .init(rawValue: NSWindow.Level.floating.rawValue - 1)
            background.ignoresMouseEvents = true; background.setAccessibilityElement(false); background.orderFrontRegardless()
            backdrops.append(background)
        }
        if let dock = panel as? PulseDockPanel {
            let previous = dock.receivedInput
            dock.receivedInput = { [weak self] type, time in previous?(type,time); self?.emit("native-input", ["type":type.rawValue,"eventTimestamp":time]) }
        }
        let previous = host.pointerInputView.onChange
        host.pointerInputView.onChange = { [weak self] point in previous?(point); self?.emit("pointer-sample", ["inside":point != nil]) }
        host.pointerInputView.verificationEntryObserved = { [weak self] in self?.emit("pointer-entry", [:]) }
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
        emit("subject-observer-installed", ["physicalDisplayCount":NSScreen.screens.count]); tick()
    }
    func emit(_ event: String, _ values: [String: Any]) {
        guard let path = config["output"] as? String else { return }
        var data = values; data["event"] = event; data["timestamp"] = ISO8601DateFormatter().string(from: Date())
        data["pid"] = ProcessInfo.processInfo.processIdentifier
        data["windowID"] = panel?.windowNumber
        guard let bytes = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]) else { return }
        if !FileManager.default.fileExists(atPath: path) { FileManager.default.createFile(atPath: path, contents: nil, attributes: [.posixPermissions:0o600]) }
        if let file = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            defer { try? file.close() }; try? file.seekToEnd(); try? file.write(contentsOf: bytes + Data([10]))
        }
    }
    func tick() {
        guard let host, let panel, let leasePath = config["lease"] as? String,
              let stop = config["stop"] as? String,
              let lease = try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: leasePath))) as? [String: Any],
              lease["runID"] as? String == config["runID"] as? String,
              lease["epoch"] as? String == config["epoch"] as? String,
              lease["exclusive"] as? Bool == true, lease["ownerPreempted"] as? Bool == false,
              let expiry = lease["expiresAt"] as? Double, Date().timeIntervalSince1970 < expiry,
              let heartbeat = lease["guardianHeartbeatAt"] as? Double,
              (0...2).contains(Date().timeIntervalSince1970 - heartbeat),
              !FileManager.default.fileExists(atPath: stop) else { finish(); return }
        let frame = panel.frame
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersection(frame).width > 0 && $0.visibleFrame.intersection(frame).height > 0 }
        emit("native-observation", ["running":true,"visible":panel.isVisible,"onScreen":onScreen,
            "nonActivating":panel.styleMask.contains(.nonactivatingPanel) && !panel.canBecomeKey && !panel.canBecomeMain,
            "key":panel.isKeyWindow,"active":NSApp.isActive,"activationCall":"not-invoked-by-subject",
            "disk":config["diskAdmitted"] as? Bool == true,"lease":true,
            "frame":["x":frame.minX,"y":frame.minY,"width":frame.width,"height":frame.height],
            "state":String(describing:host.edgePresentation?.state),"edge":String(describing:host.edgePresentation?.placement?.edge),
            "physicalDisplayCount":NSScreen.screens.count])
        guard !busy, let control = config["control"] as? String,
              let command = try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: control))) as? [String: Any],
              let id = command["id"] as? String, id != commandID, let name = command["command"] as? String else { return }
        commandID = id; busy = true
        Task { @MainActor [weak self] in
            guard let self else { return }; defer { self.busy = false }
            do {
                if name == "stub-services" { try await self.stubs(id) }
                else if name == "migration" || name == "read-migration" { try await self.migration(id, mutate:name == "migration") }
                else if name == "quit" { self.emit("command-result", ["id":id,"command":name]); self.finish() }
            } catch { self.emit("command-result", ["id":id,"command":name,"outcome":"fail","error":"candidate-test-operation-failed"]) }
        }
    }
    func stubs(_ id: String) async throws {
        var policy: NSApplication.ActivationPolicy = .accessory, activations = 0
        let presence = PulseDockPresence(currentPolicy: { policy }, setPolicy: { policy = $0 }, activate: { activations += 1 })
        let first = U5FakeWindow(), second = U5FakeWindow(); second.isVisible = false; second.isMiniaturized = true
        presence.track(first); presence.track(second); presence.apply(); first.isVisible = false; presence.apply(closing:first)
        let multiple = policy == .regular; presence.closeWindows()
        let service = U5FakeLogin(), adapter = CommunityLoginServiceAdapter(item:.init(isAppBundle:true, service:service))
        let root = URL(fileURLWithPath:config["home"] as! String).appendingPathComponent("u5-stub-settings/settings.json")
        let editor = SettingsEditor(store:try SettingsStore(url:root)); await editor.reload()
        var handled: CommunityLoginHandling?
        editor.onHostRequest = { request in if let current = editor.snapshot { handled = adapter.handle(request,current:current,mayChangeLoginItem:true) } }
        _ = try await editor.commit(SettingsB21Edit.login(true)); editor.onHostRequest = nil
        emit("command-result", ["id":id,"command":"stub-services","assertions":["stubSystemCallsOnly":true,"candidateBoundStubActions":true,
            "multiWindowPresenceObserved":multiple,"restorationNoFocusSteal":activations == 0,"explicitLoginRequestObserved":service.calls == 1,
            "requiresApprovalTruthful":handled == .performed(.requiresApproval),"realLoginItemsUntouched":true]])
    }
    func migration(_ id: String, mutate: Bool) async throws {
        let home = URL(fileURLWithPath:config["home"] as! String)
        let support = home.appendingPathComponent("Library/Application Support")
        let paths = ["Beta07/settings-v1.json","Native/settings-v1.json","Native/community-v1.json"]
        let before = try paths.map { try Data(contentsOf:support.appendingPathComponent("ModelPlan/"+$0)) }
        let store = try SettingsStore(foundationAt:support,product:.community)
        if mutate {
            _ = try await store.update { $0.dockEdge = .bottom; $0.dockAlongFraction = 0.4 }
            _ = try await store.updateCore(.init(localeIdentifier:"en",favouriteModelIDs:["u5-restart-sentinel"]))
        }
        let snapshot = await store.snapshot(), core = await store.coreSnapshot()
        let after = try paths.map { try Data(contentsOf:support.appendingPathComponent("ModelPlan/"+$0)) }
        let bytes = try Data(contentsOf:support.appendingPathComponent("ModelPlan/settings.json"))
        let object = try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        let restored = host?.edgePresentation?.placement?.edge == .bottom
        emit("command-result", ["id":id,"command":mutate ? "migration":"read-migration","assertions":["migrationObservedThroughCandidate":true,
            "newStorePublished":true,"oldFilesUnchanged":before == after,"coreSettingsPreserved":snapshot.preferences.dockEdge == .bottom && core?.favouriteModelIDs == ["u5-restart-sentinel"],
            "restartObserved":!mutate,"restartRestoredPlacement":restored,"readerConsentNotPromoted":(object["settings"] as? [String:Any])?["readerConsent"] == nil]])
    }
    func finish() {
        timer?.invalidate();timer=nil;host?.setPresentationAllowed(false)
        backdrops.forEach { $0.orderOut(nil);$0.close() };backdrops=[]
        NSApp.terminate(nil)
    }
}
#endif
