// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanAppIntegration

/// Build 5 (owner 11-25, menu-bar binding). Invariant: the attached cockpit and its rack hang from the ModelPlan status
/// item on the display that holds it, on every open. One test per path of the PATHS table in the PR. Pure geometry, no
/// window server. Each case fails on fb53eb1c, whose anchor was any button-window frame that merely touched a display.
final class StatusItemAnchorTests: XCTestCase {
    /// A 1512 x 982 MacBook display (37 pt menu bar) at the origin and a 2560 x 1440 display (25 pt) on its right.
    private let laptop = StatusItemAnchor.Display(frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                                  visibleFrame: CGRect(x: 0, y: 70, width: 1512, height: 875))
    private let external = StatusItemAnchor.Display(frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
                                                    visibleFrame: CGRect(x: 1512, y: 0, width: 2560, height: 1415))
    private var displays: [StatusItemAnchor.Display] { [laptop, external] }
    private let menuHeight: CGFloat = 24
    /// The item on each display's menu bar, 36 pt wide (the same distance from the right edge on both).
    private var laptopIcon: CGRect { CGRect(x: 1300, y: 945, width: 36, height: 37) }
    private var externalIcon: CGRect { CGRect(x: 3860, y: 1415, width: 36, height: 25) }

    private func click(at point: CGPoint, width: CGFloat = 36, height: CGFloat = 24,
                       on arrangement: [StatusItemAnchor.Display]? = nil) throws -> StatusItemAnchor {
        try XCTUnwrap(StatusItemAnchor.click(pointer: point, local: CGPoint(x: width / 2, y: height / 2),
                                             buttonBounds: CGRect(x: 0, y: 0, width: width, height: height), flipped: false,
                                             displays: arrangement ?? displays))
    }
    private func resolve(window: CGRect?, click: StatusItemAnchor?, width: CGFloat = 36,
                         on arrangement: [StatusItemAnchor.Display]? = nil) -> CGRect? {
        StatusItemAnchor.resolve(window: window, click: click, itemWidth: width, displays: arrangement ?? displays, menuHeight: menuHeight)
    }

    /// The press is placed by the pointer and the press point inside the button, never by the button window's frame.
    func testClickRectIsCentredOnThePressFlippedOrNot() throws {
        let bounds = CGRect(x: 0, y: 0, width: 40, height: 22)
        let plain = try XCTUnwrap(StatusItemAnchor.click(pointer: CGPoint(x: 1000, y: 970), local: CGPoint(x: 10, y: 5),
                                                         buttonBounds: bounds, flipped: false, displays: displays))
        XCTAssertEqual(plain.rect, CGRect(x: 990, y: 965, width: 40, height: 22))
        let flipped = try XCTUnwrap(StatusItemAnchor.click(pointer: CGPoint(x: 1000, y: 970), local: CGPoint(x: 10, y: 5),
                                                           buttonBounds: bounds, flipped: true, displays: displays))
        XCTAssertEqual(flipped.rect, CGRect(x: 990, y: 953, width: 40, height: 22))
        let outside = try XCTUnwrap(StatusItemAnchor.click(pointer: CGPoint(x: 1000, y: 970), local: CGPoint(x: -3, y: 30),
                                                           buttonBounds: bounds, flipped: false, displays: displays))
        XCTAssertTrue(outside.rect.minX <= 1000 && 1000 <= outside.rect.maxX, "an edge press still lies in the rect")
        XCTAssertNil(StatusItemAnchor.click(pointer: CGPoint(x: CGFloat.nan, y: 0), local: .zero, buttonBounds: bounds, flipped: false, displays: displays))
    }

    /// PATH first open: the menu bar has not laid the item out yet, so its window is at a parking frame (x 0 in the band,
    /// or below the screen). fb53eb1c used it: the cockpit clamped to the display's left edge with the rack at its
    /// top-left corner. The click binds it to the item.
    func testFirstOpenParkingFrameNeverAnchorsTheClickDoes() throws {
        let press = try click(at: CGPoint(x: laptopIcon.midX, y: laptopIcon.midY))
        for parked in [CGRect(x: 0, y: 945, width: 36, height: 37), CGRect(x: 0, y: -22, width: 36, height: 44),
                       CGRect(x: 0, y: 400, width: 36, height: 24)] {
            let anchor = try XCTUnwrap(resolve(window: parked, click: press), "parked at \(parked)")
            XCTAssertEqual(anchor.midX, laptopIcon.midX, accuracy: 0.5, "the rack hangs under the clicked item")
        }
        // Without a click (a shortcut before the item is placed) there is no anchor: D378's notch fallback, not x 0.
        XCTAssertNil(resolve(window: CGRect(x: 0, y: -22, width: 36, height: 44), click: nil))
        XCTAssertNil(resolve(window: CGRect(x: 0, y: 400, width: 36, height: 24), click: nil))
        XCTAssertNil(resolve(window: CGRect(x: 0, y: 945, width: 36, height: 37), click: nil), "x 0 in the band is a parking frame")
    }

