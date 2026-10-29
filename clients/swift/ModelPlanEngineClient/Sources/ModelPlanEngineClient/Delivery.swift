// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

extension ProcessEngineClient {
    func emit(_ event: EngineClientEvent, bytes: Int = 256, revision expected: UInt64? = nil,
              request key: String? = nil, error: EngineClientError? = nil, data: Bool = false, clear: UInt64? = nil,
              ready: Bool = false, receipt: Bool = false, epoch: String? = nil) {
        var item = ClientDelivery(event: event, bytes: bytes, revision: expected, epoch: epoch, requestKey: key)
        item.completionError = error
        item.isData = data; item.clearRevision = clear; item.ready = ready; item.receiptMetadata = receipt
        if data {
            if case .rowsChanged = event {
                deliveries.removeAll { if case .rowsChanged = $0.event { return true }; return false }
            }
            if deliveries.count >= 64 || deliveries.reduce(0, { $0 + $1.bytes }) + bytes > 32 << 20 {
                if let process = child { ended(process.id, protocolFault: true) }
                return
            }
            deliveries.append(item)
        } else {
            if controls.count >= 256 || controls.reduce(0, { $0 + $1.bytes }) + bytes > 4 << 20 {
                consumerStalled(); return
            }
            if clear != nil { controls.insert(item, at: 0) }
            else if case .context = event { controls.insert(item, at: 0) }
            else if ready { controls.insert(item, at: min(1, controls.count)) }
            else { controls.append(item) }
        }
        pumpDelivery()
    }
    func pumpDelivery() {
        guard delivering == nil else { return }
        while !controls.isEmpty || (!gateClosed && !deliveries.isEmpty) {
            let controlIndex = controls.firstIndex { !$0.receiptMetadata || !gateClosed }
            var item: ClientDelivery
            if let controlIndex { item = controls.remove(at: controlIndex) }
            else if !gateClosed && !deliveries.isEmpty { item = deliveries.removeFirst() }
            else { return }
            if item.receiptMetadata, case .response(let id, .grant(let grant)) = item.event, let current = context,
               item.epoch == current.floor.storeEpoch {
                item.event = .response(requestID: id, .grant(EngineGrantResult(receipt: grant.receipt,
                    committedAt: grant.committedAt, delivery: current,
                    supersededByLaterConsent: grant.committedAt.map { $0.generation < current.floor.generation } ?? grant.supersededByLaterConsent)))
            }
            if let expected = item.revision, expected != revision, !item.receiptMetadata {
                if let key = item.requestKey { finishRequest(key, error: .staleValue) }
                continue
            }
            if item.isData && gateClosed { deliveries.insert(item, at: 0); return }
            if item.receiptMetadata, let epoch = item.epoch, epoch != floor?.storeEpoch {
                if let key = item.requestKey { finishRequest(key, error: .supersededEpoch(requestID: pending[key]?.grant?.requestId)) }
                continue
            }
            if let key = item.requestKey, pending[key] == nil, !item.receiptMetadata { continue }
            delivering = item
            let consumer = self.consumer
            deliveryTask = Task { [weak self] in
                await consumer.consume(item.event)
                await self?.deliveryAcknowledged(item.id)
            }
            deliveryTimer = Task { [weak self, timeout = runtime.consumerTimeout] in
                do { try await Task.sleep(for: timeout); await self?.consumerStalled(id: item.id) } catch {}
            }
            return
        }
    }
    func deliveryAcknowledged(_ id: UUID) {
        guard let item = delivering, item.id == id else { return }
        deliveryTimer?.cancel(); deliveryTimer = nil; deliveryTask = nil
        if let clear = item.clearRevision, clear == revision {
            if consumerBlocked { consumerBlocked = false }
            if epochProbe == nil, !epochUncertain, handshaken, let current = context, authoritative(current.floor.storeEpoch) {
                clearWaiting = nil; gateClosed = false
                emit(.context(current), revision: revision)
                emit(.connection(.ready(current)), revision: revision, ready: true)
                attemptCredentials()
            }
        }
        if item.revision == revision {
            let delivered: UInt64?
            switch item.event {
            case .rowsChanged(let reply, _): delivered = reply.envelope.data.sequence
            case .response(_, .rows(let reply, _)): delivered = reply.envelope.data.sequence
            default: delivered = nil
            }
            if let delivered {
                deliveredSequence = delivered; deliveredRowRevision = revision
                for (key, waiting) in pending {
                    if let threshold = waiting.waitsForSequence, threshold <= delivered { finishRequest(key) }
                }
            }
        }
        if let key = item.requestKey { finishRequest(key, error: item.completionError) }
        if item.ready, let current = context, item.revision == revision, !gateClosed {
            let waiters = starts; starts.removeAll()
            for waiter in waiters.values { waiter.resume(returning: current) }
            bootstrap()
        }
        delivering = nil
        pumpDelivery()
    }
    func consumerStalled(id: UUID? = nil) {
        if let id, delivering?.id != id { return }
        guard !consumerBlocked else { return }
        consumerBlocked = true; stopped = true; requiresRetry = true
        deliveryTask?.cancel(); deliveryTimer?.cancel()
        // The outstanding consume may be non-cooperative. Do not create another
        // concurrent callback. A sticky clear follows it when it eventually returns.
        failRequests(.interrupted(.cancelled)); failStarts(.interrupted(.cancelled))
        controls.removeAll(); deliveries.removeAll()
        if let process = child { ended(process.id, protocolFault: true) }
        else { invalidate(.protocolFault, next: floor) }
        emit(.connection(.stopped(.consumerUnavailable)))
    }
    func invalidate(_ reason: EngineInvalidationReason, next: EngineConsentFloor?) {
        let previous = context
        if revision == UInt64.max { stopped = true; failRequests(.protocolViolation); return }
        revision += 1; gateClosed = true; clearWaiting = revision
        if let next { floor = next }
        facts = nil
        for (key, waiting) in pending where waiting.waitsForSequence != nil { finishRequest(key, error: .staleValue) }
        retireCredentials(reason: reason)
        let obsolete = deliveries
        deliveries.removeAll()
        for item in obsolete { if let key = item.requestKey { finishRequest(key, error: .staleValue) } }
        emit(.clearPrivateViews(EngineInvalidation(revision: revision, reason: reason,
            previous: previous, nextFloor: next)), clear: revision)
    }
    func authoritative(_ epoch: String) -> Bool { !epoch.isEmpty && epoch != "unavailable" && epoch != "legacy" }
    func adopt(_ stamp: EngineConsentFloor) -> Bool {
        guard authoritative(stamp.storeEpoch), !retiredEpochs.contains(stamp.storeEpoch) else { return false }
        if let old = floor {
            if old.storeEpoch == stamp.storeEpoch {
                guard stamp.generation >= old.generation else { return false }
            } else { retiredEpochs.insert(old.storeEpoch) }
        }
        epochUncertain = false
        if floor != stamp || gateClosed {
            let changedEpoch = floor?.storeEpoch != stamp.storeEpoch
            invalidate(changedEpoch ? .epochChanged : .generationAdvanced, next: stamp)
        }
        return true
    }
    /// Header observation precedes id/sequence de-duplication and data decoding.
    func observe(_ stamp: EngineConsentFloor) -> Bool {
        guard authoritative(stamp.storeEpoch) else {
            epochUncertain = true
            if !gateClosed { invalidate(.epochChanged, next: nil) }
            return false
        }
        if retiredEpochs.contains(stamp.storeEpoch) { return false }
        guard let old = floor else { beginEpochProbe(); return false }
        if old.storeEpoch != stamp.storeEpoch {
            beginEpochProbe()
            return false
        }
        guard epochProbe == nil, !epochUncertain, stamp.generation >= old.generation else { return false }
        if stamp.generation > old.generation { invalidate(.generationAdvanced, next: stamp) }
        return true
    }
    func beginEpochProbe() {
        guard epochProbe == nil, child != nil, handshaken else { return }
        epochUncertain = true
        invalidate(.epochChanged, next: nil)
        // Invalidates old private waiters without replaying any of them. Grants
        // are reconciled separately; their old-epoch outcome is not new success.
        for (key, entry) in pending where entry.purpose == .request {
            finishRequest(key, error: .supersededEpoch(requestID: entry.grant?.requestId))
        }
        if retiredEpochs.count >= 16 {
            // A fresh pipe cannot contain queued frames from retired epochs.
            // This controlled reconnect uses the same clear/unknown-outcome rules.
            if let process = child { ended(process.id, protocolFault: false, planned: true) }
            return
        }
        do { epochProbe = try enqueue("consent/get", params: .object([:]), purpose: .epochProbe, timeout: runtime.requestTimeout) }
        catch { emit(.featureFailure(.consent, .staleValue)) }
    }
    func bootstrap() {
        guard handshaken, !gateClosed, child != nil else { return }
        // Internal subscriptions have no Task-returned private values either.
        if !pending.values.contains(where: { $0.method == "consent/get" }) {
            _ = try? enqueue("consent/get", params: .object([:]), purpose: .bootstrap, timeout: runtime.requestTimeout)
        }
        if sequence == nil && !pending.values.contains(where: { $0.method == "rows/subscribe" }) {
            _ = try? enqueue("rows/subscribe", params: .object([:]), purpose: .bootstrap, timeout: runtime.requestTimeout)
        }
    }

