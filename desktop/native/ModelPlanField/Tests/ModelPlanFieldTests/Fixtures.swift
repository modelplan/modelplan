// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
@testable import ModelPlanField

func fixture(_ revision: String = "public-r1", theme: FieldTheme = .night, profile: FieldProfile = .tall) throws -> FieldConfiguration {
    let object: [String: Any] = [
        "schemaVersion": 1, "publicationId": revision,
        "units": ["ability":"websiteAbility", "cost":"usdPerReferenceTask", "time":"taskTimeCrossModel"],
        "models": [["id":"public-model", "name":"Public model", "recommended":"high",
                    "efforts":[["effort":"high", "ability":42, "cost":0.5]],
                    "basis":["private-test-sentinel":"must not cross"]]],
        "lineups": [], "personal-test-sentinel":"must not cross",
    ]
    let publication = try JSONDecoder().decode(PublicPublication.self, from: JSONSerialization.data(withJSONObject: object))
    return FieldConfiguration(appearance: .init(theme: theme, locale: .english),
        viewport: try .init(width: 800, height: 500, scale: 2, profile: profile),
        projection: try .init(publication: publication))
}
func message(_ type: FieldEventKind, _ generation: UUID, request: UUID? = nil, key: FieldCaptureKey? = nil,
             interaction: FieldInteraction? = nil) -> FieldWebMessage {
    FieldWebMessage(version: 1, generation: generation, type: type, requestId: request, captureKey: key, interaction: interaction, code: nil)
}
func commands(_ effects: [FieldEffect]) -> [FieldCommand] {
    effects.compactMap { if case .send(let c) = $0 { return c }; return nil }
}
let testClock = ContinuousClock.now
func at(_ seconds: Double) -> ContinuousClock.Instant { testClock.advanced(by: .seconds(seconds)) }
func startLive(_ state: inout FieldLifecycle, consumeCapture: Bool = true) -> (UUID, FieldCaptureKey) {
    _ = state.enlarge(now: at(0))
    let generation = state.generation!
    let initial = commands(state.receive(message(.ready, generation), now: at(1)))[0]
    let capture = commands(state.receive(message(.settled, generation, request: initial.requestId), now: at(2)))[0].captureKey!
    if consumeCapture {
        _ = state.receive(message(.captureResult, generation, request: capture.requestId, key: capture), now: at(3))
        _ = state.acceptCapture(capture, now: at(3))
    }
    return (generation, capture)
}
