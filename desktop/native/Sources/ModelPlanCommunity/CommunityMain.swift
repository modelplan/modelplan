// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore

@MainActor final class CommunityDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem?
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
        menu.addItem(withTitle: "Neutral Swift scaffold", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Intel untested; 3D may stutter", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu; status = item
    }
}
@main struct CommunityMain {
    @MainActor static func main() {
        let delegate = CommunityDelegate()
        NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) { NSApplication.shared.run() }
    }
}
