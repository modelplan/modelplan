// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore

/// Neutral line illustrations, drawn independently with system ink. No asset or animation timer.
@MainActor public final class SettingsDiagramView: NSView {
    public private(set) var input: SettingsDiagramInput
    public private(set) var reduceMotion = false
    public var language: SettingsLanguage = .chinese { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?
    var playsOnHover = true
    public override var isFlipped: Bool { true }
    public override var intrinsicContentSize: NSSize { .init(width: 96, height: 40) }
    public init(input: SettingsDiagramInput) {
        self.input = input
        super.init(frame: .init(x: 0, y: 0, width: 96, height: 40))
        wantsLayer = true
        setAccessibilityElement(false) // The adjacent native control carries the full value and label.
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    public func apply(_ input: SettingsDiagramInput, reduceMotion: Bool, animate: Bool = false) {
        let changed = self.input != input
        self.input = input; self.reduceMotion = reduceMotion
        if reduceMotion { stop() }
        needsDisplay = true
        if animate && changed { play() }
    }
    public func play() {
        stop()
        guard !reduceMotion, !isHiddenOrHasHiddenAncestor else { return }
        let key: String = { if case .autoCollapse = input { return "transform.translation.x" }; return "transform.translation.y" }()
        let movement = CABasicAnimation(keyPath: key)
        movement.fromValue = key.hasSuffix(".x") ? -8 : 3
        movement.toValue = 0; movement.duration = SettingsDiagramPolicy(reduceMotion: false).duration
        movement.repeatCount = 0; movement.isRemovedOnCompletion = true
        movement.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer?.add(movement, forKey: "settings.lineMovement")
    }
    public func stop() { layer?.removeAnimation(forKey: "settings.lineMovement") }
    public override func viewDidHide() { super.viewDidHide(); stop() }
    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { stop() }; super.viewWillMove(toWindow: newWindow)
    }
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let next = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(next); tracking = next
    }
    public override func mouseEntered(with event: NSEvent) { if playsOnHover { play() } }
    public override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
    public override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); needsDisplay = true }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Logical points give a one-point line on both native backing densities.
        func ink(_ selected: Bool) { (selected ? NSColor.labelColor : .secondaryLabelColor).setStroke() }
        func stroke(_ path: NSBezierPath, selected: Bool) { ink(selected); path.lineWidth = 1; path.stroke() }
        func line(_ a: NSPoint, _ b: NSPoint, selected: Bool = false) {
            let p = NSBezierPath(); p.move(to: a); p.line(to: b); stroke(p, selected: selected)
        }
        func ring(_ centre: NSPoint, radius: CGFloat, selected: Bool) {
            let p = NSBezierPath()
            // Explicit samples avoid dependence on flipped-coordinate arc direction conventions.
            for index in 0...48 {
                let angle = CGFloat(index) / 48 * .pi * 2 * 0.7
                let point = NSPoint(x: centre.x + sin(angle) * radius, y: centre.y - cos(angle) * radius)
                if index == 0 { p.move(to: point) } else { p.line(to: point) }
            }
            stroke(p, selected: selected)
            stroke(NSBezierPath(ovalIn: .init(x: centre.x - radius * 0.60, y: centre.y - radius * 0.60,
                                             width: radius * 1.2, height: radius * 1.2)), selected: selected)
        }
        func label(_ text: String, x: CGFloat, selected: Bool) {
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: selected ? NSColor.labelColor : .secondaryLabelColor]
            let size = (text as NSString).size(withAttributes: attrs)
            (text as NSString).draw(at: .init(x: x - size.width / 2, y: 29), withAttributes: attrs)
        }
        switch input {
        case .edge(let current):
            for (index, edge) in [SettingsDockEdge.left, .bottom, .right].enumerated() {
                let x = CGFloat(index) * 32 + 3.5, selected = current == edge
                stroke(NSBezierPath(roundedRect: .init(x: x, y: 7.5, width: 26, height: 25), xRadius: 2, yRadius: 2), selected: selected)
                switch edge {
                case .left: line(.init(x: x + 4, y: 13), .init(x: x + 4, y: 26), selected: selected)
                case .right: line(.init(x: x + 22, y: 13), .init(x: x + 22, y: 26), selected: selected)
                case .bottom: line(.init(x: x + 7, y: 28), .init(x: x + 20, y: 28), selected: selected)
                }
            }
        case .percentages(let shown, let eventDot):
            for index in 0...1 {
                let x = CGFloat(index) * 49 + 17, selected = shown == (index == 0)
                ring(.init(x: x, y: 20), radius: 11, selected: selected)
                if eventDot {
                    (selected ? NSColor.labelColor : .secondaryLabelColor).setFill()
                    NSBezierPath(ovalIn: .init(x: x + 8, y: 6, width: 3, height: 3)).fill()
                }
                if index == 0 {
                    ("%" as NSString).draw(at: .init(x: 32, y: 14), withAttributes: [
                        .font: NSFont.systemFont(ofSize: 10), .foregroundColor: selected ? NSColor.labelColor : .secondaryLabelColor,
                    ])
                }
            }
        case .autoCollapse(let collapsed):
            for x: CGFloat in [11, 27, 43] { ring(.init(x: x, y: 20), radius: 6, selected: !collapsed) }
            line(.init(x: 56, y: 20.5), .init(x: 71, y: 20.5))
            line(.init(x: 67, y: 16.5), .init(x: 71, y: 20.5))
            line(.init(x: 71, y: 20.5), .init(x: 67, y: 24.5))
            line(.init(x: 84.5, y: 9), .init(x: 84.5, y: 31), selected: collapsed)
        case .size(let selectedSize):
            for (index, item) in [(SettingsSize.small, CGFloat(44)), (.medium, 52), (.large, 64)].enumerated() {
                let x = CGFloat(index) * 32 + 16, selected = item.0 == selectedSize
                ring(.init(x: x, y: 16), radius: item.1 / 5.5, selected: selected)
                label(item.0.rawValue, x: x, selected: selected)
            }
        case .quotaWindow(_, let pin):
            for (index, option) in PercentagePin.allCases.enumerated() {
                let x = CGFloat(index) * 32 + 16, selected = pin == option
                ring(.init(x: x, y: 15), radius: 10, selected: selected)
                let auto = language == .english ? "Auto" : "自动", week = language == .english ? "W" : "周"
                label(option == .auto ? auto : option == .fiveHour ? "5h" : week, x: x, selected: selected)
            }
        }
    }
}
