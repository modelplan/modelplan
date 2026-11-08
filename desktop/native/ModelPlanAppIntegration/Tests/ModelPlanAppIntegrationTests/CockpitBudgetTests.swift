// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import Darwin
import Foundation
import WebKit
import XCTest
import ModelPlanCockpitWeb
import ModelPlanWire
@testable import ModelPlanAppIntegration

#if MODELPLAN_TEST_ONLY_SPI
/// CPU time and memory of one process, read with proc_pid_rusage. Times are Mach absolute units, converted here.
private struct ProcessSample {
    let cpuNanoseconds: UInt64, footprint: UInt64
    private static let timebase: (numer: UInt64, denom: UInt64) = {
        var info = mach_timebase_info_data_t(); mach_timebase_info(&info)
        return (UInt64(info.numer), UInt64(info.denom))
    }()
    static func read(_ pid: pid_t) -> ProcessSample? {
        var info = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
        }
        guard status == 0 else { return nil }
        let ticks = info.ri_user_time + info.ri_system_time
        return .init(cpuNanoseconds: ticks * timebase.numer / timebase.denom, footprint: info.ri_phys_footprint)
    }
}

/// The processes the budget counts: this App, the page's WebContent and WebKit's GPU process.
private struct BudgetProcesses {
    let app: pid_t, web: pid_t?, gpu: [pid_t], gpuBasis: String
    var all: [pid_t] { [app] + (web.map { [$0] } ?? []) + gpu }

    @MainActor static func of(_ web: WKWebView) -> BudgetProcesses {
        func spi(_ name: String) -> pid_t? {
            guard web.responds(to: NSSelectorFromString(name)), let value = web.value(forKey: name) as? NSNumber,
                  value.int32Value > 0 else { return nil }
            return value.int32Value
        }
        let gpu = spi("_gpuProcessIdentifier")
        // Without the WebKit accessor, count every WebKit GPU process of this user: on a test runner that is ours.
        let named = gpu == nil ? Self.processes(named: "com.apple.WebKit.GPU") : []
        return .init(app: getpid(), web: spi("_webProcessIdentifier"), gpu: gpu.map { [$0] } ?? named,
                     gpuBasis: gpu != nil ? "_gpuProcessIdentifier" : "process name (\(named.count))")
    }
    static func processes(named name: String) -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) * 2)
        let filled = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        let uid = getuid()
        return pids.prefix(Int(max(0, filled))).filter { pid in
            guard pid > 0 else { return false }
            var buffer = [CChar](repeating: 0, count: 256)
            guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0, String(cString: buffer) == name else { return false }
            var info = proc_bsdinfo()
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size)) > 0 else { return false }
            return info.pbi_uid == uid
        }
    }
    /// Average CPU over `seconds`, in percent of one core, summed over the processes.
    func cpuPercent(over seconds: Double) async throws -> Double {
        let pids = all
        let before = pids.map { ProcessSample.read($0)?.cpuNanoseconds ?? 0 }, start = DispatchTime.now().uptimeNanoseconds
        try await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
        let after = pids.map { ProcessSample.read($0)?.cpuNanoseconds ?? 0 }, end = DispatchTime.now().uptimeNanoseconds
        let used = zip(before, after).reduce(UInt64(0)) { $0 + ($1.1 > $1.0 ? $1.1 - $1.0 : 0) }
        return 100 * Double(used) / Double(end - start)
    }
}

