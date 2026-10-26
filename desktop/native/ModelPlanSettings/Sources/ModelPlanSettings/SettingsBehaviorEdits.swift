// SPDX-License-Identifier: MIT
import Foundation

/// App-owned choices only. No case grants service permission or performs an OS/reader operation.
public enum SettingsB21Edit: Sendable {
    case showDock(Bool), autoHide(Bool), reveal(Int), magnification(HoverMagnification)
    case fullscreen(Bool), activeDisplay(Bool), dockEdge(SettingsDockEdge)
    case login(Bool), automaticUpdates(Bool), menuDisplay(MenuDisplay), language(SettingsLanguage)
    case shortcut(ShortcutAction, ShortcutChord), opening(OpeningPreference), countdown(Int)
    case moveSubscription(String, to: Int, expectedOrder: [String]), resetOrder
    case visible(String, Bool), alias(AliasDraft), readerConsent(OptionalReaderID, Bool), resetHints

    public static let keys: Set<SettingKey> = [
        .showDock, .autoHide, .reveal, .magnification, .fullscreen, .activeDisplay, .dockEdge, .order,
        .login, .automaticUpdates, .menuDisplay, .language, .openShortcut, .dockShortcut, .opening, .countdown,
        .visible, .alias, .optionalReaders, .resetHints,
    ]
    public init(key: SettingKey, value: String, subscriptionID: String? = nil) throws {
        switch key {
        case .showDock: if let v = Bool(value) { self = .showDock(v); return }
        case .autoHide: if let v = Bool(value) { self = .autoHide(v); return }
        case .reveal: if let v = Int(value), [100,150,300].contains(v) { self = .reveal(v); return }
        case .magnification: if let v = HoverMagnification(rawValue: value) { self = .magnification(v); return }
        case .fullscreen: if let v = Bool(value) { self = .fullscreen(v); return }
        case .activeDisplay: if let v = Bool(value) { self = .activeDisplay(v); return }
        case .dockEdge: if let v = SettingsDockEdge(rawValue: value) { self = .dockEdge(v); return }
        case .login: if let v = Bool(value) { self = .login(v); return }
        case .automaticUpdates: if let v = Bool(value) { self = .automaticUpdates(v); return }
        case .menuDisplay: if let v = MenuDisplay(rawValue: value) { self = .menuDisplay(v); return }
        case .language: if let v = SettingsLanguage(rawValue: value) { self = .language(v); return }
        case .opening: if let v = OpeningPreference(rawValue: value) { self = .opening(v); return }
        case .countdown: if let v = Int(value), [150,200,250].contains(v) { self = .countdown(v); return }
        case .visible: if let id = subscriptionID, let v = Bool(value) { self = .visible(id, v); return }
        case .optionalReaders:
            if let id = subscriptionID.flatMap(OptionalReaderID.init(rawValue:)), let v = Bool(value) {
                self = .readerConsent(id, v); return
            }
        default: break
        }
        throw SettingsError.invalidPreference
    }
    var subscriptionID: String? {
        switch self {
        case .visible(let id, _), .moveSubscription(let id, _, _): return id
        case .alias(let draft): return draft.subscriptionID
        default: return nil
        }
    }
    func apply(to p: inout SettingsPreferences, catalogue: [String]) throws {
        switch self {
        case .showDock(let v): p.showDock = v
        case .autoHide(let v): p.autoHide = v
        case .reveal(let v): p.revealMilliseconds = v
        case .magnification(let v): p.magnification = v
        case .fullscreen(let v): p.showOverFullscreen = v
        case .activeDisplay(let v): p.followActiveDisplay = v
        case .dockEdge(let v): p.dockEdge = v
        case .login(let v): p.openAtLogin = v
        case .automaticUpdates(let v): p.automaticUpdates = v
        case .menuDisplay(let v): p.menuDisplay = v
        case .language(let v): p.language = v
        case .opening(let v): p.opening = v
        case .countdown(let v): p.beatMilliseconds = v
        case .shortcut(let action, let chord):
            if action == .openCockpit { p.openShortcut = chord } else { p.dockShortcut = chord }
        case .moveSubscription(let id, let index, let expected):
            guard try p.presentedSubscriptionIDs(catalogue, includingHidden: true) == expected else {
                throw SettingsEditorError.staleContext
            }
            try p.subscriptions.move(id, to: index, in: catalogue)
        case .resetOrder: p.subscriptions.resetOrder()
        case .visible(let id, let visible):
            if visible { p.subscriptions.hiddenIDs.remove(id) } else { p.subscriptions.hiddenIDs.insert(id) }
        case .alias(let draft): try draft.commit(to: &p)
        case .readerConsent(let id, let consent): p.readerConsent[id] = consent
        case .resetHints: p.helpHints = .init()
        }
        try p.validate()
    }
}

public enum SettingsHostIntent: Equatable, Sendable {
    case action(SettingsActionRequest)
    case shortcutPreferencesChanged(openCockpit: ShortcutChord, toggleDock: ShortcutChord)
}
/// A persisted user request, not an authorization to execute a system operation.
public struct SettingsHostRequest: Equatable, Sendable {
    public let revision: UInt64
    public let intent: SettingsHostIntent
}

/// Registration applies to this exact chord, never optimistically to a newly saved chord.
public struct SettingsShortcutObservation: Equatable, Sendable {
    public let action: ShortcutAction
    public let chord: ShortcutChord
    public let registration: ShortcutRegistration
    public init(action: ShortcutAction, chord: ShortcutChord, registration: ShortcutRegistration) {
        self.action = action; self.chord = chord; self.registration = registration
    }
}
public extension SettingsPageContext {
    func shortcutPolicy(preferences p: SettingsPreferences) -> ShortcutPolicy {
        var policy = ShortcutPolicy()
        policy.openRegistration = shortcutObservations.last { $0.action == .openCockpit && $0.chord == p.openShortcut }?.registration ?? .notRequested
        policy.dockRegistration = shortcutObservations.last { $0.action == .toggleDock && $0.chord == p.dockShortcut }?.registration ?? .notRequested
        return policy
    }
}
