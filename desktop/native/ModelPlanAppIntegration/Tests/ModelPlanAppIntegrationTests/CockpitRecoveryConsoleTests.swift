// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

#if MODELPLAN_TEST_ONLY_SPI
/// A fake console scheduler and monotonic clock: callbacks fire only when a test advances it, in due order.
final class FakeRecoveryClock {
    var now: UInt64 = 1_000
    private var nextID = 0
    private(set) var timers: [Int: (due: UInt64, fire: @MainActor () -> Void)] = [:]
    func arm(_ delay: UInt64, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
        let id = nextID; nextID += 1
        timers[id] = (due: now + delay, fire: fire)
        return { [weak self] in self?.timers[id] = nil }
    }
    @MainActor func advance(by ms: UInt64) {
        let end = now + ms
        while let next = timers.filter({ $0.value.due <= end }).min(by: { ($0.value.due, $0.key) < ($1.value.due, $1.key) }) {
            timers[next.key] = nil; now = next.value.due; next.value.fire()
        }
        now = end
    }
}

/// The real console, owner and coordinator (whose page factory throws, so an open reports `open.noClient`), with the
/// fake scheduler and clock. Page events are what the controller and coordinator would report.
@MainActor final class RecoveryConsoleRig {
    let clock: FakeRecoveryClock
    let root: URL
    let composition: EngineDockMenuComposition
    let owner: CockpitConsoleOwner
    let coordinator: EngineCockpitCoordinator
    let surface: SharedEngineCockpitConsole
    var notices: [CockpitUnavailableNotice] = []
    var lines: [String] = []
    init(noticeGrace: Duration = .milliseconds(300)) throws {
        let clock = FakeRecoveryClock(), root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-recovery-console-" + UUID().uuidString)
        self.clock = clock; self.root = root
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root)
        let composition = EngineDockMenuComposition(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:]),
            createsNativePanels: false, makeClient: { _, _ in RouteClient() })
        let owner = CockpitConsoleOwner(bundle: root, settingsStore: settings)
        let coordinator = EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
        owner.coordinator = coordinator
        var sink: ((CockpitUnavailableNotice) -> Void)?
        let surface = SharedEngineCockpitConsole(owner: owner, composition: composition, isForeground: { true }, activate: {},
            requestNotice: { sink?($0) }, noticeGrace: noticeGrace, now: { clock.now }, schedule: { clock.arm($0, $1) })
        self.composition = composition; self.owner = owner; self.coordinator = coordinator; self.surface = surface
        sink = { [weak self] in self?.notices.append($0) }
        CockpitFailureLog.verificationLine = { [weak self] in self?.lines.append($0) }
    }
    var rebuildOpens: Int { lines.filter { $0.hasPrefix("page-rebuild open after=") }.count }
    /// A page died while shown: the controller reports the failure, then its discard closes it.
    func pageDied(_ failure: CockpitWindowFailure) {
        owner.pageFailure?(failure)
        coordinator.onClosed?()
    }
    func finish() async {
        CockpitFailureLog.verificationLine = nil
        surface.hide(); await coordinator.shutdown(); await composition.stop()
        try? FileManager.default.removeItem(at: root)
    }
}

