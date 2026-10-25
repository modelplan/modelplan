// SPDX-License-Identifier: MIT
import Foundation

enum FieldResourcePolicy {
    static func snapshotWidth(width: CGFloat, height: CGFloat, backingScale: CGFloat) -> Int? {
        guard width.isFinite, height.isFinite, backingScale.isFinite,
              width > 0, height > 0, backingScale >= 1 else { return nil }
        let points = floor(min(1024, 2048 * width / height) / backingScale)
        guard points >= 1, points <= 2048 else { return nil }
        return Int(points)
    }
    static func permitsNavigation(_ url: URL, generation: UUID?, mainFrame: Bool, download: Bool) -> Bool {
        guard !download, mainFrame, url.scheme == "modelplan-field", url.host == "bundle",
              url.port == nil, url.user == nil, url.password == nil, url.path == "/index.html",
              let generation, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.queryItems == [URLQueryItem(name: "generation", value: generation.uuidString)] else { return false }
        return true
    }
    static func file(for url: URL, root: URL, bridge: URL?) -> URL? {
        guard url.scheme == "modelplan-field", url.host == "bundle", url.port == nil,
              url.user == nil, url.password == nil else { return nil }
        if url.path == "/field-bridge.mjs" { return bridge }
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        guard canonicalRoot.isFileURL else { return nil }
        let file = canonicalRoot.appendingPathComponent(url.path).standardizedFileURL.resolvingSymlinksInPath()
        guard file.path.hasPrefix(canonicalRoot.path + "/") else { return nil }
        return file
    }
}
