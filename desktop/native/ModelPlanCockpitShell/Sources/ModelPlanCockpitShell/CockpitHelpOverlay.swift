// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanPrimitives

/// Placement and localized copy come from M0's existing map/definition producers.
public struct CockpitHelpAnnotation: Sendable {
    public let id: String, text: String, label: CGRect, anchor: CGPoint, leaderEnd: CGPoint
    public init(id:String,text:String,label:CGRect,anchor:CGPoint,leaderEnd:CGPoint) {
        self.id = id;self.text = text;self.label = label;self.anchor = anchor;self.leaderEnd = leaderEnd
    }
}
@MainActor public protocol CockpitHelpSkin: AnyObject {
    func drawHelp(in context:CGContext,annotations:[CockpitHelpAnnotation],appearance:RenderProfile) throws
}
/// A pointer-transparent leaf. It has no modifier monitor, latch, hint budget, deadline or persistence.
@MainActor public final class CockpitHelpOverlay: NSView, CockpitPresentationConsumer {
    public override var isFlipped: Bool { true }
    public var onRenderingFailure: ((Error)->Void)?
    private let skin:any CockpitHelpSkin
    private var annotations:[CockpitHelpAnnotation] = []
    private var renderProfile = RenderProfile()
    private var requested = false, allowed = true
    public init(skin:any CockpitHelpSkin) { self.skin = skin;super.init(frame:.zero);isHidden = true;setAccessibilityElement(false) }
    public required init?(coder:NSCoder) { return nil }
    public func configure(visible:Bool,annotations:[CockpitHelpAnnotation],appearance:RenderProfile) throws {
        if !visible { requested = false;self.annotations = [];isHidden = true;return }
        guard (1...2).contains(appearance.scale),annotations.count<=64,Set(annotations.map(\.id)).count==annotations.count else { throw CockpitSurfaceError.invalidGeometry }
        for a in annotations {
            guard !a.id.isEmpty,a.id.utf8.count<=256,a.text.utf8.count<=4096,
                  [a.label.minX,a.label.minY,a.label.width,a.label.height,a.anchor.x,a.anchor.y,a.leaderEnd.x,a.leaderEnd.y].allSatisfy(\.isFinite),
                  a.label.width>0,a.label.height>0,a.label.width<=2048,a.label.height<=1024 else { throw CockpitSurfaceError.invalidGeometry }
        }
        self.annotations = annotations;self.renderProfile = appearance;requested = true;isHidden = !allowed || annotations.isEmpty;needsDisplay = true
    }
    public override func hitTest(_ point:NSPoint)->NSView? { nil }
    public func setPresentationAllowed(_ allowed:Bool) { self.allowed = allowed;isHidden = !allowed || !requested || annotations.isEmpty }
    public func stop() { requested = false;annotations = [];isHidden = true }
    public override func draw(_ dirtyRect:NSRect) {
        guard !isHidden,let context = NSGraphicsContext.current?.cgContext else { return }
        do { try skin.drawHelp(in:context,annotations:annotations,appearance:renderProfile) }
        catch { onRenderingFailure?(error) }
    }
}
@MainActor extension NeutralCockpitControlsSkin: CockpitHelpSkin {
    public func drawHelp(in context:CGContext,annotations:[CockpitHelpAnnotation],appearance:RenderProfile) {
        for a in annotations {
            context.setStrokeColor(NSColor.secondaryLabelColor.cgColor);context.setLineWidth(1)
            context.move(to:a.anchor);context.addLine(to:a.leaderEnd);context.strokePath()
            context.setFillColor(NSColor.windowBackgroundColor.cgColor);context.fill(a.label)
            NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current = NSGraphicsContext(cgContext:context,flipped:true)
            (a.text as NSString).draw(in:a.label.insetBy(dx:6,dy:4),withAttributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.labelColor])
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
