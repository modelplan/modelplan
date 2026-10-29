// SPDX-License-Identifier: MIT
import Foundation

#if DEBUG && MODELPLAN_E2E_JOURNEY
public struct JourneyAccountRefreshObservation: Sendable {
    public let attempts: Int, successes: Int
    public let lastSuccessAt: Date?
}
#endif

/// Composition supplies verified canonical readback, never checkbox state or a grant receipt.
/// CLI production admission remains authoritative for individual readers and in-flight revocation.
public actor ConsentGatedDesktopTransport: CLITransport {
    private let readOnly: any CLITransport
    private let normal: any CLITransport
    private var consent: ConsentPreview?
    private var revision: UInt64 = 0
    #if DEBUG && MODELPLAN_E2E_JOURNEY
    private var journeyAttempts = 0, journeySuccesses = 0
    private var journeyLastSuccess: Date?
    private var journeyEnabled: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["MODELPLAN_APP_SMOKE"] == "1" && env["MODELPLAN_E2E_JOURNEY"] == "1"
    }
    public var journeyAccountRefresh: JourneyAccountRefreshObservation? {
        guard journeyEnabled else { return nil }
        return .init(attempts: journeyAttempts, successes: journeySuccesses, lastSuccessAt: journeyLastSuccess)
    }
    #endif
    public init(readOnly: any CLITransport, normal: any CLITransport) {
        self.readOnly = readOnly; self.normal = normal
    }
    /// Invalidate before requesting new readback or applying a consent mutation.
    @discardableResult public func invalidateConsent() -> UInt64 {
        consent = nil; revision &+= 1; return revision
    }
    @discardableResult public func installCanonicalReadback(_ value: ConsentPreview, revision expected: UInt64) -> Bool {
        guard expected == revision else { return false }
        consent = value; return true
    }
    public func execute(_ command: CLICommand) async throws -> CommandResult {
        // This seam does not enable account refresh, detection or publication effects.
        guard command == .desktop else {
            #if DEBUG && MODELPLAN_E2E_JOURNEY
            if journeyEnabled, command == .refreshAccount { journeyAttempts += 1 }
            #endif
            let result = try await readOnly.execute(command)
            #if DEBUG && MODELPLAN_E2E_JOURNEY
            if journeyEnabled, command == .refreshAccount, result.exitCode == 0 {
                journeySuccesses += 1; journeyLastSuccess = Date()
            }
            #endif
            return result
        }
        let admitted = consent.map { value in
            value.mode != .off && value.tools.contains {
                $0.accessClass == .standard && $0.detected && $0.allowed
            }
        } ?? false
        return try await (admitted ? normal : readOnly).execute(command)
    }
}
