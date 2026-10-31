// SPDX-License-Identifier: MIT
#if MODELPLAN_U6_DRIVE
import AppKit
import ModelPlanMenuVerification
import ModelPlanEngineClient
import ModelPlanWire
import CryptoKit

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
    private final class WeakPrivateItem {
        let id: String
        weak var item: NSMenuItem?
        init(_ item: NSMenuItem) { self.item=item; id=String(UInt(bitPattern:ObjectIdentifier(item))) }
        var cleared: Bool { guard let item else { return true }; return item.title.isEmpty && item.attributedTitle == nil && item.toolTip == nil && item.representedObject == nil && (item.identifier?.rawValue ?? "").isEmpty }
        var state: String { item == nil ? "deallocated" : cleared ? "cleared" : "private" }
    }
    private var privateBySession: [String: [WeakPrivateItem]] = [:]
    private var privateTitleHashBySession: [String: String] = [:]
    private var sessions: [ObjectIdentifier: String] = [:]
    private var objectBySession: [String: String] = [:]
    private var activeStatusSessionID: String?
    private var currentStatusMenu: (() -> NSMenu?)?
    private var activeClear: (id: String, floor: EngineConsentFloor, openSessions: [String])?
    private var priorPrivateContent = false
    private var statusMenuOwner: ((NSMenu) -> Bool)?
    private var activeStatusInstanceID: String?
    private var arrivedRefreshContext: (requestID:UUID, objectID:String, sessionID:String)?
    private var terminalRefreshIDs = Set<String>()
    private var observationSequence: UInt64 = 0
    private var acceptedClearIDs = Set<String>()
    private weak var dockHost: StaticDockPreviewHost?
    private var lastDockFrameSignature: String?
    private let ownsMenu: (NSMenu) -> Bool
    private let hasPrivateContent: () -> Bool
    private let privateTitle: () -> String?
    static func attach(ownsMenu: @escaping (NSMenu) -> Bool, hasPrivateContent: @escaping () -> Bool,
                       privateTitle: @escaping () -> String?,
                       dockHost: StaticDockPreviewHost) throws -> U6DriveGuard? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--u6-drive-contract"), args.indices.contains(index + 1) else { return nil }
        let data = try Data(contentsOf: URL(fileURLWithPath: args[index + 1]))
        guard data.count <= 16_384, let c = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.invalid }
        let value = try U6DriveGuard(c, ownsMenu: ownsMenu, hasPrivateContent: hasPrivateContent,
                                     privateTitle:privateTitle,dockHost: dockHost); value.begin(); return value
    }
    private init(_ c: [String: Any], ownsMenu: @escaping (NSMenu) -> Bool, hasPrivateContent: @escaping () -> Bool,
                 privateTitle:@escaping () -> String?,
                 dockHost: StaticDockPreviewHost) throws {
        self.ownsMenu = ownsMenu; self.hasPrivateContent = hasPrivateContent;self.privateTitle=privateTitle
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
                        let object=ObjectIdentifier(menu)
                        self.trackedMenus.insert(object)
                        let instanceID = String(UInt(bitPattern: object))
                        let sessionID=UUID().uuidString
                        self.sessions[object]=sessionID
                        self.objectBySession[sessionID]=instanceID
                        let status=self.statusMenuOwner?(menu) == true
                        if status { self.activeStatusInstanceID = instanceID;self.activeStatusSessionID=sessionID }
                        if self.hasPrivateContent() { self.priorPrivateContent = true }
                        self.emitObject("menu-begin", fields:["privateContent":self.hasPrivateContent(), "instanceID":instanceID,
                            "subjectPID":ProcessInfo.processInfo.processIdentifier,
                            "surface":status ? "status" : "dock", "menuObjectID":instanceID,"sessionID":sessionID])
                        if status, self.hasPrivateContent(),let title=self.privateTitle(),!title.isEmpty {
                            let items=menu.items.filter { $0.title.contains(title) || $0.attributedTitle?.string.contains(title)==true
                                || $0.toolTip?.contains(title)==true }.map(WeakPrivateItem.init)
                            guard !items.isEmpty else { return }
                            self.privateBySession[sessionID]=items
                            let digest = SHA256.hash(data: Data(title.utf8)).map { String(format:"%02x",$0) }.joined()
                            self.privateTitleHashBySession[sessionID]=digest
                            self.emitObject("menu-private-title-visible", fields:["instanceID":instanceID,"menuObjectID":instanceID,
                                "sessionID":sessionID,"titleSHA256":digest,"privateItemIDs":items.map(\.id)])
                        }
                    } else {
                        let object=ObjectIdentifier(menu)
                        self.trackedMenus.remove(object)
                        let instanceID = String(UInt(bitPattern: object))
                        guard let sessionID=self.sessions.removeValue(forKey:object) else { return }
                        let causedByClear=self.activeClear?.openSessions.contains(sessionID) == true
                        var fields:[String:Any]=["instanceID":instanceID,"menuObjectID":instanceID,"sessionID":sessionID,
                            "cause":causedByClear ? "clear" : "other"]
                        if causedByClear,let clear=self.activeClear { fields["clearID"]=clear.id }
                        self.emitObject("menu-end", fields:fields)
                        if self.activeStatusInstanceID == instanceID { self.activeStatusInstanceID = nil }
                        if self.activeStatusSessionID == sessionID { self.activeStatusSessionID = nil }
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
    func observeStatusMenu(ownsStatusMenu: @escaping (NSMenu) -> Bool,
                           currentStatusMenu: @escaping () -> NSMenu?,
                           actionForItem: @escaping (NSMenuItem) -> StatusMenuAction?) {
        statusMenuOwner = ownsStatusMenu
        self.currentStatusMenu = currentStatusMenu
        arrivalObserver = StatusMenuArrivalObserver(runID: runID, epoch: epoch,
            ownsStatusMenu: ownsStatusMenu, actionForItem: actionForItem,
            pendingRequest: { [weak self] in
                guard let self, let data = try? Data(contentsOf: self.menuRequest), data.count <= 4096 else { return nil }
                return try? JSONDecoder().decode(StatusMenuActionRequest.self, from: data)
            }, isLive: { [weak self] in self?.isLive() == true },
            emit: { [weak self] receipt in
                guard let self, let instanceID = self.activeStatusInstanceID,let sessionID=self.activeStatusSessionID else { return }
                var fields = receipt.fields
                fields["menuInstanceID"] = instanceID
                fields["menuObjectID"] = instanceID
                fields["sessionID"] = sessionID
                fields["deliveryMethod"] = "axpress-menu-item"
                self.emitObject(receipt.event, fields: fields)
                if receipt.request.action == .refresh,let sessionID=self.activeStatusSessionID {
                    self.arrivedRefreshContext=(receipt.request.requestID,instanceID,sessionID)
                }
            })
    }
    struct RefreshObservation {
        let prepared: @MainActor @Sendable (WireRequestID) -> Void
        let result: @MainActor (Result<EngineMenuRefreshResult,Error>) -> Void
    }
    func beginProductRefresh(composition: EngineDockMenuComposition) -> RefreshObservation? {
        guard isLive(), let context = arrivedRefreshContext else { return nil }
        arrivedRefreshContext = nil
        let before = composition.store.snapshot.rows?.sequence ?? 0
        let accountsBefore=composition.store.snapshot.rows?.projection.rows.first(where: { $0.id=="copilot" })?.accounts.count ?? 0
        let id = context.requestID.uuidString
        var requestedMono=ProcessInfo.processInfo.systemUptime
        let prepared: @MainActor @Sendable (WireRequestID) -> Void = { [weak self] engineID in
        guard let self else { return }
        requestedMono=ProcessInfo.processInfo.systemUptime
        let encoded=(try? JSONEncoder().encode(engineID)).flatMap { try? JSONSerialization.jsonObject(with:$0,options:.fragmentsAllowed) } ?? "unknown"
        self.emitObject("refresh", fields:["kind":"refresh", "phase":"requested", "requestId":id,"engineRequestID":encoded,
                                      "rowsSequenceBefore":before,"copilotAccountsBefore":accountsBefore,
                                      "menuObjectID":context.objectID,"sessionID":context.sessionID])
        Task { [weak self] in
            while let self,self.isLive(),ProcessInfo.processInfo.systemUptime<requestedMono+60 {
                try? await Task.sleep(for:.milliseconds(100))
            }
            if let self {
                let deadline=ProcessInfo.processInfo.systemUptime>=requestedMono+60 || Date().timeIntervalSince1970>=self.expiry
                self.refreshTerminal("abandoned",requestID:id,context:context,
                    fields:["cause":deadline ? "deadline" : "stop"])
            }
        }
        }
        return RefreshObservation(prepared:prepared,result: { [weak self, weak composition] result in
            guard let self, let composition,!self.terminalRefreshIDs.contains(id) else { return }
            switch result {
            case .failure(let error):
                self.refreshTerminal("failed", requestID:id, context:context,fields:["reason":Self.refreshReason(error)])
            case .success(let reply):
                let dispositions=Dictionary(reply.scheduled.map { ($0.scope,$0.disabledReason?.rawValue ?? "scheduled") },uniquingKeysWith: { first,_ in first })
                let encoded=(try? JSONEncoder().encode(reply.engineRequestID)).flatMap { try? JSONSerialization.jsonObject(with:$0,options:.fragmentsAllowed) } ?? "unknown"
                self.emitObject("refresh",fields:["kind":"refresh","phase":"accepted","requestId":id,
                    "engineRequestID":encoded,"dispositions":dispositions,"menuObjectID":context.objectID,"sessionID":context.sessionID])
                if dispositions["copilot.runtime_usage"] != "scheduled" {
                    self.refreshTerminal("deferred",requestID:id,context:context,fields:[:]);return
                }
                Task { await self.waitForRefreshedRows(composition:composition, before:before, requestID:id,
                    requestedMono:requestedMono,context:context) }
            }
        })
    }
    private func waitForRefreshedRows(composition: EngineDockMenuComposition, before: UInt64, requestID: String,
                                     requestedMono:Double,context:(requestID:UUID,objectID:String,sessionID:String)) async {
        while isLive() && ProcessInfo.processInfo.systemUptime<requestedMono+60 {
            if let projection=composition.store.snapshot.rows,projection.sequence>before,
               let row=projection.projection.rows.first(where: { $0.id=="copilot" }),!row.accounts.isEmpty,
               let digest=try? U6ReadingFingerprint.sha256(row.accounts) {
                refreshTerminal("completed", requestID:requestID,context:context,
                    fields:["rowsSequenceAfter":projection.sequence,"copilotAccountsAfter":row.accounts.count,"readingSHA256":digest]); return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        let deadline=ProcessInfo.processInfo.systemUptime>=requestedMono+60 || Date().timeIntervalSince1970>=expiry
        refreshTerminal("abandoned",requestID:requestID,context:context,
            fields:["cause":deadline ? "deadline" : "stop"])
    }
    private func refreshTerminal(_ phase: String, requestID: String,
                                 context:(requestID:UUID,objectID:String,sessionID:String), fields: [String: Any]) {
        guard terminalRefreshIDs.insert(requestID).inserted else { return }
        emitObject("refresh", fields: fields.merging(["kind":"refresh", "phase":phase,
            "requestId":requestID,"menuObjectID":context.objectID,"sessionID":context.sessionID]) { current, _ in current })
    }
    private static func refreshReason(_ error: Error) -> String {
        if let value = error as? EngineClientError {
            switch value {
            case .notReady, .unsupportedCapability: return "engine-disabled"
            case .deadlineExceeded: return "timeout"
            case .rpc: return "engine-error"
            default: return "engine-error"
            }
        }
        return "unknown"
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
        observationSequence &+= 1
        let now = Date().timeIntervalSince1970
        guard let data = try? U6NativeReceiptSerializer.encode(event:event,fields:fields,runID:runID,epoch:epoch,
            pid:ProcessInfo.processInfo.processIdentifier,seq:observationSequence,
            mono:ProcessInfo.processInfo.systemUptime,at:now) else { return }
        if !FileManager.default.fileExists(atPath:observations.path) { FileManager.default.createFile(atPath:observations.path,contents:nil) }
        guard let handle = try? FileHandle(forWritingTo: observations) else { return }
        defer { try? handle.close() }; _ = try? handle.seekToEnd(); try? handle.write(contentsOf:data)
    }
    func recordClearInitiated(_ invalidation: EngineInvalidation) {
        guard let floor=invalidation.nextFloor else { return }
        let open=trackedMenus.compactMap { sessions[$0] }.sorted()
        let clear=(id:UUID().uuidString,floor:floor,openSessions:open)
        activeClear=clear
        emitObject("clear-initiated",fields:["clearID":clear.id,"storeEpochAfter":floor.storeEpoch,
            "generationAfter":floor.generation,"openSessionIDs":open])
    }
    func recordClear() {
        guard let clear=activeClear,!acceptedClearIDs.contains(clear.id) else { return }
        acceptedClearIDs.insert(clear.id)
        let scrubbed=clear.openSessions.filter { session in
            guard let items=privateBySession[session],!items.isEmpty else { return false }
            return items.allSatisfy(\.cleared)
        }
        emitObject("accepted-clear",fields:["clearID":clear.id,"storeEpochAfter":clear.floor.storeEpoch,
            "generationAfter":clear.floor.generation,"scrubbedSessionIDs":scrubbed,
            "priorPrivateContent":priorPrivateContent,"trackingClosed":trackedMenus.isEmpty])
        for session in clear.openSessions {
            guard let items=privateBySession[session],!items.isEmpty,let objectID=objectBySession[session] else { continue }
            let hash=privateTitleHashBySession[session]
            let current=currentStatusMenu?()?.items ?? []
            func matchesPrivateHash(_ value:String?) -> Bool {
                guard let value,let hash else { return false }
                return SHA256.hash(data:Data(value.utf8)).map { String(format:"%02x",$0) }.joined() == hash
            }
            let titlePresent=current.contains { item in
                matchesPrivateHash(item.title)
            }
            let privateAttributes=current.reduce(0) { count,item in
                count + (matchesPrivateHash(item.attributedTitle?.string) ? 1 : 0)
                    + (matchesPrivateHash(item.toolTip) ? 1 : 0)
                    + (matchesPrivateHash(item.representedObject as? String) ? 1 : 0)
                    + (matchesPrivateHash(item.identifier?.rawValue) ? 1 : 0)
            }
            emitObject("menu-scrubbed",fields:["clearID":clear.id,"sessionID":session,
                "menuObjectID":objectID,"privateTitlePresent":titlePresent,
                "privateAttributeCount":privateAttributes,
                "itemStates":items.map { ["id":$0.id,"state":$0.state] }])
        }
    }
    func recordTerminateCompleted() { emit("terminate-completed") }
    private func finish(_ reason: String) {
        guard !ending else { return }; ending = true
        emit(reason); timer?.invalidate(); arrivalObserver?.stop(); arrivalObserver = nil
        if !FileManager.default.fileExists(atPath:stop.path), let data = try? JSONSerialization.data(withJSONObject:["runID":runID,"epoch":epoch,"stop":true,"reason":reason]) { try? data.write(to:stop,options:.atomic) }
        NSApplication.shared.terminate(nil)
    }
    private func emit(_ event: String, fields: [String: Bool] = [:]) {
        emitObject(event,fields:fields)
    }
    deinit { timer?.invalidate(); for token in menuObservers { NotificationCenter.default.removeObserver(token) }; if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) } }
    private enum Failure: Error { case invalid }
}
#endif
