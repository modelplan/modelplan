// SPDX-License-Identifier: MIT
import Foundation

public enum FirstUseHint: String, CaseIterable, Codable, Sendable {
    case trial, ignition, pinned, page, cockpit
    public var urgent: Bool { self == .trial || self == .pinned }
}

/// App-owned preference value. No UserDefaults, disk access or personal snapshot data.
/// Encoding matches the reference's boolean-key ledger; unknown keys/values are ignored on restore.
public struct FirstUseHintLedger: Codable, Equatable, Sendable {
    public static let storageKey = "r7-help-hints-v1"
    private var flags: Set<FirstUseHint> = []
    public init() {}
    public func hasSeen(_ hint: FirstUseHint) -> Bool { flags.contains(hint) }
    public mutating func mark(_ hint: FirstUseHint) { flags.insert(hint) }
    public mutating func reset() { flags.removeAll() }
    public static func restore(_ data: Data?) -> Self {
        guard let data else { return Self() }
        return (try? JSONDecoder().decode(Self.self, from: data)) ?? Self()
    }
    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        for hint in FirstUseHint.allCases {
            if (try? container.decode(Bool.self, forKey: Key(hint.rawValue))) == true { flags.insert(hint) }
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        for hint in FirstUseHint.allCases where flags.contains(hint) {
            try container.encode(true, forKey: Key(hint.rawValue))
        }
    }
}

public struct HelpHintRequest: Equatable, Sendable {
    public let hint: FirstUseHint
    /// One-based page number, required only for the off-page subscription hint.
    public let pageNumber: Int?
    public init(_ hint: FirstUseHint, pageNumber: Int? = nil) {
        self.hint = hint; self.pageNumber = pageNumber
    }
    public var valid: Bool { hint != .page || (pageNumber ?? 0) > 0 }
}

public enum HelpTiming {
    public static let hintDuration = 5.0
    public static let pointerDwell = 0.5
    public static let afterAction = 0.75
    public static let afterTimeout = 0.2
    public static func dismissalFade(reducedMotion: Bool) -> Double { reducedMotion ? 0 : 0.18 }
}

public struct ActiveHelpHint: Equatable, Sendable {
    public let request: HelpHintRequest
    public let expiresAt: Double
}
public enum HelpHintChange: Equatable, Sendable {
    case show(HelpHintRequest)
    case hide(FirstUseHint)
}

/// Caller drives this value with monotonic elapsed seconds and applies returned effects.
/// canPresent must check visible anchor, app focus, available placement and absence of the help map.
/// An unpresentable hint is skipped without marking its ledger and may be requested again later.
public struct HelpHintQueue: Sendable {
    public private(set) var ledger: FirstUseHintLedger
    public private(set) var active: ActiveHelpHint?
    public private(set) var pending: [HelpHintRequest] = []
    private var nextEligibleAt: Double?
    /// Schedule one deadline callback; enqueue is followed by an immediate advance, not polling.
    public var nextDeadline: Double? { active?.expiresAt ?? (pending.isEmpty ? nil : nextEligibleAt) }
    public init(ledger: FirstUseHintLedger = .init()) { self.ledger = ledger }

    @discardableResult
    public mutating func enqueue(_ request: HelpHintRequest, at now: Double) -> Bool {
        guard now.isFinite, request.valid, !ledger.hasSeen(request.hint), active?.request.hint != request.hint,
              !pending.contains(where: { $0.hint == request.hint }) else { return false }
        if request.hint.urgent {
            pending.insert(request, at: 0)
            if active == nil { nextEligibleAt = nil }
        } else { pending.append(request) }
        return true
    }

    public mutating func advance(at now: Double, canPresent: (HelpHintRequest) -> Bool) -> [HelpHintChange] {
        guard now.isFinite else { return [] }
        if let active {
            return now >= active.expiresAt ? dismiss(at: now, byAction: false) : []
        }
        guard nextEligibleAt.map({ now >= $0 }) ?? true else { return [] }
        nextEligibleAt = nil
        while !pending.isEmpty {
            let request = pending.removeFirst()
            guard !ledger.hasSeen(request.hint), canPresent(request) else { continue }
            ledger.mark(request.hint)
            active = ActiveHelpHint(request: request, expiresAt: now + HelpTiming.hintDuration)
            return [.show(request)]
        }
        return []
    }

    public mutating func dismiss(at now: Double, byAction: Bool = true) -> [HelpHintChange] {
        guard now.isFinite else { return [] }
        let changes = active.map { [HelpHintChange.hide($0.request.hint)] } ?? []
        active = nil
        nextEligibleAt = pending.isEmpty ? nil : now + (byAction ? HelpTiming.afterAction : HelpTiming.afterTimeout)
        return changes
    }

    /// General → Show hints again. Clears active/pending state and all five flags in one transaction.
    /// The assembly owner persists the returned ledger, including an empty reset ledger.
    public mutating func reset() -> [HelpHintChange] {
        let changes = clearPresentation()
        ledger.reset()
        return changes
    }

    /// A preference refresh from another surface cancels old hints without erasing the new flags.
    public mutating func synchronize(with ledger: FirstUseHintLedger) -> [HelpHintChange] {
        let changes = clearPresentation()
        self.ledger = ledger
        return changes
    }
    private mutating func clearPresentation() -> [HelpHintChange] {
        let changes = active.map { [HelpHintChange.hide($0.request.hint)] } ?? []
        active = nil; pending.removeAll(); nextEligibleAt = nil
        return changes
    }
}

/// Stable control IDs replace DOM nodes. Re-entering the same pointer target does not restart its dwell.
public struct HelpDwell: Sendable {
    public private(set) var sourceID: String?
    public private(set) var visibleSourceID: String?
    private var dueAt: Double?
    public var nextDeadline: Double? { dueAt }
    public init() {}
    public mutating func enter(_ sourceID: String, keyboardFocus: Bool, at now: Double) {
        guard now.isFinite else { return }
        guard self.sourceID != sourceID || keyboardFocus else { return }
        leave()
        self.sourceID = sourceID
        if keyboardFocus { visibleSourceID = sourceID }
        else { dueAt = now + HelpTiming.pointerDwell }
    }
    public mutating func advance(at now: Double) {
        guard now.isFinite, let dueAt, now >= dueAt else { return }
        self.dueAt = nil; visibleSourceID = sourceID
    }
    public mutating func leave() { dueAt = nil; sourceID = nil; visibleSourceID = nil }
}
