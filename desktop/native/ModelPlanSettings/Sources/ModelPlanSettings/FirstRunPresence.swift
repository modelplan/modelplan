// SPDX-License-Identifier: MIT
import Foundation

/// FR-9-04 / E2: what the first-run page can say about a tool before the reader answers.
/// The signals mirror the reader's bundled detector list (`cli/internal/detect/catalogue.go`, `Fallback()`):
/// a command on the search path or a tool folder in the home directory. Presence only: nothing is opened
/// or read. The reader's own rows replace this list once they arrive (SET-9-37); a test compares this
/// table with the Go catalogue so the two lists cannot drift.
public struct FirstRunPresenceTool: Equatable, Sendable {
    public let id: String
    public let commands: [String]
    /// Paths relative to the home directory.
    public let paths: [String]
    public init(id: String, commands: [String], paths: [String]) { self.id = id; self.commands = commands; self.paths = paths }
}

public enum FirstRunPresenceCatalogue {
    /// In the reader's order.
    public static let tools: [FirstRunPresenceTool] = [
        .init(id: "claude", commands: ["claude"], paths: [".claude"]),
        .init(id: "codex", commands: ["codex"], paths: [".codex"]),
        .init(id: "zai", commands: ["zcode", "zcode-cli"],
              paths: [".zcode", ".local/share/zcode-community", ".local/share/zcode-cli", "Library/Application Support/ZCode"]),
        .init(id: "cursor", commands: ["cursor"], paths: [".cursor"]),
        .init(id: "copilot", commands: ["copilot"], paths: [".copilot"]),
        .init(id: "gemini", commands: ["gemini"], paths: [".gemini/oauth_creds.json", ".gemini/tmp"]),
        .init(id: "kimi", commands: ["kimi"], paths: [".kimi-code"]),
        .init(id: "qwen", commands: ["qwen"], paths: [".qwen"]),
        .init(id: "opencodego", commands: ["opencode"], paths: [".config/opencode"]),
        .init(id: "kiro", commands: ["kiro-cli"], paths: []),
        .init(id: "amp", commands: ["amp"], paths: [".local/share/amp"]),
        .init(id: "droid", commands: ["droid"], paths: [".factory"]),
        .init(id: "grok", commands: ["grok"], paths: [".grok"]),
        .init(id: "antigravity", commands: ["antigravity"], paths: [".gemini/antigravity"]),
    ]
}

/// Finds which catalogue tools are on this Mac. `exists` is the only file-system access, so a test supplies its own.
public struct FirstRunPresenceDetector: Sendable {
    public var home: String
    public var searchDirectories: [String]
    public var exists: @Sendable (String) -> Bool
    public init(home: String, searchDirectories: [String], exists: @escaping @Sendable (String) -> Bool) {
        self.home = home; self.searchDirectories = searchDirectories; self.exists = exists
    }
    /// The real Mac: the process's PATH plus the usual install folders.
    public static func live() -> FirstRunPresenceDetector {
        let home = NSHomeDirectory()
        let path = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        let usual = ["/opt/homebrew/bin", "/usr/local/bin", home + "/.local/bin", home + "/.npm-global/bin", home + "/.bun/bin", home + "/.cargo/bin"]
        return .init(home: home, searchDirectories: path + usual) { FileManager.default.fileExists(atPath: $0) }
    }
    /// Tool ids present on this Mac, in catalogue order.
    public func detect() -> [String] {
        FirstRunPresenceCatalogue.tools.filter { tool in
            tool.paths.contains { exists(home + "/" + $0) }
                || tool.commands.contains { name in searchDirectories.contains { exists($0 + "/" + name) } }
        }.map(\.id)
    }
}