    func receive(_ id: UUID, bytes: Data) {
        guard child?.id == id else { return }
        do {
            switch try IncomingFrame(bytes) {
            case .success(let rpcID, let envelope):
                guard envelope.sessionId == sessionID else { return }
                let key = requestKey(rpcID)
                if let entry = pending[key], entry.purpose == .initialize {
                    if case .object(let fields) = envelope.data, case .string(let version) = fields["protocolVersion"],
                       version.split(separator: ".").first != WireProtocol.version.split(separator: ".").first {
                        protocolMismatch(); return
                    }
                    let result = try decodeEnvelope(envelope, as: WireInitializeResult.self).value
                    capabilities = Set(result.data.capabilities); handshaken = true
                    finishRequest(key)
                    if !adopt(EngineConsentFloor(storeEpoch: envelope.storeEpoch, generation: envelope.consentGeneration)) {
                        epochUncertain = true; invalidate(.epochChanged, next: nil)
                        failStarts(.notReady); emit(.featureFailure(.consent, .notReady))
                    }
                    return
                }
                if let entry = pending[key], entry.purpose == .epochProbe, epochProbe == key {
                    let result = try decodeEnvelope(envelope, as: WireConsentFacts.self).value
                    epochProbe = nil; finishRequest(key)
                    if adopt(EngineConsentFloor(storeEpoch: result.storeEpoch, generation: result.consentGeneration)) {
                        facts = result
                    } else { emit(.featureFailure(.consent, .staleValue)) }
                    return
                }
                let stamp = EngineConsentFloor(storeEpoch: envelope.storeEpoch, generation: envelope.consentGeneration)
                // Same-epoch historical receipts are validated metadata, not a
                // projection. They are the sole below-floor result exception.
                if let entry = pending[key], let grant = entry.grant, floor?.storeEpoch != stamp.storeEpoch {
                    _ = observe(stamp)
                    finishRequest(key, error: .supersededEpoch(requestID: grant.requestId))
                    return
                }
                let historical = pending[key]?.method == "consent/grant" && floor?.storeEpoch == stamp.storeEpoch && stamp.generation < (floor?.generation ?? 0)
                if !observe(stamp) && !historical {
                    if pending[key] != nil { finishRequest(key, error: .staleValue) }
                    return
                }
                guard let entry = pending[key], let current = context else { return }
                if entry.purpose == .credentialResult {
                    if let operation = entry.credentialOperation {
                        for (provider, waiting) in credentialRequests where waiting.request.operationId == operation { waiting.timer?.cancel(); credentialRequests.removeValue(forKey: provider) }
                    }
                    finishRequest(key); return
                }
                if entry.purpose == .credentialProbe {
                    facts = try decodeEnvelope(envelope, as: WireConsentFacts.self).value
                    finishRequest(key); attemptCredentials(); return
                }
                try response(entry, key: key, envelope: envelope, context: current, bytes: bytes.count)
            case .failure(let failure):
                guard failure.error.data.sessionId == sessionID else { return }
                let key = failure.id.map(requestKey)
                if failure.error.code == -32010, let key, pending[key]?.purpose == .initialize { protocolMismatch(); return }
                if let epoch = failure.error.data.storeEpoch, let generation = failure.error.data.consentGeneration {
                    _ = observe(EngineConsentFloor(storeEpoch: epoch, generation: generation))
                }
                if let key, let entry = pending[key] {
                    if entry.purpose == .epochProbe { epochProbe = nil; emit(.featureFailure(.consent, .rpc(code: failure.error.code, context: failure.error.data))) }
                    let error = EngineClientError.rpc(code: failure.error.code, context: failure.error.data)
                    if entry.purpose == .request, gateClosed {
                        emit(.featureFailure(entry.method == "history/query" ? .history : .consent, error), revision: revision, request: key, error: error)
                    } else { finishRequest(key, error: error) }
                }
            case .notification(let method, let envelope):
                guard envelope.sessionId == sessionID else { return }
                guard observe(EngineConsentFloor(storeEpoch: envelope.storeEpoch, generation: envelope.consentGeneration)), let current = context else { return }
                switch method {
                case "rows/changed":
                    let result = try decodeEnvelope(envelope, as: WireRowsSnapshot.self)
                    guard acceptSequence(result.value.data.sequence) else { return }
                    emit(.rowsChanged(EngineReply(envelope: result.value, delivery: current), invalidRowCount: result.invalidRowCount), bytes: bytes.count, revision: revision, data: true)
                case "consent/changed":
                    let result = try decodeEnvelope(envelope, as: WireConsentFacts.self).value
                    facts = result; validateIntentsAgainstFacts(result.data)
                    emit(.consentChanged(EngineReply(envelope: result, delivery: current)), bytes: bytes.count, revision: revision)
                    attemptCredentials()
                case "engine/health":
                    let result = try decodeEnvelope(envelope, as: WireHealth.self).value
                    emit(.health(EngineReply(envelope: result, delivery: current)), bytes: bytes.count, revision: revision)
                case "credentials/request":
                    let result = try decodeEnvelope(envelope, as: WireCredentialRequest.self).value
                    credentialRequested(result)
                default: break // Minor-version notification; header fencing still ran.
                }
            }
        } catch {
            if let error = error as? EngineClientError, case .featureDecode = error { return }
            ended(id, protocolFault: true)
        }
    }
    func acceptSequence(_ next: UInt64) -> Bool {
        if let sequence, next <= sequence { return false }
        sequence = next; return true
    }
    func response(_ entry: ClientPending, key: String, envelope: WireEnvelope<WireJSONValue>, context: EngineDeliveryContext, bytes: Int) throws {
        let feature: EngineFeature
        switch entry.method {
        case "rows/subscribe": feature = .rows
        case "consent/get", "consent/grant": feature = .consent
        case "history/query": feature = .history
        case "refresh/request": feature = .rows
        default: feature = .diagnostics
        }
        do {
            let result: EngineResponse
            var rowCount = 0
            var metadata = false
            switch entry.method {
            case "rows/subscribe":
                let decoded = try decodeEnvelope(envelope, as: WireRowsSnapshot.self)
                guard acceptSequence(decoded.value.data.sequence) else {
                    if deliveredRowRevision == revision, let deliveredSequence, deliveredSequence >= decoded.value.data.sequence { finishRequest(key) }
                    else { pending[key]?.waitsForSequence = decoded.value.data.sequence }
                    return
                }
                rowCount = decoded.invalidRowCount
                result = .rows(EngineReply(envelope: decoded.value, delivery: context), invalidRowCount: rowCount)
            case "consent/get":
                let decoded = try decodeEnvelope(envelope, as: WireConsentFacts.self).value
                facts = decoded; validateIntentsAgainstFacts(decoded.data); attemptCredentials()
                result = .consent(EngineReply(envelope: decoded, delivery: context))
            case "consent/grant":
                let decoded = try decodeEnvelope(envelope, as: WireConsentReceipt.self).value
                guard let grant = entry.grant, decoded.data.requestId == grant.requestId,
                      !decoded.data.committed || decoded.data.committedGeneration == decoded.consentGeneration else { throw EngineClientError.protocolViolation }
                let committed = decoded.data.committed ? EngineConsentFloor(storeEpoch: decoded.storeEpoch, generation: decoded.data.committedGeneration!) : nil
                let historic = decoded.consentGeneration < context.floor.generation
                metadata = true; pending[key]?.receiptKnown = true; pending[key]?.committedAt = committed
                matchReceipt(grant, receipt: decoded, historical: historic)
                result = .grant(EngineGrantResult(receipt: decoded.data, committedAt: committed, delivery: context, supersededByLaterConsent: historic))
            case "refresh/request": result = .refresh(EngineReply(envelope: try decodeEnvelope(envelope, as: [WireRefreshScheduled].self).value, delivery: context))
            case "history/query": result = .history(EngineReply(envelope: try decodeEnvelope(envelope, as: WireHistoryPage.self).value, delivery: context))
            case "diagnostics/get": result = .diagnostics(EngineReply(envelope: try decodeEnvelope(envelope, as: WireDiagnostics.self).value, delivery: context))
            default: throw EngineClientError.protocolViolation
            }
            emit(.response(requestID: entry.id, result), bytes: bytes, revision: revision, request: key,
                 data: entry.method == "rows/subscribe" || entry.method == "history/query", receipt: metadata, epoch: envelope.storeEpoch)
        } catch {
            if let grant = entry.grant, !entry.receiptKnown {
                finishRequest(key, error: .mutationOutcomeUnknown(requestID: grant.requestId, expected: EngineConsentFloor(storeEpoch: grant.expectStoreEpoch, generation: grant.expectGeneration)))
            } else { finishRequest(key, error: .featureDecode(feature)) }
            emit(.featureFailure(feature, .featureDecode(feature)))
            // Valid envelope / bad method data is isolated to this feature.
        }
    }
}
