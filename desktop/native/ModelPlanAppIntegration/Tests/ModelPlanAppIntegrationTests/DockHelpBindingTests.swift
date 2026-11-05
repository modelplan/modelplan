// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

private actor DockHelpMemory: HintPreferenceWriting {
    private var revision: UInt64 = 0
    private var preferences = SettingsPreferences()
    func snapshot() -> SettingsSnapshot { .init(revision: revision, preferences: preferences) }
    func saveHints(_ value: FirstUseHintPreferences, expectedRevision: UInt64) throws -> SettingsSnapshot {
        guard revision == expectedRevision else { throw SettingsError.staleRevision }
        revision += 1; preferences.helpHints = value
        return .init(revision: revision, preferences: preferences)
    }
    func reset() -> UInt64 { revision += 1; preferences.helpHints = .init(); return revision }
}
@MainActor private final class DockHelpClock { var now = 0.0 }
@MainActor private final class DockHelpTimer: HintDeadlineScheduling {
    var action: (@MainActor () -> Void)?
    var callbacks: [@MainActor () -> Void] = []
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { self.action = action; callbacks.append(action) }
    func cancel() { action = nil }
    func fire() { let value = action; action = nil; value?() }
}
@MainActor private final class DockHelpFake: HintOverlayPresenting {
    var kinds: Set<FirstUseHintKind> = []
    var accepted = true
    var onShow: (() -> Void)?
    var offers: [HintOffer] = []
    var hidden: [UUID] = []
    func placeableKinds(context: HintContext, trial: InstrumentHintSourceSnapshot?) -> Set<FirstUseHintKind> { kinds }
    func showAndVerify(_ offer: HintOffer, trial: InstrumentHintSourceSnapshot?) -> Bool {
        offers.append(offer); onShow?(); return accepted
    }
    func updateAndVerify(_ presentation: HintPresentation) -> Bool { accepted }
    func hide(offerID: UUID) { hidden.append(offerID) }
}

