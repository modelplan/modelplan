// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanSettings

final class FoundationSettingsMigrationTests: XCTestCase {
    typealias Migration = FoundationSettingsMigration
    func testExistingOrInvalidNewTargetNeverLoadsOrReplacesLegacy() throws {
        let cases: [Migration.TargetState] = [.present, .invalid(.invalidJSON), .invalid(.unsupportedSchema)]
        for target in cases {
            var legacyReads = 0
            let result = try Migration.prepare(product: .official, target: target, legacy: {
                legacyReads += 1
                return .init(officialSettings: .data(Data("not-json".utf8)))
            })
            XCTAssertEqual(legacyReads, 0, "An existing target must end legacy migration before any old-file read")
            switch (target, result) {
            case (.present, .keepExisting): break
            case (.invalid(let failure), .blocked(let fallback)):
                let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: fallback.document) as? [String: Any])
                let settings = try XCTUnwrap(document["settings"] as? [String: Any])
                XCTAssertEqual(settings["dockEdge"] as? String, "right")
                XCTAssertNil(settings["readerConsent"])
                XCTAssertEqual(fallback.issues, [.init(source: .newSettings, failure: failure)])
            default: XCTFail("Existing/corrupt new target must not yield a migration candidate")
            }
        }
    }
    func testInvalidLegacyEdgeUsesRightWithoutImportingTheLosingProfile() throws {
        let edges: [Any?] = [nil, "unrecognized-edge", 17, NSNull()]
        for edge in edges {
            let files = try FoundationSettingsMigrationFixture()
            var preferences: [String: Any] = ["theme": "night", "dockDisplayID": "synthetic-disconnected-display", "dockAlongFraction": 0.25]
            if let edge { preferences["dockEdge"] = edge }
            let primary = try files.input("official.json", object: ["schemaVersion": 1, "preferences": preferences])
            let secondary = try files.input("native.json", #"{"schemaVersion":1,"preferences":{"theme":"day","dockEdge":"bottom"}}"#)
            let result = try Migration.prepare(product: .official, target: .absent, legacy: {
                .init(officialSettings: primary, communitySettings: secondary)
            })
            guard case .create(let candidate) = result else { return XCTFail("Expected a candidate") }
            let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: candidate.document) as? [String: Any])
            let settings = try XCTUnwrap(document["settings"] as? [String: Any])
            XCTAssertEqual(settings["theme"] as? String, "night")
            XCTAssertEqual(settings["dockEdge"] as? String, "right")
            XCTAssertEqual(settings["dockDisplayID"] as? String, "synthetic-disconnected-display")
            XCTAssertEqual(settings["dockAlongFraction"] as? Double, 0.25)
            XCTAssertEqual(candidate.issues.contains(.init(source: .officialSettings, failure: .invalidEdge)), edge != nil)
            XCTAssertTrue(try files.originalsUnchanged())
        }
    }
    func testRowMappingMovesOrderHiddenAliasAndPinTogetherWhileKeepingUnmatchedIDs() throws {
        let files = try FoundationSettingsMigrationFixture()
        let input = try files.input("rows.json", #"{"schemaVersion":1,"preferences":{"subscriptions":{"order":["old.account","unmatched","old.hidden"],"hiddenIDs":["old.hidden","missing.hidden"]},"subscriptionSettings":{"old.account":{"alias":"Work","percentagePin":"week"},"missing.preference":{"alias":"Return","percentagePin":"5h"}}}}"#)
        let result = try Migration.prepare(product: .official, target: .absent,
            legacy: { .init(officialSettings: input) }, rowIDMap: ["old.account": "row.account", "old.hidden": "row.hidden"])
        guard case .create(let candidate) = result else { return XCTFail("Expected a candidate") }
        let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: candidate.document) as? [String: Any])
        let settings = try XCTUnwrap(document["settings"] as? [String: Any])
        let order = try XCTUnwrap(settings["subscriptions"] as? [String: Any])
        let overrides = try XCTUnwrap(settings["subscriptionSettings"] as? [String: [String: Any]])
        XCTAssertEqual(order["order"] as? [String], ["row.account", "unmatched", "row.hidden"])
        XCTAssertEqual(order["hiddenIDs"] as? [String], ["missing.hidden", "row.hidden"])
        XCTAssertNil(overrides["old.account"])
        XCTAssertEqual(overrides["row.account"]?["alias"] as? String, "Work")
        XCTAssertEqual(overrides["row.account"]?["percentagePin"] as? String, "week")
        XCTAssertEqual(overrides["missing.preference"]?["alias"] as? String, "Return")
        XCTAssertEqual(overrides["missing.preference"]?["percentagePin"] as? String, "5h")
        XCTAssertTrue(try files.originalsUnchanged())
    }
    func testAmbiguousOrInvalidRowMapKeepsOriginalPreferencesWithoutClobbering() throws {
        let maps = [["a": "same", "b": "same"], ["a": "b"], ["a": "b", "b": "c"], ["a": ""]]
        for map in maps {
            let files = try FoundationSettingsMigrationFixture()
            let input = try files.input("collision.json", #"{"schemaVersion":1,"preferences":{"subscriptions":{"order":["a","b","c"],"hiddenIDs":["a"]},"subscriptionSettings":{"a":{"alias":"Alpha","percentagePin":"week"},"b":{"alias":"Beta","percentagePin":"5h"},"c":{"alias":"Gamma","percentagePin":"auto"}}}}"#)
            let result = try Migration.prepare(product: .official, target: .absent,
                legacy: { .init(officialSettings: input) }, rowIDMap: map)
            guard case .create(let candidate) = result else { return XCTFail("Unsafe mapping must retain the original candidate") }
            let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: candidate.document) as? [String: Any])
            let settings = try XCTUnwrap(document["settings"] as? [String: Any])
            let rows = try XCTUnwrap(settings["subscriptions"] as? [String: Any])
            let overrides = try XCTUnwrap(settings["subscriptionSettings"] as? [String: [String: Any]])
            XCTAssertEqual(rows["order"] as? [String], ["a", "b", "c"])
            XCTAssertEqual(rows["hiddenIDs"] as? [String], ["a"])
            XCTAssertEqual(overrides["a"]?["alias"] as? String, "Alpha")
            XCTAssertEqual(overrides["b"]?["alias"] as? String, "Beta")
            XCTAssertEqual(overrides["c"]?["alias"] as? String, "Gamma")
            XCTAssertTrue(candidate.issues.contains(.init(source: .officialSettings, failure: .ambiguousRowMapping)))
            XCTAssertTrue(try files.originalsUnchanged())
        }
    }
    func testSourceFailuresFallBackAsAGroupAndCoreRecoversIndependently() throws {
        let failures: [(Migration.Input, Migration.Failure?)] = [
            (.absent, nil), (.failed(.unreadable), .unreadable),
            (.data(Data("not-json".utf8)), .invalidJSON),
            (.data(Data(#"{"schemaVersion":99,"preferences":{}}"#.utf8)), .unsupportedSchema),
            (.data(Data(repeating: 32, count: SettingsStore.maximumBytes + 1)), .tooLarge),
            (.data(Data(#"{"schemaVersion":1,"preferences":{"redBelow":17}}"#.utf8)), .invalidPreferences)]
        for (primary, failure) in failures {
            let files = try FoundationSettingsMigrationFixture()
            let secondary = try files.input("secondary.json", #"{"schemaVersion":1,"preferences":{"theme":"day","dockEdge":"left"}}"#)
            let result = try Migration.prepare(product: .official, target: .absent, legacy: {
                .init(officialSettings: primary, communitySettings: secondary, core: .failed(.unreadable))
            })
            guard case .create(let candidate) = result else { return XCTFail("Expected recovered candidate") }
            let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: candidate.document) as? [String: Any])
            let settings = try XCTUnwrap(document["settings"] as? [String: Any])
            let core = try XCTUnwrap(document["core"] as? [String: Any])
            XCTAssertEqual(settings["theme"] as? String, "day")
            XCTAssertEqual(settings["dockEdge"] as? String, "left")
            XCTAssertEqual(core["favouriteModelIDs"] as? [String], [])
            if let failure { XCTAssertTrue(candidate.issues.contains(.init(source: .officialSettings, failure: failure))) }
            else { XCTAssertFalse(candidate.issues.contains { $0.source == .officialSettings }) }
            XCTAssertTrue(candidate.issues.contains(.init(source: .communityCore, failure: .unreadable)))
            XCTAssertTrue(try files.originalsUnchanged())
        }
        let files = try FoundationSettingsMigrationFixture()
        let core = try files.input("core.json", #"{"schemaVersion":1,"localeIdentifier":"en-GB","favouriteModelIDs":["public.model"]}"#)
        let result = try Migration.prepare(product: .official, target: .absent, legacy: {
            .init(officialSettings: .failed(.unreadable), communitySettings: .failed(.unreadable), core: core)
        })
        guard case .create(let candidate) = result else { return XCTFail("Expected defaults plus surviving Core") }
        let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: candidate.document) as? [String: Any])
        let settings = try XCTUnwrap(document["settings"] as? [String: Any])
        XCTAssertEqual(settings["dockEdge"] as? String, "right")
        XCTAssertEqual(settings["openAtLogin"] as? Bool, true)
        XCTAssertEqual((document["core"] as? [String: Any])?["localeIdentifier"] as? String, "en-GB")
        XCTAssertEqual(candidate.issues.count, 2)
        XCTAssertTrue(try files.originalsUnchanged())
    }
    func testCommunityIdentityUsesTheSamePlannerWithItsOwnWholeGroupFirst() throws {
        let files = try FoundationSettingsMigrationFixture()
        let official = try files.input("official.json", #"{"schemaVersion":1,"preferences":{"theme":"night","size":"S","dockEdge":"left"}}"#)
        let native = try files.input("native.json", #"{"schemaVersion":1,"preferences":{"theme":"day","dockEdge":"bottom"}}"#)
        let result = try Migration.prepare(product: .community, target: .absent, legacy: {
            .init(officialSettings: official, communitySettings: native)
        })
        guard case .create(let candidate) = result else { return XCTFail("Expected candidate") }
        let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: candidate.document) as? [String: Any])
        let settings = try XCTUnwrap(document["settings"] as? [String: Any])
        XCTAssertEqual(settings["theme"] as? String, "day")
        XCTAssertEqual(settings["dockEdge"] as? String, "bottom")
        XCTAssertEqual(settings["size"] as? String, "M")
        XCTAssertTrue(try files.originalsUnchanged())
    }
    func testFreshDefaultsKeepLoginOnAndCreateOnlyTheTwoPreferenceSections() throws {
        let result = try Migration.prepare(product: .official, target: .absent, legacy: { .init() })
        guard case .create(let candidate) = result else { return XCTFail("Expected default candidate") }
        let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: candidate.document) as? [String: Any])
        XCTAssertEqual(Set(document.keys), ["schemaVersion", "settings", "core"])
        XCTAssertEqual(document["schemaVersion"] as? Int, 1)
        let settings = try XCTUnwrap(document["settings"] as? [String: Any])
        XCTAssertEqual(settings["dockEdge"] as? String, "right")
        XCTAssertEqual(settings["openAtLogin"] as? Bool, true)
        XCTAssertNil(settings["readerConsent"])
        XCTAssertNil(settings["dockDisplayID"])
        XCTAssertEqual(settings["dockAlongFraction"] as? Double, 0.5)
        XCTAssertTrue(candidate.issues.isEmpty)
    }
    func testAllSettingsChoicesRoundTripWithoutReaderConsentOrUnknownData() throws {
        var original = SettingsPreferences()
        original.theme = .night; original.size = .large; original.motion = .on; original.transparency = .on
        original.percentageMode = .used; original.showPercentages = false; original.redBelow = 10; original.sliverAlert = false
        original.showDock = false; original.autoHide = false; original.revealMilliseconds = 300; original.magnification = .strong
        original.showOverFullscreen = true; original.followActiveDisplay = true
        original.dockEdge = .left; original.dockDisplayID = "synthetic-offline-uuid"; original.dockAlongFraction = 0.25
        original.openAtLogin = false; original.automaticUpdates = false; original.menuDisplay = .twoWindows
        original.openShortcut = .init("Q", modifiers: [.command, .option]); original.dockShortcut = .init("R", modifiers: [.control, .shift])
        original.language = .english; original.opening = .quick; original.beatMilliseconds = 150; original.showProjectNames = false
        original.notifications.optedIn = true; original.notifications.kinds = [.reset, .stale]
        original.subscriptions = .init(order: ["known", "missing"], hiddenIDs: ["missing"])
        original.subscriptionSettings = ["missing": .init(alias: "Retain", percentagePin: .week)]
        original.helpHints = .init(seen: [.drag], opens: 2, reveals: 1); original.onboarding.next()
        original.readerConsent.gemini = true; original.readerConsent.cursor = true
        var values = try XCTUnwrap(try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        values["accessToken"] = "DO_NOT_EXPORT_CANARY"
        let files = try FoundationSettingsMigrationFixture()
        let input = try files.input("all-settings.json", object: ["schemaVersion": 1, "preferences": values])
        _ = try files.input("untouched-engine-consent.json", #"{"generation":42,"privacy":"off"}"#)
        let result = try Migration.prepare(product: .official, target: .absent, legacy: { .init(officialSettings: input) })
        guard case .create(let candidate) = result else { return XCTFail("Expected candidate") }
        let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: candidate.document) as? [String: Any])
        let settings = try XCTUnwrap(document["settings"] as? [String: Any])
        let expectedKeys: Set<String> = ["theme", "size", "motion", "transparency", "percentageMode", "showPercentages", "redBelow", "sliverAlert", "showDock", "autoHide", "revealMilliseconds", "magnification", "showOverFullscreen", "followActiveDisplay", "dockEdge", "dockDisplayID", "dockAlongFraction", "openAtLogin", "automaticUpdates", "menuDisplay", "openShortcut", "dockShortcut", "language", "opening", "beatMilliseconds", "showProjectNames", "notifications", "subscriptions", "subscriptionSettings", "onboarding", "helpHints"]
        XCTAssertEqual(Set(settings.keys), expectedKeys)
        XCTAssertFalse(String(decoding: candidate.document, as: UTF8.self).contains("DO_NOT_EXPORT_CANARY"))
        let restored = try JSONDecoder().decode(SettingsPreferences.self, from: JSONSerialization.data(withJSONObject: settings))
        XCTAssertEqual(restored.theme, .night); XCTAssertEqual(restored.size, .large)
        XCTAssertEqual(restored.motion, .on); XCTAssertEqual(restored.transparency, .on)
        XCTAssertEqual(restored.percentageMode, .used); XCTAssertFalse(restored.showPercentages)
        XCTAssertEqual(restored.redBelow, 10); XCTAssertFalse(restored.sliverAlert)
        XCTAssertFalse(restored.showDock); XCTAssertFalse(restored.autoHide)
        XCTAssertEqual(restored.revealMilliseconds, 300); XCTAssertEqual(restored.magnification, .strong)
        XCTAssertTrue(restored.showOverFullscreen); XCTAssertTrue(restored.followActiveDisplay)
        XCTAssertEqual(restored.dockEdge, .left); XCTAssertEqual(restored.dockDisplayID, "synthetic-offline-uuid")
        XCTAssertEqual(restored.dockAlongFraction, 0.25); XCTAssertFalse(restored.openAtLogin); XCTAssertFalse(restored.automaticUpdates)
        XCTAssertEqual(restored.menuDisplay, .twoWindows)
        XCTAssertEqual(restored.openShortcut, .init("Q", modifiers: [.command, .option]))
        XCTAssertEqual(restored.dockShortcut, .init("R", modifiers: [.control, .shift]))
        XCTAssertEqual(restored.language, .english); XCTAssertEqual(restored.opening, .quick)
        XCTAssertEqual(restored.beatMilliseconds, 150); XCTAssertFalse(restored.showProjectNames)
        XCTAssertTrue(restored.notifications.optedIn); XCTAssertEqual(restored.notifications.kinds, [.reset, .stale])
        XCTAssertEqual(restored.subscriptions.order, ["known", "missing"]); XCTAssertEqual(restored.subscriptions.hiddenIDs, ["missing"])
        XCTAssertEqual(restored.subscriptionSettings["missing"], .init(alias: "Retain", percentagePin: .week))
        XCTAssertEqual(restored.helpHints, .init(seen: [.drag], opens: 2, reveals: 1)); XCTAssertTrue(restored.onboarding.completed)
        XCTAssertFalse(restored.readerConsent.gemini); XCTAssertFalse(restored.readerConsent.cursor)
        XCTAssertTrue(try files.originalsUnchanged())
    }
    func testUnsupportedSourceSchemaIsIdentifiedBeforeItsBodyAndCoreSyntaxStaysDistinct() throws {
        let result = try Migration.prepare(product: .official, target: .absent, legacy: {
            .init(officialSettings: .data(Data(#"{"schemaVersion":99}"#.utf8)),
                  core: .data(Data(#"{"schemaVersion":99}"#.utf8)))
        })
        guard case .create(let candidate) = result else { return XCTFail("Expected safe defaults with issues") }
        XCTAssertTrue(candidate.issues.contains(.init(source: .officialSettings, failure: .unsupportedSchema)))
        XCTAssertTrue(candidate.issues.contains(.init(source: .communityCore, failure: .unsupportedSchema)))
        let badCore = try Migration.prepare(product: .official, target: .absent, legacy: {
            .init(core: .data(Data("not-json".utf8)))
        })
        guard case .create(let fallback) = badCore else { return XCTFail("Expected safe Core fallback") }
        XCTAssertEqual(fallback.issues, [.init(source: .communityCore, failure: .invalidJSON)])
    }
    func testUnambiguousRowCycleRetainsBothAliasesRatherThanTreatingItAsAClobber() throws {
        let files = try FoundationSettingsMigrationFixture()
        let input = try files.input("cycle.json", #"{"schemaVersion":1,"preferences":{"subscriptions":{"order":["a","b"],"hiddenIDs":["a"]},"subscriptionSettings":{"a":{"alias":"Alpha","percentagePin":"week"},"b":{"alias":"Beta","percentagePin":"5h"}}}}"#)
        let result = try Migration.prepare(product: .official, target: .absent,
            legacy: { .init(officialSettings: input) }, rowIDMap: ["a": "b", "b": "a"])
        guard case .create(let candidate) = result else { return XCTFail("Expected cycle candidate") }
        let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: candidate.document) as? [String: Any])
        let settings = try XCTUnwrap(document["settings"] as? [String: Any])
        let rows = try XCTUnwrap(settings["subscriptions"] as? [String: Any])
        let overrides = try XCTUnwrap(settings["subscriptionSettings"] as? [String: [String: Any]])
        XCTAssertEqual(rows["order"] as? [String], ["b", "a"])
        XCTAssertEqual(rows["hiddenIDs"] as? [String], ["b"])
        XCTAssertEqual(overrides["b"]?["alias"] as? String, "Alpha")
        XCTAssertEqual(overrides["a"]?["alias"] as? String, "Beta")
        XCTAssertTrue(candidate.issues.isEmpty)
        XCTAssertTrue(try files.originalsUnchanged())
    }
    func testOfficialCoexistenceKeepsOneWholeSettingsGroupAndIndependentCore() throws {
        let files = try FoundationSettingsMigrationFixture()
        let official = try files.input("official.json", #"{"schemaVersion":1,"preferences":{"theme":"night","dockEdge":"left","openAtLogin":false}}"#)
        let community = try files.input("community.json", #"{"schemaVersion":1,"preferences":{"theme":"day","size":"S","dockEdge":"bottom"}}"#)
        let core = try files.input("core.json", #"{"schemaVersion":1,"localeIdentifier":"en-GB","favouriteModelIDs":["public.alpha","public.beta"],"fieldPickerValue":"AQID"}"#)
        let result = try Migration.prepare(product: .official, target: .absent, legacy: {
            .init(officialSettings: official, communitySettings: community, core: core)
        })
        guard case .create(let candidate) = result else { return XCTFail("Expected a candidate, not a write") }
        let document = try XCTUnwrap(try JSONSerialization.jsonObject(with: candidate.document) as? [String: Any])
        let settings = try XCTUnwrap(document["settings"] as? [String: Any])
        let values = try XCTUnwrap(document["core"] as? [String: Any])
        XCTAssertEqual(settings["theme"] as? String, "night")
        XCTAssertEqual(settings["dockEdge"] as? String, "left")
        XCTAssertEqual(settings["size"] as? String, "M")
        XCTAssertEqual(settings["openAtLogin"] as? Bool, false)
        XCTAssertEqual(values["localeIdentifier"] as? String, "en-GB")
        XCTAssertEqual(values["favouriteModelIDs"] as? [String], ["public.alpha", "public.beta"])
        XCTAssertEqual(values["fieldPickerValue"] as? String, "AQID")
        XCTAssertNil(settings["readerConsent"])
        XCTAssertTrue(try files.originalsUnchanged())
    }
}
