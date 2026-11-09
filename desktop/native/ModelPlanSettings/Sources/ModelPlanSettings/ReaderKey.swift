// SPDX-License-Identifier: MIT
import Foundation

/// D90 (2026-11-09): an optional manual key for the key-only providers, offered in the Subscriptions
/// area after auto-detect. The engine owns storage (a 0600 file in the app support directory) and
/// sends the key only to the official host of the chosen region. The app holds the typed key only
/// while the field is on screen and never keeps, logs or echoes it.
public enum ReaderKeyProvider: String, CaseIterable, Sendable {
    case zai, opencodego

    public var title: SettingsText {
        switch self {
        case .zai: return .init("GLM Coding Plan (z.ai)", "GLM 编程套餐（z.ai）")
        case .opencodego: return .init("OpenCode Go", "OpenCode Go")
        }
    }
    public var hasRegion: Bool { self == .zai }
    /// The one line of help under the field.
    public var help: SettingsText {
        switch self {
        case .zai: return .init("Stored on this Mac and sent only to api.z.ai / open.bigmodel.cn to read plan usage",
                                "保存在本机，只发送到 api.z.ai / open.bigmodel.cn 用于读取套餐用量")
        case .opencodego: return .init("Stored on this Mac and sent only to opencode.ai to read plan usage",
                                       "保存在本机，只发送到 opencode.ai 用于读取套餐用量")
        }
    }
}

public enum ReaderKeyRegion: String, CaseIterable, Sendable {
    case global, china
    public var title: SettingsText {
        self == .global ? .init("Global (z.ai)", "国际站（z.ai）") : .init("China (bigmodel.cn)", "国内站（bigmodel.cn）")
    }
}

/// The engine's fixed outcome words (`readerkey/set|test|remove`).
public enum ReaderKeyOutcome: Equatable, Sendable {
    case saved, removed, ok, keyRefused, planLapsed, noKey, unreachable, failed, notAccepted
    public init(wire: String) {
        switch wire {
        case "saved": self = .saved
        case "removed": self = .removed
        case "ok": self = .ok
        case "key_refused": self = .keyRefused
        case "plan_lapsed": self = .planLapsed
        case "no_key": self = .noKey
        case "unreachable": self = .unreachable
        case "not_accepted": self = .notAccepted
        default: self = .failed
        }
    }
    public var message: SettingsText {
        switch self {
        case .saved: return .init("Key saved on this Mac.", "密钥已保存在本机。")
        case .removed: return .init("Key removed.", "密钥已移除。")
        case .ok: return .init("The key works. Plan usage can be read.", "密钥可用，可以读取套餐用量。")
        case .keyRefused: return .init("The provider did not accept this key. Check that it is a key for the chosen site, not a relay or third-party key.",
                                       "服务商不接受这个密钥。请确认它是所选站点的密钥，而不是中转或第三方服务的密钥。")
        case .planLapsed: return .init("The key is valid, but this account has no active plan.", "密钥有效，但这个账号目前没有有效的套餐。")
        case .noKey: return .init("Enter a key first.", "请先输入密钥。")
        case .unreachable: return .init("Could not reach the provider. Check the network and try again.", "无法连接服务商，请检查网络后重试。")
        case .notAccepted: return .init("This text cannot be a key.", "这段文字不可能是密钥。")
        case .failed: return .init("The check could not be completed.", "无法完成检查。")
        }
    }
}

public struct ReaderKeyStatus: Equatable, Sendable {
    public let present: Bool
    public let region: ReaderKeyRegion?
    public init(present: Bool, region: ReaderKeyRegion?) { self.present = present; self.region = region }
}

public struct ReaderKeyReply: Equatable, Sendable {
    public let outcome: ReaderKeyOutcome
    public let status: ReaderKeyStatus
    public init(outcome: ReaderKeyOutcome, status: ReaderKeyStatus) { self.outcome = outcome; self.status = status }
}

