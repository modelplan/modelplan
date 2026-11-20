// SPDX-License-Identifier: MIT
import ModelPlanEngineClient
import ModelPlanWire
import XCTest

@testable import ModelPlanCockpitWeb

/// macrevc-844-1: the coordinator hands the saved plugin choices to every page, forwards the page's plugin actions and
/// keeps the running set honest when the page goes or is cleared.
@MainActor private final class PluginPage: CockpitPageSurface {
  var onReady: (() -> Void)?, onIntent: ((CockpitIntent) -> Void)?, onClosed: (() -> Void)?
  var queryTicket: CockpitQueryTicket? { nil }
  var plugins: [Data] = [], readings: [(String, [String: Any])] = [], opened = false
  /// Whether the state arrived before the page was opened (it must be there before the load).
  var pluginsBeforeOpen: [Bool] = []
  func setPlugins(_ json: Data) { plugins.append(json); pluginsBeforeOpen.append(!opened) }
  func sendPluginData(id: String, data: [String: Any]) { readings.append((id, data)) }
  func open() { opened = true }
  func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) {}
  func clearPrivateViews(adopting: CockpitEngineContext?) async {}
  func discard() { onClosed?() }
}

final class PluginCoordinatorTests: XCTestCase {
  private let state = Data(#"{"entries":[{"enabled":true,"id":"placeholder","pinned":false}],"settings":{},"version":1}"#.utf8)
  private func delivery() -> EngineDeliveryContext {
    EngineDeliveryContext(sessionID: "s-" + UUID().uuidString.lowercased(), floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
  }

  @MainActor func testEveryPageGetsTheStateBeforeItOpensAndChangesReachTheCurrentPage() async {
    var pages: [PluginPage] = []
    let coordinator = EngineCockpitCoordinator { _ in let page = PluginPage(); pages.append(page); return page }
    let client = HeldClient(); coordinator.bind(client: client)
    coordinator.pluginsJSON = state
    await coordinator.consume(.context(delivery()))
    coordinator.open()
    XCTAssertEqual(pages.count, 1)
    XCTAssertEqual(pages[0].plugins, [state]); XCTAssertEqual(pages[0].pluginsBeforeOpen, [true])
    let off = Data(#"{"entries":[{"enabled":false,"id":"placeholder","pinned":false}],"settings":{},"version":1}"#.utf8)
    coordinator.pluginsJSON = off
    XCTAssertEqual(pages[0].plugins.last, off, "a Settings change reaches the open page")
    coordinator.pluginsJSON = Data(#"{"entries":[],"settings":{},"version":2}"#.utf8)
    XCTAssertEqual(coordinator.pluginsJSON, off, "a state the page would refuse is never kept")
    XCTAssertEqual(pages[0].plugins.count, 2)
    coordinator.close(); coordinator.open()
    XCTAssertEqual(pages.count, 2)
    XCTAssertEqual(pages[1].plugins, [off], "a reopened page starts from the saved choices")
    await coordinator.shutdown(); await client.stop()
  }

  @MainActor func testRunningSetDrivesReadingsAndEndsWithThePageAndAtAClear() async {
    var pages: [PluginPage] = []
    let coordinator = EngineCockpitCoordinator { _ in let page = PluginPage(); pages.append(page); return page }
    let client = HeldClient(); coordinator.bind(client: client)
    var reports: [[String]] = [], edits: [Data] = []
    coordinator.onPluginsRunning = { reports.append($0) }
    coordinator.onPluginsEdit = { edits.append($0) }
    coordinator.pluginsJSON = state
    let first = delivery()
    await coordinator.consume(.context(first))
    coordinator.open()
    let page = pages[0]
    coordinator.sendPluginData(id: "placeholder", data: ["value": 1])
    XCTAssertTrue(page.readings.isEmpty, "nothing for a plugin the page does not run")
    page.onIntent?(.pluginsRunning(["placeholder"]))
    XCTAssertEqual(reports, [["placeholder"]])
    coordinator.sendPluginData(id: "placeholder", data: ["value": 2])
    coordinator.sendPluginData(id: "other", data: ["value": 3])
    XCTAssertEqual(page.readings.map(\.0), ["placeholder"])
    page.onIntent?(.pluginsRunning(["Bad id"]))
    XCTAssertEqual(reports.count, 1, "an invalid report is ignored")
    page.onIntent?(.pluginsEdit(state))
    XCTAssertEqual(edits, [state])
    // A privacy clear drops the page's placement; the host stops sampling at once.
    await coordinator.consume(.clearPrivateViews(.init(revision: 2, reason: .connectionLost, previous: first, nextFloor: nil)))
    XCTAssertEqual(reports.last, [])
    page.onIntent?(.pluginsRunning(["placeholder"]))
    XCTAssertEqual(reports.last, ["placeholder"])
    coordinator.close()
    XCTAssertEqual(reports.last, [], "a page that goes away runs nothing")
    XCTAssertEqual(coordinator.pluginsRunning, [])
    await coordinator.shutdown(); await client.stop()
  }
}
