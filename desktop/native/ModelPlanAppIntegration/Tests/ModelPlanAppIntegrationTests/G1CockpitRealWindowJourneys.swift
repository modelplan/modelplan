// SPDX-License-Identifier: MIT
#if DEBUG
import AppKit
import CryptoKit
import XCTest
import WebKit
import ModelPlanCockpitWeb
import ModelPlanEngineClient
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// Synthetic engine only; the normal Factory, verified bundle and WK page remain real.
private actor G1CockpitEngine: EngineClient {
    let consumer: any EngineClientEventConsumer
    let data: WireCockpitData
    let context = EngineDeliveryContext(sessionID: "s-00000000-0000-4000-8000-000000000001", floor: .init(storeEpoch: "g1-synthetic", generation: 1), revision: 1)
    init(consumer: any EngineClientEventConsumer, data: WireCockpitData) { self.consumer = consumer; self.data = data }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { context.storeEpochForG1 == "g1-synthetic" }
    func start() async throws -> EngineDeliveryContext { await consumer.consume(.connection(.ready(context))); return context }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g1-rows")) }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion {
        let id = WireRequestID.string(UUID().uuidString)
        let envelope = try WireEnvelope(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: context.floor.generation, data: data)
        await consumer.consume(.response(requestID: id, .cockpit(.init(envelope: envelope, delivery: context))))
        return .init(requestID: id)
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ query: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
private extension EngineDeliveryContext {
    var storeEpochForG1: String { floor.storeEpoch }
}

@MainActor final class G1CockpitRealWindowJourneys: XCTestCase {
    private func withLivePage(language: SettingsLanguage = .english, syntheticAccountCount: Int = 1, monthlyUnknown: Bool? = nil, durationKnown: Bool? = nil, generalScopedFixture: Bool = false, thresholdFixture: Bool = false, criticalAlert: Bool = false, creditBalance: Double? = nil, todaySourceCount: Int? = nil, reduceMotion: Bool = false, runningSession: Bool = false, _ exercise: @MainActor (EngineDockMenuApplication, EngineCockpitCoordinator, CockpitWindowController) async throws -> Void) async throws {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_COCKPIT_BUNDLE_DIR"], !path.isEmpty else {
            throw XCTSkip("NOT RUN: MODELPLAN_COCKPIT_BUNDLE_DIR is not supplied by the GUI CI job")
        }
        let source = URL(fileURLWithPath: path, isDirectory: true)
        let pin = try XCTUnwrap(CommunityCockpitApplicationFactory.manifestPins["community"])
        _ = try VerifiedCockpitBundle(root: source, manifestSHA256: pin, allowOfficial: false)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-cockpit-" + UUID().uuidString)
        let bundle = root.appendingPathComponent("Synthetic.app"), resources = bundle.appendingPathComponent("Contents/Resources"), helpers = bundle.appendingPathComponent("Contents/Helpers")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: resources.appendingPathComponent("Cockpit"))
        let helper = Data("g1-synthetic-not-executable".utf8)
        let digest = SHA256.hash(data: helper).map { String(format: "%02x", $0) }.joined()
        try helper.write(to: helpers.appendingPathComponent("modelplan"))
        try Data(digest.utf8).write(to: resources.appendingPathComponent("modelplan.sha256"))
        let info: [String: Any] = ["ModelPlanPublicSource": String(repeating: "a", count: 40), "ModelPlanHelperVersion": CommunityConsentBundleIdentity.version,
            "ModelPlanBundledHelperSHA256": digest, "ModelPlanSourceHelperSHA256ByArchitecture": CommunityConsentBundleIdentity.sourceSHA256ByArchitecture]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: bundle.appendingPathComponent("Contents/Info.plist"))
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../..").standardizedFileURL
        let capture = try Data(contentsOf: repo.appendingPathComponent("schema/app-cli/captures/WireCockpitData.json"))
        guard syntheticAccountCount == 1 || syntheticAccountCount == 2 else { throw CockpitBridgeError.unavailable }
        var fixture = try XCTUnwrap(JSONSerialization.jsonObject(with: capture) as? [String: Any])
        if syntheticAccountCount == 2 {
            var projection = try XCTUnwrap(fixture["projection"] as? [String: Any])
            var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
            var accounts = try XCTUnwrap(rows.first?["accounts"] as? [[String: Any]])
            var second = try XCTUnwrap(accounts.first)
            second["subscriptionRef"] = NSNull()
            second["accountLocator"] = NSNull()
            accounts.append(second)
            rows[0]["accounts"] = accounts
            projection["rows"] = rows
            fixture["projection"] = projection
        }
        if monthlyUnknown != nil || durationKnown != nil {
            let unknown = monthlyUnknown ?? false
            var projection = try XCTUnwrap(fixture["projection"] as? [String: Any])
            var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
            var accounts = try XCTUnwrap(rows.first?["accounts"] as? [[String: Any]])
            var windows = try XCTUnwrap(accounts.first?["windows"] as? [[String: Any]])
            var month = try XCTUnwrap(windows.first)
            month["id"] = "monthly:2592000:main:main"
            month["role"] = "monthly"
            if durationKnown == false {
                month["durationSeconds"] = NSNull()
                month["id"] = "monthly:unknown:main:main"
            } else { month["durationSeconds"] = 2592000 }
            if durationKnown != nil { month["resetsAt"] = "2099-01-01T00:00:00Z" }
            month["limitKey"] = "main"
            month["poolKey"] = "main"
            month.removeValue(forKey: "modelScope")
            month["label"] = ["en": "Monthly", "zh": "每月"]
            if unknown { month["remainingPercent"] = NSNull() } else { month["remainingPercent"] = 42 }
            month["current"] = true
            month["validUntil"] = "2099-01-01T00:00:00Z"
            windows = [month]
            accounts[0]["windows"] = windows
            rows[0]["accounts"] = accounts
            projection["rows"] = rows
            fixture["projection"] = projection
        }
        if generalScopedFixture || thresholdFixture {
            var projection = try XCTUnwrap(fixture["projection"] as? [String: Any])
            var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
            var accounts = try XCTUnwrap(rows.first?["accounts"] as? [[String: Any]])
            let seed = try XCTUnwrap((accounts.first?["windows"] as? [[String: Any]])?.first)
            func window(_ role: String, _ seconds: Int, _ percent: Int, _ pool: String, scoped: Bool) -> [String: Any] {
                var value = seed
                value["id"] = "\(role):\(seconds):\(pool):\(pool)"
                value["role"] = role
                value["durationSeconds"] = seconds
                value["limitKey"] = pool
                value["poolKey"] = pool
                if !scoped { value.removeValue(forKey: "modelScope") }
                value["remainingPercent"] = percent
                value["current"] = true
                value["validUntil"] = "2099-01-01T00:00:00Z"
                return value
            }
            if thresholdFixture {
                accounts[0]["windows"] = [window("session", 18000, 41, "main", scoped: false),
                                          window("weekly", 604800, 26, "main", scoped: false),
                                          window("monthly", 2592000, 25, "main", scoped: true)]
            } else {
                accounts[0]["windows"] = [window("session", 18000, 75, "main", scoped: false),
                                          window("weekly", 604800, 70, "main", scoped: false),
                                          window("monthly", 2592000, 20, "main", scoped: true),
                                          window("monthly", 2592000, 10, "code_review", scoped: false)]
            }
            rows[0]["accounts"] = accounts
            projection["rows"] = rows
            fixture["projection"] = projection
        }
        if criticalAlert {
            guard thresholdFixture else { throw CockpitBridgeError.unavailable }
            var details = try XCTUnwrap(fixture["details"] as? [String: Any])
            details["alerts"] = [["source": "codex", "subscriptionRef": "0123456789abcdef",
                                  "windowId": "monthly:2592000:main:main", "severity": "critical", "remainingPercent": 25]]
            fixture["details"] = details
        }
        if let balance = creditBalance {
            var details = try XCTUnwrap(fixture["details"] as? [String: Any])
            var subscriptions = try XCTUnwrap(details["subscriptions"] as? [[String: Any]])
            var credits = try XCTUnwrap(subscriptions.first?["credits"] as? [String: Any])
            credits["balance"] = balance
            subscriptions[0]["credits"] = credits
            details["subscriptions"] = subscriptions
            fixture["details"] = details
        }
        if let count = todaySourceCount {
            guard count == 1 || count == 2 else { throw CockpitBridgeError.unavailable }
            var details = try XCTUnwrap(fixture["details"] as? [String: Any])
            var subscriptions = try XCTUnwrap(details["subscriptions"] as? [[String: Any]])
            let first: [String: Any] = ["source": "synthetic-a", "observedOutputTokens": 1240,
                                        "generationTps": 62, "bindingBasis": "source-wide-current-binding"]
            let second: [String: Any] = ["source": "synthetic-b", "observedOutputTokens": 800,
                                         "generationTps": 40, "bindingBasis": "source-wide-current-binding"]
            subscriptions[0]["today"] = count == 1 ? [first] : [first, second]
            details["subscriptions"] = subscriptions
            fixture["details"] = details
        }
        if runningSession {
            var details = try XCTUnwrap(fixture["details"] as? [String: Any])
            var sessions = try XCTUnwrap(details["sessions"] as? [[String: Any]])
            sessions[0]["source"] = "codex"
            sessions[0]["model"] = "synthetic"
            sessions[0]["state"] = "running"
            details["sessions"] = sessions
            details["sessionCoverage"] = "local-last-seen"
            fixture["details"] = details
        }
        let data = try JSONDecoder().decode(WireCockpitData.self, from: JSONSerialization.data(withJSONObject: fixture))
        let settings = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        _ = try await settings.update { $0.language = language; if reduceMotion { $0.motion = .on } }
        let configuration = EngineClientConfiguration(executableURL: helpers.appendingPathComponent("modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        var fanout: CockpitStoreFanout?
        let app = CommunityCockpitApplicationFactory.makeForChecks(configuration: configuration, settingsStore: settings, bundleURL: bundle, createsNativePanels: false, cockpitEntryEnabled: true) { _, consumer in
            fanout = consumer as? CockpitStoreFanout
            return G1CockpitEngine(consumer: consumer, data: data)
        }
        addTeardownBlock { @MainActor in
            fanout?.cockpit.close()
            await app.composition.stop()
            try? FileManager.default.removeItem(at: root)
        }
        _ = NSApplication.shared
        await app.prepare()
        await app.composition.start()
        let coordinator = try XCTUnwrap(fanout?.cockpit)
        XCTAssertNil(coordinator.g1LivePageForChecks, "No cockpit page is prewarmed before the normal opening action")
        app.showConsole()
        let limit = ContinuousClock.now.advanced(by: .seconds(10))
        while coordinator.g1LivePageForChecks?.g1PageStateForChecks.ready != true && ContinuousClock.now < limit {
            try await Task.sleep(for: .milliseconds(20))
        }
        let page = try XCTUnwrap(coordinator.g1LivePageForChecks)
        try await exercise(app, coordinator, page)
        await page.g1CloseAndWaitForTeardown()
    }
    private func geometry(_ page: CockpitWindowController) async throws -> [String: Any] {
        let observation = try await page.g1PageGeometryForChecks()
        let raw = try XCTUnwrap(observation)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    }
    private func dimension(_ facts: [String: Any], _ element: String, _ axis: String) throws -> Double {
        let rect = try XCTUnwrap(facts[element] as? [String: Any], "Missing actual element: " + element)
        return try XCTUnwrap((rect[axis] as? NSNumber)?.doubleValue)
    }
    #if MODELPLAN_TEST_ONLY_SPI
    func testC17NormalEntryHelpReadbackIsBoundedAndRetires() async throws {
        for language: SettingsLanguage in [.english, .chinese] {
            try await withLivePage(language: language) { _, _, page in
                let web = try XCTUnwrap(page.verificationWebView)
                let initial = try await page.g1HelpCaptionFactsForChecks()
                let before = try XCTUnwrap(initial)
                let hidden = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(before.utf8)) as? [String: Any])
                XCTAssertEqual(hidden["open"] as? Bool, false)
                for attached in [true, false] {
                    if !attached {
                        _ = try await web.evaluateJavaScript("document.querySelector('[data-detach]')?.click()")
                        for _ in 0..<100 where page.verificationShellState?.attached != false {
                            try await Task.sleep(for: .milliseconds(20))
                        }
                    }
                    XCTAssertEqual(page.verificationShellState?.attached, attached)
                    _ = try await web.evaluateJavaScript("window.dispatchEvent(new KeyboardEvent('keydown',{key:'Alt'}))")
                    var facts: [String: Any] = [:]
                    for _ in 0..<100 {
                        if let raw = try await page.g1HelpCaptionFactsForChecks(),
                           let value = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
                           value["open"] as? Bool == true { facts = value; break }
                        try await Task.sleep(for: .milliseconds(20))
                    }
                    XCTAssertEqual(facts["open"] as? Bool, true)
                    let key = language == .english ? "matchesEnglish" : "matchesChinese"
                    for target in ["window", "alert", "record"] {
                        let caption = try XCTUnwrap(facts[target] as? [String: Any])
                        XCTAssertEqual(caption["count"] as? Int, 1, target)
                        XCTAssertEqual(caption[key] as? Bool, true, target)
                        XCTAssertEqual(caption["visible"] as? Bool, true, target)
                        let clipped = try XCTUnwrap(caption["clippedRect"] as? [String: Any])
                        for axis in ["x", "y", "width", "height"] {
                            let value = try XCTUnwrap((clipped[axis] as? NSNumber)?.doubleValue)
                            XCTAssertTrue(value.isFinite && value >= 0, target + "." + axis)
                        }
                    }
                    XCTExpectFailure("C-17 product-missing: narrow Help captions overlap or exceed the viewport") {
                        XCTAssertEqual(facts["allInsideAndSeparate"] as? Bool, true)
                    }
                    _ = try await web.evaluateJavaScript("window.dispatchEvent(new KeyboardEvent('keyup',{key:'Alt'}))")
                    let closedRaw = try await page.g1HelpCaptionFactsForChecks()
                    let closed = try XCTUnwrap(closedRaw)
                    let closedFacts = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(closed.utf8)) as? [String: Any])
                    XCTAssertEqual(closedFacts["open"] as? Bool, false)
                }
                await page.g1CloseAndWaitForTeardown()
                let retired = try await page.g1HelpCaptionFactsForChecks()
                XCTAssertNil(retired, "A retired page must not return observations")
            }
        }
    }
    #endif

    #if MODELPLAN_TEST_ONLY_SPI
    func testG1_CKP_ENG_02_oneAndTwoMembersKeepThreeSlots() async throws {
        for count in [1, 2] {
            try await withLivePage(syntheticAccountCount: count) { _, _, page in
                let web = try XCTUnwrap(page.verificationWebView)
                let script = """
                (() => {
                  const keys = document.querySelector('.eng-keys');
                  if (!keys) return null;
                  return JSON.stringify({slots: keys.dataset.slots,
                    members: keys.querySelectorAll('.ek[data-sub]').length,
                    empty: keys.querySelectorAll('.ek.ek-bay').length,
                    columns: document.querySelectorAll('.eng-cols > .ec').length});
                })()
                """
                let deadline = ContinuousClock.now.advanced(by: .seconds(10))
                var facts: [String: Any]?
                while ContinuousClock.now < deadline {
                    if let raw = try await web.evaluateJavaScript(script) as? String,
                       let object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
                       (object["members"] as? NSNumber)?.intValue == count {
                        facts = object
                        break
                    }
                    try await Task.sleep(for: .milliseconds(20))
                }
                let observed = try XCTUnwrap(facts, "The normal entry did not render the synthetic members")
                XCTAssertEqual(observed["slots"] as? String, "3")
                XCTAssertEqual((observed["members"] as? NSNumber)?.intValue, count)
                XCTAssertEqual((observed["empty"] as? NSNumber)?.intValue, 3 - count)
                XCTAssertEqual((observed["columns"] as? NSNumber)?.intValue, 3)
            }
        }
    }
    #endif

    #if MODELPLAN_TEST_ONLY_SPI
    func testG1_CKP_ENG_07_monthOnlyKeepsBlankAndUnknownDistinct() async throws {
        for unknown in [false, true] {
            try await withLivePage(monthlyUnknown: unknown) { _, _, page in
                let web = try XCTUnwrap(page.verificationWebView)
                let script = """
                (() => {
                  const column = document.querySelector('.eng-cols > .ec[data-col]');
                  if (!column) return null;
                  const first = column.querySelector('.qcell[data-row="first"]');
                  const second = column.querySelector('.qcell[data-row="second"]');
                  const other = column.querySelector('.qcell[data-row="other"]');
                  return JSON.stringify({firstBlank: !!first && first.classList.contains('none'),
                    secondBlank: !!second && second.classList.contains('none'),
                    otherExists: !!other && !other.classList.contains('none'),
                    otherValue: other?.querySelector('.qvalue')?.textContent ?? null,
                    otherTag: other?.getAttribute('data-tag') ?? null});
                })()
                """
                let deadline = ContinuousClock.now.advanced(by: .seconds(10))
                var facts: [String: Any]?
                while ContinuousClock.now < deadline {
                    if let raw = try await web.evaluateJavaScript(script) as? String,
                       let object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
                       object["otherExists"] as? Bool == true {
                        facts = object
                        break
                    }
                    try await Task.sleep(for: .milliseconds(20))
                }
                let observed = try XCTUnwrap(facts, "The normal entry did not render the monthly window")
                XCTAssertEqual(observed["firstBlank"] as? Bool, true)
                XCTAssertEqual(observed["secondBlank"] as? Bool, true)
                XCTAssertEqual(observed["otherExists"] as? Bool, true)
                XCTAssertEqual(observed["otherValue"] as? String, unknown ? "--" : "42")
                XCTAssertTrue((observed["otherTag"] as? String)?.contains("mo") == true)
            }
        }
    }
    #endif

    #if MODELPLAN_TEST_ONLY_SPI
    func testG1_CKP_ENG_06_generalAndOtherWindowsThroughNormalEntry() async throws {
        try await withLivePage(generalScopedFixture: true) { _, _, page in
            let web = try XCTUnwrap(page.verificationWebView)
            let script = """
            (() => {
              const column = document.querySelector('.eng-cols > .ec[data-col]');
              if (!column) return null;
              const cell = row => column.querySelector('.qcell[data-row="' + row + '"]');
              return JSON.stringify({first:cell('first')?.querySelector('.qvalue')?.textContent ?? null,
                second:cell('second')?.querySelector('.qvalue')?.textContent ?? null,
                other:cell('other')?.querySelector('.qvalue')?.textContent ?? null,
                more:cell('other')?.getAttribute('data-more') ?? null});
            })()
            """
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            var facts: [String: Any]?
            while ContinuousClock.now < deadline {
                if let raw = try await web.evaluateJavaScript(script) as? String,
                   let object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
                   object["first"] as? String == "75" {
                    facts = object
                    break
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            let observed = try XCTUnwrap(facts, "The normal entry did not render the synthetic general windows")
            XCTAssertEqual(observed["first"] as? String, "75")
            XCTAssertEqual(observed["second"] as? String, "70")
            XCTAssertEqual(observed["other"] as? String, "10")
            XCTAssertEqual(observed["more"] as? String, "1")
        }
    }
    #endif

    #if MODELPLAN_TEST_ONLY_SPI
    func testG1_CKP_ENG_09_reportedCreditFormattingThroughNormalEntry() async throws {
        for (balance, expected) in [(0.0, "0"), (0.5, "<1"), (1234.5, "1,235")] {
            try await withLivePage(creditBalance: balance) { _, _, page in
                let web = try XCTUnwrap(page.verificationWebView)
                let script = "document.querySelector('.eng-cols > .ec[data-col] .qrv-p')?.textContent ?? null"
                let deadline = ContinuousClock.now.advanced(by: .seconds(10))
                var text: String?
                while ContinuousClock.now < deadline {
                    if let value = try await web.evaluateJavaScript(script) as? String {
                        text = value
                        break
                    }
                    try await Task.sleep(for: .milliseconds(20))
                }
                XCTAssertEqual(text, expected, "Only the reported synthetic balance should appear, without a unit or abbreviation")
            }
        }
    }
    #endif

    func testG1_CKP_ENG_14_defaultThresholdColorsThroughNormalEntry() async throws {
        try await withLivePage(thresholdFixture: true) { _, _, page in
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            var colours: [G1QuotaStatusColour]?
            while ContinuousClock.now < deadline {
                if let observed = try await page.g1QuotaStatusColoursForChecks(memberKey: "0123456789abcdef"), observed.count == 3 {
                    colours = observed
                    break
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            let observed = try XCTUnwrap(colours, "The normal entry did not render all three synthetic quota rows")
            let byRow = Dictionary(uniqueKeysWithValues: observed.map { ($0.row, $0) })
            XCTAssertEqual(byRow["first"]?.fillColour, "rgb(90, 217, 186)", "41 is healthy")
            XCTAssertEqual(byRow["second"]?.fillColour, "rgb(234, 193, 123)", "26 is above the default threshold and at most 40")
            XCTAssertEqual(byRow["other"]?.fillColour, "rgb(239, 68, 68)", "25 is critical at the default threshold")
        }
    }

    #if MODELPLAN_TEST_ONLY_SPI
    func testG1_CKP_ENG_08_todayOnlyDoesNotInventAnAverage() async throws {
        for count in [1, 2] {
            try await withLivePage(todaySourceCount: count) { _, _, page in
                let web = try XCTUnwrap(page.verificationWebView)
                let script = """
                (() => {
                  const row = document.querySelector('.eng-cols > .ec[data-col] .qrow-t');
                  if (!row) return null;
                  return JSON.stringify({tokens:row.querySelector('.qtokens')?.textContent ?? null,
                    average:row.querySelector('.qaverage')?.textContent ?? null});
                })()
                """
                let deadline = ContinuousClock.now.advanced(by: .seconds(10))
                var facts: [String: Any]?
                while ContinuousClock.now < deadline {
                    if let raw = try await web.evaluateJavaScript(script) as? String,
                       let object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any] {
                        facts = object
                        if count == 2 || object["average"] as? String == "62 t/s" { break }
                    }
                    try await Task.sleep(for: .milliseconds(20))
                }
                let observed = try XCTUnwrap(facts, "The normal entry did not render the synthetic Today row")
                if count == 1 {
                    XCTAssertEqual(observed["tokens"] as? String, "1k")
                    XCTAssertEqual(observed["average"] as? String, "62 t/s")
                } else {
                    XCTAssertTrue(observed["tokens"] is NSNull, "Unmergeable source totals must stay unknown")
                    XCTAssertTrue(observed["average"] is NSNull, "Do not borrow or invent a multi-source average")
                }
            }
        }
    }
    #endif

    #if MODELPLAN_TEST_ONLY_SPI
    func testG1_CKP_ENG_12_timeDotsRequireKnownDuration() async throws {
        for known in [true, false] {
            try await withLivePage(durationKnown: known) { _, _, page in
                let web = try XCTUnwrap(page.verificationWebView)
                let script = """
                (() => {
                  const cell = document.querySelector('.eng-cols > .ec[data-col] .qcell[data-row="other"]');
                  if (!cell || !cell.querySelector('.qbar')) return null;
                  const bar = cell.querySelector('.qbar');
                  return JSON.stringify({segments:bar.querySelectorAll('i').length,
                    barWidth:bar.getBoundingClientRect().width,
                    dots:cell.querySelectorAll('.qtime i').length,
                    lit:cell.querySelectorAll('.qtime i.on').length});
                })()
                """
                let deadline = ContinuousClock.now.advanced(by: .seconds(10))
                var facts: [String: Any]?
                while ContinuousClock.now < deadline {
                    if let raw = try await web.evaluateJavaScript(script) as? String,
                       let object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any] {
                        facts = object
                        break
                    }
                    try await Task.sleep(for: .milliseconds(20))
                }
                let observed = try XCTUnwrap(facts, "The normal entry did not render the synthetic monthly bar")
                XCTAssertEqual((observed["segments"] as? NSNumber)?.intValue, 10)
                XCTAssertGreaterThan((observed["barWidth"] as? NSNumber)?.doubleValue ?? 0, 0)
                if known {
                    XCTAssertEqual((observed["dots"] as? NSNumber)?.intValue, 10)
                    XCTAssertGreaterThanOrEqual((observed["lit"] as? NSNumber)?.intValue ?? 0, 1)
                } else {
                    XCTExpectFailure("CKP-ENG-12: monthly duration is guessed when the producer supplies no duration") {
                        XCTAssertEqual((observed["dots"] as? NSNumber)?.intValue, 0)
                    }
                }
            }
        }
    }
    #endif

    #if MODELPLAN_TEST_ONLY_SPI
    func testG1_CKP_ENG_10_lcdFontAndStatusInkThroughNormalEntry() async throws {
        try await withLivePage(thresholdFixture: true) { _, _, page in
            let web = try XCTUnwrap(page.verificationWebView)
            let script = """
            (() => {
              const column = document.querySelector('.eng-cols > .ec[data-col]');
              if (!column) return null;
              const cell = row => column.querySelector('.qcell[data-row="' + row + '"]');
              const number = row => cell(row)?.querySelector('.qnum');
              const lit = row => cell(row)?.querySelector('.qbar i.on');
              if (!number('first') || !number('second') || !number('other') || !lit('first')) return null;
              return JSON.stringify({family:getComputedStyle(number('first')).fontFamily,
                fontLoaded:Array.from(document.fonts).some(face => face.family.replace(/["']/g, '') === 'JetBrains Mono' && face.status === 'loaded'),
                normal:getComputedStyle(number('first')).color,
                healthyBar:getComputedStyle(lit('first')).backgroundColor,
                middle:getComputedStyle(number('second')).color,
                low:getComputedStyle(number('other')).color});
            })()
            """
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            var facts: [String: Any]?
            while ContinuousClock.now < deadline {
                if let raw = try await web.evaluateJavaScript(script) as? String,
                   let object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any] {
                    facts = object
                    break
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            let observed = try XCTUnwrap(facts, "The normal entry did not render the synthetic quota numerals")
            XCTAssertTrue((observed["family"] as? String)?.contains("JetBrains Mono") == true)
            XCTAssertNotEqual(observed["normal"] as? String, observed["healthyBar"] as? String, "Healthy numbers stay neutral while bars use status colour")
            XCTAssertEqual(observed["middle"] as? String, "rgb(234, 193, 123)")
            XCTAssertEqual(observed["low"] as? String, "rgb(239, 68, 68)")
            XCTExpectFailure("CKP-ENG-10: the community bundle does not register the required font face") {
                XCTAssertEqual(observed["fontLoaded"] as? Bool, true)
            }
        }
    }
    #endif

    #if MODELPLAN_TEST_ONLY_SPI
    func testG1_CKP_ENG_11_alertWashAndBlankCellsThroughNormalEntry() async throws {
        try await withLivePage(thresholdFixture: true, criticalAlert: true) { _, _, page in
            let web = try XCTUnwrap(page.verificationWebView)
            let script = """
            (() => {
              const column = document.querySelector('.eng-cols > .ec[data-col]');
              if (!column || column.querySelectorAll('.qcell[data-row]').length !== 3) return null;
              const cells = Array.from(column.querySelectorAll('.qcell[data-row]'));
              return JSON.stringify({tint:column.classList.contains('tint-red'),
                background:getComputedStyle(column).backgroundColor,
                icons:column.querySelectorAll('.qcell img, .qcell svg, .qcell .icon').length,
                forbidden:cells.some(cell => /[▲!]/.test(cell.textContent ?? '')),
                hatch:cells.some(cell => getComputedStyle(cell).backgroundImage !== 'none')});
            })()
            """
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            var facts: [String: Any]?
            while ContinuousClock.now < deadline {
                if let raw = try await web.evaluateJavaScript(script) as? String,
                   let object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any] {
                    facts = object
                    break
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            let observed = try XCTUnwrap(facts, "The normal entry did not render the synthetic alert column")
            XCTAssertEqual(observed["tint"] as? Bool, true)
            XCTAssertNotEqual(observed["background"] as? String, "rgba(0, 0, 0, 0)")
            XCTAssertEqual((observed["icons"] as? NSNumber)?.intValue, 0)
            XCTAssertEqual(observed["forbidden"] as? Bool, false)
            XCTAssertEqual(observed["hatch"] as? Bool, false)
        }
        try await withLivePage(monthlyUnknown: false) { _, _, page in
            let web = try XCTUnwrap(page.verificationWebView)
            let script = """
            (() => {
              const column = document.querySelector('.eng-cols > .ec[data-col]');
              if (!column) return null;
              const empty = row => column.querySelector('.qcell[data-row="' + row + '"]');
              const first = empty('first'), second = empty('second');
              if (!first || !second) return null;
              return first.classList.contains('none') && second.classList.contains('none') &&
                first.textContent.trim() === '' && second.textContent.trim() === '';
            })()
            """
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            var isBlank: Bool?
            while ContinuousClock.now < deadline {
                if let value = try await web.evaluateJavaScript(script) as? Bool { isBlank = value; break }
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertEqual(isBlank, true, "Missing 5h and weekly windows must remain empty")
        }
    }
    #endif

    #if MODELPLAN_TEST_ONLY_SPI
    func testG1_CKP_MOT_03_reduceMotionKeepsGeometryAndStopsRunningCursor() async throws {
        var baseline: (Double, Double)?
        for reduced in [false, true] {
            try await withLivePage(reduceMotion: reduced, runningSession: true) { _, _, page in
                let web = try XCTUnwrap(page.verificationWebView)
                let script = """
                (() => {
                  const root = document.querySelector('#cockpit');
                  const cursor = document.querySelector('.ck-tape .t-cur');
                  if (!root || !cursor) return null;
                  const r = root.getBoundingClientRect();
                  return JSON.stringify({width:r.width, height:r.height,
                    reduced:document.documentElement.dataset.reduceMotion === 'true',
                    cursorAnimation:getComputedStyle(cursor).animationName});
                })()
                """
                let deadline = ContinuousClock.now.advanced(by: .seconds(10))
                var facts: [String: Any]?
                while ContinuousClock.now < deadline {
                    if let raw = try await web.evaluateJavaScript(script) as? String,
                       let object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
                       !reduced || object["reduced"] as? Bool == true {
                        facts = object
                        break
                    }
                    try await Task.sleep(for: .milliseconds(20))
                }
                let observed = try XCTUnwrap(facts, "The normal entry did not render the synthetic running session")
                let width = try XCTUnwrap((observed["width"] as? NSNumber)?.doubleValue)
                let height = try XCTUnwrap((observed["height"] as? NSNumber)?.doubleValue)
                if reduced {
                    let previous = try XCTUnwrap(baseline)
                    XCTAssertEqual(width, previous.0, accuracy: 1)
                    XCTAssertEqual(height, previous.1, accuracy: 1)
                    XCTAssertEqual(observed["cursorAnimation"] as? String, "none")
                    XCTAssertEqual(page.g1OpenAnimationDurationForChecks, 0)
                } else { baseline = (width, height) }
            }
        }
    }
    #endif

    func testG1_CKP_ENT_01_actualFadeAndOutline() async throws {
        try await withLivePage { _, _, page in
            let facts = try await self.geometry(page)
            let duration = try XCTUnwrap(page.g1OpenAnimationDurationForChecks)
            let reduce = facts["reduceMotion"] as? Bool == true
            XCTAssertEqual(duration, reduce ? 0 : 0.18, accuracy: 0.001)
            XCTAssertEqual(facts["rootOutline"] as? String, "none")
        }
    }
    func testG1_CKP_ENT_02_actualRootHasNoClipPath() async throws {
        try await withLivePage { _, _, page in
            let facts = try await self.geometry(page)
            XCTAssertEqual(facts["rootClipPath"] as? String, "none")
            XCTAssertEqual(facts["rootOpacity"] as? String, "1")
        }
    }
    func testG1_CKP_SHELL_18() async throws {
        try await withLivePage { _, _, page in
            XCTAssertTrue(page.g1PageStateForChecks.hasWindow)
            XCTAssertTrue(page.g1PageStateForChecks.hasPage)
            XCTAssertTrue(page.g1PageStateForChecks.ready)
            let facts = try await self.geometry(page)
            XCTAssertNotNil(facts["root"], "The real verified page must expose its cockpit root")
        }
    }
    func testG1_CKP_SHELL_12_baseReserve() async throws {
        try await withLivePage { _, _, page in
            let facts = try await self.geometry(page)
            let rootHeight = try self.dimension(facts, "root", "height")
            let contentHeight = try XCTUnwrap(page.window?.contentView?.bounds.height)
            XCTAssertEqual(Double(contentHeight) - rootHeight, 34, accuracy: 1)
        }
    }
    func testG1_CKP_ENTRY_01_menuAndDockRoutes() async throws {
        try await withLivePage { app, coordinator, initial in
            @MainActor func waitRetired(_ page: CockpitWindowController) async throws {
                let deadline = ContinuousClock.now.advanced(by: .seconds(3))
                while !page.g1PageStateForChecks.disposed && ContinuousClock.now < deadline {
                    try await Task.sleep(for: .milliseconds(20))
                }
                let disposed = page.g1PageStateForChecks.disposed
                XCTAssertTrue(disposed)
            }
            @MainActor func waitNewPage(_ previous: CockpitWindowController) async throws -> CockpitWindowController {
                let deadline = ContinuousClock.now.advanced(by: .seconds(10))
                while ContinuousClock.now < deadline {
                    if let current = coordinator.g1LivePageForChecks, current !== previous, current.g1PageStateForChecks.ready { return current }
                    try await Task.sleep(for: .milliseconds(20))
                }
                throw CockpitBridgeError.unavailable
            }
            initial.requestClose(); try await waitRetired(initial)
            app.composition.dock.setPresentationAllowed(true)
            app.renderMenu()
            let status = try XCTUnwrap(app.liveStatusMenu)
            let statusIndex = try XCTUnwrap(status.items.firstIndex { $0.title == "Open Cockpit" })
            status.performActionForItem(at: statusIndex)
            let fromMenu = try await waitNewPage(initial)
            XCTAssertTrue(fromMenu.g1PageStateForChecks.hasWindow)
            fromMenu.requestClose(); try await waitRetired(fromMenu)
            let dock = app.composition.dock.menu()
            let dockIndex = try XCTUnwrap(dock.items.firstIndex { $0.title == "Open Cockpit" })
            dock.performActionForItem(at: dockIndex)
            let fromDock = try await waitNewPage(fromMenu)
            XCTAssertTrue(fromDock.g1PageStateForChecks.hasWindow)
            XCTAssertTrue(initial.g1PageStateForChecks.disposed)
        }
    }
    func testG1_CKP_SHELL_24_closeControlUsesNonblockingFade() async throws {
        try await withLivePage { _, _, page in
            let facts = try await self.geometry(page)
            let close = try XCTUnwrap(facts["close"] as? [String: Any])
            let x = try XCTUnwrap((close["x"] as? NSNumber)?.doubleValue)
            let y = try XCTUnwrap((close["y"] as? NSNumber)?.doubleValue)
            let width = try XCTUnwrap((close["width"] as? NSNumber)?.doubleValue)
            let height = try XCTUnwrap((close["height"] as? NSNumber)?.doubleValue)
            let window = try XCTUnwrap(page.window)
            let web = try XCTUnwrap(window.contentView?.subviews.first { $0 is WKWebView } as? WKWebView)
            let local = web.convert(CGPoint(x: x + width / 2, y: web.isFlipped ? y + height / 2 : web.bounds.height - y - height / 2), to: nil)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: local, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
                window.sendEvent(event)
            }
            let deadline = ContinuousClock.now.advanced(by: .seconds(3))
            while page.g1CloseAnimationDurationForChecks == nil && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            let duration = try XCTUnwrap(page.g1CloseAnimationDurationForChecks)
            let reduce = facts["reduceMotion"] as? Bool == true
            XCTAssertEqual(duration, reduce ? 0 : 0.12, accuracy: 0.001)
            while !page.g1PageStateForChecks.disposed && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertTrue(page.g1PageStateForChecks.disposed)
        }
    }
    func testG1_CKP_SHELL_20_closeRetiresActualPage() async throws {
        try await withLivePage { app, coordinator, page in
            page.requestClose()
            let closeLimit = ContinuousClock.now.advanced(by: .seconds(3))
            while !page.g1PageStateForChecks.disposed && ContinuousClock.now < closeLimit {
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertTrue(page.g1PageStateForChecks.disposed)
            XCTAssertFalse(page.g1PageStateForChecks.hasPage)
            XCTAssertFalse(page.g1PageStateForChecks.hasWindow)
            XCTAssertNil(coordinator.g1LivePageForChecks)
            app.showConsole()
            let reopenLimit = ContinuousClock.now.advanced(by: .seconds(10))
            while coordinator.g1LivePageForChecks?.g1PageStateForChecks.ready != true && ContinuousClock.now < reopenLimit {
                try await Task.sleep(for: .milliseconds(20))
            }
            let reopened = try XCTUnwrap(coordinator.g1LivePageForChecks)
            XCTAssertFalse(reopened === page, "Reopen must construct a new actual page after disposal")
            XCTAssertTrue(reopened.g1PageStateForChecks.ready)
            XCTAssertTrue(reopened.g1PageStateForChecks.hasWindow)
            XCTAssertTrue(page.g1PageStateForChecks.disposed, "The retired page must not revive")
        }
    }
}
#endif
