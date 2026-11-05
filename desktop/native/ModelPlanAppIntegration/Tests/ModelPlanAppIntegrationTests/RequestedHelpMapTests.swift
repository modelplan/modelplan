// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanInstruments
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class RequestedHelpMapTests: XCTestCase {
    private func input() -> HelpUIRenderInput {
        .init(sessionID: UUID(), viewport: CGSize(width: 600, height: 600), profile: .compact640,
              language: .english, anchors: [.init(id: "a", rect: CGRect(x: 10, y: 10, width: 20, height: 20)),
                                            .init(id: "b", rect: CGRect(x: 40, y: 10, width: 20, height: 20))])
    }
    private func presentation(_ input: HelpUIRenderInput, anchors: [String]) -> HelpUIPresentation {
        .init(sessionID: input.sessionID, mapHeader: CGRect(x: 0, y: 0, width: 20, height: 20),
              mapLabels: anchors.map { .init(id: $0, text: $0, anchorID: $0,
                                            frame: CGRect(x: 0, y: 0, width: 20, height: 20), leader: []) })
    }
    func testRequestUsesExistingMapAndDismissesOnOptionRelease() throws {
        let input = input(); var modes: [HelpUIMapMode] = []
        let adapter = RequestedHelpMap(apply: { value, _, context, _ in
            modes.append(value.map.mode); XCTAssertFalse(context.reducedMotion)
            return self.presentation(value, anchors: ["a", "b"])
        }, isCurrent: { $0.sessionID == input.sessionID })
        XCTAssertTrue(try adapter.presentHelpMap(input: input, content: [:], context: .init()))
        try adapter.optionReleased()
        XCTAssertEqual(modes, [.latched, .hidden])
    }
    func testIncompleteMapIsWithdrawnAndNeverReportedComplete() throws {
        let input = input(); var modes: [HelpUIMapMode] = []
        let adapter = RequestedHelpMap(apply: { value, _, _, _ in
            modes.append(value.map.mode); return self.presentation(value, anchors: ["a"])
        }, isCurrent: { $0.sessionID == input.sessionID })
        XCTAssertFalse(try adapter.presentHelpMap(input: input, content: [:], context: .init()))
        XCTAssertEqual(modes, [.latched, .hidden])
    }
    func testMapDismissActionsAndStaleSurface() throws {
        let input = input(); var current = true; var modes: [HelpUIMapMode] = []
        let adapter = RequestedHelpMap(apply: { value, _, _, _ in
            modes.append(value.map.mode); return self.presentation(value, anchors: ["a", "b"])
        }, isCurrent: { _ in current })
        XCTAssertTrue(try adapter.presentHelpMap(input: input, content: [:], context: .init()))
        XCTAssertTrue(try adapter.handleHelpAction(.dismissMap(reason: .escape, returnFocusID: nil)))
        XCTAssertFalse(try adapter.handleHelpAction(.dismissMap(reason: .pointer, returnFocusID: nil)))
        XCTAssertTrue(try adapter.presentHelpMap(input: input, content: [:], context: .init()))
        XCTAssertTrue(try adapter.handleHelpAction(.dismissMap(reason: .pointer, returnFocusID: nil)))
        XCTAssertTrue(try adapter.presentHelpMap(input: input, content: [:], context: .init()))
        current = false; try adapter.dismissHelpMap()
        XCTAssertEqual(modes, [.latched, .hidden, .latched, .hidden, .latched])
    }
}
