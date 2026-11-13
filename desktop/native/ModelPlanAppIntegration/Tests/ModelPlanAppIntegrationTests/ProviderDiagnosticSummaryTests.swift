// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanAppIntegration

final class ProviderDiagnosticSummaryTests: XCTestCase {
    func testOnlyProblemsAppearAndEachProviderHasOneLine() {
        let facts: [ProviderDiagnosticFact] = [
            .init(providerID: "a", name: "Codex", condition: .normal),
            .init(providerID: "b", name: "Other", condition: .loading),
            .init(providerID: "a", name: "Codex", condition: .stale),
            .init(providerID: "a", name: "Codex", condition: .failed),
            .init(providerID: "a", name: "Codex", condition: .permission),
        ]
        XCTAssertTrue(ProviderDiagnosticSummary.lines(Array(facts.prefix(2)), english: true).isEmpty)
        XCTAssertEqual(ProviderDiagnosticSummary.lines(facts, english: true), ["Codex: Permission needed · Details…"])
        XCTAssertEqual(ProviderDiagnosticSummary.lines(facts, english: false), ["Codex：需要读取权限 · 查看…"])
        XCTAssertEqual(ProviderDiagnosticSummary.lines([facts[2]], english: true), ["Codex: Reading stale · Details…"])
        XCTAssertEqual(ProviderDiagnosticSummary.lines([facts[3]], english: false), ["Codex：读取失败 · 查看…"])
    }
}
