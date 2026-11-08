// SPDX-License-Identifier: MIT
import AppKit
import Darwin
import Foundation
import WebKit
import XCTest

@testable import ModelPlanCockpitWeb

/// CPU time and memory of one process, read with proc_pid_rusage (the #723 method, CockpitBudgetTests.swift).
private struct FieldProcessSample {
  let cpuNanoseconds: UInt64, footprint: UInt64
  private static let timebase: (numer: UInt64, denom: UInt64) = {
    var info = mach_timebase_info_data_t(); mach_timebase_info(&info)
    return (UInt64(info.numer), UInt64(info.denom))
  }()
  static func read(_ pid: pid_t) -> FieldProcessSample? {
    var info = rusage_info_v4()
    let status = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
    }
    guard status == 0 else { return nil }
    let ticks = info.ri_user_time + info.ri_system_time
    return .init(cpuNanoseconds: ticks * timebase.numer / timebase.denom, footprint: info.ri_phys_footprint)
  }
}

/// This test process, the field page's WebContent and WebKit's GPU process.
private struct FieldBudgetProcesses {
  let app: pid_t, web: pid_t?, gpu: [pid_t], gpuBasis: String
  var all: [pid_t] { [app] + (web.map { [$0] } ?? []) + gpu }
  @MainActor static func of(_ web: WKWebView) -> FieldBudgetProcesses {
    func spi(_ name: String) -> pid_t? {
      guard web.responds(to: NSSelectorFromString(name)), let value = web.value(forKey: name) as? NSNumber,
            value.int32Value > 0 else { return nil }
      return value.int32Value
    }
    let gpu = spi("_gpuProcessIdentifier")
    let named = gpu == nil ? processes(named: "com.apple.WebKit.GPU") : []
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
    let before = pids.map { FieldProcessSample.read($0)?.cpuNanoseconds ?? 0 }, start = DispatchTime.now().uptimeNanoseconds
    try await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
    let after = pids.map { FieldProcessSample.read($0)?.cpuNanoseconds ?? 0 }, end = DispatchTime.now().uptimeNanoseconds
    let used = zip(before, after).reduce(UInt64(0)) { $0 + ($1.1 > $1.0 ? $1.1 - $1.0 : 0) }
    return 100 * Double(used) / Double(end - start)
  }
}

/// CKP-SHELL-19 for the enlarged launch field (plan item 7, D63): the transparent, feathered composition with its
/// frosted card and behind-window blur, opened on the real official page with synthetic public models. At rest it
/// costs at most 10% of one core (this process + WebContent + GPU); ten open/close cycles return memory to its
/// pre-open level with no growth across cycles (the #723 thresholds). Every figure prints as `CKP-FIELD-BUDGET`.
final class CockpitFieldBudgetTests: XCTestCase {
  private static func repoRoot() -> URL {
    var repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    for _ in 0..<8 where !FileManager.default.fileExists(atPath: repo.appendingPathComponent("desktop/cockpit/build.mjs").path) {
      repo.deleteLastPathComponent()
    }
    return repo
  }
  /// Synthetic public models only: four makers, three efforts each, ★ at Med.
  private static func payload() throws -> String {
    let makers = ["openai", "anthropic", "zhipuai", "google"]
    let models: [[String: Any]] = (0..<17).map { i in
      ["id": "synthetic-\(i)", "name": "Synthetic \(i)", "developerId": makers[i % makers.count], "recommended": "medium",
       "efforts": [["effort": "low", "label": "Low", "star": false, "ability": 28 + i, "cost": 0.05 * Double(i + 1), "time": 20],
                   ["effort": "medium", "label": "Med", "star": true, "ability": 34 + i, "cost": 0.1 * Double(i + 1), "time": 40],
                   ["effort": "high", "label": "High", "star": false, "ability": 38 + i, "cost": 0.3 * Double(i + 1), "time": 90]]]
    }
    let value: [String: Any] = ["language": "en", "reduceMotion": false, "models": models,
                                "mine": ["synthetic-1", "synthetic-2", "synthetic-5", "synthetic-8", "synthetic-11", "synthetic-14"], "focus": NSNull()]
    return String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
  }
  /// The alpha of the page's own snapshot at a point given as fractions of the view (top left origin).
  @MainActor private static func alpha(_ image: NSImage, _ x: Double, _ y: Double) -> Double? {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
    let px = Int(Double(rep.pixelsWide - 1) * x), py = Int(Double(rep.pixelsHigh - 1) * y)
    return rep.colorAt(x: px, y: py).map { Double($0.alphaComponent) }
  }

