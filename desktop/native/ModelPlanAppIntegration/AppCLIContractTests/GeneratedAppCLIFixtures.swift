// SPDX-License-Identifier: MIT
import Foundation

/// Reads the one checked-in capture set; no package-local copies can drift.
enum GeneratedAppCLIFixtures {
    struct Manifest: Decodable { let states: [String]; let entries: [Entry] }
    struct Entry: Decodable {
        let file: String, state: String, schema: String, encoding: String
        let arguments: [String], exitCode: Int32, stderr: String
        let request: String?
    }
    static func directory() throws -> URL {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while root.path != "/" {
            let candidate = root.appendingPathComponent("schema/app-cli/fixtures")
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("manifest.json").path) { return candidate }
            root.deleteLastPathComponent()
        }
        throw NSError(domain: "Missing generated app–CLI fixtures; run make app-cli-fixtures", code: 1)
    }
    static func data(_ name: String) throws -> Data { try Data(contentsOf: directory().appendingPathComponent(name)) }
    static func object(_ name: String) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: data(name)) as? [String: Any] else {
            throw NSError(domain: "Expected fixture object: " + name, code: 2)
        }
        return value
    }
    static func manifest() throws -> Manifest { try JSONDecoder().decode(Manifest.self, from: data("manifest.json")) }
}
