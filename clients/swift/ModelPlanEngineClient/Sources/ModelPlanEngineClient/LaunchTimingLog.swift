// SPDX-License-Identifier: MIT
import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// WP-17 (G3-123): the cold-start path, one line per stage and only the first time it happens in this process:
/// `timing launch stage=<name> uptimeMs=<monotonic> sinceStartMs=<since the process was started>`, in ModelPlan.log
/// (category `lifecycle`) and the unified log. Measurement only: nothing waits on it and nothing reads it back.
///
/// `uptimeMs` is the monotonic clock (`systemUptime`), the same clock as the cockpit's open and close stages, so a
/// summary can line the two up. `sinceStartMs` counts from the kernel's start time of this process (so it includes the
/// dynamic loader and everything before `main`); when that cannot be read it counts from the first stage instead.
///
/// Privacy: stage names, tool ids (`DiagnosticsLog.safeID`) and numbers only; never account data, paths or error text.
public final class LaunchTimingLog: @unchecked Sendable {
    public static let shared = LaunchTimingLog()

    private let lock = NSLock()
    private let now: () -> TimeInterval
    private let processStart: () -> TimeInterval?
    private var origin: TimeInterval?
    private var marked: Set<String> = []
    private let sink: (String) -> Void

    public convenience init() {
        self.init(now: { ProcessInfo.processInfo.systemUptime }, processStart: LaunchTimingLog.processStartUptime,
                  sink: { DiagnosticsLog.shared.record("lifecycle", .notice, $0) })
    }
    /// Test seam: an injected monotonic clock, process start and line sink.
    init(now: @escaping () -> TimeInterval, processStart: @escaping () -> TimeInterval?, sink: @escaping (String) -> Void) {
        self.now = now; self.processStart = processStart; self.sink = sink
    }

    /// Records `stage` once per process; later calls with the same stage are ignored. `detail` is extra `key=value`
    /// tokens (counts and milliseconds only). Returns the line written, or nil when the stage was already recorded.
    @discardableResult
    public func mark(_ stage: String, detail: String = "") -> String? {
        let at = now()
        lock.lock()
        guard marked.insert(stage).inserted else { lock.unlock(); return nil }
        if origin == nil { origin = processStart().flatMap { $0 <= at ? $0 : nil } ?? at }
        let since = Self.ms(at - (origin ?? at))
        lock.unlock()
        let line = "timing launch stage=\(stage) uptimeMs=\(Self.ms(at)) sinceStartMs=\(since)" + (detail.isEmpty ? "" : " " + detail)
        sink(line)
        return line
    }
    /// A tool's stage: the tool id is reduced to a safe identifier and joined to the stage name with a dot.
    @discardableResult
    public func mark(_ stage: String, tool: String, detail: String = "") -> String? {
        mark(stage + "." + DiagnosticsLog.safeID(tool), detail: detail)
    }

    static func ms(_ seconds: TimeInterval) -> Int { max(0, Int((seconds * 1_000).rounded())) }

    /// The process start on the monotonic clock: now minus how long ago the kernel started this process. The wall-clock
    /// difference is read once, right away, so a later clock change cannot move it by more than that read takes.
    static func processStartUptime() -> TimeInterval? {
        #if canImport(Darwin)
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let start = info.kp_proc.p_un.__p_starttime
        let started = Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
        let uptime = ProcessInfo.processInfo.systemUptime
        let age = Date().timeIntervalSince1970 - started
        guard age >= 0, age < 3_600 else { return nil }
        return uptime - age
        #else
        return nil
        #endif
    }
}
