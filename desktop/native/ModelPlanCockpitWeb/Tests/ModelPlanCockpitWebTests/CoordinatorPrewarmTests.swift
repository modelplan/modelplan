// SPDX-License-Identifier: MIT
import ModelPlanEngineClient
import ModelPlanWire
import XCTest

@testable import ModelPlanCockpitWeb

/// Holds each cockpit query until complete(); the test delivers the reply event while it is held,
/// as the process client does before the call returns.
private actor CountingClient: EngineClient {
  nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { false }
  var requests = 0
  private var waiters: [CheckedContinuation<EngineRequestCompletion, Error>] = []
  func start() throws -> EngineDeliveryContext { throw EngineClientError.notReady }
  func retry() throws -> EngineDeliveryContext { throw EngineClientError.notReady }
  func stop() { complete() }
  func complete() {
    let held = waiters; waiters = []
    for waiter in held { waiter.resume(returning: .init(requestID: .string("synthetic-cockpit"))) }
  }
  func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion {
    requests += 1
    return try await withCheckedThrowingContinuation { waiters.append($0) }
  }
  func subscribeRows(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
  func consent(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
  func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) throws
    -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
  func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) throws -> EngineRequestCompletion {
    throw EngineClientError.unsupportedCapability
  }
  func history(_ query: WireHistoryQueryParams, timeout: Duration?) throws -> EngineRequestCompletion {
    throw EngineClientError.unsupportedCapability
  }
  func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) throws -> EngineRequestCompletion {
    throw EngineClientError.unsupportedCapability
  }
  func publication(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
  func diagnostics(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// A page that loads when prewarmed and is confirmed visible only when opened, like the real one.
@MainActor private final class WarmProbe: CockpitPageSurface {
  let state: CockpitBridgeState
  var onReady: (() -> Void)?, onIntent: ((CockpitIntent) -> Void)?, onClosed: (() -> Void)?, onShown: (() -> Void)?
  var queryTicket: CockpitQueryTicket? { state.queryTicket }
  private(set) var prewarmed = false, opened = 0, discarded = false
  private(set) var displays = 0, displayedWhileHidden = 0
  private var sequence = 0
  init(_ context: CockpitEngineContext) { state = CockpitBridgeState(context: context) }
  private func ack(_ raw: String, _ type: String) {
    var value = try! JSONSerialization.jsonObject(with: Data(raw.utf8)) as! [String: Any]
    value["shell"] = nil; value["appearance"] = nil; value["redBelow"] = nil
    if type == "ready" {
      value["appearanceVersion"] = 2; value["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"]
    }
    value["type"] = type
    sequence += 1
    value["sequence"] = String(sequence)
    _ = try! state.accept(
      String(decoding: try! JSONSerialization.data(withJSONObject: value), as: UTF8.self),
      source: .init(mainFrame: true, origin: "modelplan-cockpit://bundle"))
  }
  private func load() {
    guard !state.ready else { return }
    ack(try! state.load(.init(theme: .night, locale: .en, profile: .full),
      shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall)), "ready")
    onReady?()
  }
  func prewarm() { prewarmed = true; load() }
  func open() {
    opened += 1
    load()
    if opened == 1 { onShown?() }
  }
  func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) {
    guard ticket == queryTicket else { return }
    if opened == 0 { displayedWhileHidden += 1 } else { displays += 1 }
  }
  func clearPrivateViews(adopting: CockpitEngineContext?) async {
    let raw = try! state.clear(adopting: adopting)
    ack(raw, "cleared")
  }
  func requestClose() { discard() }
  func discard() {
    guard !discarded else { return }
    discarded = true
    state.dispose()
    onClosed?()
  }
  /// A page that fails before it is shown, for instance a terminated web content process.
  func failWhileHidden() { discard() }
}

final class CoordinatorPrewarmTests: XCTestCase {
  private func delivery(generation: UInt64 = 3) -> EngineDeliveryContext {
    EngineDeliveryContext(sessionID: "s-" + UUID().uuidString.lowercased(),
      floor: .init(storeEpoch: "synthetic", generation: generation), revision: 2)
  }
  private func reply(_ delivery: EngineDeliveryContext) throws -> EngineClientEvent {
    let data = try JSONDecoder().decode(WireCockpitData.self, from: Data(contentsOf: XCTUnwrap(
      Bundle.module.url(forResource: "cockpit", withExtension: "json", subdirectory: "Fixtures"))))
    let envelope = try WireEnvelope(sessionId: delivery.sessionID, storeEpoch: delivery.floor.storeEpoch,
      consentGeneration: delivery.floor.generation, data: data)
    return .response(requestID: .string("synthetic-reply"), .cockpit(.init(envelope: envelope, delivery: delivery)))
  }
  @MainActor private func settle(_ condition: () async -> Bool) async {
    for _ in 0..<200 {
      if await condition() { return }
      try? await Task.sleep(for: .milliseconds(5))
    }
  }

