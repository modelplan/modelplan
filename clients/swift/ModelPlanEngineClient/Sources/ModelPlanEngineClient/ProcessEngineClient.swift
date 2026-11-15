// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

struct ClientRuntime: Sendable {
    var consumerTimeout: Duration = .seconds(30)
    var requestTimeout: Duration = .seconds(30)
    var writeTimeout: Double = 10
    var now: @Sendable () -> Double = { ProcessInfo.processInfo.systemUptime }
    var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
}

struct ClientPending {
    enum Purpose { case initialize, epochProbe, credentialProbe, bootstrap, credentialResult, request }
    let id: WireRequestID
    let method: String
    let purpose: Purpose
    let grant: WireConsentGrantParams?
    var continuation: CheckedContinuation<EngineRequestCompletion, Error>?
    var timeout: Task<Void, Never>?
    var pluginTool: WirePluginTool? = nil
    var memberRefresh = false
    var sent = false
    var receiptKnown = false
    var committedAt: EngineConsentFloor? = nil
    var credentialOperation: String? = nil
    var waitsForSequence: UInt64? = nil
}
struct ClientWrite {
    let data: Data
    let key: String?
    let credentialOperation: String?
}
struct ClientDelivery {
    let id = UUID()
    var event: EngineClientEvent
    let bytes: Int
    let revision: UInt64?
    let epoch: String?
    let requestKey: String?
    var isData: Bool = false
    var clearRevision: UInt64? = nil
    var ready: Bool = false
    var receiptMetadata = false
    var completionError: EngineClientError? = nil
}

