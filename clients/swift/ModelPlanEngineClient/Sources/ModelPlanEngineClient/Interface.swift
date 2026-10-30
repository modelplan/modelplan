// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

public enum EngineStopReason: Sendable, Equatable {
    case requested, crashLimit, protocolMismatch, consumerUnavailable, processCleanupFailed
}

public enum EngineConnectionState: Sendable, Equatable {
    case idle, starting
    case ready(EngineDeliveryContext)
    case restarting(attempt: Int, delay: Duration)
    case stopped(EngineStopReason)
}

public enum EngineInvalidationReason: Sendable, Equatable {
    case generationAdvanced, epochChanged, connectionLost, stopped, protocolFault
}

public enum EngineFeature: Sendable, Equatable {
    case rows, consent, history, cockpit, publication, pluginInstall, diagnostics
}

public enum EngineRequestDisposition: Sendable, Equatable {
    case notSent, cancelled, connectionLost, outcomeUnknown, supersededEpoch
}

/// Bounded local/RPC error categories. No raw frames, stderr or credential payloads.
public enum EngineClientError: Error, Sendable {
    case notReady, localBusy, invalidConfiguration, unsupportedCapability
    case deadlineExceeded(EngineRequestDisposition)
    case interrupted(EngineRequestDisposition)
    case mutationOutcomeUnknown(requestID: String, expected: EngineConsentFloor)
    /// A validated commit remains known even if consumer delivery is interrupted.
    case receiptDeliveryInterrupted(requestID: String, committedAt: EngineConsentFloor)
    case supersededEpoch(requestID: String?)
    case staleValue, protocolViolation, protocolMismatch
    case featureDecode(EngineFeature)
    case rpc(code: Int, context: WireErrorContext)
}

/// Response values have a single ordered delivery path, never a second Task-return path.
public enum EngineResponse: Sendable {
    case rows(EngineReply<WireRowsSnapshot>, invalidRowCount: Int)
    case consent(EngineReply<WireConsentFacts>)
    case grant(EngineGrantResult)
    case refresh(EngineReply<[WireRefreshScheduled]>)
    case history(EngineReply<WireHistoryPage>)
    case cockpit(EngineReply<WireCockpitData>)
    case pluginInstall(EngineReply<WirePluginInstallResult>)
    case publication(EngineReply<WirePublicationResult>)
    case diagnostics(EngineReply<WireDiagnostics>)
}

public enum EngineClientEvent: Sendable {
    case connection(EngineConnectionState)
    case clearPrivateViews(EngineInvalidation)
    case context(EngineDeliveryContext)
    case response(requestID: WireRequestID, EngineResponse)
    case rowsChanged(EngineReply<WireRowsSnapshot>, invalidRowCount: Int)
    case consentChanged(EngineReply<WireConsentFacts>)
    case health(EngineReply<WireHealth>)
    case featureFailure(EngineFeature, EngineClientError)
}

/// M0's EngineStore consumes serially, normally on MainActor.
/// Returning acknowledges the event. Clear every private view/cache/cockpit value
/// before returning from clearPrivateViews. consume must not await an RPC whose
/// response requires this same consumer; start follow-up RPCs outside that turn. Do not retain response Tasks as a
/// second private-value publication path. The package owns all protocol gating.
public protocol EngineClientEventConsumer: Sendable {
    func consume(_ event: EngineClientEvent) async
}

/// Protocol only: M0 supplies the Security.framework adapter in U7.
/// Background calls must not prompt. Logical cancellation does not claim to
/// cancel an OS call; the client discards late or mismatched results.
/// Results travel only to the private credentials/result writer, never UI events.
public protocol CredentialAgent: Sendable {
    func handle(_ operation: EngineCredentialOperation) async -> WireCredentialResult
}

/// The single protocol/supervision boundary implemented by ProcessEngineClient.
///
/// The implementation alone owns sessions, sequence, equality-only epochs,
/// generation floors, bounded framing/queues, deadlines and process supervision.
/// It acknowledges clearPrivateViews before delivering higher-stamp responses or
/// completing their requests. Requests return completion only after the ordered
/// consumer acknowledges their response; private values arrive solely as events.
///
/// Every old-child waiter completes exactly once on restart. Sent mutations with
/// no validated receipt report outcomeUnknown, never success. No automatic replay
/// of mutations, plugin operations, credentials or old cursors is implied.
/// Task cancellation sends a bounded $/cancel for the original wire id when sent.
/// nil timeouts select bounded method defaults, not unlimited waits.
public protocol EngineClient: Actor {
    /// A synchronous, thread-safe point-in-time veto for credential callbacks.
    /// True only for the accepted session, epoch, generation and revision after
    /// clear acknowledgement. False during invalidation, stop or restart.
    /// This does not grant scope, reserve validity or cancel an OS operation.
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool
    func start() async throws -> EngineDeliveryContext
    func stop() async
    func retry() async throws -> EngineDeliveryContext
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?,
               timeout: Duration?) async throws -> EngineRequestCompletion
    func refresh(_ request: WireRefreshRequestParams,
                 timeout: Duration?) async throws -> EngineRequestCompletion
    func history(_ query: WireHistoryQueryParams,
                 timeout: Duration?) async throws -> EngineRequestCompletion
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion
    func pluginInstall(_ request: WirePluginInstallParams,
                       timeout: Duration?) async throws -> EngineRequestCompletion
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion
}
