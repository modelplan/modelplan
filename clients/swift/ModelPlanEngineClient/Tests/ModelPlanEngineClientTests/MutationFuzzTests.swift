// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanEngineClient

private struct MutationRandom {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
    mutating func index(_ count: Int) -> Int { Int(next() % UInt64(max(1, count))) }
}
private struct MutationFailure: Error { let reason: String }
private struct FrameFingerprint: Equatable {
    let kind: String
    let id: String?
    let method: String?
    let session: String
    let epoch: String?
    let generation: UInt64?
    let payload: WireJSONValue?
    let error: Int?
}

final class MutationFuzzTests: XCTestCase {
    private var root: URL {
        var path = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { path.deleteLastPathComponent() }
        return path
    }
    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
    private func captures() throws -> [Data] {
        try ["WireSuccess", "WireNotification", "WireFailure", "production-rows", "WireRequest"].map { name in
            let raw = try Data(contentsOf: root.appendingPathComponent("schema/app-cli/captures/" + name + ".json"))
            // Compact the producer's real Go encodings without a Double id conversion.
            return try encoder().encode(WireDecoder.decode(WireJSONValue.self, from: raw))
        }
    }
    private func mutate(_ seed: Data, random: inout MutationRandom) throws -> Data {
        var bytes = Array(seed)
        switch random.index(8) {
        case 0:
            if !bytes.isEmpty { bytes[random.index(bytes.count)] ^= UInt8(1 << random.index(8)) }
        case 1: bytes = Array(bytes.prefix(random.index(bytes.count + 1)))
        case 2:
            if !bytes.isEmpty {
                let start = random.index(bytes.count)
                bytes.removeSubrange(start..<min(bytes.count, start + 1 + random.index(64)))
            }
        case 3:
            let position = random.index(bytes.count + 1)
            let extra = (0..<random.index(32)).map { _ in UInt8(truncatingIfNeeded: random.next()) }
            bytes.insert(contentsOf: extra, at: position)
        case 4:
            if !bytes.isEmpty {
                let start = random.index(bytes.count)
                let block = Array(bytes[start..<min(bytes.count, start + 1 + random.index(128))])
                bytes.insert(contentsOf: block, at: start)
            }
        case 5:
            bytes = (0..<random.index(512)).map { _ in UInt8(truncatingIfNeeded: random.next()) }
        case 6:
            let depth = [1, 16, 64, 511, 512, 513, 1024][random.index(7)]
            bytes = Array(repeating: UInt8(91), count: depth) + bytes + Array(repeating: UInt8(93), count: depth)
        default:
            if case .object(var fields) = try WireDecoder.decode(WireJSONValue.self, from: seed) {
                let key = ["jsonrpc", "id", "result", "params", "method", "error", "accessToken"][random.index(7)]
                fields[key] = [.null, .string("synthetic"), .unsigned(UInt64.max), .array([])][random.index(4)]
                bytes = Array(try encoder().encode(WireJSONValue.object(fields)))
            }
        }
        return Data(bytes.prefix(65_536))
    }
    private func verifyFramer(_ data: Data, random: inout MutationRandom) throws {
        let bytes = Array(data)
        var expected: [Data] = []
        var start = 0
        var valid = true
        for index in bytes.indices where bytes[index] == 10 {
            let line = Data(bytes[start..<index])
            if line.count + 1 > WireProtocol.maxFrameBytes || String(data: line, encoding: .utf8) == nil {
                valid = false; break
            }
            expected.append(line); start = index + 1
        }
        if start != bytes.count { valid = false }
        var reader = LineFramer()
        var actual: [Data] = []
        var failed = false
        var offset = data.startIndex
        do {
            while offset < data.endIndex {
                let end = min(data.endIndex, offset + 1 + random.index(257))
                // Nonzero Data slice indices exercise the production chunk boundary.
                actual += try reader.append(data[offset..<end])
                if reader.bufferedBytes > WireProtocol.maxFrameBytes { throw MutationFailure(reason: "framer exceeded cap") }
                offset = end
            }
            try reader.finish()
        } catch let error as MutationFailure { throw error }
        catch { failed = true }
        if failed == valid { throw MutationFailure(reason: "framer acceptance differs from LF/UTF-8 oracle") }
        // A fatal append may discard its batch's earlier valid frames. Delivered
        // frames must still be an unchanged prefix, never bytes from the bad line.
        if actual.count > expected.count || !zip(actual, expected).allSatisfy({ $0.0 == $0.1 }) {
            throw MutationFailure(reason: "framer emitted changed/non-prefix data")
        }
        if valid && actual != expected { throw MutationFailure(reason: "valid framing depends on chunk boundaries") }
    }
    private func fingerprint(_ frame: IncomingFrame) -> FrameFingerprint {
        switch frame {
        case .success(let id, let envelope):
            return FrameFingerprint(kind: "success", id: requestKey(id), method: nil, session: envelope.sessionId,
                epoch: envelope.storeEpoch, generation: envelope.consentGeneration, payload: envelope.data, error: nil)
        case .failure(let failure):
            return FrameFingerprint(kind: "error", id: failure.id.map(requestKey), method: failure.error.message,
                session: failure.error.data.sessionId, epoch: failure.error.data.storeEpoch,
                generation: failure.error.data.consentGeneration, payload: nil, error: failure.error.code)
        case .notification(let method, let envelope):
            return FrameFingerprint(kind: "notification", id: nil, method: method, session: envelope.sessionId,
                epoch: envelope.storeEpoch, generation: envelope.consentGeneration, payload: envelope.data, error: nil)
        }
    }
    private func verifyDecoder(_ data: Data) throws {
        let frame: IncomingFrame
        do { frame = try IncomingFrame(data) } catch { return } // Rejected mutations are expected.
        let encoded: Data
        switch frame {
        case .success(let id, let envelope): encoded = try encoder().encode(WireSuccess(jsonrpc: WireProtocol.jsonrpc, id: id, result: envelope))
        case .failure(let failure): encoded = try encoder().encode(failure)
        case .notification(let method, let envelope): encoded = try encoder().encode(WireNotification(jsonrpc: WireProtocol.jsonrpc, method: method, params: envelope))
        }
        if fingerprint(try IncomingFrame(encoded)) != fingerprint(frame) {
            throw MutationFailure(reason: "accepted frame changed exact id/context/payload on round trip")
        }
    }
    func testCaptureSeededFramerAndDecoderMutations() throws {
        let seeds = try captures()
        let environment = ProcessInfo.processInfo.environment
        let seed = environment["MODELPLAN_SWIFT_FUZZ_SEED"].flatMap(UInt64.init) ?? 0x4d6f64656c506c61
        let seconds = min(3600, max(0, environment["MODELPLAN_SWIFT_FUZZ_SECONDS"].flatMap(Double.init) ?? 0))
        let deadline = ProcessInfo.processInfo.systemUptime + seconds
        let evidence = root.appendingPathComponent(".tmp/transport-fuzz")
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        var random = MutationRandom(state: seed)
        var count = 0
        repeat {
            let before = random.state
            let candidate = try mutate(seeds[random.index(seeds.count)], random: &random)
            if count % 256 == 0 {
                let checkpoint = ["seed": String(seed), "case": String(count), "rngBefore": String(before)]
                try encoder().encode(checkpoint).write(to: evidence.appendingPathComponent("swift-checkpoint.json"), options: .atomic)
            }
            do {
                try verifyFramer(candidate, random: &random)
                try verifyDecoder(candidate)
            } catch {
                try candidate.write(to: evidence.appendingPathComponent("swift-crasher.bin"), options: .atomic)
                XCTFail("mutation failure at seed \(seed), case \(count), rng \(before): \(error)")
                return
            }
            count += 1
        } while count < 512 || ProcessInfo.processInfo.systemUptime < deadline
        print("Swift mutation fuzz: seed=\(seed) cases=\(count) seconds=\(seconds)")
    }
    func testCommittedMalformedStringCrashSeedsThrowWithoutTrap() throws {
        for name in ["invalid-utf8-dictionary-key", "unescaped-control-dictionary-key"] {
            let path = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "bin", subdirectory: "FuzzSeeds"))
            let seed = try Data(contentsOf: path)
            XCTAssertEqual(seed.count, 7)
            XCTAssertThrowsError(try WireDecoder.decode(WireJSONValue.self, from: seed)) { error in
                guard case WireDecodeError.invalidFrame = error else { return XCTFail("missing typed invalid-frame rejection") }
            }
            XCTAssertThrowsError(try IncomingFrame(seed))
            if String(data: seed, encoding: .utf8) == nil {
                var framer = LineFramer()
                XCTAssertThrowsError(try framer.append(seed + Data([10])))
            }
        }
    }
    func testDecoderRejectsMutatedRequiredHeadersAndTokenPlacement() throws {
        for raw in try captures().prefix(3) {
            guard case .object(var fields) = try WireDecoder.decode(WireJSONValue.self, from: raw) else { return XCTFail("missing capture object") }
            fields.removeValue(forKey: "jsonrpc")
            XCTAssertThrowsError(try IncomingFrame(encoder().encode(WireJSONValue.object(fields))))
            fields["jsonrpc"] = .string(WireProtocol.jsonrpc)
            fields["accessToken"] = .string("synthetic-forbidden-token")
            XCTAssertThrowsError(try IncomingFrame(encoder().encode(WireJSONValue.object(fields))))
        }
    }
}
