// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanWire

private final class Completion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<WireCredentialResult, Never>?
    private var result: WireCredentialResult?
    func install(_ value: CheckedContinuation<WireCredentialResult, Never>) {
        lock.lock()
        if let result { lock.unlock(); value.resume(returning: result) }
        else { continuation = value; lock.unlock() }
    }
    var active: Bool { lock.lock(); defer { lock.unlock() }; return result == nil }
    func finish(_ value: WireCredentialResult) {
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        result = value; let callback = continuation; continuation = nil
        lock.unlock(); callback?.resume(returning: value)
    }
}
/// Interface-only adapter. The caller supplies its authoritative thread-safe context fence.
/// EngineClient owns operation replay, explicit-action matching and final wire/session admission.
/// Logical expiry does not cancel an OS call: one blocked worker retains its slot until it returns.
public final class NativeCredentialAgent: CredentialAgent, @unchecked Sendable {
    private let reader: any FixedItemReading
    private let isCurrent: @Sendable (EngineDeliveryContext) -> Bool
    private let queue = DispatchQueue(label: "ModelPlan.U7.fixed-item")
    private let lock = NSLock()
    private var busy = false
    public init(reader: any FixedItemReading, isCurrent: @escaping @Sendable (EngineDeliveryContext) -> Bool) {
        self.reader = reader; self.isCurrent = isCurrent
    }
    private func acquire() -> Bool { lock.lock(); defer { lock.unlock() }; guard !busy else { return false }; busy = true; return true }
    private func release() { lock.lock(); busy = false; lock.unlock() }
    public func handle(_ operation: EngineCredentialOperation) async -> WireCredentialResult {
        let id = operation.request.operationId
        // Generated request validation already admitted this operationId.
        @Sendable func outcome(_ kind: WireCredentialOutcome) -> WireCredentialResult { try! .init(operationId: id, outcome: kind) }
        guard operation.request.provider == "claude", operation.request.scope == "claude.account_usage.saved_login",
              isCurrent(operation.delivery) else { return outcome(.error) }
        guard !operation.request.interactive || operation.userAction != nil else { return outcome(.denied) }
        guard !Task.isCancelled else { return outcome(.canceled) }
        guard ContinuousClock.now < operation.deadline else { return outcome(.timeout) }
        guard acquire() else { return outcome(.error) }
        let completion = Completion()
        let timeout = Task {
            do { try await Task.sleep(until: operation.deadline, clock: .continuous) }
            catch { return }
            completion.finish(outcome(.timeout))
        }
        defer { timeout.cancel() }
        return await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { callback in
                completion.install(callback)
                queue.async { [self] in
                    defer { release() }
                    guard completion.active, isCurrent(operation.delivery) else { completion.finish(outcome(.canceled)); return }
                    let result = reader.read(.init(interactive: operation.request.interactive))
                    guard completion.active else { return }
                    guard ContinuousClock.now < operation.deadline else { completion.finish(outcome(.timeout)); return }
                    guard isCurrent(operation.delivery) else { completion.finish(outcome(.canceled)); return }
                    let kind = SecurityOutcome.map(result.status)
                    guard kind == .ok else { completion.finish(outcome(kind)); return }
                    guard let data = result.data, data.count <= 64 * 1024,
                          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let oauth = object["claudeAiOauth"] as? [String: Any],
                          let token = oauth["accessToken"] as? String,
                          let wire = try? WireCredentialResult(operationId: id, outcome: .ok, accessToken: token) else {
                        completion.finish(outcome(.error)); return
                    }
                    completion.finish(wire)
                }
            }
        }, onCancel: { completion.finish(outcome(.canceled)) })
    }
}
