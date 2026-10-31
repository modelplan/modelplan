// SPDX-License-Identifier: MIT
#if MODELPLAN_U6_DRIVE
import AppKit
import ModelPlanMenuVerification
import ModelPlanEngineClient

/// Test-build-only lease/owner stop hook. Emits only scoped booleans, never other-app identity.
@MainActor final class U6DriveGuard {
    private let runID: String, epoch: String
    private let expiry: Double
    private let lease: URL, stop: URL, observations: URL
    private let menuRequest: URL
    private var arrivalObserver: StatusMenuArrivalObserver?
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private var armed = false, ending = false
    private var menuObservers: [NSObjectProtocol] = []
    private var trackedMenus = Set<ObjectIdentifier>()
    private var retainedItems: [NSMenuItem] = []
    private var priorPrivateContent = false
    private var privateMenuInstanceIDs = Set<String>()
    private var statusMenuOwner: ((NSMenu) -> Bool)?
    private var activeStatusInstanceID: String?
    private weak var dockHost: StaticDockPreviewHost?
    private var lastDockFrameSignature: String?
    private let ownsMenu: (NSMenu) -> Bool
    private let hasPrivateContent: () -> Bool
    static func attach(ownsMenu: @escaping (NSMenu) -> Bool, hasPrivateContent: @escaping () -> Bool,
                       dockHost: StaticDockPreviewHost) throws -> U6DriveGuard? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--u6-drive-contract"), args.indices.contains(index + 1) else { return nil }
        let data = try Data(contentsOf: URL(fileURLWithPath: args[index + 1]))
        guard data.count <= 16_384, let c = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.invalid }
        let value = try U6DriveGuard(c, ownsMenu: ownsMenu, hasPrivateContent: hasPrivateContent, dockHost: dockHost); value.begin(); return value
    }
    private init(_ c: [String: Any], ownsMenu: @escaping (NSMenu) -> Bool, hasPrivateContent: @escaping () -> Bool,
                 dockHost: StaticDockPreviewHost) throws {
        self.ownsMenu = ownsMenu; self.hasPrivateContent = hasPrivateContent
        self.dockHost = dockHost
        guard let runID = c["runID"] as? String, let epoch = c["epoch"] as? String,
              let start = c["start"] as? Double, let expiry = c["expiresAt"] as? Double,
              expiry.isFinite, start.isFinite, expiry > start, expiry-start <= 1200,
              Date().timeIntervalSince1970 < expiry, let lease = c["lease"] as? String,
              let stop = c["stop"] as? String, let observations = c["observations"] as? String,
              let menuRequest = c["menuRequest"] as? String else { throw Failure.invalid }
        self.runID=runID;self.epoch=epoch;self.expiry=expiry
        self.lease=URL(fileURLWithPath:lease);self.stop=URL(fileURLWithPath:stop);self.observations=URL(fileURLWithPath:observations);self.menuRequest=URL(fileURLWithPath:menuRequest)
    }
    private func begin() {
        emit("started")
        for name in [NSMenu.didBeginTrackingNotification, NSMenu.didEndTrackingNotification] {
            menuObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    guard let self, let menu = note.object as? NSMenu, self.ownsMenu(menu) else { return }
                    if note.name == NSMenu.didBeginTrackingNotification {
                        self.trackedMenus.insert(ObjectIdentifier(menu))
                        let instanceID = String(UInt(bitPattern: ObjectIdentifier(menu)))
                        if self.statusMenuOwner?(menu) == true { self.activeStatusInstanceID = instanceID }
                        if self.hasPrivateContent() { self.retainedItems += menu.items; self.priorPrivateContent = true; self.privateMenuInstanceIDs.insert(instanceID) }
                        self.emitObject("menu-begin", fields:["privateContent":self.hasPrivateContent(), "instanceID":instanceID,
                            "surface":self.statusMenuOwner?(menu) == true ? "status" : "dock"])
                    } else {
                        self.trackedMenus.remove(ObjectIdentifier(menu))
                        let instanceID = String(UInt(bitPattern: ObjectIdentifier(menu)))
                        self.emitObject("menu-end", fields:["instanceID":instanceID])
                        if self.activeStatusInstanceID == instanceID { self.activeStatusInstanceID = nil }
                    }
                }
            })
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { self.armed = true }
                else if self.armed { self.finish("owner-preempted") }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        // Exactly one foreground request for the admitted synthetic run.
        NSApplication.shared.activate(); armed = NSApplication.shared.isActive
        tick()
    }
    func observeStatusMenu(composition: EngineDockMenuComposition, ownsStatusMenu: @escaping (NSMenu) -> Bool,
                           actionForItem: @escaping (NSMenuItem) -> StatusMenuAction?) {
        statusMenuOwner = ownsStatusMenu
        arrivalObserver = StatusMenuArrivalObserver(runID: runID, epoch: epoch,
            ownsStatusMenu: ownsStatusMenu, actionForItem: actionForItem,
            pendingRequest: { [weak self] in
                guard let self, let data = try? Data(contentsOf: self.menuRequest), data.count <= 4096 else { return nil }
                return try? JSONDecoder().decode(StatusMenuActionRequest.self, from: data)
            }, isLive: { [weak self] in self?.isLive() == true },
            emit: { [weak self, weak composition] receipt in
                guard let self, let instanceID = self.activeStatusInstanceID else { return }
                var fields = receipt.fields
                fields["menuInstanceID"] = instanceID
                fields["deliveryMethod"] = "axpress-menu-item"
                self.emitObject(receipt.event, fields: fields)
                if receipt.request.action == .refresh, let composition {
                    self.beginRefresh(composition: composition, requestID: receipt.request.requestID)
                }
            })
    }
    private func beginRefresh(composition: EngineDockMenuComposition, requestID: UUID) {
        guard isLive() else { return }
        let before = composition.store.snapshot.rows?.sequence ?? 0
        let id = requestID.uuidString
        emitObject("refresh", fields:["kind":"refresh", "phase":"requested", "requestId":id,
                                      "rowsSequenceBefore":before, "at":Date().timeIntervalSince1970])
        Task { [weak self, weak composition] in
            guard let self, let composition else { return }
            do { _ = try await composition.client.refresh(try .init(), timeout: .seconds(60)) }
            catch {
                self.refreshTerminal("failed", requestID:id, fields:["reason":Self.refreshReason(error)])
                return
            }
            let deadline = min(self.expiry, Date().timeIntervalSince1970 + 60)
            while self.isLive() && Date().timeIntervalSince1970 < deadline {
                if let after = composition.store.snapshot.rows?.sequence, after > before {
                    self.refreshTerminal("completed", requestID:id, fields:["rowsSequenceAfter":after])
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            self.refreshTerminal("failed", requestID:id, fields:["reason":"rows-timeout"])
        }
    }
    private func refreshTerminal(_ phase: String, requestID: String, fields: [String: Any]) {
        emitObject("refresh", fields: fields.merging(["kind":"refresh", "phase":phase,
            "requestId":requestID, "at":Date().timeIntervalSince1970]) { current, _ in current })
    }
    private static func refreshReason(_ error: Error) -> String {
        if let value = error as? EngineClientError {
            switch value {
            case .notReady: return "engine-not-ready"
            case .unsupportedCapability: return "refresh-disabled"
            case .rpc(let code, _): return "engine-rpc-\(code)"
            case .deadlineExceeded: return "engine-deadline"
            default: return "engine-failure"
            }
        }
        return "engine-failure"
    }
    private func isLive() -> Bool {
        let now = Date().timeIntervalSince1970
        guard !ending, now < expiry, !FileManager.default.fileExists(atPath: stop.path),
              let bytes = try? Data(contentsOf: lease), bytes.count <= 16_384,
              let c = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              c["runID"] as? String == runID, c["epoch"] as? String == epoch,
              c["exclusive"] as? Bool == true, c["ownerPreempted"] as? Bool == false,
              let heartbeat = c["guardianHeartbeatAt"] as? Double else { return false }
        return now-heartbeat >= 0 && now-heartbeat <= 2
    }
    private func tick() {
        guard !ending else { return }
        let now = Date().timeIntervalSince1970
        guard now < expiry, !FileManager.default.fileExists(atPath: stop.path),
              let bytes = try? Data(contentsOf: lease), bytes.count <= 16_384,
              let c = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              c["runID"] as? String == runID, c["epoch"] as? String == epoch,
              c["exclusive"] as? Bool == true, c["ownerPreempted"] as? Bool == false,
              let heartbeat = c["guardianHeartbeatAt"] as? Double, now-heartbeat >= 0, now-heartbeat <= 2 else { finish("stop-or-lease-expired"); return }
        let panels = NSApplication.shared.windows.compactMap { $0 as? NSPanel }.filter(\.isVisible)
        let visible = !panels.isEmpty
        let onScreen = panels.contains { panel in NSScreen.screens.contains { $0.visibleFrame.intersects(panel.frame) } }
        let nonActivating = visible && panels.allSatisfy { $0.styleMask.contains(.nonactivatingPanel) }
        emit("doctor", fields:["visible":visible,"onScreen":onScreen,"nonActivating":nonActivating,"ownerStopArmed":armed])
        recordDockSurface()
    }
    private func recordDockSurface() {
        guard let host = dockHost, let panel = host.nativePanel, panel.isVisible,
              let presentation = host.edgePresentation, let frame = presentation.paintedFrame,
              let primary = NSScreen.screens.first, frame.width > 0, frame.height > 0 else { return }
        let state = String(describing: presentation.state)
        let signature = "\(state):\(frame):\(panel.windowNumber)"
        guard signature != lastDockFrameSignature else { return }
        lastDockFrameSignature = signature
        emitObject("dock-surface-frame", fields:["state":state,"windowNumber":panel.windowNumber,
            "x":frame.minX,"y":primary.frame.maxY-frame.maxY,"width":frame.width,"height":frame.height,
            "coordinateSpace":"cg-screen"])
    }
    /// Window-server coordinates in AppKit screen space, only for the owned status item.
    func recordStatusButtonFrame(_ button: NSStatusBarButton) {
        guard let window = button.window, window.isVisible else { return }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard frame.width > 0, frame.height > 0 else { return }
        let fields: [String: Any] = ["x": frame.origin.x, "y": frame.origin.y,
            "width": frame.width, "height": frame.height, "coordinateSpace": "appkit-screen",
            "cgX":frame.minX,"cgY":(NSScreen.screens.first?.frame.maxY ?? 0)-frame.maxY]
        emitObject("status-item-frame", fields: fields)
    }
    private func emitObject(_ event: String, fields: [String: Any]) {
        let object: [String: Any] = event == "refresh"
            ? fields.merging(["runID":runID,"epoch":epoch]) { _, bound in bound }
            : ["runID":runID,"epoch":epoch,"event":event,"timestamp":Date().timeIntervalSince1970,"checks":fields]
        guard let data = try? JSONSerialization.data(withJSONObject:object,options:[.sortedKeys]) else { return }
        if !FileManager.default.fileExists(atPath:observations.path) { FileManager.default.createFile(atPath:observations.path,contents:nil) }
        guard let handle = try? FileHandle(forWritingTo: observations) else { return }
        defer { try? handle.close() }; try? handle.seekToEnd(); try? handle.write(contentsOf:data + Data([10]))
    }
    func recordClear() {
        let scrubbed = !retainedItems.isEmpty && retainedItems.allSatisfy { $0.title.isEmpty && $0.attributedTitle == nil && $0.toolTip == nil && $0.representedObject == nil }
        emitObject("accepted-clear",fields:["priorPrivateContent":priorPrivateContent,"trackingClosed":trackedMenus.isEmpty,
            "scrubbedInstanceIDs":scrubbed ? Array(privateMenuInstanceIDs).sorted() : [],
            "oldItemTitlesScrubbed": !retainedItems.isEmpty && retainedItems.allSatisfy { $0.title.isEmpty },
            "oldItemPrivateAttributesScrubbed": !retainedItems.isEmpty && retainedItems.allSatisfy { $0.attributedTitle == nil && $0.toolTip == nil && $0.representedObject == nil }])
    }
    private func finish(_ reason: String) {
        guard !ending else { return }; ending = true
        emit(reason); timer?.invalidate(); arrivalObserver?.stop(); arrivalObserver = nil
        if !FileManager.default.fileExists(atPath:stop.path), let data = try? JSONSerialization.data(withJSONObject:["runID":runID,"epoch":epoch,"stop":true,"reason":reason]) { try? data.write(to:stop,options:.atomic) }
        NSApplication.shared.terminate(nil)
    }
    private func emit(_ event: String, fields: [String: Bool] = [:]) {
        guard let data = try? JSONSerialization.data(withJSONObject:["runID":runID,"epoch":epoch,"event":event,"timestamp":Date().timeIntervalSince1970,"checks":fields],options:[.sortedKeys]) else { return }
        if !FileManager.default.fileExists(atPath:observations.path) { FileManager.default.createFile(atPath:observations.path,contents:nil) }
        guard let handle = try? FileHandle(forWritingTo: observations) else { return }
        defer { try? handle.close() }; try? handle.seekToEnd(); try? handle.write(contentsOf:data + Data([10]))
    }
    deinit { timer?.invalidate(); for token in menuObservers { NotificationCenter.default.removeObserver(token) }; if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) } }
    private enum Failure: Error { case invalid }
}
#endif
