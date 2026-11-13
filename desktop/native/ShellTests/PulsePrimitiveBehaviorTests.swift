// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanShell

@MainActor final class PulsePrimitiveBehaviorTests: XCTestCase {
    func testFollowerRetriesRefusalThenDeduplicatesAndReprobes() {
        let follower = ActiveDisplayFollower(currentDisplayIdentifier: { "display-A" })
        var calls = 0
        follower.onEnter = { _ in calls += 1; return calls != 1 }
        follower.start(); defer { follower.stop() }
        follower.sample(); follower.sample(); follower.sample()
        XCTAssertEqual(calls, 2, "refusal must not remember an unhandled display")
        follower.forgetLastDisplay(); follower.sample()
        XCTAssertEqual(calls, 3, "screen changes must report the same id again")
    }
    func testFollowerStopPreventsSamplingAndRestartForgetsOldDisplay() {
        var reads = 0, calls = 0
        let follower = ActiveDisplayFollower(currentDisplayIdentifier: { reads += 1; return "display-A" })
        follower.onEnter = { _ in calls += 1; return true }
        follower.start(); follower.sample(); follower.stop(); follower.sample()
        XCTAssertEqual(reads, 1); XCTAssertEqual(calls, 1); XCTAssertFalse(follower.isRunning)
        follower.start(); defer { follower.stop() }; follower.sample()
        XCTAssertEqual(calls, 2)
    }
    func testCallbackCannotLatchAnIdentifierAfterStoppingItsFollower() {
        let follower = ActiveDisplayFollower(currentDisplayIdentifier: { "display-A" })
        var calls = 0
        follower.onEnter = { _ in calls += 1; follower.stop(); return true }
        follower.start(); follower.sample()
        XCTAssertFalse(follower.isRunning)
        follower.start(); follower.sample(); follower.stop()
        XCTAssertEqual(calls, 2, "the stopped callback cannot suppress the restart sample")
    }
    func testPointerSamplerDeduplicatesSubpointMotionButReportsExitAndReprobe() {
        var point: CGPoint? = CGPoint(x: 12, y: 34)
        let view = PanelPointerWatcher.WatcherView(pointSource: { point })
        var reports: [CGPoint?] = []
        view.onChange = { reports.append($0) }
        view.start(); defer { view.stop() }
        view.sample()
        point = CGPoint(x: 12.9, y: 34.9); view.sample()
        XCTAssertEqual(reports.count, 1)
        point = CGPoint(x: 13, y: 34); view.sample()
        XCTAssertEqual(reports.last!, point, "one-point motion must not be suppressed")
        point = nil; view.sample(); view.sample()
        XCTAssertEqual(reports.count, 3); XCTAssertNil(reports.last!)
        view.reportAgain(); view.sample()
        XCTAssertEqual(reports.count, 4, "an already absent pointer must be reportable again")
    }
    func testStoppedPointerSamplerDoesNotReadOrReportAndRestartForgetsOldSample() {
        var reads = 0, reports = 0
        let view = PanelPointerWatcher.WatcherView(pointSource: {
            reads += 1; return CGPoint(x: 2, y: 3)
        })
        view.onChange = { _ in reports += 1 }
        view.start(); view.sample(); view.stop(); view.sample()
        XCTAssertEqual(reads, 1); XCTAssertEqual(reports, 1)
        view.start(); view.sample(); view.stop()
        XCTAssertEqual(reports, 2)
        XCTAssertTrue(view.isFlipped, "production conversion uses SwiftUI's top-left coordinates")
    }
    func testTrackingEntryWorksWithoutActiveApplicationAndDoesNotDuplicateAreas() {
        let view = PointerEntryReporter.TrackingView()
        var entries = 0
        view.onEnter = { entries += 1 }
        view.updateTrackingAreas(); view.updateTrackingAreas()
        XCTAssertEqual(view.trackingAreas.count, 1)
        let options = view.trackingAreas[0].options
        XCTAssertTrue(options.contains(.activeAlways))
        XCTAssertTrue(options.contains(.inVisibleRect))
        XCTAssertFalse(options.contains(.activeInKeyWindow))
        let event = NSEvent.enterExitEvent(with: .mouseEntered, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 1, trackingNumber: 0, userData: nil)!
        view.mouseEntered(with: event)
        XCTAssertEqual(entries, 1)
    }

    func testComposedPointerEntryReprobesAbsentSampleAndNeverCapturesClicks() throws {
        let surface = PulsePanelPointerSurface(pointSource: { nil })
        var reports = 0; surface.onChange = { _ in reports += 1 }
        surface.setActive(true); defer { surface.stop() }
        surface.sampleNow(); surface.sampleNow()
        XCTAssertEqual(reports, 1)
        XCTAssertNil(surface.hitTest(.zero), "observation must not consume instrument/menu/drag input")
        let entry = try XCTUnwrap(surface.subviews.first { !$0.trackingAreas.isEmpty })
        let event = try XCTUnwrap(NSEvent.enterExitEvent(with: .mouseEntered, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 1, trackingNumber: 0, userData: nil))
        entry.mouseEntered(with: event)
        XCTAssertEqual(reports, 2, "late entry must force an already absent sample through again")
        surface.stop(); entry.mouseEntered(with: event); surface.sampleNow()
        XCTAssertEqual(reports, 2, "disabled entry and queued sample cannot report")
    }
    func testComposedPointerSurfaceStopsReadsAndResizesBothObservers() {
        var reads = 0
        let surface = PulsePanelPointerSurface(pointSource: { reads += 1; return CGPoint(x: 2, y: 3) })
        surface.frame = CGRect(x: 0, y: 0, width: 80, height: 180)
        surface.setActive(true); surface.sampleNow(); surface.stop(); surface.sampleNow()
        XCTAssertEqual(reads, 1)
        XCTAssertTrue(surface.isFlipped)
        XCTAssertTrue(surface.subviews.allSatisfy { $0.frame == surface.bounds })
        surface.setActive(true); surface.sampleNow(); surface.stop()
        XCTAssertEqual(reads, 2, "restart must not retain a stopped sample")
    }

    func testEntryQueriesFreshProbeBetweenSamplerTicks() throws {
        var point: CGPoint? = CGPoint(x: 2, y: 3)
        let surface = PulsePanelPointerSurface(pointSource: { point })
        var reports: [CGPoint?] = []; surface.onChange = { reports.append($0) }
        surface.setActive(true); defer { surface.stop() }
        surface.sampleNow()
        point = CGPoint(x: 29, y: 31)
        let entry = try XCTUnwrap(surface.subviews.first { !$0.trackingAreas.isEmpty })
        let event = try XCTUnwrap(NSEvent.enterExitEvent(with: .mouseEntered, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 1, trackingNumber: 0, userData: nil))
        entry.mouseEntered(with: event)
        XCTAssertEqual(reports.count, 2)
        XCTAssertEqual(reports.last!, point, "entry must read the linked live probe, not the previous sample")
        surface.reportAgain(); surface.sampleNow()
        XCTAssertEqual(reports.count, 3, "production reparent/reprobe must also use the linked probe")
    }

}
