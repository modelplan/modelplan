// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanWire
import XCTest

@testable import ModelPlanCockpitWeb

@MainActor private final class NewsPage: CockpitPageSurface {
  var onReady: (() -> Void)?, onIntent: ((CockpitIntent) -> Void)?, onClosed: (() -> Void)?
  var queryTicket: CockpitQueryTicket? { nil }
  var news: [[CockpitNewsItem]] = []
  func setNews(_ items: [CockpitNewsItem]) { news.append(items) }
  func open() {}
  func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) {}
  func clearPrivateViews(adopting: CockpitEngineContext?) async {}
  func discard() { onClosed?() }
}

/// D466: the coordinator hands the host's news answers to every page (before it loads and on change) and forwards the
/// page's first looks to the app.
final class NewsCoordinatorTests: XCTestCase {
  private func delivery() -> EngineDeliveryContext {
    EngineDeliveryContext(sessionID: "s-" + UUID().uuidString.lowercased(), floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
  }

  @MainActor func testPagesGetTheAnswersOnCreationAndOnChange() async {
    var pages: [NewsPage] = []
    let coordinator = EngineCockpitCoordinator { _ in let page = NewsPage(); pages.append(page); return page }
    let client = HeldClient(); coordinator.bind(client: client)
    let first = [CockpitNewsItem(id: "banked-1", status: .confirmed, until: Date(timeIntervalSince1970: 1_795_000_000))]
    coordinator.newsItems = first
    await coordinator.consume(.context(delivery()))
    coordinator.open()
    XCTAssertEqual(pages.count, 1)
    XCTAssertEqual(pages[0].news, [first], "a new page starts from the current answers")
    let second = [CockpitNewsItem(id: "banked-1", status: .confirmed, until: nil)]
    coordinator.newsItems = second
    XCTAssertEqual(pages[0].news.last, second, "a changed answer reaches the open page")
    coordinator.newsItems = second
    XCTAssertEqual(pages[0].news.count, 2, "an unchanged answer is not sent again")
    await coordinator.shutdown(); await client.stop()
  }

  @MainActor func testTheFirstLooksReachTheApp() async {
    var pages: [NewsPage] = []
    let coordinator = EngineCockpitCoordinator { _ in let page = NewsPage(); pages.append(page); return page }
    let client = HeldClient(); coordinator.bind(client: client)
    var looks: [[CockpitNewsLookEvent]] = []
    coordinator.onNewsLook = { looks.append($0) }
    await coordinator.consume(.context(delivery()))
    coordinator.open()
    let event = CockpitNewsLookEvent(id: "banked-1", status: .confirmed)
    pages[0].onIntent?(.newsLook([event]))
    pages[0].onIntent?(.newsLook([]))
    pages[0].onIntent?(.newsLook((0..<65).map { CockpitNewsLookEvent(id: "e\($0)", status: .announced) }))
    XCTAssertEqual(looks, [[event]], "only a valid batch of 1 to 64 events is forwarded")
    await coordinator.shutdown(); await client.stop()
  }
}
