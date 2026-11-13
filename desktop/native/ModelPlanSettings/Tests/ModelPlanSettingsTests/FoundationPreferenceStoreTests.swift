// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

@MainActor final class FoundationPreferenceStoreTests: XCTestCase {
    typealias File = FoundationPreferenceFile
    private final class Fixture {
        let root: URL
        let location: FoundationPreferenceLocation
        var originals: [URL: Data] = [:]
        init(_ product: FoundationSettingsMigration.ProductIdentity = .official) throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("foundation-store-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            location = try .init(applicationSupport: root, product: product)
        }
        deinit { try? FileManager.default.removeItem(at: root) }
        func legacy(_ path: String, _ text: String) throws {
            let url = location.directory.appendingPathComponent(path), data = Data(text.utf8)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url); originals[url] = data
        }
        func unchanged() throws { for (url, bytes) in originals { XCTAssertEqual(try Data(contentsOf: url), bytes) } }
        func noStages() throws { XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: location.directory.path).contains { $0.hasSuffix(".tmp") }) }
    }
    private func document(theme: SettingsTheme = .night, edge: SettingsDockEdge = .left,
                          core: FoundationCorePreferences = .init()) throws -> Data {
        var preferences = SettingsPreferences(); preferences.theme = theme; preferences.dockEdge = edge
        return try File.Document(settings: preferences, core: core).encoded()
    }
    func testCoexistingLegacyFilesSelectSettingsAsOneGroupAndCoreIndependently() async throws {
        for product in [FoundationSettingsMigration.ProductIdentity.official, .community] {
            let f = try Fixture(product)
            try f.legacy("Beta07/settings-v1.json", #"{"schemaVersion":1,"preferences":{"theme":"night","dockEdge":"left","openAtLogin":false,"subscriptions":{"order":["old","unmatched"],"hiddenIDs":["unmatched"]},"readerConsent":{"gemini":true}}}"#)
            try f.legacy("Native/settings-v1.json", #"{"schemaVersion":1,"preferences":{"theme":"day","dockEdge":"bottom"}}"#)
            try f.legacy("Native/community-v1.json", #"{"schemaVersion":1,"localeIdentifier":"en","favouriteModelIDs":["synthetic-model"],"fieldPickerValue":"AQID"}"#)
            let store = try SettingsStore(foundationAt: f.root, product: product, rowIDMap: ["old": "new-row"])
            let snapshot = await store.snapshot(), loadedCore = await store.coreSnapshot()
            let core = try XCTUnwrap(loadedCore)
            let loadedStatus = await store.foundationStatus()
            let status = try XCTUnwrap(loadedStatus)
            XCTAssertEqual(snapshot.preferences.theme, product == .official ? .night : .day)
            XCTAssertEqual(snapshot.preferences.dockEdge, product == .official ? .left : .bottom)
            if product == .official {
                XCTAssertFalse(snapshot.preferences.openAtLogin)
                XCTAssertEqual(snapshot.preferences.subscriptions.order, ["new-row", "unmatched"])
            } else { XCTAssertTrue(snapshot.preferences.openAtLogin) }
            XCTAssertEqual(snapshot.preferences.readerConsent, ReaderConsent())
            XCTAssertEqual(core, .init(localeIdentifier: "en", favouriteModelIDs: ["synthetic-model"], fieldPickerValue: Data([1,2,3])))
            XCTAssertTrue(status.createdByMigration); XCTAssertFalse(status.readOnlyRecovery)
            XCTAssertEqual(status.path, f.location.target)
            XCTAssertEqual(status.selection?.settings, product == .official ? .officialSettings : .communitySettings)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: f.location.target)) as? [String: Any])
            XCTAssertNil((object["settings"] as? [String: Any])?["readerConsent"]); XCTAssertNil(object["preferences"])
            try f.unchanged(); try f.noStages()
        }
    }
    func testCorruptOfficialFallsBackAsGroupAndCoreFailureIsReported() async throws {
        let f = try Fixture()
        try f.legacy("Beta07/settings-v1.json", "not-json")
        try f.legacy("Native/settings-v1.json", #"{"schemaVersion":1,"preferences":{"theme":"day","dockEdge":"left"}}"#)
        try f.legacy("Native/community-v1.json", "not-json")
        let store = try SettingsStore(foundationAt: f.root, product: .official)
        let snapshot = await store.snapshot(), loadedStatus = await store.foundationStatus()
        let status = try XCTUnwrap(loadedStatus)
        XCTAssertEqual(snapshot.preferences.theme, .day); XCTAssertEqual(snapshot.preferences.dockEdge, .left)
        XCTAssertEqual(status.selection?.settings, .communitySettings); XCTAssertEqual(status.selection?.core, .defaults)
        XCTAssertEqual(Set(status.issues.map(\.source)), [.officialSettings, .communityCore])
        try f.unchanged()
    }
    func testFreshDefaultsPublishCompletePrivateFile() async throws {
        let f = try Fixture(), store = try SettingsStore(foundationAt: f.root, product: .community)
        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.preferences.dockEdge, .right); XCTAssertTrue(snapshot.preferences.openAtLogin)
        XCTAssertEqual(try File.Document.decode(Data(contentsOf: f.location.target)).core, .init())
        let mode = try FileManager.default.attributesOfItem(atPath: f.location.target.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(mode?.intValue, 0o600); try f.noStages()
    }
    func testExistingTargetSkipsLegacyAndIsNotRewrittenOnLoad() throws {
        let f = try Fixture()
        try f.legacy("Beta07/settings-v1.json", "bad-legacy")
        let bytes = try document(); try bytes.write(to: f.location.target)
        var reads = 0
        let opened = try File.open(f.location, hooks: .init(onLegacyRead: { _ in reads += 1 }))
        XCTAssertEqual(reads, 0); XCTAssertFalse(opened.status.createdByMigration)
        XCTAssertEqual(opened.document.settings.theme, .night)
        XCTAssertEqual(try Data(contentsOf: f.location.target), bytes); try f.unchanged()
    }
    func testInvalidNewTargetUsesReadOnlyRightDefaultsWithoutLegacyReadsOrReplacement() async throws {
        for bytes in [Data("bad-json".utf8), Data(#"{"schemaVersion":99,"settings":{},"core":{}}"#.utf8), Data(repeating: 32, count: File.maximumBytes + 1)] {
            let f = try Fixture(); try f.legacy("Beta07/settings-v1.json", #"{"schemaVersion":1,"preferences":{"dockEdge":"left"}}"#)
            try bytes.write(to: f.location.target)
            var reads = 0
            let opened = try File.open(f.location, hooks: .init(onLegacyRead: { _ in reads += 1 }))
            XCTAssertEqual(reads, 0); XCTAssertTrue(opened.status.readOnlyRecovery)
            let store = try SettingsStore(foundationAt: f.root, product: .official)
            let snapshot = await store.snapshot(); XCTAssertEqual(snapshot.preferences.dockEdge, .right)
            do { try await store.update { $0.theme = .day }; XCTFail("corrupt target must stay read-only") }
            catch { XCTAssertEqual(error as? FoundationPreferenceError, .recoveryRequired) }
            XCTAssertEqual(try Data(contentsOf: f.location.target), bytes); try f.unchanged()
        }
    }
    func testPublicationRaceKeepsWinnerWithoutPartialOrOverwrite() throws {
        let f = try Fixture(); try f.legacy("Beta07/settings-v1.json", #"{"schemaVersion":1,"preferences":{"theme":"day"}}"#)
        let winner = try document(theme: .night, core: .init(favouriteModelIDs: ["winner"]))
        let opened = try File.open(f.location, hooks: .init(beforePublish: {
            try winner.write(to: f.location.target, options: .withoutOverwriting)
        }))
        XCTAssertEqual(try Data(contentsOf: f.location.target), winner)
        XCTAssertFalse(opened.status.createdByMigration); XCTAssertEqual(opened.document.core.favouriteModelIDs, ["winner"])
        try f.unchanged(); try f.noStages()
    }
    func testFailureBeforePublishLeavesNoTargetAndRemovesOnlyOwnStage() throws {
        enum Injected: Error { case stop }
        let f = try Fixture(); try f.legacy("Beta07/settings-v1.json", #"{"schemaVersion":1,"preferences":{}}"#)
        XCTAssertThrowsError(try File.open(f.location, hooks: .init(beforePublish: { throw Injected.stop })))
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.location.target.path))
        try f.unchanged(); try f.noStages()
    }
    func testCompetingBootstrapFailsBusyWithoutWaitingOrOverwriting() throws {
        let f = try Fixture(); var busy = false
        let opened = try File.open(f.location, hooks: .init(beforePublish: {
            do { _ = try File.open(f.location); XCTFail("second bootstrap must not enter the writer transaction") }
            catch { busy = (error as? FoundationPreferenceError) == .busy }
        }))
        XCTAssertTrue(busy); XCTAssertTrue(opened.status.createdByMigration); try f.noStages()
    }
    func testCanonicalSettingsAndCoreUpdatesPreserveEachOtherAndRestart() async throws {
        let f = try Fixture(); try f.legacy("Beta07/settings-v1.json", #"{"schemaVersion":1,"preferences":{"dockEdge":"left","subscriptions":{"order":["unmatched"],"hiddenIDs":[]}}}"#)
        try f.legacy("Native/community-v1.json", #"{"schemaVersion":1,"localeIdentifier":"en","favouriteModelIDs":["old-favourite"]}"#)
        let store = try SettingsStore(foundationAt: f.root, product: .official)
        let saved = try await store.update(expectedRevision: 0) { $0.theme = .day; $0.openAtLogin = false }
        XCTAssertEqual(saved.revision, 1)
        let unchangedCore = await store.coreSnapshot(); XCTAssertEqual(unchangedCore?.favouriteModelIDs, ["old-favourite"])
        let nextCore = FoundationCorePreferences(localeIdentifier: "zh", favouriteModelIDs: ["new-favourite"], fieldPickerValue: Data([4,5]))
        let coreCommit = try await store.updateCore(nextCore, expectedRevision: saved.revision)
        XCTAssertEqual(coreCommit.revision, 2); XCTAssertEqual(coreCommit.preferences.theme, .day)
        let reopened = try SettingsStore(foundationAt: f.root, product: .community)
        let snapshot = await reopened.snapshot(), core = await reopened.coreSnapshot()
        XCTAssertEqual(core, nextCore); XCTAssertEqual(snapshot.preferences.theme, .day)
        XCTAssertFalse(snapshot.preferences.openAtLogin); XCTAssertEqual(snapshot.preferences.subscriptions.order, ["unmatched"])
        try f.unchanged(); try f.noStages()
    }
    func testStaleSecondStoreCannotLoseFirstWritersCommit() async throws {
        let f = try Fixture(), first = try SettingsStore(foundationAt: f.root, product: .official)
        let stale = try SettingsStore(foundationAt: f.root, product: .official)
        try await first.update { $0.theme = .night }
        let committed = try Data(contentsOf: f.location.target)
        do { try await stale.update { $0.theme = .day }; XCTFail("stale owner cannot overwrite") }
        catch { XCTAssertEqual(error as? FoundationPreferenceError, .externalChange) }
        let staleMemory = await stale.snapshot(); XCTAssertEqual(staleMemory.preferences.theme, .system)
        XCTAssertEqual(try Data(contentsOf: f.location.target), committed); try f.noStages()
    }
    func testInvalidAndConsentEditsDoNotChangeDiskOrMemory() async throws {
        let f = try Fixture(), store = try SettingsStore(foundationAt: f.root, product: .official)
        let bytes = try Data(contentsOf: f.location.target)
        do { try await store.update { $0.redBelow = 17 }; XCTFail("invalid settings") } catch {}
        do { try await store.update { $0.readerConsent[.gemini] = true }; XCTFail("consent belongs to engine") }
        catch { XCTAssertEqual(error as? FoundationPreferenceError, .engineOwnedConsent) }
        do { try await store.updateCore(.init(favouriteModelIDs: [String(repeating: "x", count: 40000)])); XCTFail("oversized core") } catch {}
        do { try await store.updateCore(.init(), expectedRevision: 9); XCTFail("stale core revision") }
        catch { XCTAssertEqual(error as? SettingsError, .staleRevision) }
        let snapshot = await store.snapshot(); XCTAssertEqual(snapshot.revision, 0); XCTAssertEqual(snapshot.preferences.readerConsent, ReaderConsent())
        XCTAssertEqual(try Data(contentsOf: f.location.target), bytes); try f.noStages()
    }
    func testSymlinkLegacyAndTargetNeverFollowOrModifyOutsideFiles() async throws {
        let f = try Fixture()
        let outside = f.root.appendingPathComponent("outside.json"), sentinel = try document()
        try sentinel.write(to: outside)
        try FileManager.default.createDirectory(at: f.location.directory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: f.location.target, withDestinationURL: outside)
        let store = try SettingsStore(foundationAt: f.root, product: .official)
        let status = await store.foundationStatus(); XCTAssertEqual(status?.readOnlyRecovery, true)
        do { try await store.update { $0.theme = .day }; XCTFail("symlink target must not be replaced") } catch {}
        XCTAssertEqual(try Data(contentsOf: outside), sentinel)
        let legacy = try Fixture(); let externalGroup = legacy.root.appendingPathComponent("outside-group")
        try FileManager.default.createDirectory(at: externalGroup, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion":1,"preferences":{"theme":"night"}}"#.utf8).write(to: externalGroup.appendingPathComponent("settings-v1.json"))
        try legacy.legacy("Native/settings-v1.json", #"{"schemaVersion":1,"preferences":{"theme":"day"}}"#)
        try FileManager.default.createSymbolicLink(at: legacy.location.directory.appendingPathComponent("Beta07"), withDestinationURL: externalGroup)
        let recovered = try File.open(legacy.location)
        XCTAssertEqual(recovered.document.settings.theme, .day)
        XCTAssertTrue(recovered.status.issues.contains { $0.source == .officialSettings && $0.failure == .unreadable })
        try legacy.unchanged()
    }
    func testExistingModelPlanDirectorySymlinkIsRejectedBeforeReadingOrWriting() throws {
        let f = try Fixture(), outside = f.root.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let bytes = try document(); try bytes.write(to: outside.appendingPathComponent("settings.json"))
        try FileManager.default.createSymbolicLink(at: f.location.directory, withDestinationURL: outside)
        XCTAssertThrowsError(try File.open(f.location)) { XCTAssertEqual($0 as? FoundationPreferenceError, .invalidLocation) }
        XCTAssertEqual(try Data(contentsOf: outside.appendingPathComponent("settings.json")), bytes)
    }
    func testExistingEditorCommitsToCanonicalDocumentAndKeepsLastSnapshotOnExternalFailure() async throws {
        let f = try Fixture()
        try f.legacy("Native/community-v1.json", #"{"schemaVersion":1,"favouriteModelIDs":["retained-core"]}"#)
        let store = try SettingsStore(foundationAt: f.root, product: .community)
        let editor = SettingsEditor(store: store)
        await editor.reload()
        let committed = try await editor.commit(SettingsB21Edit.dockEdge(.left))
        let document = try File.Document.decode(Data(contentsOf: f.location.target))
        XCTAssertEqual(document.settings.dockEdge, .left)
        XCTAssertEqual(document.core.favouriteModelIDs, ["retained-core"])
        let external = Data("external-change".utf8); try external.write(to: f.location.target)
        do { _ = try await editor.commit(SettingsB21Edit.dockEdge(.bottom)); XCTFail("external change must fail the editor transaction") }
        catch { XCTAssertEqual(error as? FoundationPreferenceError, .externalChange) }
        XCTAssertEqual(editor.snapshot?.revision, committed.revision)
        XCTAssertEqual(editor.snapshot?.preferences.dockEdge, .left); XCTAssertFalse(editor.isSaving)
        XCTAssertEqual(try Data(contentsOf: f.location.target), external)
        try f.unchanged(); try f.noStages()
    }

}
