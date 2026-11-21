// SPDX-License-Identifier: MIT
import Foundation

/// macOS memory pressure (`kern.memorystatus_vm_pressure_level`: 1 normal, 2 warn, 4 critical).
public enum ResourcePressure: String, Equatable, Sendable { case normal, warn, critical }

/// One reading of this Mac. Percentages are of all cores together (0–100); sizes are bytes.
/// `uptime` (monotonic seconds) drives the rules; `unixMs` is only the page's time axis.
public struct ResourceSample: Equatable, Sendable {
    public var unixMs: Int64
    public var uptime: TimeInterval
    public var cpuUser: Double, cpuSystem: Double, load: Double
    public var memTotal: UInt64, memApp: UInt64, memWired: UInt64, memCompressed: UInt64, memCached: UInt64, memFree: UInt64
    public var swapUsed: UInt64
    public var pressure: ResourcePressure
    public var diskTotal: UInt64, diskFree: UInt64
    public init(unixMs: Int64, uptime: TimeInterval, cpuUser: Double, cpuSystem: Double, load: Double,
                memTotal: UInt64, memApp: UInt64, memWired: UInt64, memCompressed: UInt64, memCached: UInt64, memFree: UInt64,
                swapUsed: UInt64, pressure: ResourcePressure, diskTotal: UInt64, diskFree: UInt64) {
        self.unixMs = unixMs; self.uptime = uptime; self.cpuUser = cpuUser; self.cpuSystem = cpuSystem; self.load = load
        self.memTotal = memTotal; self.memApp = memApp; self.memWired = memWired; self.memCompressed = memCompressed
        self.memCached = memCached; self.memFree = memFree; self.swapUsed = swapUsed; self.pressure = pressure
        self.diskTotal = diskTotal; self.diskFree = diskFree
    }
    public var cpu: Double { min(100, max(0, cpuUser + cpuSystem)) }
    /// Used = app + wired + compressed (Activity Monitor's "Memory Used"); cached memory is not used.
    public var memoryUsed: UInt64 { memApp + memWired + memCompressed }
    public var memoryPercent: Double { memTotal == 0 ? 0 : min(100, Double(memoryUsed) / Double(memTotal) * 100) }
    public var cachedPercent: Double { memTotal == 0 ? 0 : min(100, Double(memCached) / Double(memTotal) * 100) }
    public var diskPercent: Double { diskTotal == 0 ? 0 : Double(diskTotal - min(diskFree, diskTotal)) / Double(diskTotal) * 100 }
}

public enum ResourceLanguage: Sendable { case english, chinese }

/// Number and size formatting shared by the card and the page (resource-plugin.ts `gb`).
enum ResourceFormat {
    static func gb(_ bytes: UInt64) -> String {
        let g = Double(bytes) / Double(1 << 30)
        let r = g >= 100 ? g.rounded() : (g * 10).rounded() / 10
        return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
    }
}

/// The page's `pluginData` body for the resource plugin (desktop/cockpit/src/resource-plugin.ts accepts exactly this).
public enum ResourcePagePayload {
    public static func data(_ samples: [ResourceSample]) -> [String: Any] {
        func p(_ v: Double) -> Double { (min(100, max(0, v)) * 10).rounded() / 10 }
        func b(_ v: UInt64) -> Int { Int(min(v, UInt64(1) << 53)) }
        return ["samples": samples.map { s -> [String: Any] in
            ["t": Int(s.unixMs), "cpuUser": p(s.cpuUser), "cpuSystem": p(min(s.cpuSystem, 100 - p(s.cpuUser))),
             "load": (max(0, min(4096, s.load)) * 100).rounded() / 100,
             "memTotal": b(s.memTotal), "memApp": b(s.memApp), "memWired": b(s.memWired), "memCompressed": b(s.memCompressed),
             "memCached": b(s.memCached), "memFree": b(s.memFree), "swapUsed": b(s.swapUsed), "pressure": s.pressure.rawValue,
             "diskTotal": b(s.diskTotal), "diskFree": b(min(s.diskFree, s.diskTotal))]
        }]
    }
}
