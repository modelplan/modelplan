// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
import ModelPlanEngineClient

private struct GrantIntent: EngineConsentGrantIntent {
    var requestID = "synthetic-user-gesture"
    var allowIDs: [String] = []
    var denyIDs: [String] = []
    var forgetIDs: [String] = []
    var keychainIDs: [String] = []
}

final class ConsentGrantFactoryTests: XCTestCase {
    private func capture() throws -> WireConsentFacts {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures").standardizedFileURL
        return try WireDecoder.decode(WireConsentFacts.self, from: Data(contentsOf: root.appendingPathComponent("WireConsentFacts.json")))
    }
    private func context(_ generation: UInt64 = 7, epoch: String = "z-current", session: String = "synthetic-session", revision: UInt64 = 1) -> EngineDeliveryContext {
        .init(sessionID: session, floor: .init(storeEpoch: epoch, generation: generation), revision: revision)
    }
    private func reply(_ facts: WireConsentFacts, _ context: EngineDeliveryContext) throws -> EngineReply<WireConsentFacts> {
        .init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
                                  consentGeneration: context.floor.generation, data: facts), delivery: context)
    }

    func testCapturedAuthoritativeVersionAndIntentChoicesArePreserved() async throws {
        let facts = try capture(), current = context()
        let accepted = try reply(facts, current)
        try await MainActor.run {
            let factory = EngineConsentGrantFactory { (current, accepted) }
            let scope = try XCTUnwrap(facts.scopes.first?.scope)
            let intents = [
                GrantIntent(allowIDs: [scope], keychainIDs: [scope]),
                GrantIntent(denyIDs: [scope]),
                GrantIntent(forgetIDs: [scope])
            ]
            for intent in intents {
                let params = try factory.make(intent)
                XCTAssertEqual(params.requestId, intent.requestID)
                XCTAssertEqual(params.expectStoreEpoch, current.floor.storeEpoch)
                XCTAssertEqual(params.expectGeneration, current.floor.generation)
                XCTAssertEqual(params.consentTextVersion, facts.consentTextVersion)
                XCTAssertEqual(params.allow, intent.allowIDs)
                XCTAssertEqual(params.deny, intent.denyIDs)
                XCTAssertEqual(params.forget, intent.forgetIDs)
                XCTAssertEqual(Set(params.keychain?.keys.map { $0 } ?? []), Set(intent.keychainIDs))
                XCTAssertTrue(params.keychain?.values.allSatisfy { $0 == .allow } ?? false)
            }
        }
    }

    func testFactoryReadsLiveStateAndRefusesStaleFloorBeforeFreshFacts() async throws {
        let facts = try capture(), initial = context()
        let initialReply = try reply(facts, initial)
        // A synthetic future producer version proves the factory never hard-codes
        // either today's consent text version or the value in the fixture.
        let updatedFacts = try WireConsentFacts(consentTextVersion: facts.consentTextVersion + 17, scopes: facts.scopes)
        let next = context(8, revision: 2), fresh = try reply(updatedFacts, next)
        let reset = context(1, epoch: "a-new", session: "new-session", revision: 3), resetFacts = try reply(updatedFacts, reset)
        try await MainActor.run {
            var current: EngineDeliveryContext? = initial
            var consent: EngineReply<WireConsentFacts>? = initialReply
            let factory = EngineConsentGrantFactory { (current, consent) }
            let intent = GrantIntent(allowIDs: [facts.scopes[0].scope])
            XCTAssertEqual(try factory.make(intent).expectGeneration, 7)
            current = next
            XCTAssertThrowsError(try factory.make(intent)) { XCTAssertEqual($0 as? EngineConsentGrantError, .staleConsentFacts) }
            consent = fresh
            let updated = try factory.make(intent)
            XCTAssertEqual(updated.expectGeneration, 8)
            XCTAssertEqual(updated.consentTextVersion, updatedFacts.consentTextVersion)
            current = reset
            XCTAssertThrowsError(try factory.make(intent)) { XCTAssertEqual($0 as? EngineConsentGrantError, .staleConsentFacts) }
            consent = resetFacts
            XCTAssertEqual(try factory.make(intent).expectStoreEpoch, "a-new")
            XCTAssertEqual(try factory.make(intent).expectGeneration, 1, "epochs have equality only")
            current = nil; consent = nil
            XCTAssertThrowsError(try factory.make(intent)) { XCTAssertEqual($0 as? EngineConsentGrantError, .missingContext) }
            current = reset
            XCTAssertThrowsError(try factory.make(intent)) { XCTAssertEqual($0 as? EngineConsentGrantError, .missingConsentFacts) }
        }
    }

    func testOldSessionRevisionAndEnvelopeAreNotCurrentFacts() async throws {
        let facts = try capture(), current = context()
        let mismatches = [context(6), context(epoch: "another"), context(session: "old-session"), context(revision: 0)]
        let stale = try mismatches.map { try reply(facts, $0) }
        let mismatchedEnvelope = EngineReply(envelope: try reply(facts, context(6)).envelope, delivery: current)
        try await MainActor.run {
            for value in stale + [mismatchedEnvelope] {
                let factory = EngineConsentGrantFactory { (current, value) }
                XCTAssertThrowsError(try factory.make(GrantIntent())) { XCTAssertEqual($0 as? EngineConsentGrantError, .staleConsentFacts) }
            }
        }
    }

    func testMissingAuthorityAndInvalidIntentsThrowTypedErrors() async throws {
        let facts = try capture(), current = context(), accepted = try reply(facts, current)
        let invalidVersion = try reply(WireConsentFacts(consentTextVersion: 0, scopes: facts.scopes), current)
        try await MainActor.run {
            let absent = EngineConsentGrantFactory { (nil, accepted) }
            XCTAssertThrowsError(try absent.make(GrantIntent())) { XCTAssertEqual($0 as? EngineConsentGrantError, .missingContext) }
            let noFacts = EngineConsentGrantFactory { (current, nil) }
            XCTAssertThrowsError(try noFacts.make(GrantIntent())) { XCTAssertEqual($0 as? EngineConsentGrantError, .missingConsentFacts) }
            let invalid = EngineConsentGrantFactory { (current, invalidVersion) }
            XCTAssertThrowsError(try invalid.make(GrantIntent())) { XCTAssertEqual($0 as? EngineConsentGrantError, .invalidConsentTextVersion) }
            let factory = EngineConsentGrantFactory { (current, accepted) }
            for intent in [GrantIntent(requestID: ""), GrantIntent(allowIDs: ["a", "a"]), GrantIntent(allowIDs: ["a"], denyIDs: ["a"]), GrantIntent(keychainIDs: ["a"])] {
                XCTAssertThrowsError(try factory.make(intent)) { XCTAssertEqual($0 as? EngineConsentGrantError, .invalidIntent) }
            }
        }
    }
}
