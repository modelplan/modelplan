// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanEngineClient

extension RealBinaryTests {
    func testRealDocumentedKimiEnvironmentKeyCanLaunch() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        var allowed = environment(home)
        allowed["KIMI_CODE_API_KEY"] = "synthetic-unused-key"
        let client = ProcessEngineClient(configuration: EngineClientConfiguration(executableURL: binary,
            applicationVersion: "synthetic-environment", allowedEnvironment: allowed), consumer: probe)
        addTeardownBlock { await client.stop() }
        _ = try await client.start()
    }
}

final class EnvironmentContractTests: XCTestCase {
    func testGeneratedSwiftSetEqualsGoSupervisionContract() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let data = try Data(contentsOf: root.appendingPathComponent("schema/app-cli/child-environment.json"))
        let contract = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let names = try XCTUnwrap(contract["allowedKeys"] as? [String])
        XCTAssertEqual(names.count, Set(names).count)
        XCTAssertEqual(Set(names), WireChildEnvironment.allowedKeys)
    }
}

extension RealBinaryTests {
    func testRealConfigurationUsesEntireGeneratedEnvironmentSet() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        for key in WireChildEnvironment.allowedKeys {
            var allowed = environment(home)
            if allowed[key] == nil { allowed[key] = "synthetic-unused-value" }
            let client = ProcessEngineClient(configuration: EngineClientConfiguration(executableURL: binary,
                applicationVersion: "synthetic-environment", allowedEnvironment: allowed), consumer: probe)
            try await client.validateConfiguration()
        }
        for key in ["KIMI_API_KEY", "KIMI_AUTH_TOKEN", "UNRELATED_SECRET"] {
            var allowed = environment(home); allowed[key] = "synthetic-unused-value"
            let client = ProcessEngineClient(configuration: EngineClientConfiguration(executableURL: binary,
                applicationVersion: "synthetic-environment", allowedEnvironment: allowed), consumer: probe)
            do { try await client.validateConfiguration(); XCTFail("undeclared environment key accepted") }
            catch EngineClientError.invalidConfiguration {}
        }
    }
}
