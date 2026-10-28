// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import CryptoKit

final class ConsentProcessTransportTests: XCTestCase {
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let file = root.appendingPathComponent("consent-fixture")
        try Data("#!/usr/bin/python3\nimport sys,json\nif sys.argv[1:]==['consent','grant','--json']:\n sys.stdout.buffer.write(sys.stdin.buffer.read())\nelse:\n print(json.dumps(sys.argv[1:]))\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        return file
    }
    func testBoundedGrantStdinIsCompleteAndReadUsesExactCommand() async throws {
        let file = try fixture(); defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let port = ProcessCLITransport(executable: file, environment: [:])
        let start = ProcessInfo.processInfo.systemUptime
        let read: CommandResult
        do { read = try await port.readConsentJSON() }
        catch {
            XCTFail("CONSENT-PROCESS-PROBE read stage failed after \(ProcessInfo.processInfo.systemUptime - start)s: \(error)")
            return
        }
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: read.stdout), ["consent", "--json"])
        let bytes = Data(repeating: 120, count: 65536)
        let grantStart = ProcessInfo.processInfo.systemUptime
        let result: CommandResult
        do { result = try await port.grantConsentJSON(bytes) }
        catch {
            XCTFail("CONSENT-PROCESS-PROBE grant stdin stage failed after \(ProcessInfo.processInfo.systemUptime - grantStart)s: \(error)")
            return
        }
        XCTAssertEqual(result.exitCode, 0); XCTAssertEqual(result.stdout, bytes)
    }
    func testOversizedAndEmptyPayloadsRefuseBeforeLaunch() async throws {
        let port = ProcessCLITransport(executable: URL(fileURLWithPath: "/no-such-helper"), environment: [:])
        for bytes in [Data(), Data(repeating: 0, count: 65537)] {
            do { _ = try await port.grantConsentJSON(bytes); XCTFail("Must reject") }
            catch { XCTAssertEqual(error as? TransportError, .outputLimit) }
        }
    }
    func testBundledConsentUsesTheSameHelperPinBoundary() async throws {
        let file = try fixture(); defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let bundle = file.deletingLastPathComponent().appendingPathComponent("Fixture.app")
        let helpers = bundle.appendingPathComponent("Contents/Helpers"), resources = bundle.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: file, to: helpers.appendingPathComponent("modelplan"))
        let hash = SHA256.hash(data: try Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
        let pin = resources.appendingPathComponent("modelplan.sha256")
        try Data(hash.utf8).write(to: pin)
        let result = try await BundledCLI(bundle: bundle, environment: [:]).readConsentJSON()
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: result.stdout), ["consent", "--json"])
        try Data(String(repeating: "0", count: 64).utf8).write(to: pin)
        do { _ = try await BundledCLI(bundle: bundle, environment: [:]).readConsentJSON(); XCTFail("Must reject pin") }
        catch { XCTAssertEqual(error as? TransportError, .launchFailed) }
    }
}
