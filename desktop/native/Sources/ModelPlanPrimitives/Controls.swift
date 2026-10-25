// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore

/// Provisional reference values only. Task 38 revises these later; consumers/tests use this one source.
public struct DockTiming: Equatable, Sendable {
    public var revealDwell = 0.150, hideGrace = 0.320, hitZone: CGFloat = 4, slack: CGFloat = 6
    public init() {}
}

@MainActor public final class EffortControl: NSControl {
    public let stableID: String
    public private(set) var efforts: [String], current: Int?, recommended: Int?, trial: Int?
    private var chinese = false
    public init(id: String, efforts: [String], current: Int?, recommended: Int?) {
        stableID = id; self.efforts = efforts; self.current = current; self.recommended = recommended
        super.init(frame: .zero); wantsLayer = true; focusRingType = .exterior
        setAccessibilityElement(true); setAccessibilityRole(.slider); setAccessibilityIdentifier(id)
        refreshSemantics()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    public override var acceptsFirstResponder: Bool { true }
    public func localize(chinese: Bool) { guard self.chinese != chinese else { return }; self.chinese = chinese; refreshSemantics(); needsDisplay = true }
    public func choose(_ index: Int) { guard efforts.indices.contains(index), trial != index else { return }; trial = index; refreshSemantics(); needsDisplay = true; sendAction(action, to: target) }
    public func clearTrial() { guard trial != nil else { return }; trial = nil; refreshSemantics(); needsDisplay = true }
    public override func accessibilityPerformIncrement() -> Bool {
        let next = min(efforts.count - 1, (trial ?? current ?? -1) + 1)
        guard efforts.indices.contains(next), next != (trial ?? current) else { return false }; choose(next); return true
    }
    public override func accessibilityPerformDecrement() -> Bool {
        let next = max(0, (trial ?? current ?? efforts.count) - 1)
        guard efforts.indices.contains(next), next != (trial ?? current) else { return false }; choose(next); return true
    }
    public override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126, 124: _ = accessibilityPerformIncrement()
        case 125, 123: _ = accessibilityPerformDecrement()
        case 53: clearTrial()
        default: super.keyDown(with: event)
        }
    }
    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        choose(max(0, min(efforts.count - 1, Int((point.x - 12) / max(1, bounds.width - 24) * CGFloat(efforts.count)))))
    }
    private func name(_ value: Int?) -> String { value.flatMap { efforts.indices.contains($0) ? efforts[$0] : nil } ?? (chinese ? "未知" : "unknown") }
    private func refreshSemantics() {
        setAccessibilityLabel(chinese ? "推理档位（仅本地试选）" : "Native effort (local trial only)")
        setAccessibilityValue((trial ?? current).map(NSNumber.init(value:))); setAccessibilityMinValue(0); setAccessibilityMaxValue(max(0, efforts.count - 1))
        let trialName = trial == nil ? (chinese ? "未试选" : "none") : name(trial)
        setAccessibilityValueDescription(chinese ? "当前 \(name(current))；试选 \(trialName)；推荐 \(name(recommended))" : "Current \(name(current)); trial \(trialName); recommended \(name(recommended))")
        setAccessibilityHelp(chinese ? "方向键试选；Escape 返回，不修改 Agent 设置。" : "Arrow keys try an effort; Escape returns. Agent settings are unchanged.")
        NSAccessibility.post(element: self, notification: .valueChanged)
    }
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.controlBackgroundColor.setFill(); NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
        for (index, effort) in efforts.enumerated() {
            let x = 12 + CGFloat(index) / CGFloat(max(1, efforts.count - 1)) * (bounds.width - 72)
            let label = (index == recommended ? "★ " : "") + effort
            (label as NSString).draw(at: NSPoint(x: x, y: 8), withAttributes: attributes)
            let point = NSPoint(x: x + 6, y: 36)
            NSColor.secondaryLabelColor.setFill(); NSBezierPath(ovalIn: NSRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)).fill()
            if index == current { NSColor.labelColor.setFill(); NSBezierPath(rect: NSRect(x: point.x - 6, y: point.y + 5, width: 12, height: 6)).fill() }
            if index == trial { NSColor.systemBlue.setStroke(); let ghost = NSBezierPath(rect: NSRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)); ghost.lineWidth = 2; ghost.stroke() }
        }
    }
}

