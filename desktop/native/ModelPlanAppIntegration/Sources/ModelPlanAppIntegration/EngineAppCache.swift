// SPDX-License-Identifier: MIT
import Foundation

/// "Clear app cache": only the app's own derived cache. Preferences, consent and the CLI's
/// cache (a sibling `modelplan` folder under Caches) are never touched.
enum EngineAppCache {
    @discardableResult static func clear(cachesRoot: URL, bundleIdentifier: String, fileManager: FileManager = .default) -> Bool {
        guard !bundleIdentifier.isEmpty, !bundleIdentifier.contains("/"), bundleIdentifier != "modelplan" else { return false }
        let folder = cachesRoot.appendingPathComponent(bundleIdentifier, isDirectory: true)
        guard let items = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return true }
        var cleared = true
        for item in items where (try? fileManager.removeItem(at: item)) == nil { cleared = false }
        return cleared
    }
    static func clearCurrentApp() {
        URLCache.shared.removeAllCachedResponses()
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let id = Bundle.main.bundleIdentifier else { return }
        clear(cachesRoot: root, bundleIdentifier: id)
    }
}
