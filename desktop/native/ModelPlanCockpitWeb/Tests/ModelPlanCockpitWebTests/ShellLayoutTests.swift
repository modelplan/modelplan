// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

final class ShellLayoutTests: XCTestCase {
    func fit(_ height: CGFloat, closed: Bool = false, width: CGFloat = 1400) throws -> CockpitShellLayout {
        try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 100, y: 50, width: width, height: height),
            anchor: .init(x: 800, y: height + 50, width: 20, height: 22), shutterClosed: closed))
    }
    func testDiscreteProfilesAndExactRoots() throws {
        XCTAssertEqual(try fit(1000).rootHeight, 877)
        XCTAssertEqual(try fit(1000, closed: true).rootHeight, 691)
        XCTAssertEqual(try fit(680).rootHeight, 627)
        XCTAssertEqual(try fit(680, closed: true).rootHeight, 609)
        XCTAssertEqual(try fit(917).profile, .full)
        // D51: the full cockpit scales down to 75 %; below that the short version shows.
        XCTAssertEqual(try fit(916).profile, .full)
        XCTAssertEqual(try fit(690).profile, .full)
        XCTAssertEqual(try fit(689).profile, .compact)
    }
    func testNativeShellTierAndForcedClosedBoundary() throws {
        let forced = try fit(666).shellState(attached: true)
        XCTAssertEqual(forced.profile, .closed); XCTAssertEqual(forced.tier, .compact)
        XCTAssertTrue(forced.forcedClosed)
        let fitting = try fit(667).shellState(attached: true)
        XCTAssertEqual(fitting.profile, .open); XCTAssertEqual(fitting.tier, .compact)
        XCTAssertFalse(fitting.forcedClosed)
        XCTAssertEqual(try fit(917).shellState(attached: false).tier, .tall)
    }
    func placed(width: CGFloat, height: CGFloat, bar: CGFloat, macDock: CGFloat = 0, closed: Bool = false, size: CockpitSize = .standard) throws -> CockpitShellLayout {
        try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 0, y: macDock, width: width, height: height - bar - macDock),
            anchor: .init(x: width - 200, y: height - bar, width: 28, height: bar), shutterClosed: closed, size: size))
    }
    /// G3-39: the menu bar is excluded from `usable` once, and a step is taken when its root really fits.
    func testG3_39ProfileFollowsTheRealFitOnLaptopScreens() throws {
        // 13-inch Air without a notch at its default size: 876 pt usable, the full canvas needs 911 + 6. D51: scaled full.
        XCTAssertEqual(try placed(width: 1440, height: 900, bar: 24).profile, .full)
        // The same Air at "More Space".
        XCTAssertEqual(try placed(width: 1680, height: 1050, bar: 24).profile, .full)
        // 13-inch notched Air: 919 pt usable fits unless the macOS Dock takes the bottom edge.
        let notched = try placed(width: 1470, height: 956, bar: 37, size: .percent100)
        XCTAssertEqual(notched.profile, .full); XCTAssertEqual(notched.scale, 1)
        XCTAssertEqual(notched.frame.height, 911); XCTAssertEqual(notched.frame.minY, 2)
        XCTAssertEqual(try placed(width: 1470, height: 956, bar: 37, macDock: 70).profile, .full)
    }
    /// CKP-SHELL-07 / owner D51, D60: every MacBook Air shows the full cockpit with its base flames at the default
    /// 85 %, or smaller when the room below the menu bar icon is too short. The macOS Dock at the bottom is about
    /// 70 pt at its default size. Each case also states what 100 % would fit to.
    func testD51EveryAirShowsTheFullCockpitWithItsFlames() throws {
        let cases: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            // width, height, menu bar, Dock, default scale, largest fit = (usable - 6) / (877 root + 34 flame reserve)
            (1440, 900, 24, 0, 0.85, 870 / 911), (1440, 900, 24, 70, 0.85, 800 / 911),
            (1470, 956, 37, 0, 0.85, 1), (1470, 956, 37, 70, 0.85, 843 / 911),
            // The largest Dock (128 pt tiles, about 140 pt) on the smallest Air is still full, below 85 %.
            (1440, 900, 24, 140, 730 / 911, 730 / 911),
        ]
        for (width, height, bar, dock, expected, largest) in cases {
            XCTAssertEqual(try placed(width: width, height: height, bar: bar, macDock: dock, size: .percent100).scale, largest, accuracy: 1e-9)
            let value = try placed(width: width, height: height, bar: bar, macDock: dock)
            let label = "\(Int(width))x\(Int(height)), Dock \(Int(dock))"
            XCTAssertEqual(value.profile, .full, label); XCTAssertEqual(value.rootHeight, 877, label)
            XCTAssertEqual(value.scale, expected, accuracy: 1e-9, label)
            XCTAssertGreaterThanOrEqual(value.scale, CockpitShellLayout.minimumFullScale, label)
            // The window holds the root and the flame reserve, uniformly scaled, 6 pt below the icon and above the Dock.
            XCTAssertEqual(value.frame.width, 636 * value.scale, accuracy: 1e-9, label)
            XCTAssertEqual(value.frame.height, 911 * value.scale, accuracy: 1e-9, label)
            XCTAssertEqual(value.frame.maxY, height - bar - 6, accuracy: 1e-9, label)
            XCTAssertGreaterThanOrEqual(value.frame.minY, dock - 1e-9, label)
            XCTAssertEqual(value.pageSize, CGSize(width: 636, height: 911), label)
        }
    }
    /// D51: closing the shutter keeps the open root's scale, so the strip and canopy never jump in size.
    func testD51ShutterKeepsTheScale() throws {
        let open = try placed(width: 1470, height: 956, bar: 37, macDock: 70)
        let closed = try placed(width: 1470, height: 956, bar: 37, macDock: 70, closed: true)
        XCTAssertEqual(closed.profile, .full); XCTAssertEqual(closed.rootHeight, 691)
        XCTAssertEqual(closed.scale, open.scale); XCTAssertEqual(closed.frame.width, open.frame.width)
        XCTAssertEqual(closed.frame.maxY, open.frame.maxY)
        XCTAssertEqual(closed.frame.height, (691 + 34) * open.scale, accuracy: 1e-9)
    }
    /// D51: below 75 % the short version shows, at the chosen size when it fits (D60: 85 % by default).
    func testD51ShortVersionOnlyBelowTheReadableScale() throws {
        let floor = try fit(689)
        XCTAssertEqual(floor.profile, .compact); XCTAssertEqual(floor.rootHeight, 627); XCTAssertEqual(floor.scale, 0.85)
        let lowest = try fit(690)
        XCTAssertEqual(lowest.profile, .full); XCTAssertEqual(lowest.scale, 684 / 911, accuracy: 1e-9)
    }
    /// D51/D60 Settings "Cockpit size" 80 / 85 (default) / 90 / 100 %: drawn at that size when it fits, otherwise
    /// smaller to fit the screen.
    func testD60SizesFitOrShrinkToTheScreen() throws {
        XCTAssertEqual(CockpitSize.standard, .automatic)
        for size in CockpitSize.allCases {
            let value = try placed(width: 1680, height: 1050, bar: 24, size: size)
            XCTAssertEqual(value.scale, size.scale(screenWidth: 1680)); XCTAssertFalse(value.sizeFellBack); XCTAssertEqual(value.profile, .full)
            XCTAssertEqual(value.frame.maxY, 1050 - 24 - 6)
        }
        // 1440x900 with the Dock at the bottom: 80 % and 85 % fit (729 and 774 of 800 pt), 90 % and 100 % draw at 87.8 %.
        for size in [CockpitSize.percent80, .percent85] {
            let value = try placed(width: 1440, height: 900, bar: 24, macDock: 70, size: size)
            XCTAssertEqual(value.scale, size.scale(screenWidth: 1440)); XCTAssertFalse(value.sizeFellBack)
        }
        for size in [CockpitSize.percent90, .percent100] {
            let value = try placed(width: 1440, height: 900, bar: 24, macDock: 70, size: size)
            XCTAssertTrue(value.sizeFellBack); XCTAssertEqual(value.scale, 800 / 911, accuracy: 1e-9); XCTAssertEqual(value.profile, .full)
        }
    }
    /// D60 + #713 review: placement uses the final scale (the 85 % default, not only the fit-to-screen scale),
    /// so the window is the 85 % width where it is anchored and its right-edge clamp uses that width.
    func testD60PlacementUsesTheFinalScaledWidth() throws {
        let value = try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 0, y: 0, width: 1680, height: 1026),
            anchor: .init(x: 800, y: 1026, width: 28, height: 24), shutterClosed: false, size: .percent85))
        XCTAssertEqual(value.scale, 0.85)
        XCTAssertEqual(value.frame.width, 636 * 0.85, accuracy: 1e-9)
        XCTAssertEqual(value.frame.midX, 814, accuracy: 1e-9, "anchored on the icon at the scaled width")
        let edge = try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 0, y: 0, width: 1680, height: 1026),
            anchor: .init(x: 1670, y: 1026, width: 28, height: 24), shutterClosed: false, size: .percent85))
        XCTAssertEqual(edge.frame.maxX, 1680, accuracy: 1e-9, "the right-edge clamp uses the scaled width")
        XCTAssertEqual(edge.frame.width, 636 * 0.85, accuracy: 1e-9)
    }
    /// D66: Auto (the default) is 85 % on screens up to 1512 pt wide (13-14 inch laptops) and 100 % on wider ones,
    /// judged on the full width of the icon's screen; it is re-judged when the cockpit opens on another screen.
    func testD66AutoFollowsTheScreenWidth() throws {
        XCTAssertEqual(CockpitSize.automaticLaptopScreenWidth, 1512)
        // width, height, menu bar, expected Auto scale (every case has room for 100 %, so only the width decides).
        for (width, height, bar, expected) in [(1440, 1050, 24, 0.85), (1470, 1050, 37, 0.85), (1512, 1050, 37, 0.85),
                                               (1728, 1117, 37, 1.0), (2560, 1440, 25, 1.0), (1920, 1080, 25, 1.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            let value = try placed(width: width, height: height, bar: bar)
            XCTAssertEqual(value.scale, expected, "\(Int(width)) pt wide"); XCTAssertEqual(value.profile, .full)
        }
        // Real Air screens: Auto 85 %, still shrinking to fit when the Dock is at the bottom on the 13-inch.
        XCTAssertEqual(try placed(width: 1470, height: 956, bar: 37, macDock: 70).scale, 0.85)
        XCTAssertEqual(try placed(width: 1440, height: 900, bar: 24, macDock: 140).scale, 730 / 911, accuracy: 1e-9)
        // The screen's full width decides, not the width left by a side Dock.
        let side = try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 80, y: 0, width: 1648, height: 1093), anchor: .init(x: 1200, y: 1093, width: 28, height: 24),
                                                        shutterClosed: false, screenWidth: 1728))
        XCTAssertEqual(side.scale, 1)
        let air = try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 70, y: 0, width: 1400, height: 919), anchor: .init(x: 1000, y: 919, width: 28, height: 24),
                                                       shutterClosed: false, screenWidth: 1470))
        XCTAssertEqual(air.scale, 0.85)
        // Switching screens: the same Auto choice gives 85 % on the Air and 100 % on an external display.
        let onAir = try placed(width: 1470, height: 956, bar: 37), onExternal = try placed(width: 2560, height: 1440, bar: 25)
        XCTAssertEqual(onAir.frame.width, 636 * 0.85, accuracy: 1e-9); XCTAssertEqual(onExternal.frame.width, 636, accuracy: 1e-9)
        // Manual choices stay fixed across screens.
        XCTAssertEqual(try placed(width: 2560, height: 1440, bar: 25, size: .percent85).scale, 0.85)
        XCTAssertEqual(try placed(width: 1470, height: 1050, bar: 37, size: .percent100).scale, 1)
    }
    /// D51: the drag region scales with the page so it stays on the strip at every size.
    func testD51DragRegionScalesWithThePage() throws {
        let value = try placed(width: 1440, height: 900, bar: 24, macDock: 70)
        XCTAssertEqual(value.scaledTitleDragFrame.minY, value.titleDragFrame.minY * value.scale, accuracy: 1e-9)
        XCTAssertEqual(value.scaledTitleDragFrame.width, 216 * value.scale, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(value.scaledTitleDragFrame.maxY, value.frame.height)
    }
    /// G3-43 / CKP-SHELL-04: the drag region sits on the strip, not on the canopy, in every shape.
    func testG3_43TitleDragFrameFollowsTheStrip() throws {
        for (height, closed, stripTop) in [(1000, false, 225), (1000, true, 45), (680, false, 57), (680, true, 45)] as [(CGFloat, Bool, CGFloat)] {
            let value = try fit(height, closed: closed), canvas = value.rootHeight + 34
            XCTAssertEqual(canvas - value.titleDragFrame.maxY, stripTop - 3, "top of the strip keys")
            XCTAssertEqual(value.titleDragFrame.height, 32)
            XCTAssertLessThan(value.titleDragFrame.maxX, 243, "the shutter keeps its input")
        }
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
        let value = try fit(680)
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
