// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanAppIntegration

/// Build 6 (owner 11-27, fourth report after #1038, #1196 and #1251). Invariant: the cockpit opens on the display the
/// user acted on; a status-item copy behind the notch is never visible and never anchors it. Pure geometry with a
/// synthetic notch display (the housing between the auxiliary top areas) and an external display, one test per open
/// entry. On main the click-free anchor was `resolve(window:click: nil)`, which returns the notch-covered copy, so each
/// red-button / shortcut / restore case below opened just left of the notch on the built-in display.
final class NotchStatusItemPlacementTests: XCTestCase {
    typealias Display = StatusItemAnchor.Display
    /// A 1512 x 982 MacBook (37 pt menu bar) with the housing at x 656...856, and a 2560 x 1440 display on its right.
    private let laptop = Display(frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                 visibleFrame: CGRect(x: 0, y: 70, width: 1512, height: 875), notchRightEdge: 856)
    private let external = Display(frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
                                   visibleFrame: CGRect(x: 1512, y: 0, width: 2560, height: 1415))
    private var displays: [Display] { [laptop, external] }
    private let menuHeight: CGFloat = 24, width: CGFloat = 32
    /// The copy AppKit hands back on a full built-in menu bar: behind the notch (the owner's G3-22 numbers, scaled).
    private var hiddenCopy: CGRect { CGRect(x: 769, y: 945, width: width, height: 37) }
    private var laptopCopy: CGRect { CGRect(x: 1300, y: 945, width: width, height: 37) }
    private var externalCopy: CGRect { CGRect(x: 3860, y: 1415, width: width, height: 25) }
    /// The external copy projected from the notch-covered slot: same distance from the right edge.
    private var projectedExternal: CGRect { CGRect(x: 4072 - (1512 - hiddenCopy.maxX) - width, y: 1415, width: width, height: 25) }
    private let onLaptop = CGPoint(x: 400, y: 500), onExternal = CGPoint(x: 2500, y: 700)

    private func click(_ rect: CGRect) throws -> StatusItemAnchor {
        try XCTUnwrap(StatusItemAnchor.click(pointer: CGPoint(x: rect.midX, y: rect.midY), local: CGPoint(x: width / 2, y: 12),
                                             buttonBounds: CGRect(x: 0, y: 0, width: width, height: 24), flipped: false, displays: displays))
    }
    /// `drawn` is the button window's; `undrawn` lists other copies AppKit reports as not drawn (occluded).
    private func place(window: CGRect?, drawn: Bool = true, copies: [CGRect] = [], undrawn: [CGRect] = [],
                       click: StatusItemAnchor? = nil, at point: CGPoint? = nil, last: StatusItemAnchor? = nil,
                       itemWidth: CGFloat? = nil, on arrangement: [Display]? = nil) -> StatusItemAnchor.Placement {
        let reported: [StatusItemAnchor.Known] = copies.map { StatusItemAnchor.Known($0) } + undrawn.map { StatusItemAnchor.Known($0, drawn: false) }
        return StatusItemAnchor.placement(window: window.map { StatusItemAnchor.Known($0, drawn: drawn) }, copies: reported,
                                   click: click, actedAt: point, lastClick: last,
                                   itemWidth: itemWidth ?? width, displays: arrangement ?? displays, menuHeight: menuHeight)
    }

    func testACopyInTheNotchHousingOrLeftOfItIsNotVisible() {
        XCTAssertTrue(StatusItemAnchor.underNotch(hiddenCopy, on: laptop))
        XCTAssertTrue(StatusItemAnchor.underNotch(CGRect(x: 500, y: 945, width: width, height: 37), on: laptop), "squeezed left of the housing")
        XCTAssertFalse(StatusItemAnchor.underNotch(laptopCopy, on: laptop))
        XCTAssertFalse(StatusItemAnchor.underNotch(CGRect(x: 857, y: 945, width: width, height: 37), on: laptop), "right of the housing")
        XCTAssertFalse(StatusItemAnchor.underNotch(hiddenCopy, on: Display(frame: laptop.frame, visibleFrame: laptop.visibleFrame)), "no notch")
        // The click-free resolver alone (main's cockpitAnchor) accepts it: that was the bug.
        XCTAssertEqual(StatusItemAnchor.resolve(window: hiddenCopy, click: nil, itemWidth: width, displays: displays, menuHeight: menuHeight), hiddenCopy)
    }

    /// ENTRY red button on the notch display whose copy is behind the notch: the display that shows the item.
    func testRedButtonOnTheNotchDisplayOpensWhereTheItemIsShown() {
        let projected = place(window: hiddenCopy, at: onLaptop)
        XCTAssertEqual(projected.display, external)
        XCTAssertEqual(projected.anchor, projectedExternal)
        // AppKit also lists the external copy's own window: that rect wins over the projection.
        XCTAssertEqual(place(window: hiddenCopy, copies: [externalCopy], at: onLaptop), .init(display: external, anchor: externalCopy))
        // The button window is the external copy and the laptop's own copy is the hidden one.
        XCTAssertEqual(place(window: externalCopy, copies: [hiddenCopy], at: onLaptop), .init(display: external, anchor: externalCopy))
    }

