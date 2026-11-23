// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanShell
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// D377 option C (owner 2026-11-21): the automatic menu-bar display. Icon only normally; a compact number below the
/// alert line; the icon with a red dot when used up; the icon only again when the item is squeezed.
@MainActor final class D377StatusAutoDisplayTests: XCTestCase {
    private let base = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func reading(_ remaining: Double, line: Double = 25, name: String = "Codex") -> StatusAutoInput {
        .reading(.init(name: name, remaining: remaining, shown: "\(Int(remaining.rounded()))%", alertLine: line))
    }

    // ---- the policy, pure ----

    func testIconOnlyAboveTheAlertLineAndNumberBelowIt() {
        var auto = StatusAutoDisplay()
        XCTAssertEqual(auto.resolve(reading(60), squeezed: false, displayEpoch: 0, now: base), .iconOnly, "normally the icon only")
        XCTAssertEqual(auto.resolve(reading(26), squeezed: false, displayEpoch: 0, now: base), .iconOnly, "above the line")
        XCTAssertEqual(auto.resolve(reading(25), squeezed: false, displayEpoch: 0, now: base), .number("25%"), "at the line")
        XCTAssertEqual(auto.resolve(reading(12), squeezed: false, displayEpoch: 0, now: base), .number("12%"))
    }

    func testTheNumberGoesOnlyFiveAboveTheLine() {
        var auto = StatusAutoDisplay()
        XCTAssertEqual(auto.resolve(reading(20), squeezed: false, displayEpoch: 0, now: base), .number("20%"))
        XCTAssertEqual(auto.resolve(reading(29), squeezed: false, displayEpoch: 0, now: base), .number("29%"), "inside the hysteresis band the number stays")
        XCTAssertEqual(auto.resolve(reading(30), squeezed: false, displayEpoch: 0, now: base), .number("30%"), "exactly line + 5 still stays")
        XCTAssertEqual(auto.resolve(reading(31), squeezed: false, displayEpoch: 0, now: base), .iconOnly, "above line + 5 the number goes")
        XCTAssertEqual(auto.resolve(reading(27), squeezed: false, displayEpoch: 0, now: base), .iconOnly, "and does not come back above the line")
    }

    func testUsedUpShowsTheIconWithARedDotAndNoNumber() {
        var auto = StatusAutoDisplay()
        XCTAssertEqual(auto.resolve(reading(0), squeezed: false, displayEpoch: 0, now: base), .usedUp)
        XCTAssertEqual(auto.resolve(reading(0), squeezed: true, displayEpoch: 0, now: base.addingTimeInterval(5)), .usedUp,
                       "a used-up item is already icon width: a squeeze changes nothing")
        XCTAssertEqual(auto.resolve(reading(8), squeezed: false, displayEpoch: 0, now: base.addingTimeInterval(6)), .number("8%"))
    }

    func testNoReadingIsTheIconOnlyAndAGapKeepsTheLastReading() {
        var auto = StatusAutoDisplay()
        XCTAssertEqual(auto.resolve(.none, squeezed: false, displayEpoch: 0, now: base), .iconOnly)
        XCTAssertEqual(auto.resolve(.unavailable, squeezed: false, displayEpoch: 0, now: base), .iconOnly, "no reading yet")
        XCTAssertEqual(auto.resolve(reading(12), squeezed: false, displayEpoch: 0, now: base), .number("12%"))
        XCTAssertEqual(auto.resolve(.unavailable, squeezed: false, displayEpoch: 0, now: base.addingTimeInterval(1)), .number("12%"))
        XCTAssertEqual(auto.resolve(.unavailable, squeezed: false, displayEpoch: 0,
                                    now: base.addingTimeInterval(StatusTitleKeeper.holdLimit + 2)), .iconOnly)
        XCTAssertEqual(auto.resolve(reading(12), squeezed: false, displayEpoch: 0, now: base.addingTimeInterval(700)), .number("12%"))
        XCTAssertEqual(auto.resolve(.none, squeezed: false, displayEpoch: 0, now: base.addingTimeInterval(701)), .iconOnly, "a privacy clear takes it away at once")
    }

