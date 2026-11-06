// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore
import ModelPlanDock

/// R64 D-9: the expanded widget fades in over 0.16 s (ease-out) and, on collapse, fades out over
/// 0.12 s (ease-in) while sliding 14 pt toward its attached edge. Reduce Motion keeps the fades and
/// drops the slide. Prototype: design-handoffs/opus-r7/src/rocket-r1/dock.css:25-29 (.dk-body /
/// .collapsed transitions, per-edge translate, body.reduced transform none).
enum DockRevealMotion {
    static let revealDuration: CFTimeInterval = 0.16
    static let collapseDuration: CFTimeInterval = 0.12
    static let slide: CGFloat = 14

    /// The offset toward the attached edge, in the coordinates of a layer whose geometry is
    /// flipped (y down) when `flipped` is true.
    static func towardEdge(_ edge: DockEdge, flipped: Bool) -> CGVector {
        switch edge {
        case .right: return CGVector(dx: slide, dy: 0)
        case .left: return CGVector(dx: -slide, dy: 0)
        case .bottom: return CGVector(dx: 0, dy: flipped ? slide : -slide)
        case .top: return CGVector(dx: 0, dy: flipped ? -slide : slide)
        }
    }

    static func animations(revealing: Bool, edge: DockEdge, flipped: Bool, reduceMotion: Bool) -> [String: CABasicAnimation] {
        let duration = revealing ? revealDuration : collapseDuration
        let timing = CAMediaTimingFunction(name: revealing ? .easeOut : .easeIn)
        func animation(_ keyPath: String, from: Any, to: Any) -> CABasicAnimation {
            let value = CABasicAnimation(keyPath: keyPath)
            value.fromValue = from; value.toValue = to; value.duration = duration; value.timingFunction = timing
            value.fillMode = .both; value.isRemovedOnCompletion = revealing
            return value
        }
        var result = ["dock.reveal.opacity": animation("opacity", from: revealing ? 0 : 1, to: revealing ? 1 : 0)]
        if !reduceMotion {
            let offset = towardEdge(edge, flipped: flipped)
            let start = revealing ? CATransform3DMakeTranslation(offset.dx, offset.dy, 0) : CATransform3DIdentity
            let end = revealing ? CATransform3DIdentity : CATransform3DMakeTranslation(offset.dx, offset.dy, 0)
            result["dock.reveal.slide"] = animation("transform", from: NSValue(caTransform3D: start), to: NSValue(caTransform3D: end))
        }
        return result
    }

    /// Reveal: animate the presented content's own layer back to its resting model values.
    @MainActor static func reveal(_ view: NSView, edge: DockEdge, reduceMotion: Bool) {
        view.wantsLayer = true
        guard let layer = view.layer else { return }
        for (key, animation) in animations(revealing: true, edge: edge, flipped: layer.isGeometryFlipped || view.isFlipped, reduceMotion: reduceMotion) {
            layer.add(animation, forKey: key)
        }
    }
}

/// A click-through, transparent panel that shows the last expanded image fading toward the
/// edge while the real panel already presents the sliver.
@MainActor final class DockCollapseGhost {
    private var panel: NSPanel?
    private var generation: UInt64 = 0
    private(set) var animatingForChecks = false

    func play(snapshotOf content: NSView, frame: CGRect, level: NSWindow.Level, edge: DockEdge, reduceMotion: Bool) {
        guard frame.width > 0, frame.height > 0, content.bounds.width > 0, content.bounds.height > 0,
              let rep = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { return }
        content.cacheDisplay(in: content.bounds, to: rep)
        let image = NSImage(size: content.bounds.size); image.addRepresentation(rep)
        let ghost = panel ?? {
            let value = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            value.isOpaque = false; value.backgroundColor = .clear; value.hasShadow = false
            value.ignoresMouseEvents = true; value.hidesOnDeactivate = false; value.isReleasedWhenClosed = false
            value.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
            return value
        }()
        panel = ghost
        let view = NSImageView(frame: CGRect(origin: .zero, size: frame.size))
        view.image = image; view.imageScaling = .scaleAxesIndependently; view.wantsLayer = true
        ghost.contentView = view
        ghost.level = level
        ghost.setFrame(frame, display: false)
        ghost.orderFrontRegardless()
        if let layer = view.layer {
            for (key, animation) in DockRevealMotion.animations(revealing: false, edge: edge, flipped: layer.isGeometryFlipped || view.isFlipped,
                                                                 reduceMotion: reduceMotion) {
                layer.add(animation, forKey: key)
            }
        }
        generation &+= 1
        let token = generation
        animatingForChecks = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(DockRevealMotion.collapseDuration * 1000) + 20))
            guard let self, self.generation == token else { return }
            self.stop()
        }
    }

    func stop() {
        generation &+= 1
        animatingForChecks = false
        panel?.contentView?.layer?.removeAllAnimations()
        panel?.orderOut(nil)
    }
}

/// R64 M-2: while the widget is carried away from an edge, a click-through hairline shows where it
/// will snap (the destination face outline). Hidden when the widget sits on that edge already.
/// Prototype: clients/official-visuals/dock-aftview-integration/face-view.js:23-25, face.css:136-137.
@MainActor final class DockSnapPreview {
    private final class OutlineView: NSView {
        var path: CGPath?, stroke: NSColor = .white, lineWidth: CGFloat = 1, flipped = true
        override var isFlipped: Bool { flipped }
        override func draw(_ dirtyRect: NSRect) {
            NSColor.clear.setFill(); bounds.fill(using: .copy)
            guard let path, let context = NSGraphicsContext.current?.cgContext else { return }
            context.addPath(path); context.setStrokeColor(stroke.cgColor); context.setLineWidth(lineWidth)
            context.setLineJoin(.round); context.strokePath()
        }
    }
    private var panel: NSPanel?
    private let outline = OutlineView(frame: .zero)
    private(set) var frameForChecks: CGRect?
    var strokeForChecks: NSColor { outline.stroke }

    func show(path: CGPath, flipped: Bool, frame: CGRect, stroke: NSColor, lineWidth: CGFloat, level: NSWindow.Level) {
        let preview = panel ?? {
            let value = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            value.isOpaque = false; value.backgroundColor = .clear; value.hasShadow = false
            value.ignoresMouseEvents = true; value.hidesOnDeactivate = false; value.isReleasedWhenClosed = false
            value.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
            return value
        }()
        panel = preview
        outline.path = path; outline.flipped = flipped; outline.stroke = stroke; outline.lineWidth = lineWidth
        outline.frame = CGRect(origin: .zero, size: frame.size); outline.needsDisplay = true
        if preview.contentView !== outline { preview.contentView = outline }
        preview.level = level
        preview.setFrame(frame, display: true)
        preview.orderFrontRegardless()
        frameForChecks = frame
    }

    func hide() {
        frameForChecks = nil
        panel?.orderOut(nil)
    }
}
