// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanSettings

/// Bundle-only legal text. This does not inspect a profile, execute a component or follow an external link.
enum CommunityBundledNotices {
    static let maximumBytes = 1_048_576
    static func load(bundle: URL) -> [SettingsLicenseNotice] {
        let root = bundle.standardizedFileURL.resolvingSymlinksInPath()
        let files: [(String, String, String, Bool)] = [
            ("LICENSE.txt", "ModelPlan software", "MIT", true),
            ("CLI-THIRD-PARTY-NOTICES.md", "Bundled CLI dependencies", "See bundled licence notices", true),
            ("VISUAL-LICENSE.md", "Official visuals", "ModelPlan Official Visuals License 1.0", false),
        ]
        var notices: [SettingsLicenseNotice] = []
        for (name, component, license, required) in files {
            let file = root.appendingPathComponent("Contents/Resources/" + name)
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path) else {
                if required { return [] }
                continue
            }
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let text = read(file, inside: root) else { return [] }
            notices.append(.init(component: component, license: license, text: text))
        }
        return notices
    }
    private static func read(_ file: URL, inside root: URL) -> String? {
        let resolved = file.resolvingSymlinksInPath()
        guard resolved.path.hasPrefix(root.path + "/"),
              let metadata = try? resolved.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              metadata.isRegularFile == true, let size = metadata.fileSize, size > 0, size <= maximumBytes,
              let handle = try? FileHandle(forReadingFrom: resolved) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maximumBytes + 1), data.count == size,
              let text = String(data: data, encoding: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !text.unicodeScalars.contains(where: { $0.value == 0 }) else { return nil }
        return text
    }
}
