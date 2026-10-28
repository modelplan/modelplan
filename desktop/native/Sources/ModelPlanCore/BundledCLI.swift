// SPDX-License-Identifier: MIT
import Foundation
import CryptoKit

/// Fixed bundle helper, pinned by a resource included in the app's code signature.
/// Hash verification and process IO occur off the main actor. No PATH or unsigned fallback.
public actor BundledCLI: CLITransport, ConsentJSONTransport {
    private let bundle: URL
    private let environment: [String: String]?
    private let desktopReadMode: DesktopReadMode
    private var verified: ProcessCLITransport?
    public init(bundle: URL, environment: [String: String]? = nil, desktopReadMode: DesktopReadMode = .readOnly) {
        self.bundle = bundle; self.environment = environment; self.desktopReadMode = desktopReadMode
    }
    public func execute(_ command: CLICommand) async throws -> CommandResult {
        try await verifiedTransport().execute(command)
    }
    public func readConsentJSON() async throws -> CommandResult {
        try await verifiedTransport().readConsentJSON()
    }
    public func grantConsentJSON(_ payload: Data) async throws -> CommandResult {
        try await verifiedTransport().grantConsentJSON(payload)
    }
    private func verifiedTransport() throws -> ProcessCLITransport {
        if verified == nil {
            let helper = bundle.appendingPathComponent("Contents/Helpers/modelplan")
            let pin = bundle.appendingPathComponent("Contents/Resources/modelplan.sha256")
            let properties = try helper.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard properties.isRegularFile == true, properties.isSymbolicLink != true,
                  let size = properties.fileSize, size > 0, size <= 128 * 1024 * 1024,
                  (try pin.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 257) <= 256 else { throw TransportError.launchFailed }
            let expected = try String(contentsOf: pin, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            guard expected.count == 64, expected.allSatisfy({ $0.isHexDigit }) else { throw TransportError.launchFailed }
            let bytes = try Data(contentsOf: helper, options: .mappedIfSafe)
            let actual = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            guard actual == expected else { throw TransportError.launchFailed }
            try Task.checkCancellation()
            verified = ProcessCLITransport(executable: helper, environment: environment, desktopReadMode: desktopReadMode)
        }
        guard let verified else { throw TransportError.launchFailed }
        return verified
    }
}
