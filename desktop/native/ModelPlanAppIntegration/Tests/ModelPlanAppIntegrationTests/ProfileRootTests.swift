// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// D164: a fresh profile keeps every store the app or its engine writes under one folder.
@MainActor final class ProfileRootTests: XCTestCase {
    private func freshRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("profile-root-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.resolvingSymlinksInPath()
    }
    private func assertUnder(_ root: URL, _ url: URL, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        XCTAssertTrue(path.hasPrefix(root.standardizedFileURL.path + "/"), "\(name) resolves outside the profile root: \(path)", file: file, line: line)
    }

    func testEveryStoreResolvesUnderTheOverrideRoot() throws {
        let root = try freshRoot()
        let profile = try ProfileRoot.resolve(environment: [ProfileRoot.environmentKey: root.path])
        XCTAssertTrue(profile.isFresh)
        let stores = profile.stores(bundleIdentifier: "org.modelplan.synthetic")
        XCTAssertTrue(stores.contains { $0.name == "engine config" } && stores.contains { $0.name == "engine cache" })
        for store in stores { assertUnder(root, store.url, store.name) }
        assertUnder(root, profile.applicationSupport, "Application Support")
        assertUnder(root, profile.caches, "Caches")
        // The engine child follows the same root; nothing reaches the real defaults domain or login item.
        XCTAssertEqual(profile.childEnvironment(["HOME": "/synthetic"])[ProfileRoot.environmentKey], profile.root?.path)
        XCTAssertNil(profile.statusItemAutosaveName)
        XCTAssertFalse(profile.allowsLoginItem)
    }

    func testTheNormalEntryStoresFollowTheRoot() throws {
        let root = try freshRoot()
        let profile = try ProfileRoot.resolve(environment: [ProfileRoot.environmentKey: root.path])
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile.applicationSupport)
        assertUnder(root, settings.directory, "settings store")
        XCTAssertEqual(settings.directory.standardizedFileURL, profile.modelPlanSupport.standardizedFileURL)
    }

    func testWithoutTheKeyTheRealProfileIsUnchanged() throws {
        let profile = try ProfileRoot.resolve(environment: [:])
        XCTAssertFalse(profile.isFresh)
        XCTAssertEqual(profile.applicationSupport, FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
        XCTAssertEqual(profile.statusItemAutosaveName, ProfileRoot.statusItemAutosaveName)
        XCTAssertTrue(profile.allowsLoginItem)
        XCTAssertNil(profile.urlCacheDirectory)
        // A stray key never reaches the engine of a real-profile launch.
        XCTAssertNil(profile.childEnvironment([ProfileRoot.environmentKey: "/elsewhere"])[ProfileRoot.environmentKey])
    }

    func testUnusableRootsAreRefusedNotIgnored() throws {
        let key = ProfileRoot.environmentKey
        XCTAssertThrowsError(try ProfileRoot.resolve(environment: [key: "relative/profile"])) { XCTAssertEqual($0 as? ProfileRoot.Failure, .notAbsolute) }
        XCTAssertThrowsError(try ProfileRoot.resolve(environment: [key: "/nonexistent-" + UUID().uuidString])) { XCTAssertEqual($0 as? ProfileRoot.Failure, .notADirectory) }
        for overlap in ["/", FileManager.default.homeDirectoryForCurrentUser.path] {
            XCTAssertThrowsError(try ProfileRoot.resolve(environment: [key: overlap])) { XCTAssertEqual($0 as? ProfileRoot.Failure, .overlapsRealProfile) }
        }
    }

    func testFreshLoginItemIsUnavailableAndNeverChanges() {
        let adapter = CommunityLoginServiceAdapter(item: ProfileRoot.unavailableLoginItem())
        XCTAssertEqual(adapter.observedState, .unavailable)
        XCTAssertFalse(adapter.observedNotInApplications)
    }

    /// Every app store goes through ProfileRoot: a new call to the system folders, a hard-coded status-item
    /// autosave name or another SMAppService user would escape a fresh profile.
    func testNoStoreBypassesTheResolver() throws {
        var native = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { native.deleteLastPathComponent() }
        let roots = ["Sources", "ModelPlanAppIntegration/Sources", "ModelPlanSettings/Sources", "ModelPlanEngineStore/Sources",
                     "ModelPlanCockpitWeb/Sources", "ModelPlanDock", "ModelPlanInstruments/Sources", "ModelPlanField", "ModelPlanSelection"]
        let allowed: [String: Set<String>] = [
            "ProfileRoot.swift": ["applicationSupportDirectory", "cachesDirectory", "ModelPlanCommunity.StatusItem"],
            "PulseLoginItem.swift": ["SMAppService."],
        ]
        var checked = 0
        for root in roots {
            guard let walker = FileManager.default.enumerator(at: native.appendingPathComponent(root), includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" && !url.path.contains("/Tests/") {
                let text = try String(contentsOf: url, encoding: .utf8)
                checked += 1
                for needle in ["applicationSupportDirectory", "cachesDirectory", "ModelPlanCommunity.StatusItem", "SMAppService."]
                where text.contains(needle) && !(allowed[url.lastPathComponent]?.contains(needle) ?? false) {
                    XCTFail("\(url.path) uses \(needle); resolve the store through ProfileRoot")
                }
            }
        }
        XCTAssertGreaterThan(checked, 50)
    }
}
