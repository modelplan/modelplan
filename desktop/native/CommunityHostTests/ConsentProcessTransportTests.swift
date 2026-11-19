// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import CryptoKit
import Darwin

final class ConsentProcessTransportTests: XCTestCase {
    func testDefaultEnvironmentInheritsAndExplicitEmptyDoesNot() async throws {
        let key = "MODELPLAN_CONSENT_ENV_TEST"
        let old = ProcessInfo.processInfo.environment[key]
        setenv(key, "synthetic-marker", 1)
        defer { if let old { setenv(key, old, 1) } else { unsetenv(key) } }
        // Prints {"marker":null} when the variable is unset, else its value (the synthetic marker needs no escaping).
        let script = try SubprocessFixture.write("environment-fixture", body: """
        if [ -n "${MODELPLAN_CONSENT_ENV_TEST+set}" ]; then printf '{"marker":"%s"}\\n' "$MODELPLAN_CONSENT_ENV_TEST"
        else printf '{"marker":null}\\n'; fi
        """)
        defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }
        for explicitEmpty in [false, true] {
            let port = ProcessCLITransport(executable: script, environment: explicitEmpty ? [:] : nil,
                                           timeoutOverride: SubprocessFixture.generousTimeout)
            let result = try await port.readConsentJSON()
            XCTAssertEqual(result.exitCode, 0)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: result.stdout) as? [String: Any])
            if explicitEmpty { XCTAssertTrue(object["marker"] is NSNull) }
            else { XCTAssertEqual(object["marker"] as? String, "synthetic-marker") }
        }
    }
    /// `consent grant --json` (exactly) copies stdin to stdout byte for byte; any other argv is printed as JSON.
    private func fixture() throws -> URL {
        try SubprocessFixture.write("consent-fixture", body: SubprocessFixture.printArgv + """

        if [ $# -eq 3 ] && [ "$1" = consent ] && [ "$2" = grant ] && [ "$3" = --json ]; then exec /bin/cat; fi
        print_argv "$@"
        """)
    }
    func testBoundedGrantStdinIsCompleteAndReadUsesExactCommand() async throws {
        let file = try fixture(); defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let port = ProcessCLITransport(executable: file, environment: [:], timeoutOverride: SubprocessFixture.generousTimeout)
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
