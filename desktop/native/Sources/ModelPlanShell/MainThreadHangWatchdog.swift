// SPDX-License-Identifier: MIT
import Foundation
import os

// Spec 5.3 D (behaviour from CodexBar `MainThreadHangWatchdog`, own code and names): an opt-in background thread
// pings the main thread and reports when it does not answer for 150 ms, with the static activity labels pushed on the
// main thread at that time. After 2 s of one hang it takes one `/usr/bin/sample` of this process, at most once every
// 5 minutes, into ~/Library/Logs/ModelPlan (mode 0600, newest 10 kept).
//
// Release builds: off unless MODELPLAN_MAIN_THREAD_HANG_WATCHDOG=1 or the defaults key `debugMainThreadHangWatchdog`.
// Debug builds: on unless that variable is "0". Never while MODELPLAN_TESTING is set or XCTest is loaded, so test
// runs get no extra thread (CodexBar enables it in every debug process; we do not copy that).
//
// Privacy: labels are `StaticString` literals only (never data). A sample file holds stack symbols and may hold paths;
// it stays on this Mac, is never uploaded and is not part of a diagnostics export.

/// Static labels of what the main thread is doing, for the hang watchdog. Push/pop are a single flag read when off.
public enum MainThreadActivityBreadcrumb {
    final class Stack: @unchecked Sendable {
        let lock = NSLock()
        var enabled = false
        var labels: [StaticString] = []
    }
    static let stack = Stack()
    public static func push(_ label: StaticString) {
        let stack = Self.stack
        stack.lock.lock(); defer { stack.lock.unlock() }
        guard stack.enabled else { return }
        stack.labels.append(label)
    }
    public static func pop() {
        let stack = Self.stack
        stack.lock.lock(); defer { stack.lock.unlock() }
        guard stack.enabled, !stack.labels.isEmpty else { return }
        stack.labels.removeLast()
    }
    /// The innermost label, or nil.
    public static func current() -> String? {
        let stack = Self.stack
        stack.lock.lock(); defer { stack.lock.unlock() }
        return stack.labels.last.map { "\($0)" }
    }
    static func setEnabled(_ on: Bool) {
        let stack = Self.stack
        stack.lock.lock(); defer { stack.lock.unlock() }
        stack.enabled = on
        if !on { stack.labels.removeAll() }
    }
    public static var isEnabled: Bool {
        let stack = Self.stack
        stack.lock.lock(); defer { stack.lock.unlock() }
        return stack.enabled
    }
}

/// The watchdog's decisions, free of threads and clocks so they are tested with fake time.
public struct MainThreadHangDetector: Equatable {
    public static let pingMilliseconds: UInt64 = 25
    public static let hangMilliseconds: UInt64 = 150
    public static let sampleAfterMilliseconds: UInt64 = 2_000
    public static let sampleCooldownMilliseconds: UInt64 = 300_000
    public static let maximumLabels = 8
    public enum Action: Equatable { case sample, report(durationMs: UInt64, activity: [String]) }
    private var pingSentAt: UInt64?
    private var labels: [String] = []
    private var sampledThisHang = false
    private var lastSampleAt: UInt64?
    public init() {}
    public var waiting: Bool { pingSentAt != nil }
    public mutating func pingSent(at now: UInt64) {
        pingSentAt = now; labels = []; sampledThisHang = false
    }
    /// One poll while a ping is out: `answered` when the main thread ran the ping, `activity` its current label.
    public mutating func observe(now: UInt64, answered: Bool, activity: String?) -> [Action] {
        guard let sent = pingSentAt else { return [] }
        let elapsed = now >= sent ? now - sent : 0
        if answered {
            pingSentAt = nil
            defer { labels = []; sampledThisHang = false }
            return elapsed >= Self.hangMilliseconds ? [.report(durationMs: elapsed, activity: labels)] : []
        }
        if let activity, !labels.contains(activity), labels.count < Self.maximumLabels { labels.append(activity) }
        guard elapsed >= Self.sampleAfterMilliseconds, !sampledThisHang,
              lastSampleAt.map({ now >= $0 && now - $0 >= Self.sampleCooldownMilliseconds }) ?? true else { return [] }
        sampledThisHang = true; lastSampleAt = now
        return [.sample]
    }
}

