// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI
import ModelPlanShell
import ImageIO

@main struct FieldProbe {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = Probe(); app.delegate = delegate; app.run(); _ = delegate
    }
}
@MainActor final class Probe: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let field = FieldSurface()
    var window: NSWindow!, settings: NSWindow?
    var root: URL!, out: URL!, started = ContinuousClock.now
    var events: [[String: Any]] = [], cycle = 0, captured = false, settingsOpen = false
    var timer: Timer?, closeTimer: Timer?, occlusionTimer: Timer?
    var pressureReleased = false
    func emit(_ name: String, _ data: [String: Any] = [:]) {
        var d = data; d["event"] = name; d["seconds"] = Double(started.duration(to: .now).components.seconds) + Double(started.duration(to: .now).components.attoseconds)/1e18
        d["cycle"] = cycle; events.append(d)
        if let data = try? JSONSerialization.data(withJSONObject: events, options: [.prettyPrinted,.sortedKeys]) { try? data.write(to: out.appendingPathComponent("events.json"), options: .atomic) }
    }
    func later(_ t: Double, _ body: @escaping @MainActor () -> Void) {
        let timer = Timer(timeInterval: t, repeats: false) { _ in MainActor.assumeIsolated { body() } }; RunLoop.main.add(timer, forMode: .common)
    }
    func applicationDidFinishLaunching(_ n: Notification) {
        let args = CommandLine.arguments
        func value(_ key: String) -> String? { args.firstIndex(of:key).flatMap { $0+1 < args.count ? args[$0+1] : nil } }
        guard let r = value("--resources"), let o = value("--output") else { NSApp.terminate(nil); return }
        root = URL(fileURLWithPath:r); out = URL(fileURLWithPath:o)
        try? FileManager.default.createDirectory(at:out, withIntermediateDirectories:true)
        NSApp.setActivationPolicy(.accessory)
        window = NSWindow(contentRect:NSRect(x:120,y:120,width:800,height:500),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.title = "ModelPlan — B05a field resource probe"; window.isReleasedWhenClosed = false; window.delegate = self
        window.contentView = NSView(frame:window.contentLayoutRect); window.orderFront(nil)
        field.onEvent = { [weak self] kind,d in
            guard let self else { return }; self.emit(kind,d)
            if kind == "settled", !self.captured {
                self.captured = true
                self.field.capture(to:self.out.appendingPathComponent("still.png")) { ok in self.emit("capture",["passed":ok,"decodedBytes":self.field.decodedStillBytes]) }
                self.later(3) { self.field.send("stats") }
                self.later(4) { self.field.dispose(reason:"cycle-close"); self.emit("closed") ; self.later(self.cycle == 1 ? 181 : 31) { self.nextCycle() } }
            }
        }
        if value("--verify-still") == "yes" {
            let f = out.appendingPathComponent("still.png")
            let data = try? Data(contentsOf:f)
            let source = data.flatMap { CGImageSourceCreateWithData($0 as CFData,nil) }
            let valid = source.flatMap { CGImageSourceCreateImageAtIndex($0,0,nil) }.map { $0.width>0 && $0.width<=2048 && $0.height<=2048 } ?? false
            emit("relaunch-still",["passed":valid]); NSApp.terminate(nil); return
        }
        emit("cold")
        later(5) { self.openSettings() }
        later(8) { self.settings?.close(); self.settings = nil; self.emit("settings-closed") }
        later(value("--quick") == "yes" ? 2 : 40) { self.nextCycle() }
        later(1000) { self.field.dispose(reason:"overall-timeout"); self.emit("timeout"); NSApp.terminate(nil) }
    }
    func openSettings() {
        let s = NSWindow(contentRect:NSRect(x:200,y:200,width:320,height:180),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        s.title = "Synthetic Settings"; s.isReleasedWhenClosed = false
        s.contentView = NSHostingView(rootView:VStack { Text("ModelPlan Settings"); Toggle("Synthetic preview",isOn:.constant(false)); Text("Local resource test only") }.padding())
        s.orderFront(nil); settings = s; emit("settings-open")
    }
    func nextCycle() {
        cycle += 1
        if cycle > 10 { field.dispose(reason:"finished"); emit("finished"); NSApp.terminate(nil); return }
        captured = false; emit("mount")
        field.mount(root:root,in:window.contentView!)
        let this = cycle
        later(15) { if self.cycle == this && !self.captured { self.field.dispose(reason:"failed-cycle"); self.emit("failed-cycle"); self.later(31) { self.nextCycle() } } }
    }
    func windowDidChangeOcclusionState(_ n: Notification) {
        guard window != nil else { return }
        occlusionTimer?.invalidate()
        if !window.occlusionState.contains(.visible) {
            field.send("pause")
            let t = Timer(timeInterval:5,repeats:false) { [weak self] _ in MainActor.assumeIsolated { self?.field.dispose(reason:"occluded") } }
            RunLoop.main.add(t,forMode:.common); occlusionTimer = t
        }
    }
    func windowWillClose(_ n: Notification) { field.dispose(reason:"native-close"); emit("user-close"); NSApp.terminate(nil) }
}
