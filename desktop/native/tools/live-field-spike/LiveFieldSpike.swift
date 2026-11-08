// SPDX-License-Identifier: MIT
// Measurement driver only (cockpit-full-v1 spike, 2026-11-08). Hosts the shipped launch-field scene in a
// WKWebView and steps through render modes while an outside sampler records process counters.
// Synthetic data; no CLI, accounts or session files. Not part of the app.
import AppKit
import WebKit

let argv = CommandLine.arguments
func arg(_ name: String) -> String? { argv.firstIndex(of: name).flatMap { $0 + 1 < argv.count ? argv[$0 + 1] : nil } }
let root = URL(fileURLWithPath: arg("--root") ?? ".")
let out = URL(fileURLWithPath: arg("--out") ?? "./spike-out")
let plan = arg("--plan") ?? "full"
let phaseSeconds = Double(arg("--seconds") ?? "20") ?? 20

final class Scheme: NSObject, WKURLSchemeHandler {
  let types = ["html": "text/html", "js": "text/javascript", "css": "text/css", "png": "image/png", "svg": "image/svg+xml",
               "json": "application/json", "woff2": "font/woff2", "jpg": "image/jpeg", "webp": "image/webp"]
  func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
    let path = task.request.url?.path ?? "/"
    let file = root.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
    guard file.path.hasPrefix(root.standardizedFileURL.path), let data = try? Data(contentsOf: file) else {
      task.didReceive(HTTPURLResponse(url: task.request.url!, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: [:])!)
      task.didFinish(); return
    }
    let mime = types[file.pathExtension] ?? "application/octet-stream"
    task.didReceive(HTTPURLResponse(url: task.request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
                                    headerFields: ["Content-Type": mime, "Content-Length": "\(data.count)"])!)
    task.didReceive(data); task.didFinish()
  }
  func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

struct Config { let name: String; let kind: String; let w: Int; let h: Int; let scale: Double; let onDemand: Bool; let active: Bool; let quiet: Bool; var hideWindow = false }
let L = (900, 640), P = (620, 217)
func live(_ name: String, _ s: (Int, Int), scale: Double, fps: Int, quiet: Bool = false) -> Config {
  Config(name: name, kind: "scene", w: s.0, h: s.1, scale: scale, onDemand: fps == 30, active: fps == 30, quiet: quiet)
}
let fullConfigs: [Config] = [
  Config(name: "shipped-ondemand-idle-L1x", kind: "scene", w: L.0, h: L.1, scale: 1, onDemand: true, active: false, quiet: false),
  Config(name: "shipped-ondemand-idle-L2x", kind: "scene", w: L.0, h: L.1, scale: 2, onDemand: true, active: false, quiet: false),
  live("live30-L1x", L, scale: 1, fps: 30), live("live60-L1x", L, scale: 1, fps: 60),
  live("live30-L2x", L, scale: 2, fps: 30), live("live60-L2x", L, scale: 2, fps: 60),
  live("live30-P2x", P, scale: 2, fps: 30), live("live60-P2x", P, scale: 2, fps: 60),
  live("live30-P1.35x", P, scale: 1.35, fps: 30),
  live("reduce-motion-continuous60-L2x", L, scale: 2, fps: 60, quiet: true),
  Config(name: "reduce-motion-ondemand-L2x", kind: "scene", w: L.0, h: L.1, scale: 2, onDemand: true, active: false, quiet: true),
  Config(name: "still-image-P2x", kind: "still", w: P.0, h: P.1, scale: 2, onDemand: false, active: false, quiet: false),
  { var c = live("hidden-window-live60-L2x", L, scale: 2, fps: 60); c.hideWindow = true; return c }(),
]
let lpmConfigs: [Config] = [
  Config(name: "shipped-ondemand-idle-L2x", kind: "scene", w: L.0, h: L.1, scale: 2, onDemand: true, active: false, quiet: false),
  live("live30-L2x", L, scale: 2, fps: 30), live("live60-L2x", L, scale: 2, fps: 60), live("live60-P2x", P, scale: 2, fps: 60),
]

