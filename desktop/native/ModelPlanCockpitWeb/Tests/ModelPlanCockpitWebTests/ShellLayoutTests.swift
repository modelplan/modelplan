// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

final class ShellLayoutTests: XCTestCase {
    func fit(_ height: CGFloat, closed: Bool = false, width: CGFloat = 1400) throws -> CockpitShellLayout {
        try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 100, y: 50, width: width, height: height),
            anchor: .init(x: 800, y: height + 50, width: 20, height: 22), shutterClosed: closed))
    }
    func testDiscreteProfilesAndExactRoots() throws {
        XCTAssertEqual(try fit(1000).rootHeight, 905)
        XCTAssertEqual(try fit(1000, closed: true).rootHeight, 691)
        XCTAssertEqual(try fit(800).rootHeight, 655)
        XCTAssertEqual(try fit(800, closed: true).rootHeight, 609)
        XCTAssertEqual(try fit(984).profile, .full)
        XCTAssertEqual(try fit(983).profile, .compact)
    }
    func testNativeShellTierAndForcedClosedBoundary() throws {
        let forced = try fit(733).shellState(attached: true)
        XCTAssertEqual(forced.profile, .closed); XCTAssertEqual(forced.tier, .compact)
        XCTAssertTrue(forced.forcedClosed)
        let fitting = try fit(734).shellState(attached: true)
        XCTAssertEqual(fitting.profile, .open); XCTAssertEqual(fitting.tier, .compact)
        XCTAssertFalse(fitting.forcedClosed)
        XCTAssertEqual(try fit(984).shellState(attached: false).tier, .tall)
    }
    func testShortAndNarrowDisplaysScaleTheWholeRootIncludingBaseReserve() throws {
        let value = try fit(500, width: 400)
        XCTAssertTrue(value.shutterClosed); XCTAssertTrue(value.forcedClosed)
        XCTAssertEqual(value.rootHeight, 609)
        XCTAssertLessThan(value.scale, 1)
        XCTAssertEqual(value.frame.width / 636, value.frame.height / 643, accuracy: 0.00001)
        XCTAssertGreaterThanOrEqual(value.frame.minY, 50)
        XCTAssertLessThanOrEqual(value.frame.maxX, 500)
        XCTAssertEqual(value.frame.maxY, 544, accuracy: 0.001)
    }
    func testDetachedPositionClampsCompleteSilhouetteOnDisplayChange() throws {
        let value = try fit(800)
        let moved = value.clamping(origin: .init(x: -500, y: 9000), usable: .init(x: 100, y: 50, width: 1400, height: 800))
        XCTAssertEqual(moved.minX, 100)
        XCTAssertEqual(moved.maxY, 850)
        XCTAssertEqual(moved.size, value.frame.size)
    }
    @MainActor func testSessionRemembersAtMostEightArrangementsAcrossPageReplacement() {
        let session = CockpitShellSession(); session.detached = true; session.shutterClosed = true
        for index in 0..<9 { session.remember(.init(x: index, y: index), arrangement: String(index)) }
        XCTAssertNil(session.origin(for: "0")); XCTAssertEqual(session.origin(for: "8"), .init(x: 8, y: 8))
        XCTAssertTrue(session.detached); XCTAssertTrue(session.shutterClosed)
    }
    func testInvalidPlacementCannotAdmitAFrame() {
        let anchor = CGRect(x:700,y:1000,width:20,height:22)
        for usable in [CGRect.zero,CGRect.null,CGRect.infinite] {
            XCTAssertNil(CockpitShellLayout.fit(usable:usable,anchor:anchor,shutterClosed:false),"Invalid usable area: null=\(usable.isNull), infinite=\(usable.isInfinite), empty=\(usable.isEmpty)")
        }
        XCTAssertNil(CockpitShellLayout.fit(usable:.init(x:0,y:0,width:1400,height:1000),anchor:.init(x:CGFloat.nan,y:1000,width:20,height:22),shutterClosed:false))
    }
    func testAttachedAnchorClampsBothEdgesOfAnOffOriginDisplay() throws {
        let usable = CGRect(x:-1440,y:100,width:1440,height:1000)
        let left = try XCTUnwrap(CockpitShellLayout.fit(usable:usable,anchor:.init(x:-3000,y:1100,width:20,height:22),shutterClosed:false))
        let right = try XCTUnwrap(CockpitShellLayout.fit(usable:usable,anchor:.init(x:2000,y:1100,width:20,height:22),shutterClosed:false))
        XCTAssertEqual(left.frame.minX,-1440)
        XCTAssertEqual(right.frame.maxX,0)
        XCTAssertEqual(left.frame.maxY,1094)
        XCTAssertEqual(right.frame.size,left.frame.size)
    }
    /// G3-46 / D53: the shell's left edge sits under the icon's left edge, directly below the menu bar,
    /// and shifts left only as far as the right screen edge needs.
    func testG3_46OpensWithItsLeftEdgeUnderTheIcon() throws {
        let usable = CGRect(x: 0, y: 0, width: 1440, height: 876)
        func placed(_ iconX: CGFloat) throws -> CGRect {
            try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: .init(x: iconX, y: 876, width: 28, height: 24), shutterClosed: false)).frame
        }
        let roomy = try placed(500)
        XCTAssertEqual(roomy.minX + 8, 500, "the shell's left edge is the icon's left edge")
        XCTAssertEqual(roomy.maxY, 870, "directly below the menu bar, 6 pt gap")
        let tight = try placed(1100)
        XCTAssertEqual(tight.maxX, 1440, "near the right edge it shifts left only to stay on screen")
        XCTAssertEqual(tight.minX, 1440 - 636)
        XCTAssertEqual(try placed(804 + 8).minX, 804, "the last icon position that needs no shift")
        let hidden = try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: CockpitShellLayout.hiddenIconAnchor(usable: usable), shutterClosed: false)).frame
        XCTAssertEqual(hidden.maxX, 1440, "a hidden icon opens the cockpit at the top-right")
        XCTAssertEqual(hidden.maxY, 870, "directly below the menu bar")
    }
    @MainActor func testUpdatingOneArrangementDoesNotConsumeExtraMemorySlots() {
        let session = CockpitShellSession()
        for index in 0..<12 { session.remember(.init(x:index,y:index),arrangement:"same") }
        for index in 0..<7 { session.remember(.init(x:index,y:index),arrangement:"other-\(index)") }
        XCTAssertEqual(session.origin(for:"same"),.init(x:11,y:11))
        XCTAssertEqual(session.origin(for:"other-0"),.zero)
    }
    func testPinnedLegacyPageIsRejectedBeforeQueryAuthority() throws {
        let state = CockpitBridgeState(context: try .init(sessionID: UUID(), storeEpoch: "synthetic", generation: 1))
        let load = try state.load(.init(theme: .night, locale: .en, profile: .full, reduceMotion: true), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
        var ack = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(load.utf8)) as? [String: Any])
        ack["shell"] = nil; ack["appearance"] = nil; ack["redBelow"] = nil; ack["type"] = "ready"; ack["sequence"] = "1"
        XCTAssertThrowsError(try state.accept(String(decoding: JSONSerialization.data(withJSONObject: ack), as: UTF8.self), source: .init(mainFrame: true, origin: "modelplan-cockpit://bundle")))
        XCTAssertFalse(state.supportsAppearance)
        XCTAssertNil(state.queryTicket)
        XCTAssertThrowsError(try state.setAppearance(.init(theme: .night, locale: .zhCN, profile: .full)))
    }
    func testAppearanceUpdatePreservesPageContextAndRejectsAfterPrivacyBarrier() throws {
        let state = CockpitBridgeState(context: try .init(sessionID: UUID(), storeEpoch: "synthetic", generation: 1))
        let load = try state.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
        var ack = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(load.utf8)) as? [String: Any])
        let initialAppearance = try XCTUnwrap(ack["appearance"] as? [String: Any])
        XCTAssertEqual(Set(initialAppearance.keys), ["theme", "locale", "reduceMotion", "reduceTransparency", "showProjectNames"], "v2 load appearance excludes shell/profile state")
        ack["shell"] = nil; ack["appearance"] = nil; ack["redBelow"] = nil; ack["type"] = "ready"; ack["sequence"] = "1"; ack["appearanceVersion"] = 2; ack["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"]
        let raw = String(decoding: try JSONSerialization.data(withJSONObject: ack), as: UTF8.self)
        _ = try state.accept(raw, source: .init(mainFrame: true, origin: "modelplan-cockpit://bundle"))
        XCTAssertTrue(state.supportsAppearance)
        let ticket = state.queryTicket
        let update = try state.setAppearance(.init(theme: .night, locale: .zhCN, profile: .compact, reduceMotion: true, shutterClosed: true))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(update.utf8)) as? [String: Any])
        let appearance = object
        XCTAssertEqual(object["type"] as? String, "appearance")
        XCTAssertEqual(appearance["locale"] as? String, "zh-CN")
        XCTAssertEqual(appearance["reduceMotion"] as? Bool, true)
        XCTAssertEqual(appearance["reduceTransparency"] as? Bool, false)
        let shellRaw = try state.setShell(.init(closed: true, attached: false, forcedClosed: true, tier: .compact))
        let shell = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(shellRaw.utf8)) as? [String: Any])
        XCTAssertEqual(shell["profile"] as? String, "closed")
        XCTAssertEqual(shell["attached"] as? Bool, false)
        XCTAssertEqual(shell["forcedClosed"] as? Bool, true)
        XCTAssertEqual(ticket, state.queryTicket)
        _ = try state.clear()
        XCTAssertThrowsError(try state.setAppearance(.init(theme: .night, locale: .en, profile: .full)))
        state.dispose()
        XCTAssertThrowsError(try state.setAppearance(.init(theme: .night, locale: .en, profile: .full)))
    }
}
