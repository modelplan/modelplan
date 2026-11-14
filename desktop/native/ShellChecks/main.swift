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

        // The neutral surface shows one language, taken from the macOS preferred-language list (#873); there is no
        // bilingual line any more. Each check pins the language it asserts on, so the runner's language never matters.
        let diagnostics: StoreDiagnostics = { var value = StoreDiagnostics(); value.personal = "personal-read-unavailable"; return value }()
        func renderedLabels(_ languages: [String]) async throws -> (surface: any NativeOverviewSurface, window: NSWindow, labels: [String]) {
            let surface = NeutralSurfaceProvider(preferredLanguages: languages).makeOverview()
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 210), styleMask: [.titled], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = surface.view
            window.orderFront(nil)
            surface.render(snapshot: nil, diagnostics: diagnostics)
            surface.view.layoutSubtreeIfNeeded()
            try await Task.sleep(nanoseconds: 100_000_000)
            surface.view.display()
            let labels = (surface.view.subviews.first as? NSStackView)?.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue } ?? []
            return (surface, window, labels)
        }
        let chinese = try await renderedLabels(["zh-Hans"])
        chinese.window.orderOut(nil)
        check(chinese.labels.contains("本地数据不可用"), "denial/error must be visible (Chinese)")
        check(chinese.labels.contains("Intel 未测试，3D 效果可能卡顿"), "Intel warning (Chinese)")
        check(!chinese.labels.contains { $0.contains("Intel untested") }, "one language per surface (Chinese)")
        let english = try await renderedLabels(["en"])
        let surface = english.surface, window = english.window
        defer { window.orderOut(nil) }
        check(english.labels.contains("Local data unavailable"), "denial/error must be visible")
        check(english.labels.contains("Intel untested; 3D may stutter"), "Intel warning (English)")
        check(!english.labels.contains { $0.contains("Intel 未测试") }, "one language per surface (English)")
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
        print("PASS AppKit adapter notification delivery, removal/recovery/teardown; neutral error surface and Intel warning in English and Chinese")
        print("Injected centers and own-view rendering only; no physical lock/hot-plug/input or minimum-runtime claim")
    }
}
