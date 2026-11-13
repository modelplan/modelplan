// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanShell

/// Bounded, explicit integration mode. Uses the packaged helper with an isolated synthetic home.
/// Receipts contain timings/counts only, never raw personal JSON or local identities.
private actor ObservedCLI: CLITransport {
    let wrapped: any CLITransport
    let origin = ContinuousClock.now
    private var active = 0, peak = 0
    private var records: [[String: Any]] = []
    init(_ wrapped: any CLITransport) { self.wrapped = wrapped }
    func execute(_ command: CLICommand) async throws -> CommandResult {
        active += 1; peak = max(peak, active); defer { active -= 1 }
        let start = milliseconds(origin.duration(to: .now))
        do {
            let result = try await wrapped.execute(command)
            records.append(["command": command.rawValue, "arguments": command.arguments, "startMs": start,
                "endMs": milliseconds(origin.duration(to: .now)), "exit": result.exitCode,
                "stdoutBytes": result.stdout.count, "warning": result.warning])
            return result
        } catch {
            records.append(["command": command.rawValue, "arguments": command.arguments, "startMs": start,
                "endMs": milliseconds(origin.duration(to: .now)), "failedOrCancelled": true])
            throw error
        }
    }
    func receipt() -> [String: Any] { ["commands": records, "peakConcurrent": peak, "active": active] }
}
private func milliseconds(_ duration: Duration) -> Double {
    let value = duration.components
    return Double(value.seconds) * 1000 + Double(value.attoseconds) / 1e15
}
@MainActor final class RuntimeProbe {
    private let runtime: CommunityRuntime
    private let observed: ObservedCLI
    private let surface = NeutralSurfaceProvider().makeOverview()
    private let output: URL, duration: Double
    private let origin = ContinuousClock.now
    private var previous = ContinuousClock.now
    private var beats: [Double] = [], changes = 0, firstUsable: Double?
    private var timer: Timer?, window: NSWindow?
    private var originalFrontmost: pid_t?
    private var finishing = false
    init(home: URL, output: URL, duration: Double) {
        self.output = output; self.duration = duration
        observed = ObservedCLI(BundledCLI(bundle: Bundle.main.bundleURL, environment: AccessProbe.environment(home: home)))
        runtime = CommunityRuntime(transport: observed)
    }
    func start() {
        originalFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 210), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = "ModelPlan — synthetic read-only check"; panel.contentView = surface.view
        panel.isReleasedWhenClosed = false; panel.center(); window = panel
        runtime.store.onChange = { [weak self] in self?.render() }
        runtime.lifecycle.onPresentationChange = { [weak self] allowed in
            guard let self else { return }
            if allowed { self.render(); self.window?.orderFront(nil) }
            else { self.window?.orderOut(nil) }
        }
        runtime.start()
        previous = .now
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    private func render() {
        changes += 1
        let snapshot = runtime.store.view()
        if firstUsable == nil, snapshot?.presentation.actionable == true { firstUsable = milliseconds(origin.duration(to: .now)) }
        surface.render(snapshot: snapshot, diagnostics: runtime.store.diagnostics)
    }
    private func tick() {
        let now = ContinuousClock.now
        beats.append(milliseconds(previous.duration(to: now))); previous = now
        if origin.duration(to: now) >= .seconds(duration), !finishing {
            finishing = true; timer?.invalidate(); timer = nil
            Task { await finish() }
        }
    }
    private func finish() async {
        let final = runtime.store.view(), wasKey = window?.isKeyWindow == true
        let focusUnchanged = NSWorkspace.shared.frontmostApplication?.processIdentifier == originalFrontmost
        let cancellationStart = ContinuousClock.now
        await runtime.stop(); window?.orderOut(nil)
        let cancellationMs = milliseconds(cancellationStart.duration(to: .now))
        var receipt = await observed.receipt()
        let sorted = beats.sorted()
        receipt["heartbeatCount"] = sorted.count
        receipt["heartbeatP95Ms"] = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        receipt["heartbeatMaxMs"] = sorted.last ?? 0
        receipt["firstActionableProjectionMs"] = firstUsable as Any? ?? NSNull()
        receipt["onChangeCount"] = changes
        receipt["quotaWindows"] = final?.presentation.quotas.count ?? 0
        receipt["actionable"] = final?.presentation.actionable ?? false
        receipt["joinedPublication"] = final?.publication != nil
        receipt["personalUnavailableReason"] = runtime.store.diagnostics.personal as Any? ?? NSNull()
        receipt["publicationUnavailableReason"] = runtime.store.diagnostics.publication as Any? ?? NSNull()
        receipt["stoppedIdle"] = runtime.store.idle
        receipt["cancellationMs"] = cancellationMs
        receipt["frontmostUnchanged"] = focusUnchanged
        receipt["probeBecameKey"] = wasKey
        receipt["scope"] = "synthetic native AppKit integration; projection timing, not first physical pixel or manual input"
        if let data = try? JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: output, options: .atomic)
        }
        NSApp.terminate(nil)
    }
}
