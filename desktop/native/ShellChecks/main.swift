// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanShell

actor EmptyCLI: CLITransport {
    var calls = 0
    func execute(_ command: CLICommand) async throws -> CommandResult {
        calls += 1; return CommandResult(exitCode: 3, stdout: Data())
    }
}
@MainActor func check(_ truth: Bool, _ message: String) {
    if !truth { fatalError(message) }
}
@main struct ShellChecks {
    @MainActor static func main() async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let cli = EmptyCLI(), store = SnapshotStore(transport: cli, automaticTimers: false)
        let gate = LifecycleCoordinator(store: store)
        let workspace = NotificationCenter(), local = NotificationCenter()
        var displays: Set<UInt32> = [1, 2]
        let events = SystemEvents(gate: gate, workspace: workspace, local: local, displayIDs: { displays })
        events.start()
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        workspace.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        check(!gate.canPresent, "actual notification adapter cleared overlapping reason")
        workspace.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        check(gate.canPresent, "actual notification adapter failed to resume")
        displays = [2]; local.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        check(!gate.canPresent, "removed display must cancel synchronously")
        await Task.yield(); try await Task.sleep(nanoseconds: 20_000_000)
        check(gate.canPresent, "display recovery")
        local.post(name: .NSSystemClockDidChange, object: nil)
        local.post(name: .NSSystemTimeZoneDidChange, object: nil)
        events.stop(); await gate.stop()
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        check(!gate.canPresent && store.idle, "observer teardown restarted work")

        let surface = NeutralSurfaceProvider().makeOverview()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 210), styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = surface.view
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        var diagnostics = StoreDiagnostics(); diagnostics.personal = "personal-read-unavailable"
        surface.render(snapshot: nil, diagnostics: diagnostics)
        surface.view.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        surface.view.display()
        let labels = (surface.view.subviews.first as? NSStackView)?.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue } ?? []
        check(labels.contains("Local data unavailable"), "denial/error must be visible")
        check(labels.contains { $0.contains("Intel 未测试") && $0.contains("Intel untested") }, "bilingual warning")
        if let output = CommandLine.arguments.dropFirst().first {
            let pdf = surface.view.dataWithPDF(inside: surface.view.bounds)
            guard let provider = CGDataProvider(data: pdf as CFData), let page = CGPDFDocument(provider)?.page(at: 1),
                  let context = CGContext(data: nil, width: 880, height: 420, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("own-view render failed") }
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 880, height: 420))
            context.scaleBy(x: 2, y: 2); context.drawPDFPage(page)
            guard let image = context.makeImage() else { fatalError("own-view bitmap failed") }
            try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: output))
        }
        print("PASS AppKit adapter notification delivery, removal/recovery/teardown; neutral error surface and bilingual warning")
        print("Injected centers and own-view rendering only; no physical lock/hot-plug/input or minimum-runtime claim")
    }
}
