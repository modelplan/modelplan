// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI || MODELPLAN_U6_DRIVE
  import AppKit
  import Foundation

  /// Attach inside the already admitted synthetic app. The existing guard/loader
  /// supplies liveness and the existing observation writer; this API does no I/O,
  /// admission, input posting, permission request or unrelated-menu inspection.
  @MainActor public final class StatusMenuArrivalObserver {
    private let runID: String, epoch: String
    private let subjectPID: Int32
    private let ownsStatusMenu: (NSMenu) -> Bool
    private let actionForItem: (NSMenuItem) -> StatusMenuAction?
    private let pendingRequest: () -> StatusMenuActionRequest?
    private let isLive: () -> Bool
    private let emit: (StatusMenuArrivalReceipt) -> Void
    private let clock: () -> Double, uptime: () -> Double
    private var lastRequestID: UUID?
    private var token: NSObjectProtocol?
    public init(
      runID: String, epoch: String, ownsStatusMenu: @escaping (NSMenu) -> Bool,
      actionForItem: @escaping (NSMenuItem) -> StatusMenuAction?,
      pendingRequest: @escaping () -> StatusMenuActionRequest?,
      isLive: @escaping () -> Bool, emit: @escaping (StatusMenuArrivalReceipt) -> Void,
      center: NotificationCenter = .default,
      clock: @escaping () -> Double = { Date().timeIntervalSince1970 },
      uptime: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }
    ) {
      self.runID = runID
      self.epoch = epoch
      subjectPID = ProcessInfo.processInfo.processIdentifier
      self.ownsStatusMenu = ownsStatusMenu
      self.actionForItem = actionForItem
      self.pendingRequest = pendingRequest
      self.isLive = isLive
      self.emit = emit
      self.clock = clock
      self.uptime = uptime
      self.center = center
      token = center.addObserver(
        forName: NSMenu.didSendActionNotification, object: nil, queue: .main
      ) { [weak self] note in
        MainActor.assumeIsolated { self?.received(note) }
      }
    }
    private let center: NotificationCenter
    private func received(_ notification: Notification) {
      guard isLive(), let menu = notification.object as? NSMenu, ownsStatusMenu(menu),
        let item = notification.userInfo?["MenuItem"] as? NSMenuItem, item.menu === menu,
        menu.items.contains(where: { $0 === item }), item.isEnabled, !item.isHidden,
        let selector = item.action, let target = item.target as? NSObject,
        target.responds(to: selector),
        let action = actionForItem(item), let request = pendingRequest(), request.runID == runID,
        request.epoch == epoch, request.subjectPID == subjectPID,
        request.action == action, request.requestID != lastRequestID,
        (try? request.validate(now: clock())) != nil
      else { return }
      lastRequestID = request.requestID
      emit(.init(request: request, timestamp: clock(), uptimeSeconds: uptime()))
    }
    public func stop() {
      if let token {
        center.removeObserver(token)
        self.token = nil
      }
    }
    deinit { if let token { center.removeObserver(token) } }
  }
#endif
