// SPDX-License-Identifier: MIT
#if MODELPLAN_VERIFICATION_ROWS
import Foundation
import ModelPlanWire
import ModelPlanEngineClient
import ModelPlanEngineStore

private final class VerificationAuthority: @unchecked Sendable {
    private let lock = NSLock()
    private var current: EngineDeliveryContext?
    func set(_ value: EngineDeliveryContext?) { lock.lock(); defer { lock.unlock() }; current = value }
    func isCurrent(_ value: EngineDeliveryContext) -> Bool { lock.lock(); defer { lock.unlock() }; return current == value }
}

/// Compiled only into the explicitly marked verification application.
public actor VerificationRowsClient: EngineClient {
    private let store: EngineStore
    private let home: URL
    private var context = EngineDeliveryContext(sessionID: UUID().uuidString, floor: .init(storeEpoch: "verification-rows", generation: 1), revision: 1)
    private nonisolated let authority = VerificationAuthority()
    private var monitor: Task<Void, Never>?
    private var lastBytes: Data?
    public init(store: EngineStore, home: URL) { self.store = store; self.home = home }
    public nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { authority.isCurrent(context) }
    private static func load(home: URL) throws -> (WireRowsSnapshot, Data) {
        let marker = home.appendingPathComponent(".modelplan-verification-home", isDirectory: false)
        let file = home.appendingPathComponent(".modelplan-verification-rows.json", isDirectory: false)
        let fm = FileManager.default
        for path in [marker, file] {
            let attributes = try fm.attributesOfItem(atPath: path.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? NSNumber, size.intValue <= 1_048_576 else { throw EngineClientError.invalidConfiguration }
        }
        guard try String(contentsOf: marker, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) == "MODELPLAN VERIFICATION HOME" else { throw EngineClientError.invalidConfiguration }
        let bytes = try Data(contentsOf: file)
        return (try WireDecoder.decode(WireRowsSnapshot.self, from: bytes), bytes)
    }
    public nonisolated static func validateHome(_ home: URL) throws { _ = try load(home: home) }
    private func publish() async throws {
        let (rows, bytes) = try Self.load(home: home)
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        lastBytes = bytes
    }
    public func start() async throws -> EngineDeliveryContext {
        _ = try Self.load(home: home) // Fail closed; never start a CLI when the synthetic profile is invalid.
        monitor?.cancel()
        context = EngineDeliveryContext(sessionID: UUID().uuidString, floor: .init(storeEpoch: "verification-rows", generation: 1), revision: 1)
        authority.set(context)
        await store.consume(.connection(.ready(context)))
        do { try await publish() }
        catch { authority.set(nil); throw error }
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                await self?.publishChangedFixture()
            }
        }
        return context
    }
    private func publishChangedFixture() async {
        guard authority.isCurrent(context), let (_, bytes) = try? Self.load(home: home), bytes != lastBytes else { return }
        try? await publish()
    }
    public func stop() async {
        authority.set(nil)
        monitor?.cancel(); monitor = nil; lastBytes = nil
        await store.consume(.connection(.stopped(.requested)))
    }
    public func retry() async throws -> EngineDeliveryContext { try await start() }
    public func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("verification-subscribe")) }
    public func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { try await publish(); return .init(requestID: .string("verification-refresh")) }
    public func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    public func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    public func history(_ query: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    public func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    public func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    public func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    public func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
#endif
