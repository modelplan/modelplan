import CryptoKit
import Darwin
// SPDX-License-Identifier: MIT
import Foundation

public enum CockpitBundleError: Error {
  case invalidManifest, unsafePath, unsafeRoot, unsafeInventory, unsafeOpen, unsafeRegular,
    integrity, limit
}

/// Caller-pinned build output. Holds hashes and a directory descriptor, never a
/// second asset cache. Every served file is checked again through no-follow FDs.
public final class VerifiedCockpitBundle {
  private struct Manifest: Decodable {
    let schemaVersion: Int
    let edition: String
    let interfaceOnly: Bool
    let files: [String: String]
  }
  private let rootFD: Int32
  private let files: [String: String]
  public let edition: String
  private static let fileLimit = 8 * 1024 * 1024
  static func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
  static func safe(_ path: String) -> Bool {
    !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\")
      && !path.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
      && path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
        !$0.isEmpty && $0 != "." && $0 != ".."
      }
  }
  public init(root: URL, manifestSHA256: String, allowOfficial: Bool = false) throws {
    let fd = open(root.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard fd >= 0 else { throw CockpitBundleError.unsafeRoot }
    do {
      let manifestData = try Self.read("bundle-manifest.json", root: fd)
      guard Self.digest(manifestData) == manifestSHA256 else { throw CockpitBundleError.integrity }
      let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
      guard manifest.schemaVersion == 1, manifest.interfaceOnly,
        manifest.edition == "community" || allowOfficial && manifest.edition == "official",
        !manifest.files.isEmpty, manifest.files.count <= 4096,
        manifest.files["index.html"] != nil,
        manifest.files["bundle-manifest.json"] == nil
      else { throw CockpitBundleError.invalidManifest }
      var total = 0
      for (path, hash) in manifest.files {
        guard Self.safe(path), hash.count == 64,
          hash.allSatisfy({ $0.isHexDigit && !$0.isUppercase })
        else { throw CockpitBundleError.invalidManifest }
        let data = try Self.read(path, root: fd)
        total += data.count
        guard total <= 64 * 1024 * 1024 else { throw CockpitBundleError.limit }
        guard Self.digest(data) == hash else { throw CockpitBundleError.integrity }
      }
      let canonicalRoot = root.resolvingSymlinksInPath()
      guard
        let entries = FileManager.default.enumerator(
          at: canonicalRoot,
          includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey])
      else { throw CockpitBundleError.unsafePath }
      var seen = Set<String>()
      var nodes = 0
      for case let url as URL in entries {
        nodes += 1
        guard nodes <= 8192 else { throw CockpitBundleError.limit }
        let flags = try url.resourceValues(forKeys: [
          .isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey,
        ])
        guard flags.isSymbolicLink != true else { throw CockpitBundleError.unsafePath }
        if flags.isDirectory == true { continue }
        guard flags.isRegularFile == true else { throw CockpitBundleError.unsafeRegular }
        let base = canonicalRoot.standardizedFileURL.pathComponents
        let child = url.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        guard child.starts(with: base), child.count > base.count else {
          throw CockpitBundleError.unsafeInventory
        }
        seen.insert(child.dropFirst(base.count).joined(separator: "/"))
        guard seen.count <= 4097 else { throw CockpitBundleError.limit }
      }
      guard seen == Set(manifest.files.keys).union(["bundle-manifest.json"]) else {
        throw CockpitBundleError.integrity
      }
      self.rootFD = fd
      self.files = manifest.files
      self.edition = manifest.edition
    } catch {
      close(fd)
      throw error
    }
  }
  deinit { close(rootFD) }
  private static func read(_ path: String, root: Int32) throws -> Data {
    guard safe(path) else { throw CockpitBundleError.unsafePath }
    var fd = dup(root)
    guard fd >= 0 else { throw CockpitBundleError.unsafePath }
    defer { close(fd) }
    let parts = path.split(separator: "/").map(String.init)
    for (index, part) in parts.enumerated() {
      let child = openat(
        fd, part,
        O_RDONLY | O_NOFOLLOW | O_CLOEXEC | (index < parts.count - 1 ? O_DIRECTORY : O_NONBLOCK))
      guard child >= 0 else { throw CockpitBundleError.unsafeOpen }
      close(fd)
      fd = child
    }
    var info = stat()
    guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else {
      throw CockpitBundleError.unsafeRegular
    }
    guard info.st_size >= 0, info.st_size <= fileLimit else { throw CockpitBundleError.limit }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
    var data = Data()
    while let chunk = try handle.read(upToCount: 65536), !chunk.isEmpty {
      data.append(chunk)
      guard data.count <= fileLimit else { throw CockpitBundleError.limit }
    }
    return data
  }
  public func resource(path: String) throws -> Data {
    guard let expected = files[path] else { throw CockpitBundleError.unsafePath }
    let data = try Self.read(path, root: rootFD)
    guard Self.digest(data) == expected else { throw CockpitBundleError.integrity }
    return data
  }
}
