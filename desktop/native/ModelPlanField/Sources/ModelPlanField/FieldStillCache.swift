// SPDX-License-Identifier: MIT
import Foundation
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

public enum FieldImageError: Error { case invalidPNG, oversized, invalidCache }
public struct PreparedFieldStill: @unchecked Sendable {
    public let png: Data
    public let image: CGImage
    public var decodedBytes: Int { image.bytesPerRow * image.height }
}
/// Header limits precede ImageIO allocation. Only a downsample is retained.
public enum FieldPNG {
    public static let encodedLimit = 8 * 1024 * 1024
    public static func prepare(_ data: Data) throws -> PreparedFieldStill {
        try Task.checkCancellation()
        guard data.count <= encodedLimit else { throw FieldImageError.oversized }
        let bytes = [UInt8](data.prefix(33))
        guard bytes.count == 33, Array(bytes[0..<8]) == [137,80,78,71,13,10,26,10],
              Array(bytes[8..<16]) == [0,0,0,13,73,72,68,82] else { throw FieldImageError.invalidPNG }
        func uint(_ offset: Int) -> UInt64 { bytes[offset..<offset+4].reduce(0) { ($0 << 8) | UInt64($1) } }
        let width = uint(16), height = uint(20)
        guard width > 0, height > 0, width <= 2048, height <= 2048, width * height <= 2048 * 2048 else {
            throw FieldImageError.oversized
        }
        try validateChunks(data)
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1, CGImageSourceGetStatus(source) == .statusComplete,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 640,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw FieldImageError.invalidPNG }
        try Task.checkCancellation()
        return PreparedFieldStill(png: try encode(image), image: image)
    }
    private static let crcTable: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 { crc = (crc & 1) == 1 ? 0xedb88320 ^ (crc >> 1) : crc >> 1 }
        return crc
    }
    private static func validateChunks(_ data: Data) throws {
        try data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            func uint(_ offset: Int) -> UInt32 {
                (0..<4).reduce(0) { ($0 << 8) | UInt32(bytes[offset + $1]) }
            }
            var offset = 8, sawPixels = false
            while offset < bytes.count {
                try Task.checkCancellation()
                guard bytes.count - offset >= 12 else { throw FieldImageError.invalidPNG }
                let length = Int(uint(offset)), kind = uint(offset + 4)
                guard length <= bytes.count - offset - 12 else { throw FieldImageError.invalidPNG }
                let end = offset + 8 + length
                var crc: UInt32 = 0xffffffff
                for i in offset + 4..<end { crc = crcTable[Int((crc ^ UInt32(bytes[i])) & 255)] ^ (crc >> 8) }
                guard crc ^ 0xffffffff == uint(end) else { throw FieldImageError.invalidPNG }
                if kind == 0x49444154 { sawPixels = true } // IDAT
                if kind == 0x49454e44 { // IEND: no incomplete stream or trailing payload.
                    guard length == 0, sawPixels, end + 4 == bytes.count else { throw FieldImageError.invalidPNG }
                    return
                }
                offset = end + 4
            }
            throw FieldImageError.invalidPNG
        }
    }
    public static func encode(_ image: CGImage) throws -> Data {
        try Task.checkCancellation()
        guard image.width > 0, image.height > 0, image.width <= 2048, image.height <= 2048 else { throw FieldImageError.oversized }
        let buffer = NSMutableData()
        guard let target = CGImageDestinationCreateWithData(buffer, UTType.png.identifier as CFString, 1, nil) else {
            throw FieldImageError.invalidPNG
        }
        CGImageDestinationAddImage(target, image, nil)
        guard CGImageDestinationFinalize(target), buffer.length <= encodedLimit else { throw FieldImageError.oversized }
        try Task.checkCancellation()
        return buffer as Data
    }
}