    /// PATH reopen: the button's window is the copy on the other display's menu bar (the last one laid out). fb53eb1c
    /// bound the cockpit to that display. The click on this display's copy wins; with no click the window is used.
    func testReopenFromTheOtherDisplaysCopyBindsToTheClickedOne() throws {
        let onExternal = try click(at: CGPoint(x: externalIcon.midX, y: externalIcon.midY))
        XCTAssertEqual(resolve(window: laptopIcon, click: onExternal)?.midX ?? 0, externalIcon.midX, accuracy: 0.5)
        let onLaptop = try click(at: CGPoint(x: laptopIcon.midX, y: laptopIcon.midY))
        XCTAssertEqual(resolve(window: externalIcon, click: onLaptop)?.midX ?? 0, laptopIcon.midX, accuracy: 0.5)
        XCTAssertEqual(resolve(window: laptopIcon, click: onLaptop), laptopIcon, "agreeing sources keep the window's exact rect")
        XCTAssertEqual(resolve(window: externalIcon, click: nil), externalIcon, "a shortcut reopen reads the item's window")
    }

    /// PATH screen change: a click made on another arrangement no longer names the item; the placed window does.
    func testDisplayArrangementChangeDropsTheClick() throws {
        let old = try click(at: CGPoint(x: laptopIcon.midX, y: laptopIcon.midY), on: [laptop])
        XCTAssertEqual(resolve(window: externalIcon, click: old), externalIcon)
        XCTAssertNil(resolve(window: CGRect(x: 0, y: -22, width: 36, height: 44), click: old), "stale click, parked window: no anchor")
    }

    /// PATH status-item width change: the automatic display turns the icon into icon + percentage (36 -> 74 pt); the
    /// click's rect has the old width and position, so the placed window is used.
    func testStatusItemWidthChangeDropsTheClick() throws {
        let press = try click(at: CGPoint(x: externalIcon.midX, y: externalIcon.midY))
        let wider = CGRect(x: 3822, y: 1415, width: 74, height: 25)
        XCTAssertEqual(resolve(window: wider, click: press, width: 74), wider)
        XCTAssertEqual(resolve(window: externalIcon, click: press, width: 36), externalIcon)
    }

    /// PATH wake: the same arrangement after sleep. The item is where it was, so window and click agree on the window;
    /// a window still parked while the menu bar comes back is replaced by the click.
    func testWakeKeepsTheItemAndRejectsAParkedWindow() throws {
        let press = try click(at: CGPoint(x: laptopIcon.midX, y: laptopIcon.midY))
        XCTAssertEqual(resolve(window: laptopIcon, click: press), laptopIcon)
        XCTAssertEqual(resolve(window: CGRect(x: 0, y: 945, width: 36, height: 37), click: press)?.midX ?? 0, laptopIcon.midX, accuracy: 0.5)
    }

    /// PATH display reconfigure: the external display is unplugged while the cockpit hangs from its copy. The window
    /// moves to the laptop's menu bar; the click (old arrangement) is dropped, so the cockpit follows the item.
    func testDisplayReconfigureFollowsTheItemToTheRemainingDisplay() throws {
        let press = try click(at: CGPoint(x: externalIcon.midX, y: externalIcon.midY))
        XCTAssertEqual(resolve(window: laptopIcon, click: press, on: [laptop]), laptopIcon)
        XCTAssertNil(resolve(window: externalIcon, click: press, on: [laptop]), "a frame on a display that is gone is no anchor")
    }

    /// The placement rule itself: the centre must be in some display's menu bar band (at least `menuHeight` tall).
    func testMenuBarBandPlacement() {
        XCTAssertEqual(StatusItemAnchor.menuBarDisplay(of: laptopIcon, displays: displays, menuHeight: menuHeight), laptop)
        XCTAssertEqual(StatusItemAnchor.menuBarDisplay(of: externalIcon, displays: displays, menuHeight: menuHeight), external)
        XCTAssertNil(StatusItemAnchor.menuBarDisplay(of: CGRect(x: 600, y: 500, width: 36, height: 24), displays: displays, menuHeight: menuHeight))
        // A hidden menu bar (full screen, visible frame up to the top) still has a band of `menuHeight`.
        let full = StatusItemAnchor.Display(frame: laptop.frame, visibleFrame: laptop.frame)
        XCTAssertEqual(StatusItemAnchor.menuBarDisplay(of: CGRect(x: 1300, y: 960, width: 36, height: 22), displays: [full], menuHeight: 24), full)
    }
}
