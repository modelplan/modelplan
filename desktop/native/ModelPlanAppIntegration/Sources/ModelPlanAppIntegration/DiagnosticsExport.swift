// SPDX-License-Identifier: MIT
import AppKit
import UniformTypeIdentifiers
import ModelPlanEngineClient
import ModelPlanSettings

/// Everything one diagnostics file is made from. Plain inputs, so a test builds a bundle from synthetic files.
public struct DiagnosticsBundleInputs: Sendable {
    /// ModelPlan.log, engine.log and their rotated generations.
    public var logFiles: [URL]
    /// ~/Library/Logs/DiagnosticReports; only ModelPlan's own reports are taken from it.
    public var crashReports: URL
    /// The bundled engine, asked for `doctor readers --json`; nil leaves that file out.
    public var helper: URL?
    /// The engine child's own environment (HOME, TMPDIR, PATH, profile root), never the app's whole environment.
    public var helperEnvironment: [String: String]
    /// Versions, macOS, reader ids and error codes: Settings' "Copy diagnostics" text.
    public var summary: String
    public var now: Date
    public var crashReportMaxAge: TimeInterval = 14 * 24 * 3600
    public var maxCrashReports = 10
    public var doctorTimeout: TimeInterval = 20

    public init(logFiles: [URL], crashReports: URL, helper: URL?, helperEnvironment: [String: String], summary: String, now: Date = Date()) {
        self.logFiles = logFiles; self.crashReports = crashReports; self.helper = helper
        self.helperEnvironment = helperEnvironment; self.summary = summary; self.now = now
    }

    /// The running app's inputs: its log files (flushed), the user's crash report folder and the bundled engine.
    public static func live(helper: URL?, helperEnvironment: [String: String], summary: String) -> DiagnosticsBundleInputs {
        let logs = [DiagnosticsLog.shared.app, DiagnosticsLog.shared.engine].compactMap { $0 }.flatMap(\.existingFiles)
        let reports = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
        return .init(logFiles: logs, crashReports: reports, helper: helper, helperEnvironment: helperEnvironment, summary: summary)
    }
}

/// Builds the diagnostics zip. Every text file passes `DiagnosticsRedactor` on the way in, whatever wrote it;
/// nothing is sent anywhere: the user saves the file and decides whom to give it to.
public enum DiagnosticsBundle {
    public static let title = SettingsText("Export diagnostics", "导出诊断包")
    public static let disclosure = SettingsText(
        "The diagnostics file contains:\n• ModelPlan app and engine logs\n• ModelPlan crash reports from the last 14 days\n• Reader status reported by the engine (states and error codes only)\n• App, engine and macOS versions\n\nIt never contains API keys, tokens, sign-in cookies, prompts or replies, or account emails and ids. Text in a log that looks like a key or token is replaced before saving.\n\nNothing is uploaded: you choose where to save the file and whom to send it to.",
        "诊断包包含：\n• ModelPlan 应用日志与引擎日志\n• 最近 14 天的 ModelPlan 崩溃报告\n• 引擎报告的读取状态（只有状态和错误代码）\n• 应用、引擎与 macOS 版本\n\n其中不会包含 API 密钥、token、登录凭据、提示词或回复、账户邮箱或账户标识。日志里看起来像密钥或 token 的文字会在保存前被替换。\n\n不会上传：由你选择保存位置，也由你决定发给谁。")
    public static let chooseLocation = SettingsText("Choose Location…", "选择保存位置…")
    public static let cancel = SettingsText("Cancel", "取消")
    public static let failed = SettingsText("Could not export diagnostics. Nothing was saved.", "无法导出诊断包，未保存任何文件。")

    /// The file names inside the bundle, for the README and the tests.
    public static let readmeName = "README.txt", versionsName = "versions.txt", doctorName = "doctor-readers.json"
    public static let logsFolder = "logs", crashFolder = "crash-reports"
    static let maxTextBytes = 8 * 1024 * 1024
    static let crashExtensions: Set<String> = ["ips", "crash", "diag", "hang", "spin"]

    public static func defaultName(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "ModelPlan-diagnostics-" + formatter.string(from: date)
    }

