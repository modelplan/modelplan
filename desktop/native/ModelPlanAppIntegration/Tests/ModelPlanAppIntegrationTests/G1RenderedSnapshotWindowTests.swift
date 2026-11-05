// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import ModelPlanCockpitWeb
import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanSettings
import ModelPlanWire
import XCTest

@testable import ModelPlanAppIntegration

actor G1WindowClient: EngineClient {
  let consumer: any EngineClientEventConsumer, rows: WireRowsSnapshot
  nonisolated let context = EngineDeliveryContext(
    sessionID: "00000000-0000-4000-8000-000000000701",
    floor: .init(storeEpoch: "g1-window", generation: 1), revision: 1)
  init(_ consumer: any EngineClientEventConsumer, rows: WireRowsSnapshot) {
    self.consumer = consumer
    self.rows = rows
  }
  nonisolated func isCurrent(_ value: EngineDeliveryContext) -> Bool { value == context }
  func supportsCapability(_ value: String) async -> Bool { value == "cockpit" }
  func start() async throws -> EngineDeliveryContext {
    await consumer.consume(.connection(.ready(context)))
    await consumer.consume(.context(context))
    try await publish()
    return context
  }
  func publish() async throws {
    await consumer.consume(
      .rowsChanged(
        .init(
          envelope: try .init(
            sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
  }
  func revoke() async {
    await consumer.consume(
      .clearPrivateViews(
        .init(revision: 2, reason: .generationAdvanced, previous: context, nextFloor: nil)))
  }
  func stop() async {}
  func retry() async throws -> EngineDeliveryContext { try await start() }
  func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
    try await publish()
    return .init(requestID: .string("rows"))
  }
  func consent(timeout: Duration?) throws -> EngineRequestCompletion {
    throw EngineClientError.unsupportedCapability
  }
  func grant(_ value: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?)
    throws -> EngineRequestCompletion
  { throw EngineClientError.unsupportedCapability }
  func refresh(_ value: WireRefreshRequestParams, timeout: Duration?) throws
    -> EngineRequestCompletion
  { throw EngineClientError.unsupportedCapability }
  func history(_ value: WireHistoryQueryParams, timeout: Duration?) throws
    -> EngineRequestCompletion
  { throw EngineClientError.unsupportedCapability }
  func cockpit(timeout: Duration?) throws -> EngineRequestCompletion {
    .init(requestID: .string("pending-cockpit-with-no-private-response"))
  }
  func publication(timeout: Duration?) throws -> EngineRequestCompletion {
    throw EngineClientError.unsupportedCapability
  }
  func pluginInstall(_ value: WirePluginInstallParams, timeout: Duration?) throws
    -> EngineRequestCompletion
  { throw EngineClientError.unsupportedCapability }
  func diagnostics(timeout: Duration?) throws -> EngineRequestCompletion {
    throw EngineClientError.unsupportedCapability
  }
}

/// Actual native Settings/WebKit tests. Default GUI partition only; no env-based success skip.
@MainActor final class G1RenderedSnapshotWindowTests: XCTestCase {
  private func root() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "g1-rendered-window-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    return root
  }
  private func make(_ root: URL, bundle: VerifiedCockpitBundle? = nil, nativeCockpit: Bool = false)
    async throws -> (EngineDockMenuApplication, G1WindowClient)
  {
    let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json")
      .standardizedFileURL
    let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
    let display = DockDisplayArea(
      id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900),
      visibleFrame: .init(x: 0, y: 80, width: 1440, height: 820))
    let controls = G1InspectionControls(
      now: Date(timeIntervalSince1970: 1_800_000_000), displays: [display])
    let store = try EngineRowsEntry.makeSettingsStore(
      applicationSupport: root.appendingPathComponent("profile"), preferredLanguages: ["en"])
    _ = try await store.update { p in
      p.language = .english
      p.autoHide = false
      for _ in 0..<16 { p.onboarding.next() }
    }
    var client: G1WindowClient?
    let app = try EngineRowsEntry.makeForG1Checks(
      configuration: .init(
        executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic",
        allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store,
      controls: controls, bundleURL: root.appendingPathComponent("Synthetic.app"),
      cockpitBundle: bundle, nativeCockpit: nativeCockpit
    ) { _, consumer in
      let value = G1WindowClient(consumer, rows: rows)
      client = value
      return value
    }
    await app.prepare()
    app.allowDockPresentation()
    await app.composition.start()
    addTeardownBlock { @MainActor in
      app.settingsHost.suspend()
      app.composition.dock.close()
      await app.composition.stop()
    }
    return (app, try XCTUnwrap(client))
  }
  func testSettingsSnapshotReadsTheRetainedPaintedControlAndSurface() async throws {
    _ = NSApplication.shared
    let root = try root()
    let (app, _) = try await make(root)
    XCTAssertNotNil(
      app.composition.renderedSnapshotForChecks().element("settings")?.unavailable["surface"])
    await app.settingsHost.present(paneID: "dock")
    let window = try XCTUnwrap(app.settingsHost.renderedWindowForG1Checks)
    defer { window.close() }
    let view = try XCTUnwrap(window.contentView)
    func fields(_ v: NSView) -> [NSTextField] {
      (v as? NSTextField).map { [$0] } ?? v.subviews.flatMap(fields)
    }
    let field = try XCTUnwrap(fields(view).first { $0.stringValue == "Show Quota Widget" })
    field.stringValue = "G1 Settings painted marker"
    field.textColor = NSColor(srgbRed: 0.1, green: 0.2, blue: 0.3, alpha: 1)
    view.layoutSubtreeIfNeeded()
    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: bitmap)
    let snapshot = app.composition.renderedSnapshotForChecks()
    let node = try XCTUnwrap(
      snapshot.root.elements.first { $0.text == "G1 Settings painted marker" })
    let facade = app.renderedSnapshotForChecks()
    XCTAssertNotNil(facade.settings)
    let exported = try XCTUnwrap(facade.find(node.identifier))
    XCTAssertEqual(exported.text, field.stringValue)
    XCTAssertEqual(exported.ink?.hex, "#1A334DFF")
    XCTAssertEqual(exported.frame, window.convertToScreen(field.convert(field.bounds, to: nil)))
    XCTAssertEqual(exported.contrastToParent, node.contrastAgainstParent)
    XCTAssertEqual(node.ink?.hex, "#1A334DFF")
    XCTAssertGreaterThan(try XCTUnwrap(node.frame).width, 0)
    XCTAssertGreaterThan(try XCTUnwrap(node.contrastAgainstParent), 1)
    XCTAssertEqual(snapshot.element("settings")?.attributes["selectedPane"], "dock")
    XCTAssertEqual(
      snapshot.element("settings")?.attributes["paintEvidence"], "completed-native-draw")
    let before = field.frame
    let revision = app.settingsHost.application.editor.snapshot?.revision
    _ = app.composition.renderedSnapshotForChecks()
    XCTAssertEqual(field.frame, before)
    XCTAssertEqual(app.settingsHost.application.editor.snapshot?.revision, revision)
  }
  func testCockpitSnapshotReadsActualVerifiedWebLayoutAndClearsWithTheFanout() async throws {
    _ = NSApplication.shared
    let root = try root()
    let web = root.appendingPathComponent("web")
    let src = web.appendingPathComponent("src")
    try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
    let html = Data(
      "<html><body style='margin:0;background:rgb(255,255,255)'><div class='ck' style='background:rgb(255,255,255);width:240px;height:120px'><span id='g1-cockpit-label' style='color:color(srgb 0.0666666667 0.1333333333 0.2)'>G1 cockpit painted marker</span><button id='g1-cockpit-disabled' disabled>Unavailable</button><input id='g1-password' type='password' value='synthetic-secret'><div id='g1-transparent' style='opacity:0'><span id='g1-transparent-child'>Not painted</span></div></div></body></html>"
        .utf8)
    // The actual WebKit fixture acknowledges API readiness and real DOM clear only.
    // It never claims a rendered/display receipt or supplies private query data.
    let js = Data(
      #"""
      let sequence=0;
      function receipt(raw,type){
        const m=JSON.parse(raw),r={};
        for(const k of ['version','pageId','requestId','sessionId','storeEpoch','generation','viewRevision'])r[k]=m[k];
        r.type=type;r.sequence=String(++sequence);
        if(type==='ready'){r.appearanceVersion=2;r.capabilities=['appearanceUpdates','shellState','shellActions']}
        window.webkit.messageHandlers.cockpit.postMessage(JSON.stringify(r));
      }
      window.modelPlanCockpit={receive(raw){
        const m=JSON.parse(raw);
        if(m.type==='load')queueMicrotask(()=>receipt(raw,'ready'));
        if(m.type==='appearance')document.querySelector('.ck').dataset.theme=m.theme;
        if(m.type==='shell')document.querySelector('.ck').dataset.shell=JSON.stringify(m.shell||{});
        return true;
      },clear(raw){document.querySelector('.ck').replaceChildren();queueMicrotask(()=>receipt(raw,'cleared'));return true}};
      """#.utf8)
    try html.write(to: web.appendingPathComponent("index.html"))
    try js.write(to: src.appendingPathComponent("main.js"))
    func hash(_ d: Data) -> String {
      SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
    let manifest = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 1, "edition": "community", "interfaceOnly": true,
      "files": ["index.html": hash(html), "src/main.js": hash(js)],
    ])
    try manifest.write(to: web.appendingPathComponent("bundle-manifest.json"))
    let bundle = try VerifiedCockpitBundle(root: web, manifestSHA256: hash(manifest))
    let (app, client) = try await make(root, bundle: bundle, nativeCockpit: true)
    app.showConsole()
    let deadline = ContinuousClock.now + .seconds(8)
    while app.composition.renderedSnapshotForChecks().element("g1-cockpit-label") == nil,
      ContinuousClock.now < deadline
    { try await Task.sleep(for: .milliseconds(10)) }
    let snapshot = app.composition.renderedSnapshotForChecks()
    let node = try XCTUnwrap(snapshot.element("g1-cockpit-label"))
    XCTAssertEqual(node.text, "G1 cockpit painted marker")
    let facade = app.renderedSnapshotForChecks()
    let shell = try XCTUnwrap(facade.cockpit)
    XCTAssertEqual(shell.role, .cockpitShell); XCTAssertNotNil(shell.frame)
    let exported = try XCTUnwrap(facade.find("g1-cockpit-label"))
    XCTAssertEqual(exported.text, node.text); XCTAssertEqual(exported.ink, node.ink)
    XCTAssertEqual(exported.contrastToParent, node.contrastAgainstParent)
    XCTAssertNil(exported.frame, "Unmapped CSS coordinates are not screen points")
    XCTAssertEqual(facade.find("g1-cockpit-disabled")?.interaction,.disabled)
    XCTAssertEqual(snapshot.element("cockpit.dom")?.visible, true)
    XCTAssertEqual(snapshot.element("g1-transparent")?.visible, false)
    XCTAssertEqual(snapshot.element("g1-transparent-child")?.visible, false)
    XCTAssertEqual(node.ink?.hex, "#112233FF")
    XCTAssertGreaterThan(try XCTUnwrap(node.frame).width, 0)
    XCTAssertGreaterThan(try XCTUnwrap(node.contrastAgainstParent), 10)
    XCTAssertEqual(snapshot.element("g1-cockpit-disabled")?.interaction.disabled, true)
    XCTAssertNil(snapshot.element("g1-password")?.text)
    XCTAssertEqual(
      snapshot.element("g1-password")?.unavailable["text"], "Secure control content withheld")
    XCTAssertEqual(snapshot.element("cockpit")?.assetSource, "manifest:" + hash(manifest))
    XCTAssertEqual(snapshot.element("cockpit")?.attributes["hasWebView"], "true")
    await client.revoke()
    XCTAssertNil(app.composition.renderedSnapshotForChecks().element("g1-cockpit-label"))
  }
}