@MainActor final class Driver: NSObject, WKNavigationDelegate {
  var window: NSWindow!
  var view: WKWebView?
  let log: FileHandle
  var loaded: CheckedContinuation<Void, Never>?
  override init() {
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: out.appendingPathComponent("events.jsonl").path, contents: nil)
    log = try! FileHandle(forWritingTo: out.appendingPathComponent("events.jsonl"))
    super.init()
  }
  func emit(_ event: String, _ extra: [String: Any] = [:]) {
    var row = extra; row["event"] = event; row["t"] = Date().timeIntervalSince1970
    if let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) { log.write(data); log.write("\n".data(using: .utf8)!) }
  }
  func sleep(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1e9)) }
  func makeWindow() {
    window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: L.0, height: L.1), styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.level = .floating; window.title = "live field spike"
    window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
  }
  func makeView() async {
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    config.setURLSchemeHandler(Scheme(), forURLScheme: "spike")
    let v = WKWebView(frame: window.contentView!.bounds, configuration: config)
    v.autoresizingMask = [.width, .height]; v.navigationDelegate = self
    window.contentView!.addSubview(v); view = v
    await withCheckedContinuation { c in loaded = c; v.load(URLRequest(url: URL(string: "spike://bundle/spike-harness.html")!)) }
    for _ in 0..<100 { if (try? await v.evaluateJavaScript("typeof window.spike")) as? String == "object" { break }; await sleep(0.1) }
    emit("view-created")
  }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded?.resume(); loaded = nil }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    emit("nav-fail", ["error": "\(error)"]); loaded?.resume(); loaded = nil
  }
  func destroyView() {
    view?.evaluateJavaScript("window.spike&&window.spike.unmount()", completionHandler: nil)
    view?.stopLoading(); view?.removeFromSuperview(); view = nil
    emit("view-destroyed")
  }
  func js(_ body: String, _ args: [String: Any] = [:]) async -> [String: Any] {
    guard let v = view else { return [:] }
    do { return (try await v.callAsyncJavaScript(body, arguments: args, in: nil, contentWorld: .page) as? [String: Any]) ?? [:] }
    catch { return ["error": "\(error)"] }
  }
  func resize(_ w: Int, _ h: Int) { window.setContentSize(NSSize(width: w, height: h)) }
  func phase(_ name: String, _ seconds: Double, extra: [String: Any] = [:]) async {
    emit("phase-start", extra.merging(["phase": name]) { a, _ in a })
    await sleep(seconds)
    emit("phase-end", extra.merging(["phase": name]) { a, _ in a })
  }
  func measure(_ c: Config) async {
    resize(c.w, c.h)
    let o: [String: Any] = ["kind": c.kind, "w": c.w, "h": c.h, "scale": c.scale, "onDemand": c.onDemand, "active": c.active, "quiet": c.quiet, "n": 10,
                            "src": "runtime/porthole-stills/assets/background-night-890-tall-2x.png"]
    let mounted = await js("return await window.spike.mount(o)", ["o": o])
    emit("mounted", ["phase": c.name, "stats": mounted])
    await sleep(8) // settle: entrance, shader warmup, on-demand bursts
    if c.hideWindow { window.orderOut(nil); await sleep(2) }
    let s0 = await js("return window.spike.stats()")
    emit("phase-start", ["phase": c.name, "stats": s0, "config": o, "hidden": c.hideWindow])
    await sleep(phaseSeconds)
    let s1 = await js("return window.spike.stats()")
    emit("phase-end", ["phase": c.name, "stats": s1])
    if c.hideWindow { window.makeKeyAndOrderFront(nil) }
    _ = await js("return window.spike.unmount()")
    await sleep(3)
  }
  func run() async {
    makeWindow()
    let screen = window.screen ?? NSScreen.main
    emit("env", ["plan": plan, "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
                 "reduceMotion": NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                 "backingScale": screen?.backingScaleFactor ?? 0, "maxFPS": screen?.maximumFramesPerSecond ?? 0,
                 "screen": "\(screen?.frame.size.width ?? 0)x\(screen?.frame.size.height ?? 0)",
                 "os": ProcessInfo.processInfo.operatingSystemVersionString, "cores": ProcessInfo.processInfo.activeProcessorCount])
    await sleep(5)
    await phase("before-open-no-webview", phaseSeconds)
    await makeView()
    await sleep(3)
    await phase("blank-webview", phaseSeconds)
    for c in (plan == "lpm" ? lpmConfigs : fullConfigs) { await measure(c) }
    destroyView()
    await sleep(5)
    await phase("after-close", phaseSeconds)
    if plan == "full" {
      for cycle in 1...5 {
        await makeView()
        resize(L.0, L.1)
        _ = await js("return await window.spike.mount(o)", ["o": ["kind": "scene", "w": L.0, "h": L.1, "scale": 2, "onDemand": true, "active": true, "quiet": false, "n": 10]])
        await phase("cycle-open-live30", 8, extra: ["cycle": cycle])
        destroyView()
        await phase("cycle-closed", 10, extra: ["cycle": cycle])
      }
      await phase("final-closed", phaseSeconds)
    }
    emit("done")
    try? log.synchronize()
    NSApp.terminate(nil)
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let driver = Driver()
try? "\(getpid())".write(to: out.appendingPathComponent("pid"), atomically: true, encoding: .utf8)
Task { @MainActor in await driver.run() }
app.run()