  @MainActor func testTheTransparentFieldStaysWithinItsCPUAndMemoryBudgetOverTenCycles() async throws {
    let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
    let manifest = official.appendingPathComponent("bundle-manifest.json")
    guard let manifestData = FileManager.default.contents(atPath: manifest.path),
          FileManager.default.fileExists(atPath: official.appendingPathComponent("field.html").path) else {
      throw XCTSkip("Build the canonical official cockpit first (U11 native does)")
    }
    _ = NSApplication.shared
    let bundle = try VerifiedCockpitBundle(root: official, manifestSHA256: VerifiedCockpitBundle.digest(manifestData), allowOfficial: true)
    let payload = try Self.payload()
    let panel = CockpitFieldPanel(bundle: bundle, idleSeconds: 600)
    var events: [String] = []
    panel.onPageEvent = { events.append($0) }

    try await Task.sleep(for: .seconds(1))
    let baseline = try XCTUnwrap(FieldProcessSample.read(getpid())).footprint
    var closedFootprints: [UInt64] = []
    let cycles = 10, budget = 10.0, mebibyte = Double(1 << 20)
    for cycle in 1...cycles {
      events.removeAll()
      panel.open(payload: payload, near: nil)
      let deadline = ContinuousClock.now + .seconds(30)
      while !events.contains("ready") && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
      XCTAssertTrue(events.contains("ready"), "cycle \(cycle): the real field page becomes ready")
      let web = try XCTUnwrap(panel.verificationWebView), window = try XCTUnwrap(panel.verificationWindow)
      try await Task.sleep(for: .seconds(2))  // the scene's opening frames (renderFor 1400 ms) settle
      let scene = (try? await web.evaluateJavaScript(
        "document.querySelector('.field-stage canvas')?'scene':document.querySelector('.field-stage .nogl')?'no-webgl':'none'")) as? String ?? "?"
      let shape = (try? await web.evaluateJavaScript("document.querySelector('.field-stage')?.dataset.shape??'none'")) as? String ?? "?"
      if cycle == 1 {
        // The floating look in the native panel: a clear, non-opaque window with no shadow; the page's own pixels
        // are transparent outside the card and the feathered silhouette, and the blur sits under the card.
        XCTAssertFalse(window.isOpaque, "the field's panel is not opaque")
        XCTAssertEqual(window.backgroundColor.alphaComponent, 0, "the panel's background is clear")
        XCTAssertFalse(window.hasShadow, "no rectangular window shadow")
        XCTAssertEqual(shape, "feathered", "the scene is masked by the feathered c01 silhouette")
        XCTAssertNotNil(panel.cardBlurFrame, "the frosted card has its behind-window blur")
        let config = WKSnapshotConfiguration(); config.afterScreenUpdates = true
        let snapshot: NSImage? = await withCheckedContinuation { done in web.takeSnapshot(with: config) { image, _ in done.resume(returning: image) } }
        if let image = snapshot {
          let a = { (x: Double, y: Double) in Self.alpha(image, x, y).map { String(format: "%.2f", $0) } ?? "--" }
          print("CKP-FIELD-BUDGET snapshot size=\(Int(image.size.width))x\(Int(image.size.height)) alpha topRight=\(a(0.99, 0.01)) bottomRight=\(a(0.99, 0.99)) gap=\(a(0.338, 0.5)) sceneCentre=\(a(0.67, 0.5)) card=\(a(0.15, 0.5)) blur=\(panel.cardBlurFrame.map { "\($0)" } ?? "none")")
        } else {
          print("CKP-FIELD-BUDGET snapshot unavailable")
        }
      }
      let processes = FieldBudgetProcesses.of(web)
      XCTAssertNotNil(processes.web, "cycle \(cycle): the page's WebContent process is attributable")
      let open = try await processes.cpuPercent(over: 10)
      let mib = { (pid: pid_t?) in pid.flatMap { FieldProcessSample.read($0) }.map { String(format: "%.1f", Double($0.footprint) / mebibyte) } ?? "--" }
      print("CKP-FIELD-BUDGET cycle=\(cycle) scene=\(scene) shape=\(shape) openCPU=\(String(format: "%.2f", open))% openAppMiB=\(mib(getpid())) openWebContentMiB=\(mib(processes.web)) openGPUMiB=\(processes.gpu.isEmpty ? "--" : processes.gpu.map { mib($0) }.joined(separator: "+")) gpu=\(processes.gpuBasis)")
      XCTAssertLessThanOrEqual(open, budget, "cycle \(cycle): App + WebContent + GPU average at most 10% of one core with the field open at rest")
      panel.close()
      let webPID = processes.web
      var ended = false
      let gone = ContinuousClock.now + .seconds(10)
      while !ended && ContinuousClock.now < gone {
        ended = webPID.map { kill($0, 0) != 0 } ?? true
        if !ended { try await Task.sleep(for: .milliseconds(50)) }
      }
      try await Task.sleep(for: .seconds(2))
      let closed = try await FieldBudgetProcesses(app: getpid(), web: nil, gpu: processes.gpu, gpuBasis: processes.gpuBasis).cpuPercent(over: 3)
      // A WebContent process WebKit keeps after the close still counts against the memory budget.
      let kept = ended ? 0 : webPID.flatMap { FieldProcessSample.read($0)?.footprint } ?? 0
      let footprint = try XCTUnwrap(FieldProcessSample.read(getpid())).footprint + kept
      closedFootprints.append(footprint)
      print(String(format: "CKP-FIELD-BUDGET cycle=%d closedCPU=%.2f%% webContentEnded=%@ baselineMiB=%.1f closedMiB=%.1f",
                   cycle, closed, ended ? "yes" : "no", Double(baseline) / mebibyte, Double(footprint) / mebibyte))
      XCTAssertLessThanOrEqual(closed, budget, "cycle \(cycle): closed, the field costs nothing near the open budget")
    }
    // #723 thresholds: the first open loads WebKit's shared code once (32 MiB allowance); later cycles may not grow.
    let firstLoad = 32.0, growth = 8.0
    let last = try XCTUnwrap(closedFootprints.last), second = closedFootprints[1]
    print(String(format: "CKP-FIELD-BUDGET summary baselineMiB=%.1f secondMiB=%.1f lastMiB=%.1f perCycleMiB=%.2f",
                 Double(baseline) / mebibyte, Double(second) / mebibyte, Double(last) / mebibyte,
                 (Double(last) - Double(second)) / mebibyte / Double(cycles - 2)))
    XCTAssertLessThanOrEqual((Double(last) - Double(baseline)) / mebibyte, firstLoad, "after close memory is back near its pre-open level")
    XCTAssertLessThanOrEqual((Double(last) - Double(second)) / mebibyte, growth, "memory does not grow across ten open and close cycles")
  }
}