@MainActor public final class CautionControl: NSButton {
    public private(set) var cautionState = CautionState()
    private let lens = CALayer()
    private var deadlineTimer: Timer?
    private var elapsed: () -> Double
    private var reduced = false, chinese = false
    public var onOpenAlerts: (() -> Void)?
    public init(elapsed: @escaping () -> Double) {
        self.elapsed = elapsed
        super.init(frame: .zero); title = "ALERT"; bezelStyle = .regularSquare; wantsLayer = true
        lens.cornerRadius = 4; layer?.addSublayer(lens)
        target = self; action = #selector(acknowledge); setAccessibilityIdentifier("calibration.caution")
        render()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    public override func layout() { super.layout(); lens.frame = bounds.insetBy(dx: 3, dy: 3) }
    public func update(_ conditions: [CautionCondition], profile: RenderProfile) {
        reduced = profile.reduceMotion; chinese = profile.locale.hasPrefix("zh")
        let before = cautionState; cautionState.update(conditions, now: elapsed(), reduceMotion: reduced)
        render(); if before != cautionState { NSAccessibility.post(element: self, notification: .valueChanged) }
    }
    public func validate() { cautionState.validate(now: elapsed(), reduceMotion: reduced); render() }
    @objc public func acknowledge() {
        let before = cautionState; cautionState.press(); render(); onOpenAlerts?()
        if before != cautionState { NSAccessibility.post(element: self, notification: .valueChanged) }
    }
    public func suspend() { deadlineTimer?.invalidate(); deadlineTimer = nil; lens.removeAllAnimations() }
    public func dispose() { suspend(); onOpenAlerts = nil }
    public var animationDuration: Double? { lens.animation(forKey: "caution")?.duration }
    private func render() {
        deadlineTimer?.invalidate(); deadlineTimer = nil
        CATransaction.begin(); CATransaction.setDisableActions(true)
        lens.removeAllAnimations(); lens.opacity = 1
        lens.backgroundColor = (cautionState.mode == .off ? NSColor.tertiaryLabelColor : cautionState.severity == .red ? .systemRed : .systemOrange).withAlphaComponent(0.35).cgColor
        CATransaction.commit()
        setAccessibilityLabel(chinese ? "警报" : "Alert")
        let modeDescription: String
        switch cautionState.mode {
        case .off: modeDescription = chinese ? "无警报" : "No active caution"
        case .blinking: modeDescription = chinese ? "未确认，闪烁" : "unacknowledged, blinking"
        case .steadyUnacknowledged: modeDescription = chinese ? "未确认，常亮" : "unacknowledged, steady"
        case .acknowledged: modeDescription = chinese ? "已确认" : "acknowledged"
        }
        setAccessibilityValueDescription(cautionState.mode == .off ? modeDescription : "\(cautionState.severity == .red ? (chinese ? "严重" : "red") : (chinese ? "注意" : "amber")); \(modeDescription)")
        setAccessibilityHelp(chinese ? "打开警报并确认当前条件。" : "Open alerts and acknowledge current conditions.")
        if cautionState.mode == .blinking, let deadline = cautionState.deadline {
            let remaining = max(0, deadline - elapsed())
            BoundedOpacity.apply(to: lens, remaining: remaining, phase: max(0, elapsed() - (cautionState.blinkStart ?? elapsed())), key: "caution")
            let timer = Timer(timeInterval: remaining, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.validate() } }
            RunLoop.main.add(timer, forMode: .common); deadlineTimer = timer
        }
    }
}

