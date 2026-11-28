// SPDX-License-Identifier: MIT
import Foundation

/// Master spec decision 3 / C13 / C45 (D474): a subscription gets a ring and a cockpit column only after its first good
/// reading on this Mac. There is no "ever read" flag on the wire, so the host keeps this small memory itself
/// (`seen-subscriptions.json`, contract `desktop/tests/shared/seen-subscriptions.json`).
///
/// Privacy: only member keys (a verified subscription reference, 16 lowercase hex, or a session fallback key
/// `<row>#<route>[#<n>]`) are stored; never an account name, an email or a token. Cleared on Forget and on a privacy
/// clear.
public struct DockSeenSubscriptions: Codable, Equatable, Sendable {
    /// The bridge message carries at most this many keys (`seen {ids:[≤64]}`); the store keeps the same bound.
    public static let maxIDs = 64
    public private(set) var ids: [String] = []
    public init(ids: [String] = []) { for id in ids { _ = insert(id) } }

    /// The member key forms (`idForm` in the fixture): a verified reference (16 lowercase hex) or a fallback
    /// `<row>#<route>[#<n>]`. Structural only here; the cockpit bridge also checks the route against the wire's routes.
    /// "all" is a scope, never a member.
    public static func isValidKey(_ key: String) -> Bool {
        if key.utf8.count == 16, key.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) { return true }
        var parts = key.split(separator: "#", omittingEmptySubsequences: false).map(String.init)
        if parts.count == 3 {
            guard let n = Int(parts[2]), (1...1024).contains(n), String(n) == parts[2] else { return false }
            parts.removeLast()
        }
        guard parts.count == 2, let row = parts.first, !row.isEmpty, row.utf16.count <= 128,
              !row.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
              !parts[1].isEmpty, parts[1].utf8.allSatisfy({ (97...122).contains($0) || $0 == 95 }) else { return false }
        return true
    }

    /// Records a key; true when the set changed. An invalid key or a full set changes nothing.
    @discardableResult
    public mutating func insert(_ key: String) -> Bool {
        guard Self.isValidKey(key), !ids.contains(key), ids.count < Self.maxIDs else { return false }
        ids.append(key); return true
    }

    public func contains(_ key: String) -> Bool { ids.contains(key) }

    /// The column / ring rule (fixture `columns.rule`): shown when the key was seen before, or the reading is good now
    /// (value current or retained: normal, stale, failed with the last good kept). Never read on this Mac: no ring.
    public func shows(_ key: String, goodNow: Bool) -> Bool { goodNow || contains(key) }
}

/// The consent scope the memory was written under: the engine store's privacy epoch and consent generation. A Forget
/// advances the generation; a privacy clear (also one done with the CLI while the app is closed) changes the epoch.
public struct DockSeenScope: Codable, Equatable, Sendable {
    public let storeEpoch: String
    public let generation: UInt64
    public init(storeEpoch: String, generation: UInt64) { self.storeEpoch = storeEpoch; self.generation = generation }
}

/// The holder: one JSON file beside `news-clock.json`, written 0600 under the app support directory. A missing or
/// unreadable file starts empty (the next good readings fill it again).
///
/// macrev2-1289-5 (privacy): the file carries the consent scope it was written under. Until the engine's first delivery
/// names the current scope (`adopt`), the saved keys qualify nothing and are not sent; a different scope, or a file
/// without one, drops them from memory and disk. The same scope keeps them across a restart.
public final class DockSeenSubscriptionsStore: @unchecked Sendable {
    private struct File: Codable { var scope: DockSeenScope?; var ids: [String] }
    /// The saved keys (only usable once `scope` is adopted and matches).
    public private(set) var value: DockSeenSubscriptions
    /// G3-135: a numbered fallback member (two unbound accounts on one route) names a list position, not an account, so it
    /// is remembered for this session only and never written to disk.
    public private(set) var session = DockSeenSubscriptions()
    /// The current delivery's scope once known; nil before the first delivery.
    public private(set) var scope: DockSeenScope?
    private var savedScope: DockSeenScope?
    /// Durable keys recorded before the scope was known; kept after adoption.
    private var early = DockSeenSubscriptions()
    private let url: URL?
    /// Called after the set changed (a first good reading, or a clear), so the cockpit page gets a fresh `seen`.
    public var onChange: (() -> Void)?
    /// Called when `adopt` changed what qualifies (the saved keys came into use, or were dropped), so the widget projects
    /// again. Never called from `record` (that runs inside a projection).
    public var onScopeChange: (() -> Void)?
    public init(url: URL? = nil) {
        self.url = url
        if let url, let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(File.self, from: data) {
            value = DockSeenSubscriptions(ids: decoded.ids); savedScope = decoded.scope
        } else { value = DockSeenSubscriptions() }
        // A store without a file (previews, tests) has nothing to protect: it is in scope at once.
        if url == nil { scope = DockSeenScope(storeEpoch: "", generation: 0); savedScope = scope }
    }
    private var adopted: Bool { scope != nil && scope == savedScope }
    /// The engine delivered under `next`. A different scope than the file's (or none on file) drops the saved keys.
    public func adopt(_ next: DockSeenScope) {
        guard scope != next else { return }
        let before = ids
        scope = next
        if savedScope != next {
            value = DockSeenSubscriptions(); session = DockSeenSubscriptions()
            if let url { try? FileManager.default.removeItem(at: url) }
        }
        savedScope = next
        for key in early.ids { _ = value.insert(key) }
        early = DockSeenSubscriptions()
        if !value.ids.isEmpty { save() }
        if ids != before { onChange?(); onScopeChange?() }
    }
    /// What the cockpit page is told (`seen {ids}`): the saved keys, then this session's, at most 64. Nothing before the
    /// scope is known.
    public var ids: [String] {
        guard adopted else { return [] }
        return Array((value.ids + session.ids.filter { !value.contains($0) }).prefix(DockSeenSubscriptions.maxIDs))
    }
    public func shows(_ key: String, goodNow: Bool) -> Bool {
        goodNow || (adopted && (value.contains(key) || session.contains(key)))
    }
    /// Records the members with a good reading now (`durable` false: session only); saves and notifies only on a change.
    /// macrev2-1289-7: the session keys share the one 64-key bound with the saved ones, so the widget never keeps a
    /// member the bridge would cut.
    public func record(_ keys: [(key: String, durable: Bool)]) {
        guard adopted else {
            for entry in keys where entry.durable { _ = early.insert(entry.key) }
            return
        }
        var saved = false, changed = false
        for entry in keys {
            if entry.durable { if value.insert(entry.key) { saved = true; changed = true } }
            else if !value.contains(entry.key), value.ids.count + session.ids.count < DockSeenSubscriptions.maxIDs,
                    session.insert(entry.key) { changed = true }
        }
        if saved { save() }
        if changed { onChange?() }
    }
    /// Forget / privacy clear: the memory goes with the readings.
    public func clear() {
        let had = !value.ids.isEmpty || !session.ids.isEmpty
        value = DockSeenSubscriptions(); session = DockSeenSubscriptions(); early = DockSeenSubscriptions()
        if let url { try? FileManager.default.removeItem(at: url) }
        if had { onChange?() }
    }
    private func save() {
        guard let url, let data = try? JSONEncoder().encode(File(scope: savedScope, ids: value.ids)) else { return }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard (try? data.write(to: url, options: .atomic)) != nil else { return }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