/// Recovery contract (G3-96, G3-116) in the console: only a dead page is rebuilt, two times per rolling 10 minutes
/// (after 1 s, then 4 s), then a 60 s cooldown and an automatic probe; the generic notice is only for a dead page whose
/// budget is spent. Deterministic: every timer runs on the fake scheduler.
extension CommunityCockpitEntryTests {
    @MainActor func testRecoveryRebuildsADeadPageAfterOneThenFourSecondsAndAnnouncesOnlyWhenTheBudgetIsSpent() async throws {
        let rig = try RecoveryConsoleRig()
        rig.surface.wantsVisible = true
        rig.pageDied(.contentTerminated)
        XCTAssertTrue(rig.lines.contains { $0.hasPrefix("page-rebuild attempt=1 delayMs=1000 after=page.contentTerminated") }, rig.lines.joined(separator: "\n"))
        XCTAssertTrue(rig.surface.wantsVisible, "The presentation is kept while the page is rebuilt")
        rig.clock.advance(by: 999); XCTAssertEqual(rig.rebuildOpens, 0)
        rig.clock.advance(by: 1); XCTAssertEqual(rig.rebuildOpens, 1, "The first rebuild runs after 1 s")
        rig.coordinator.onOpened?()
        rig.clock.advance(by: 10_000)
        rig.pageDied(.unresponsive)
        XCTAssertTrue(rig.lines.contains { $0.hasPrefix("page-rebuild attempt=2 delayMs=4000 after=page.unresponsive") }, rig.lines.joined(separator: "\n"))
        rig.clock.advance(by: 3_999); XCTAssertEqual(rig.rebuildOpens, 1)
        rig.clock.advance(by: 1); XCTAssertEqual(rig.rebuildOpens, 2, "The second rebuild runs after 4 s")
        rig.coordinator.onOpened?()
        XCTAssertTrue(rig.notices.isEmpty, "Rebuilds inside the budget are silent")
        rig.pageDied(.contentTerminated)
        XCTAssertEqual(rig.notices.count, 1, "The third dead page in 10 minutes, with nothing left on screen, is announced")
        XCTAssertFalse(rig.notices.first?.bundleProblem ?? true)
        XCTAssertTrue(rig.lines.contains { $0.hasPrefix("notice-shown cause=page.contentTerminated bundleProblem=false") }, rig.lines.joined(separator: "\n"))
        XCTAssertTrue(rig.lines.contains { $0.hasPrefix("page-rebuild cooldown probeAfterMs=60000") })
        rig.clock.advance(by: 59_999); XCTAssertEqual(rig.rebuildOpens, 2)
        rig.clock.advance(by: 1); XCTAssertEqual(rig.rebuildOpens, 3, "After the cooldown one probe rebuild runs by itself")
        await rig.finish()
    }

    @MainActor func testRecoveryANewClickOpensButDoesNotResetTheBudget() async throws {
        let rig = try RecoveryConsoleRig()
        rig.surface.wantsVisible = true
        rig.pageDied(.contentTerminated); rig.clock.advance(by: 1_000); rig.coordinator.onOpened?()
        rig.pageDied(.contentTerminated); rig.clock.advance(by: 4_000); rig.coordinator.onOpened?()
        rig.surface.show() // a new click; its open step runs after the settings hop, which this test never awaits
        rig.pageDied(.contentTerminated)
        XCTAssertTrue(rig.lines.contains { $0.hasPrefix("page-rebuild cooldown") }, "A click is not sustained health: the budget stays spent")
        XCTAssertEqual(rig.notices.count, 1)
        await rig.finish()
    }

    @MainActor func testRecoveryOnlySustainedVerifiedHealthResetsTheBudget() async throws {
        for (healthy, resets) in [(119_999 as UInt64, false), (120_000, true)] {
            let rig = try RecoveryConsoleRig()
            rig.surface.wantsVisible = true
            rig.pageDied(.contentTerminated); rig.clock.advance(by: 1_000); rig.coordinator.onOpened?()
            rig.pageDied(.contentTerminated); rig.clock.advance(by: 4_000); rig.coordinator.onOpened?()
            rig.coordinator.onRenderVerified?() // the rebuilt page acknowledged a rendered display
            rig.clock.advance(by: healthy)
            rig.pageDied(.contentTerminated)
            XCTAssertEqual(rig.lines.filter { $0.hasPrefix("page-rebuild attempt=1 delayMs=1000") }.count, resets ? 2 : 1,
                           "healthy for \(healthy) ms: \(resets ? "the budget starts over" : "the budget stays spent")")
            XCTAssertEqual(rig.notices.count, resets ? 0 : 1)
            await rig.finish()
        }
    }

