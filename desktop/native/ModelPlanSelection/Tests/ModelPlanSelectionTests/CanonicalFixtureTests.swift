// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSelection

private struct FixturePublication: Decodable {
    struct Model: Decodable { let id: String; let developerId: String?; let lineageId: String?; let lineageStatus: String?; let defaultSelected: Bool? }
    struct Lineup: Decodable {
        struct Member: Decodable { let id: String; let tags: [String]? }
        let members: [Member]?
    }
    let publicationId: String
    let selectionRevision: String?
    let models: [Model]
    let lineups: [Lineup]
    var input: SelectionPublication {
        .init(publicationID: publicationId, selectionRevision: selectionRevision,
              models: models.map { .init(id: $0.id, developerID: $0.developerId, lineageID: $0.lineageId,
                                        lineageStatus: $0.lineageStatus, defaultSelected: $0.defaultSelected) },
              picks: lineups.flatMap { ($0.members ?? []).flatMap { member in
                  (member.tags ?? []).compactMap { PublishedPickKind(rawValue: $0).map { PublishedPick(modelID: member.id, kind: $0) } }
              } })
    }
}
final class CanonicalFixtureTests: XCTestCase {
    private func load(_ name: String) throws -> SelectionPublication {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = folder.appendingPathComponent("../../../../../testdata/contract-v1/" + name).standardizedFileURL
        return try JSONDecoder().decode(FixturePublication.self, from: Data(contentsOf: url)).input
    }
    private func select(_ publication: SelectionPublication, usage: [SelectionUsage] = [], scope: SelectionScope = .all) -> SharedModelSelection {
        ModelSelection.select(.init(scope: scope, publication: publication,
            subscriptions: [.init(id: "s", availability: .available, offeredModelIDs: Set(publication.models.map(\.id)))],
            usage: usage, now: referenceTime))
    }
    func testCanonicalPresentFlagsAreConsumedVerbatimIncludingRecentOlderException() throws {
        let publication = try load("F06-lineage-present-publication.json")
        XCTAssertEqual(select(publication).orderedIDs, ["synthetic-z"])
        let result = select(publication, usage: [use("synthetic-one", age: 1), use("synthetic-preview", age: 1), use("synthetic-retired", age: 1)])
        XCTAssertEqual(result.orderedIDs, ["synthetic-one", "synthetic-z"])
        XCTAssertTrue(result.models[0].isOlder)
        XCTAssertEqual(result.models[0].model.defaultSelected, false)
        let single = select(publication, usage: [use("synthetic-one", age: 1)], scope: .subscription("s"))
        XCTAssertEqual(single.orderedIDs, result.orderedIDs)
        XCTAssertTrue(single.models[0].isOlder)
    }
    func testCanonicalAbsentAndPartialFlagsRemainUnknownWithoutInferringFromScoresNamesOrPicks() throws {
        for name in ["F06-lineage-absent-publication.json", "F06-lineage-partial-publication.json"] {
            let publication = try load(name)
            let result = select(publication, usage: [use("synthetic-z", age: 1)])
            XCTAssertTrue(result.orderedIDs.isEmpty)
            XCTAssertTrue(result.issues.contains { $0.reason == .unknownLineageStatus })
            XCTAssertFalse(result.issues.contains { $0.reason == .retired })
        }
        let partial = try load("F06-lineage-partial-publication.json")
        let partialResult = select(partial)
        XCTAssertTrue(partialResult.issues.contains { $0.modelID == "synthetic-z" && $0.reason == .notGlobalDefault })
        XCTAssertFalse(partialResult.issues.contains { $0.modelID == "synthetic-z" && $0.reason == .unknownGlobalDefault })
        XCTAssertEqual(partial.models[0].defaultSelected, false)
        XCTAssertNil(partial.models[1].defaultSelected)
    }
    func testMissingAndNullAreBothUnknownButFalseStaysKnown() throws {
        let source = "{\"publicationId\":\"p\",\"models\":[{\"id\":\"absent\"},{\"id\":\"null\",\"lineageId\":null,\"lineageStatus\":null,\"defaultSelected\":null},{\"id\":\"false\",\"defaultSelected\":false}],\"lineups\":[]}"
        let publication = try JSONDecoder().decode(FixturePublication.self, from: Data(source.utf8)).input
        XCTAssertNil(publication.models[0].defaultSelected)
        XCTAssertNil(publication.models[1].defaultSelected)
        XCTAssertEqual(publication.models[2].defaultSelected, false)
        XCTAssertNil(publication.models[0].lineageStatus)
        XCTAssertNil(publication.models[1].lineageStatus)
    }
}
