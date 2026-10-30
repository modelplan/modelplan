// SPDX-License-Identifier: MIT
// Synthetic verification adapter; not an alternate product renderer.
#if MODELPLAN_TEST_ONLY_SPI && MODELPLAN_U11_WIRED
  import AppKit
  import WebKit
  import ModelPlanCockpitWeb
  import ModelPlanEngineClient
import ModelPlanAppIntegration

  @MainActor final class U11DiagnosticHandler: NSObject, WKScriptMessageHandler {
  weak var host: U11aHost?
  init(_ host: U11aHost) { self.host = host }
  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let host, host.config["mode"] as? String == "preflight", message.frameInfo.isMainFrame,
      message.webView === host.web,
      let body = message.body as? [String:Any], body.count <= 5,
      let stage = body["stage"] as? String, ["error", "rejection", "csp", "dom"].contains(stage) else { return }
    var row:[String:Any] = ["event":"u11-install-diagnostic", "stage":stage]
    // This channel exists only in synthetic preflight; no rendered DTO/owner data.
    for key in ["message", "directive"] { if let value = body[key] as? String { row[key] = String(value.prefix(160)) } }
    for key in ["api", "opaqueOrigin"] { if let value = body[key] as? Bool { row[key] = value } }
    host.emit(row)
  }
}

