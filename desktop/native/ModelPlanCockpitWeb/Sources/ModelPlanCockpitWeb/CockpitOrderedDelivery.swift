// SPDX-License-Identifier: MIT
import Foundation

enum CockpitDeliveryResult { case accepted, missing, rejected, failed }

/// Serializes one page's outbound calls across invalidations. An old in-flight
/// call must finish before newer work starts; its completion cannot affect the new epoch.
@MainActor final class CockpitOrderedDelivery<Message> {
  typealias Completion = (CockpitDeliveryResult) -> Void
  private struct Job {
    let message: Message, coalesce: String?, isCurrent: () -> Bool, completed: Completion
  }
  private let capacity: Int, deliver: (Message, @escaping Completion) -> Void
  private var queued: [Job] = [], active: Job?
  private var generation: UInt64 = 0, serial: UInt64 = 0
  init(capacity: Int = 32, deliver: @escaping (Message, @escaping Completion) -> Void) {
    self.capacity = capacity; self.deliver = deliver
  }
  /// G3-86: `coalesce` names a whole-state message (shell, untriggered appearance): a newer one
  /// replaces a queued older one, at the back, so host sequence order is kept. A full queue first drops
  /// queued work that is no longer current; only then is the message refused.
  @discardableResult func submit(_ message: Message, coalesce: String? = nil, isCurrent: @escaping () -> Bool,
                                  completed: @escaping Completion) -> Bool {
    guard capacity > 0 else { return false }
    if let coalesce { queued.removeAll { $0.coalesce == coalesce } }
    if !hasRoom { queued.removeAll { !$0.isCurrent() } }
    guard hasRoom else { return false }
    queued.append(Job(message: message, coalesce: coalesce, isCurrent: isCurrent, completed: completed))
    pump(); return true
  }
  private var hasRoom: Bool { queued.count + (active == nil ? 0 : 1) < capacity }
  /// Calls admitted and not yet completed, the active one included.
  var outstanding: Int { queued.count + (active == nil ? 0 : 1) }
  func invalidate() {
    generation &+= 1; queued.removeAll()
  }
  private func pump() {
    guard active == nil else { return }
    while !queued.isEmpty {
      let job = queued.removeFirst()
      guard job.isCurrent() else { continue }
      active = job; serial &+= 1
      let epoch = generation, token = serial
      deliver(job.message) { [weak self] result in
        guard let self, self.serial == token, let current = self.active else { return }
        self.active = nil; self.serial &+= 1
        if self.generation == epoch && current.isCurrent() { current.completed(result) }
        self.pump()
      }
      return
    }
  }
}
