// SPDX-License-Identifier: MIT
import AppKit
import WebKit
import ImageIO

/// Scoped transport only; no cockpit/window styling or official renderer is included.
@MainActor public final class WKFieldTransport: NSObject, FieldTransport, FieldSnapshotCancellation, WKNavigationDelegate, WKUIDelegate {
    public private(set) var view: WKWebView?
    private weak var host: NSView?
    private let root: URL
    private var generation: UUID?
    private var snapshotRequest: FieldSnapshotRequest?
    private var receive: ((Data) -> Void)?
    private var failed: ((FieldReleaseReason) -> Void)?
    public init(resourceRoot: URL, host: NSView) {
        root = resourceRoot.standardizedFileURL.resolvingSymlinksInPath(); self.host = host
    }
    public func start(generation: UUID, receive: @escaping (Data) -> Void, failed: @escaping (FieldReleaseReason) -> Void) {
        invalidate()
        self.generation = generation; self.receive = receive; self.failed = failed
        guard root.isFileURL, let host else { failed(.navigation); return }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(FieldResources(root: root), forURLScheme: "modelplan-field")
        configuration.userContentController.add(FieldMessageProxy(self), name: "field")
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let view = WKWebView(frame: host.bounds, configuration: configuration)
        view.autoresizingMask = [.width, .height]; view.navigationDelegate = self; view.uiDelegate = self
        self.view = view; host.addSubview(view)
        var entry = URLComponents(string: "modelplan-field://bundle/index.html")!
        entry.queryItems = [URLQueryItem(name: "generation", value: generation.uuidString)]
        view.load(URLRequest(url: entry.url!))
    }
    public func send(_ command: FieldCommand) {
        guard command.generation == generation, let view, let object = try? command.structuredObject() else { return }
        let generation = generation
        view.callAsyncJavaScript("window.modelPlanFieldReceive(message)", arguments: ["message": object],
                                 in: nil, in: .page) { [weak self] result in
            if case .failure = result, self?.generation == generation { self?.failed?(.webError) }
        }
    }
    public func snapshot(completion: @escaping (Data?) -> Void) {
        guard snapshotRequest == nil, let view, view.bounds.width > 0, view.bounds.height > 0,
              view.window?.isVisible == true, view.window?.occlusionState.contains(.visible) == true else { completion(nil); return }
        let generation = generation
        let configuration = WKSnapshotConfiguration(); configuration.rect = view.bounds
        guard let width = FieldResourcePolicy.snapshotWidth(width: view.bounds.width, height: view.bounds.height,
            backingScale: view.window?.backingScaleFactor ?? 1) else { completion(nil); return }
        configuration.snapshotWidth = NSNumber(value: width)
        let request = FieldSnapshotRequest(completion: completion)
        snapshotRequest = request
        view.takeSnapshot(with: configuration) { [weak self, request] image, error in
            guard let self else { request.finish(nil); return }
            guard !request.cancelled, self.generation == generation, error == nil, let image,
                  let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                self.finishSnapshot(request, data: nil); return
            }
            let pixels = FieldPixels(image: cg)
            let started = request.startEncoding({ try? FieldPNG.encode(pixels.image) }) { [weak self, request] data in
                guard let self else { request.finish(nil); return }
                self.finishSnapshot(request, data: request.cancelled || self.generation != generation ? nil : data)
            }
            if !started { self.finishSnapshot(request, data: nil) }
        }
    }
    func cancelSnapshot() { snapshotRequest?.cancel() }
    private func finishSnapshot(_ request: FieldSnapshotRequest, data: Data?) {
        guard snapshotRequest === request else { return }
        snapshotRequest = nil
        request.finish(data)
    }

    public func invalidate() {
        cancelSnapshot()
        generation = nil; receive = nil; failed = nil
        view?.stopLoading(); view?.configuration.userContentController.removeScriptMessageHandler(forName: "field")
        view?.navigationDelegate = nil; view?.uiDelegate = nil; view?.removeFromSuperview(); view = nil
    }
    deinit {
        // Explicit invalidation is synchronous. This fallback also detaches a view if its owner is dropped.
        let retiredView = view, request = snapshotRequest
        DispatchQueue.main.async {
            request?.cancel()
            retiredView?.stopLoading()
            retiredView?.configuration.userContentController.removeScriptMessageHandler(forName: "field")
            retiredView?.navigationDelegate = nil; retiredView?.uiDelegate = nil
            retiredView?.removeFromSuperview()
        }
    }
    fileprivate func message(_ message: WKScriptMessage) {
        guard message.webView === view, message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.protocol == "modelplan-field", message.frameInfo.securityOrigin.host == "bundle",
              let text = message.body as? String, text.utf8.count <= 64 * 1024 else { return }
        receive?(Data(text.utf8))
    }
    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, FieldResourcePolicy.permitsNavigation(url, generation: generation,
            mainFrame: action.targetFrame?.isMainFrame == true, download: action.shouldPerformDownload) else {
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                        for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failed?(.webProcessTerminated) }
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed?(.navigation) }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed?(.navigation) }
}
@MainActor final class FieldSnapshotRequest {
    let completion: (Data?) -> Void
    var cancelled = false, finished = false
    var encoder: Task<Data?, Never>?
    var waiter: Task<Void, Never>?
    init(completion: @escaping (Data?) -> Void) { self.completion = completion }
    @discardableResult
    func startEncoding(_ encode: @escaping @Sendable () async -> Data?, completed: @escaping (Data?) -> Void) -> Bool {
        guard encoder == nil, !cancelled, !finished else { return false }
        let encoder = Task.detached(priority: .utility) {
            guard !Task.isCancelled else { return nil as Data? }
            let data = await encode()
            return Task.isCancelled ? nil : data
        }
        self.encoder = encoder
        waiter = Task {
            let data = await encoder.value
            self.encoder = nil; waiter = nil
            completed(cancelled ? nil : data)
        }
        return true
    }
    func cancel() { cancelled = true; encoder?.cancel() }
    func finish(_ data: Data?) {
        guard !finished else { return }
        finished = true; encoder = nil; waiter = nil
        completion(cancelled ? nil : data)
    }
}
private struct FieldPixels: @unchecked Sendable { let image: CGImage }
private final class FieldMessageProxy: NSObject, WKScriptMessageHandler {
    weak var owner: WKFieldTransport?
    init(_ owner: WKFieldTransport) { self.owner = owner }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) { owner?.message(message) }
}

