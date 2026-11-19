// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

struct LineFramer {
    private var bytes = Data()
    var bufferedBytes: Int { bytes.count }
    mutating func append(_ chunk: Data) throws -> [Data] {
        var result: [Data] = []
        var start = chunk.startIndex
        while start < chunk.endIndex {
            let newline = chunk[start...].firstIndex(of: 10)
            let end = newline.map { chunk.index(after: $0) } ?? chunk.endIndex
            let count = chunk.distance(from: start, to: end)
            guard bytes.count + count <= WireProtocol.maxFrameBytes else { throw EngineClientError.protocolViolation }
            bytes.append(chunk[start..<end])
            if newline != nil {
                bytes.removeLast()
                guard String(data: bytes, encoding: .utf8) != nil else { throw EngineClientError.protocolViolation }
                result.append(bytes)
                bytes = Data()
            } else if bytes.count == WireProtocol.maxFrameBytes {
                throw EngineClientError.protocolViolation // no room remains for LF
            }
            start = end
        }
        return result
    }
    func finish() throws {
        guard bytes.isEmpty else { throw EngineClientError.protocolViolation }
    }
}

/// Recovery contract (cockpit recovery step 5): the engine supervisor's budget. Crashes restart after a capped
/// exponential backoff (1, 2, 4, 8 s, at most 30 s). The fifth crash inside the rolling 600 s window starts a cooldown,
/// after which one half-open attempt runs by itself; while crashes stay inside the window each further crash starts
/// another cooldown. Nothing is sticky: the engine never needs an explicit retry to come back.
struct RestartBudget {
    enum Decision: Equatable { case restart(after: Double), cooldown(after: Double) }
    static let window: Double = 600, limit = 5, cap: Double = 30, cooldown: Double = 120
    private var crashes: [Double] = []
    mutating func recordCrash(at now: Double) -> Decision {
        crashes.removeAll { now - $0 >= Self.window }
        crashes.append(now)
        guard crashes.count < Self.limit else { return .cooldown(after: Self.cooldown) }
        return .restart(after: min(Self.cap, pow(2, Double(crashes.count - 1))))
    }
}

func durationSeconds(_ value: Duration) -> Double {
    let parts = value.components
    return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
}

func requestKey(_ id: WireRequestID) -> String {
    switch id {
    case .string(let value): return "s:" + value
    case .signed(let value): return "n:" + String(value)
    case .unsigned(let value): return "n:" + String(value)
    }
}

func wireJSON<T: Encodable>(_ value: T) throws -> WireJSONValue {
    // This is conversion of an already-typed outbound value, never an inbound
    // decoder bypass. WireRequest validates the sole credential-bearing method.
    try JSONDecoder().decode(WireJSONValue.self, from: JSONEncoder().encode(value))
}

func encodedRequest(_ method: String, id: WireRequestID?, params: WireJSONValue) throws -> Data {
    let request = try WireRequest(jsonrpc: WireProtocol.jsonrpc, id: id, method: method, params: params)
    var bytes = try JSONEncoder().encode(request)
    guard bytes.count < WireProtocol.maxFrameBytes else { throw EngineClientError.protocolViolation }
    bytes.append(10)
    return bytes
}

enum IncomingFrame {
    case success(WireRequestID, WireEnvelope<WireJSONValue>)
    case failure(WireFailure)
    case notification(String, WireEnvelope<WireJSONValue>)

    init(_ bytes: Data) throws {
        let value = try WireDecoder.decode(WireJSONValue.self, from: bytes)
        guard case .object(let fields) = value,
              fields["jsonrpc"] == .string(WireProtocol.jsonrpc) else { throw EngineClientError.protocolViolation }
        if fields["result"] != nil {
            guard fields["error"] == nil, fields["method"] == nil else { throw EngineClientError.protocolViolation }
            let message = try WireDecoder.decode(WireSuccess<WireJSONValue>.self, from: bytes)
            self = .success(message.id, message.result)
        } else if fields["error"] != nil {
            guard fields["method"] == nil else { throw EngineClientError.protocolViolation }
            self = .failure(try WireDecoder.decode(WireFailure.self, from: bytes))
        } else {
            guard fields["id"] == nil, case .string(let method) = fields["method"] else { throw EngineClientError.protocolViolation }
            let message = try WireDecoder.decode(WireNotification<WireJSONValue>.self, from: bytes)
            self = .notification(method, message.params)
        }
    }
}

func decodeEnvelope<T: Codable & Sendable>(_ value: WireEnvelope<WireJSONValue>, as type: T.Type) throws -> WireDecoded<WireEnvelope<T>> {
    try WireDecoder.decodeWithDiagnostics(WireEnvelope<T>.self, from: JSONEncoder().encode(value))
}