    /// ModelPlan's own crash reports: the app (ModelPlan…) and the engine helper (modelplan…).
    static func isOurCrashReport(_ url: URL) -> Bool {
        url.lastPathComponent.lowercased().hasPrefix("modelplan") && crashExtensions.contains(url.pathExtension.lowercased())
    }

    /// Writes the bundle's files into `folder`; returns their paths relative to it, sorted.
    @discardableResult
    public static func stage(_ inputs: DiagnosticsBundleInputs, into folder: URL) throws -> [String] {
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var written: [String] = []
        func put(_ text: String, _ relative: String) throws {
            let url = folder.appendingPathComponent(relative)
            try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(DiagnosticsRedactor.redact(text).utf8).write(to: url, options: .atomic)
            written.append(relative)
        }
        func readText(_ url: URL) -> String? {
            guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
            defer { try? handle.close() }
            guard let data = try? handle.read(upToCount: DiagnosticsBundle.maxTextBytes) else { return nil }
            return String(decoding: data, as: UTF8.self)
        }

        let stamp = ISO8601DateFormatter().string(from: inputs.now)
        try put(readme(generated: stamp), readmeName)
        let osBuild = ProcessInfo.processInfo.operatingSystemVersionString
        let info = Bundle.main.infoDictionary ?? [:]
        let bundleVersion = [info["CFBundleShortVersionString"], info["CFBundleVersion"]].compactMap { $0 as? String }.joined(separator: " ")
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        try put("generated=\(stamp)\nappBundle=\(bundleVersion.isEmpty ? "unknown" : bundleVersion)\n\(inputs.summary)\nmacOSBuild=\(osBuild)\narch=\(architecture)\n", versionsName)

        var seen = Set<String>()
        for url in inputs.logFiles where seen.insert(url.lastPathComponent).inserted {
            if let text = readText(url) { try put(text, logsFolder + "/" + url.lastPathComponent) }
        }

        let cutoff = inputs.now.addingTimeInterval(-inputs.crashReportMaxAge)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        let reports = ((try? manager.contentsOfDirectory(at: inputs.crashReports, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? [])
            .filter { DiagnosticsBundle.isOurCrashReport($0) }
            .compactMap { url -> (URL, Date)? in
                guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true,
                      let date = values.contentModificationDate, date >= cutoff else { return nil }
                return (url, date)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(inputs.maxCrashReports)
        for (url, _) in reports {
            if let text = readText(url) { try put(text, crashFolder + "/" + url.lastPathComponent) }
        }

        if let helper = inputs.helper {
            let result = runDoctor(helper: helper, environment: inputs.helperEnvironment, timeout: inputs.doctorTimeout)
            if let output = result.output { try put(output, doctorName) }
            else { try put("doctor readers unavailable: \(result.status)\n", "doctor-readers.txt") }
        }
        return written.sorted()
    }

    /// Zips a staged folder (macOS `ditto`, the Finder's own archive format) to `destination`.
    public static func zip(_ folder: URL, to destination: URL) throws {
        let manager = FileManager.default
        let partial = destination.deletingLastPathComponent().appendingPathComponent("." + destination.lastPathComponent + ".partial")
        try? manager.removeItem(at: partial)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", folder.path, partial.path]
        process.standardInput = FileHandle.nullDevice; process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            try? manager.removeItem(at: partial)
            throw CocoaError(.fileWriteUnknown)
        }
        if manager.fileExists(atPath: destination.path) { try manager.removeItem(at: destination) }
        try manager.moveItem(at: partial, to: destination)
    }

    /// Stages into a private temporary folder, zips to `destination`, and removes the staging folder.
    @discardableResult
    public static func export(_ inputs: DiagnosticsBundleInputs, to destination: URL) throws -> [String] {
        let name = destination.deletingPathExtension().lastPathComponent
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("modelplan-diagnostics-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let folder = scratch.appendingPathComponent(name.isEmpty ? defaultName(inputs.now) : name, isDirectory: true)
        let files = try stage(inputs, into: folder)
        try zip(folder, to: destination)
        return files
    }

    static func readme(generated: String) -> String {
        """
        ModelPlan diagnostics (generated \(generated))

        \(versionsName)       app, engine and macOS versions; reader ids and error codes
        \(logsFolder)/              ModelPlan.log (app events) and engine.log (engine helper output, start and exit), with rotated copies
        \(crashFolder)/     ModelPlan crash reports from the last 14 days, if any
        \(doctorName)  `modelplan doctor readers --json`: reader states and fixed error codes

        Never included: API keys, tokens, cookies, prompt or reply text, account emails or ids.
        Every file was passed through a redaction step that replaces anything shaped like a key, token,
        cookie or email address, and the user folder name in paths, with [redacted], [email] or ~.
        Nothing was uploaded. This file was saved by you and goes only where you send it.

        """
    }

    /// Runs the engine's read-only reader report. Never refreshes and never shows output on screen.
    static func runDoctor(helper: URL, environment: [String: String], timeout: TimeInterval) -> (output: String?, status: String) {
        guard FileManager.default.isExecutableFile(atPath: helper.path) else { return (nil, "helper_missing") }
        let process = Process(), pipe = Pipe()
        process.executableURL = helper
        process.arguments = ["doctor", "readers", "--json"]
        process.environment = environment
        process.standardInput = FileHandle.nullDevice; process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return (nil, "launch_failed") }
        let done = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable { var data = Data() }
        let box = Box()
        DispatchQueue.global(qos: .utility).async {
            box.data = (try? pipe.fileHandleForReading.read(upToCount: DiagnosticsBundle.maxTextBytes)) ?? Data()
            // Keep draining so a chatty child is never blocked on a full pipe.
            while let more = try? pipe.fileHandleForReading.read(upToCount: 64 * 1024), !more.isEmpty {}
            done.signal()
        }
        if done.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            _ = done.wait(timeout: .now() + 2)
            return (nil, "timeout")
        }
        process.waitUntilExit()
        guard process.terminationReason == .exit else { return (nil, "signal_\(process.terminationStatus)") }
        guard !box.data.isEmpty else { return (nil, "exit_\(process.terminationStatus)_no_output") }
        return (String(decoding: box.data, as: UTF8.self), "exit_\(process.terminationStatus)")
    }
}

/// Settings → Diagnostics → Export diagnostics…: say what is included, let the user pick where to save, then
/// write the file off the main thread and show it in the Finder.
@MainActor public enum DiagnosticsExportFlow {
    public static func present(language: SettingsLanguage, inputs: @escaping @Sendable () -> DiagnosticsBundleInputs) {
        NSApplication.shared.activate()
        let alert = NSAlert()
        alert.messageText = DiagnosticsBundle.title.value(language)
        alert.informativeText = DiagnosticsBundle.disclosure.value(language)
        alert.addButton(withTitle: DiagnosticsBundle.chooseLocation.value(language))
        alert.addButton(withTitle: DiagnosticsBundle.cancel.value(language))
        guard alert.runModal() == .alertFirstButtonReturn else {
            DiagnosticsLog.shared.info("settings", "diagnostics export cancelled at disclosure"); return
        }
        let panel = NSSavePanel()
        panel.title = DiagnosticsBundle.title.value(language)
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = DiagnosticsBundle.defaultName() + ".zip"
        guard panel.runModal() == .OK, let destination = panel.url else {
            DiagnosticsLog.shared.info("settings", "diagnostics export cancelled at save panel"); return
        }
        DiagnosticsLog.shared.notice("settings", "diagnostics export started")
        Task.detached(priority: .userInitiated) {
            let started = Date()
            do {
                let files = try DiagnosticsBundle.export(inputs(), to: destination)
                let ms = Int(Date().timeIntervalSince(started) * 1000)
                await MainActor.run {
                    DiagnosticsLog.shared.notice("settings", "diagnostics export finished files=\(files.count) ms=\(ms)")
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                }
            } catch {
                await MainActor.run {
                    DiagnosticsLog.shared.error("settings", "diagnostics export failed error=\(DiagnosticsLog.errorName(error))")
                    let failure = NSAlert()
                    failure.alertStyle = .warning
                    failure.messageText = DiagnosticsBundle.failed.value(language)
                    failure.runModal()
                }
            }
        }
    }
}
