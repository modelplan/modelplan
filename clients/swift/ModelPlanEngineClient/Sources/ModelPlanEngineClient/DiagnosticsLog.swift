// SPDX-License-Identifier: MIT
import Foundation
#if canImport(os)
import os
#endif

/// Replaces anything that looks like a secret or a personal identifier before a line is written to a log
/// file or copied into a diagnostics bundle. Callers already log only scope ids, cause codes, counts and
/// durations; this pass is the backstop for text the app does not control (engine stderr, crash reports).
public enum DiagnosticsRedactor {
    public static let marker = "[redacted]"
    private static let rules: [(NSRegularExpression, String)] = {
        let sources: [(String, String)] = [
            // Header- and assignment-shaped secrets: keep the name, drop the value.
            (#"(?im)^(\s*(?:set-)?cookie\s*[:=]).*$"#, "$1 " + marker),
            (#"(?i)\b(authorization\s*[:=]\s*)(?:bearer|basic|token)?\s*[^\s,;"']+"#, "$1" + marker),
            (#"(?i)\bbearer\s+[A-Za-z0-9._~+/=-]{8,}"#, "Bearer " + marker),
            (#"(?i)((?:api[_-]?key|apikey|access[_-]?key|secret(?:[_-]?key)?|client[_-]?secret|password|passwd|token|access[_-]?token|refresh[_-]?token|id[_-]?token|session[_-]?(?:id|key|token)|cookie|auth)["']?\s*[:=]\s*["']?)[^\s"',;&}]+"#, "$1" + marker),
            // Well-known token shapes, wherever they appear.
            (#"\bsk-[A-Za-z0-9_-]{12,}"#, marker),
            (#"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})"#, marker),
            (#"\bxox[abprs]-[A-Za-z0-9-]{10,}"#, marker),
            (#"\bAKIA[0-9A-Z]{16}\b"#, marker),
            (#"\bAIza[0-9A-Za-z_-]{30,}"#, marker),
            (#"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"#, marker),
            // Account emails.
            (#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, "[email]"),
            // The user's own folder name inside paths.
            (#"/Users/[^/\s"']+"#, "/Users/~"),
            (#"/home/[^/\s"']+"#, "/home/~"),
            // Any other long opaque token: 32+ letters, digits or '_' mixing letters and digits. Dashed UUIDs (crash
            // report image ids, needed for symbolication) have shorter runs and are kept.
            (#"(?<![A-Za-z0-9_])(?=[A-Za-z0-9_]*[0-9])(?=[A-Za-z0-9_]*[A-Za-z])[A-Za-z0-9_]{32,}(?![A-Za-z0-9_])"#, marker),
        ]
        return sources.compactMap { pattern, template in
            (try? NSRegularExpression(pattern: pattern)).map { ($0, template) }
        }
    }()

    public static func redact(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var value = text
        for (expression, template) in rules {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            value = expression.stringByReplacingMatches(in: value, options: [], range: range, withTemplate: template)
        }
        return value
    }
}

/// An append-only log file that rotates by size: `name.log`, then `name.1.log` … `name.(maxFiles-1).log`, oldest
/// last. Every line is redacted before it reaches the disk. Writes are serialized on a private queue so callers on
/// the main thread never wait for the disk; `flush()` waits for the queued lines.
public final class RotatingLogFile: @unchecked Sendable {
    public static let defaultMaxBytes = 5 * 1024 * 1024
    public static let defaultMaxFiles = 5
    /// A single line longer than this is cut, so one runaway line cannot rotate the whole history away.
    public static let maxLineBytes = 8 * 1024

    public let url: URL
    public let maxBytes: Int
    public let maxFiles: Int
    private let queue: DispatchQueue
    private var handle: FileHandle?
    private var size = 0

    public init(url: URL, maxBytes: Int = RotatingLogFile.defaultMaxBytes, maxFiles: Int = RotatingLogFile.defaultMaxFiles) {
        self.url = url
        self.maxBytes = max(1024, maxBytes)
        self.maxFiles = max(1, maxFiles)
        self.queue = DispatchQueue(label: "modelplan.diagnostics." + url.lastPathComponent)
    }
    deinit { try? handle?.close() }

    /// The file for one generation: 0 is the live file.
    public func file(generation: Int) -> URL {
        guard generation > 0 else { return url }
        let base = url.deletingPathExtension().lastPathComponent, ext = url.pathExtension
        let name = ext.isEmpty ? "\(base).\(generation)" : "\(base).\(generation).\(ext)"
        return url.deletingLastPathComponent().appendingPathComponent(name)
    }
    /// Every generation present on disk, newest first.
    public var existingFiles: [URL] {
        flush()
        return (0..<maxFiles).map(file(generation:)).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    public func append(_ line: String) {
        var text = DiagnosticsRedactor.redact(line.replacingOccurrences(of: "\r", with: " "))
        if text.utf8.count > Self.maxLineBytes {
            text = String(decoding: Data(text.utf8.prefix(Self.maxLineBytes)), as: UTF8.self) + " [cut]"
        }
        let data = Data((text + "\n").utf8)
        queue.async { [self] in write(data) }
    }
    public func flush() { queue.sync {} }

    private func write(_ data: Data) {
        if handle == nil { open() }
        if size > 0 && size + data.count > maxBytes { rotate(); open() }
        guard let handle else { return }
        do { try handle.write(contentsOf: data); size += data.count } catch { try? handle.close(); self.handle = nil }
    }
    private func open() {
        let manager = FileManager.default
        let folder = url.deletingLastPathComponent()
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        if !manager.fileExists(atPath: url.path) {
            _ = manager.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        guard let opened = try? FileHandle(forWritingTo: url) else { handle = nil; return }
        size = Int((try? opened.seekToEnd()) ?? 0)
        handle = opened
    }
    private func rotate() {
        try? handle?.close(); handle = nil
        let manager = FileManager.default
        try? manager.removeItem(at: file(generation: maxFiles - 1))
        if maxFiles > 1 {
            for generation in stride(from: maxFiles - 2, through: 0, by: -1) {
                let from = file(generation: generation)
                if manager.fileExists(atPath: from.path) { try? manager.moveItem(at: from, to: file(generation: generation + 1)) }
            }
        } else { try? manager.removeItem(at: url) }
        size = 0
    }
}

/// The app's persistent diagnostics: `ModelPlan.log` (the app's own events, mirrored from the unified log at info
/// and above) and `engine.log` (the engine helper's stderr, start and exit), both rotating, in
/// ~/Library/Logs/ModelPlan. Nothing is written until `configure` names the folder, so tests and other hosts that
/// never configure it keep the old behaviour (unified log only, engine stderr discarded).
///
/// Privacy: callers pass fixed event names, scope ids, cause codes, counts and durations only; never keys, tokens,
/// cookies, prompt or reply text, account emails or ids. Every line also passes `DiagnosticsRedactor`.
public final class DiagnosticsLog: @unchecked Sendable {
    public enum Level: Int, Comparable, Sendable {
        case debug, info, notice, warning, error, fault
        public static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
        var name: String {
            switch self {
            case .debug: return "debug"
            case .info: return "info"
            case .notice: return "notice"
            case .warning: return "warning"
            case .error: return "error"
            case .fault: return "fault"
            }
        }
    }
    public static let shared = DiagnosticsLog()
    public static let subsystem = "org.modelplan.community"
    public static let appLogName = "ModelPlan.log"
    public static let engineLogName = "engine.log"

    private let lock = NSLock()
    private var appFile: RotatingLogFile?
    private var engineFile: RotatingLogFile?
    #if canImport(os)
    private var loggers: [String: Logger] = [:]
    #endif

    public init() {}

    /// Opens (or reopens) both files in `directory`. Call once at launch, before the engine starts.
    public func configure(directory: URL, maxBytes: Int = RotatingLogFile.defaultMaxBytes, maxFiles: Int = RotatingLogFile.defaultMaxFiles) {
        configure(app: RotatingLogFile(url: directory.appendingPathComponent(Self.appLogName), maxBytes: maxBytes, maxFiles: maxFiles),
                  engine: RotatingLogFile(url: directory.appendingPathComponent(Self.engineLogName), maxBytes: maxBytes, maxFiles: maxFiles))
    }
    public func configure(app: RotatingLogFile?, engine: RotatingLogFile?) {
        lock.lock(); appFile = app; engineFile = engine; lock.unlock()
    }
    public var app: RotatingLogFile? { lock.lock(); defer { lock.unlock() }; return appFile }
    public var engine: RotatingLogFile? { lock.lock(); defer { lock.unlock() }; return engineFile }

    /// One app event: to the unified log (unless `systemLog` is false because the caller already wrote it there)
    /// and, at info and above, to ModelPlan.log.
    public func record(_ category: String, _ level: Level, _ message: String, systemLog: Bool = true) {
        if systemLog { emitSystem(category, level, message) }
        guard level >= .info, let file = app else { return }
        file.append(Self.timestamp() + " " + level.name + " [" + category + "] " + message)
    }
    public func info(_ category: String, _ message: String) { record(category, .info, message) }
    public func notice(_ category: String, _ message: String) { record(category, .notice, message) }
    public func error(_ category: String, _ message: String) { record(category, .error, message) }

    /// One line the engine helper wrote to stderr, kept verbatim (after redaction) in engine.log.
    public func engineOutput(pid: Int32, line: String, into file: RotatingLogFile? = nil) {
        guard let file = file ?? engine else { return }
        file.append(Self.timestamp() + " pid=\(pid) " + line)
    }
    /// A start or exit of the helper, in both files so either one tells the story.
    public func engineEvent(pid: Int32, _ message: String, into file: RotatingLogFile? = nil) {
        record("engine", .notice, "pid=\(pid) " + message)
        guard let file = file ?? engine else { return }
        file.append(Self.timestamp() + " pid=\(pid) --- " + message)
    }

    /// The case name of an error: an associated value can carry account or path text, so it is never logged.
    public static func errorName(_ error: Error) -> String {
        if case EngineClientError.rpc(let code, _) = error { return "rpc.\(code)" }
        let mirror = Mirror(reflecting: error)
        guard mirror.displayStyle == .enum else { return String(describing: type(of: error)) }
        return mirror.children.first?.label ?? String(describing: error)
    }
    /// A short identifier that is safe to log: lowercase letters, digits and `._:-`, at most 64 characters.
    /// Anything else becomes "other".
    public static func safeID(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789._:-")
        let lowered = value.lowercased()
        guard !lowered.isEmpty, lowered.count <= 64, lowered.allSatisfy(allowed.contains) else { return "other" }
        return lowered
    }

    private static let formatter: ISO8601DateFormatter = {
        let value = ISO8601DateFormatter()
        value.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        value.timeZone = .current
        return value
    }()
    private static let formatterLock = NSLock()
    static func timestamp(_ date: Date = Date()) -> String {
        formatterLock.lock(); defer { formatterLock.unlock() }
        return formatter.string(from: date)
    }

    private func emitSystem(_ category: String, _ level: Level, _ message: String) {
        #if canImport(os)
        lock.lock()
        let logger: Logger
        if let cached = loggers[category] { logger = cached } else {
            logger = Logger(subsystem: Self.subsystem, category: category); loggers[category] = logger
        }
        lock.unlock()
        switch level {
        case .debug: logger.debug("\(message, privacy: .public)")
        case .info: logger.info("\(message, privacy: .public)")
        case .notice: logger.notice("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        case .fault: logger.fault("\(message, privacy: .public)")
        }
        #endif
    }
}
