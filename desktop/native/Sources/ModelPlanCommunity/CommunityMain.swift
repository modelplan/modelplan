// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanShell

@MainActor final class CommunityDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem?
    private let surfaces: any NativeSurfaceProvider
    private var overview: (any NativeOverviewSurface)?
    private var window: NSWindow?
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
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Model Plan"
        let menu = NSMenu()
        let show = menu.addItem(withTitle: "Status…", action: #selector(showStatus), keyEquivalent: "")
        show.target = self
        menu.addItem(withTitle: "Intel untested; 3D may stutter", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu; status = item
    }
    @objc private func showStatus() {
        if window == nil {
            let surface = surfaces.makeOverview(); overview = surface
            surface.render(snapshot:nil,diagnostics:StoreDiagnostics())
            let panel = NSWindow(contentRect:NSRect(x:0,y:0,width:440,height:210),
                styleMask:[.titled,.closable],backing:.buffered,defer:false)
            panel.title = "Model Plan Community"; panel.contentView = surface.view
            panel.isReleasedWhenClosed = false; panel.center(); window = panel
        }
        NSApp.activate(ignoringOtherApps:true); window?.makeKeyAndOrderFront(nil)
    }
}
@main struct CommunityMain {
    @MainActor static func main() {
        let delegate = CommunityDelegate(surfaces:NeutralSurfaceProvider())
        NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) { NSApplication.shared.run() }
    }
}
