// SPDX-License-Identifier: MIT
#if canImport(Darwin)
import Darwin
import Foundation

/// Reads this Mac with system calls only (D324): host_processor_info (CPU ticks), host_statistics64 (HOST_VM_INFO64),
/// sysctlbyname (memory pressure, swap), getloadavg, statfs and, for the D407 network row, the NET_RT_IFLIST2 sysctl
/// (64-bit byte counters of every interface but loopback). It never starts a child process.
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
    /// Per core: user, system, idle, nice ticks at the previous read; nil until the first admitted read.
    private var previous: [[UInt32]]?
    /// The CPU tick source (host_processor_info); a test passes a counting one.
    private let tickSource: (() -> [[UInt32]]?)?
    /// How many times the CPU ticks were read (macrevb-1096-3: zero until the sampler admits a read).
    public private(set) var tickReads = 0
    /// D407: total bytes in and out (a test passes its own source); the previous totals and their uptime give the rate.
    private let networkSource: (() -> (in: UInt64, out: UInt64)?)?
    private var previousNetwork: (uptime: TimeInterval, in: UInt64, out: UInt64)?

    /// macrevb-1096-3: construction reads nothing. A saved-Off launch builds the reader and never samples, so it must
    /// never touch the CPU ticks; the first admitted read primes them (see `readCPU`).
    public init(diskPath: String? = nil, tickSource: (() -> [[UInt32]]?)? = nil, networkSource: (() -> (in: UInt64, out: UInt64)?)? = nil) {
        self.tickSource = tickSource
        self.networkSource = networkSource
        host = mach_host_self()
        pageSize = UInt64(vm_kernel_page_size)
        memTotal = ProcessInfo.processInfo.physicalMemory
        // The data volume holds the user's files; "/" is the sealed system volume.
        let data = "/System/Volumes/Data"
        self.diskPath = diskPath ?? (FileManager.default.fileExists(atPath: data) ? data : "/")
    }
    deinit { mach_port_deallocate(mach_task_self_, host) }

    public func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? {
        guard let cpu = readCPU(), let memory = readMemory(), let disk = readDisk() else { return nil }
        var loads = [Double](repeating: 0, count: 3)
        let load = getloadavg(&loads, 3) >= 1 ? loads[0] : 0
        let network = readNetwork(uptime: uptime)
        return ResourceSample(unixMs: unixMs, uptime: uptime, cpuUser: cpu.user, cpuSystem: cpu.system, load: load.isFinite ? max(0, load) : 0,
                              memTotal: memTotal, memApp: memory.app, memWired: memory.wired, memCompressed: memory.compressed,
                              memCached: memory.cached, memFree: memory.free, swapUsed: memory.swap, pressure: memory.pressure,
                              diskTotal: disk.total, diskFree: disk.free, netIn: network?.in, netOut: network?.out)
    }

    /// D407: bytes per second since the previous read. The first read only primes the totals; a counter that went
    /// down (an interface went away) or no time passing gives no rate for this read.
    private func readNetwork(uptime: TimeInterval) -> (in: UInt64, out: UInt64)? {
        guard let now = networkSource.map({ $0() }) ?? interfaceBytes() else { previousNetwork = nil; return nil }
        defer { previousNetwork = (uptime, now.in, now.out) }
        guard let before = previousNetwork, uptime > before.uptime, now.in >= before.in, now.out >= before.out else { return nil }
        let seconds = uptime - before.uptime
        return (UInt64(Double(now.in - before.in) / seconds), UInt64(Double(now.out - before.out) / seconds))
    }

    /// Sums the 64-bit byte counters of every non-loopback interface from one NET_RT_IFLIST2 sysctl (no child process).
    private func interfaceBytes() -> (in: UInt64, out: UInt64)? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 else { return nil }
        var totalIn: UInt64 = 0, totalOut: UInt64 = 0, offset = 0
        buffer.withUnsafeBytes { raw in
            while offset + MemoryLayout<if_msghdr>.size <= size {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                let length = Int(header.ifm_msglen)
                guard length > 0, offset + length <= size else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= size, header.ifm_flags & IFF_LOOPBACK == 0 {
                    let info = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    totalIn &+= info.ifm_data.ifi_ibytes; totalOut &+= info.ifm_data.ifi_obytes
                }
                offset += length
            }
        }
        return (totalIn, totalOut)
    }

    private func ticks() -> [[UInt32]]? {
        tickReads += 1
        if let tickSource { return tickSource() }
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
        // The first read has no earlier ticks: its share counts since boot (Stats does the same on its first read).
        let previous = self.previous ?? []
        defer { self.previous = now }
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
