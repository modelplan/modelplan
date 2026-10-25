// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore

struct ContractFailure: Error { let message: String }
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw ContractFailure(message: message) }
}
struct ScenarioIndex: Decodable {
    let contractVersion: Int
    let cases: [Scenario]
    struct Scenario: Decodable { let id: String; let desktop: String; let publication: String; let coverage: String }
}
@main struct ContractV1Checks {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw ContractFailure(message: "Pass the repository's testdata/contract-v1 directory")
        }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let index = try JSONDecoder().decode(ScenarioIndex.self, from: Data(contentsOf: root.appendingPathComponent("cases.json")))
        try require(index.contractVersion == 1 && !index.cases.isEmpty, "unsupported/empty scenario inventory")
        var ids = Set<String>(), decoded = 0
        for entry in index.cases {
            let desktopData = try Data(contentsOf: root.appendingPathComponent(entry.desktop))
            let publicationData = try Data(contentsOf: root.appendingPathComponent(entry.publication))
            let personal = try FeedDecoder.personal(desktopData)
            let publication = try FeedDecoder.publication(publicationData)
            try require(personal.contractVersion == 1 && publication.contractVersion == 1, "missing v1 handshake: \(entry.id)")
            try require(personal.capabilities?["creditsHistory"]?.status == "unavailable", "unknown credit history became supported")
            try require(publication.capabilities?["lineageSelection"]?.status == "unavailable", "unpublished curation became supported")
            try require(publication.resets?.count == 2 && publication.windows?.count == 1, "public reset/window metadata lost")
            try require(publication.multipliers?.count == 1 && publication.multiplierHorizon != nil, "scoped public metadata lost")
            try require(publication.planMetering == .null || publication.planMetering == nil, "fixture invented plan metering")
            if entry.id == "F02" {
                try require(personal.accounts?.first?.windows?.first?.remainingPercent == 0, "known zero lost")
            }
            if entry.id == "F09", let sums = personal.todayTotals?.map(\.sums) {
                let rate = MetricMath.generationRate(sums)
                try require(rate != nil && abs(rate! - 1000.0 / 91.0) < 1e-8, "weighted generation average changed")
            }
            if entry.id == "F01-six-working" {
                var ledger = ExpiryLedger()
                let projection = PersonalProjection.evaluate(personal, now: personal.generatedAt.date, ledger: &ledger)
                try require(personal.subscriptions?.count == 6 && projection.live.filter(\.working).count == 6, "six independent attributed sessions lost")
            }
            if entry.id == "F05" {
                var ledger = ExpiryLedger()
                let projection = PersonalProjection.evaluate(personal, now: personal.generatedAt.date, ledger: &ledger)
                try require(projection.live.allSatisfy { !$0.working }, "ambiguous attribution lit a subscription")
            }
            if entry.id == "F18" {
                try require(personal.publication?.publicationId != publication.publicationId, "mismatch fixture joined incorrectly")
            }
            if entry.id == "F19" {
                try require(personal.hourly?.count == 2, "DST repeated-hour rows collapsed")
            }
            for (data, isPersonal) in [(desktopData, true), (publicationData, false)] {
                var document = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                document["futureAdditiveField"] = ["synthetic": true]
                let additive = try JSONSerialization.data(withJSONObject: document)
                if isPersonal { _ = try FeedDecoder.personal(additive) } else { _ = try FeedDecoder.publication(additive) }
                document.removeValue(forKey: "contractVersion")
                let legacy = try JSONSerialization.data(withJSONObject: document)
                if isPersonal { _ = try FeedDecoder.personal(legacy) } else { _ = try FeedDecoder.publication(legacy) }
                document["contractVersion"] = 2
                let incompatible = try JSONSerialization.data(withJSONObject: document)
                do {
                    if isPersonal { _ = try FeedDecoder.personal(incompatible) } else { _ = try FeedDecoder.publication(incompatible) }
                    throw ContractFailure(message: "accepted incompatible contract version")
                } catch FeedError.unsupportedSchema { }
            }
            ids.insert(String(entry.id.prefix(3)))
            decoded += 2
        }
        try require(ids == Set((1...20).map { String(format: "F%02d", $0) }), "F01-F20 inventory incomplete")
        print("PASS desktop contract v1: \(decoded) Go-produced golden documents decoded, all F01-F20 data scenarios")
        print("PASS additive/legacy compatibility, version rejection, exact values, attribution and published metadata")
        print("UI-only scenarios cover data prerequisites; no physical, visual, geometry or OS-event acceptance claim")
    }
}