    /// ENTRY red button where the widget's display shows the item: that display, under its own copy.
    func testRedButtonOpensOnTheWidgetsDisplayWhenItShowsTheItem() throws {
        XCTAssertEqual(place(window: laptopCopy, copies: [externalCopy], at: onLaptop), .init(display: laptop, anchor: laptopCopy))
        XCTAssertEqual(place(window: laptopCopy, copies: [externalCopy], at: onExternal), .init(display: external, anchor: externalCopy))
        // Only one window known: the other display's copy is projected (same right-edge offset).
        let projected = try XCTUnwrap(place(window: laptopCopy, at: onExternal).anchor)
        XCTAssertEqual(projected.maxX, 4072 - (1512 - laptopCopy.maxX), accuracy: 0.5)
        XCTAssertEqual(place(window: externalCopy, at: onLaptop).anchor?.maxX ?? 0, 1512 - (4072 - externalCopy.maxX), accuracy: 0.5)
        // A red button on the external display while the last click was on the laptop: still the external.
        XCTAssertEqual(place(window: laptopCopy, copies: [externalCopy], at: onExternal, last: try click(laptopCopy)).display, external)
    }

    /// ENTRY red button on the notch display, hidden copy, and the last status-item click was on the external display.
    func testRedButtonFallsBackToTheLastClickedDisplay() throws {
        let last = try click(externalCopy)
        XCTAssertEqual(place(window: hiddenCopy, at: onLaptop, last: last), .init(display: external, anchor: last.rect))
    }

    /// ENTRY shortcut, status menu item and reopen (no point): the last clicked display, then a display without a notch.
    func testOpensWithoutAPointUseTheLastClickThenADisplayWithoutANotch() throws {
        XCTAssertEqual(place(window: hiddenCopy).display, external, "hidden on the laptop: the external")
        XCTAssertEqual(place(window: laptopCopy, copies: [externalCopy]), .init(display: external, anchor: externalCopy),
                       "both show it, no click yet: the display without a notch")
        XCTAssertEqual(place(window: laptopCopy, copies: [externalCopy], last: try click(laptopCopy)), .init(display: laptop, anchor: laptopCopy),
                       "the last click named the laptop's copy")
        XCTAssertEqual(place(window: hiddenCopy, last: try click(laptopCopy)).display, external,
                       "the laptop's copy has since gone behind the notch: not the last clicked display")
        // A click from another arrangement is forgotten.
        let stale = try XCTUnwrap(StatusItemAnchor.click(pointer: CGPoint(x: laptopCopy.midX, y: laptopCopy.midY), local: CGPoint(x: 16, y: 12),
            buttonBounds: CGRect(x: 0, y: 0, width: width, height: 24), flipped: false, displays: [laptop]))
        XCTAssertEqual(place(window: laptopCopy, copies: [externalCopy], last: stale).display, external)
    }

    /// ENTRY status-item click: the display that holds the press, even when AppKit's window is the notch-covered copy.
    func testStatusClickOpensOnTheClickedDisplay() throws {
        let press = try click(externalCopy)
        XCTAssertEqual(place(window: hiddenCopy, click: press, at: nil), .init(display: external, anchor: press.rect))
        let onLaptop = try click(laptopCopy)
        XCTAssertEqual(place(window: externalCopy, click: onLaptop), .init(display: laptop, anchor: onLaptop.rect))
    }

    /// ENTRY restore / any entry with one notch display only: no visible copy, so no anchor (D378: right of the notch)
    /// on that display, never the hidden copy's rect.
    func testSingleNotchDisplayWithTheItemHiddenHasNoAnchor() {
        XCTAssertEqual(place(window: hiddenCopy, at: onLaptop, on: [laptop]), .init(display: laptop, anchor: nil))
        XCTAssertEqual(place(window: hiddenCopy, on: [laptop]), .init(display: laptop, anchor: nil))
        XCTAssertEqual(place(window: laptopCopy, at: onLaptop, on: [laptop]), .init(display: laptop, anchor: laptopCopy))
        XCTAssertEqual(place(window: CGRect(x: 0, y: -22, width: width, height: 44), on: [laptop]), .init(display: nil, anchor: nil), "parked: no anchor")
    }

    /// statusItemHidden: a drawn window behind the notch is not visible; another display without a window of its own
    /// shows the item through its projected copy.
    @MainActor func testCopyVisibilitiesTreatTheNotchAsHidden() {
        func states(_ windows: [(CGRect, Bool)], _ arrangement: [Display]) -> [Bool] {
            StatusItemAnchor.copyVisibilities(windows: windows.map { (frame: $0.0, drawn: $0.1) }, itemWidth: width,
                                              displays: arrangement, menuHeight: menuHeight)
        }
        XCTAssertEqual(states([(hiddenCopy, true)], [laptop]), [false], "drawn, but behind the notch")
        XCTAssertEqual(states([(hiddenCopy, false)], [laptop]), [false])
        XCTAssertEqual(states([(laptopCopy, true)], [laptop]), [true])
        XCTAssertEqual(states([(hiddenCopy, true)], displays), [false, true], "the external display shows it")
        XCTAssertEqual(states([(hiddenCopy, false)], displays), [false, true], "occluded by the notch only")
        XCTAssertEqual(states([(hiddenCopy, true), (externalCopy, true)], displays), [false, true])
        XCTAssertEqual(states([(externalCopy, false)], displays), [false], "an occluded copy elsewhere says nothing about the others")
        XCTAssertNil(EngineDockMenuApplication.anyWindowVisible([]))
        XCTAssertEqual(EngineDockMenuApplication.anyWindowVisible(states([(hiddenCopy, true)], [laptop])), false)
    }

