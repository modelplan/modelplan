// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import XCTest
import CoreGraphics
@testable import ModelPlanOfficialDock

final class T2ResetEventDotTests: XCTestCase {
    func testSyntheticProviderPresentationDecodesWithoutWireInference() throws {
        let data = Data("""
        [{"memberKey":"member-a","style":"announced","unacknowledged":true},
         {"memberKey":"member-b","style":"confirmed","unacknowledged":false}]
        """.utf8)
        let values = try JSONDecoder().decode([T2ResetEventPresentation].self, from: data)
        let g = try geometry()
        let dots = try T2ResetEventDots.layout(geometry: g, events: values, percentageRows: rows(g), showsPercentages: true)
        XCTAssertEqual(dots.filter { $0.surface == .dock }.count, 2)
        XCTAssertEqual(dots.filter { $0.surface == .sliver }.map(\.memberKey), ["member-a"])
        XCTAssertThrowsError(try JSONDecoder().decode(T2ResetEventPresentation.self,
            from: Data("{\"memberKey\":\"member-a\",\"style\":\"unsupported\",\"unacknowledged\":true}".utf8)))
    }
    private func geometry(_ edge: T2Edge = .right, diameter: CGFloat = 44, members: [String] = ["member-a", "member-b"]) throws -> T2Geometry {
        try T2Geometry.make(subscriptions: members.map { T2Subscription(id: $0) },
            input: T2GeometryInput(coordinates: .init(edge: edge, width: 1470, height: 956, menuBarExclusion: 26), diameter: diameter))
    }
    private func rows(_ g: T2Geometry) -> [String: CGRect] {
        let scale = g.input.diameter / 52
        return Dictionary(uniqueKeysWithValues: g.stations.compactMap { station in
            station.subscription.map { ($0.id, CGRect(x: station.readoutCentre.x - 28 * scale,
                y: station.readoutCentre.y - 8 * scale, width: 56 * scale, height: 16 * scale)) }
        })
    }
    // DOCK-3.4-03/-04, DOCK-3.7-02. Synthetic provider presentation, not wire admission.
    func testPerMemberAnnouncedAndConfirmedDrawOnBothSurfaces() throws {
        for edge in [T2Edge.left, .right, .bottom] {
            for d in [CGFloat(36), 44, 52] {
                let g = try geometry(edge, diameter: d), rows = rows(g)
                let dots = try T2ResetEventDots.layout(geometry: g, events: [
                    .init(memberKey: "member-a", style: .announced, unacknowledged: true),
                    .init(memberKey: "member-b", style: .confirmed, unacknowledged: true)
                ], percentageRows: rows, showsPercentages: true)
                XCTAssertEqual(dots.count, 4)
                for dot in dots {
                    if dot.surface == .dock {
                        let row = try XCTUnwrap(rows[dot.memberKey])
                        XCTAssertEqual(dot.centre.x, row.midX + 22 * d/52, accuracy: 1e-7)
                        XCTAssertEqual(dot.centre.y, row.midY, accuracy: 1e-7)
                        XCTAssertEqual(dot.opacity, 1)
                        XCTAssertEqual(dot.diameter, (dot.style == .announced ? 6 : 5) * d/52, accuracy: 1e-7)
                    } else {
                        XCTAssertEqual(dot.opacity, 0.7)
                        XCTAssertEqual(dot.diameter, 4*d/44, accuracy: 1e-7)
                        XCTAssertGreaterThanOrEqual(dot.centre.x, 0); XCTAssertGreaterThanOrEqual(dot.centre.y, 0)
                    }
                    XCTAssertEqual(dot.strokeWidth > 0, dot.style == .announced)
                }
            }
        }
    }
    func testAcknowledgementAndMemberClearWithdrawTheLayoutValues() throws {
        let g = try geometry()
        let value = T2ResetEventPresentation(memberKey: "member-a", style: .announced, unacknowledged: false)
        let dots = try T2ResetEventDots.layout(geometry: g, events: [value], percentageRows: rows(g), showsPercentages: true)
        XCTAssertEqual(dots.count, 1); XCTAssertEqual(dots.first?.surface, .dock)
        XCTAssertTrue(try T2ResetEventDots.layout(geometry: g, events: [], percentageRows: rows(g), showsPercentages: true).isEmpty)
        let cleared = try geometry(members: [])
        XCTAssertTrue(try T2ResetEventDots.layout(geometry: cleared, events: [value], percentageRows: [:], showsPercentages: true).isEmpty)
    }
    func testRimIsScreenOneOClockAndFollowsSuppliedNozzlePresentation() throws {
        for edge in [T2Edge.left, .right, .bottom] {
            let g = try geometry(edge)
            let station = try XCTUnwrap(g.stations.first)
            let frame = CGRect(x: station.centre.x - 30, y: station.centre.y - 20, width: 50.6, height: 50.6)
            let dots = try T2ResetEventDots.layout(geometry: g,
                events: [.init(memberKey: "member-a", style: .confirmed, unacknowledged: false)],
                percentageRows: [:], showsPercentages: false, nozzlePresentationRects: ["member-a": frame])
            let dot = try XCTUnwrap(dots.first)
            XCTAssertEqual(dot.centre.x, frame.midX + frame.width * 0.25, accuracy: 1e-7)
            XCTAssertEqual(dot.centre.y, frame.midY - frame.height * 0.433013, accuracy: 1e-7)
            XCTAssertGreaterThan(dot.centre.x, frame.midX); XCTAssertLessThan(dot.centre.y, frame.midY)
            XCTAssertEqual(dot.diameter, 5*44/52.0, accuracy: 1e-7, "Magnification moves the anchor, not the notice size")
        }
    }
    func testForeignKeysDoNotAttachByVendorAndInvalidInputsRefuse() throws {
        let g = try geometry()
        let foreign = T2ResetEventPresentation(memberKey: "old-member-key", style: .announced, unacknowledged: true)
        XCTAssertTrue(try T2ResetEventDots.layout(geometry: g, events: [foreign], percentageRows: [:], showsPercentages: true).isEmpty)
        let event = T2ResetEventPresentation(memberKey: "member-a", style: .announced, unacknowledged: true)
        XCTAssertThrowsError(try T2ResetEventDots.layout(geometry: g, events: [event,event], percentageRows: rows(g), showsPercentages: true))
        XCTAssertThrowsError(try T2ResetEventDots.layout(geometry: g, events: [event], percentageRows: [:], showsPercentages: true))
    }
    func testHiddenOverflowMemberMapsOnlyToSliverUntilATrayAnchorExists() throws {
        let g = try geometry(diameter: 52, members: (0..<30).map { "member-\($0)" })
        let member = try XCTUnwrap(g.overflow.first?.id)
        let event = T2ResetEventPresentation(memberKey: member, style: .announced, unacknowledged: true)
        let collapsed = try T2ResetEventDots.layout(geometry: g, events: [event], percentageRows: rows(g), showsPercentages: true)
        XCTAssertEqual(collapsed.count, 1); XCTAssertEqual(collapsed.first?.surface, .sliver)
        var trayRows = rows(g)
        trayRows[member] = CGRect(x: 100, y: 100, width: 56, height: 16)
        let expanded = try T2ResetEventDots.layout(geometry: g, events: [event], percentageRows: trayRows, showsPercentages: true)
        XCTAssertEqual(expanded.filter { $0.surface == .dock }.count, 1)
        XCTAssertEqual(expanded.filter { $0.surface == .sliver }.count, 1)
    }
    func testPainterUsesBlueInkAndHollowAnnouncement() throws {
        func image(_ style: T2ResetEventPresentation.Style) throws -> Data {
            let c = try XCTUnwrap(CGContext(data:nil,width:16,height:16,bitsPerComponent:8,bytesPerRow:64,
                space:CGColorSpace(name:CGColorSpace.sRGB)!,
                bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            let dot = T2ResetDot(memberKey:"member-a",surface:.dock,style:style,centre:CGPoint(x:8,y:8),
                diameter:6,strokeWidth:style == .announced ? 1.2:0,opacity:1,outlineWidth:0)
            T2ResetEventDots.draw([dot],surface:.dock,in:c)
            return try XCTUnwrap(c.makeImage()?.dataProvider?.data) as Data
        }
        let offset = 8*64 + 8*4
        let solid = try image(.confirmed), hollow = try image(.announced)
        for (channel, expected) in [159,210,255,255].enumerated() {
            XCTAssertEqual(Double(solid[offset+channel]), Double(expected), accuracy:2)
        }
        for (channel, expected) in [16,21,28,255].enumerated() {
            XCTAssertEqual(Double(hollow[offset+channel]), Double(expected), accuracy:2)
        }
    }
}
