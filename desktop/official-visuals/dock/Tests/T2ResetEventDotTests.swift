// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import CoreGraphics
import XCTest
@testable import ModelPlanOfficialDock
import AppKit
import ModelPlanDock

final class T2ResetEventDotTests: XCTestCase {
    func testReadoutAndRimAnchorsUseTheSameInstrumentSkin() throws {
        for edge in [T2Edge.left, .right, .bottom] {
            for diameter in [CGFloat(36), 44, 52] {
                let geometry = try T2Geometry.make(subscriptions: [.init(id: "member-a")], input: .init(coordinates: .init(edge: edge, width: 1470, height: 956, menuBarExclusion: 26), diameter: diameter))
                let station = try XCTUnwrap(geometry.stations.first)
                let withReading = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true).stations[0]
                let rim = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: false).stations[0]
                XCTAssertEqual(withReading.eventRect.midX, station.readoutCentre.x + 22 * diameter / 52, accuracy: 1e-7)
                XCTAssertEqual(withReading.eventRect.midY, station.readoutCentre.y, accuracy: 1e-7)
                XCTAssertEqual(rim.eventRect.midX, station.centre.x + diameter * 0.25, accuracy: 1e-7)
                XCTAssertEqual(rim.eventRect.midY, station.centre.y - diameter * 0.433013, accuracy: 1e-7)
                for skin in [withReading, rim] {
                    XCTAssertEqual(try XCTUnwrap(skin.eventSolidDiameter), 5 * diameter / 52, accuracy: 1e-7)
                    XCTAssertEqual(try XCTUnwrap(skin.eventHollowDiameter), 6 * diameter / 52, accuracy: 1e-7)
                    XCTAssertEqual(try XCTUnwrap(skin.eventStrokeWidth), 1.2 * diameter / 52, accuracy: 1e-7)
                }
            }
        }
    }
    func testOverflowHasARegisteredNoticeAnchor() throws {
        let geometry = try T2Geometry.make(subscriptions: (0..<30).map { .init(id: "member-\($0)") }, input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26), diameter: 52))
        XCTAssertFalse(geometry.overflow.isEmpty)
        let skin = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: false)
        let overflow = try XCTUnwrap(skin.stations.first { $0.overflowCount != nil })
        XCTAssertEqual(overflow.overflowNoticeKey, "__t2_overflow_notice__")
        let position = try XCTUnwrap(geometry.stations.first { $0.isOverflow })
        let readingSkin = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true)
        let readingOverflow = try XCTUnwrap(readingSkin.stations.first { $0.overflowCount != nil })
        XCTAssertEqual(readingOverflow.eventRect.midX, position.centre.x + 52 * 0.25, accuracy: 1e-7)
        XCTAssertEqual(readingOverflow.eventRect.midY, position.centre.y - 52 * 0.433013, accuracy: 1e-7)
    }

    /// Reads the stored sRGB bytes of one pixel. The image is redrawn 1:1 into a known sRGB RGBA8 buffer, so no
    /// NSColor colour-space conversion (NSBitmapImageRep.colorAt) can shift the value being compared.
    private func sample(_ image: CGImage, x: Int, y: Int) throws -> (r: Double, g: Double, b: Double, a: Double) {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(drawn)
        // CGContext memory is top row first for a bitmap context.
        let index = (y * image.width + x) * 4
        let alpha = Double(bytes[index + 3]) / 255
        XCTAssertGreaterThan(alpha, 0)
        return (Double(bytes[index]) / alpha, Double(bytes[index + 1]) / alpha, Double(bytes[index + 2]) / alpha, alpha)
    }

    /// Draws the overflow station's notice dot with the real renderer on the real T2 skin. Artwork layers and
    /// readings are left out (an empty resource manifest), so the only thing painted over the body is the dot.
    @MainActor private func renderOverflowDot(_ notice: DockNotice) throws -> (image: CGImage, eventRect: CGRect, bounds: CGRect) {
        let geometry = try T2Geometry.make(subscriptions: (0..<30).map { .init(id: "member-\($0)") }, input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26), diameter: 52))
        var skin = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: false)
        skin.fixedLayers = []
        for index in skin.stations.indices {
            skin.stations[index].layers = []; skin.stations[index].radialOverlay = nil; skin.stations[index].overflowCount = nil
        }
        let station = try XCTUnwrap(skin.stations.first { $0.overflowNoticeKey != nil })
        let key = try XCTUnwrap(station.overflowNoticeKey)
        let store = try DockArtworkStore(root: FileManager.default.temporaryDirectory, manifest: DockResourceManifest(files: [:]))
        let result = try DockInstrumentRenderer(resources: store).render(skin: skin, readings: [:], notices: [key: notice], scale: 3)
        return (result.image, station.eventRect, skin.bounds)
    }

    /// COL-2.1-09 / DOCK-3.7-01, D166: an announced public reset (a forecast) is a hollow dot, a confirmed one a solid
    /// dot, for a reset credit and a direct reset alike. The colour follows `DockNotice.resetPalette` (owner choice
    /// pending): notice blue #9FD2FF for both, or notice amber #EAC17B / notice green #34C759.
    @MainActor func testResetDotsFollowTheResetPalette() throws {
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        var signal = DockSubscriptionSignal(id: "member-a"); signal.dataState = .fresh
        for kind in [DockResetSignal.Kind.resetCredit, .directReset] {
            var announcedReset = DockResetSignal(id: "event", status: .announced, announcedAt: now.addingTimeInterval(-60), scheduledThrough: now.addingTimeInterval(3600))
            announcedReset.kind = kind; signal.reset = announcedReset
            let announced = try XCTUnwrap(DockNoticeProjection.selected(for: signal, at: now))
            XCTAssertEqual(announced.tone, DockNotice.resetAnnouncedTone); XCTAssertEqual(announced.shape, .hollow)
            var confirmedReset = DockResetSignal(id: "event", status: .confirmed, confirmedAt: now.addingTimeInterval(-60))
            confirmedReset.kind = kind; signal.reset = confirmedReset
            let confirmed = try XCTUnwrap(DockNoticeProjection.selected(for: signal, at: now))
            XCTAssertEqual(confirmed.tone, DockNotice.resetConfirmedTone); XCTAssertEqual(confirmed.shape, .solid)
        }
        signal.reset = DockResetSignal(id: "event", status: .announced, announcedAt: now.addingTimeInterval(-60), scheduledThrough: now.addingTimeInterval(3600))
        let announced = try XCTUnwrap(DockNoticeProjection.selected(for: signal, at: now))
        signal.reset = DockResetSignal(id: "event", status: .confirmed, confirmedAt: now.addingTimeInterval(-60))
        let confirmed = try XCTUnwrap(DockNoticeProjection.selected(for: signal, at: now))

        func rgb(_ tone: DockNotice.Tone) -> (Double, Double, Double) {
            switch tone { case .amber: return (234, 193, 123); case .green: return (52, 199, 89); case .blue: return (159, 210, 255); case .white: return (255, 255, 255) }
        }
        let ringInk = rgb(DockNotice.resetAnnouncedTone), dotInk = rgb(DockNotice.resetConfirmedTone)
        let scale = 3.0
        let hollow = try renderOverflowDot(announced)
        // Hollow: the ring (6 u diameter, 1.2 u stroke) carries the ink; its centre shows the dark backdrop.
        let ringX = Int((hollow.eventRect.midX + 2.4 - hollow.bounds.minX) * scale), ringY = Int((hollow.eventRect.midY - hollow.bounds.minY) * scale)
        let ring = try sample(hollow.image, x: ringX, y: ringY)
        XCTAssertEqual(ring.r, ringInk.0, accuracy: 3); XCTAssertEqual(ring.g, ringInk.1, accuracy: 3); XCTAssertEqual(ring.b, ringInk.2, accuracy: 3)
        let hole = try sample(hollow.image, x: Int((hollow.eventRect.midX - hollow.bounds.minX) * scale), y: ringY)
        XCTAssertLessThan(max(hole.r, hole.g, hole.b), 100, "the hollow dot's centre is the dark backdrop")
        let solid = try renderOverflowDot(confirmed)
        let centre = try sample(solid.image, x: Int((solid.eventRect.midX - solid.bounds.minX) * scale), y: Int((solid.eventRect.midY - solid.bounds.minY) * scale))
        XCTAssertEqual(centre.r, dotInk.0, accuracy: 3); XCTAssertEqual(centre.g, dotInk.1, accuracy: 3); XCTAssertEqual(centre.b, dotInk.2, accuracy: 3)
    }

    /// DOCK-3.1-18a: event dots are a 12 u hit area, solid 5 u or hollow 6 u with a 1.2 u ring, and the open card's
    /// nozzle glows 0 0 7 #ffffff2e, at S, M and L, with and without a percentage readout.
    func testEventDotSizesAndHitRect() throws {
        for diameter in [CGFloat(36), 44, 52] {
            let unit = diameter / 52
            let geometry = try T2Geometry.make(subscriptions: [.init(id: "member-a")], input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26), diameter: diameter))
            for showsPercentages in [true, false] {
                let station = try XCTUnwrap(T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: showsPercentages).stations.first)
                let label = "D\(diameter) readout \(showsPercentages)"
                XCTAssertEqual(station.eventRect.width, 12 * unit, accuracy: 1e-7, label)
                XCTAssertEqual(station.eventRect.height, 12 * unit, accuracy: 1e-7, label)
                XCTAssertEqual(try XCTUnwrap(station.eventSolidDiameter), 5 * unit, accuracy: 1e-7, label)
                XCTAssertEqual(try XCTUnwrap(station.eventHollowDiameter), 6 * unit, accuracy: 1e-7, label)
                XCTAssertEqual(try XCTUnwrap(station.eventStrokeWidth), 1.2 * unit, accuracy: 1e-7, label)
                XCTAssertGreaterThan(station.eventRect.width, try XCTUnwrap(station.eventHollowDiameter), "the hit area is larger than the dot")
            }
        }
        XCTAssertEqual(QuotaWidgetCardMaterial.hotGlow, QuotaWidgetCardMaterial.RGBA(0xffffff, alpha: 0x2e))
        XCTAssertEqual(QuotaWidgetCardMaterial.hotGlowBlur, 7)
    }
}