    func testASqueezeFallsBackToTheIconOnlyAfterTheDebounce() {
        var auto = StatusAutoDisplay()
        XCTAssertEqual(auto.resolve(reading(12), squeezed: false, displayEpoch: 0, now: base), .number("12%"))
        XCTAssertEqual(auto.resolve(reading(12), squeezed: true, displayEpoch: 0, now: base.addingTimeInterval(1)), .number("12%"),
                       "the first look at a squeeze changes nothing")
        XCTAssertEqual(auto.pendingDeadline, base.addingTimeInterval(1 + StatusAutoDisplay.squeezeDebounce), "and asks to be looked at again")
        XCTAssertEqual(auto.resolve(reading(12), squeezed: true, displayEpoch: 0, now: base.addingTimeInterval(1.5)), .number("12%"))
        XCTAssertEqual(auto.resolve(reading(12), squeezed: true, displayEpoch: 0,
                                    now: base.addingTimeInterval(1 + StatusAutoDisplay.squeezeDebounce)), .iconOnly)
        XCTAssertEqual(auto.pendingDeadline, base.addingTimeInterval(1 + StatusAutoDisplay.squeezeDebounce + StatusAutoDisplay.retryWide))
    }

    func testAShortSqueezeNeverSwitches() {
        var auto = StatusAutoDisplay()
        _ = auto.resolve(reading(12), squeezed: true, displayEpoch: 0, now: base)
        XCTAssertEqual(auto.resolve(reading(12), squeezed: false, displayEpoch: 0, now: base.addingTimeInterval(0.5)), .number("12%"))
        XCTAssertEqual(auto.resolve(reading(12), squeezed: true, displayEpoch: 0, now: base.addingTimeInterval(1)), .number("12%"),
                       "the debounce restarts after a clear moment")
        XCTAssertEqual(auto.resolve(reading(12), squeezed: false, displayEpoch: 0, now: base.addingTimeInterval(1.5)), .number("12%"))
    }

    func testTheWideFormIsTriedAgainOnlyOnADisplayChangeOrAfterTenMinutes() {
        var auto = StatusAutoDisplay()
        _ = auto.resolve(reading(12), squeezed: true, displayEpoch: 0, now: base)
        XCTAssertEqual(auto.resolve(reading(12), squeezed: true, displayEpoch: 0, now: base.addingTimeInterval(1)), .iconOnly)
        // The icon now fits, but the number does not come back by itself.
        XCTAssertEqual(auto.resolve(reading(12), squeezed: false, displayEpoch: 0, now: base.addingTimeInterval(30)), .iconOnly)
        XCTAssertEqual(auto.resolve(reading(12), squeezed: false, displayEpoch: 0,
                                    now: base.addingTimeInterval(1 + StatusAutoDisplay.retryWide - 1)), .iconOnly)
        XCTAssertEqual(auto.resolve(reading(12), squeezed: false, displayEpoch: 0,
                                    now: base.addingTimeInterval(1 + StatusAutoDisplay.retryWide)), .number("12%"), "ten minutes later")
        // After the switch interval, a display change retries before the ten-minute fallback.
        var other = StatusAutoDisplay()
        _ = other.resolve(reading(12), squeezed: true, displayEpoch: 0, now: base)
        XCTAssertEqual(other.resolve(reading(12), squeezed: true, displayEpoch: 0, now: base.addingTimeInterval(1)), .iconOnly)
        XCTAssertEqual(other.resolve(reading(12), squeezed: false, displayEpoch: 1, now: base.addingTimeInterval(61)), .number("12%"))
    }