  /// CKP-SHELL-20: the app's coordinator builds one hidden page after the session is known, without
  /// telling the console a page opened, fills the last reply once, and the click shows that page.
  @MainActor func testPrewarmBuildsOneHiddenPageThatTheClickShowsWithTheLastReplyFirst() async throws {
    var pages: [WarmProbe] = [], opened = 0, closed = 0
    let coordinator = EngineCockpitCoordinator { let page = WarmProbe($0); pages.append(page); return page }
    let client = CountingClient(); coordinator.bind(client: client)
    coordinator.onOpened = { opened += 1 }; coordinator.onClosed = { closed += 1 }
    coordinator.prewarmDelay = .zero
    coordinator.prewarmEnabled = true
    let session = delivery()
    await coordinator.consume(.context(session))
    await settle { pages.count == 1 }
    let warm = try XCTUnwrap(pages.first)
    XCTAssertTrue(warm.prewarmed); XCTAssertEqual(warm.opened, 0); XCTAssertFalse(coordinator.presented)
    XCTAssertEqual(opened, 0, "a hidden page is not an open")
    await settle { await client.requests == 1 }
    var requests = await client.requests
    XCTAssertEqual(requests, 1, "the hidden page fills an empty last reply once")
    await coordinator.consume(try reply(session))
    await client.complete(); await coordinator.joinCurrentQueryForVerification()
    XCTAssertEqual(warm.displayedWhileHidden, 0, "nothing is displayed on a hidden page")
    coordinator.refresh() // what a row change asks for
    requests = await client.requests
    XCTAssertEqual(requests, 1, "row changes while hidden wait for the open")

    coordinator.open()
    XCTAssertEqual(pages.count, 1, "the click shows the prewarmed page; it does not build one")
    XCTAssertEqual(warm.opened, 1); XCTAssertEqual(opened, 1); XCTAssertTrue(coordinator.presented)
    XCTAssertEqual(warm.displays, 1, "the last reply is on screen before any new query returns")
    await settle { await client.requests == 2 }
    requests = await client.requests
    XCTAssertEqual(requests, 2, "and a fresh query replaces it")
    await coordinator.consume(try reply(session))
    XCTAssertEqual(warm.displays, 2)
    await client.complete(); await coordinator.joinCurrentQueryForVerification()

    coordinator.requestClose()
    XCTAssertTrue(warm.discarded); XCTAssertEqual(closed, 1)
    await settle { pages.count == 2 }
    XCTAssertEqual(pages.count, 2, "a closed page is discarded and an empty one is prewarmed in its place")
    XCTAssertTrue(pages[1].prewarmed); XCTAssertEqual(pages[1].opened, 0)
    requests = await client.requests
    XCTAssertEqual(requests, 2, "the replacement does not query while the last reply is current for this delivery")
    await coordinator.shutdown(); await client.complete()
    XCTAssertTrue(pages[1].discarded)
  }

  /// The last reply never crosses a private-view clear or a delivery change, so a reply is never retagged.
  @MainActor func testTheLastReplyIsDroppedWithAClearOrANewDelivery() async throws {
    var pages: [WarmProbe] = []
    let coordinator = EngineCockpitCoordinator { let page = WarmProbe($0); pages.append(page); return page }
    let client = CountingClient(); coordinator.bind(client: client)
    coordinator.prewarmDelay = .zero
    coordinator.prewarmEnabled = true
    let first = delivery()
    await coordinator.consume(.context(first))
    await settle { pages.count == 1 }
    await settle { await client.requests == 1 }
    await coordinator.consume(try reply(first))
    await client.complete(); await coordinator.joinCurrentQueryForVerification()
    await coordinator.consume(.clearPrivateViews(.init(revision: 3, reason: .connectionLost, previous: first, nextFloor: nil)))
    let second = delivery(generation: 4)
    await coordinator.consume(.context(second))
    await settle { pages.last?.queryTicket != nil }
    coordinator.open()
    let shown = try XCTUnwrap(pages.last)
    XCTAssertEqual(shown.opened, 1)
    XCTAssertEqual(shown.displays, 0, "a reply for an earlier delivery is not shown")
    await coordinator.consume(try reply(first))
    XCTAssertEqual(shown.displays, 0, "nor accepted late")
    await coordinator.consume(try reply(second))
    XCTAssertEqual(shown.displays, 1)
    await coordinator.shutdown(); await client.complete()
  }