public final class MainThreadHangWatchdog: @unchecked Sendable {
    public static let shared = MainThreadHangWatchdog()
    static let log = Logger(subsystem: "org.modelplan.community", category: "hang-watchdog")
    public static let environmentKey = "MODELPLAN_MAIN_THREAD_HANG_WATCHDOG"
    public static let defaultsKey = "debugMainThreadHangWatchdog"
    public static let testingKey = "MODELPLAN_TESTING"
    private let lock = NSLock()
    private var thread: Thread?
    private var running = false

    public init() {}

    public static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment,
                                 defaults: UserDefaults = .standard, underTest: Bool = MainThreadHangWatchdog.runningUnderXCTest) -> Bool {
        guard environment[testingKey] == nil, !underTest else { return false }
        if environment[environmentKey] == "1" || defaults.bool(forKey: defaultsKey) { return true }
        #if DEBUG
        return environment[environmentKey] != "0"
        #else
        return false
        #endif
    }

    /// A test process (XCTest loaded) never gets the thread, whatever the build configuration.
    public static var runningUnderXCTest: Bool { NSClassFromString("XCTestCase") != nil }

    public var isRunning: Bool { lock.lock(); defer { lock.unlock() }; return running }

    /// Starts the thread only when enabled; otherwise nothing at all happens.
    public func startIfEnabled(environment: [String: String] = ProcessInfo.processInfo.environment,
                               defaults: UserDefaults = .standard) {
        guard Self.isEnabled(environment: environment, defaults: defaults) else { return }
        start()
    }

    func start() {
        lock.lock()
        guard !running else { lock.unlock(); return }
        running = true
        lock.unlock()
        MainThreadActivityBreadcrumb.setEnabled(true)
        let thread = Thread { [weak self] in self?.loop() }
        thread.name = "ModelPlan.MainThreadHangWatchdog"
        thread.qualityOfService = .utility
        lock.lock(); self.thread = thread; lock.unlock()
        thread.start()
    }

    public func stop() {
        lock.lock(); running = false; thread = nil; lock.unlock()
        MainThreadActivityBreadcrumb.setEnabled(false)
    }

    private static func nowMilliseconds() -> UInt64 { DispatchTime.now().uptimeNanoseconds / 1_000_000 }

    private func loop() {
        var detector = MainThreadHangDetector()
        while isRunning {
            let answered = DispatchSemaphore(value: 0)
            detector.pingSent(at: Self.nowMilliseconds())
            DispatchQueue.main.async { answered.signal() }
            var done = false
            while !done && isRunning {
                let result = answered.wait(timeout: .now() + .milliseconds(Int(MainThreadHangDetector.pingMilliseconds)))
                done = result == .success
                for action in detector.observe(now: Self.nowMilliseconds(), answered: done,
                                               activity: MainThreadActivityBreadcrumb.current()) {
                    perform(action)
                }
            }
            // macrev2-976-4: the next ping goes out one ping interval (25 ms) after the answer, as in the reference, so a
            // 150 ms stall cannot fall between two pings.
            Thread.sleep(forTimeInterval: Double(MainThreadHangDetector.pingMilliseconds) / 1_000)
        }
    }

    private func perform(_ action: MainThreadHangDetector.Action) {
        switch action {
        case .report(let duration, let activity):
            let labels = activity.joined(separator: ",")
            Self.log.notice("main thread hang durationMs=\(duration, privacy: .public) activity=\(labels, privacy: .public)")
        case .sample:
            Self.sample()
        }
    }

    static func logsDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/ModelPlan", isDirectory: true)
    }

    /// One `sample` of this process for 3 s, then only the newest 10 sample files are kept.
    private static func sample() {
        let directory = logsDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let file = directory.appendingPathComponent("hang-sample-\(stamp).txt")
        FileManager.default.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sample")
        process.arguments = [String(ProcessInfo.processInfo.processIdentifier), "3", "-file", file.path]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            pruneSamples(in: directory, keep: 10)
        }
        do { try process.run() } catch { log.error("main thread hang sample unavailable") }
    }

    static func pruneSamples(in directory: URL, keep: Int) {
        let files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("hang-sample-") && $0.pathExtension == "txt" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for stale in files.dropFirst(keep) { try? FileManager.default.removeItem(at: stale) }
    }
}