/// The engine seam: `readerkey/set`, `readerkey/test` and `readerkey/remove`. `key` is nil to test
/// the key already stored.
@MainActor public protocol ReaderKeyBackend: AnyObject {
    func status(_ provider: ReaderKeyProvider) async -> ReaderKeyStatus
    func set(_ provider: ReaderKeyProvider, key: String, region: ReaderKeyRegion?) async -> ReaderKeyReply
    func test(_ provider: ReaderKeyProvider, key: String?, region: ReaderKeyRegion?) async -> ReaderKeyReply
    func remove(_ provider: ReaderKeyProvider) async -> ReaderKeyReply
    /// Saving a key is the user's explicit choice to have this provider read: grant its consent
    /// through the existing grant path. Returns false when the grant could not be requested.
    func allowReading(_ provider: ReaderKeyProvider) async -> Bool
}

/// State of one key entry. The typed text lives only here, and is cleared after a successful save,
/// a removal and when the entry is dismissed.
@MainActor public final class ReaderKeyEntry {
    public let provider: ReaderKeyProvider
    public private(set) var typed = ""
    public var region: ReaderKeyRegion = .global {
        didSet { if region != oldValue { verifiedKey = nil; message = nil; onChange?() } }
    }
    public private(set) var status = ReaderKeyStatus(present: false, region: nil)
    public private(set) var message: SettingsText?
    public private(set) var isBusy = false
    public var onChange: (() -> Void)?
    private let backend: ReaderKeyBackend
    /// The typed text that last passed a Test.
    private var verifiedKey: String?

    public init(provider: ReaderKeyProvider, backend: ReaderKeyBackend) { self.provider = provider; self.backend = backend }

    private var trimmed: String { typed.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var effectiveRegion: ReaderKeyRegion? { provider.hasRegion ? region : nil }

    public func setTyped(_ text: String) { typed = text; message = nil; if text.trimmingCharacters(in: .whitespacesAndNewlines) != verifiedKey { verifiedKey = nil }; onChange?() }
    /// Test is available with a typed key, or with a saved one when the field is empty.
    public var canTest: Bool { !isBusy && (!trimmed.isEmpty || status.present) }
    public var canSave: Bool { !isBusy && !trimmed.isEmpty }
    public var canRemove: Bool { !isBusy && status.present }

    public func load() async {
        let current = await backend.status(provider)
        status = current
        if let saved = current.region { region = saved }
        onChange?()
    }
    public func test() async {
        guard canTest else { return }
        let key: String? = trimmed.isEmpty ? nil : trimmed
        begin()
        let reply = await backend.test(provider, key: key, region: effectiveRegion)
        if reply.outcome == .ok, let key { verifiedKey = key }
        finish(reply)
    }
    /// Save tests the key first (unless this exact text just passed a Test), saves only a key that
    /// works, then grants the provider's consent so it starts reading without a second step.
    public func save() async {
        guard canSave else { return }
        let key = trimmed
        begin()
        if verifiedKey != key {
            let check = await backend.test(provider, key: key, region: effectiveRegion)
            guard check.outcome == .ok else { finish(check); return }
            verifiedKey = key
        }
        let reply = await backend.set(provider, key: key, region: effectiveRegion)
        guard reply.outcome == .saved else { finish(reply); return }
        typed = ""; verifiedKey = nil
        let allowed = await backend.allowReading(provider)
        isBusy = false; status = reply.status
        message = allowed ? ReaderKeyOutcome.saved.message
            : .init("Key saved, but ModelPlan could not turn reading on. Allow it under Permissions.", "密钥已保存，但未能开启读取。请在“权限”里允许。")
        onChange?()
    }
    public func remove() async {
        guard canRemove else { return }
        begin()
        let reply = await backend.remove(provider)
        if reply.outcome == .removed { typed = "" }
        finish(reply)
    }
    /// Drop the typed key, for example when Settings closes.
    public func dismiss() { typed = ""; verifiedKey = nil; message = nil; onChange?() }

    private func begin() { isBusy = true; message = nil; onChange?() }
    private func finish(_ reply: ReaderKeyReply) {
        isBusy = false; status = reply.status; message = reply.outcome.message; onChange?()
    }
}
