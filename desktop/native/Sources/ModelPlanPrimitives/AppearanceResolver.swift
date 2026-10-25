// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit

/// Per-view effective appearance and the correct workspace AX notification center.
/// Coalesces one resource transaction; consumers preserve their semantic deadline and focus objects.
@MainActor public final class AppearanceResolver {
    private weak var view: NSView?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var queued = false, stopped = false
    private var previous: RenderProfile?
    public var onChange: ((RenderProfile) -> Void)?
    public var locale = "en", viewport = "calibration"
    public init(view: NSView) { self.view = view }
    public func start() {
        guard tokens.isEmpty else { return }; stopped = false
        for (center, name) in [(NSWorkspace.shared.notificationCenter, NSWorkspace.accessibilityDisplayOptionsDidChangeNotification),
                                (NotificationCenter.default, NSWindow.didChangeBackingPropertiesNotification),
                                (NotificationCenter.default, NSWindow.didChangeScreenNotification)] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.invalidate() } }
            tokens.append((center, token))
        }
        invalidate()
    }
    public func invalidate() {
        guard !queued, !stopped else { return }; queued = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }; self.queued = false; guard !self.stopped, let view = self.view else { return }
            let workspace = NSWorkspace.shared
            let profile = RenderProfile(dark: view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua,
                scale: (view.window?.backingScaleFactor ?? 2) >= 1.5 ? 2 : 1, locale: self.locale,
                highContrast: workspace.accessibilityDisplayShouldIncreaseContrast,
                reduceMotion: workspace.accessibilityDisplayShouldReduceMotion,
                reduceTransparency: workspace.accessibilityDisplayShouldReduceTransparency,
                colorSpace: SHA256.hash(data: view.window?.colorSpace?.iccProfileData ?? Data()).description, viewport: self.viewport)
            if profile != self.previous { self.previous = profile; self.onChange?(profile) }
        }
    }
    public func stop() { stopped = true; for (center, token) in tokens { center.removeObserver(token) }; tokens.removeAll() }
    deinit { for (center, token) in tokens { center.removeObserver(token) } }
}