@MainActor public final class CalibrationRow: NSView {
    public let pool = EffectResourcePool()
    public let fader = EffortControl(id: "calibration.model", efforts: ["low", "medium", "high", "xhigh", "max", "custom"], current: 1, recommended: 3)
    public let caution: CautionControl
    public let help = NSButton(title: "?", target: nil, action: nil)
    public let cursor = CALayer()
    public private(set) var profile = RenderProfile()
    public private(set) var workingIDs: Set<String> = []
    public private(set) var selectedSubscriptionID: String?
    public var onSelectSubscription: ((String) -> Void)?
    private var effects: [String: SteppedEffect] = [:], nozzles: [String: NSButton] = [:]
    private let heading = NSTextField(labelWithString: "Neutral primitive calibration")
    private let chart = NSTextField(wrappingLabelWithString: "")
    private let bars = CalibrationChart()
    private var tooltip: NSPopover?
    private let elapsed: () -> Double
    private var typingDeadline: Double?
    public var followSystemAppearance = false
    public var onAppearanceChange: (() -> Void)?
    public init(elapsed: @escaping () -> Double) {
        self.elapsed = elapsed
        caution = CautionControl(elapsed: elapsed)
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 330)); wantsLayer = true
        heading.font = .systemFont(ofSize: 16, weight: .semibold); addSubview(heading)
        for index in 0..<6 {
            let id = "synthetic-sub-\(index)"
            let button = NSButton(title: "S\(index + 1)", target: nil, action: nil); button.wantsLayer = true
            button.target = self; button.action = #selector(selectNozzle(_:))
            button.setAccessibilityIdentifier(id); button.setAccessibilityHelp("Synthetic subscription; no account action")
            let effect = SteppedEffect(pool: pool); button.layer?.addSublayer(effect.layer)
            effects[id] = effect; nozzles[id] = button; addSubview(button)
        }
        addSubview(fader); addSubview(caution); addSubview(help); addSubview(chart); addSubview(bars)
        help.target = self; help.action = #selector(showHelp); help.setAccessibilityIdentifier("calibration.help")
        cursor.backgroundColor = NSColor.labelColor.cgColor; cursor.opacity = 0; layer?.addSublayer(cursor)
        configure(profile: profile, workingIDs: [])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    public override func layout() {
        super.layout(); heading.frame = NSRect(x: 20, y: 285, width: 760, height: 25)
        for (index, id) in nozzles.keys.sorted().enumerated() {
            nozzles[id]?.frame = NSRect(x: 20 + index * 122, y: 170, width: 108, height: 94)
            effects[id]?.layer.frame.origin = CGPoint(x: 28, y: 5)
        }
        fader.frame = NSRect(x: 20, y: 88, width: 590, height: 65)
        caution.frame = NSRect(x: 632, y: 103, width: 110, height: 36); help.frame = NSRect(x: 751, y: 104, width: 28, height: 32)
        chart.frame = NSRect(x: 20, y: 20, width: 520, height: 55); bars.frame = NSRect(x: 560, y: 15, width: 180, height: 62)
        cursor.frame = CGRect(x: 765, y: 40, width: 2, height: 16)
    }
    public func configure(profile: RenderProfile, workingIDs: Set<String>) {
        for effect in effects.values { effect.stop() }; pool.purgeUnleased()
        self.profile = profile; self.workingIDs = workingIDs.intersection(Set(nozzles.keys))
        cursor.backgroundColor = (profile.dark ? NSColor.white : .black).cgColor
        appearance = followSystemAppearance ? nil : NSAppearance(named: profile.dark ? .darkAqua : .aqua)
        let zh = profile.locale.hasPrefix("zh")
        heading.stringValue = zh ? "中性原生校准：额度 / Token / ★" : "Neutral calibration: quota / Token / ★"
        chart.stringValue = zh ? "可访问图表替代：09:00 未知；10:00 0；11:00 12。\n试选不会修改当前档位。" : "Chart data alternative: 09:00 unknown; 10:00 zero; 11:00 twelve.\nTrying an effort does not change the current effort."
        chart.setAccessibilityIdentifier("calibration.chart-data"); chart.setAccessibilityLabel(chart.stringValue)
        bars.setAccessibilityLabel(zh ? "历史柱图；后续文字提供完整数据，未知不等于零。" : "History bars; the text alternative provides all values. Unknown is not zero.")
        help.toolTip = zh ? "键盘与辅助功能帮助" : "Keyboard and accessibility help"; help.setAccessibilityHelp(help.toolTip)
        fader.localize(chinese: zh)
        for (id, effect) in effects {
            effect.configure(profile: profile, working: self.workingIDs.contains(id), color: profile.dark ? .systemTeal : NSColor(srgbRed: 0, green: 0.4, blue: 0.6, alpha: 1))
            nozzles[id]?.setAccessibilityLabel("\(id); \(self.workingIDs.contains(id) ? (zh ? "工作中" : "working") : (zh ? "空闲" : "idle"))")
        }
        needsLayout = true
    }
    public var animatingCount: Int { effects.values.filter(\.isAnimating).count }
    public var minimumPoseCount: Int { effects.values.filter(\.isAnimating).map(\.discretePoseCount).min() ?? 0 }
    public func startTyping(seconds: Double) {
        typingDeadline = elapsed() + seconds
        if profile.reduceMotion { cursor.removeAllAnimations(); cursor.opacity = 1; return }
        cursor.opacity = 1; BoundedOpacity.apply(to: cursor, remaining: seconds, key: "typing")
    }
    public func finishTyping() { cursor.removeAllAnimations(); cursor.opacity = 0; typingDeadline = nil }
    public func setVisible(_ visible: Bool) {
        if !visible {
            effects.values.forEach { $0.stop() }; pool.purgeUnleased(); caution.suspend(); cursor.removeAllAnimations(); tooltip?.close()
        } else {
            configure(profile: profile, workingIDs: workingIDs); caution.validate()
            if let end = typingDeadline { if end > elapsed() { startTyping(seconds: end - elapsed()) } else { finishTyping() } }
        }
    }
    public override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); onAppearanceChange?() }
    public func freezeForCapture() { effects.values.forEach { $0.seekForCapture(0.333) }; cursor.removeAllAnimations() }
    public func dispose() { effects.values.forEach { $0.stop() }; pool.purgeUnleased(); caution.dispose(); finishTyping(); tooltip?.close() }
    @objc private func selectNozzle(_ sender: NSButton) {
        guard let id = nozzles.first(where: { $0.value === sender })?.key else { return }
        selectedSubscriptionID = id; onSelectSubscription?(id)
    }
    @objc private func showHelp() {
        let content = NSViewController(); let label = NSTextField(wrappingLabelWithString: help.toolTip ?? "")
        label.frame = NSRect(x: 12, y: 12, width: 245, height: 45); content.view = NSView(frame: NSRect(x: 0, y: 0, width: 270, height: 70)); content.view.addSubview(label)
        let popover = NSPopover(); popover.contentViewController = content; popover.behavior = .transient
        popover.show(relativeTo: help.bounds, of: help, preferredEdge: .maxY); tooltip = popover
    }
}

@MainActor private final class CalibrationChart: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true; setAccessibilityElement(true)
        setAccessibilityRole(.image); setAccessibilityIdentifier("calibration.chart")
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override func draw(_ dirtyRect: NSRect) {
        let values: [CGFloat?] = [nil, 0, 12]
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * 58 + 10
            NSColor.labelColor.setFill()
            if let value { NSBezierPath(rect: NSRect(x: x, y: 18, width: 28, height: max(1, value * 3))).fill() }
            else { ("--" as NSString).draw(at: NSPoint(x: x + 5, y: 18), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]) }
            ("\(index + 9):00" as NSString).draw(at: NSPoint(x: x - 1, y: 0), withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.labelColor])
        }
    }
}
