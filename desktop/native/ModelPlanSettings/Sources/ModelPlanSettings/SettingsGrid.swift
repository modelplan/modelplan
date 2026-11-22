// SPDX-License-Identifier: MIT
import AppKit

/// D371 (B5): one column grid for the Subscriptions page. Subscription rows and plugin rows use these same widths,
/// so the alias field, the switch, the grip and the two arrows sit on the same vertical lines in both lists.
@MainActor enum SettingsGrid {
    static let mark: CGFloat = 30
    static let alias: CGFloat = 132
    static let toggle: CGFloat = 40
    static let handle: CGFloat = 22
    static let step: CGFloat = 26
    static let gap: CGFloat = 8
    static let rowHeight: CGFloat = 44
    static let statusFont: CGFloat = 12
    /// Width of the grip and the two arrows with the gaps between them (the "order" columns).
    static var orderColumns: CGFloat { handle + 2 * step + 2 * gap }
    /// Everything right of the name column: alias, switch and order columns with their gaps.
    static var trailingColumns: CGFloat { alias + toggle + orderColumns + 3 * gap }
    /// The "Reading permissions" and path rows (opus-r7): name and note on the left, the button on the right.
    static let rowSpacing: CGFloat = 8

    /// An empty cell of fixed width (a column a row does not use, such as a plugin's alias).
    static func spacer(_ width: CGFloat) -> NSView {
        let view = NSView(); view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }
    /// Puts `content` in the middle of a cell of fixed width.
    static func cell(_ content: NSView, width: CGFloat) -> NSView {
        let box = NSView(); box.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(content)
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: width),
            content.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            box.heightAnchor.constraint(greaterThanOrEqualTo: content.heightAnchor),
        ])
        return box
    }
    /// A thin divider the width of its parent (the lines between rows and blocks).
    static func divider() -> NSBox {
        let line = NSBox(); line.boxType = .separator
        return line
    }
    /// A small grey column title ("Alias", "Show", "Order") above the first row.
    static func headerLabel(_ text: String, width: CGFloat?, alignment: NSTextAlignment) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11); label.textColor = .secondaryLabelColor; label.alignment = alignment
        if let width { label.translatesAutoresizingMaskIntoConstraints = false; label.widthAnchor.constraint(equalToConstant: width).isActive = true }
        return label
    }
    /// A fix action is a blue word inside the status line, not a bordered button (D202).
    static func styleAsLink(_ button: NSButton) {
        let title = button.title
        button.isBordered = false
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: statusFont), .foregroundColor: NSColor.linkColor,
        ])
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}

/// The painted switch: a 34 x 20 track with a round knob. It is an NSButton, so state, target, action and Accessibility
/// stay the system's; only the drawing differs from the checkbox AppKit draws for the `.switch` button type.
@MainActor enum SettingsSwitchPainter {
    static let size = NSSize(width: 40, height: 24)
    static func paint(bounds: NSRect, on: Bool, enabled: Bool) {
        let track = NSRect(x: bounds.midX - 17, y: bounds.midY - 10, width: 34, height: 20)
        let fill: NSColor = on ? .controlAccentColor : .tertiaryLabelColor
        (enabled ? fill : fill.withAlphaComponent(0.4)).setFill()
        NSBezierPath(roundedRect: track, xRadius: 10, yRadius: 10).fill()
        let knob = NSRect(x: on ? track.maxX - 18 : track.minX + 2, y: track.minY + 2, width: 16, height: 16)
        NSColor.white.withAlphaComponent(enabled ? 1 : 0.7).setFill()
        NSBezierPath(ovalIn: knob).fill()
    }
    static func configure(_ button: NSButton) {
        button.setButtonType(.switch); button.isBordered = false; button.title = ""
        button.imagePosition = .noImage; button.focusRingType = .exterior
        button.setAccessibilityRole(.checkBox)
        button.setAccessibilitySubrole(NSAccessibility.Subrole(rawValue: "AXSwitch"))
    }
}

/// A switch with a target and action (the plugin rows).
@MainActor final class PlainSwitchButton: NSButton {
    override init(frame: NSRect) { super.init(frame: frame); SettingsSwitchPainter.configure(self) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override var intrinsicContentSize: NSSize { SettingsSwitchPainter.size }
    override var isEnabled: Bool { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        SettingsSwitchPainter.paint(bounds: bounds, on: state == .on, enabled: isEnabled)
    }
    override func drawFocusRingMask() { NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 10, yRadius: 10).fill() }
    override var focusRingMaskBounds: NSRect { bounds }
}

/// A switch that reports through `ConnectionButton.invoke` (the subscription rows).
@MainActor final class ConnectionSwitchButton: ConnectionButton {
    func becomeSwitch() { SettingsSwitchPainter.configure(self) }
    override var intrinsicContentSize: NSSize { SettingsSwitchPainter.size }
    override var isEnabled: Bool { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        SettingsSwitchPainter.paint(bounds: bounds, on: state == .on, enabled: isEnabled)
    }
    override func drawFocusRingMask() { NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 10, yRadius: 10).fill() }
    override var focusRingMaskBounds: NSRect { bounds }
}