  /// Memory pressure releases only the hidden page, and normal pressure brings it back. Three hidden
  /// pages that fail in a row stop prewarming until the next open. A close request never closes a hidden page.
  @MainActor func testMemoryPressureAndRepeatedFailuresStopPrewarming() async throws {
    var pages: [WarmProbe] = [], closed = 0
    let coordinator = EngineCockpitCoordinator { let page = WarmProbe($0); pages.append(page); return page }
    let client = CountingClient(); coordinator.bind(client: client)
    coordinator.onClosed = { closed += 1 }
    coordinator.prewarmDelay = .zero
    coordinator.prewarmEnabled = true
    await coordinator.consume(.context(delivery()))
    await settle { pages.count == 1 }
    coordinator.requestClose()
    XCTAssertFalse(pages[0].discarded, "a close request is for a shown page only")
    coordinator.memoryPressureChanged(pressured: true)
    XCTAssertTrue(pages[0].discarded); XCTAssertEqual(closed, 0, "releasing a hidden page is not a close")
    try await Task.sleep(for: .milliseconds(50))
    XCTAssertEqual(pages.count, 1, "no page is rebuilt under pressure")
    coordinator.memoryPressureChanged(pressured: false)
    await settle { pages.count == 2 }
    XCTAssertEqual(pages.count, 2)
    for expected in 3...4 {
      pages.last?.failWhileHidden()
      await settle { pages.count == expected }
    }
    pages.last?.failWhileHidden()
    try await Task.sleep(for: .milliseconds(50))
    XCTAssertEqual(pages.count, 4, "three failures in a row stop prewarming")
    XCTAssertEqual(closed, 0)
    coordinator.open()
    XCTAssertEqual(pages.count, 5, "a click still opens a page")
    coordinator.requestClose()
    await settle { pages.count == 6 }
    XCTAssertEqual(pages.count, 6, "after an open, prewarming resumes")
    await coordinator.shutdown(); await client.complete()
  }

  /// Off unless the app turns it on: no page exists before a click.
  @MainActor func testNoPrewarmByDefault() async throws {
    var pages = 0
    let coordinator = EngineCockpitCoordinator { pages += 1; return WarmProbe($0) }
    let client = CountingClient(); coordinator.bind(client: client)
    await coordinator.consume(.context(delivery()))
    try await Task.sleep(for: .milliseconds(50))
    XCTAssertEqual(pages, 0)
    await coordinator.shutdown()
  }

  #if MODELPLAN_TEST_ONLY_SPI
  /// G3-42: the timing log shows, in a packaged build, that the hidden page was made and how long the click
  /// took to show data. Each line is a stage name with counts and milliseconds, never data.
  @MainActor func testTimingLogShowsThePrewarmAndTheOpenStagesWithoutData() async throws {
    var pages: [WarmProbe] = [], lines: [String] = []
    let saved = CockpitTimingLog.verificationLine
    CockpitTimingLog.verificationLine = { lines.append($0) }
    defer { CockpitTimingLog.verificationLine = saved }
    let coordinator = EngineCockpitCoordinator { let page = WarmProbe($0); pages.append(page); return page }
    let client = CountingClient(); coordinator.bind(client: client)
    coordinator.prewarmDelay = .zero
    coordinator.prewarmEnabled = true
    let session = delivery()
    await coordinator.consume(.context(session))
    await settle { await client.requests == 1 }
    await coordinator.consume(try reply(session))
    await client.complete(); await coordinator.joinCurrentQueryForVerification()
    CockpitTimingLog.markClick()
    coordinator.open()
    await settle { await client.requests == 2 }
    await coordinator.consume(try reply(session))
    await client.complete(); await coordinator.joinCurrentQueryForVerification()
    func stage(_ prefix: String) -> String? { lines.first { $0.hasPrefix(prefix) } }
    XCTAssertNotNil(stage("prewarm build n=1"), "\(lines)")
    XCTAssertNotNil(stage("prewarm ready buildMs="), "\(lines)")
    XCTAssertNotNil(stage("prewarm last-reply buildMs="), "\(lines)")
    XCTAssertNotNil(stage("open page=warm-ready clickMs="), "the click found the hidden page loaded: \(lines)")
    XCTAssertNotNil(stage("open shown clickMs="), "\(lines)")
    XCTAssertNotNil(stage("open display=last clickMs="), "\(lines)")
    XCTAssertNotNil(stage("open display=fresh clickMs="), "\(lines)")
    XCTAssertEqual(lines.filter { $0.hasPrefix("open display=fresh") }.count, 1, "one fresh line per open")
    let order = ["prewarm build", "prewarm ready", "prewarm last-reply", "open page=", "open shown", "open display=last", "open display=fresh"]
      .map { prefix in lines.firstIndex { $0.hasPrefix(prefix) } ?? -1 }
    XCTAssertEqual(order, order.sorted(), "stages in order: \(lines)")
    let shape = try NSRegularExpression(pattern: "^(prewarm|open) [a-z-]+(=[a-z-]+)?( [a-zA-Z]+=-?[0-9a-z-]+)*$")
    for line in lines {
      XCTAssertNotNil(shape.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)), "names and numbers only: \(line)")
      XCTAssertFalse(line.contains(session.sessionID), line)
    }
    await coordinator.shutdown(); await client.complete()
  }
  #endif
}
