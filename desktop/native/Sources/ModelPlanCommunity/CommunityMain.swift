// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanShell

@MainActor final class CommunityDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem?
    private let surfaces: any NativeSurfaceProvider
    private var overview: (any NativeOverviewSurface)?
    private var window: NSWindow?
    private var runtime: CommunityRuntime?
    private var probe: RuntimeProbe?
    private var restoreWindow = false
    private var terminating = false
    init(surfaces: any NativeSurfaceProvider) { self.surfaces = surfaces; super.init() }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let args = CommandLine.arguments
        if let at = args.firstIndex(of: "--access-probe"), args.count > at + 2 {
            let home = URL(fileURLWithPath: args[at + 1], isDirectory: true)
            let output = URL(fileURLWithPath: args[at + 2])
            Task {
                await AccessProbe.run(home: home, result: output)
                NSApp.terminate(nil)
            }
            return
        }
        if let at = args.firstIndex(of: "--runtime-probe"), args.count > at + 3,
           let duration = Double(args[at + 3]), duration >= 1, duration <= 120 {
            probe = RuntimeProbe(home: URL(fileURLWithPath: args[at + 1]), output: URL(fileURLWithPath: args[at + 2]), duration: duration)
            probe?.start(); return
        }
        let runtime = CommunityRuntime(transport: BundledCLI(bundle: Bundle.main.bundleURL))
        self.runtime = runtime
        runtime.store.onChange = { [weak self] in self?.render() }
        runtime.lifecycle.onPresentationChange = { [weak self] allowed in
            guard let self else { return }
            if !allowed {
                self.restoreWindow = self.window?.isVisible == true; self.window?.orderOut(nil)
            } else {
                self.render()
                if self.restoreWindow { self.window?.orderFront(nil); self.restoreWindow = false }
            }
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Model Plan"
        let menu = NSMenu()
        let show = menu.addItem(withTitle: "Status…", action: #selector(showStatus), keyEquivalent: "")
        show.target = self
        menu.addItem(withTitle: "Intel untested; 3D may stutter", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu; status = item
        runtime.start()
    }
    @objc private func showStatus() {
        guard let runtime, runtime.lifecycle.canPresent else { return }
        if window == nil {
            let surface = surfaces.makeOverview(); overview = surface
            let panel = NSWindow(contentRect:NSRect(x:0,y:0,width:440,height:210),
                styleMask:[.titled,.closable],backing:.buffered,defer:false)
            panel.title = "Model Plan Community"; panel.contentView = surface.view
            panel.isReleasedWhenClosed = false; panel.center(); window = panel
        }
        render(); runtime.store.refresh()
        NSApp.activate(ignoringOtherApps:true); window?.makeKeyAndOrderFront(nil)
    }
    private func render() {
        guard let runtime else { return }
        overview?.render(snapshot: runtime.store.view(), diagnostics: runtime.store.diagnostics)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let runtime else { return .terminateNow }
        guard !terminating else { return .terminateLater }
        terminating = true
        Task { await runtime.stop(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
@main struct CommunityMain {
    @MainActor static func main() {
        let delegate = CommunityDelegate(surfaces:NeutralSurfaceProvider())
        NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) { NSApplication.shared.run() }
    }
}
