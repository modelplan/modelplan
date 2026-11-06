// SPDX-License-Identifier: MIT
// THROWAWAY SPIKE (session C, 2026-11-06): hosts the built official cockpit bundle in a WKWebView,
// drives it with synthetic host messages and runs a fixed timeline of states for an external sampler.
// Usage: PortholeHarness <url> <messages.json>
// Prints "MARK <phase> <begin|end> <unix-seconds>" lines; "FPS <phase> <frames> <seconds>" lines.
import AppKit
import WebKit

final class Harness: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    let url: URL, messages: [String]
    var window: NSWindow!, web: WKWebView!
    init(url: URL, messages: [String]) { self.url = url; self.messages = messages }
    func say(_ s: String) { print(s); fflush(stdout) }
    func mark(_ phase: String, _ edge: String) { say("MARK \(phase) \(edge) \(Date().timeIntervalSince1970)") }
    func applicationDidFinishLaunching(_ n: Notification) {
        let config = WKWebViewConfiguration()
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1040, height: 900), configuration: config)
        web.navigationDelegate = self
        window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 1040, height: 900), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Porthole spike"; window.contentView = web
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        web.load(URLRequest(url: url))
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            for _ in 0..<50 { if (try? await web.evaluateJavaScript("!!window.modelPlanCockpit")) as? Bool == true { break }; try? await Task.sleep(nanoseconds: 100_000_000) }
            for raw in messages {
                let literal = String(data: try! JSONSerialization.data(withJSONObject: [raw]), encoding: .utf8)!
                let ok = try? await web.evaluateJavaScript("window.modelPlanCockpit.receive(\(literal)[0])")
                say("RECEIVE \(String(describing: ok))")
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let stats = try? await web.evaluateJavaScript("JSON.stringify({p:window.__porthole?window.__porthole.stats():null,anims:document.getAnimations().length})")
            say("STATS \(stats ?? "nil")")
            await timeline()
        }
    }
    func fps(_ phase: String) async {
        let js = "await new Promise(r=>{let n=0;const t0=performance.now();const f=()=>{n++;if(performance.now()-t0<5000)requestAnimationFrame(f);else r(n+' '+((performance.now()-t0)/1000).toFixed(2));};requestAnimationFrame(f);setTimeout(()=>r(n+' timeout'),9000);})"
        let r = try? await web.callAsyncJavaScript("return " + js, contentWorld: .page)
        say("FPS \(phase) \(r.map { "\($0)" } ?? "nil")")
    }
    func hold(_ phase: String, _ seconds: UInt64) async { mark(phase, "begin"); try? await Task.sleep(nanoseconds: seconds * 1_000_000_000); mark(phase, "end") }
    @MainActor func timeline() async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        await hold("focused", 20)
        // Visible but unfocused: another app becomes frontmost; the window stays on screen.
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"), configuration: .init())
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        say("KEY \(window.isKeyWindow) ACTIVE \(NSApp.isActive) VISIBLE \(window.isVisible) OCCLUSION \(window.occlusionState.contains(.visible))")
        await hold("unfocused", 20)
        window.miniaturize(nil)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        say("MINI \(window.isMiniaturized) OCCLUSION \(window.occlusionState.contains(.visible))")
        await hold("minimized", 15)
        window.deminiaturize(nil); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        mark("fps", "begin"); await fps("focused"); mark("fps", "end")
        mark("done", "end")
        NSApp.terminate(nil)
    }
}

let args = CommandLine.arguments
guard args.count == 3, let url = URL(string: args[1]),
      let data = FileManager.default.contents(atPath: args[2]),
      let messages = try? JSONSerialization.jsonObject(with: data) as? [String] else {
    FileHandle.standardError.write("usage: PortholeHarness <url> <messages.json>\n".data(using: .utf8)!); exit(2)
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Harness(url: url, messages: messages)
app.delegate = delegate
app.run()
