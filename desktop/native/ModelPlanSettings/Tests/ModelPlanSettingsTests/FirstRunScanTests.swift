// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanWire
@testable import ModelPlanSettings

/// First run v1 (owner OK 2026-11-12, D216): the page lists tools from a local presence check at once, then
/// shows each tool's own step; Done waits for the reader's handshake; a slow tool never blocks the rest.
@MainActor final class FirstRunScanTests: XCTestCase {
    final class Clock { var now = Date(timeIntervalSince1970: 1_000_000); func advance(_ s: Double) { now = now.addingTimeInterval(s) } }

    private func makeEntry(clock: Clock) -> ScopeConsentEntry {
        let entry = ScopeConsentEntry(client: ScopeConsentTestClient(), ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic", expectGeneration: 1, consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        entry.controller.clock = { clock.now }
        return entry
    }
    private func texts(_ root: NSView) -> [String] {
        ([(root as? NSTextField)?.stringValue, (root as? NSButton)?.title].compactMap { $0 }) + root.subviews.flatMap(texts)
    }
    private func identifiers(_ root: NSView) -> [String] { [root.accessibilityIdentifier()] + root.subviews.flatMap(identifiers) }

    // MARK: presence check (E2)

    func testPresenceFindsToolsByFolderOrCommandInCatalogueOrder() {
        let present: Set<String> = ["/Users/x/.codex", "/opt/homebrew/bin/claude", "/Users/x/Library/Application Support/ZCode"]
        let detector = FirstRunPresenceDetector(home: "/Users/x", searchDirectories: ["/usr/bin", "/opt/homebrew/bin"]) { present.contains($0) }
        XCTAssertEqual(detector.detect(), ["claude", "codex", "zai"], "reader order, not discovery order")
        XCTAssertEqual(FirstRunPresenceDetector(home: "/Users/x", searchDirectories: []) { _ in false }.detect(), [])
    }
    func testPresenceTableMatchesTheReadersBundledDetectorList() throws {
        // One list, not two (coverage.md E2): every Go fallback entry has the same commands and folders here.
        var root = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent()
        while root.path != "/", !FileManager.default.fileExists(atPath: root.appendingPathComponent("cli/internal/detect/catalogue.go").path) { root.deleteLastPathComponent() }
        let source = try String(contentsOf: root.appendingPathComponent("cli/internal/detect/catalogue.go"), encoding: .utf8)
        let pattern = try NSRegularExpression(pattern: #"\{"([a-z]+)", "[^"]+", "([a-z-]+)", "([^"]+)"\}"#)
        let matches = pattern.matches(in: source, range: NSRange(source.startIndex..., in: source))
        XCTAssertEqual(matches.count, FirstRunPresenceCatalogue.tools.count)
        for match in matches {
            func group(_ i: Int) -> String { String(source[Range(match.range(at: i), in: source)!]) }
            let tool = try XCTUnwrap(FirstRunPresenceCatalogue.tools.first { $0.id == group(1) }, group(1))
            XCTAssertTrue(tool.commands.contains(group(2)), group(1))
            XCTAssertTrue(tool.paths.contains(group(3)), group(1))
        }
        XCTAssertEqual(FirstRunPresenceCatalogue.tools.map(\.id), matches.map { String(source[Range($0.range(at: 1), in: source)!]) })
    }

    // MARK: per-tool states, honest count, timeout (E3)

    func testRowsAreListedFromPresenceBeforeTheReaderAnswersAndDoneWaits() throws {
        let clock = Clock(), controller = makeEntry(clock: clock).controller
        XCTAssertEqual(controller.firstRunToolStatus("codex"), .finding, "nothing is claimed before the local check")
        XCTAssertFalse(controller.firstRunPresenceDone)
        controller.setFirstRunPresence(["codex", "zai"])
        XCTAssertEqual(controller.firstRunListTools.map(\.tool), ["codex", "zai"])
        XCTAssertEqual(controller.firstRunToolStatus("codex"), .waitingForEngine)
        XCTAssertEqual(controller.firstRunProgress.total, 2)
        XCTAssertEqual(controller.firstRunProgress.done, 0)
        XCTAssertEqual(controller.firstRunDoneBlock, .engineStarting)
        XCTAssertFalse(controller.firstRunCanFinish, "owner 11-12 answer 3: Done is off until the reader answers")
        XCTAssertFalse(controller.firstRunNotFound.contains("codex"))
        XCTAssertTrue(controller.firstRunNotFound.contains("cursor"))
    }
    func testReaderWaitShowsSecondsThenFailureAndDoneOpensAtTheHandshake() throws {
        let clock = Clock(), controller = makeEntry(clock: clock).controller
        controller.setFirstRunPresence(["gemini"])
        XCTAssertTrue(controller.beginFirstRunDraft())
        XCTAssertEqual(controller.firstRunEngine, .starting)
        clock.advance(4); XCTAssertEqual(controller.firstRunEngine, .waiting(4), "past the 3 s target the page says how long")
        clock.advance(20); XCTAssertEqual(controller.firstRunEngine, .slow(24))
        controller.setFirstRunEngineFailed(true)
        XCTAssertEqual(controller.firstRunEngine, .failed); XCTAssertEqual(controller.firstRunDoneBlock, .engineFailed)
        XCTAssertTrue(controller.firstRunScanSettled, "a failed start ends the scan so nothing else waits on it")
        controller.setFirstRunEngineFailed(false)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        XCTAssertEqual(controller.firstRunEngine, .ready)
        XCTAssertNil(controller.firstRunDoneBlock)
        XCTAssertTrue(controller.firstRunCanFinish)
    }
    func testASlowToolTimesOutAfterFifteenSecondsWithoutBlockingTheOthers() throws {
        let clock = Clock(), controller = makeEntry(clock: clock).controller
        controller.setFirstRunPresence(["gemini", "cursor"])
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        XCTAssertEqual(controller.firstRunToolStatus("gemini"), .reading(0))
        XCTAssertEqual(controller.firstRunProgress.done, 0)
        controller.setRowForTesting("cursor", state: .fresh, readings: [.init(kind: .fiveHour, percent: 63)])
        XCTAssertEqual(controller.firstRunToolStatus("cursor"), .read)
        XCTAssertEqual(controller.firstRunProgress.done, 1, "honest count: one of two has a result")
        clock.advance(6)
        XCTAssertEqual(controller.firstRunToolStatus("gemini"), .slowReading(6))
        XCTAssertFalse(controller.firstRunScanSettled)
        XCTAssertTrue(controller.firstRunCanFinish, "a slow tool does not hold Done")
        clock.advance(10)
        XCTAssertEqual(controller.firstRunToolStatus("gemini"), .couldNotRead)
        XCTAssertEqual(controller.firstRunProgress.done, 2)
        XCTAssertTrue(controller.firstRunScanSettled)
        XCTAssertTrue(controller.isFirstRunToolChosen("gemini"), "the tick stays; it is retried in the background")
        // Try again restarts that row's 15 seconds and tells the host which tool.
        var retried: [String] = []
        controller.onRetryTool = { retried.append($0) }
        controller.retryFirstRunTool("gemini")
        XCTAssertEqual(retried, ["gemini"])
        XCTAssertEqual(controller.firstRunToolStatus("gemini"), .reading(0))
    }
    func testNoToolsKeepsDoneEnabledOnceTheReaderAnswered() throws {
        let clock = Clock(), controller = makeEntry(clock: clock).controller
        controller.setFirstRunPresence([])
        XCTAssertTrue(controller.firstRunListTools.isEmpty)
        XCTAssertEqual(controller.firstRunDoneBlock, .engineStarting)
        controller.receiveAcceptedFacts(try WireConsentFacts(consentTextVersion: 17, scopes: []))
        XCTAssertNil(controller.firstRunDoneBlock, "FR-9-05: no dead end when nothing is found")
        XCTAssertTrue(controller.firstRunScanSettled)
    }

    // MARK: the page

    func testPageShowsPresenceRowsReasonAndCountWhileTheReaderStarts() async throws {
        let clock = Clock(), entry = makeEntry(clock: clock)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("first-run-scan-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let editor = SettingsEditor(store: try SettingsStore(url: directory.appendingPathComponent("preferences.json")))
        let page = SettingsFirstRunController(editor: editor, scopeConsentEntry: entry)
        page.presence = FirstRunPresenceDetector(home: "/h", searchDirectories: []) { $0 == "/h/.codex" }
        var closedBeforeDone = 0
        page.onClosedBeforeDone = { closedBeforeDone += 1 }
        await page.prepare()
        let root = try XCTUnwrap(page.window?.contentView)
        XCTAssertTrue(identifiers(root).contains("scope.firstRun.row.codex"), "the row exists before the reader answers")
        XCTAssertFalse(identifiers(root).contains("scope.firstRun.row.claude"))
        XCTAssertTrue(identifiers(root).contains("scope.firstRun.engine"))
        XCTAssertFalse(page.doneButton.isEnabled)
        XCTAssertFalse(page.doneReason.isHidden, "the reason is shown")
        XCTAssertTrue([FirstRunCopy.needEngine.english, FirstRunCopy.needEngine.chinese].contains(page.doneReason.stringValue))
        XCTAssertTrue(texts(root).contains { $0.hasPrefix("Not on this Mac:") || $0.hasPrefix("本机没找到：") })
        // The reader answers: rows come from it, Done opens.
        entry.controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        XCTAssertTrue(page.doneButton.isEnabled)
        XCTAssertTrue(page.doneReason.isHidden)
        // Closing the window mid-scan is not Done: nothing is committed and the host is told.
        page.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        XCTAssertEqual(closedBeforeDone, 1)
        XCTAssertEqual(editor.snapshot?.preferences.onboarding.completed, false)
        XCTAssertEqual(entry.controller.phase.isIdleForTesting, true, "no grant was sent")
    }

    // MARK: copy

    func testHistoryImportLineNamesProjectFolderNamesAndThisMacOnly() {
        // HIST-IMP-10 (coverage.md: the #881 copy was missing this).
        XCTAssertTrue(FirstRunCopy.smallPrint.english.contains("project folder names"))
        XCTAssertTrue(FirstRunCopy.smallPrint.english.contains("kept on this Mac"))
        XCTAssertTrue(FirstRunCopy.smallPrint.chinese.contains("项目文件夹名"))
        XCTAssertTrue(FirstRunCopy.smallPrint.chinese.contains("只存在本机"))
    }
}

private extension ScopeConsentPhase {
    var isIdleForTesting: Bool { if case .idle = self { return true } else { return false } }
}
