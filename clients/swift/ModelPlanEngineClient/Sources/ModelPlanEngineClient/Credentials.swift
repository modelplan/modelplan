// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

struct CredentialIntent {
    let action: EngineUserAction
    let grant: WireConsentGrantParams
    let payload: Data
    let session: String
    let expires: Double
    var committed: EngineConsentFloor?
    var consumed = false
}
struct CredentialWaiting {
    let request: WireCredentialRequest
    let stamp: EngineConsentFloor
    let session: String
    let expires: Double
    var timer: Task<Void, Never>?
    // Retain the admission stamp until the write finishes, but never admit
    // another agent call or timeout reply after a result has been queued.
    var resultQueued = false
}
struct CredentialWorker {
    let operation: String
    let stamp: EngineConsentFloor
    let session: String
    let task: Task<Void, Never>
    var retired = false
}

extension ProcessEngineClient {
    func registerIntent(_ grant: WireConsentGrantParams, action: EngineUserAction) throws {
        let scopes = (grant.keychain ?? [:]).filter { $0.value.rawValue == "allow" }.map(\.key)
        guard scopes.isEmpty || (scopes.count == 1 && scopes[0] == "claude.account_usage.saved_login" && grant.allow.contains(scopes[0])) else { throw EngineClientError.invalidConfiguration }
        guard let scope = scopes.first else { return }
        let now = runtime.now()
        usedActions = usedActions.filter { $0.value > now }
        interactiveRequestIDs = interactiveRequestIDs.filter { $0.value > now }
        guard usedActions[action.id] == nil, usedActions.count < 256,
              grant.requestId.utf8.count <= 128, interactiveRequestIDs[grant.requestId] == nil, interactiveRequestIDs.count < 256,
              grant.expectGeneration == floor?.generation,
              intents[scope] == nil, grant.expectStoreEpoch == floor?.storeEpoch else { throw EngineClientError.localBusy }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(grant)
        usedActions[action.id] = now + 600
        interactiveRequestIDs[grant.requestId] = now + 600
        intents[scope] = CredentialIntent(action: action, grant: grant, payload: payload, session: sessionID, expires: now + 30)
        let session = sessionID
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            await self?.expireIntent(scope, action: action.id, session: session)
        }
    }
    func expireIntent(_ scope: String, action: UUID, session: String) {
        if intents[scope]?.action.id == action && intents[scope]?.session == session { intents.removeValue(forKey: scope) }
    }
    func retireIntent(requestID: String, unlessCommitted: Bool) {
        for (scope, intent) in intents where intent.grant.requestId == requestID {
            if !unlessCommitted || intent.committed == nil { intents.removeValue(forKey: scope) }
        }
    }
    func matchReceipt(_ grant: WireConsentGrantParams, receipt: WireEnvelope<WireConsentReceipt>, historical: Bool) {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let payload = try? encoder.encode(grant)
        for (scope, var intent) in intents where intent.grant.requestId == receipt.data.requestId {
            guard receipt.data.committed, !historical,
                  receipt.data.committedGeneration == receipt.consentGeneration,
                  intent.session == sessionID, intent.payload == payload,
                  intent.grant.expectStoreEpoch == receipt.storeEpoch,
                  runtime.now() < intent.expires else { intents.removeValue(forKey: scope); continue }
            intent.committed = EngineConsentFloor(storeEpoch: receipt.storeEpoch, generation: receipt.consentGeneration)
            intents[scope] = intent
        }
        attemptCredentials()
    }
    func validateIntentsAgainstFacts(_ facts: WireConsentFacts) {
        for (scope, intent) in intents {
            // Facts captured before this grant are the expected old decision,
            // not a revoke of its not-yet-committed explicit action.
            guard intent.committed != nil || (floor?.generation ?? 0) > intent.grant.expectGeneration else { continue }
            if let fact = facts.scopes.first(where: { $0.scope == scope }),
               fact.state.rawValue != "allowed" || fact.keychain?.rawValue != "allow" {
                intents.removeValue(forKey: scope)
            }
        }
    }
    func retireCredentials(reason: EngineInvalidationReason) {
        for (provider, worker) in credentialWorkers {
            if worker.stamp != floor || reason != .generationAdvanced {
                worker.task.cancel(); credentialWorkers[provider]?.retired = true
            }
        }
        for (provider, waiting) in credentialRequests {
            waiting.timer?.cancel(); credentialRequests.removeValue(forKey: provider)
        }
        for (scope, intent) in intents {
            if reason != .generationAdvanced || (intent.committed != nil && intent.committed != floor) {
                intents.removeValue(forKey: scope)
            }
        }
    }
    func credentialRequested(_ envelope: WireEnvelope<WireCredentialRequest>) {
        let request = envelope.data
        // An operation is single-use for this session. A duplicate must not
        // displace its legitimate pending result with a second error result.
        guard !seenCredentialOperations.contains(request.operationId) else { return }
        guard request.operationId.utf8.count <= 128, seenCredentialOperations.count < 256 else {
            if let process = child { ended(process.id, protocolFault: false, planned: true) }
            return
        }
        seenCredentialOperations.insert(request.operationId)
        guard request.provider == "claude", request.scope == "claude.account_usage.saved_login" else {
            sendCredentialOutcome(request.operationId, outcome: "error"); return
        }
        guard credentialRequests[request.provider] == nil else {
            sendCredentialOutcome(request.operationId, outcome: "error"); return
        }
        guard credentialWorkers[request.provider] == nil else {
            // A logically retired, non-cancelable OS call still owns this slot.
            sendCredentialOutcome(request.operationId, outcome: "timeout"); return
        }
        let stamp = EngineConsentFloor(storeEpoch: envelope.storeEpoch, generation: envelope.consentGeneration)
        var waiting = CredentialWaiting(request: request, stamp: stamp, session: sessionID, expires: runtime.now() + 30)
        waiting.timer = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)); await self?.credentialExpired(request.provider, operation: request.operationId) } catch {}
        }
        credentialRequests[request.provider] = waiting
        if facts?.storeEpoch != stamp.storeEpoch || facts?.consentGeneration != stamp.generation {
            if !pending.values.contains(where: { $0.purpose == .credentialProbe }) {
                _ = try? enqueue("consent/get", params: .object([:]), purpose: .credentialProbe, timeout: runtime.requestTimeout)
            }
        }
        attemptCredentials()
    }
    func credentialExpired(_ provider: String, operation: String) {
        guard let waiting = credentialRequests[provider], waiting.request.operationId == operation else { return }
        credentialRequests.removeValue(forKey: provider)
        if let worker = credentialWorkers[provider], worker.operation == operation {
            worker.task.cancel(); credentialWorkers[provider]?.retired = true
        }
        intents.removeValue(forKey: waiting.request.scope)
        // Expiry still retires queued admission metadata, but cannot append a
        // second reply after the operation has claimed its result.
        if !waiting.resultQueued { sendCredentialOutcome(operation, outcome: "timeout") }
    }
    func attemptCredentials() {
        guard !gateClosed, let context, let floor else { return }
        for (provider, waiting) in credentialRequests {
            guard !waiting.resultQueued, credentialWorkers[provider] == nil else { continue }
            guard waiting.session == sessionID, waiting.stamp == floor, runtime.now() < waiting.expires else {
                credentialRequests.removeValue(forKey: provider); waiting.timer?.cancel(); continue
            }
            guard let credentialAgent else {
                waiting.timer?.cancel(); credentialRequests.removeValue(forKey: provider)
                sendCredentialOutcome(waiting.request.operationId, outcome: "interaction_required"); continue
            }
            guard let facts, facts.storeEpoch == floor.storeEpoch, facts.consentGeneration == floor.generation else { continue }
            guard let fact = facts.data.scopes.first(where: { $0.scope == waiting.request.scope }),
                  fact.state.rawValue == "allowed", fact.keychain?.rawValue == "allow" else {
                waiting.timer?.cancel(); credentialRequests.removeValue(forKey: provider)
                sendCredentialOutcome(waiting.request.operationId, outcome: "denied"); continue
            }
            var action: EngineUserAction?
            if waiting.request.interactive {
                guard var intent = intents[waiting.request.scope], intent.session == sessionID,
                      runtime.now() < intent.expires, !intent.consumed else {
                    waiting.timer?.cancel(); credentialRequests.removeValue(forKey: provider)
                    sendCredentialOutcome(waiting.request.operationId, outcome: "interaction_required"); continue
                }
                // A valid operation can arrive before its grant receipt. Keep
                // one bounded request, with no OS interaction until exact match.
                guard let committed = intent.committed else { continue }
                guard committed == waiting.stamp else {
                    intents.removeValue(forKey: waiting.request.scope)
                    waiting.timer?.cancel(); credentialRequests.removeValue(forKey: provider)
                    sendCredentialOutcome(waiting.request.operationId, outcome: "interaction_required"); continue
                }
                intent.consumed = true; intents[waiting.request.scope] = intent
                action = intent.action
            }
            let operation = EngineCredentialOperation(request: waiting.request, delivery: context,
                deadline: ContinuousClock.now.advanced(by: .seconds(max(0, waiting.expires - runtime.now()))), userAction: action)
            let task = Task { [weak self] in
                let result = await credentialAgent.handle(operation)
                await self?.credentialCompleted(provider, operation: operation, result: result)
            }
            credentialWorkers[provider] = CredentialWorker(operation: waiting.request.operationId,
                stamp: waiting.stamp, session: sessionID, task: task)
        }
    }
    func credentialIsCurrent(_ operation: String) -> Bool {
        credentialRequests.values.contains { $0.request.operationId == operation && $0.session == sessionID && $0.stamp == floor && runtime.now() < $0.expires }
    }
    func credentialCompleted(_ provider: String, operation: EngineCredentialOperation, result: WireCredentialResult) {
        guard let worker = credentialWorkers[provider], worker.operation == operation.request.operationId else { return }
        credentialWorkers.removeValue(forKey: provider)
        guard !worker.retired, credentialIsCurrent(worker.operation), !gateClosed else { return }
        // Actor-atomic transition before enqueueing: facts/clear acknowledgements
        // may retry admission before nextWrite/writeCompleted runs. The worker
        // has ended, but this operation already owns its sole result.
        credentialRequests[provider]?.resultQueued = true
        guard result.operationId == worker.operation,
              ["ok", "canceled", "denied", "not_found", "interaction_required", "timeout", "error"].contains(result.outcome.rawValue),
              (result.outcome.rawValue == "ok" ? validCredentialToken(result) : result.accessToken == nil && result.expiresAt == nil) else {
            sendCredentialOutcome(worker.operation, outcome: "error")
            if let waiting = credentialRequests.removeValue(forKey: provider) { waiting.timer?.cancel() }
            return
        }
        do {
            let key = try enqueue("credentials/result", params: wireJSON(result), purpose: .credentialResult, timeout: runtime.requestTimeout)
            pending[key]?.credentialOperation = worker.operation
            // Revalidate before the writer begins this frame, not just at callback.
            if let index = controlWrites.firstIndex(where: { $0.key == key }) {
                controlWrites[index] = ClientWrite(data: controlWrites[index].data, key: key, credentialOperation: worker.operation)
            }
        } catch { sendCredentialOutcome(worker.operation, outcome: "error") }
        intents.removeValue(forKey: operation.request.scope)
        // Keep matching metadata until writer admission, but never retain result.
    }
    func validCredentialToken(_ result: WireCredentialResult) -> Bool {
        guard let token = result.accessToken, !token.isEmpty, token.utf8.count <= 64 << 10 else { return false }
        guard let expires = result.expiresAt else { return true }
        let plain = ISO8601DateFormatter(); plain.formatOptions = [.withInternetDateTime]
        let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = plain.date(from: expires.rawValue) ?? fractional.date(from: expires.rawValue) else { return false }
        return date > Date()
    }
    func sendCredentialOutcome(_ operation: String, outcome: String) {
        guard child != nil else { return }
        do {
            let value = try WireCredentialResult(operationId: operation, outcome: WireCredentialOutcome(rawValue: outcome))
            _ = try enqueue("credentials/result", params: wireJSON(value), purpose: .credentialResult, timeout: runtime.requestTimeout)
        } catch { if let process = child { ended(process.id, protocolFault: false) } }
    }
}
