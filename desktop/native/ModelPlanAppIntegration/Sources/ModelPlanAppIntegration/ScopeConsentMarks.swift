// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanDock
import ModelPlanDockResources

/// G3-45: the first-run tool list shows each vendor's mark, from the same checked third-party
/// marks the Quota Widget uses (nominative use, see the vendor notice). Missing marks return nil
/// and the page shows two letters instead. Marks that are a filled tile (Kiro, ZCode's Zhipu mark) read
/// as a plain block when drawn in one colour, so they keep their own colours; the rest follow the label colour.
@MainActor enum ScopeConsentMarks {
    private static let resources: [String: String] = [
        "claude": "logo-claude", "codex": "logo-openai", "cursor": "logo-cursor", "copilot": "logo-copilot",
        "gemini": "logo-gemini", "grok": "logo-grok", "kimi": "logo-kimi", "qwen": "logo-qwen",
        "opencodego": "logo-opencode", "opencode": "logo-opencode", "kiro": "logo-kiro", "amp": "logo-amp",
        "droid": "logo-droid", "antigravity": "logo-antigravity", "minimax": "logo-minimax",
        "zai": "logo-zhipu",
    ]
    /// Tools whose mark is a coloured tile: drawn as the file is, not as a one-colour template.
    static let colouredTools: Set<String> = ["kiro", "zai"]
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
            image.isTemplate = !colouredTools.contains(tool)
            cache[tool] = image
            return image
        } catch { return nil }
    }
}
