// SPDX-License-Identifier: MIT
import AppKit

/// Only menus whose delegate is the bound Dock are observed; notifications are process-local.
@MainActor final class LivePrivateMenus {
    private let menus = NSHashTable<NSMenu>.weakObjects()
    private var observers: [NSObjectProtocol] = []
    private weak var owner: StaticDockPreviewHost?
    private var scrubbing = false
    func watch(_ host: StaticDockPreviewHost) {
        owner = host
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        // didAddItem also covers menus retained by hidden views before first tracking.
        for name in [NSMenu.didAddItemNotification, NSMenu.didBeginTrackingNotification] {
            let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    guard let self, let owner = self.owner, let menu = note.object as? NSMenu, menu.delegate === owner else { return }
                    self.menus.add(menu)
                }
            }
            observers.append(observer)
        }
    }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
    func scrubAll() {
        guard !scrubbing else { return }
        scrubbing = true; defer { scrubbing = false }
        for menu in menus.allObjects { Self.scrub(menu) }
    }
    static func scrub(_ menu: NSMenu) {
        menu.cancelTrackingWithoutAnimation()
        // Wipe the retained items too, not just the next menu or the menu's item array.
        for item in menu.items {
            if let child = item.submenu { scrub(child) }
            item.title = ""; item.attributedTitle = nil; item.toolTip = nil
            item.representedObject = nil; item.image = nil
            item.identifier = nil
            item.target = nil; item.action = nil; item.isEnabled = false
        }
        menu.removeAllItems()
    }
}
