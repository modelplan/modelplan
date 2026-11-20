// SPDX-License-Identifier: MIT
#if canImport(Darwin)
import Darwin
import Foundation

/// Reads this Mac with system calls only (D324): host_processor_info (CPU ticks), host_statistics64 (HOST_VM_INFO64),
/// sysctlbyname (memory pressure, swap), getloadavg and statfs. It never starts a child process.
///
/// Memory follows Stats (exelban/Stats Modules/RAM/readers.swift, the macOS reference for resource readers):
/// used = active + inactive + speculative + wired + compressed − purgeable − external; app = used − wired − compressed;
/// cached = purgeable + external; free = total − used − cached. CPU is the share of user and system ticks across all
/// cores since the previous read (Stats Modules/CPU/readers.swift).
public final class SystemResourceReader: ResourceReader {
    private let host: mach_port_t
    private let pageSize: UInt64
    private let memTotal: UInt64
    private let diskPath: String
    /// Per core: user, system, idle, nice ticks at the previous read.
    private var previous: [[UInt32]] = []

    public init(diskPath: String? = nil) {
        host = mach_host_self()
        pageSize = UInt64(vm_kernel_page_size)
        memTotal = ProcessInfo.processInfo.physicalMemory
        // The data volume holds the user's files; "/" is the sealed system volume.
        let data = "/System/Volumes/Data"
        self.diskPath = diskPath ?? (FileManager.default.fileExists(atPath: data) ? data : "/")
        previous = ticks() ?? []
    }
    deinit { mach_port_deallocate(mach_task_self_, host) }

    public func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? {
        guard let cpu = readCPU(), let memory = readMemory(), let disk = readDisk() else { return nil }
        var loads = [Double](repeating: 0, count: 3)
        let load = getloadavg(&loads, 3) >= 1 ? loads[0] : 0
        return ResourceSample(unixMs: unixMs, uptime: uptime, cpuUser: cpu.user, cpuSystem: cpu.system, load: load.isFinite ? max(0, load) : 0,
                              memTotal: memTotal, memApp: memory.app, memWired: memory.wired, memCompressed: memory.compressed,
                              memCached: memory.cached, memFree: memory.free, swapUsed: memory.swap, pressure: memory.pressure,
                              diskTotal: disk.total, diskFree: disk.free)
    }

    private func ticks() -> [[UInt32]]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS, let info else { return nil }
        defer { vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)) }
        let states = Int(CPU_STATE_MAX)
        guard Int(infoCount) >= Int(cpuCount) * states else { return nil }
        return (0..<Int(cpuCount)).map { core in
            let base = core * states
            return [CPU_STATE_USER, CPU_STATE_SYSTEM, CPU_STATE_IDLE, CPU_STATE_NICE].map { UInt32(bitPattern: info[base + Int($0)]) }
        }
    }

    private func readCPU() -> (user: Double, system: Double)? {
        guard let now = ticks() else { return nil }
        defer { previous = now }
        var user: UInt64 = 0, system: UInt64 = 0, total: UInt64 = 0
        for (core, current) in now.enumerated() {
            // Ticks are 32-bit counters that wrap; a core seen for the first time counts from zero.
            let before = core < previous.count ? previous[core] : [0, 0, 0, 0]
            let d = zip(current, before).map { UInt64($0 &- $1) }
            user += d[0] + d[3]; system += d[1]; total += d.reduce(0, +)
        }
        guard total > 0 else { return (0, 0) }
        return (Double(user) / Double(total) * 100, Double(system) / Double(total) * 100)
    }

    private func readMemory() -> (app: UInt64, wired: UInt64, compressed: UInt64, cached: UInt64, free: UInt64, swap: UInt64, pressure: ResourcePressure)? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return nil }
        let page = Int64(pageSize)
        func bytes<T: BinaryInteger>(_ pages: T) -> Int64 { Int64(pages) * page }
        let wired = bytes(stats.wire_count), compressed = bytes(stats.compressor_page_count)
        let purgeable = bytes(stats.purgeable_count), external = bytes(stats.external_page_count)
        let total = Int64(clamping: memTotal)
        let used = min(total, max(0, bytes(stats.active_count) + bytes(stats.inactive_count) + bytes(stats.speculative_count) + wired + compressed - purgeable - external))
        let app = max(0, used - wired - compressed)
        let cached = min(max(0, total - used), purgeable + external)
        let free = max(0, total - used - cached)

        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let pressure: ResourcePressure
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 {
            pressure = level >= 4 ? .critical : level == 2 ? .warn : .normal
        } else { pressure = .normal }
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapUsed = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 ? swap.xsu_used : 0
        func u(_ v: Int64) -> UInt64 { UInt64(max(0, v)) }
        return (u(app), u(min(wired, used)), u(min(compressed, used)), u(cached), u(free), swapUsed, pressure)
    }

    private func readDisk() -> (total: UInt64, free: UInt64)? {
        var fs = statfs()
        guard statfs(diskPath, &fs) == 0 else { return nil }
        let block = UInt64(fs.f_bsize), total = UInt64(fs.f_blocks) * block, free = UInt64(fs.f_bavail) * block
        guard total > 0 else { return nil }
        return (total, min(free, total))
    }
}
#endif