/// App-side protocol client. UI state and Security.framework remain with its consumers.
public actor ProcessEngineClient: EngineClient {
    nonisolated let deliveryAuthority = DeliveryAuthority()
    /// Tells this client's lines apart in the app log (the cockpit and the rows each run their own engine child).
    nonisolated let logTag = String(UUID().uuidString.prefix(8)).lowercased()
    let configuration: EngineClientConfiguration
    let consumer: any EngineClientEventConsumer
    let credentialAgent: (any CredentialAgent)?
    let runtime: ClientRuntime
    var child: EngineProcess?
    var unreapedProcess: EngineProcess?
    var stoppingTask: Task<Void, Never>?
    var sessionID = ""
    var floor: EngineConsentFloor?
    var revision: UInt64 = 0
    var sequence: UInt64?
    var deliveredSequence: UInt64?
    var deliveredRowRevision: UInt64?
    var capabilities: Set<String> = []
    var serverVersion: String?
    var handshaken = false
    var gateClosed = true
    var epochUncertain = false
    var clearWaiting: UInt64?
    var epochProbe: String?
    var retiredEpochs: Set<String> = []
    var stopped = false
    var requiresRetry = false
    var fatalMismatch = false
    var stopping = false
    var consumerBlocked = false
    var requestCounter: UInt64 = 0
    var pending: [String: ClientPending] = [:]
    var starts: [UUID: CheckedContinuation<EngineDeliveryContext, Error>] = [:]
    var writes: [ClientWrite] = []
    var controlWrites: [ClientWrite] = []
    var writerRunning = false
    var deliveries: [ClientDelivery] = []
    var controls: [ClientDelivery] = []
    var delivering: ClientDelivery?
    var deliveryTask: Task<Void, Never>?
    var deliveryTimer: Task<Void, Never>?
    var restartTask: Task<Void, Never>?
    var rowsBootstrapRetry: Task<Void, Never>?
    var rowsBootstrapBusyCount = 0
    /// Recovery contract: a failed or timed-out epoch probe is retried with a capped backoff, never left closed.
    var epochProbeRetry: Task<Void, Never>?
    var epochProbeAttempts = 0
    /// Recovery contract: a stalled consumer stops the child; once its outstanding consume returns, a fresh session starts.
    var stallRecoveryPending = false
    var stalledProcess: EngineProcess?
    var budget = RestartBudget()
    var facts: WireEnvelope<WireConsentFacts>?
    var intents: [String: CredentialIntent] = [:]
    var usedActions: [UUID: Double] = [:]
    var interactiveRequestIDs: [String: Double] = [:]
    var seenCredentialOperations: Set<String> = []
    var credentialRequests: [String: CredentialWaiting] = [:]
    var credentialWorkers: [String: CredentialWorker] = [:]

    public init(configuration: EngineClientConfiguration, initialFloor: EngineConsentFloor? = nil,
                credentialAgent: (any CredentialAgent)? = nil,
                consumer: any EngineClientEventConsumer) {
        self.configuration = configuration; self.floor = initialFloor
        self.credentialAgent = credentialAgent; self.consumer = consumer
        self.runtime = ClientRuntime()
    }
    init(configuration: EngineClientConfiguration, initialFloor: EngineConsentFloor? = nil,
         credentialAgent: (any CredentialAgent)? = nil, consumer: any EngineClientEventConsumer,
         runtime: ClientRuntime) {
        self.configuration = configuration; self.floor = initialFloor
        self.credentialAgent = credentialAgent; self.consumer = consumer; self.runtime = runtime
    }
    deinit {
        restartTask?.cancel(); rowsBootstrapRetry?.cancel(); epochProbeRetry?.cancel(); deliveryTask?.cancel(); deliveryTimer?.cancel()
        let current = child
        let abandoned = unreapedProcess
        if let current { Task { _ = await current.finish() } }
        else if let abandoned { Task { _ = await abandoned.finish() } }
    }
    func hasOpenFloor(_ value: EngineConsentFloor) -> Bool { floor == value && !gateClosed }
    func consumerHasStopped() -> Bool { consumerBlocked && stopped }
    func confirmationIsPendingOrFailed() -> Bool { epochUncertain && epochProbe == nil }
    var processIdentifier: Int32? { child?.process.processIdentifier }
    var context: EngineDeliveryContext? {
        floor.map { EngineDeliveryContext(sessionID: sessionID, floor: $0, revision: revision) }
    }

    public nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool {
        deliveryAuthority.isCurrent(context)
    }

    public func supportsCapability(_ capability: String) async -> Bool {
        handshaken && !gateClosed && capabilities.contains(capability)
    }

    public func acceptedServerVersion() async -> String? {
        handshaken && !gateClosed ? serverVersion : nil
    }

    public func start() async throws -> EngineDeliveryContext {
        if Task.isCancelled { throw EngineClientError.interrupted(.notSent) }
        guard !consumerBlocked && !requiresRetry && !stopping else { throw EngineClientError.notReady }
        if handshaken && !gateClosed, let current = context { return current }
        guard starts.count < 16 else { throw EngineClientError.localBusy }
        let id = UUID(); let cancellation = RequestCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                starts[id] = continuation
                cancellation.install { [weak self] in Task { await self?.cancelStart(id) } }
                if child == nil && restartTask == nil { stopped = false; launch() }
            }
        } onCancel: { cancellation.cancel() }
    }
    func cancelStart(_ id: UUID) { starts.removeValue(forKey: id)?.resume(throwing: EngineClientError.interrupted(.cancelled)) }
    public func retry() async throws -> EngineDeliveryContext {
        if fatalMismatch { throw EngineClientError.protocolMismatch }
        guard !consumerBlocked else { throw EngineClientError.notReady }
        guard !stopping else { throw EngineClientError.notReady }
        await stop()
        guard unreapedProcess == nil else { throw EngineClientError.interrupted(.connectionLost) }
        stopped = false; stopping = false; requiresRetry = false; budget = RestartBudget()
        return try await start()
    }
    public func stop() async {
        deliveryAuthority.replace(with: nil)
        if let stoppingTask { await stoppingTask.value; return }
        stopped = true; stopping = true; stallRecoveryPending = false; stalledProcess = nil
        rowsBootstrapRetry?.cancel(); rowsBootstrapRetry = nil; rowsBootstrapBusyCount = 0
        epochProbeRetry?.cancel(); epochProbeRetry = nil; epochProbeAttempts = 0
        let retiring = restartTask
        retiring?.cancel(); restartTask = nil
        let process = child ?? unreapedProcess
        let wasWriting = writerRunning
        child = nil; handshaken = false
        writes.removeAll(); controlWrites.removeAll(); writerRunning = false
        failRequests(EngineClientError.interrupted(.cancelled))
        failStarts(EngineClientError.interrupted(.cancelled))
        invalidate(.stopped, next: floor)
        let task = Task { [weak self] in
            // Join retirement before a retry may spawn another child.
            await retiring?.value
            var reaped = true
            if let process {
                if !wasWriting, let data = try? encodedRequest("shutdown", id: .string("shutdown-" + UUID().uuidString), params: .object([:])) {
                    try? await process.send(data, timeout: 2)
                }
                reaped = await process.finish()
            }
            await self?.stopFinished(process: process, reaped: reaped)
        }
        stoppingTask = task
        await task.value
    }
    func stopFinished(process: EngineProcess?, reaped: Bool) {
        if !reaped, let process { unreapedProcess = process; requiresRetry = true }
        else if let process, unreapedProcess?.id == process.id { unreapedProcess = nil }
        stopping = false; stoppingTask = nil
        emit(.connection(.stopped(unreapedProcess == nil ? .requested : .processCleanupFailed)))
    }

    /// Capabilities the client declares in `initialize`. The server only attaches an opt-in field (for example
    /// `rows.Account.Today`, which feeds the today tokens and t/s) when the client lists its capability, so a
    /// feature the app renders must be listed here. scripts/tests/capability-handshake.test.mjs checks this list
    /// against the server's advertised capabilities.
    static func declaredCapabilities(withCredentials: Bool) -> [String] {
        ["rows", "consent", "diagnostics", "refresh", "history", "cockpit", "cockpitDetailsV1", "cockpitForecastV1", "cockpitHistoryV1", "cockpitModelsV1", "cockpitSessionsV1", "cockpitPeaksV1", "publication", "plugin_install", "history_import_v1", "reader_key", "resetEvents", "memberRefreshV1", "windowSourcesV1", "resetEventLinksV1", "accountTodayV1"] + (withCredentials ? ["credentials"] : [])
    }

    func launch() {
        guard child == nil && unreapedProcess == nil && !stopped && !consumerBlocked && !stopping else { return }
        deliveryAuthority.replace(with: nil)
        do {
            try validateConfiguration()
            sessionID = "s-" + UUID().uuidString.lowercased()
            let token = UUID()
            handshaken = false; sequence = nil; deliveredSequence = nil; deliveredRowRevision = nil; gateClosed = true
            retiredEpochs.removeAll(); capabilities.removeAll(); serverVersion = nil; facts = nil
            seenCredentialOperations.removeAll()
            emit(.connection(.starting))
            let process = try EngineProcess(id: token, configuration: configuration, writeTimeout: runtime.writeTimeout,
                frame: { [weak self] id, bytes in await self?.receive(id, bytes: bytes) },
                ended: { [weak self] id, badFrame in await self?.ended(id, protocolFault: badFrame) })
            child = process
            let params = try WireInitializeParams(sessionId: sessionID, protocolVersion: WireProtocol.version,
                appVersion: configuration.applicationVersion,
                capabilities: Self.declaredCapabilities(withCredentials: credentialAgent != nil))
            _ = try enqueue("initialize", params: wireJSON(params), purpose: .initialize, timeout: runtime.requestTimeout)
        } catch {
            failStarts(error as? EngineClientError ?? .invalidConfiguration)
            if let process = child { ended(process.id, protocolFault: false) }
            else if case EngineClientError.invalidConfiguration = error { stopped = true; emit(.connection(.stopped(.requested))) }
            // Recovery contract: a child that could not be spawned is a crash for the budget, not a stop.
            else { superviseCrash(reaping: nil, planned: false) }
        }
    }
    func validateConfiguration() throws {
        let allowed = WireChildEnvironment.allowedKeys
        guard configuration.executableURL.isFileURL,
              FileManager.default.isExecutableFile(atPath: configuration.executableURL.path),
              !configuration.applicationVersion.isEmpty,
              configuration.allowedEnvironment.keys.allSatisfy(allowed.contains),
              let home = configuration.allowedEnvironment["HOME"], !home.isEmpty,
              let temporary = configuration.allowedEnvironment["TMPDIR"], !temporary.isEmpty else { throw EngineClientError.invalidConfiguration }
    }

    func ended(_ id: UUID, protocolFault: Bool, planned: Bool = false) {
        guard let process = child, process.id == id else { return }
        deliveryAuthority.replace(with: nil)
        child = nil; handshaken = false; writerRunning = false
        rowsBootstrapRetry?.cancel(); rowsBootstrapRetry = nil; rowsBootstrapBusyCount = 0
        epochProbeRetry?.cancel(); epochProbeRetry = nil; epochProbeAttempts = 0
        writes.removeAll(); controlWrites.removeAll(); epochProbe = nil
        failRequests(.interrupted(.connectionLost)); failStarts(.interrupted(.connectionLost))
        invalidate(protocolFault ? .protocolFault : .connectionLost, next: floor)
        guard !stopped && !stopping else {
            Task { [weak self] in if !(await process.finish()) { await self?.cleanupFailed(process) } }
            return
        }
        superviseCrash(reaping: process, planned: planned)
    }
    /// The engine supervisor (recovery contract, step 5): reap the old child first, then restart after the budget's
    /// backoff; past the crash limit, a cooldown and then one automatic half-open attempt. `.stopped(.crashLimit)` still
    /// tells the app the engine is cooling down; start() refuses until the half-open attempt (retry() skips the wait).
    func superviseCrash(reaping process: EngineProcess?, planned: Bool) {
        let decision: RestartBudget.Decision = planned ? .restart(after: 0) : budget.recordCrash(at: runtime.now())
        let delay: Double, halfOpen: Bool
        switch decision {
        case .restart(let after):
            delay = after; halfOpen = false
            emit(.connection(.restarting(attempt: after == 0 ? 0 : Int(log2(after)) + 1, delay: .seconds(after))))
        case .cooldown(let after):
            delay = after; halfOpen = true; requiresRetry = true
            emit(.connection(.stopped(.crashLimit)))
        }
        let sleep = runtime.sleep
        restartTask = Task { [weak self] in
            // Never two children: the old one is reaped before another can be spawned.
            if let process, !(await process.finish()) { await self?.cleanupFailed(process); return }
            guard let self else { return }
            do { try await sleep(.seconds(delay)); try Task.checkCancellation(); await self.restartFinished(launch: true, halfOpen: halfOpen) }
            catch { await self.restartFinished(launch: false, halfOpen: false) }
        }
    }
    /// A child that would not exit is re-reaped with a capped backoff; once it is gone a fresh session starts by itself.
    func cleanupFailed(_ process: EngineProcess) {
        deliveryAuthority.replace(with: nil)
        unreapedProcess = process; requiresRetry = true; restartTask = nil
        emit(.connection(.stopped(.processCleanupFailed)))
        scheduleReap(process, attempt: 0)
    }
    func scheduleReap(_ process: EngineProcess, attempt: Int) {
        guard !stopping else { return }
        let sleep = runtime.sleep, delay = min(60, 5 * pow(2, Double(min(attempt, 6))))
        restartTask = Task { [weak self] in
            do { try await sleep(.seconds(delay)); try Task.checkCancellation() } catch { return }
            let reaped = await process.finish()
            await self?.reapFinished(process, reaped: reaped, attempt: attempt)
        }
    }
    func reapFinished(_ process: EngineProcess, reaped: Bool, attempt: Int) {
        restartTask = nil
        guard unreapedProcess?.id == process.id, !stopping else { return }
        guard reaped else { scheduleReap(process, attempt: attempt + 1); return }
        unreapedProcess = nil; requiresRetry = false
        if !stopped && !consumerBlocked { launch() }
    }
    func restartFinished(launch shouldLaunch: Bool, halfOpen: Bool = false) {
        restartTask = nil
        if halfOpen { requiresRetry = false }
        if shouldLaunch && !stopped { launch() }
    }
    func initializationFailed(_ id: UUID, error: EngineClientError) {
        guard child?.id == id else { return }
        // Public start continuations are separate from the internal initialize
        // request. Resolve them before normal retirement cancels that request.
        failStarts(error)
        ended(id, protocolFault: false)
    }
    func protocolMismatch() {
        deliveryAuthority.replace(with: nil)
        stopped = true; requiresRetry = true; fatalMismatch = true
        failStarts(.protocolMismatch)
        if let process = child { ended(process.id, protocolFault: false) }
        emit(.connection(.stopped(.protocolMismatch)))
    }
    func failStarts(_ error: EngineClientError) {
        let waiters = starts; starts.removeAll()
        for waiter in waiters.values { waiter.resume(throwing: error) }
    }
    func nextID() throws -> WireRequestID {
        guard requestCounter < UInt64.max else { throw EngineClientError.localBusy }
        requestCounter += 1
        return .string("r-" + String(requestCounter))
    }
    func isControl(_ method: String) -> Bool {
        ["initialize", "shutdown", "consent/grant", "consent/get", "credentials/result", "$/cancel"].contains(method)
    }
    @discardableResult
    func enqueue(_ method: String, params: WireJSONValue, purpose: ClientPending.Purpose,
                 grant: WireConsentGrantParams? = nil, pluginTool: WirePluginTool? = nil, timeout: Duration,
                 reservedID: WireRequestID? = nil,
                 continuation: CheckedContinuation<EngineRequestCompletion, Error>? = nil) throws -> String {
        guard child != nil else { throw EngineClientError.notReady }
        let control = isControl(method)
        let normal = pending.values.filter { !isControl($0.method) || $0.method == "consent/get" }.count
        let queries = pending.values.filter { ["history/query", "cockpit/query"].contains($0.method) }.count
        let privileged = control && method != "consent/get" || purpose == .epochProbe || purpose == .credentialProbe
        guard privileged ? pending.count < 256 : normal < 16,
              !["history/query", "cockpit/query"].contains(method) || queries < 2 else { throw EngineClientError.localBusy }
        if ["rows/subscribe", "history/query", "cockpit/query", "publication/get", "plugin/install"].contains(method) {
            let reserved = pending.values.filter { ["rows/subscribe", "history/query", "cockpit/query", "publication/get", "plugin/install"].contains($0.method) }.count * WireProtocol.maxFrameBytes
            guard reserved + deliveries.reduce(0, { $0 + $1.bytes }) + WireProtocol.maxFrameBytes <= 32 << 20 else { throw EngineClientError.localBusy }
        }
        let id = try reservedID ?? nextID(); let key = requestKey(id)
        let data = try encodedRequest(method, id: id, params: params)
        let current = control ? controlWrites : writes
        guard current.count < (control ? 256 : 64), current.reduce(0, { $0 + $1.data.count }) + data.count <= (control ? 4 << 20 : 32 << 20) else { throw EngineClientError.localBusy }
        var entry = ClientPending(id: id, method: method, purpose: purpose, grant: grant, continuation: continuation)
        entry.pluginTool = pluginTool
        if method == "refresh/request", case .object(let fields) = params { entry.memberRefresh = fields["member"] != nil }
        let token = child!.id
        entry.timeout = Task { [weak self] in
            do { try await Task.sleep(for: timeout); await self?.timedOut(key, child: token) } catch {}
        }
        pending[key] = entry
        let message = ClientWrite(data: data, key: key, credentialOperation: nil)
        if control { controlWrites.append(message) } else { writes.append(message) }
        pumpWriter()
        return key
    }
    func pumpWriter() {
        guard !writerRunning, let process = child else { return }
        writerRunning = true
        Task { [weak self] in
            while let message = await self?.nextWrite(process.id) {
                do { try await process.send(message.data); await self?.writeCompleted(message, child: process.id) }
                catch { await self?.ended(process.id, protocolFault: false); return }
            }
        }
    }
    func nextWrite(_ id: UUID) -> ClientWrite? {
        guard child?.id == id else { return nil }
        while !controlWrites.isEmpty || !writes.isEmpty {
            let message = !controlWrites.isEmpty ? controlWrites.removeFirst() : writes.removeFirst()
            if let key = message.key {
                guard pending[key] != nil else { continue }
                pending[key]?.sent = true
            }
            if let operation = message.credentialOperation, !credentialIsCurrent(operation) {
                if let key = message.key { finishRequest(key, error: .interrupted(.cancelled)) }
                continue
            }
            return message
        }
        writerRunning = false
        return nil
    }
    func writeCompleted(_ message: ClientWrite, child id: UUID) {
        guard child?.id == id, let operation = message.credentialOperation else { return }
        for (provider, waiting) in credentialRequests where waiting.request.operationId == operation {
            waiting.timer?.cancel(); credentialRequests.removeValue(forKey: provider)
        }
    }
    func sendCancel(_ original: WireRequestID) {
        guard let process = child else { return }
        guard controlWrites.count < 256,
              let params = try? WireCancelParams(id: original),
              let data = try? encodedRequest("$/cancel", id: nil, params: wireJSON(params)),
              controlWrites.reduce(0, { $0 + $1.data.count }) + data.count <= 4 << 20 else { ended(process.id, protocolFault: false); return }
        controlWrites.append(ClientWrite(data: data, key: nil, credentialOperation: nil))
        pumpWriter()
    }
    func timedOut(_ key: String, child id: UUID) {
        guard child?.id == id, let entry = pending[key] else { return }
        if entry.sent { sendCancel(entry.id) }
        let error: EngineClientError = (entry.receiptKnown ? nil : entry.grant).map { .mutationOutcomeUnknown(requestID: $0.requestId, expected: EngineConsentFloor(storeEpoch: $0.expectStoreEpoch, generation: $0.expectGeneration)) } ?? .deadlineExceeded(entry.sent ? (entry.method == "plugin/install" ? .outcomeUnknown : .cancelled) : .notSent)
        finishRequest(key, error: error)
        if entry.purpose == .initialize { initializationFailed(id, error: error) }
        if entry.purpose == .epochProbe { epochProbe = nil; emit(.featureFailure(.consent, .staleValue)); scheduleEpochProbeRetry() }
    }
    func cancelRequest(_ key: String) {
        guard let entry = pending[key] else { return }
        if entry.sent { sendCancel(entry.id) }
        let error: EngineClientError
        if entry.sent, let grant = entry.grant, !entry.receiptKnown { error = .mutationOutcomeUnknown(requestID: grant.requestId, expected: EngineConsentFloor(storeEpoch: grant.expectStoreEpoch, generation: grant.expectGeneration)) }
        else { error = .interrupted(entry.sent && entry.method == "plugin/install" ? .outcomeUnknown : .cancelled) }
        finishRequest(key, error: error)
    }
    func finishRequest(_ key: String, error: EngineClientError? = nil) {
        guard let entry = pending.removeValue(forKey: key) else { return }
        entry.timeout?.cancel()
        if let grant = entry.grant { retireIntent(requestID: grant.requestId, unlessCommitted: error == nil) }
        guard let continuation = entry.continuation else { return }
        if let error {
            if let committed = entry.committedAt, let grant = entry.grant {
                if floor?.storeEpoch != committed.storeEpoch { continuation.resume(throwing: EngineClientError.supersededEpoch(requestID: grant.requestId)) }
                else { continuation.resume(throwing: EngineClientError.receiptDeliveryInterrupted(requestID: grant.requestId, committedAt: committed)) }
            } else { continuation.resume(throwing: error) }
        } else { continuation.resume(returning: EngineRequestCompletion(requestID: entry.id)) }
    }
    func failRequests(_ reason: EngineClientError) {
        for key in Array(pending.keys) {
            guard let entry = pending[key] else { continue }
            if entry.sent, let grant = entry.grant, !entry.receiptKnown {
                finishRequest(key, error: .mutationOutcomeUnknown(requestID: grant.requestId, expected: EngineConsentFloor(storeEpoch: grant.expectStoreEpoch, generation: grant.expectGeneration)))
            } else if entry.sent && entry.method == "plugin/install" { finishRequest(key, error: .interrupted(.outcomeUnknown)) }
            else { finishRequest(key, error: reason) }
        }
    }

    func request<T: Encodable & Sendable>(_ method: String, _ params: T, timeout: Duration?, grant: WireConsentGrantParams? = nil, userAction: EngineUserAction? = nil, pluginTool: WirePluginTool? = nil, prepared: (@Sendable (WireRequestID) async -> Void)? = nil) async throws -> EngineRequestCompletion {
        guard handshaken, child != nil, epochProbe == nil, !epochUncertain else { throw EngineClientError.notReady }
        if let capability = ["rows/subscribe": "rows", "consent/get": "consent", "consent/grant": "consent", "history/query": "history", "cockpit/query": "cockpit", "publication/get": "publication", "plugin/install": "plugin_install", "readerkey/set": "reader_key", "readerkey/test": "reader_key", "readerkey/remove": "reader_key", "readerkey/status": "reader_key", "history/import_start": "history_import_v1", "history/import_status": "history_import_v1", "history/import_cancel": "history_import_v1", "history/import_remove": "history_import_v1", "refresh/request": "refresh", "diagnostics/get": "diagnostics"][method], !capabilities.contains(capability) { throw EngineClientError.unsupportedCapability }
        if Task.isCancelled { throw EngineClientError.interrupted(.notSent) }
        let maximum: Duration = method == "plugin/install" ? .seconds(120) : runtime.requestTimeout
        let bound = min(timeout ?? maximum, maximum)
        guard bound > .zero else { throw EngineClientError.deadlineExceeded(.notSent) }
        if let refresh = params as? WireRefreshRequestParams, refresh.member != nil, !capabilities.contains("memberRefreshV1") {
            throw EngineClientError.unsupportedCapability
        }
        let parameters = try wireJSON(params)
        if let grant, let userAction { try registerIntent(grant, action: userAction) }
        let cancellation = RequestCancellation()
        let reservedID: WireRequestID?
        if let prepared {
            let processID = child!.id
            let id = try nextID()
            reservedID = id
            await prepared(id)
            guard handshaken, child?.id == processID, epochProbe == nil, !epochUncertain else { throw EngineClientError.notReady }
            if Task.isCancelled { throw EngineClientError.interrupted(.notSent) }
        } else { reservedID = nil }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    let key = try enqueue(method, params: parameters, purpose: .request, grant: grant, pluginTool: pluginTool, timeout: bound, reservedID: reservedID, continuation: continuation)
                    cancellation.install { [weak self] in Task { await self?.cancelRequest(key) } }
                } catch {
                    if let grant { retireIntent(requestID: grant.requestId, unlessCommitted: false) }
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: { cancellation.cancel() }
    }
    public func subscribeRows(timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("rows/subscribe", WireEmpty(), timeout: timeout) }
    public func consent(timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("consent/get", WireEmpty(), timeout: timeout) }
    public func grant(_ value: WireConsentGrantParams, userAction: EngineUserAction? = nil, timeout: Duration? = nil) async throws -> EngineRequestCompletion {
        // Scope ids only: no account, key or keychain value.
        func ids(_ list: [String]?) -> String { "[" + (list ?? []).map(DiagnosticsLog.safeID).joined(separator: ",") + "]" }
        let scopes = "allow=\(ids(value.allow)) deny=\(ids(value.deny)) forget=\(ids(value.forget)) client=\(logTag)"
        DiagnosticsLog.shared.notice("consent", "grant requested " + scopes)
        do {
            let completion = try await request("consent/grant", value, timeout: timeout, grant: value, userAction: userAction)
            DiagnosticsLog.shared.notice("consent", "grant accepted " + scopes)
            return completion
        } catch {
            DiagnosticsLog.shared.notice("consent", "grant failed error=\(DiagnosticsLog.errorName(error)) " + scopes)
            throw error
        }
    }
    public func refresh(_ value: WireRefreshRequestParams, timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("refresh/request", value, timeout: timeout) }
    public func refresh(_ value: WireRefreshRequestParams, timeout: Duration? = nil,
                        prepared: @escaping @Sendable (WireRequestID) async -> Void) async throws -> EngineRequestCompletion {
        try await request("refresh/request", value, timeout: timeout, prepared: prepared)
    }
    public func history(_ value: WireHistoryQueryParams, timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("history/query", value, timeout: timeout) }
    public func diagnostics(timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("diagnostics/get", WireEmpty(), timeout: timeout) }
    public func cockpit(timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("cockpit/query", WireEmpty(), timeout: timeout) }
    public func pluginInstall(_ value: WirePluginInstallParams, timeout: Duration? = nil) async throws -> EngineRequestCompletion {
        try await request("plugin/install", value, timeout: timeout, pluginTool: value.tool)
    }
    public func readerKey(_ method: EngineReaderKeyMethod, _ params: WireReaderKeyParams, timeout: Duration? = nil) async throws -> EngineRequestCompletion {
        try await request(method.rawValue, params, timeout: timeout)
    }
    public func publication(timeout: Duration? = nil) async throws -> EngineRequestCompletion {
        try await request("publication/get", WireEmpty(), timeout: timeout)
    }
    public func historyImportStart(_ value: WireHistoryImportStartParams, timeout: Duration? = nil) async throws -> EngineRequestCompletion {
        try await request("history/import_start", value, timeout: timeout)
    }
    public func historyImportStatus(timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("history/import_status", WireEmpty(), timeout: timeout) }
    public func historyImportCancel(timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("history/import_cancel", WireEmpty(), timeout: timeout) }
    public func historyImportRemove(timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("history/import_remove", WireEmpty(), timeout: timeout) }
}

final class RequestCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var action: (@Sendable () -> Void)?
    func install(_ action: @escaping @Sendable () -> Void) {
        lock.lock(); self.action = action; let run = cancelled; lock.unlock()
        if run { action() }
    }
    func cancel() {
        lock.lock(); cancelled = true; let run = action; lock.unlock(); run?()
    }
}
