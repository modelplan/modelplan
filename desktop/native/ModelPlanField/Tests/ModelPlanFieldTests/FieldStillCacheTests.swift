// SPDX-License-Identifier: MIT
import XCTest
import ImageIO
@testable import ModelPlanField

func sampleImage(width: Int = 32, height: Int = 24) throws -> CGImage {
    let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return try XCTUnwrap(context.makeImage())
}
final class FieldStillCacheTests: XCTestCase {
    var temporary: [URL] = []
    func directory() throws -> URL {
        let root = ProcessInfo.processInfo.environment["MODELPLAN_FIELD_TEST_ROOT"].map { URL(fileURLWithPath: $0) } ??
            FileManager.default.temporaryDirectory
        let url = root.appendingPathComponent("field-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporary.append(url); return url
    }
    override func tearDownWithError() throws { for url in temporary { try? FileManager.default.removeItem(at: url) } }

    func testPNGPredecodeLimitsAndDownsampleReencode() throws {
        let image = try sampleImage(width: 1200, height: 1000)
        let png = try FieldPNG.encode(image)
        let prepared = try FieldPNG.prepare(png)
        XCTAssertEqual(prepared.image.width, 640)
        XCTAssertLessThanOrEqual(prepared.decodedBytes, FieldStillCache.decodedLimit)
        XCTAssertLessThan(prepared.png.count, FieldPNG.encodedLimit)
        for data in [Data(), Data(repeating: 0, count: 33), Data(png.prefix(33)),
                     Data(repeating: 0, count: FieldPNG.encodedLimit + 1)] {
            XCTAssertThrowsError(try FieldPNG.prepare(data))
        }
        var damaged = png
        damaged[29] ^= 1 // Correct dimensions/signature, invalid chunk checksum.
        XCTAssertThrowsError(try FieldPNG.prepare(damaged))
        var trailing = png; trailing.append(0)
        XCTAssertThrowsError(try FieldPNG.prepare(trailing))
        var forged = [UInt8](png.prefix(33))
        forged[16] = 0; forged[17] = 0; forged[18] = 8; forged[19] = 1 // 2049 pixels, before ImageIO.
        XCTAssertThrowsError(try FieldPNG.prepare(Data(forged)))
    }
    @MainActor func testPersistenceBindsThemeProfileScaleLocaleAndProjectionAcrossRelaunch() async throws {
        let path = try directory()
        let configuration = try fixture()
        var state = FieldLifecycle(configuration: configuration)
        let (_, key) = startLive(&state)
        let prepared = try FieldPNG.prepare(FieldPNG.encode(sampleImage()))
        let first = try FieldStillCache(directory: path)
        try await first.store(prepared, key: key)
        let relaunched = try FieldStillCache(directory: path)
        let restored = try await relaunched.load(configuration: configuration)
        XCTAssertNotNil(restored)
        let missingRevision = try await relaunched.load(configuration: fixture("public-r2"))
        XCTAssertNil(missingRevision)
        let missingTheme = try await relaunched.load(configuration: fixture(theme: .day))
        XCTAssertNil(missingTheme)
        let missingProfile = try await relaunched.load(configuration: fixture(profile: .short))
        XCTAssertNil(missingProfile)
        let changedScale = FieldConfiguration(appearance: configuration.appearance,
            viewport: try .init(width: 800, height: 500, scale: 1, profile: .tall), projection: configuration.projection)
        let missingScale = try await relaunched.load(configuration: changedScale)
        XCTAssertNil(missingScale)
        let changedLocale = FieldConfiguration(appearance: .init(theme: .night, locale: .chinese),
            viewport: configuration.viewport, projection: configuration.projection)
        let missingLocale = try await relaunched.load(configuration: changedLocale)
        XCTAssertNil(missingLocale)
        XCTAssertLessThanOrEqual(relaunched.decodedBytes, FieldStillCache.decodedLimit)
    }
    @MainActor func testReplacementClearCorruptionAndWriteFailurePreserveIndependentPreset() async throws {
        let path = try directory()
        let preset = path.appendingPathComponent("preset.png")
        let png = try FieldPNG.encode(sampleImage())
        try png.write(to: preset)
        let cache = try FieldStillCache(directory: path)
        var state = FieldLifecycle(configuration: try fixture())
        let (_, key) = startLive(&state)
        try await cache.store(FieldPNG.prepare(png), key: key)
        try await cache.store(FieldPNG.prepare(png), key: key)
        let records = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil).filter { $0.pathExtension == "capture" }
        XCTAssertEqual(records.count, 1)
        cache.clearDecoded(); XCTAssertEqual(cache.decodedBytes, 0)
        try Data("interrupted".utf8).write(to: records[0])
        do { _ = try await cache.load(configuration: fixture()); XCTFail("Corrupt record accepted") } catch {}
        try await cache.clear()
        XCTAssertNotNil(try Data(contentsOf: preset))
        let absent = try await cache.load(configuration: fixture())
        XCTAssertNil(absent)
        try FileManager.default.removeItem(at: path)
        do { try await cache.store(FieldPNG.prepare(png), key: key); XCTFail("Missing directory accepted") } catch {}
    }
    @MainActor func testDiskAndDecodedCapsEvictBoundedlyAcrossFourSlots() async throws {
        let path = try directory()
        let cache = try FieldStillCache(directory: path)
        let image = try sampleImage(width: 1024, height: 1024)
        // Exercise budgets independently of the codec's smaller production thumbnails.
        let prepared = PreparedFieldStill(png: Data(repeating: 7, count: 5 * 1024 * 1024), image: image)
        for theme in [FieldTheme.day, .night] { for profile in [FieldProfile.tall, .short] {
            var state = FieldLifecycle(configuration: try fixture(theme: theme, profile: profile))
            let (_, key) = startLive(&state)
            try await cache.store(prepared, key: key)
            XCTAssertLessThanOrEqual(cache.decodedBytes, FieldStillCache.decodedLimit)
            let size = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: [.fileSizeKey]).reduce(0) {
                $0 + (try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
            }
            XCTAssertLessThanOrEqual(size, FieldStillCache.diskLimit)
        } }
    }
    func testOutOfOrderDiskCommitsAndClearCannotRestoreStaleRecord() async throws {
        let path = try directory()
        let disk = FieldDiskCache(directory: path)
        let png = try FieldPNG.prepare(FieldPNG.encode(sampleImage())).png
        var first = FieldLifecycle(configuration: try fixture("r1"))
        var second = FieldLifecycle(configuration: try fixture("r2"))
        let (_, old) = startLive(&first), (_, new) = startLive(&second)
        let accepted = try await disk.store(png, key: new, ticket: 2)
        let stale = try await disk.store(png, key: old, ticket: 1)
        XCTAssertTrue(accepted); XCTAssertFalse(stale)
        let loaded = try await disk.load(configuration: fixture("r2"))
        XCTAssertEqual(loaded?.0, new)
        try await disk.clear(ticket: 3)
        let afterClear = try await disk.store(png, key: new, ticket: 2)
        XCTAssertFalse(afterClear)
        let empty = try await disk.load(configuration: fixture("r2"))
        XCTAssertNil(empty)
    }
    @MainActor func testPlantedRecordSymlinkCannotWriteOutsideCache() async throws {
        let path = try directory()
        let outside = path.appendingPathComponent("independent-preset")
        try Data("keep".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: path.appendingPathComponent("night-tall.capture"), withDestinationURL: outside)
        let cache = try FieldStillCache(directory: path)
        var state = FieldLifecycle(configuration: try fixture())
        let (_, key) = startLive(&state)
        do { try await cache.store(FieldPNG.prepare(FieldPNG.encode(sampleImage())), key: key); XCTFail("Symlink accepted") } catch {}
        XCTAssertEqual(try String(contentsOf: outside), "keep")
    }
}
