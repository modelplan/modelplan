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
