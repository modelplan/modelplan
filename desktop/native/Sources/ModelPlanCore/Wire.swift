// SPDX-License-Identifier: MIT
import Foundation

public struct ContractCapability: Decodable, Sendable {
    public let status: String
    public let reason: String?
}

public enum FeedError: Error, Equatable, Sendable {
    case tooLarge, invalidJSON, unsupportedSchema, unsupportedUnits, invalidIdentity, malformed(String)
}

/// Keeps the offset-bearing wire identity as well as the absolute instant. Never rebuckets hourly data.
public struct WireInstant: Codable, Hashable, Sendable {
    public let raw: String
    public let date: Date
    public init(_ raw: String) throws {
        guard raw.utf8.count <= 64, raw.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$"#, options: .regularExpression) != nil, let date = InstantParser.parse(raw) else { throw FeedError.malformed("timestamp") }
        self.raw = raw; self.date = date
    }
    public init(from decoder: Decoder) throws { try self.init(decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(raw) }
}

private enum InstantParser {
    static let lock = NSLock()
    static let fractional: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
    static let whole = ISO8601DateFormatter()
    static func parse(_ value: String) -> Date? {
        lock.lock(); defer { lock.unlock() }
        return fractional.date(from: value) ?? whole.date(from: value)
    }
}

/// Opaque evidence/extension values are retained without executing or interpreting them.
public enum JSONValue: Codable, Equatable, Sendable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let x = try? c.decode(Bool.self) { self = .bool(x) }
        else if let x = try? c.decode(Double.self), x.isFinite { self = .number(x) }
        else if let x = try? c.decode(String.self) { self = .string(x) }
        else if let x = try? c.decode([JSONValue].self) { self = .array(x) }
        else if let x = try? c.decode([String: JSONValue].self) { self = .object(x) }
        else { throw FeedError.invalidJSON }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .null: try c.encodeNil(); case .bool(let v): try c.encode(v); case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v); case .array(let v): try c.encode(v); case .object(let v): try c.encode(v) }
    }
    func checkDepth(_ n: Int = 0) throws {
        guard n < 64 else { throw FeedError.invalidJSON }
        switch self { case .array(let a): try a.forEach { try $0.checkDepth(n + 1) }
        case .object(let d): try d.values.forEach { try $0.checkDepth(n + 1) }; default: break }
    }
}

public enum FeedDecoder {
    /// Canonical consent readback only; detection and saved permission are not admission.
    public static func consentPreview(_ data: Data) throws -> ConsentPreview {
        let value = try decode(ConsentPreview.self, data)
        guard value.consentTextVersion > 0, value.tools.count <= 512,
              Set(value.tools.map(\.id)).count == value.tools.count,
              !value.consentText.en.isEmpty, !value.consentText.zh.isEmpty,
              value.consentText.en.utf8.count <= 8192, value.consentText.zh.utf8.count <= 8192,
              value.tools.allSatisfy({ !$0.id.isEmpty && $0.id.utf8.count <= 48 && $0.hosts.count <= 64 })
        else { throw FeedError.invalidIdentity }
        return value
    }
    public static let maximumBytes = 8 * 1024 * 1024
    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        guard data.count <= maximumBytes else { throw FeedError.tooLarge }
        let decoder = JSONDecoder()
        // Bound nesting without materialising unknown extension arrays in a second object graph.
        // JSONDecoder still validates JSON syntax, including skipped additive fields.
        var depth = 0, inString = false, escaped = false
        for byte in data {
            if inString {
                if escaped { escaped = false }
                else if byte == 92 { escaped = true }
                else if byte == 34 { inString = false }
            } else if byte == 34 { inString = true }
            else if byte == 91 || byte == 123 { depth += 1; if depth > 64 { throw FeedError.invalidJSON } }
            else if byte == 93 || byte == 125 { depth -= 1; if depth < 0 { throw FeedError.invalidJSON } }
        }
        guard depth == 0, !inString else { throw FeedError.invalidJSON }
        return try decoder.decode(type, from: data)
    }
    public static func personal(_ data: Data) throws -> PersonalSnapshot {
        let value = try decode(PersonalSnapshot.self, data)
        guard value.contractVersion == nil || value.contractVersion == 1 else { throw FeedError.unsupportedSchema }
        guard value.schemaVersion == 1, value.kind == "modelplan.personal-snapshot" else { throw FeedError.unsupportedSchema }
        guard (value.accounts ?? []).allSatisfy({ !$0.source.isEmpty }),
              (value.sessions ?? []).allSatisfy({ !$0.source.isEmpty }),
              (value.liveSessions ?? []).allSatisfy({ !$0.ref.isEmpty && !$0.source.isEmpty }),
              (value.subscriptions ?? []).allSatisfy({ !$0.subscriptionRef.isEmpty }) else { throw FeedError.invalidIdentity }
        for window in (value.accounts ?? []).flatMap({ $0.windows ?? [] }) {
            if let remaining = window.remainingPercent, !(0...100).contains(remaining) { throw FeedError.malformed("remaining-percent") }
        }
        for session in value.liveSessions ?? [] {
            if let rate = session.rate?.value, rate < 0 { throw FeedError.malformed("generation-rate") }
        }
        return value
    }
    public static func detection(_ data: Data) throws -> DetectionReport {
        let value = try decode(DetectionReport.self, data)
        guard value.schemaVersion == 1 else { throw FeedError.unsupportedSchema }
        let ids = value.tools.map(\.providerId)
        guard value.tools.count <= 512, Set(ids).count == ids.count,
              ids.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 }) else { throw FeedError.invalidIdentity }
        return value
    }
    public static func publication(_ data: Data) throws -> PublicPublication {
        let value = try decode(PublicPublication.self, data)
        guard value.contractVersion == nil || value.contractVersion == 1 else { throw FeedError.unsupportedSchema }
        guard value.schemaVersion == 1 else { throw FeedError.unsupportedSchema }
        guard !value.publicationId.isEmpty else { throw FeedError.invalidIdentity }
        guard Set(value.models.map(\.id)).count == value.models.count, value.models.allSatisfy({ !$0.id.isEmpty }) else { throw FeedError.invalidIdentity }
        for model in value.models {
            let keys = (model.efforts ?? []).map(\.effort)
            guard Set(keys).count == keys.count, keys.allSatisfy({ !$0.isEmpty }) else { throw FeedError.invalidIdentity }
        }
        return value
    }
}

/// Keeps potentially large decoding work off the main actor, independently of process execution.
public actor DecodeWorker {
    public init() {}
    public func personal(_ data: Data) throws -> PersonalSnapshot { try FeedDecoder.personal(data) }
    public func publication(_ data: Data) throws -> PublicPublication { try FeedDecoder.publication(data) }
    public func detection(_ data: Data) throws -> DetectionReport { try FeedDecoder.detection(data) }
}