extension CommunityCockpitEntryTests {
    private static func budgetRepoRoot() -> URL {
        var repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: repo.appendingPathComponent("desktop/cockpit/build.mjs").path) {
            repo.deleteLastPathComponent()
        }
        return repo
    }
    /// The owner-test package shape the production page factory admits (see OwnerTestCockpitPageTests).
    private static func budgetApp(at root: URL, official: URL) throws -> URL {
        let app = root.appendingPathComponent("ModelPlan Community.app"), contents = app.appendingPathComponent("Contents")
        let fm = FileManager.default
        for dir in ["MacOS", "Helpers", "Resources"] {
            try fm.createDirectory(at: contents.appendingPathComponent(dir), withIntermediateDirectories: true)
        }
        let helper = contents.appendingPathComponent("Helpers/modelplan")
        try Data("synthetic helper".utf8).write(to: helper)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
        let digest = SHA256.hash(data: try Data(contentsOf: helper)).map { String(format: "%02x", $0) }.joined()
        try Data((digest + "\n").utf8).write(to: contents.appendingPathComponent("Resources/modelplan.sha256"))
        try fm.copyItem(at: official, to: contents.appendingPathComponent("Resources/Cockpit"))
        try Data(#"{"edition": "official", "stage": "owner-test"}"#.utf8).write(to: contents.appendingPathComponent("Resources/build-edition.json"))
        let info: [String: Any] = ["CFBundleIdentifier": "org.modelplan.community.swift.scaffold", "CFBundleExecutable": "ModelPlanCommunity",
                                   "CFBundlePackageType": "APPL", "ModelPlanCockpitEntryEnabled": true,
                                   "ModelPlanPublicSource": String(repeating: "a", count: 40), "ModelPlanBundledHelperSHA256": digest,
                                   CommunityConsentBundleIdentity.ownerTestKey: true]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        return app
    }

    /// CKP-SHELL-19 (C-41, U11a budget): with the real official page open on synthetic readings, this App, its
    /// WebContent and the GPU process together average at most 10% of one core; after each close the page's
    /// App's memory, plus any WebContent WebKit keeps, comes back to where it was, with no growth across cycles.
    /// Hosted-runner numbers stand in for the owner's Mac; every figure is printed as `CKP-SHELL-19` for review.
    @MainActor func testCockpitStaysWithinItsCPUAndMemoryBudgetOpenAndClosed() async throws {
        let official = Self.budgetRepoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path),
              !CommunityCockpitApplicationFactory.manifestPins.isEmpty else { // pins exist only in a build that generated them
            throw XCTSkip("Build the canonical official cockpit and generate its pins (check-bundle-pins.py --write, -DMODELPLAN_COCKPIT_BUILD_PINS) first")
        }
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ckp-shell-19-" + UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try Self.budgetApp(at: root, official: official)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"])
        let owner = CockpitConsoleOwner(bundle: app, settingsStore: settings)
        let helper = app.appendingPathComponent("Contents/Helpers/modelplan")
        let capture = Self.budgetRepoRoot().appendingPathComponent("schema/app-cli/captures/WireCockpitData.json")
        let data = try WireDecoder.decode(WireCockpitData.self, from: Data(contentsOf: capture))

        // The App before any cockpit page exists.
        try await Task.sleep(for: .seconds(1))
        let baseline = try XCTUnwrap(ProcessSample.read(getpid())).footprint
        var closedFootprints: [UInt64] = []
        let cycles = 5, budget = 10.0, mebibyte = Double(1 << 20)
        for cycle in 1...cycles {
            // The open part holds the only references to the page and its web view, so after it returns nothing
            // in this test keeps them alive, as the coordinator keeps nothing after a close.
            func openAndClose() async throws -> (open: Double, processes: BudgetProcesses) {
            let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic-budget", generation: 1)
            let page = try owner.makePage(context: context, executable: helper)
            var ready = false
            page.onReady = { ready = true }
            page.open()
            let deadline = ContinuousClock.now + .seconds(30)
            while !ready && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
            XCTAssertTrue(ready, "cycle \(cycle): the real page becomes ready")
            let web = try XCTUnwrap(page.verificationWebView)
            // Show readings, as the engine's reply would, once the page is confirmed visible.
            var shown = false
            while !shown && ContinuousClock.now < deadline {
                if let ticket = page.queryTicket { page.display(data, ticket: ticket) }
                try await Task.sleep(for: .milliseconds(200))
                let columns = (try? await web.evaluateJavaScript("document.querySelectorAll('.eng-cols .ec').length")) as? Int
                shown = (columns ?? 0) > 0
            }
            XCTAssertTrue(shown, "cycle \(cycle): the readings are on the page")
            try await Task.sleep(for: .seconds(2)) // let the open settle, as a person reads it
            let processes = BudgetProcesses.of(web)
            XCTAssertNotNil(processes.web, "cycle \(cycle): the page's WebContent process is attributable")
            let open = try await processes.cpuPercent(over: 10)
            // Memory while open, per process: the App, the page's WebContent and the GPU process(es).
            let mib = { (pid: pid_t?) in pid.flatMap { ProcessSample.read($0) }.map { String(format: "%.1f", Double($0.footprint) / mebibyte) } ?? "--" }
            print("CKP-SHELL-19 cycle=\(cycle) openAppMiB=\(mib(getpid())) openWebContentMiB=\(mib(processes.web)) openGPUMiB=\(processes.gpu.isEmpty ? "--" : processes.gpu.map { mib($0) }.joined(separator: "+"))")
            page.discard()
            return (open, processes)
            }
            let (open, processes) = try await openAndClose()
            let webPID = processes.web
            var ended = false
            let gone = ContinuousClock.now + .seconds(10)
            while !ended && ContinuousClock.now < gone {
                ended = webPID.map { kill($0, 0) != 0 } ?? true
                if !ended { try await Task.sleep(for: .milliseconds(50)) }
            }
            try await Task.sleep(for: .seconds(2))
            let closed = try await BudgetProcesses(app: getpid(), web: nil, gpu: processes.gpu, gpuBasis: processes.gpuBasis).cpuPercent(over: 5)
            // A WebContent process WebKit keeps after the close still counts against the memory budget.
            let kept = ended ? 0 : webPID.flatMap { ProcessSample.read($0)?.footprint } ?? 0
            let footprint = try XCTUnwrap(ProcessSample.read(getpid())).footprint + kept
            closedFootprints.append(footprint)
            print(String(format: "CKP-SHELL-19 cycle=%d openCPU=%.2f%% closedCPU=%.2f%% webContentEnded=%@ gpu=%@ baselineMiB=%.1f closedMiB=%.1f",
                         cycle, open, closed, ended ? "yes" : "no", processes.gpuBasis, Double(baseline) / mebibyte, Double(footprint) / mebibyte))
            XCTAssertLessThanOrEqual(open, budget, "cycle \(cycle): App + WebContent + GPU average at most 10% of one core while open")
            XCTAssertLessThanOrEqual(closed, budget, "cycle \(cycle): closed, the cockpit costs nothing near the open budget")
        }
        // Memory returns to its pre-open level. The first open loads WebKit's shared code into the App once; that
        // allowance is the only one, and later cycles may not grow.
        let firstLoad = 32.0, growth = 8.0
        let last = try XCTUnwrap(closedFootprints.last), second = closedFootprints[1]
        XCTAssertLessThanOrEqual((Double(last) - Double(baseline)) / mebibyte, firstLoad,
                                 "after close the App's memory is back near its pre-open level")
        XCTAssertLessThanOrEqual((Double(last) - Double(second)) / mebibyte, growth,
                                 "memory does not grow across repeated open and close cycles")
    }
}
#endif
