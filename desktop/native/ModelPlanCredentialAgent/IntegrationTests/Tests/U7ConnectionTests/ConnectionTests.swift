// SPDX-License-Identifier: MIT
import XCTest
import CryptoKit
@testable import ModelPlanCredentialAgent
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire

private actor InjectedAgent: CredentialAgent {
    var calls = 0
    func handle(_ operation: EngineCredentialOperation) async -> WireCredentialResult {
        calls += 1
        return try! .init(operationId: operation.request.operationId, outcome: .denied)
    }
    func count() -> Int { calls }
}

@MainActor final class ConnectionTests: XCTestCase {
    private func profile() throws -> URL {
        // Keep the packaged fixture under the checkout's real directory. Foundation
        // standardizes /private/var back to /var, a symlink the pin correctly rejects.
        var package = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { package.deleteLastPathComponent() }
        let home = package.appendingPathComponent(".build/u7-fixtures/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let fixture = try XCTUnwrap(Bundle.module.url(forResource: "engine", withExtension: "py", subdirectory: "Fixtures"))
        let executable = home.appendingPathComponent("engine")
        try FileManager.default.copyItem(at: fixture, to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        return home
    }
    private func config(_ home: URL) -> EngineClientConfiguration {
        .init(executableURL: home.appendingPathComponent("engine"), applicationVersion: "synthetic-u7",
              allowedEnvironment: ["HOME": home.path, "TMPDIR": home.path,
                "PATH": "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"], offline: true, readOnly: true)
    }
    private func outcome(_ home: URL) async throws -> [String: Any] {
        let file = home.appendingPathComponent("outcome.json")
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while !FileManager.default.fileExists(atPath: file.path), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let value = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        XCTAssertEqual(value["operationId"] as? String, "u7-synthetic-operation")
        XCTAssertEqual(value["outcome"] as? String, "denied")
        XCTAssertEqual(value["hasToken"] as? Bool, false)
        return value
    }
    func testNormalConnectionAdvertisesCredentialsAndReturnsR2Denial() async throws {
        let home = try profile()
        defer { try? FileManager.default.removeItem(at: home) }
        let connection = EngineStoreConnection(configuration: config(home))
        let current = try await connection.client.start()
        do {
            let capabilities = try JSONDecoder().decode([String].self, from: Data(contentsOf: home.appendingPathComponent("capabilities.json")))
            XCTAssertTrue(capabilities.contains("credentials"), "normal constructor must install the agent")
            XCTAssertTrue(connection.client.isCurrent(current))
            _ = try await outcome(home)
        } catch { await connection.client.stop(); throw error }
        await connection.client.stop()
        XCTAssertFalse(connection.client.isCurrent(current))
    }
    func testNormalConnectionPreservesExplicitInjectedAgent() async throws {
        let home = try profile()
        defer { try? FileManager.default.removeItem(at: home) }
        let agent = InjectedAgent()
        let connection = EngineStoreConnection(configuration: config(home), credentialAgent: agent)
        _ = try await connection.client.start()
        do { _ = try await outcome(home) } catch { await connection.client.stop(); throw error }
        let calls = await agent.count()
        XCTAssertEqual(calls, 1)
        await connection.client.stop()
    }
    func testFactoryLaunchesPinnedPackagedFixtureWithRealCurrentVeto() async throws {
        let home = try profile()
        defer { try? FileManager.default.removeItem(at: home) }
        let app = home.appendingPathComponent("Synthetic.app")
        let helper = app.appendingPathComponent("Contents/Helpers/modelplan-credential-agent")
        let resources = app.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: helper.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>ai.modelplan.u7.synthetic</string></dict></plist>".write(to: app.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)
        let source = """
        #!/usr/bin/env python3
        import json
        from pathlib import Path
        import sys
        request = json.load(sys.stdin)
        (Path(__file__).parents[1] / 'Resources/helper-called').write_text('synthetic')
        print(json.dumps({'operationId': request['operationId'], 'outcome': 'denied'}))
        """
        let bytes = Data(source.utf8)
        try bytes.write(to: helper)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
        let pin = CredentialHelperPin(sha256: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(),
                                      bytes: bytes.count, inputSHA256: String(repeating: "0", count: 64))
        try JSONEncoder().encode(pin).write(to: resources.appendingPathComponent("credential-agent.json"))
        let bundle = try XCTUnwrap(Bundle(url: app))
        XCTAssertEqual(bundle.bundleURL.standardizedFileURL.path, app.standardizedFileURL.path)
        XCTAssertTrue(pin.accepts(helper), "the canonical synthetic packaged fixture must pass the artifact pin")
        XCTAssertNotNil(FixedHelperCredentialAgent.bundled(in: bundle, isCurrent: { _ in true }))
        let client = CredentialAgentClientFactory.make(configuration: config(home), consumer: EngineStore(), bundle: bundle)
        let current = try await client.start()
        do {
            _ = try await outcome(home)
            XCTAssertTrue(FileManager.default.fileExists(atPath: resources.appendingPathComponent("helper-called").path),
                          "constant in-process denial must not masquerade as the packaged helper path")
            XCTAssertTrue(client.isCurrent(current))
        } catch { await client.stop(); throw error }
        await client.stop()
        XCTAssertFalse(client.isCurrent(current))
    }
}
