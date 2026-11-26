// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

final class ShellLayoutTests: XCTestCase {
    func fit(_ height: CGFloat, closed: Bool = false, width: CGFloat = 1400) throws -> CockpitShellLayout {
        try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 100, y: 50, width: width, height: height),
            anchor: .init(x: 800, y: height + 50, width: 20, height: 22), shutterClosed: closed))
    }
    /// D444 (owner, 2026-11-25): one layout. Every room gets the full roots; only the scale changes.
    func testD444OneLayoutAtEveryHeight() throws {
        for height in [1200, 1000, 945, 944, 720, 719, 700, 692, 600, 486, 485, 400] as [CGFloat] {
            for closed in [false, true] {
                let value = try fit(height, closed: closed), label = "\(Int(height)) closed \(closed)"
                XCTAssertEqual(value.profile, .full, label)
                XCTAssertEqual(value.rootHeight, value.shutterClosed ? 691 : 905, label)
                XCTAssertEqual(value.pageSize, CGSize(width: 636, height: 951), label)
                XCTAssertEqual(value.shellState(attached: true).tier, .tall, label)
                XCTAssertEqual(value.shellState(attached: false).tier, .tall, label)
            }
        }
    }
    /// D444: a short display (700 pt usable) keeps the full cockpit under the old 75 % switch; nothing goes compact.
    func testD444ShortDisplayGetsTheFullLayoutBelowTheOldSwitch() throws {
        let value = try fit(700)
        XCTAssertEqual(value.profile, .full); XCTAssertEqual(value.rootHeight, 905)
        XCTAssertLessThan(value.scale, 0.75); XCTAssertEqual(value.scale, 690 / 951, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(value.scale, CockpitShellLayout.minimumScale)
        XCTAssertFalse(value.forcedClosed); XCTAssertFalse(value.shutterClosed)
        let shell = value.shellState(attached: true)
        XCTAssertEqual(shell.profile, .open); XCTAssertEqual(shell.tier, .tall); XCTAssertFalse(shell.forcedClosed)
        assertHoldsThePage(value, "700 pt")
    }
    /// D444: the open cockpit is never under the 0.5 floor. One point shorter, it opens forced closed at the floor.
    func testD444FloorBoundaryForcesTheShutterClosed() throws {
        let open = try fit(486) // 476 pt of room / 951 px
        XCTAssertFalse(open.forcedClosed); XCTAssertEqual(open.scale, 476 / 951, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(open.scale, CockpitShellLayout.minimumScale)
        let forced = try fit(485)
        XCTAssertTrue(forced.forcedClosed); XCTAssertTrue(forced.shutterClosed)
        XCTAssertEqual(forced.scale, CockpitShellLayout.minimumScale); XCTAssertEqual(forced.rootHeight, 691)
        let shell = forced.shellState(attached: true)
        XCTAssertEqual(shell.profile, .closed); XCTAssertEqual(shell.tier, .tall); XCTAssertTrue(shell.forcedClosed)
        assertHoldsThePage(forced, "floor")
    }
    /// D444: a very short display opens closed at the floor scale; the closed window fits the room.
    func testD444VeryShortDisplayOpensClosedAtTheFloor() throws {
        let value = try fit(400)
        XCTAssertTrue(value.forcedClosed); XCTAssertTrue(value.shutterClosed); XCTAssertEqual(value.profile, .full)
        XCTAssertEqual(value.scale, 0.5); XCTAssertEqual(value.canvasHeight, 476)
        XCTAssertEqual(value.frame.height, 476 - 114, "the open canvas minus the porthole band")
        XCTAssertLessThanOrEqual(value.frame.height, 390, "inside the room under the 10 pt gap")
        XCTAssertEqual(value.frame.maxY, 440)
        assertHoldsThePage(value, "very short")
        // A room too short even for the closed window at the floor: the closed cockpit shrinks rather than being cut.
        let tiny = try fit(300)
        XCTAssertTrue(tiny.forcedClosed); XCTAssertLessThan(tiny.scale, 0.5)
        XCTAssertLessThanOrEqual(tiny.frame.height, 290)
        assertNeverClipped(tiny, usable: .init(x: 100, y: 50, width: 1400, height: 300), "300 pt")
    }
    /// macrev2-1257-1 invariant: in any room the cockpit is never clipped. The window holds the whole open canvas, or
    /// closed the whole canvas below the porthole band (the slab included), and fits the room in both directions;
    /// the frame caps in `fit` never bind.
    func assertNeverClipped(_ value: CockpitShellLayout, usable: CGRect, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let band = value.shutterClosed ? CockpitShellLayout.portholeBand(scale: value.scale) : 0
        XCTAssertEqual(value.frame.height, value.canvasHeight - band, "\(label): the window is not cut (slab and body whole)", file: file, line: line)
        XCTAssertLessThanOrEqual(value.portholeHeight, 228 * value.scale + 1e-9, "\(label): only the porthole band is left out, never the slab", file: file, line: line)
        XCTAssertEqual(value.frame.width, CockpitShellLayout.wholePoints(636 * value.scale), "\(label): the width is not cut", file: file, line: line)
        XCTAssertGreaterThanOrEqual(value.frame.minX, usable.minX - 1e-9, "\(label): left edge on screen", file: file, line: line)
        XCTAssertLessThanOrEqual(value.frame.maxX, usable.maxX + 1e-9, "\(label): right edge on screen", file: file, line: line)
        XCTAssertGreaterThanOrEqual(value.frame.minY, usable.minY - 1e-9, "\(label): bottom edge in the room", file: file, line: line)
        XCTAssertLessThanOrEqual(value.frame.maxY, usable.maxY - CockpitShellLayout.menuBarGap + 1e-9, "\(label): top edge under the gap", file: file, line: line)
        XCTAssertGreaterThan(value.scale, 0, label, file: file, line: line)
    }
    /// macrev2-1257-1 (failing first at e2d0930: the 300 pt room cut 0.548 pt of the closed slab): the very short room.
    func testMacrev2_1257_1VeryShortRoomKeepsTheWholeClosedSlab() throws {
        let usable = CGRect(x: 100, y: 50, width: 1400, height: 300)
        let value = try fit(300)
        XCTAssertTrue(value.forcedClosed)
        XCTAssertLessThanOrEqual(value.frame.height, 290)
        XCTAssertLessThanOrEqual(value.portholeHeight, 228 * value.scale)
        XCTAssertEqual(value.frame.height, value.canvasHeight - CockpitShellLayout.portholeBand(scale: value.scale))
        assertNeverClipped(value, usable: usable, "300 pt")
    }
    /// macrev2-1257-1, width-bound (failing first at e2d0930: a fractional width rounded the canvas one point past the
    /// screen and the cap cut it): the room bounded by width, open and forced closed, attached anywhere on the display.
    func testMacrev2_1257_1WidthBoundRoomIsNeverCut() throws {
        for (minX, width) in [(0, 300.5), (0.5, 300), (0.25, 317.75), (0, 250), (10.5, 480.5)] as [(CGFloat, CGFloat)] {
            for height in [1000, 600, 400] as [CGFloat] {
                for closed in [false, true] {
                    for anchorX in [minX, minX + width / 2, minX + width] {
                        let usable = CGRect(x: minX, y: 0, width: width, height: height)
                        let value = try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: .init(x: anchorX, y: height, width: 20, height: 22), shutterClosed: closed))
                        assertNeverClipped(value, usable: usable, "x \(minX) w \(width) h \(height) closed \(closed) icon \(anchorX)")
                    }
                }
            }
        }
    }
    /// macrev2-1257-1: every fit path (open / user-closed / forced closed at the floor / below the floor, bounded by height
    /// or by width, whole and fractional frames, with and without a display basis) keeps the whole cockpit.
    func testMacrev2_1257_1NoFitPathEverClips() throws {
        var heights: [CGFloat] = Array(stride(from: CGFloat(60), through: 1200, by: 1))
        heights += heights.map { $0 + 0.25 }
        for height in heights {
            for (minY, width) in [(0, 1400), (0.5, 1400), (70.5, 318.5)] as [(CGFloat, CGFloat)] {
                for closed in [false, true] {
                    let usable = CGRect(x: 0, y: minY, width: width, height: height)
                    guard let value = CockpitShellLayout.fit(usable: usable, anchor: .init(x: 700, y: usable.maxY, width: 20, height: 22), shutterClosed: closed) else { continue }
                    assertNeverClipped(value, usable: usable, "h \(height) y \(minY) w \(width) closed \(closed)")
                    if value.forcedClosed { XCTAssertTrue(value.shutterClosed) } else { XCTAssertGreaterThanOrEqual(value.scale, CockpitShellLayout.minimumScale - 1e-9) }
                }
            }
        }
        // With a display basis (G3-132): the room is the smallest display's, possibly fractional.
        for small in [300.5, 361.5, 485.25, 700.75] as [CGFloat] {
            let basis = CockpitSizeBasis(visibleHeight: small, visibleWidth: 1280, screenWidth: 1280)
            let usable = CGRect(x: 0, y: 0, width: 2560, height: 1415)
            for closed in [false, true] {
                let value = try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: .init(x: 1300, y: 1415, width: 20, height: 22), shutterClosed: closed, basis: basis))
                assertNeverClipped(value, usable: usable, "basis \(small) closed \(closed)")
                XCTAssertLessThanOrEqual(value.frame.height, (small - CockpitShellLayout.menuBarGap).rounded(.down), "fits the smallest display")
            }
        }
    }
    func placed(width: CGFloat, height: CGFloat, bar: CGFloat, macDock: CGFloat = 0, closed: Bool = false, size: CockpitSize = .standard) throws -> CockpitShellLayout {
        try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 0, y: macDock, width: width, height: height - bar - macDock),
            anchor: .init(x: width - 200, y: height - bar, width: 28, height: bar), shutterClosed: closed, size: size))
    }
    func testPortraitAutoUsesTheFractionalViewportCoveredByTheHullRasterTest() throws {
        let layout = try placed(width: 1440, height: 2560, bar: 24)
        XCTAssertEqual(layout.profile, .full)
        XCTAssertEqual(layout.scale, 0.85)
        XCTAssertEqual(layout.webFrame.size, CGSize(width: 541, height: 809))
    }

    /// The window server places borderless panels on whole points: the layout frame is already whole, so the
    /// real window equals it, and it holds the scaled page with under 1 pt to spare.
    /// G3-108: the web view keeps the open canvas; closed, the window leaves out the porthole band above the slab.
    func assertHoldsThePage(_ value: CockpitShellLayout, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let frame = value.frame
        for edge in [frame.minX, frame.minY, frame.width, frame.height, value.canvasHeight] { XCTAssertEqual(edge, edge.rounded(), "\(label): whole points", file: file, line: line) }
        XCTAssertEqual(value.webFrame, CGRect(x: 0, y: 0, width: frame.width, height: value.canvasHeight), "\(label): on the bottom edge", file: file, line: line)
        let band = value.shutterClosed ? (228 * value.scale).rounded(.down) : 0
        XCTAssertEqual(value.portholeHeight, band, "\(label): the closed window leaves out the porthole band", file: file, line: line)
        for (window, page) in [(frame.width, value.pageSize.width * value.scale), (value.canvasHeight, value.pageSize.height * value.scale)] {
            XCTAssertGreaterThanOrEqual(window, page - 1e-6, "\(label): the page fits", file: file, line: line)
            XCTAssertLessThan(window - page, 1, "\(label): no more than the rounding", file: file, line: line)
        }
    }
    /// CI 11-10: a fractional frame (531.69 pt) came back from the window server as 532 pt; fit() now returns the whole frame.
    func testFramesAreWholePointsAndHoldTheScaledPage() throws {
        for (width, height, bar, dock) in [(1440, 900, 24, 0), (1440, 900, 24, 70), (1470, 956, 37, 70), (1512, 982, 37, 0), (1680, 1050, 24, 0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            for size in CockpitSize.allCases {
                for closed in [false, true] {
                    let value = try placed(width: width, height: height, bar: bar, macDock: dock, closed: closed, size: size)
                    assertHoldsThePage(value, "\(Int(width))x\(Int(height)) Dock \(Int(dock)) \(size.rawValue) closed \(closed)")
                    XCTAssertEqual(value.frame.maxY, height - bar - 10)
                    XCTAssertGreaterThanOrEqual(value.frame.minY, dock)
                }
            }
        }
        // Fractional icon positions still give a whole frame, the left shoulder under the icon to within half a point.
        let odd = try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 0, y: 0, width: 1440, height: 876), anchor: .init(x: 700.3, y: 876, width: 28, height: 24), shutterClosed: false, size: .percent85))
        assertHoldsThePage(odd, "fractional icon"); XCTAssertEqual(odd.shoulder.x, 714.3, accuracy: 0.5)
    }
    /// G3-39: the menu bar is excluded from `usable` once, and a step is taken when its root really fits.
    func testG3_39ProfileFollowsTheRealFitOnLaptopScreens() throws {
        // 13-inch Air without a notch at its default size: 876 pt usable, the full canvas needs 951 + 10. D51: scaled full.
        XCTAssertEqual(try placed(width: 1440, height: 900, bar: 24).profile, .full)
        // The same Air at "More Space".
        XCTAssertEqual(try placed(width: 1680, height: 1050, bar: 24).profile, .full)
        // 13-inch notched Air: 919 pt usable, 909 under the 10 pt gap (CKP-SHELL-33).
        let notched = try placed(width: 1470, height: 956, bar: 37, size: .percent100)
        XCTAssertEqual(notched.profile, .full); XCTAssertEqual(notched.scale, 909 / 951, accuracy: 1e-9)
        XCTAssertEqual(notched.frame.height, 909, accuracy: 1e-9); XCTAssertEqual(notched.frame.minY, 0, accuracy: 1e-9)
        XCTAssertEqual(try placed(width: 1470, height: 956, bar: 37, macDock: 70).profile, .full)
    }
    /// CKP-SHELL-07 / owner D51, D60: every MacBook Air shows the full cockpit with its base flames at the default
    /// 85 %, or smaller when the room below the menu bar icon is too short. The macOS Dock at the bottom is about
    /// 70 pt at its default size. Each case also states what 100 % would fit to.
    func testD51EveryAirShowsTheFullCockpitWithItsFlames() throws {
        let cases: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            // width, height, menu bar, Dock, default scale, largest fit = (usable - 10) / (905 root + 46 flame reserve).
            // CKP-SHELL-33's 10 pt gap leaves the 13-inch Air with the Dock 796 pt, just under 85 % (798).
            (1440, 900, 24, 0, 0.85, 866 / 951), (1440, 900, 24, 70, 796 / 951, 796 / 951),
            (1470, 956, 37, 0, 0.85, 909 / 951), (1470, 956, 37, 70, 0.85, 839 / 951),
            // The largest Dock (128 pt tiles, about 140 pt) on the smallest Air is still full, below 85 %.
            (1440, 900, 24, 140, 726 / 951, 726 / 951),
        ]
        for (width, height, bar, dock, expected, largest) in cases {
            XCTAssertEqual(try placed(width: width, height: height, bar: bar, macDock: dock, size: .percent100).scale, largest, accuracy: 1e-9)
            let value = try placed(width: width, height: height, bar: bar, macDock: dock)
            let label = "\(Int(width))x\(Int(height)), Dock \(Int(dock))"
            XCTAssertEqual(value.profile, .full, label); XCTAssertEqual(value.rootHeight, 905, label)
            XCTAssertEqual(value.scale, expected, accuracy: 1e-9, label)
            XCTAssertGreaterThanOrEqual(value.scale, CockpitShellLayout.minimumScale, label)
            // The window holds the root and the flame reserve, uniformly scaled, on whole points, 10 pt below the bar and above the Dock.
            assertHoldsThePage(value, label)
            XCTAssertEqual(value.frame.maxY, height - bar - 10, accuracy: 1e-9, label)
            XCTAssertGreaterThanOrEqual(value.frame.minY, dock - 1e-9, label)
            XCTAssertEqual(value.pageSize, CGSize(width: 636, height: 951), label)
        }
    }
    /// D51: closing the shutter keeps the open root's scale, so the strip and canopy never jump in size.
    func testD51ShutterKeepsTheScale() throws {
        let open = try placed(width: 1470, height: 956, bar: 37, macDock: 70)
        let closed = try placed(width: 1470, height: 956, bar: 37, macDock: 70, closed: true)
        XCTAssertEqual(closed.profile, .full); XCTAssertEqual(closed.rootHeight, 691)
        XCTAssertEqual(closed.scale, open.scale); XCTAssertEqual(closed.frame.width, open.frame.width)
        XCTAssertEqual(closed.frame.maxY, open.frame.maxY)
        assertHoldsThePage(closed, "closed")
    }
    /// G3-108 (owner, build 14e): the shutter never rescales and never moves the body inside the window. The page
    /// canvas, the web view and the strip's window place (from the bottom edge) are the same open or closed.
    /// Attached (D88 / CKP-SHELL-07: the window hangs 6 pt below the menu bar icon) the top edge stays and the body
    /// rises by the porthole band; the detached placement (bottom edge kept) is the controller's, covered by
    /// CockpitShutterMotionTests.
    func testG3_108ShutterKeepsTheBodyAndTheScale() throws {
        for (width, height, bar, dock) in [(1470, 956, 37, 70), (1440, 900, 24, 0), (1680, 1050, 24, 0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            for size in CockpitSize.allCases {
                let open = try placed(width: width, height: height, bar: bar, macDock: dock, size: size)
                let closed = try placed(width: width, height: height, bar: bar, macDock: dock, closed: true, size: size)
                let label = "\(Int(width))x\(Int(height)) \(size.rawValue)"
                XCTAssertEqual(closed.scale, open.scale, label)
                XCTAssertEqual(closed.pageSize, open.pageSize, label); XCTAssertEqual(closed.webFrame, open.webFrame, label)
                XCTAssertEqual(closed.scaledTitleDragFrame, open.scaledTitleDragFrame, "\(label): the strip keeps its place over the bottom edge")
                XCTAssertEqual(closed.frame.maxY, open.frame.maxY, "\(label): attached, the top edge stays under the icon")
                XCTAssertEqual(closed.frame.minY - open.frame.minY, closed.portholeHeight, "\(label): the body rises by the porthole band")
                XCTAssertEqual(closed.portholeHeight, (228 * open.scale).rounded(.down), label)
                XCTAssertEqual(open.portholeHeight, 0, label)
            }
        }
        // D444: a short display (formerly the short version) keeps the same body behaviour at its smaller scale.
        let shortOpen = try fit(700), shortClosed = try fit(700, closed: true)
        XCTAssertEqual(shortOpen.profile, .full)
        XCTAssertEqual(shortClosed.webFrame, shortOpen.webFrame)
        XCTAssertEqual(shortClosed.portholeHeight, (228 * shortOpen.scale).rounded(.down))
        XCTAssertEqual(shortClosed.scaledTitleDragFrame, shortOpen.scaledTitleDragFrame)
    }
    /// D51/D60 Settings "Cockpit size" 80 / 85 (default) / 90 / 100 %: drawn at that size when it fits, otherwise
    /// smaller to fit the screen.
    func testD60SizesFitOrShrinkToTheScreen() throws {
        XCTAssertEqual(CockpitSize.standard, .automatic)
        for size in CockpitSize.allCases {
            let value = try placed(width: 1680, height: 1050, bar: 24, size: size)
            XCTAssertEqual(value.scale, size.scale(screenWidth: 1680)); XCTAssertFalse(value.sizeFellBack); XCTAssertEqual(value.profile, .full)
            XCTAssertEqual(value.frame.maxY, 1050 - 24 - 10)
        }
        // 1440x900 with the Dock at the bottom: 80 % fits (751 of 796 pt under the 10 pt gap); 85 %, 90 % and 100 % draw at 84.8 %.
        for size in [CockpitSize.percent80] {
            let value = try placed(width: 1440, height: 900, bar: 24, macDock: 70, size: size)
            XCTAssertEqual(value.scale, size.scale(screenWidth: 1440)); XCTAssertFalse(value.sizeFellBack)
        }
        for size in [CockpitSize.percent85, .percent90, .percent100] {
            let value = try placed(width: 1440, height: 900, bar: 24, macDock: 70, size: size)
            XCTAssertTrue(value.sizeFellBack); XCTAssertEqual(value.scale, 796 / 951, accuracy: 1e-9); XCTAssertEqual(value.profile, .full)
        }
    }
    /// D60 + #713 review: placement uses the final scale (the 85 % default, not only the fit-to-screen scale),
    /// so the window is the 85 % width, its left shoulder under the icon (CKP-SHELL-33), and its right-edge clamp uses that width.
    func testD60PlacementUsesTheFinalScaledWidth() throws {
        let value = try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 0, y: 0, width: 1680, height: 1026),
            anchor: .init(x: 800, y: 1026, width: 28, height: 24), shutterClosed: false, size: .percent85))
        XCTAssertEqual(value.scale, 0.85)
        XCTAssertEqual(value.frame.width, 541, "636 x 85 % on whole points")
        XCTAssertEqual(value.shoulder.x, 814, accuracy: 0.5, "CKP-SHELL-33: the scaled shoulder is under the icon (anchor midX 814)")
        let edge = try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 0, y: 0, width: 1680, height: 1026),
            anchor: .init(x: 1670, y: 1026, width: 28, height: 24), shutterClosed: false, size: .percent85))
        XCTAssertEqual(edge.frame.maxX, 1680, accuracy: 1e-9, "the right-edge clamp uses the scaled width")
        XCTAssertEqual(edge.frame.width, 541)
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
        XCTAssertEqual(try placed(width: 1440, height: 900, bar: 24, macDock: 140).scale, 726 / 951, accuracy: 1e-9)
        // The screen's full width decides, not the width left by a side Dock.
        let side = try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 80, y: 0, width: 1648, height: 1093), anchor: .init(x: 1200, y: 1093, width: 28, height: 24),
                                                        shutterClosed: false, screenWidth: 1728))
        XCTAssertEqual(side.scale, 1)
        let air = try XCTUnwrap(CockpitShellLayout.fit(usable: .init(x: 70, y: 0, width: 1400, height: 919), anchor: .init(x: 1000, y: 919, width: 28, height: 24),
                                                       shutterClosed: false, screenWidth: 1470))
        XCTAssertEqual(air.scale, 0.85)
        // Switching screens: the same Auto choice gives 85 % on the Air and 100 % on an external display.
        let onAir = try placed(width: 1470, height: 956, bar: 37), onExternal = try placed(width: 2560, height: 1440, bar: 25)
        XCTAssertEqual(onAir.frame.width, 541); XCTAssertEqual(onExternal.frame.width, 636)
        // Manual choices stay fixed across screens.
        XCTAssertEqual(try placed(width: 2560, height: 1440, bar: 25, size: .percent85).scale, 0.85)
        XCTAssertEqual(try placed(width: 1470, height: 1050, bar: 37, size: .percent100).scale, 1)
    }
    /// D51: the drag region scales with the page so it stays on the strip at every size.
    func testD51DragRegionScalesWithThePage() throws {
        let value = try placed(width: 1440, height: 900, bar: 24, macDock: 70)
        // The page is top-anchored in the whole-point web view, so the region keeps its scaled distance from the top.
        XCTAssertEqual(value.canvasHeight - value.scaledTitleDragFrame.maxY, (value.pageSize.height - value.titleDragFrame.maxY) * value.scale, accuracy: 1e-9)
        XCTAssertEqual(value.scaledTitleDragFrame.width, 190 * value.scale, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(value.scaledTitleDragFrame.maxY, value.frame.height)
    }
    /// G3-43 / CKP-SHELL-04: the drag region sits on the strip, not on the canopy, in every shape.
    func testG3_43TitleDragFrameFollowsTheStrip() throws {
        // G3-108: the closed page keeps the strip at its open place on the open canvas.
        for (height, closed, stripTop) in [(1000, false, 253), (1000, true, 253), (680, false, 253), (680, true, 253), (400, false, 253)] as [(CGFloat, Bool, CGFloat)] {
            let value = try fit(height, closed: closed), canvas = value.pageSize.height
            XCTAssertEqual(canvas - value.titleDragFrame.maxY, stripTop - 3, "top of the strip keys")
            XCTAssertEqual(value.titleDragFrame.height, 32)
            XCTAssertLessThanOrEqual(value.titleDragFrame.maxX, 214, "ALERT keeps its input (WP-10: page x 214)")
        }
    }
    func testShortAndNarrowDisplaysScaleTheWholeRootIncludingBaseReserve() throws {
        let value = try fit(400, width: 400)
        XCTAssertTrue(value.shutterClosed); XCTAssertTrue(value.forcedClosed)
        XCTAssertEqual(value.rootHeight, 691); XCTAssertEqual(value.scale, 0.5)
        XCTAssertEqual(value.frame.width / 636, value.canvasHeight / 951, accuracy: 0.002, "uniform, up to the whole-point rounding")
        XCTAssertLessThanOrEqual(value.frame.height, 390, "the closed window fits the room")
        assertHoldsThePage(value, "short and narrow")
        XCTAssertGreaterThanOrEqual(value.frame.minY, 50)
        XCTAssertLessThanOrEqual(value.frame.maxX, 500)
        XCTAssertEqual(value.frame.maxY, 440, accuracy: 0.001)
        // Narrower than the floor's width (318 pt): the width bounds the scale, the layout stays full.
        let narrow = try fit(900, width: 300)
        XCTAssertEqual(narrow.profile, .full); XCTAssertTrue(narrow.forcedClosed); XCTAssertEqual(narrow.scale, 300 / 636, accuracy: 1e-9)
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
        XCTAssertEqual(left.frame.maxY,1090)
        XCTAssertEqual(right.frame.size,left.frame.size)
    }
    /// CKP-SHELL-33 (D158/D178, supersedes D88's centring): the icon sits above the left canopy shoulder, the cockpit
    /// 10 pt below the menu bar, and it shifts only as far as a screen edge needs.
    func testD88OpensCentredUnderTheIcon() throws {
        let usable = CGRect(x: 0, y: 0, width: 1440, height: 1026)
        func placed(_ iconX: CGFloat) throws -> CGRect {
            try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: .init(x: iconX, y: 1026, width: 28, height: 24), shutterClosed: false, size: .percent100)).frame
        }
        let roomy = try placed(700)
        XCTAssertEqual(roomy.minX + CockpitShellLayout.shoulderX, 714, "the left shoulder is under the icon's centre")
        XCTAssertEqual(roomy.maxY, 1016, "below the menu bar, 10 pt gap")
        let tight = try placed(1300)
        XCTAssertEqual(tight.maxX, 1440, "near the right edge it shifts left only to stay on screen")
        XCTAssertEqual(tight.minX, 1440 - 636)
        XCTAssertEqual(try placed(20).minX, 0, "near the left edge it shifts right only to stay on screen")
        XCTAssertEqual(try placed(864 - 14).minX, 864 - CockpitShellLayout.shoulderX, "the last icon centre that needs no shift")
        XCTAssertEqual(try placed(864 - 14).maxX, 1440)
        let hidden = try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: CockpitShellLayout.hiddenIconAnchor(usable: usable), shutterClosed: false, size: .percent100)).frame
        XCTAssertEqual(hidden.maxX, 1440, "a hidden icon opens the cockpit at the top-right")
        XCTAssertEqual(hidden.maxY, 1016, "10 pt below the menu bar")
    }
    /// D378 (owner, 11-21): a status item that is not visible anchors the attached cockpit just below the notch's RIGHT
    /// edge, the rack's left side on that edge; without a notch, where a notch edge would be (100 pt right of centre).
    @MainActor func testAnInvisibleStatusItemAnchorsAtTheNotchsRightEdgeOrWhereItWouldBe() throws {
        let frame = CGRect(x: 0, y: 0, width: 1512, height: 982), usable = CGRect(x: 0, y: 0, width: 1512, height: 945)
        let notch = CockpitShellLayout.menuBarEdgeAnchor(screen: CockpitScreen(frame: frame, visibleFrame: usable, notchRightEdge: 851))
        XCTAssertEqual(notch, CGRect(x: 851, y: 945, width: CockpitDockingBoom.edgeAnchorWidth, height: 37), "right of the camera housing, the menu bar's height")
        // #1207 round 3: the edge anchor is as wide as the clamp-only boom, so the boom drawn there has that one width with
        // the shutter open or closed and its left side stays on the edge.
        XCTAssertEqual(CockpitDockingBoom.edgeAnchorWidth, 42)
        for closed in [CGFloat(0), 0.5, 1] {
            XCTAssertEqual(CockpitDockingBoom.drawnWidth(widest: notch.width, line: CockpitShellLayout.menuBarGap, closed: closed).rounded(.up), notch.width)
            XCTAssertEqual(CockpitLaunchRack.frame(icon: notch, width: notch.width).minX, 851, "the boom's left side on the edge")
        }
        let plain = CockpitShellLayout.menuBarEdgeAnchor(screen: CockpitScreen(frame: frame, visibleFrame: usable))
        XCTAssertEqual(plain.minX, 756 + 100, "no notch: the nominal notch edge right of the menu bar's centre")
        XCTAssertEqual(plain.minY, usable.maxY)
        let fit = try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: notch, shutterClosed: false, size: .percent100))
        XCTAssertEqual(fit.shoulder.x, notch.midX, accuracy: 0.5, "the left shoulder sits under the rack hanging there")
        XCTAssertGreaterThan(fit.frame.minX, 851 - CockpitShellLayout.shoulderX - 1, "not at the top-right corner (G3-46)")
        // The rack hangs from the anchor: its frame starts at the notch edge, from the menu bar's edge down.
        let rack = CockpitLaunchRack.frame(icon: notch)
        XCTAssertEqual(rack.minX, 851); XCTAssertEqual(rack.maxY, usable.maxY)
    }
    /// Owner question 11-22 (menubar-right-edge-check): a status item at the far right of a 13-inch MacBook Air menu bar
    /// (1470 x 956 pt, 37 pt notched menu bar, 70 pt Dock, Auto = 85 %). NSPopover-style: the rack stays under the icon,
    /// the cockpit slides left only as far as the screen edge needs, and the icon's rack still lands on the hull (the
    /// page's 8 px transparent margin keeps the visible hull inside the screen edge). No detach.
    @MainActor func testAFarRightIconOnA1470PointScreenClampsTheCockpitAndKeepsTheRackAttached() throws {
        let width: CGFloat = 1470, bar: CGFloat = 37, dock: CGFloat = 70
        let usable = CGRect(x: 0, y: dock, width: width, height: 956 - bar - dock)
        let hullMargin: CGFloat = 8 // page px between the 636 px canvas edge and the hull (see `shoulderX`)
        // A realistic rightmost third-party item (left of Control Center and the clock) and the extreme: flush right.
        for iconX in [1300, width - 28] as [CGFloat] {
            for closed in [false, true] {
                let icon = CGRect(x: iconX, y: usable.maxY, width: 28, height: bar)
                let label = "icon at \(iconX), closed \(closed)"
                let fit = try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: closed, screenWidth: width), label)
                XCTAssertEqual(fit.profile, .full, label); XCTAssertEqual(fit.scale, 0.85, label)
                XCTAssertEqual(fit.frame.width, 541, label)
                // Clamped: flush with the screen's right edge, never past it, 10 pt below the menu bar, still attached.
                XCTAssertEqual(fit.frame.maxX, width, "\(label): slides left just enough to stay on screen")
                XCTAssertEqual(fit.frame.minX, width - 541, label)
                XCTAssertGreaterThanOrEqual(fit.frame.minX, usable.minX, label)
                XCTAssertEqual(fit.frame.maxY, usable.maxY - CockpitShellLayout.menuBarGap, "\(label): attached, under the menu bar")
                XCTAssertLessThan(fit.shoulder.x, icon.midX, "\(label): the cockpit slid left of the icon (the shoulder no longer under it)")
                // The rack (the tower) stays centred under the icon, hanging from the menu bar's edge.
                let rack = CockpitLaunchRack.frame(icon: icon)
                XCTAssertEqual(rack.midX, icon.midX, accuracy: 0.5, "\(label): the rack stays under the icon")
                XCTAssertEqual(rack.maxY, usable.maxY, "\(label): the rack hangs from the menu bar")
                // ...and lands on the hull: its centre over the visible hull, its foot below the rack's mask line.
                let hull = (fit.frame.minX + hullMargin * fit.scale)...(fit.frame.maxX - hullMargin * fit.scale)
                XCTAssertTrue(hull.contains(rack.midX), "\(label): the rack centre \(rack.midX) is over the hull \(hull)")
                XCTAssertLessThanOrEqual(rack.minY, fit.frame.maxY - fit.rackMaskDrop, "\(label): the rack reaches the hull line, no gap")
            }
        }
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
        ack["shell"] = nil; ack["appearance"] = nil; ack["redBelow"] = nil; ack["showUsedPercent"] = nil; ack["showAllModels"] = nil; ack["type"] = "ready"; ack["sequence"] = "1"
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
        ack["shell"] = nil; ack["appearance"] = nil; ack["redBelow"] = nil; ack["showUsedPercent"] = nil; ack["showAllModels"] = nil; ack["type"] = "ready"; ack["sequence"] = "1"; ack["appearanceVersion"] = 2; ack["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"]
        let raw = String(decoding: try JSONSerialization.data(withJSONObject: ack), as: UTF8.self)
        _ = try state.accept(raw, source: .init(mainFrame: true, origin: "modelplan-cockpit://bundle"))
        XCTAssertTrue(state.supportsAppearance)
        let ticket = state.queryTicket
        let update = try state.setAppearance(.init(theme: .night, locale: .zhCN, profile: .full, reduceMotion: true, shutterClosed: true))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(update.utf8)) as? [String: Any])
        let appearance = object
        XCTAssertEqual(object["type"] as? String, "appearance")
        XCTAssertEqual(appearance["locale"] as? String, "zh-CN")
        XCTAssertEqual(appearance["reduceMotion"] as? Bool, true)
        XCTAssertEqual(appearance["reduceTransparency"] as? Bool, false)
        let shellRaw = try state.setShell(.init(closed: true, attached: false, forcedClosed: true, tier: .tall))
        let shell = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(shellRaw.utf8)) as? [String: Any])
        XCTAssertEqual(shell["profile"] as? String, "closed")
        XCTAssertEqual(shell["tier"] as? String, "tall", "D444: the wire keeps one tier")
        XCTAssertEqual(shell["attached"] as? Bool, false)
        XCTAssertEqual(shell["forcedClosed"] as? Bool, true)
        XCTAssertEqual(ticket, state.queryTicket)
        _ = try state.clear()
        XCTAssertThrowsError(try state.setAppearance(.init(theme: .night, locale: .en, profile: .full)))
        state.dispose()
        XCTAssertThrowsError(try state.setAppearance(.init(theme: .night, locale: .en, profile: .full)))
    }
}
