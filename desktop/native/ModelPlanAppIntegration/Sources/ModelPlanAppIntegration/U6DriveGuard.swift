// SPDX-License-Identifier: MIT
#if MODELPLAN_U6_DRIVE
import AppKit

/// Test-build-only lease/owner stop hook. Emits only scoped booleans, never other-app identity.
@MainActor final class U6DriveGuard {
    private let runID: String, epoch: String
    private let expiry: Double
    private let lease: URL, stop: URL, observations: URL
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private var armed = false, ending = false
    private var menuObservers: [NSObjectProtocol] = []
    private var trackedMenus = Set<ObjectIdentifier>()
    private var retainedItems: [NSMenuItem] = []
    private var priorPrivateContent = false
    private let ownsMenu: (NSMenu) -> Bool
    private let hasPrivateContent: () -> Bool
    static func attach(ownsMenu: @escaping (NSMenu) -> Bool, hasPrivateContent: @escaping () -> Bool) throws -> U6DriveGuard? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--u6-drive-contract"), args.indices.contains(index + 1) else { return nil }
        let data = try Data(contentsOf: URL(fileURLWithPath: args[index + 1]))
        guard data.count <= 16_384, let c = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.invalid }
        let value = try U6DriveGuard(c, ownsMenu: ownsMenu, hasPrivateContent: hasPrivateContent); value.begin(); return value
    }
    private init(_ c: [String: Any], ownsMenu: @escaping (NSMenu) -> Bool, hasPrivateContent: @escaping () -> Bool) throws {
        self.ownsMenu = ownsMenu; self.hasPrivateContent = hasPrivateContent
        guard let runID = c["runID"] as? String, let epoch = c["epoch"] as? String,
              let start = c["start"] as? Double, let expiry = c["expiresAt"] as? Double,
              expiry.isFinite, start.isFinite, expiry > start, expiry-start <= 1200,
              Date().timeIntervalSince1970 < expiry, let lease = c["lease"] as? String,
              let stop = c["stop"] as? String, let observations = c["observations"] as? String else { throw Failure.invalid }
        self.runID=runID;self.epoch=epoch;self.expiry=expiry
        self.lease=URL(fileURLWithPath:lease);self.stop=URL(fileURLWithPath:stop);self.observations=URL(fileURLWithPath:observations)
    }
    private func begin() {
        emit("started")
        for name in [NSMenu.didBeginTrackingNotification, NSMenu.didEndTrackingNotification] {
            menuObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    guard let self, let menu = note.object as? NSMenu, self.ownsMenu(menu) else { return }
                    if note.name == NSMenu.didBeginTrackingNotification {
                        self.trackedMenus.insert(ObjectIdentifier(menu))
                        if self.hasPrivateContent() { self.retainedItems += menu.items; self.priorPrivateContent = true }
                        self.emit("menu-begin", fields:["privateContent":self.hasPrivateContent()])
                    } else { self.trackedMenus.remove(ObjectIdentifier(menu)); self.emit("menu-end") }
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
    }
    func recordClear() {
        emit("accepted-clear",fields:["priorPrivateContent":priorPrivateContent,"trackingClosed":trackedMenus.isEmpty,
            "oldItemTitlesScrubbed": !retainedItems.isEmpty && retainedItems.allSatisfy { $0.title.isEmpty },
            "oldItemPrivateAttributesScrubbed": !retainedItems.isEmpty && retainedItems.allSatisfy { $0.attributedTitle == nil && $0.toolTip == nil && $0.representedObject == nil }])
    }
    private func finish(_ reason: String) {
        guard !ending else { return }; ending = true
        emit(reason); timer?.invalidate()
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
