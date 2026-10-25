// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanField

final class FieldLifecycleTests: XCTestCase {
    func testStartupUpdatesAndDuplicateEnlargeOwnOnlyOneInstance() throws {
        var state = FieldLifecycle(configuration: try fixture())
        XCTAssertEqual(state.phase, .still)
        XCTAssertTrue(state.update(try fixture("public-r2"), now: at(0)).isEmpty)
        let first = state.enlarge(now: at(0))
        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(state.enlarge(now: at(1)).isEmpty)
        let command = commands(state.receive(message(.ready, state.generation!), now: at(2)))[0]
        XCTAssertEqual(command.configuration?.projection.revision, "public-r2")
        XCTAssertTrue(state.receive(message(.ready, state.generation!), now: at(3)).isEmpty)
    }
    func testMissingReadySettledAndCaptureHaveIndependentFailureBounds() throws {
        var state = FieldLifecycle(configuration: try fixture())
        _ = state.enlarge(now: at(0))
        XCTAssertTrue(state.advance(now: at(9.9)).isEmpty)
        XCTAssertEqual(state.advance(now: at(10)).count, 2)
        XCTAssertEqual(state.lastRelease, .readyTimeout)
        XCTAssertEqual(state.phase, .failed)
        XCTAssertNil(state.generation)
        XCTAssertTrue(state.update(try fixture("public-r2"), now: at(11)).isEmpty)
        _ = state.enlarge(now: at(20))
        _ = state.receive(message(.ready, state.generation!), now: at(21))
        _ = state.advance(now: at(26))
        XCTAssertEqual(state.lastRelease, .settledTimeout)
        var capturing = FieldLifecycle(configuration: try fixture())
        _ = startLive(&capturing, consumeCapture: false)
        _ = capturing.advance(now: at(4))
        XCTAssertEqual(capturing.lastRelease, .captureTimeout)
    }
    func testCloseWhileLoadingAndLateEventsCannotRestoreRenderer() throws {
        var state = FieldLifecycle(configuration: try fixture())
        _ = state.enlarge(now: at(0)); let old = state.generation!
        let effects = state.close(now: at(1))
        XCTAssertEqual(effects.count, 2)
        XCTAssertNil(state.generation)
        XCTAssertEqual(state.phase, .still)
        XCTAssertTrue(state.receive(message(.ready, old), now: at(1.1)).isEmpty)
        _ = state.enlarge(now: at(2)); let new = state.generation!
        XCTAssertNotEqual(old, new)
        XCTAssertTrue(state.receive(message(.ready, old), now: at(3)).isEmpty)
        XCTAssertEqual(commands(state.receive(message(.ready, new), now: at(3))).count, 1)
    }
    func testProjectionAndAppearanceChangesCoalesceAndCancelOldCapture() throws {
        var state = FieldLifecycle(configuration: try fixture())
        let (generation, key) = startLive(&state, consumeCapture: false)
        let r2 = commands(state.update(try fixture("public-r2"), now: at(2.5)))[0]
        XCTAssertEqual(r2.type, .setPublicProjection)
        XCTAssertNil(state.pendingCapture)
        XCTAssertTrue(state.update(try fixture("public-r3", theme: .day), now: at(2.6)).isEmpty)
        XCTAssertTrue(state.receive(message(.captureResult, generation, request: key.requestId, key: key), now: at(2.7)).isEmpty)
        let next = commands(state.receive(message(.settled, generation, request: r2.requestId), now: at(3)))[0]
        XCTAssertEqual(next.configuration?.projection.revision, "public-r3")
        XCTAssertEqual(next.type, .configure)
        XCTAssertEqual(next.configuration?.appearance.theme, .day)
        XCTAssertTrue(state.receive(message(.settled, generation, request: r2.requestId), now: at(3.1)).isEmpty)
    }
    func testCaptureIdentityDuplicateAndDelayedCompletionRules() throws {
        var state = FieldLifecycle(configuration: try fixture())
        let (generation, key) = startLive(&state, consumeCapture: false)
        var bad = key
        bad = FieldCaptureKey(generation: generation, requestId: key.requestId, configurationId: key.configurationId,
                              appearance: .init(theme: .day, locale: .english), viewport: key.viewport,
                              projectionRevision: key.projectionRevision)
        XCTAssertTrue(state.receive(message(.captureResult, generation, request: key.requestId, key: bad), now: at(2.5)).isEmpty)
        let valid = state.receive(message(.captureResult, generation, request: key.requestId, key: key), now: at(3))
        XCTAssertEqual(valid, [.snapshot(key)])
        XCTAssertTrue(state.receive(message(.captureResult, generation, request: key.requestId, key: key), now: at(3.1)).isEmpty)
        _ = state.setVisibility(.collapsed, now: at(3.2))
        XCTAssertFalse(state.acceptCapture(key, now: at(3.3)))
        XCTAssertNil(state.generation)
        XCTAssertTrue(state.receive(message(.captureResult, generation, request: key.requestId, key: key), now: at(3.4)).isEmpty)
    }
    func testCaptureAtDeadlineCannotCommit() throws {
        var state = FieldLifecycle(configuration: try fixture())
        let (generation, key) = startLive(&state, consumeCapture: false)
        _ = state.receive(message(.captureResult, generation, request: key.requestId, key: key), now: at(3))
        XCTAssertFalse(state.acceptCapture(key, now: at(4)))
        _ = state.advance(now: at(4))
        XCTAssertNil(state.generation)
    }
    func testOnlyMeaningfulCurrentInteractionRenewsIdleDeadline() throws {
        var state = FieldLifecycle(configuration: try fixture())
        let (generation, _) = startLive(&state)
        // Being visible while another app has focus has no state mutation/lifetime consequence.
        XCTAssertTrue(state.advance(now: at(100)).isEmpty)
        _ = state.receive(message(.interaction, UUID(), interaction: .pointer), now: at(101))
        _ = state.receive(message(.interaction, generation, interaction: .drag), now: at(120))
        XCTAssertTrue(state.advance(now: at(299)).isEmpty)
        _ = state.advance(now: at(300))
        XCTAssertEqual(state.lastRelease, .idle)
        XCTAssertEqual(state.phase, .still)
        _ = state.setVisibility(.visible, now: at(301))
        XCTAssertNil(state.generation)
    }
    func testOcclusionPausesCoalescesAndUncoverDoesNotRemountAfterDisposal() throws {
        var state = FieldLifecycle(configuration: try fixture())
        let (generation, _) = startLive(&state)
        let pause = commands(state.setVisibility(.occluded, now: at(10)))[0]
        XCTAssertEqual(pause.type, .setAppearance)
        XCTAssertEqual(pause.paused, true)
        XCTAssertTrue(state.setVisibility(.occluded, now: at(11)).isEmpty)
        _ = state.receive(message(.settled, generation, request: pause.requestId), now: at(12))
        _ = state.advance(now: at(15))
        XCTAssertEqual(state.lastRelease, .occluded)
        _ = state.setVisibility(.visible, now: at(16))
        XCTAssertNil(state.generation)
        XCTAssertEqual(state.enlarge(now: at(17)).count, 1)
    }
    func testBriefOcclusionResumesSameInstanceWithNoHiddenCapture() throws {
        var state = FieldLifecycle(configuration: try fixture())
        let (generation, _) = startLive(&state)
        let pause = commands(state.setVisibility(.occluded, now: at(10)))[0]
        XCTAssertTrue(state.receive(message(.settled, generation, request: pause.requestId), now: at(11)).isEmpty)
        XCTAssertNil(state.pendingCapture)
        let resume = commands(state.setVisibility(.visible, now: at(12)))[0]
        XCTAssertEqual(resume.paused, false)
        _ = state.receive(message(.settled, generation, request: resume.requestId), now: at(13))
        XCTAssertEqual(state.generation, generation)
        XCTAssertNotNil(state.pendingCapture)
    }
    func testImmediateInterruptionAndSurfaceExitReasonsReleaseOnce() throws {
        for reason in [FieldReleaseReason.locked, .sleep, .sessionInactive, .screenRemoved, .memoryPressure,
                       .termination, .webProcessTerminated, .navigation] {
            var state = FieldLifecycle(configuration: try fixture())
            _ = startLive(&state)
            XCTAssertEqual(state.close(reason, now: at(10)).count, 2)
            XCTAssertNil(state.generation)
            XCTAssertTrue(state.close(reason, now: at(11)).isEmpty)
        }
        for visibility in [FieldVisibility.orderedOut, .collapsed, .offSpace] {
            var state = FieldLifecycle(configuration: try fixture())
            _ = startLive(&state)
            XCTAssertEqual(state.setVisibility(visibility, now: at(10)).count, 2)
            XCTAssertTrue(state.enlarge(now: at(11)).isEmpty)
        }
    }
    func testCombinedLockSleepSessionAndDisplayBlockersRequireSeparateRecovery() throws {
        var state = FieldLifecycle(configuration: try fixture())
        _ = startLive(&state)
        _ = state.setBlocked(.locked, blocked: true, now: at(10))
        _ = state.setBlocked(.sleep, blocked: true, now: at(11))
        _ = state.setBlocked(.sleep, blocked: false, now: at(12))
        XCTAssertTrue(state.enlarge(now: at(13)).isEmpty)
        _ = state.setBlocked(.locked, blocked: false, now: at(14))
        XCTAssertNil(state.generation)
        XCTAssertEqual(state.enlarge(now: at(15)).count, 1)
        _ = state.setBlocked(.noDisplay, blocked: true, now: at(16))
        XCTAssertTrue(state.enlarge(now: at(17)).isEmpty)
    }
    func testOccludedDeadlineDoesNotReportASettledFailureWhenBothExpireTogether() throws {
        var state = FieldLifecycle(configuration: try fixture())
        _ = startLive(&state)
        _ = state.setVisibility(.occluded, now: at(10))
        _ = state.advance(now: at(15))
        XCTAssertEqual(state.lastRelease, .occluded)
        XCTAssertEqual(state.phase, .still)
    }
    func testDisposalAckIsBoundedDiagnosticNotClosePermission() throws {
        var state = FieldLifecycle(configuration: try fixture())
        let (generation, _) = startLive(&state)
        let dispose = commands(state.close(now: at(10)))[0]
        XCTAssertNil(state.generation)
        _ = state.receive(message(.disposed, generation, request: dispose.requestId), now: at(10.1))
        XCTAssertTrue(state.disposalAcknowledged)
        XCTAssertEqual(state.phase, .still)
        _ = state.enlarge(now: at(11))
        let next = commands(state.close(now: at(12)))[0]
        _ = state.receive(message(.disposed, next.generation, request: next.requestId), now: at(12.3))
        XCTAssertFalse(state.disposalAcknowledged)
    }
}
