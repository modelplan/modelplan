// SPDX-License-Identifier: MIT
import Foundation
import CryptoKit
import XCTest
import ModelPlanCore
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class ProductionConsentIdentityTests: XCTestCase {
    private actor Transport: ConsentJSONTransport {
        var reads = 0, grants = 0
        func readConsentJSON() async throws -> CommandResult {
            reads += 1
            return .init(exitCode: 0, stdout: Data(#"{"generation":1,"consentTextVersion":2,"mode":"automatic","consentText":{"en":"Synthetic consent","zh":"合成授权"},"tools":[]}"#.utf8))
        }
        func grantConsentJSON(_ payload: Data) async throws -> CommandResult { grants += 1; throw TransportError.launchFailed }
        func counts() -> [Int] { [reads, grants] }
    }
    private let arm64Source = "e8f04d7eba3108ec808f2ce53e2a0c72e895c7dc83306e7bd135f039bc50c6ae"
    private let amd64Source = "10a3fb58d4211b59dfad2660bedc45c1bee6cf021edfa5cae01e6e58d9b9f4b5"
    private func bundle(version: String = "0.5.43", source: String? = nil) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("consent-identity-" + UUID().uuidString).resolvingSymlinksInPath()
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let helpers = root.appendingPathComponent("Contents/Helpers"), resources = root.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        // Inert bytes, not executable or actual release provenance. Only consistency is tested.
        let bytes = Data("Synthetic packaged helper; never executed".utf8)
        try bytes.write(to: helpers.appendingPathComponent("modelplan"))
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        try Data((digest + "\n").utf8).write(to: resources.appendingPathComponent("modelplan.sha256"))
        let info = ["ModelPlanPublicSource": String(repeating: "a", count: 40), "ModelPlanHelperVersion": version,
                    "ModelPlanSourceHelperSHA256": source ?? arm64Source, "ModelPlanBundledHelperSHA256": digest]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: root.appendingPathComponent("Contents/Info.plist"))
        return root
    }
    func testActualEntryConsentFactoryAdmitsOnlyTheReviewedConsistentRelease() async throws {
        for source in [arm64Source, amd64Source] {
        let location = try bundle(source: source), transport = Transport()
        let port = CommunityApplicationFactory.makeConsentPort(bundle: location, transport: transport)
        XCTAssertTrue(port.availability.canInspect)
        XCTAssertTrue(port.availability.canGrant); XCTAssertTrue(port.availability.canForget)
        let before = await transport.counts(); XCTAssertEqual(before, [0, 0], "Identity construction must never execute a helper")
        let preview = try await port.readCanonicalConsent()
        XCTAssertEqual(preview.generation, 1)
        let after = await transport.counts(); XCTAssertEqual(after, [1, 0])
        }
    }
    private func updateInfo(_ root: URL, _ change: (inout [String: Any]) -> Void) throws {
        let path = root.appendingPathComponent("Contents/Info.plist")
        var info = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: path), format: nil) as? [String: Any])
        change(&info)
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: path)
    }
    func testOldMissingMismatchedAndSymlinkedBundlesNeverReachConsentTransport() async throws {
        for failure in ["old", "source", "bundled", "pin", "missing", "symlink", "public-source", "oversized-pin", "missing-info"] {
            let root = try bundle(), transport = Transport()
            let helper = root.appendingPathComponent("Contents/Helpers/modelplan")
            switch failure {
            case "old": try updateInfo(root) { $0["ModelPlanHelperVersion"] = "0.5.42" }
            case "source": try updateInfo(root) { $0["ModelPlanSourceHelperSHA256"] = String(repeating: "b", count: 64) }
            case "bundled": try updateInfo(root) { $0["ModelPlanBundledHelperSHA256"] = String(repeating: "c", count: 64) }
            case "pin": try Data((String(repeating: "d", count: 64) + "\n").utf8).write(to: root.appendingPathComponent("Contents/Resources/modelplan.sha256"))
            case "missing": try FileManager.default.removeItem(at: helper)
            case "symlink":
                let original = helper.appendingPathExtension("fixture")
                try FileManager.default.moveItem(at: helper, to: original)
                try FileManager.default.createSymbolicLink(at: helper, withDestinationURL: original)
            case "public-source": try updateInfo(root) { $0["ModelPlanPublicSource"] = "unknown" }
            case "oversized-pin": try Data(repeating: 97, count: 257).write(to: root.appendingPathComponent("Contents/Resources/modelplan.sha256"))
            case "missing-info": try FileManager.default.removeItem(at: root.appendingPathComponent("Contents/Info.plist"))
            default: XCTFail("Unexpected fixture")
            }
            let port = CommunityApplicationFactory.makeConsentPort(bundle: root, transport: transport)
            XCTAssertFalse(port.availability.hasAnyAction, failure)
            XCTAssertEqual(port.availability.reason, .componentUnverified)
            do { _ = try await port.readCanonicalConsent(); XCTFail("Must refuse before transport") } catch { }
            let calls = await transport.counts(); XCTAssertEqual(calls, [0, 0])
        }
    }
    func testUniversalDeclarationRequiresBothReviewedRawSourcePins() async throws {
        let root = try bundle(), transport = Transport()
        try updateInfo(root) {
            $0.removeValue(forKey: "ModelPlanSourceHelperSHA256")
            $0["ModelPlanSourceHelperSHA256ByArchitecture"] = ["arm64": self.arm64Source, "x86_64": self.amd64Source]
        }
        XCTAssertTrue(CommunityApplicationFactory.makeConsentPort(bundle: root, transport: transport).availability.canInspect)
        try updateInfo(root) { $0["ModelPlanSourceHelperSHA256ByArchitecture"] = ["arm64": self.arm64Source] }
        XCTAssertFalse(CommunityApplicationFactory.makeConsentPort(bundle: root, transport: transport).availability.hasAnyAction)
        try updateInfo(root) { $0["ModelPlanSourceHelperSHA256ByArchitecture"] = ["arm64": self.arm64Source, "x86_64": String(repeating: "a", count: 64)] }
        XCTAssertFalse(CommunityApplicationFactory.makeConsentPort(bundle: root, transport: transport).availability.hasAnyAction)
        let calls = await transport.counts(); XCTAssertEqual(calls, [0, 0])
    }

}
