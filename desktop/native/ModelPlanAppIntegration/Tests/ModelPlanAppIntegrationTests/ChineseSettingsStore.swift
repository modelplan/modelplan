// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanSettings

/// A legacy-url settings store whose saved language is Chinese. The product default is now the shared English fallback
/// (SET-9-39); tests whose oracle is Chinese text pin the language here instead of relying on the old default.
func chineseSettingsStore(url: URL) throws -> SettingsStore {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(#"{"schemaVersion":1,"preferences":{"language":"zh-CN"}}"#.utf8).write(to: url)
    return try SettingsStore(url: url)
}
