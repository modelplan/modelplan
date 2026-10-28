// SPDX-License-Identifier: MIT
import Foundation

/// Wire values from the CLI. This readback neither grants consent nor enables a reader.
public struct ConsentPreview: Decodable, Sendable {
    public enum Mode: String, Decodable, Sendable { case automatic, passive, off }
    public struct Text: Decodable, Sendable { public let en: String; public let zh: String }
    public struct Tool: Decodable, Sendable {
        public enum Access: String, Decodable, Sendable {
            case standard, browserSession = "browser-session", notRead = "not-read"
        }
        public enum Keychain: String, Decodable, Sendable { case allowed, denied, unset }
        public let id: String, displayName: String, backend: String, readerId: String
        public let accessClass: Access
        public let detected: Bool, allowed: Bool
        public let keychain: Keychain
        public let hosts: [String]
    }
    public let generation: UInt64
    public let consentTextVersion: Int
    public let mode: Mode
    public let consentText: Text
    public let tools: [Tool]
}