    func testAtMostOneSqueezeSwitchAMinute() {
        var auto = StatusAutoDisplay()
        _ = auto.resolve(reading(12), squeezed: true, displayEpoch: 0, now: base)
        XCTAssertEqual(auto.resolve(reading(12), squeezed: true, displayEpoch: 0, now: base.addingTimeInterval(1)), .iconOnly)
        let retry = base.addingTimeInterval(61)
        XCTAssertEqual(auto.resolve(reading(12), squeezed: true, displayEpoch: 1, now: base.addingTimeInterval(10)), .iconOnly)
        XCTAssertEqual(auto.pendingDeadline, retry)
        XCTAssertEqual(auto.resolve(reading(12), squeezed: true, displayEpoch: 1, now: base.addingTimeInterval(60.99)), .iconOnly)
        XCTAssertEqual(auto.resolve(reading(12), squeezed: true, displayEpoch: 1, now: retry), .number("12%"))
        XCTAssertEqual(auto.pendingDeadline, base.addingTimeInterval(121))
        XCTAssertEqual(auto.resolve(reading(12), squeezed: true, displayEpoch: 1, now: base.addingTimeInterval(120.99)), .number("12%"))
        XCTAssertEqual(auto.resolve(reading(12), squeezed: true, displayEpoch: 1, now: base.addingTimeInterval(121)), .iconOnly)
    }

    func testTheLabelIsCompleteInEveryState() {
        XCTAssertEqual(StatusAutoDisplay.accessibilityLabel(.init(name: "Codex", remaining: 0, shown: "0%", alertLine: 25)), "ModelPlan \u{00B7} Codex 0%")
        XCTAssertEqual(StatusAutoDisplay.accessibilityLabel(.init(name: "Claude", remaining: 80, shown: "80%", alertLine: 25)), "ModelPlan \u{00B7} Claude 80%",
                       "also when the item shows the icon only")
        XCTAssertEqual(StatusAutoDisplay.accessibilityLabel(nil), "ModelPlan")
        XCTAssertEqual(StatusAutoDisplay.compactLength, 42)
    }

    // ---- through the real application ----

