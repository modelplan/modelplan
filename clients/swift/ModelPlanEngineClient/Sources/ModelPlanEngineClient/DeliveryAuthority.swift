// SPDX-License-Identifier: MIT
import Foundation

/// The actor is the sole writer. Synchronous readers never access actor state.
/// The lock protects the complete value; no user code runs while it is held.
final class DeliveryAuthority: @unchecked Sendable {
    private let lock = NSLock()
    private var accepted: EngineDeliveryContext?

    func replace(with context: EngineDeliveryContext?) {
        lock.lock()
        defer { lock.unlock() }
        accepted = context
    }

    func isCurrent(_ context: EngineDeliveryContext) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return accepted == context
    }
}
