// SPDX-License-Identifier: MIT
import Foundation

public enum FeedError: Error, Equatable, Sendable {
    case tooLarge, invalidJSON, unsupportedSchema, unsupportedUnits, invalidIdentity, malformed(String)
}

/// Keeps the offset-bearing wire identity as well as the absolute instant. Never rebuckets hourly data.
public struct WireInstant: Codable, Hashable, Sendable {
    public let raw: String
    public let date: Date
    public init(_ raw: String) throws {
        guard let date = InstantParser.parse(raw) else { throw FeedError.malformed("timestamp") }
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
    public static let maximumBytes = 8 * 1024 * 1024
    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        guard data.count <= maximumBytes else { throw FeedError.tooLarge }
        let decoder = JSONDecoder()
        // Validate even unknown additive fields; ignore them in typed projections, never malformed numbers.
        let tree = try decoder.decode(JSONValue.self, from: data); try tree.checkDepth()
        return try decoder.decode(type, from: data)
    }
    public static func personal(_ data: Data) throws -> PersonalSnapshot {
        let value = try decode(PersonalSnapshot.self, data)
        guard value.schemaVersion == 1, value.kind == "modelplan.personal-snapshot" else { throw FeedError.unsupportedSchema }
        return value
    }
    public static func publication(_ data: Data) throws -> PublicPublication {
        let value = try decode(PublicPublication.self, data)
        guard value.schemaVersion == 1 else { throw FeedError.unsupportedSchema }
        guard !value.publicationId.isEmpty else { throw FeedError.invalidIdentity }
        guard Set(value.models.map(\.id)).count == value.models.count, value.models.allSatisfy({ !$0.id.isEmpty }) else { throw FeedError.invalidIdentity }
        return value
    }
}

/// Keeps potentially large decoding work off the main actor, independently of process execution.
public actor DecodeWorker {
    public init() {}
    public func personal(_ data: Data) throws -> PersonalSnapshot { try FeedDecoder.personal(data) }
    public func publication(_ data: Data) throws -> PublicPublication { try FeedDecoder.publication(data) }
}
