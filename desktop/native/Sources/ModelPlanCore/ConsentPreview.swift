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
        /// Display metadata only: legacy strings and the structured host/note form share one projection.
        public let hosts: [String]
        private enum CodingKeys: String, CodingKey {
            case id, displayName, backend, readerId, accessClass, detected, allowed, keychain, hosts, hostDetails
        }
        private struct HostValue: Decodable {
            let text: String
            private enum CodingKeys: String, CodingKey { case host, note }
            init(from decoder: Decoder) throws {
                let value = try decoder.singleValueContainer()
                if let text = try? value.decode(String.self) { self.text = text; return }
                let object = try decoder.container(keyedBy: CodingKeys.self)
                let host = try object.decode(String.self, forKey: .host)
                let note = try object.decodeIfPresent(String.self, forKey: .note)
                if let note, !note.isEmpty {
                    self.text = host + " " + (note.hasPrefix("(") && note.hasSuffix(")") ? note : "(" + note + ")")
                } else { self.text = host }
            }
        }
        public init(from decoder: Decoder) throws {
            let value = try decoder.container(keyedBy: CodingKeys.self)
            id = try value.decode(String.self, forKey: .id)
            displayName = try value.decode(String.self, forKey: .displayName)
            backend = try value.decode(String.self, forKey: .backend)
            readerId = try value.decode(String.self, forKey: .readerId)
            accessClass = try value.decode(Access.self, forKey: .accessClass)
            detected = try value.decode(Bool.self, forKey: .detected)
            allowed = try value.decode(Bool.self, forKey: .allowed)
            keychain = try value.decode(Keychain.self, forKey: .keychain)
            let legacy = try value.decodeIfPresent([HostValue].self, forKey: .hosts)
            if let legacy, !legacy.isEmpty { hosts = legacy.map(\.text) }
            else if let structured = try value.decodeIfPresent([HostValue].self, forKey: .hostDetails) { hosts = structured.map(\.text) }
            else if legacy != nil { hosts = [] }
            else { throw DecodingError.keyNotFound(CodingKeys.hosts, .init(codingPath: value.codingPath, debugDescription: "Expected hosts or hostDetails display metadata")) }
        }
    }
    public let generation: UInt64
    public let consentTextVersion: Int
    public let mode: Mode
    public let consentText: Text
    public let tools: [Tool]
}