/// All surfaces, timing and persistence are in-memory fakes; no AppKit surface is constructed.
@MainActor final class DockHelpBindingTests: XCTestCase {
    func testV1FindHintPrecedesRingOnTheSameReveal() async throws {
        let store = DockHelpMemory(), clock = DockHelpClock(), timer = DockHelpTimer(), cockpit = DockHelpFake(), dock = DockHelpFake()
        dock.kinds = [.findWidget, .ringRefresh, .ignition, .drag, .pinned]
        let router = HelpOverlayRouter(cockpit: cockpit)
        let host = await HintExecutionHost.restored(persistence: store, scheduler: timer, overlay: router, uptime: { clock.now })
        let binding = DockHelpBinding(presenter: dock, isCurrent: { _ in true }); router.installDock(binding)
        var context = HintContext(); context.v1MinimalHints = true; context.ringRefreshAvailable = true
        let surface = DockHelpSurface(revealID: UUID(), layoutID: UUID(), visible: true, dragging: false,
            anchors: [.findWidget: CGRect(x: 1, y: 1, width: 4, height: 4), .ringRefresh: CGRect(x: 9, y: 1, width: 4, height: 4)])
        try binding.update(surface, context: context, host: host)
        XCTAssertEqual(dock.offers.map(\.kind), [.findWidget])
        host.dismiss(); clock.now = 1
        try binding.update(surface, context: context, host: host)
        XCTAssertEqual(dock.offers.map(\.kind), [.findWidget, .ringRefresh])
        host.dismiss(); clock.now = 2
        try binding.update(surface, context: context, host: host)
        XCTAssertEqual(dock.offers.map(\.kind), [.findWidget, .ringRefresh])
        await host.flushPersistence()
        let saved = await store.snapshot()
        XCTAssertEqual(saved.preferences.helpHints.seen, [.findWidget, .ringRefresh])
    }
    func testV1FindHintRequiresVisibleStatusAnchorAndIsShownOnce() async throws {
        let store = DockHelpMemory(), clock = DockHelpClock(), timer = DockHelpTimer(), cockpit = DockHelpFake(), dock = DockHelpFake()
        dock.kinds = [.findWidget]
        let router = HelpOverlayRouter(cockpit: cockpit)
        let host = await HintExecutionHost.restored(persistence: store, scheduler: timer, overlay: router, uptime: { clock.now })
        let binding = DockHelpBinding(presenter: dock, isCurrent: { _ in true }); router.installDock(binding)
        var context = HintContext(); context.v1MinimalHints = true; context.widgetConcealed = true
        try binding.update(nil, context: context, host: host)
        XCTAssertTrue(dock.offers.isEmpty)
        context.statusAnchorAvailable = true
        let status = DockHelpSurface(revealID: UUID(), layoutID: UUID(), visible: true, dragging: false,
                                     anchors: [.findWidget: CGRect(x: 1, y: 1, width: 4, height: 4)])
        try binding.update(status, context: context, host: host)
        XCTAssertEqual(dock.offers.map(\.kind), [.findWidget])
        await host.flushPersistence()
        try binding.update(nil, context: context, host: host)
        clock.now = 1
        try binding.update(status, context: context, host: host)
        XCTAssertEqual(dock.offers.map(\.kind), [.findWidget])
        let saved = await store.snapshot()
        XCTAssertEqual(saved.preferences.helpHints.seen, [.findWidget])
    }
    private func surface(_ id: UUID = UUID(), layout: UUID = UUID(), visible: Bool = true, dragging: Bool = false) -> DockHelpSurface {
        .init(revealID: id, layoutID: layout, visible: visible, dragging: dragging,
              anchors: [.ignition: CGRect(x: 1, y: 1, width: 4, height: 4), .drag: CGRect(x: 9, y: 1, width: 4, height: 4)])
    }
    func testRouterDefaultsToExistingCockpitPresenter() async throws {
        let store = DockHelpMemory(), clock = DockHelpClock(), timer = DockHelpTimer(), cockpit = DockHelpFake()
        cockpit.kinds = [.detach]
        let router = HelpOverlayRouter(cockpit: cockpit)
        let host = await HintExecutionHost.restored(persistence: store, scheduler: timer, overlay: router, uptime: { clock.now })
        var context = HintContext(cockpitOpen: UUID()); context.captureReady = true
        try host.updateContext(context)
        XCTAssertEqual(cockpit.offers.map(\.kind), [.detach])
        XCTAssertTrue(host.hints.preferences.seen.contains(.detach))
        await host.flushPersistence()
    }
    func testCompositionOverlaySelectionPreservesDefaultAndUsesFactoryOnce() {
        let cockpit = DockHelpFake(), routed = DockHelpFake()
        let unchanged = selectHelpOverlay(cockpit, factory: nil)
        XCTAssertTrue(unchanged === cockpit)
        var calls = 0
        let result = selectHelpOverlay(cockpit, factory: { value in
            calls += 1; XCTAssertTrue(value === cockpit); return routed
        })
        XCTAssertTrue(result === routed); XCTAssertEqual(calls, 1)
    }
    func testOneHostFirstAndSecondRevealAndReducedMotion() async throws {
        let store = DockHelpMemory(), clock = DockHelpClock(), timer = DockHelpTimer(), cockpit = DockHelpFake(), dock = DockHelpFake()
        dock.kinds = [.ignition, .drag]
        let router = HelpOverlayRouter(cockpit: cockpit)
        let host = await HintExecutionHost.restored(persistence: store, scheduler: timer, overlay: router, uptime: { clock.now })
        let binding = DockHelpBinding(presenter: dock, isCurrent: { _ in true }); router.installDock(binding)
        var context = HintContext(); context.reducedMotion = true
        try binding.update(surface(), context: context, host: host)
        XCTAssertTrue(host.hints.preferences.seen.isEmpty)
        clock.now = 0.5; timer.fire()
        XCTAssertEqual(dock.offers.map(\.kind), [.ignition]); XCTAssertEqual(host.hints.visible?.fadeSeconds, 0)
        await host.flushPersistence()
        try binding.update(nil, context: context, host: host); await host.flushPersistence()
        clock.now = 1; try binding.update(surface(), context: context, host: host)
        clock.now = 1.5; timer.fire()
        XCTAssertEqual(dock.offers.map(\.kind), [.ignition, .drag])
        await host.flushPersistence()
        let saved = await store.snapshot()
        XCTAssertEqual(saved.preferences.helpHints.seen, [.ignition, .drag]); XCTAssertEqual(saved.preferences.helpHints.reveals, 2)
    }
    func testRevokedAnchorAndOldDeadlineNeverSpendSeen() async throws {
        let store = DockHelpMemory(), clock = DockHelpClock(), timer = DockHelpTimer(), cockpit = DockHelpFake(), dock = DockHelpFake()
        dock.kinds = [.ignition]
        let router = HelpOverlayRouter(cockpit: cockpit)
        let host = await HintExecutionHost.restored(persistence: store, scheduler: timer, overlay: router, uptime: { clock.now })
        var current = true
        let binding = DockHelpBinding(presenter: dock, isCurrent: { _ in current }); router.installDock(binding)
        try binding.update(surface(), context: .init(), host: host)
        let late = try XCTUnwrap(timer.callbacks.last)
        dock.onShow = { current = false }
        clock.now = 0.5; timer.fire()
        XCTAssertFalse(host.hints.preferences.seen.contains(.ignition)); XCTAssertNil(host.hints.visible)
        XCTAssertEqual(dock.hidden.count, 1)
        try binding.retire(context: .init(), host: host); clock.now = 1; late()
        XCTAssertFalse(host.hints.preferences.seen.contains(.ignition))
        await host.flushPersistence()
    }
    func testCommittedResetFencesLateTimer() async throws {
        let store = DockHelpMemory(), clock = DockHelpClock(), timer = DockHelpTimer(), cockpit = DockHelpFake(), dock = DockHelpFake()
        dock.kinds = [.ignition]
        let router = HelpOverlayRouter(cockpit: cockpit)
        let host = await HintExecutionHost.restored(persistence: store, scheduler: timer, overlay: router, uptime: { clock.now })
        let binding = DockHelpBinding(presenter: dock, isCurrent: { _ in true }); router.installDock(binding)
        try binding.update(surface(), context: .init(), host: host)
        clock.now = 0.5; timer.fire(); await host.flushPersistence()
        let late = try XCTUnwrap(timer.callbacks.last)
        let revision = await store.reset()
        let accepted = await host.applyCommittedReset(.init(revision: revision, intent: .action(.resetHelpHints)))
        XCTAssertTrue(accepted); XCTAssertTrue(host.hints.preferences.seen.isEmpty)
        clock.now = 10; late()
        XCTAssertTrue(host.hints.preferences.seen.isEmpty); XCTAssertNil(host.hints.visible)
    }
    func testDraggingAndLayoutReplacementCancelPriorDwell() async throws {
        let store = DockHelpMemory(), clock = DockHelpClock(), timer = DockHelpTimer(), cockpit = DockHelpFake(), dock = DockHelpFake()
        dock.kinds = [.ignition]
        let router = HelpOverlayRouter(cockpit: cockpit)
        let host = await HintExecutionHost.restored(persistence: store, scheduler: timer, overlay: router, uptime: { clock.now })
        let binding = DockHelpBinding(presenter: dock, isCurrent: { _ in true }); router.installDock(binding)
        let reveal = UUID(), layout = UUID()
        try binding.update(surface(reveal, layout: layout), context: .init(), host: host)
        let old = try XCTUnwrap(timer.callbacks.last)
        clock.now = 0.2; try binding.update(surface(reveal, layout: layout, dragging: true), context: .init(), host: host)
        clock.now = 0.5; old(); XCTAssertTrue(dock.offers.isEmpty)
        try binding.update(surface(reveal, layout: UUID()), context: .init(), host: host)
        let replacement = try XCTUnwrap(timer.callbacks.last)
        clock.now = 0.6; old(); XCTAssertTrue(dock.offers.isEmpty)
        clock.now = 1; replacement()
        XCTAssertEqual(dock.offers.map(\.kind), [.ignition])
        XCTAssertEqual(host.hints.preferences.reveals, 1)
        await host.flushPersistence()
    }
    func testReentrantRouterReplacementCannotConfirmOldSurface() async throws {
        let store = DockHelpMemory(), clock = DockHelpClock(), timer = DockHelpTimer(), cockpit = DockHelpFake(), dock = DockHelpFake()
        dock.kinds = [.ignition]
        let router = HelpOverlayRouter(cockpit: cockpit)
        let host = await HintExecutionHost.restored(persistence: store, scheduler: timer, overlay: router, uptime: { clock.now })
        let binding = DockHelpBinding(presenter: dock, isCurrent: { _ in true }); router.installDock(binding)
        dock.onShow = { router.installDock(nil) }
        try binding.update(surface(), context: .init(), host: host)
        clock.now = 0.5; timer.fire()
        XCTAssertTrue(host.hints.preferences.seen.isEmpty); XCTAssertNil(host.hints.visible)
        XCTAssertEqual(dock.hidden.count, 1)
        await host.flushPersistence()
    }
    func testUnverifiedRevealDoesNotAdvanceLedgerAndCanBecomeVisible() async throws {
        let store = DockHelpMemory(), clock = DockHelpClock(), timer = DockHelpTimer(), cockpit = DockHelpFake(), dock = DockHelpFake()
        dock.kinds = [.ignition]
        let router = HelpOverlayRouter(cockpit: cockpit)
        let host = await HintExecutionHost.restored(persistence: store, scheduler: timer, overlay: router, uptime: { clock.now })
        var current = false
        let binding = DockHelpBinding(presenter: dock, isCurrent: { _ in current }); router.installDock(binding)
        let snapshot = surface()
        try binding.update(snapshot, context: .init(), host: host)
        XCTAssertEqual(host.hints.preferences.reveals, 0); XCTAssertNil(host.hints.context.dockReveal)
        current = true; try binding.update(snapshot, context: .init(), host: host)
        XCTAssertEqual(host.hints.preferences.reveals, 1)
        clock.now = 0.5; timer.fire()
        XCTAssertEqual(dock.offers.map(\.kind), [.ignition])
        await host.flushPersistence()
    }
    func testUnregisterOrReplaceWithdrawsShownDockWithoutReroutingHide() async throws {
        for replace in [false, true] {
            let store = DockHelpMemory(), clock = DockHelpClock(), timer = DockHelpTimer()
            let cockpit = DockHelpFake(), old = DockHelpFake(), replacement = DockHelpFake()
            old.kinds = [.ignition]; replacement.kinds = [.ignition]
            let router = HelpOverlayRouter(cockpit: cockpit)
            let host = await HintExecutionHost.restored(persistence: store, scheduler: timer, overlay: router, uptime: { clock.now })
            let binding = DockHelpBinding(presenter: old, isCurrent: { _ in true }); router.installDock(binding)
            try binding.update(surface(), context: .init(), host: host)
            clock.now = 0.5; timer.fire()
            let offer = try XCTUnwrap(host.hints.visible?.offer)
            router.installDock(replace ? replacement : nil)
            XCTAssertEqual(old.hidden, [offer.id], "withdraw immediately")
            XCTAssertTrue(cockpit.hidden.isEmpty); XCTAssertTrue(replacement.hidden.isEmpty)
            router.hide(offerID: offer.id)
            XCTAssertEqual(old.hidden, [offer.id], "remove stale owner record")
            XCTAssertTrue(replacement.hidden.isEmpty)
            XCTAssertTrue(host.hints.preferences.seen.contains(.ignition))
            await host.flushPersistence()
        }
    }
    func testRemovingDockDoesNotWithdrawCockpitOffer() async throws {
        for sharedPresenter in [false, true] {
            let store = DockHelpMemory(), clock = DockHelpClock(), timer = DockHelpTimer()
            let cockpit = DockHelpFake(), separateDock = DockHelpFake()
            let dock = sharedPresenter ? cockpit : separateDock
            cockpit.kinds = [.detach]
            let router = HelpOverlayRouter(cockpit: cockpit); router.installDock(dock)
            let host = await HintExecutionHost.restored(persistence: store, scheduler: timer, overlay: router, uptime: { clock.now })
            var context = HintContext(cockpitOpen: UUID()); context.captureReady = true
            try host.updateContext(context)
            let offer = try XCTUnwrap(host.hints.visible?.offer)
            router.installDock(nil)
            XCTAssertTrue(cockpit.hidden.isEmpty); XCTAssertEqual(host.hints.visible?.offer.id, offer.id)
            host.dismiss()
            XCTAssertEqual(cockpit.hidden, [offer.id]); XCTAssertTrue(separateDock.hidden.isEmpty)
            await host.flushPersistence()
        }
    }
    func testUnregisterAndReregisterDuringShowCannotConfirmOldOffer() async throws {
        let store = DockHelpMemory(), clock = DockHelpClock(), timer = DockHelpTimer()
        let cockpit = DockHelpFake(), dock = DockHelpFake(); dock.kinds = [.ignition]
        let router = HelpOverlayRouter(cockpit: cockpit)
        let host = await HintExecutionHost.restored(persistence: store, scheduler: timer, overlay: router, uptime: { clock.now })
        let binding = DockHelpBinding(presenter: dock, isCurrent: { _ in true }); router.installDock(binding)
        dock.onShow = { router.installDock(nil); router.installDock(binding) }
        try binding.update(surface(), context: .init(), host: host)
        clock.now = 0.5; timer.fire()
        XCTAssertTrue(host.hints.preferences.seen.isEmpty); XCTAssertNil(host.hints.visible)
        XCTAssertEqual(dock.hidden.count, 1)
        await host.flushPersistence()
    }
}