/// Main-actor decoded LRU, with image work and all record IO isolated off the main actor.
/// Tickets prevent delayed stores/reads from replacing newer slots or undoing a cache clear.
@MainActor public final class FieldStillCache {
    private struct Entry { let key: FieldCaptureKey, still: PreparedFieldStill; var used: UInt64 }
    public nonisolated static let diskLimit = 16 * 1024 * 1024
    public nonisolated static let decodedLimit = 8 * 1024 * 1024
    private let disk: FieldDiskCache
    private var entries: [String: Entry] = [:]
    private var tick: UInt64 = 0, memoryGeneration: UInt64 = 0, clearGeneration: UInt64 = 0
    private var slotTickets: [String: UInt64] = [:]
    public var decodedBytes: Int { entries.values.reduce(0) { $0 + $1.still.decodedBytes } }
    public init(directory: URL) throws {
        guard directory.isFileURL else { throw FieldImageError.invalidCache }
        let root = directory.standardizedFileURL.resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        disk = FieldDiskCache(directory: root)
    }
    public func store(_ still: PreparedFieldStill, key: FieldCaptureKey) async throws {
        guard still.png.count <= FieldPNG.encodedLimit, still.decodedBytes <= Self.decodedLimit else { throw FieldImageError.oversized }
        tick &+= 1
        let ticket = tick, memory = memoryGeneration, clear = clearGeneration
        slotTickets[key.slot] = ticket
        guard try await disk.store(still.png, key: key, ticket: ticket) else { return }
        guard clearGeneration == clear, memoryGeneration == memory, slotTickets[key.slot] == ticket else { return }
        entries[key.slot] = Entry(key: key, still: still, used: ticket); trimMemory()
    }
    /// Relaunch lookup matches appearance/viewport/public revision, not historical instance IDs.
    public func load(configuration: FieldConfiguration) async throws -> PreparedFieldStill? {
        let slot = configuration.appearance.theme.rawValue + "-" + configuration.viewport.profile.rawValue
        if var entry = entries[slot], Self.matches(entry.key, configuration) {
            tick &+= 1; entry.used = tick; entries[slot] = entry; return entry.still
        }
        let memory = memoryGeneration, clear = clearGeneration, ticket = slotTickets[slot]
        guard let (key, still) = try await disk.load(configuration: configuration) else { return nil }
        guard clear == clearGeneration, ticket == slotTickets[slot] else { return nil }
        if memory == memoryGeneration {
            tick &+= 1; entries[slot] = Entry(key: key, still: still, used: tick); trimMemory()
        }
        return still
    }
    public func clearDecoded() { memoryGeneration &+= 1; entries.removeAll() }
    public func clear() async throws {
        clearDecoded(); clearGeneration &+= 1; tick &+= 1; slotTickets.removeAll()
        try await disk.clear(ticket: tick)
    }
    fileprivate nonisolated static func matches(_ key: FieldCaptureKey, _ configuration: FieldConfiguration) -> Bool {
        key.appearance == configuration.appearance && key.viewport == configuration.viewport &&
            key.projectionRevision == configuration.projection.revision
    }
    private func trimMemory() {
        while decodedBytes > Self.decodedLimit, let oldest = entries.min(by: { $0.value.used < $1.value.used }) {
            entries.removeValue(forKey: oldest.key)
        }
    }
}

actor FieldDiskCache {
    private struct Record: Codable { let version: Int, key: FieldCaptureKey, digest: String, png: Data }
    private static let slots = ["day-tall", "day-short", "night-tall", "night-short"]
    let directory: URL
    private var latest: [String: UInt64] = [:]
    private var clearTicket: UInt64 = 0
    init(directory: URL) { self.directory = directory }
    func store(_ png: Data, key: FieldCaptureKey, ticket: UInt64) throws -> Bool {
        guard ticket > clearTicket, ticket > (latest[key.slot] ?? 0) else { return false }
        let data = try PropertyListEncoder().encode(Record(version: 1, key: key, digest: Self.digest(png), png: png))
        guard data.count <= FieldPNG.encodedLimit + 64 * 1024 else { throw FieldImageError.oversized }
        let file = url(key.slot)
        if (try? file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { throw FieldImageError.invalidCache }
        try makeRoom(for: data.count, replacing: file)
        try data.write(to: file, options: .atomic)
        latest[key.slot] = ticket; return true
    }
    func load(configuration: FieldConfiguration) throws -> (FieldCaptureKey, PreparedFieldStill)? {
        let slot = configuration.appearance.theme.rawValue + "-" + configuration.viewport.profile.rawValue
        let file = url(slot)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let values = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= FieldPNG.encodedLimit + 64 * 1024 else { throw FieldImageError.invalidCache }
        let record = try PropertyListDecoder().decode(Record.self, from: Data(contentsOf: file))
        guard record.version == 1, record.key.slot == slot, record.digest == Self.digest(record.png),
              FieldStillCache.matches(record.key, configuration) else { return nil }
        return (record.key, try FieldPNG.prepare(record.png))
    }
    func clear(ticket: UInt64) throws {
        clearTicket = max(clearTicket, ticket)
        for slot in Self.slots where (latest[slot] ?? 0) <= ticket {
            let file = url(slot)
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        }
    }
    private func url(_ slot: String) -> URL { directory.appendingPathComponent(slot + ".capture") }
    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func makeRoom(for newBytes: Int, replacing destination: URL) throws {
        let files = try Self.slots.compactMap { slot -> (URL, Int, Date)? in
            let file = url(slot)
            guard FileManager.default.fileExists(atPath: file.path) else { return nil }
            let v = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isSymbolicLinkKey])
            guard v.isSymbolicLink != true else { throw FieldImageError.invalidCache }
            return (file, v.fileSize ?? 0, v.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        var total = files.filter { $0.0 != destination }.reduce(newBytes) { $0 + $1.1 }
        for (file, size, _) in files where file != destination && total > FieldStillCache.diskLimit {
            try FileManager.default.removeItem(at: file); total -= size
        }
    }
}
