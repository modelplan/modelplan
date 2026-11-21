// SPDX-License-Identifier: MIT
import Foundation
@testable import ModelPlanResources

let GB: UInt64 = 1 << 30
func gb(_ value: Double) -> UInt64 { UInt64((value * Double(GB)).rounded()) }

/// The board's "normal" state: memory 47 % (15.1 / 32 GB used, 12.8 GB cached), CPU 22 %, disk 76 %.
func sample(at uptime: TimeInterval = 0, cpuUser: Double = 19, cpuSystem: Double = 3,
            pressure: ResourcePressure = .normal, diskFree: Double = 120, used: (app: Double, wired: Double, compressed: Double) = (9.2, 4.5, 1.4),
            cached: Double = 12.8, swap: Double = 0) -> ResourceSample {
    let total = gb(32), usedBytes = gb(used.app) + gb(used.wired) + gb(used.compressed), cachedBytes = gb(cached)
    return ResourceSample(unixMs: 1_795_000_000_000 + Int64(uptime * 1000), uptime: uptime, cpuUser: cpuUser, cpuSystem: cpuSystem, load: 2.4,
                          memTotal: total, memApp: gb(used.app), memWired: gb(used.wired), memCompressed: gb(used.compressed),
                          memCached: cachedBytes, memFree: total > usedBytes + cachedBytes ? total - usedBytes - cachedBytes : 0,
                          swapUsed: gb(swap), pressure: pressure, diskTotal: gb(494), diskFree: gb(diskFree))
}
func cpu(_ percent: Double, at uptime: TimeInterval, pressure: ResourcePressure = .normal) -> ResourceSample {
    sample(at: uptime, cpuUser: percent * 0.75, cpuSystem: percent * 0.25, pressure: pressure)
}

/// A reader that counts reads and returns the fixture at the clock's time.
final class CountingReader: ResourceReader {
    var reads: [TimeInterval] = []
    func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? { reads.append(uptime); return sample(at: uptime) }
}

/// Manual timers and clock: `run(until:)` fires due timers in order, each at its deadline plus `lateness`
/// (a coalesced timer fires late, never early).
@MainActor final class ManualTimers {
    private struct Pending { let id: Int; let deadline: TimeInterval; let fire: @MainActor () -> Void }
    private var pending: [Pending] = []
    private var nextID = 0
    private(set) var tolerances: [TimeInterval] = []
    var now: TimeInterval = 0
    var lateness: TimeInterval = 0
    var clock: ResourceSampler.Clock { { [unowned self] in self.now } }
    var scheduler: ResourceSampler.Scheduler {
        { [unowned self] delay, tolerance, fire in
            self.nextID += 1
            let id = self.nextID
            self.tolerances.append(tolerance)
            self.pending.append(Pending(id: id, deadline: self.now + delay, fire: fire))
            return ResourceTimerHandle { [weak self] in self?.pending.removeAll { $0.id == id } }
        }
    }
    var armed: Int { pending.count }
    func run(until end: TimeInterval) {
        while let next = pending.min(by: { $0.deadline < $1.deadline }), next.deadline + lateness <= end {
            pending.removeAll { $0.id == next.id }
            now = max(now, next.deadline + lateness)
            next.fire()
        }
        now = max(now, end)
    }
}
