// Copyright (c) 2026 qunqin24. Licensed under the Apache License, Version 2.0.
// ModelPlan adaptation: no AppSettings; injected application effects and weak
// window interface. Upstream DockQuit interception is deliberately not ported.
import AppKit

@MainActor public protocol PulsePresenceWindow: AnyObject {
    var isVisible: Bool { get }
    var isMiniaturized: Bool { get }
    func close()
}
extension NSWindow: PulsePresenceWindow {}

/// One owner for the application's Dock/Command-Tab presence across all tracked
/// Settings/cockpit windows. Construction and tracking perform no OS effect.
@MainActor public final class PulseDockPresence {
    private final class WeakWindow {
        weak var value: (any PulsePresenceWindow)?
        init(_ value: any PulsePresenceWindow) { self.value = value }
    }
    private var windows: [WeakWindow] = []
    private var showsIcon: Bool
    private let currentPolicy: () -> NSApplication.ActivationPolicy
    private let setPolicy: (NSApplication.ActivationPolicy) -> Void
    private let activate: () -> Void

    public init(showsIcon: Bool = true,
                currentPolicy: @escaping () -> NSApplication.ActivationPolicy,
                setPolicy: @escaping (NSApplication.ActivationPolicy) -> Void,
                activate: @escaping () -> Void) {
        self.showsIcon = showsIcon; self.currentPolicy = currentPolicy
        self.setPolicy = setPolicy; self.activate = activate
    }
    public convenience init(showsIcon: Bool = true) {
        self.init(showsIcon: showsIcon,
            currentPolicy: { NSApplication.shared.activationPolicy() },
            setPolicy: { _ = NSApplication.shared.setActivationPolicy($0) },
            activate: { NSApplication.shared.activate(ignoringOtherApps: true) })
    }
    public func track(_ window: any PulsePresenceWindow) {
        windows.removeAll { $0.value == nil }
        guard !windows.contains(where: { $0.value === window }) else { return }
        windows.append(WeakWindow(window))
    }
    public func setShowsIcon(_ enabled: Bool, activateIfRegular: Bool = false) {
        showsIcon = enabled; apply(activateIfRegular: activateIfRegular)
    }
    public func apply(closing: (any PulsePresenceWindow)? = nil, activateIfRegular: Bool = false) {
        windows.removeAll { $0.value == nil }
        let open = windows.contains { entry in
            guard let window = entry.value, window !== closing else { return false }
            return window.isVisible || window.isMiniaturized
        }
        let policy: NSApplication.ActivationPolicy = open && showsIcon ? .regular : .accessory
        guard currentPolicy() != policy else { return }
        setPolicy(policy)
        // Restored/programmatic windows must not steal focus. The existing
        // explicit user-presentation owner alone may request reactivation.
        if policy == .regular, activateIfRegular { activate() }
    }
    public func closeWindows() {
        // A snapshot is safe when a close callback re-enters apply/track.
        let open = windows.compactMap(\.value).filter { $0.isVisible || $0.isMiniaturized }
        open.forEach { $0.close() }
        apply()
    }
}
