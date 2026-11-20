// SPDX-License-Identifier: MIT
import Foundation

/// Reads one sample. The system reader uses system calls only (never a child process).
public protocol ResourceReader: AnyObject {
    func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample?
}

/// Cancels one armed timer.
public struct ResourceTimerHandle {
    private let cancelAction: @MainActor () -> Void
    public init(cancel: @escaping @MainActor () -> Void) { cancelAction = cancel }
    @MainActor public func cancel() { cancelAction() }
}

/// The app's one resource sampler (D324). It owns a single coalesced one-shot timer whose interval follows the
/// visibility (ResourceCadence), asks ResourceSchedule before every read, keeps the ten-minute history in memory,
/// updates the widget readout and redraws the widget only on a ≥ 1 % change. Turning the plugin off stops the timer
/// and drops the history.
@MainActor public final class ResourceSampler {
    public typealias Clock = @MainActor () -> TimeInterval
    public typealias Scheduler = @MainActor (_ delay: TimeInterval, _ tolerance: TimeInterval, _ fire: @escaping @MainActor () -> Void) -> ResourceTimerHandle

    public private(set) var visibility = ResourceVisibility(pluginEnabled: false, columnShown: false, widgetShown: false, columnSetting: 5)
    public private(set) var history = ResourceHistory()
    public private(set) var face: ResourceFace?
    public private(set) var shown: ResourceShown?
    /// Every admitted sample (the cockpit host pushes it to the page through ResourcePageFeed).
    public var onSample: ((ResourceSample) -> Void)?
    /// The widget ring and readout, only when they changed by at least one percentage point (or the readout changed).
    public var onRedraw: ((ResourceFace) -> Void)?

    private let reader: ResourceReader
    private let clock: Clock
    private let scheduler: Scheduler
    private let reduceMotion: () -> Bool
    private let wallClock: () -> Int64
    private var schedule = ResourceSchedule()
    private var readout = ResourceReadout()
    private var gate = ResourceRedrawGate()
    private var timer: ResourceTimerHandle?

    public init(reader: ResourceReader, clock: @escaping Clock = { ProcessInfo.processInfo.systemUptime },
                scheduler: @escaping Scheduler = ResourceSampler.dispatchTimer, reduceMotion: @escaping () -> Bool = { false },
                wallClock: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }) {
        self.reader = reader; self.clock = clock; self.scheduler = scheduler; self.reduceMotion = reduceMotion; self.wallClock = wallClock
    }

    /// Report every change of plugin state, cockpit column (`pluginsRunning`) or widget visibility.
    public func setVisibility(_ next: ResourceVisibility) {
        visibility = next
        let delay = schedule.update(next, now: clock())
        if !next.pluginEnabled {
            // The last sample time stays (only a time, no reading), so switching off and on never samples sooner
            // than the cadence allows (60 s while nothing is visible).
            history.removeAll(); readout.reset(); gate.reset(); face = nil; shown = nil
        }
        arm(delay)
    }

    public func stop() { timer?.cancel(); timer = nil }

    private func arm(_ delay: TimeInterval?) {
        timer?.cancel(); timer = nil
        guard let delay, let interval = schedule.interval else { return }
        timer = scheduler(delay, ResourceCadence.tolerance(interval)) { [weak self] in self?.fire() }
    }

    private func fire() {
        timer = nil
        let now = clock()
        if schedule.admit(now: now), let sample = reader.read(uptime: now, unixMs: wallClock()) {
            history.append(sample)
            let shown = readout.step(sample)
            self.shown = shown
            let face = ResourceFace(sample: sample, shown: shown, reduceMotion: reduceMotion())
            self.face = face
            onSample?(sample)
            if gate.admit(face) { onRedraw?(face) }
        }
        arm(schedule.delay(now: clock()))
    }

    /// A one-shot GCD timer on the main queue with leeway, so the system can coalesce its wake-ups.
    public static func dispatchTimer(_ delay: TimeInterval, _ tolerance: TimeInterval, _ fire: @escaping @MainActor () -> Void) -> ResourceTimerHandle {
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + max(0, delay), repeating: .never, leeway: .milliseconds(Int((tolerance * 1000).rounded())))
        source.setEventHandler { MainActor.assumeIsolated { fire() } }
        source.resume()
        return ResourceTimerHandle { source.cancel() }
    }
}
