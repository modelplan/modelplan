// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore

final class DesktopReadModeTests: XCTestCase {
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:false)
        let file = root.appendingPathComponent("argv-fixture")
        try Data("#!/usr/bin/python3\nimport sys,json\nprint(json.dumps(sys.argv[1:]))\n".utf8).write(to:file)
        try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:file.path)
        return file
    }
    func testDefaultBoundaryRemainsReadonlyAndExplicitNormalDropsOnlyThatFlag() async throws {
        let file = try fixture(); defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        let readonly = ProcessCLITransport(executable:file,environment:[:])
        let normal = ProcessCLITransport(executable:file,environment:[:],desktopReadMode:.normal)
        let a = try await readonly.execute(.desktop), b = try await normal.execute(.desktop)
        XCTAssertEqual(try JSONDecoder().decode([String].self,from:a.stdout),["desktop","--json","--read-only"])
        XCTAssertEqual(try JSONDecoder().decode([String].self,from:b.stdout),["desktop","--json"])
        XCTAssertEqual(a.exitCode,0); XCTAssertEqual(b.exitCode,0)
    }
    func testNormalSelectionCannotTurnOfflinePublicationIntoNetworkCommand() async throws {
        let file = try fixture(); defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        let normal = ProcessCLITransport(executable:file,environment:[:],desktopReadMode:.normal)
        let result = try await normal.execute(.publicationOffline)
        XCTAssertEqual(try JSONDecoder().decode([String].self,from:result.stdout),["publication","--json","--offline"])
    }
}
