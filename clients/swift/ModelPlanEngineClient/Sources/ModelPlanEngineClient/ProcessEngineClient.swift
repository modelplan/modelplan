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
        restartTask?.cancel(); deliveryTask?.cancel(); deliveryTimer?.cancel()
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
        if let stoppingTask { await stoppingTask.value; return }
        stopped = true; stopping = true
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

    func launch() {
        guard child == nil && unreapedProcess == nil && !stopped && !consumerBlocked && !stopping else { return }
        do {
            try validateConfiguration()
            sessionID = "s-" + UUID().uuidString.lowercased()
            let token = UUID()
            handshaken = false; sequence = nil; deliveredSequence = nil; deliveredRowRevision = nil; gateClosed = true
            retiredEpochs.removeAll(); capabilities.removeAll(); facts = nil
            seenCredentialOperations.removeAll()
            emit(.connection(.starting))
            let process = try EngineProcess(id: token, configuration: configuration, writeTimeout: runtime.writeTimeout,
                frame: { [weak self] id, bytes in await self?.receive(id, bytes: bytes) },
                ended: { [weak self] id, badFrame in await self?.ended(id, protocolFault: badFrame) })
            child = process
            let params = try WireInitializeParams(sessionId: sessionID, protocolVersion: WireProtocol.version,
                appVersion: configuration.applicationVersion,
                capabilities: ["rows", "consent", "diagnostics", "refresh", "history", "publication", "plugin_install"] + (credentialAgent == nil ? [] : ["credentials"]))
            _ = try enqueue("initialize", params: wireJSON(params), purpose: .initialize, timeout: runtime.requestTimeout)
        } catch {
            failStarts(error as? EngineClientError ?? .invalidConfiguration)
            if let process = child { ended(process.id, protocolFault: false) }
            else { stopped = true; emit(.connection(.stopped(.requested))) }
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
        child = nil; handshaken = false; writerRunning = false
        writes.removeAll(); controlWrites.removeAll(); epochProbe = nil
        failRequests(.interrupted(.connectionLost)); failStarts(.interrupted(.connectionLost))
        invalidate(protocolFault ? .protocolFault : .connectionLost, next: floor)
        guard !stopped && !stopping else {
            Task { [weak self] in if !(await process.finish()) { await self?.cleanupFailed(process) } }
            return
        }
        let delay: Double? = planned ? 0 : budget.recordCrash(at: runtime.now())
        if let delay { emit(.connection(.restarting(attempt: delay == 0 ? 0 : Int(log2(delay)) + 1, delay: .seconds(delay)))) }
        else { stopped = true; requiresRetry = true; emit(.connection(.stopped(.crashLimit))) }
        let sleep = runtime.sleep
        restartTask = Task { [weak self] in
            let reaped = await process.finish()
            guard let self else { return }
            if !reaped { await self.cleanupFailed(process); return }
            guard let delay else { await self.restartFinished(launch: false); return }
            do { try await sleep(.seconds(delay)); try Task.checkCancellation(); await self.restartFinished(launch: true) }
            catch { await self.restartFinished(launch: false) }
        }
    }
    func cleanupFailed(_ process: EngineProcess) { unreapedProcess = process; stopped = true; requiresRetry = true; restartTask = nil; emit(.connection(.stopped(.processCleanupFailed))) }
    func restartFinished(launch shouldLaunch: Bool) {
        restartTask = nil
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
                 grant: WireConsentGrantParams? = nil, timeout: Duration,
                 continuation: CheckedContinuation<EngineRequestCompletion, Error>? = nil) throws -> String {
        guard child != nil else { throw EngineClientError.notReady }
        let control = isControl(method)
        let normal = pending.values.filter { !isControl($0.method) || $0.method == "consent/get" }.count
        let queries = pending.values.filter { ["history/query", "cockpit/query"].contains($0.method) }.count
        let privileged = control && method != "consent/get" || purpose == .epochProbe || purpose == .credentialProbe
        guard privileged ? pending.count < 256 : normal < 16,
              method != "history/query" || queries < 2 else { throw EngineClientError.localBusy }
        if ["rows/subscribe", "history/query"].contains(method) {
            let reserved = pending.values.filter { ["rows/subscribe", "history/query"].contains($0.method) }.count * WireProtocol.maxFrameBytes
            guard reserved + deliveries.reduce(0, { $0 + $1.bytes }) + WireProtocol.maxFrameBytes <= 32 << 20 else { throw EngineClientError.localBusy }
        }
        let id = try nextID(); let key = requestKey(id)
        let data = try encodedRequest(method, id: id, params: params)
        let current = control ? controlWrites : writes
        guard current.count < (control ? 256 : 64), current.reduce(0, { $0 + $1.data.count }) + data.count <= (control ? 4 << 20 : 32 << 20) else { throw EngineClientError.localBusy }
        var entry = ClientPending(id: id, method: method, purpose: purpose, grant: grant, continuation: continuation)
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
        let error: EngineClientError = (entry.receiptKnown ? nil : entry.grant).map { .mutationOutcomeUnknown(requestID: $0.requestId, expected: EngineConsentFloor(storeEpoch: $0.expectStoreEpoch, generation: $0.expectGeneration)) } ?? .deadlineExceeded(entry.sent ? .cancelled : .notSent)
        finishRequest(key, error: error)
        if entry.purpose == .initialize { initializationFailed(id, error: error) }
        if entry.purpose == .epochProbe { epochProbe = nil; emit(.featureFailure(.consent, .staleValue)) }
    }
    func cancelRequest(_ key: String) {
        guard let entry = pending[key] else { return }
        if entry.sent { sendCancel(entry.id) }
        let error: EngineClientError
        if entry.sent, let grant = entry.grant, !entry.receiptKnown { error = .mutationOutcomeUnknown(requestID: grant.requestId, expected: EngineConsentFloor(storeEpoch: grant.expectStoreEpoch, generation: grant.expectGeneration)) }
        else { error = .interrupted(.cancelled) }
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

    func request<T: Encodable & Sendable>(_ method: String, _ params: T, timeout: Duration?, grant: WireConsentGrantParams? = nil, userAction: EngineUserAction? = nil) async throws -> EngineRequestCompletion {
        guard handshaken, child != nil, epochProbe == nil, !epochUncertain else { throw EngineClientError.notReady }
        if let capability = ["rows/subscribe": "rows", "consent/get": "consent", "consent/grant": "consent", "history/query": "history", "refresh/request": "refresh", "diagnostics/get": "diagnostics"][method], !capabilities.contains(capability) { throw EngineClientError.unsupportedCapability }
        if Task.isCancelled { throw EngineClientError.interrupted(.notSent) }
        let maximum: Duration = method == "plugin/install" ? .seconds(120) : runtime.requestTimeout
        let bound = min(timeout ?? maximum, maximum)
        guard bound > .zero else { throw EngineClientError.deadlineExceeded(.notSent) }
        let parameters = try wireJSON(params)
        if let grant, let userAction { try registerIntent(grant, action: userAction) }
        let cancellation = RequestCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    let key = try enqueue(method, params: parameters, purpose: .request, grant: grant, timeout: bound, continuation: continuation)
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
    public func grant(_ value: WireConsentGrantParams, userAction: EngineUserAction? = nil, timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("consent/grant", value, timeout: timeout, grant: value, userAction: userAction) }
    public func refresh(_ value: WireRefreshRequestParams, timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("refresh/request", value, timeout: timeout) }
    public func history(_ value: WireHistoryQueryParams, timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("history/query", value, timeout: timeout) }
    public func diagnostics(timeout: Duration? = nil) async throws -> EngineRequestCompletion { try await request("diagnostics/get", WireEmpty(), timeout: timeout) }
    public func pluginInstall(_ value: WirePluginInstallParams, timeout: Duration? = nil) async throws -> EngineRequestCompletion {
        guard handshaken, !epochUncertain else { throw EngineClientError.notReady }
        guard capabilities.contains("plugin_install") else { throw EngineClientError.unsupportedCapability }
        // No generated result root exists yet. Never execute a host mutation and
        // then label an unchecked JSON body a successful installation.
        emit(.featureFailure(.pluginInstall, .featureDecode(.pluginInstall)))
        throw EngineClientError.featureDecode(.pluginInstall)
    }
    public func publication(timeout: Duration? = nil) async throws -> EngineRequestCompletion {
        guard handshaken, !epochUncertain else { throw EngineClientError.notReady }
        guard capabilities.contains("publication") else { throw EngineClientError.unsupportedCapability }
        emit(.featureFailure(.publication, .featureDecode(.publication)))
        throw EngineClientError.featureDecode(.publication)
    }
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