    /// macrevb-981-2: replies handed to a page that never acknowledges a render are not health. Two minutes of them
    /// leave the budget spent.
    @MainActor func testRecoveryRepliesWithoutARenderedReceiptDoNotResetTheBudget() async throws {
        let rig = try RecoveryConsoleRig()
        rig.surface.wantsVisible = true
        rig.pageDied(.contentTerminated); rig.clock.advance(by: 1_000); rig.coordinator.onOpened?()
        rig.pageDied(.contentTerminated); rig.clock.advance(by: 4_000); rig.coordinator.onOpened?()
        for _ in 0..<130 { rig.coordinator.onDisplayed?(); rig.clock.advance(by: 1_000) } // a reply a second, never rendered
        rig.pageDied(.contentTerminated)
        XCTAssertTrue(rig.lines.contains { $0.hasPrefix("page-rebuild cooldown") }, rig.lines.joined(separator: "\n"))
        XCTAssertEqual(rig.surface.budget.attempts.count, 2)
        XCTAssertEqual(rig.notices.count, 1)
        await rig.finish()
    }

    @MainActor func testRecoveryPrivacyDisposalRebuildsAtOnceWithoutNoticeOrBudget() async throws {
        let rig = try RecoveryConsoleRig()
        rig.surface.wantsVisible = true
        for failure in [CockpitWindowFailure.clearDeadline, .clearRejected] {
            rig.pageDied(failure)
            XCTAssertEqual(rig.rebuildOpens, failure == .clearDeadline ? 0 : 1)
            rig.clock.advance(by: 0)
            XCTAssertEqual(rig.rebuildOpens, failure == .clearDeadline ? 1 : 2, "A fresh page is built at once")
            rig.coordinator.onOpened?()
        }
        XCTAssertTrue(rig.surface.budget.attempts.isEmpty, "A privacy disposal spends no rebuild")
        XCTAssertTrue(rig.notices.isEmpty, "and is not an availability failure")
        await rig.finish()
    }

    @MainActor func testRecoveryRepairAsksForReinstallAtOnceAndRebuildsNothing() async throws {
        for failure in [CockpitWindowFailure.bundleResource, .unsupportedPageContract] {
            let rig = try RecoveryConsoleRig()
            rig.surface.wantsVisible = true
            rig.pageDied(failure)
            XCTAssertEqual(rig.notices.count, 1, "\(failure): announced at once")
            XCTAssertTrue(rig.notices.first?.bundleProblem ?? false, "\(failure): the reinstall copy")
            XCTAssertNil(rig.owner.verifiedBundle, "The bundle is admitted afresh at the next open")
            rig.pageDied(.navigationFailed) // the same page's later failure in this click
            rig.clock.advance(by: 600_000)
            XCTAssertEqual(rig.rebuildOpens, 0, "\(failure): a rebuild cannot mend it")
            XCTAssertEqual(rig.notices.count, 1)
            XCTAssertTrue(rig.surface.budget.attempts.isEmpty)
            await rig.finish()
        }
    }

    @MainActor func testRecoveryHideCancelsAPendingRebuildAndAHiddenConsoleSpendsNoBudget() async throws {
        let rig = try RecoveryConsoleRig()
        rig.surface.wantsVisible = true
        rig.pageDied(.contentTerminated)
        rig.surface.hide()
        rig.clock.advance(by: 10_000)
        XCTAssertEqual(rig.rebuildOpens, 0, "A closed cockpit is not rebuilt")
        XCTAssertEqual(rig.surface.budget.attempts.count, 1)
        rig.owner.pageFailure?(.contentTerminated) // a hidden (prewarmed) page dies
        XCTAssertEqual(rig.surface.budget.attempts.count, 1, "Nothing is spent for a page nobody asked to see")
        XCTAssertTrue(rig.clock.timers.isEmpty)
        XCTAssertTrue(rig.notices.isEmpty)
        await rig.finish()
    }
}
#endif
