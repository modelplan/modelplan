// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanDock
import ModelPlanDockResources

/// G3-45: the first-run tool list shows each vendor's mark, from the same checked third-party
/// marks the Quota Widget uses (nominative use, see the vendor notice). Missing marks return nil
/// and the page shows two letters instead.
@MainActor enum ScopeConsentMarks {
    private static let resources: [String: String] = [
        "claude": "logo-claude", "codex": "logo-openai", "cursor": "logo-cursor", "copilot": "logo-copilot",
        "gemini": "logo-gemini", "grok": "logo-grok", "kimi": "logo-kimi", "zai": "logo-zhipu", "qwen": "logo-qwen",
        "opencodego": "logo-opencode", "opencode": "logo-opencode", "kiro": "logo-kiro", "amp": "logo-amp",
        "droid": "logo-droid", "antigravity": "logo-antigravity", "minimax": "logo-minimax",
    ]
    private static var store: DockArtworkStore?
    private static var cache: [String: NSImage] = [:]
    static func image(for tool: String) -> NSImage? {
        if let cached = cache[tool] { return cached }
        guard let id = resources[tool] else { return nil }
        do {
            if store == nil {
                let manifest = try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(zaiMarkEnabled: false))
                store = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: manifest)
            }
            guard let store else { return nil }
            let glyph = try store.fittedGlyph(id, targetPixelSize: 40)
            let image = NSImage(cgImage: glyph, size: NSSize(width: 20, height: 20))
            image.isTemplate = true
            cache[tool] = image
            return image
        } catch { return nil }
    }
}
