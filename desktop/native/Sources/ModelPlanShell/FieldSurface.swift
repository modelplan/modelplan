// SPDX-License-Identifier: MIT
import AppKit
import WebKit
import ImageIO
import UniformTypeIdentifiers

/// Narrow B05a resource spike; enlargement stays disabled in the product until acceptance.
/// No account data, remote content, process execution or credential access.
@MainActor public final class FieldSurface: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    public private(set) var view: WKWebView?
    public private(set) var generation = UUID().uuidString
    public var onEvent: ((String, [String: Any]) -> Void)?
    private var root: URL?
    private var deadline: Timer?, watchdog: Timer?
    private var captureID: String?
    private var captureTimeout: Timer?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var pressure: DispatchSourceMemoryPressure?
    private var pendingCapture: String?
    public private(set) var lastStill: NSImage?
    public private(set) var decodedStillBytes = 0
    public override init() { super.init() }
    public func mount(root: URL, in host: NSView) {
        dispose(reason: "replace")
        generation = UUID().uuidString; self.root = root.standardizedFileURL.resolvingSymlinksInPath()
        let c = WKWebViewConfiguration()
        c.websiteDataStore = .nonPersistent()
        c.setURLSchemeHandler(FieldFiles(root: self.root!), forURLScheme: "modelplan-field")
        c.userContentController.add(WeakFieldHandler(self), name: "field")
        let w = WKWebView(frame: host.bounds, configuration: c)
        w.autoresizingMask = [.width, .height]; w.navigationDelegate = self
        view = w; host.addSubview(w)
        let g = generation
        deadline = timer(10) { [weak self] in guard self?.generation == g else { return }; self?.dispose(reason: "ready-timeout") }
        renewWatchdog()
        pressure = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        pressure?.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.dispose(reason: "memory-pressure") } }; pressure?.resume()
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            let t = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.dispose(reason: "workspace-transition") } }
            tokens.append((nc, t))
        }
        let dc = DistributedNotificationCenter.default()
        let t = dc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.dispose(reason: "lock") } }
        tokens.append((dc, t))
        w.load(URLRequest(url: URL(string: "modelplan-field://bundle/index.html")!))
    }
    private func timer(_ seconds: Double, _ body: @escaping @MainActor () -> Void) -> Timer {
        let t = Timer(timeInterval: seconds, repeats: false) { _ in MainActor.assumeIsolated { body() } }
        RunLoop.main.add(t, forMode: .common); return t
    }
    private func renewWatchdog() { watchdog?.invalidate(); watchdog = timer(180) { [weak self] in self?.dispose(reason: "idle-watchdog") } }
    public func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let d = message.body as? [String: Any], (d["version"] as? Int) == 1,
              let kind = d["type"] as? String, ["ready","settled","interaction","error","stats","disposed"].contains(kind) else { return }
        // The initial ready is unbound; native binds this instance immediately through structured arguments.
        if kind == "error", d["generation"] as? String == "" { onEvent?("bootstrap-error", d); dispose(reason: "bootstrap-error"); return }
        if kind == "ready", d["generation"] as? String == "" {
            deadline?.invalidate()
            send("configure", values: ["generation": generation])
            let g = generation; deadline = timer(5) { [weak self] in guard self?.generation == g else { return }; self?.dispose(reason: "settled-timeout") }
            return
        }
        guard d["generation"] as? String == generation else { return }
        if kind == "settled" { deadline?.invalidate() }
        if kind == "interaction" { renewWatchdog() }
        onEvent?(kind, d)
        if kind == "error" { dispose(reason: "web-error") }
    }
    public func send(_ type: String, values: [String: Any] = [:]) {
        guard let view else { return }
        var d = values; d["type"] = type; d["version"] = 1; d["generation"] = generation
        view.callAsyncJavaScript("window.receive(message)", arguments: ["message": d], in: nil, in: .page, completionHandler: { _ in })
    }
    public func capture(to file: URL, completion: @escaping (Bool) -> Void) {
        guard pendingCapture == nil, let w = view, w.window?.isVisible == true, w.window?.occlusionState.contains(.visible) == true else { completion(false); return }
        let id = UUID().uuidString, g = generation; pendingCapture = id
        let config = WKSnapshotConfiguration(); config.rect = w.bounds; config.snapshotWidth = 640
        captureTimeout = timer(2) { [weak self] in
            guard let self, self.pendingCapture == id else { return }; self.pendingCapture = nil; completion(false)
        }
        w.takeSnapshot(with: config) { [weak self, weak w] image, error in
            MainActor.assumeIsolated {
                guard let self, self.generation == g, self.pendingCapture == id else { return }
                self.captureTimeout?.invalidate(); self.pendingCapture = nil
                guard self.view === w, let image, error == nil,
                      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                      cg.width > 0, cg.height > 0, cg.width <= 2048, cg.height <= 2048 else { completion(false); return }
                let data = NSMutableData()
                guard let dst = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { completion(false); return }
                CGImageDestinationAddImage(dst, cg, nil)
                guard CGImageDestinationFinalize(dst), data.length <= 8*1024*1024 else { completion(false); return }
                do { try (data as Data).write(to: file, options: .atomic); self.lastStill = image; self.decodedStillBytes = cg.bytesPerRow * cg.height; completion(true) }
                catch { completion(false) }
            }
        }
    }
    public func dispose(reason: String) {
        let had = view != nil
        deadline?.invalidate(); deadline = nil; watchdog?.invalidate(); watchdog = nil
        captureTimeout?.invalidate(); captureTimeout = nil; pendingCapture = nil
        pressure?.cancel(); pressure = nil
        for (c,t) in tokens { c.removeObserver(t) }; tokens.removeAll()
        send("dispose")
        generation = UUID().uuidString
        view?.stopLoading(); view?.configuration.userContentController.removeScriptMessageHandler(forName: "field")
        view?.navigationDelegate = nil; view?.removeFromSuperview(); view = nil; root = nil
        if had { onEvent?("released", ["reason": reason, "liveViews": 0]) }
    }
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { onEvent?("navigation-finished", [:]) }
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { dispose(reason: "web-process-terminated") }
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { dispose(reason: "navigation-failed") }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { dispose(reason: "load-failed") }
    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let u = action.request.url, u.scheme == "modelplan-field", u.host == "bundle",
              u.path == "/index.html", action.targetFrame?.isMainFrame != false else { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }
}
private final class WeakFieldHandler: NSObject, WKScriptMessageHandler {
    weak var owner: FieldSurface?
    @MainActor init(_ owner: FieldSurface) { self.owner = owner }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) { owner?.userContentController(controller, didReceive: message) }
}

/// Scoped packaged-resource handler; canonical paths prevent symlink and traversal escape.
private final class FieldFiles: NSObject, WKURLSchemeHandler {
    let root: URL
    init(root: URL) { self.root = root.resolvingSymlinksInPath().standardizedFileURL }
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let u = task.request.url, u.host == "bundle" else { task.didFailWithError(URLError(.badURL)); return }
        let file = root.appendingPathComponent(u.path).standardizedFileURL.resolvingSymlinksInPath()
        let types = ["html": "text/html", "css": "text/css", "js": "text/javascript", "svg": "image/svg+xml", "png": "image/png", "jpg": "image/jpeg", "woff2": "font/woff2"]
        guard file.path.hasPrefix(root.path + "/"), let mime = types[file.pathExtension],
              let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              let size = attributes[.size] as? Int, size <= 8*1024*1024,
              let data = try? Data(contentsOf: file) else { task.didFailWithError(URLError(.fileDoesNotExist)); return }
        let response = HTTPURLResponse(url:u,statusCode:200,httpVersion:"HTTP/1.1",headerFields:["Content-Type":mime,"Content-Length":String(data.count),"Access-Control-Allow-Origin":"*"])!
        task.didReceive(response); task.didReceive(data); task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