    private func launch(weekly: Double, fiveHour: Double? = nil, display: MenuDisplay = .automatic) async throws -> (EngineDockMenuApplication, NSButton) {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("d377-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let fixture = try HostPairedProjectionTests.rows(weekly: weekly, fiveHour: fiveHour)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: fixture) }, activateSettings: {})
        addTeardownBlock { @MainActor in app.removeStatusItem(); await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        if display != .automatic { _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.menuDisplay(display)) }
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 42, height: 24))
        EngineDockMenuApplication.configureStatusButton(button, image: NSImage(size: .init(width: 16, height: 16)), barThickness: 22)
        return (app, button)
    }

    func testAFreshProfileShowsTheIconOnlyWhenTheQuotaIsHealthy() async throws {
        let (app, button) = try await launch(weekly: 60, fiveHour: 90)
        app.applyStatusContent(to: button, detail: "")
        XCTAssertEqual(button.title, "")
        XCTAssertEqual(button.imagePosition, .imageOnly)
        XCTAssertFalse(app.usedUpDotVisibleForTesting)
        XCTAssertEqual(button.accessibilityLabel(), "ModelPlan \u{00B7} Synthetic account 60%", "the label is complete although only the icon shows")
    }

    func testBelowTheAlertLineAFreshProfileShowsACompactNumberWithTheFullLabel() async throws {
        let (app, button) = try await launch(weekly: 15)
        app.applyStatusContent(to: button, detail: "")
        XCTAssertEqual(button.title, "15%")
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertFalse(app.usedUpDotVisibleForTesting)
        XCTAssertEqual(button.accessibilityLabel(), "ModelPlan \u{00B7} Synthetic account 15%")
        XCTAssertEqual(app.statusAutoMode, .number("15%"))
    }

    func testUsedUpShowsTheIconWithARedDotAndTheLabelSaysZero() async throws {
        let (app, button) = try await launch(weekly: 0)
        app.applyStatusContent(to: button, detail: "")
        XCTAssertEqual(button.title, "", "no number")
        XCTAssertEqual(button.imagePosition, .imageOnly)
        XCTAssertEqual(app.statusAutoMode, .usedUp)
        XCTAssertTrue(app.usedUpDotVisibleForTesting, "the red dot")
        XCTAssertEqual(button.accessibilityLabel(), "ModelPlan \u{00B7} Synthetic account 0%")
    }

    func testASqueezedItemFallsBackToTheIconOnlyAfterTheDebounce() async throws {
        let (app, button) = try await launch(weekly: 15)
        var armed: [(seconds: TimeInterval, fire: @MainActor () -> Void)] = []
        app.statusAutoSchedule = { seconds, fire in armed.append((seconds, fire)); return {} }
        var visible: Bool? = true
        app.statusItemVisibility = { visible }
        app.applyStatusContent(to: button, detail: "")
        XCTAssertEqual(button.title, "15%")
        visible = false
        app.checkStatusItemVisibility()
        app.applyStatusContent(to: button, detail: "")
        XCTAssertEqual(button.title, "15%", "the squeeze must last before the item changes")
        XCTAssertEqual(armed.last?.seconds ?? 0, StatusAutoDisplay.squeezeDebounce, accuracy: 0.05, "and it is looked at again after 750 ms")
        // The injected clock is the application's; make it pass the debounce.
        let later = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z")).addingTimeInterval(StatusAutoDisplay.squeezeDebounce + 1)
        app.composition.currentDate = { later }
        app.applyStatusContent(to: button, detail: "")
        XCTAssertEqual(button.title, "", "squeezed: the icon only")
        XCTAssertEqual(button.imagePosition, .imageOnly)
        XCTAssertEqual(button.accessibilityLabel(), "ModelPlan \u{00B7} Synthetic account 15%", "the label keeps the number")
    }

    func testAutomaticReadingExpiresOnItsScheduledCallback() async throws {
        let (app, _) = try await launch(weekly: 15)
        var now = app.composition.currentDate()
        app.composition.currentDate = { now }
        app.statusItemVisibility = { true }
        var armed: [(seconds: TimeInterval, fire: @MainActor () -> Void)] = []
        app.statusAutoSchedule = { seconds, fire in armed.append((seconds, fire)); return {} }
        app.installStatusItem()
        app.renderMenu()
        let button = try XCTUnwrap(app.statusButtonForTesting)
        XCTAssertEqual(button.title, "15%")

        app.composition.suspendDeadlines()
        app.renderMenu()
        XCTAssertEqual(button.title, "15%")
        let expiry = try XCTUnwrap(armed.last, "Automatic schedules the end of the reading hold")
        XCTAssertEqual(expiry.seconds, StatusTitleKeeper.holdLimit, accuracy: 0.001)

        now = now.addingTimeInterval(StatusTitleKeeper.holdLimit)
        expiry.fire()
        XCTAssertEqual(button.imagePosition, .imageOnly)
        XCTAssertEqual(button.title, "")
        XCTAssertEqual(button.accessibilityLabel(), "ModelPlan")
    }

    func testDisplayChangeSchedulesADeferredWideRetry() async throws {
        let (app, _) = try await launch(weekly: 12)
        let start = app.composition.currentDate()
        var now = start
        app.composition.currentDate = { now }
        var visible = true
        app.statusItemVisibility = { visible }
        app.displayRecheckSchedule = { _, _ in {} }
        var armed: [(seconds: TimeInterval, fire: @MainActor () -> Void)] = []
        app.statusAutoSchedule = { seconds, fire in armed.append((seconds, fire)); return {} }
        app.installStatusItem()
        app.renderMenu()
        let button = try XCTUnwrap(app.statusButtonForTesting)
        XCTAssertEqual(button.title, "12%")

        visible = false
        app.checkStatusItemVisibility()
        let debounce = try XCTUnwrap(armed.last)
        now = start.addingTimeInterval(1)
        debounce.fire()
        XCTAssertEqual(button.title, "")

        now = start.addingTimeInterval(10)
        app.displayParametersChanged()
        app.renderMenu()
        XCTAssertEqual(button.title, "", "the display change keeps the item narrow during the switch interval")
        let retry = try XCTUnwrap(armed.last)
        XCTAssertEqual(retry.seconds, 51, accuracy: 0.001)
        now = start.addingTimeInterval(60.99)
        app.renderMenu()
        XCTAssertEqual(button.title, "")

        now = start.addingTimeInterval(61)
        retry.fire()
        XCTAssertEqual(button.title, "12%", "the scheduled callback retries without another display change")
    }

    /// macrevc-1184-1: after a fallback, a recent visibility rewrite plus an unchanged-visibility display notification must
    /// still reach a render from the real settle and follow-up callbacks, so the one-minute retry replaces the ten-minute one.
    func testSettledDisplayChangeAfterARecentRewriteRearmsTheOneMinuteRetry() async throws {
        let (app, _) = try await launch(weekly: 12)
        let start = app.composition.currentDate()
        var now = start
        app.composition.currentDate = { now }
        var visible = true
        app.statusItemVisibility = { visible }
        var recheck: [(ms: UInt64, fire: @MainActor () -> Void)] = []
        app.displayRecheckSchedule = { ms, fire in recheck.append((ms, fire)); return {} }
        var armed: [(seconds: TimeInterval, fire: @MainActor () -> Void)] = []
        app.statusAutoSchedule = { seconds, fire in armed.append((seconds, fire)); return {} }
        app.installStatusItem()
        app.renderMenu()
        let button = try XCTUnwrap(app.statusButtonForTesting)
        XCTAssertEqual(button.title, "12%")

        visible = false
        app.checkStatusItemVisibility()
        let debounce = try XCTUnwrap(armed.last)
        now = start.addingTimeInterval(1)
        debounce.fire()
        XCTAssertEqual(button.title, "")
        XCTAssertEqual(armed.last?.seconds ?? 0, StatusAutoDisplay.retryWide, accuracy: 0.001, "the ordinary ten-minute deadline is armed")

        app.rewriteStatusContent()            // a visible-window occlusion notification just rewrote the item
        app.displayParametersChanged()        // visibility stays the same (hidden)
        let settle = try XCTUnwrap(recheck.last)
        XCTAssertEqual(settle.ms, DisplayChangeRecheck.settleMilliseconds)
        settle.fire()                         // throttled rewrite, unchanged visibility
        let followUp = try XCTUnwrap(recheck.last)
        XCTAssertEqual(followUp.ms, DisplayChangeRecheck.followUpMilliseconds)
        followUp.fire()

        let retry = try XCTUnwrap(armed.last)
        XCTAssertEqual(retry.seconds, 60, accuracy: 0.001, "the one-minute retry replaces the ten-minute deadline")
        XCTAssertEqual(button.title, "")
        now = start.addingTimeInterval(61)
        retry.fire()
        XCTAssertEqual(button.title, "12%", "the installed button widens at the retry")
    }

    func testNoticeReplacesTheUsedUpDotWhileTheMenuIsTracking() async throws {
        let (app, _) = try await launch(weekly: 0)
        app.installStatusItem()
        app.renderMenu()
        XCTAssertTrue(app.usedUpDotVisibleForTesting)

        let menu = try XCTUnwrap(app.liveStatusMenu)
        let delegate = try XCTUnwrap(menu.delegate)
        delegate.menuWillOpen?(menu)
        defer { delegate.menuDidClose?(menu) }
        app.renderMenu()
        XCTAssertTrue(app.statusRenderHeld)

        let now = app.composition.currentDate()
        var signal = DockSubscriptionSignal(id: "synthetic")
        signal.reset = .init(id: "reset", status: .announced, announcedAt: now)
        let notice = try XCTUnwrap(DockNoticeProjection.candidates(for: signal, at: now).first)
        let deliver = try XCTUnwrap(app.composition.dock.menuNoticeDidChange)
        deliver(notice, true)
        XCTAssertEqual(app.noticeIndicator.notice, notice)
        XCTAssertFalse(app.usedUpDotVisibleForTesting)
        XCTAssertTrue(app.statusRenderHeld)

        deliver(nil, false)
        XCTAssertNil(app.noticeIndicator.notice)
        XCTAssertTrue(app.usedUpDotVisibleForTesting)
        XCTAssertTrue(app.statusRenderHeld)
    }

    func testTheOtherDisplayChoicesAreUnchanged() async throws {
        let (app, button) = try await launch(weekly: 60, fiveHour: 90, display: .tightest)
        app.applyStatusContent(to: button, detail: "")
        XCTAssertEqual(button.title, "60%", "an explicit tightest choice still shows the number above the line")
        XCTAssertEqual(button.accessibilityLabel(), "ModelPlan 60%")
        XCTAssertEqual(app.statusAutoMode, .iconOnly)
    }
}
