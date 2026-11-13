// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanSettings

/// Only caller-owned synthetic files are read. This is not a second persistence store.
final class FoundationSettingsMigrationFixture {
    private let root: URL
    private var originals: [URL: Data] = [:]
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("U5-migration-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: root) }
    func input(_ name: String, _ json: String) throws -> FoundationSettingsMigration.Input {
        let url = root.appendingPathComponent(name), bytes = Data(json.utf8)
        try bytes.write(to: url); originals[url] = bytes
        return .data(try Data(contentsOf: url))
    }
    func input(_ name: String, object: [String: Any]) throws -> FoundationSettingsMigration.Input {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return try input(name, String(decoding: data, as: UTF8.self))
    }
    func originalsUnchanged() throws -> Bool {
        try originals.allSatisfy { try Data(contentsOf: $0.key) == $0.value }
    }
}