/// Fixed bridge resource plus canonical descendants of the private packaged renderer directory.
private final class FieldResources: NSObject, WKURLSchemeHandler {
    let root: URL
    init(root: URL) { self.root = root }
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, url.scheme == "modelplan-field", url.host == "bundle" else {
            task.didFailWithError(URLError(.badURL)); return
        }
        let bridge = Bundle.module.url(forResource: "field-bridge", withExtension: "mjs", subdirectory: "Web")
        let file = FieldResourcePolicy.file(for: url, root: root, bridge: bridge)
        let types = ["html":"text/html", "js":"text/javascript", "mjs":"text/javascript", "css":"text/css",
                     "png":"image/png", "jpg":"image/jpeg", "webp":"image/webp", "svg":"image/svg+xml",
                     "woff2":"font/woff2", "json":"application/json", "bin":"application/octet-stream"]
        guard let file, (url.path == "/field-bridge.mjs" || file.path.hasPrefix(root.path + "/")),
              let mime = types[file.pathExtension],
              let size = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              size.isRegularFile == true, let count = size.fileSize, count <= 8 * 1024 * 1024,
              let data = try? Data(contentsOf: file) else { task.didFailWithError(URLError(.fileDoesNotExist)); return }
        let csp = "default-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'none'; frame-src 'none'; worker-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'"
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": mime, "Content-Length": String(data.count),
                           "Content-Security-Policy": csp, "Cache-Control": "no-store"])!
        task.didReceive(response); task.didReceive(data); task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