    /// macrevc-1283-1: AppKit reports both copies undrawn (the built-in one behind the notch, the external one occluded).
    /// No copy is visible, so there is no anchor and D378 runs on the display acted on; the external display's own
    /// window is never replaced by a projection, and a last click proves nothing about now.
    func testEveryCopyUndrawnFallsBackToD378OnTheActedOnDisplay() throws {
        for drawn in [false, true] {
            XCTAssertEqual(place(window: hiddenCopy, drawn: drawn, undrawn: [externalCopy], at: onLaptop), .init(display: laptop, anchor: nil), "drawn \(drawn)")
            XCTAssertEqual(place(window: hiddenCopy, drawn: drawn, undrawn: [externalCopy], at: onLaptop, last: try click(externalCopy)),
                           .init(display: laptop, anchor: nil))
            XCTAssertEqual(place(window: hiddenCopy, drawn: drawn, undrawn: [externalCopy], at: onExternal), .init(display: external, anchor: nil))
            XCTAssertEqual(place(window: hiddenCopy, drawn: drawn, undrawn: [externalCopy]).anchor, nil, "shortcut")
        }
        // The button window itself occluded on the external display, nothing else known: no anchor.
        XCTAssertEqual(place(window: externalCopy, drawn: false, at: onExternal), .init(display: external, anchor: nil))
        XCTAssertEqual(place(window: externalCopy, drawn: false, at: onLaptop), .init(display: laptop, anchor: nil))
        XCTAssertEqual(place(window: externalCopy, drawn: false, last: try click(externalCopy)).anchor, nil)
        // statusItemHidden sees the same: no visible copy.
        let states = StatusItemAnchor.copyVisibilities(windows: [(frame: hiddenCopy, drawn: true), (frame: externalCopy, drawn: false)],
                                                       itemWidth: width, displays: displays, menuHeight: menuHeight)
        XCTAssertFalse(states.contains(true))
    }

    /// macrevc-1283-2: the press was on the visible laptop copy, then a width change moved that copy behind the notch
    /// before the cockpit was placed, while the external display still shows the item. The clicked display is kept,
    /// with no anchor (D378), never the moved rect.
    func testAClickedCopyThatMovedBehindTheNotchIsNotAnAnchor() throws {
        let press = try click(laptopCopy)
        let wider = CGRect(x: hiddenCopy.minX - 40, y: 945, width: width + 40, height: 37)
        XCTAssertEqual(place(window: wider, copies: [externalCopy], click: press, itemWidth: width + 40), .init(display: laptop, anchor: nil))
        XCTAssertEqual(place(window: externalCopy, copies: [wider], click: press, itemWidth: width + 40), .init(display: laptop, anchor: nil),
                       "the moved copy is one of the other windows")
        XCTAssertEqual(place(window: hiddenCopy, copies: [externalCopy], click: press), .init(display: laptop, anchor: nil), "same width, moved")
        // The clicked copy's window occluded at the press position.
        XCTAssertEqual(place(window: laptopCopy, drawn: false, copies: [externalCopy], click: press), .init(display: laptop, anchor: nil))
        // Still visible after the width change: anchored as before.
        let grown = CGRect(x: laptopCopy.maxX - width - 40, y: 945, width: width + 40, height: 37)
        XCTAssertEqual(place(window: grown, copies: [externalCopy], click: press, itemWidth: width + 40), .init(display: laptop, anchor: grown))
        XCTAssertEqual(place(window: laptopCopy, copies: [externalCopy], click: press), .init(display: laptop, anchor: laptopCopy))
    }

    /// The press point comes from the window server (the event's own record, else the cursor at the click), never
    /// from a conversion through the event's window.
    func testPressPointComesFromTheWindowServer() {
        XCTAssertEqual(StatusItemAnchor.windowServerPoint(event: CGPoint(x: 3000, y: 1430), cursor: CGPoint(x: 10, y: 10)), CGPoint(x: 3000, y: 1430))
        XCTAssertEqual(StatusItemAnchor.windowServerPoint(event: nil, cursor: CGPoint(x: 10, y: 10)), CGPoint(x: 10, y: 10))
        XCTAssertEqual(StatusItemAnchor.windowServerPoint(event: CGPoint(x: CGFloat.nan, y: 0), cursor: CGPoint(x: 10, y: 10)), CGPoint(x: 10, y: 10))
        XCTAssertNil(StatusItemAnchor.windowServerPoint(event: nil, cursor: CGPoint(x: CGFloat.infinity, y: 0)))
    }
}
