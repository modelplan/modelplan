// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI
  import AppKit
  import XCTest
  @testable import ModelPlanMenuVerification

  private struct Tree: StatusMenuTree {
    struct Node {
      var pid: Int32 = 42
      var role: String
      var title: String?
      var id: String?
      var enabled = true
      var children: [Int] = []
    }
    var nodes: [Int: Node] = [
      1: .init(role: "AXMenuBar", children: [2]), 2: .init(role: "AXMenuBarItem", children: [3]),
      3: .init(role: "AXMenu", children: [4]), 4: .init(role: "AXMenuItem", title: "Refresh / 刷新"),
    ]
    func pid(_ n: Int) throws -> Int32 { nodes[n]!.pid }
    func role(_ n: Int) throws -> String { nodes[n]!.role }
    func title(_ n: Int) throws -> String? { nodes[n]!.title }
    func identifier(_ n: Int) throws -> String? { nodes[n]!.id }
    func enabled(_ n: Int) throws -> Bool { nodes[n]!.enabled }
    func children(_ n: Int) throws -> [Int] { nodes[n]!.children }
  }
  @MainActor private final class Receiver: NSObject {
    var calls = 0
    @objc func refresh(_ sender: Any?) { calls += 1 }
  }
  final class MenuTests: XCTestCase {
    func testOwnExtrasMenuNamedLookupAndAmbiguity() throws {
      var tree = Tree()
      let status = try StatusMenuLocator.statusItem(
        tree: tree, extras: 1, subjectPID: 42, identifier: nil)
      XCTAssertEqual(
        try StatusMenuLocator.item(
          tree: tree, statusItem: status, subjectPID: 42, name: "Refresh / 刷新"), 4)
      tree.nodes[5] = .init(role: "AXMenuItem", title: "Refresh / 刷新")
      tree.nodes[3]!.children.append(5)
      XCTAssertThrowsError(
        try StatusMenuLocator.item(
          tree: tree, statusItem: status, subjectPID: 42, name: "Refresh / 刷新"))
      tree.nodes[1]!.children.append(6)
      tree.nodes[6] = .init(role: "AXMenuBarItem", id: "other")
      XCTAssertThrowsError(
        try StatusMenuLocator.statusItem(tree: tree, extras: 1, subjectPID: 42, identifier: nil))
      XCTAssertEqual(
        try StatusMenuLocator.statusItem(
          tree: tree, extras: 1, subjectPID: 42, identifier: "other"), 6)
    }
    func testForeignPIDWindowTraversalDisabledAndMissingFailClosed() throws {
      var tree = Tree()
      tree.nodes[4]!.pid = 99
      XCTAssertThrowsError(
        try StatusMenuLocator.item(tree: tree, statusItem: 2, subjectPID: 42, name: "Refresh / 刷新"))
      tree = Tree()
      tree.nodes[3]!.role = "AXWindow"
      XCTAssertThrowsError(
        try StatusMenuLocator.item(tree: tree, statusItem: 2, subjectPID: 42, name: "Refresh / 刷新"))
      tree = Tree()
      tree.nodes[4]!.enabled = false
      XCTAssertThrowsError(
        try StatusMenuLocator.item(tree: tree, statusItem: 2, subjectPID: 42, name: "Refresh / 刷新"))
      tree = Tree()
      XCTAssertThrowsError(
        try StatusMenuLocator.item(tree: tree, statusItem: 2, subjectPID: 42, name: "Refresh"))
      tree.nodes[3]!.children = Array(repeating: 4, count: 257)
      XCTAssertThrowsError(
        try StatusMenuLocator.item(tree: tree, statusItem: 2, subjectPID: 42, name: "Refresh / 刷新"))
    }
    func request(
      pid: Int32 = 42, id: UUID = UUID(), epoch: String = "epoch",
      action: StatusMenuAction = .refresh
    ) -> StatusMenuActionRequest {
      .init(
        runID: "run", epoch: epoch, subjectPID: pid, requestID: id, action: action, notBefore: 1000,
        expiresAt: 1100)
    }
    func testArrivalMatcherRequiresFreshNativeCorrelationNotAXSuccess() throws {
      let r = request()
      let receipt = StatusMenuArrivalReceipt(request: r, timestamp: 1005, uptimeSeconds: 50).object
      XCTAssertTrue(
        StatusMenuArrivalReceipt.matches(receipt, request: r, afterUptime: 49, nowUptime: 51))
      let json =
        try JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: receipt))
        as! [String: Any]
      XCTAssertTrue(
        StatusMenuArrivalReceipt.matches(json, request: r, afterUptime: 49, nowUptime: 51))
      for wrong in [
        request(pid: 43, id: r.requestID), request(id: UUID()),
        request(id: r.requestID, epoch: "other"), request(id: r.requestID, action: .settings),
      ] {
        XCTAssertFalse(
          StatusMenuArrivalReceipt.matches(receipt, request: wrong, afterUptime: 49, nowUptime: 51))
      }
      XCTAssertFalse(
        StatusMenuArrivalReceipt.matches(receipt, request: r, afterUptime: 51, nowUptime: 52))
      XCTAssertFalse(
        StatusMenuArrivalReceipt.matches(
          ["event": "status-menu-press-requested", "transportAccepted": true], request: r,
          afterUptime: 49, nowUptime: 51))
      XCTAssertThrowsError(try r.validate(now: 1100))
      XCTAssertThrowsError(
        try StatusMenuActionRequest(
          profile: "owner", runID: "run", epoch: "epoch", subjectPID: 42, requestID: UUID(),
          action: .refresh, notBefore: 1000, expiresAt: 1100
        ).validate(now: 1001))
    }
    @MainActor func testNativeOwnMenuDispatchEmitsOneSanitizedReceipt() async throws {
      _ = NSApplication.shared  // No window, popup, AX/permission query or posted input.
      let menu = NSMenu(title: "private synthetic title must not leak")
      menu.autoenablesItems = false
      let receiver = Receiver()
      let item = NSMenuItem(
        title: "Refresh / 刷新", action: #selector(Receiver.refresh(_:)), keyEquivalent: "")
      item.target = receiver
      menu.addItem(item)
      var pending: StatusMenuActionRequest? = request(
        pid: ProcessInfo.processInfo.processIdentifier)
      var receipts: [StatusMenuArrivalReceipt] = []
      var live = true
      let observer = StatusMenuArrivalObserver(
        runID: "run", epoch: "epoch", ownsStatusMenu: { $0 === menu },
        actionForItem: { $0.action == #selector(Receiver.refresh(_:)) ? .refresh : nil },
        pendingRequest: { pending }, isLive: { live }, emit: { receipts.append($0) },
        clock: { 1005 }, uptime: { 50 })
      defer { observer.stop() }
      menu.performActionForItem(at: 0)
      XCTAssertEqual(receiver.calls, 1)
      XCTAssertEqual(receipts.count, 1)
      menu.performActionForItem(at: 0)
      XCTAssertEqual(receipts.count, 1, "One request has only one arrival")
      let encoded = try JSONSerialization.data(withJSONObject: XCTUnwrap(receipts.first).object)
      XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("private synthetic"))
      let foreign = NSMenu()
      foreign.autoenablesItems = false
      let other = NSMenuItem(
        title: "Refresh / 刷新", action: #selector(Receiver.refresh(_:)), keyEquivalent: "")
      other.target = receiver
      foreign.addItem(other)
      pending = request(pid: ProcessInfo.processInfo.processIdentifier)
      foreign.performActionForItem(at: 0)
      XCTAssertEqual(receipts.count, 1)
      live = false
      menu.performActionForItem(at: 0)
      XCTAssertEqual(receipts.count, 1)
      live = true
      pending = request(pid: 99999)
      menu.performActionForItem(at: 0)
      XCTAssertEqual(receipts.count, 1)
      observer.stop()
      pending = request(pid: ProcessInfo.processInfo.processIdentifier)
      menu.performActionForItem(at: 0)
      XCTAssertEqual(receipts.count, 1)
    }
  }
#endif
