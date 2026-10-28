// SPDX-License-Identifier: MIT
import Foundation

/// Composition supplies verified canonical readback, never checkbox state or a grant receipt.
/// CLI production admission remains authoritative for individual readers and in-flight revocation.
public actor ConsentGatedDesktopTransport: CLITransport {
    private let readOnly: any CLITransport
    private let normal: any CLITransport
    private var consent: ConsentPreview?
    private var revision: UInt64 = 0
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
        guard command == .desktop else { return try await readOnly.execute(command) }
        let admitted = consent.map { value in
            value.mode != .off && value.tools.contains {
                $0.accessClass == .standard && $0.detected && $0.allowed
            }
        } ?? false
        return try await (admitted ? normal : readOnly).execute(command)
    }
}