@MainActor protocol U11WiredDriving: AnyObject {
  var rendered: Bool { get set }
  func open() async throws
  func close()
  func shutdown() async
}
@MainActor final class U11WiredSession: U11WiredDriving {
    weak var host: U11aHost?
    let coordinator: EngineCockpitCoordinator
    let client: ProcessEngineClient
    var rendered = false
    init(host: U11aHost, config: [String: Any]) throws {
      self.host = host
      guard let root = config["bundleRoot"] as? String,
        let pin = config["manifestSHA256"] as? String,
        let helper = config["helper"] as? String,
        let home = ProcessInfo.processInfo.environment["HOME"],
        let tmp = ProcessInfo.processInfo.environment["TMPDIR"]
      else { throw CockpitBridgeError.invalidContext }
      let bundle = try VerifiedCockpitBundle(
        root: URL(fileURLWithPath: root), manifestSHA256: pin,
        allowOfficial: config["official"] as? Bool == true)
      coordinator = EngineCockpitCoordinator { [weak host] context in
        let controller = CockpitWindowController(
          bundle: bundle, context: context,
          appearance: .init(theme: .night, locale: .en, profile: .full))
        attachU11Verification(controller, host: host)
      return controller
      }
      client = coordinator.makeClient(
        configuration: .init(
          executableURL: URL(fileURLWithPath: helper),
          applicationVersion: "synthetic-u11-verification",
          allowedEnvironment: [
            "HOME": home, "TMPDIR": tmp, "PATH": "/usr/bin:/bin", "LANG": "en_US.UTF-8",
          ], offline: true, readOnly: true))
      coordinator.onUnavailable = { [weak host] in host?.stop("engine-cockpit-unavailable") }
    }
    func open() async throws {
      rendered = false
      _ = try await client.start()
      coordinator.open()
    }
    func close() {
      coordinator.close()
      rendered = false
    }
    func shutdown() async { await coordinator.shutdown() }
  }
  @MainActor private func attachU11Verification(_ controller: CockpitWindowController, host: U11aHost?) {
      controller.verificationResource = { [weak host] path in
        if host?.config["mode"] as? String == "preflight" { host?.emit(["event":"u11-bundle-resource", "path":path]) }
      }
      controller.onFailure = { [weak host] failure in host?.emit(["event":"wired-failure","stage":failure.rawValue]); host?.stop("wired-page-" + failure.rawValue) }
        controller.onRendered = { [weak host] in
          host?.wired?.rendered = true
          host?.emit(["event": "cockpit-query-rendered"])
        }
        controller.configureVerification = { [weak host] configuration in
          guard let host else { return }
          let frame = VerificationFrameHandler(scheme: "modelplan-cockpit", host: "bundle") {
            [weak host] row in
            guard let host else { return }
            host.emit(row)
            if row["outcome"] as? String == "pass", !host.raf {
              host.raf = true
              host.web?.evaluateJavaScript(
                "window.__u11aStopTicks?.();window.__u11ResetCounts?.()", completionHandler: nil)
            }
          }
          host.frameHandler = frame
        if host.config["mode"] as? String == "preflight" {
          configuration.userContentController.add(U11DiagnosticHandler(host), name:"verificationDiagnostic")
          let diagnostics = """
          (()=>{const post=x=>window.webkit.messageHandlers.verificationDiagnostic.postMessage(x);addEventListener('error',e=>post({stage:'error',message:String(e.message||'module-resource-load-failed')}),true);addEventListener('unhandledrejection',e=>post({stage:'rejection',message:String(e.reason?.message||'promise-rejected')}));addEventListener('securitypolicyviolation',e=>post({stage:'csp',directive:e.effectiveDirective}));addEventListener('DOMContentLoaded',()=>post({stage:'dom',api:!!window.modelPlanCockpit,opaqueOrigin:location.origin==='null'}));})();
          """
          configuration.userContentController.addUserScript(WKUserScript(source:diagnostics,injectionTime:.atDocumentStart,forMainFrameOnly:true))
        }
          configuration.userContentController.add(frame, name: "verificationFrames")
          let js =
            (try? String(
              contentsOfFile: host.config["scripts"].flatMap { $0 as? [String] }?.first ?? "",
              encoding: .utf8)) ?? ""
          let counter = """
            (()=>{let requested=0,callbacks=0,timers=0;const raf=window.requestAnimationFrame.bind(window);window.requestAnimationFrame=f=>{requested++;return raf(t=>{callbacks++;f(t)})};const timeout=window.setTimeout.bind(window),interval=window.setInterval.bind(window);window.setTimeout=(...a)=>{timers++;return timeout(...a)};window.setInterval=(...a)=>{timers++;return interval(...a)};window.__u11CallbackCounts=()=>({requested,callbacks,timers});window.__u11ResetCounts=()=>{requested=0;callbacks=0;timers=0};})();
            """
          configuration.userContentController.addUserScript(
            WKUserScript(
              source: counter + js
                + "\nwindow.__u11aStopTicks=installVerificationRAFTicks('verificationFrames');",
              injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        controller.verificationDidOpen = { [weak host] view, window in
          guard let host else { return }
          host.web = view
          host.window = window
          host.activation = ["activationCall": "makeKeyAndOrderFront", "event": "activation-call"]
          host.emit(host.activation)
        }
  }
@MainActor final class U11ProductWiredSession: U11WiredDriving {
  weak var host: U11aHost?
  let dock: StaticDockPreviewHost
  var rendered = false
  init(host: U11aHost) {
    self.host = host
    dock = ProductionDockFactory.community()
    CommunityCockpitEntry.verificationPage = { [weak host] page in attachU11Verification(page, host: host) }
  }
  func open() async throws {
    rendered = false; dock.setPresentationAllowed(true)
    guard NSApp.sendAction(NSSelectorFromString("openConsole"), to: dock, from: nil) else { throw CockpitBridgeError.unavailable }
  }
  func close() { CommunityCockpitEntry.closeWindow(); rendered = false }
  func shutdown() async {
    await CommunityCockpitEntry.shutdown()
    CommunityCockpitEntry.verificationPage = nil; dock.close()
  }
}

extension U11aHost {
    func openWiredView() {
      guard web == nil, permitted(), let config = config["wired"] as? [String: Any] else { return }
      raf = false
      subjectReady = false
      attribution = WebContentAttribution(allowScopedSPI: true)
      emit(["event": "open-request"])
      let requested = !NSApp.isActive
      if requested { NSApp.activate(ignoringOtherApps: true) }
      emit([
        "event": "activation-call",
        "activationCall": requested
          ? "NSApplication.activate(ignoringOtherApps:true)" : "not-invoked-already-active",
        "target": "own-U11-App",
      ])
      Task { @MainActor in
        do {
          if wired == nil {
          if config["productEntry"] as? Bool == true { wired = U11ProductWiredSession(host: self) }
          else { wired = try U11WiredSession(host: self, config: config) }
        }
          try await wired?.open()
        } catch { stop("wired-setup-failed") }
      }
    }
    func closeWiredView() {
      if let attribution {
        attribution.retire()
        emit(["event": "process-attribution-retired"])
      }
      web?.configuration.userContentController.removeScriptMessageHandler(
        forName: "verificationFrames")
      wired?.close()
      web = nil
      window = nil
      attribution = nil
      frameHandler = nil
      busy = false
      emit(["event": "view-released"])
    }
  }
#endif
