// SPDX-License-Identifier: MIT
import Foundation

enum CockpitDeliveryResult { case accepted, missing, rejected, failed }

/// Serializes one page's outbound calls across invalidations. An old in-flight
/// call must finish before newer work starts; its completion cannot affect the new epoch.
@MainActor final class CockpitOrderedDelivery<Message> {
  typealias Completion = (CockpitDeliveryResult) -> Void
  private struct Job {
    let message: Message, isCurrent: () -> Bool, completed: Completion
  }
  private let capacity: Int, deliver: (Message, @escaping Completion) -> Void
  private var queued: [Job] = [], active: Job?
  private var generation: UInt64 = 0, serial: UInt64 = 0
  init(capacity: Int = 32, deliver: @escaping (Message, @escaping Completion) -> Void) {
    self.capacity = capacity; self.deliver = deliver
  }
  @discardableResult func submit(_ message: Message, isCurrent: @escaping () -> Bool,
                                  completed: @escaping Completion) -> Bool {
    guard capacity > 0, queued.count + (active == nil ? 0 : 1) < capacity else { return false }
    queued.append(Job(message: message, isCurrent: isCurrent, completed: completed))
    pump(); return true
  }
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
