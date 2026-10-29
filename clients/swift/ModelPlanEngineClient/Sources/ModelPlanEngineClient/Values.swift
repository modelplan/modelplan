// SPDX-License-Identifier: MIT
// Interface only: data construction and protocol requirements; no transport implementation.
import Foundation
import ModelPlanWire

/// Epochs have equality only. Generation ordering is valid within an equal epoch.
/// Deliberately does not conform to Comparable.
public struct EngineConsentFloor: Sendable, Equatable {
    public let storeEpoch: String
    public let generation: UInt64

    public init(storeEpoch: String, generation: UInt64) {
        self.storeEpoch = storeEpoch
        self.generation = generation
    }
}

/// A package-issued delivery revision, invalidated by floor changes and disconnects.
public struct EngineDeliveryContext: Sendable, Equatable {
    public let sessionID: String
    public let floor: EngineConsentFloor
    public let revision: UInt64

    public init(sessionID: String, floor: EngineConsentFloor, revision: UInt64) {
        self.sessionID = sessionID
        self.floor = floor
        self.revision = revision
    }
}

/// A generated wire value admitted by the client; delivered only through the consumer.
public struct EngineReply<Value: Codable & Sendable>: Sendable {
    public let envelope: WireEnvelope<Value>
    public let delivery: EngineDeliveryContext

    public init(envelope: WireEnvelope<Value>, delivery: EngineDeliveryContext) {
        self.envelope = envelope
        self.delivery = delivery
    }
}

/// Transaction metadata. A historical receipt never replaces current consent facts.
public struct EngineGrantResult: Sendable {
    public let receipt: WireConsentReceipt
    public let committedAt: EngineConsentFloor?
    public let delivery: EngineDeliveryContext
    public let supersededByLaterConsent: Bool

    public init(receipt: WireConsentReceipt, committedAt: EngineConsentFloor?, delivery: EngineDeliveryContext, supersededByLaterConsent: Bool) {
        self.receipt = receipt
        self.committedAt = committedAt
        self.delivery = delivery
        self.supersededByLaterConsent = supersededByLaterConsent
    }
}

/// The consumer clears all private state before acknowledging this event.
public struct EngineInvalidation: Sendable {
    public let revision: UInt64
    public let reason: EngineInvalidationReason
    public let previous: EngineDeliveryContext?
    public let nextFloor: EngineConsentFloor?

    public init(revision: UInt64, reason: EngineInvalidationReason, previous: EngineDeliveryContext?, nextFloor: EngineConsentFloor?) {
        self.revision = revision
        self.reason = reason
        self.previous = previous
        self.nextFloor = nextFloor
    }
}

/// Acknowledges an already-consumed response; contains no private response value.
public struct EngineRequestCompletion: Sendable, Equatable {
    public let requestID: WireRequestID

    public init(requestID: WireRequestID) {
        self.requestID = requestID
    }
}

/// An ephemeral assertion from the Settings consumer, not a consent authorization.
public struct EngineUserAction: Sendable, Equatable {
    public let id: UUID

    public init(id: UUID) {
        self.id = id
    }
}

/// An operation bound to one session, scope, floor and logical deadline.
public struct EngineCredentialOperation: Sendable {
    public let request: WireCredentialRequest
    public let delivery: EngineDeliveryContext
    public let deadline: ContinuousClock.Instant
    public let userAction: EngineUserAction?

    public init(request: WireCredentialRequest, delivery: EngineDeliveryContext, deadline: ContinuousClock.Instant, userAction: EngineUserAction?) {
        self.request = request
        self.delivery = delivery
        self.deadline = deadline
        self.userAction = userAction
    }
}

/// Launch inputs only. Stage 2 validates the environment allow-list and executable.
/// Environment values must never be logged or contain handed-off credential tokens.
public struct EngineClientConfiguration: Sendable {
    public let executableURL: URL
    public let applicationVersion: String
    public let allowedEnvironment: [String: String]
    public let offline: Bool
    public let readOnly: Bool

    public init(executableURL: URL, applicationVersion: String, allowedEnvironment: [String: String], offline: Bool = false, readOnly: Bool = false) {
        self.executableURL = executableURL
        self.applicationVersion = applicationVersion
        self.allowedEnvironment = allowedEnvironment
        self.offline = offline
        self.readOnly = readOnly
    }
}
