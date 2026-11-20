// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore

final class DesktopReadModeTests: XCTestCase {
    // Real child through the production transport; the timeout is not under test here (see SubprocessFixture).
    private func fixture() throws -> URL { try SubprocessFixture.argv() }
    func testDefaultBoundaryRemainsReadonlyAndExplicitNormalDropsOnlyThatFlag() async throws {
        let file = try fixture(); defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        let readonly = ProcessCLITransport(executable:file,environment:[:],timeoutOverride:SubprocessFixture.generousTimeout)
        let normal = ProcessCLITransport(executable:file,environment:[:],timeoutOverride:SubprocessFixture.generousTimeout,desktopReadMode:.normal)
        let a = try await readonly.execute(.desktop), b = try await normal.execute(.desktop)
        XCTAssertEqual(try JSONDecoder().decode([String].self,from:a.stdout),["desktop","--json","--read-only"])
        XCTAssertEqual(try JSONDecoder().decode([String].self,from:b.stdout),["desktop","--json"])
        XCTAssertEqual(a.exitCode,0); XCTAssertEqual(b.exitCode,0)
    }
    func testNormalSelectionCannotTurnOfflinePublicationIntoNetworkCommand() async throws {
        let file = try fixture(); defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        let normal = ProcessCLITransport(executable:file,environment:[:],timeoutOverride:SubprocessFixture.generousTimeout,desktopReadMode:.normal)
        let result = try await normal.execute(.publicationOffline)
        XCTAssertEqual(try JSONDecoder().decode([String].self,from:result.stdout),["publication","--json","--offline"])
    }
}
