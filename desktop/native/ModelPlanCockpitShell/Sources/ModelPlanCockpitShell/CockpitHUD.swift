// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanPrimitives

/// Numbers and eligibility/order are supplied by the shared published-model projection.
/// This component does not rank, choose a lineup, infer a session or calculate recommendations.
public struct CockpitHUDValue: Equatable, Sendable {
    public let ability: Double, cost: Double
    public init(ability: Double, cost: Double) { self.ability = ability; self.cost = cost }
    public var isValid: Bool { ability.isFinite && cost.isFinite && cost>0 }
}
public struct CockpitHUDModel: Equatable, Sendable {
    public let id: String, name: String, shortName: String, recommendedEffort: String
    public let reportedEffort: String?
    public let recommended: CockpitHUDValue?, current: CockpitHUDValue?
    public let dominated: Bool, older: Bool, currentIsRecommended: Bool
    public init(id: String, name: String, shortName: String, recommendedEffort: String,
                recommended: CockpitHUDValue?, current: CockpitHUDValue? = nil,
                dominated: Bool = false, older: Bool = false, currentIsRecommended: Bool = false, reportedEffort: String? = nil) {
        self.id = id; self.name = name; self.shortName = shortName; self.recommendedEffort = recommendedEffort
        self.recommended = recommended; self.current = current; self.dominated = dominated; self.older = older
        self.currentIsRecommended = currentIsRecommended; self.reportedEffort = reportedEffort
    }
}
public struct CockpitHUDState {
    public let profile: CockpitProfile, appearance: RenderProfile
    public let closed: Bool
    public let models: [CockpitHUDModel], frontierIDs: [String]
    public let selectedID: String?, hoveredID: String?
    public init(profile: CockpitProfile, appearance: RenderProfile, closed: Bool = false, models: [CockpitHUDModel], frontierIDs: [String] = [], selectedID: String? = nil, hoveredID: String? = nil) {
        self.profile = profile; self.appearance = appearance; self.closed = closed
        self.models = models; self.frontierIDs = frontierIDs; self.selectedID = selectedID; self.hoveredID = hoveredID
    }
}
public struct CockpitHUDLayout {
    public let frame: CGRect, chart: CGRect, rows: [CGRect]
    public init(frame: CGRect, chart: CGRect, rows: [CGRect]) { self.frame = frame; self.chart = chart; self.rows = rows }
}
public struct CockpitHUDPoint: Sendable {
    public let id: String, recommended: CGPoint, current: CGPoint?
}
public struct CockpitHUDChart: Sendable {
    public let points: [CockpitHUDPoint], frontier: [CGPoint]
    public let costBaseline: Double?
    /// Pure log-cost / linear-ability viewport geometry, not a score or selection algorithm.
    public static func project(_ models: [CockpitHUDModel], frontierIDs: [String], size: CGSize) -> Self {
        let valid = models.filter { $0.recommended?.isValid == true }
        guard size.width>=24,size.height>=24,size.width.isFinite,size.height.isFinite,
              let base = valid.compactMap({$0.recommended?.cost}).min() else { return Self(points:[],frontier:[],costBaseline:nil) }
        let values = valid.flatMap { [$0.recommended,$0.currentIsRecommended ? nil:$0.current].compactMap { $0 }.filter(\.isValid) }
        let lx0 = min(0,values.map { (log2($0.cost)-log2(base)) }.min() ?? 0)
        let lx1 = max(1,ceil(values.map { (log2($0.cost)-log2(base)) }.max() ?? 1))
        let a0 = floor(((values.map(\.ability).min() ?? 0)-4)/5)*5
        let a1 = ceil(((values.map(\.ability).max() ?? 0)+4)/5)*5
        guard [lx0,lx1,a0,a1,lx1-lx0,a1-a0].allSatisfy(\.isFinite),lx1>lx0,a1>a0 else { return Self(points:[],frontier:[],costBaseline:nil) }
        func point(_ v: CockpitHUDValue) -> CGPoint {
            CGPoint(x:8+((log2(v.cost)-log2(base))-lx0)/(lx1-lx0)*(size.width-17),y:6+(a1-v.ability)/(a1-a0)*(size.height-18))
        }
        let points = valid.map { CockpitHUDPoint(id:$0.id,recommended:point($0.recommended!),current:$0.currentIsRecommended ? nil:$0.current.flatMap { $0.isValid ? point($0):nil }) }
        let byID = Dictionary(points.map { ($0.id,$0.recommended) },uniquingKeysWith:{first,_ in first})
        return Self(points:points,frontier:frontierIDs.compactMap { byID[$0] },costBaseline:base)
    }
}
@MainActor public protocol CockpitHUDSkin: AnyObject {
    func layout(for state: CockpitHUDState) throws -> CockpitHUDLayout
    func drawHUD(in context: CGContext, state: CockpitHUDState, layout: CockpitHUDLayout, chart: CockpitHUDChart) throws
}
/// A leaf consumer. M0/M3 owns the sourced Tune view and return stack.
@MainActor public final class CockpitHUDView: NSView, CockpitPresentationConsumer {
    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }
    public var onRenderingFailure: ((Error) -> Void)?
    public var onOpenEffort: ((String?) -> Void)?
    public var onReturn: (() -> Void)?
    public var onHoverModel: ((String?) -> Void)?
    public private(set) var state: CockpitHUDState?
    public private(set) var hudLayout: CockpitHUDLayout?
    private let skin: any CockpitHUDSkin
    private var targets: [String:HUDTarget] = [:]
    private var hoveredID: String?
    private var presentationAllowed = true
    private var chart = CockpitHUDChart.project([],frontierIDs:[],size:.zero)
    public init(skin: any CockpitHUDSkin) {
        self.skin = skin; super.init(frame:.zero); setAccessibilityElement(true); setAccessibilityRole(.group); wantsLayer = true
    }
    public required init?(coder: NSCoder) { return nil }
    public func configure(_ state: CockpitHUDState) throws {
        if state.closed || state.models.isEmpty { stop(); return }
        guard (1...2).contains(state.appearance.scale), (state.selectedID?.utf8.count ?? 0)<=256, (state.hoveredID?.utf8.count ?? 0)<=256, state.models.count<=6,Set(state.models.map(\.id)).count==state.models.count,
              state.models.allSatisfy({!$0.id.isEmpty && $0.id.utf8.count<=256 && $0.name.utf8.count<=1024 && $0.shortName.utf8.count<=256 && $0.recommendedEffort.utf8.count<=128 && ($0.reportedEffort?.utf8.count ?? 0)<=128}),Set(state.frontierIDs).count==state.frontierIDs.count,
              Set(state.frontierIDs).isSubset(of:Set(state.models.map(\.id))) else { throw CockpitSurfaceError.invalidGeometry }

        let layout = try skin.layout(for:state), root = CGRect(origin:.zero,size:layout.frame.size)
        guard layout.frame.width>0,layout.frame.height>0,layout.frame.width<=1024,layout.frame.height<=512,
              [layout.frame.minX,layout.frame.minY,layout.frame.width,layout.frame.height].allSatisfy(\.isFinite),
              root.contains(layout.chart),layout.chart.width>=24,layout.chart.height>=24,
              layout.rows.count<=6,layout.rows.allSatisfy({!$0.isNull && !$0.isInfinite && root.contains($0) && $0.width>0 && $0.height>0}) else { throw CockpitSurfaceError.invalidGeometry }
        self.state = state; hudLayout = layout; isHidden = false; frame = layout.frame
        chart = .project(state.models,frontierIDs:state.frontierIDs,size:layout.chart.size)
        var nextTargets: [String:HUDTarget] = [:]
        func target(_ key:String,_ rect:CGRect) -> HUDTarget {
            let button = targets[key] ?? HUDTarget(frame:rect)
            button.frame = rect; nextTargets[key] = button
            if button.superview == nil { addSubview(button) }
            return button
        }
        let chinese = state.appearance.locale.hasPrefix("zh")
        for (index,rect) in layout.rows.enumerated() where state.models.indices.contains(index) {
            let model = state.models[index], button = target("row:"+state.models[index].id,rect)
            button.identifier = NSUserInterfaceItemIdentifier(model.id); button.title = ""; button.isBordered = false; button.focusRingType = .none
            button.target = self; button.action = #selector(choose(_:)); button.onHover = { [weak self] hot in self?.setHovered(model.id,hot:hot) }
            button.toolTip = model.name+(model.older ? (chinese ? " · 旧版":" · older"):"") // H11 full-name exception.
            button.setAccessibilityIdentifier("cockpit.hud.\(model.id)")
            button.setAccessibilityLabel(button.toolTip)
            let recommended = (chinese ? "推荐 ":"Recommended ")+model.recommendedEffort
            let actual = model.currentIsRecommended ? (chinese ? "；当前使用推荐配置":"; current configuration is recommended"):(model.reportedEffort.map { (chinese ? "；当前 ":"; Current ")+$0 } ?? "")
            button.setAccessibilityValueDescription(recommended+actual)
        }
        for point in chart.points {
            let p = CGPoint(x:layout.chart.minX+point.recommended.x,y:layout.chart.minY+point.recommended.y)
            let button = target("point:"+point.id,CGRect(x:p.x-5,y:p.y-5,width:10,height:10))
            button.identifier = NSUserInterfaceItemIdentifier(point.id); button.title = ""; button.isBordered = false; button.focusRingType = .none
            button.target = self; button.action = #selector(choose(_:)); button.toolTip = nil
            button.setAccessibilityLabel(state.models.first(where:{$0.id==point.id})?.name)
            button.setAccessibilityIdentifier("cockpit.hud.point.\(point.id)")
            if let model = state.models.first(where:{$0.id==point.id}), let value = model.recommended {
                let ratio = value.cost/(chart.costBaseline ?? value.cost)
                let factor = ratio.isFinite ? String(format:"%.2f",ratio):(chinese ? "不可用":"unavailable")
                button.setAccessibilityValueDescription(chinese ? "推荐 \(model.recommendedEffort)；能力 \(value.ability)；相对成本 ×\(factor)":"Recommended \(model.recommendedEffort); Ability \(value.ability); Relative cost ×\(factor)")
            }
            button.onHover = { [weak self] hot in self?.setHovered(point.id,hot:hot) }
            if let current = point.current {
                let aux = target("current:"+point.id,CGRect(x:layout.chart.minX+current.x-5,y:layout.chart.minY+current.y-5,width:10,height:10))
                aux.identifier = NSUserInterfaceItemIdentifier(point.id);aux.title = "";aux.isBordered = false;aux.focusRingType = .none
                aux.target = self;aux.action = #selector(choose(_:));aux.toolTip = nil;aux.keyboardEligible = false;aux.setAccessibilityElement(false)
                aux.onHover = { [weak self] hot in self?.setHovered(point.id,hot:hot) }
            }
        }
        for (key,button) in targets where nextTargets[key] == nil { button.removeFromSuperview() }
        targets = nextTargets
        if let hoveredID, !state.models.contains(where:{$0.id==hoveredID}) { setHovered(hoveredID,hot:false) }
        setAccessibilityLabel(chinese ? "打开档位，查看推荐前沿":"Open Effort to see the recommendation frontier")
        needsDisplay = true
    }
    public func setPresentationAllowed(_ allowed: Bool) {
        presentationAllowed = allowed
        if !allowed, hoveredID != nil { hoveredID = nil;onHoverModel?(nil);needsDisplay = true }
    }
    public func stop() {
        let hadState = state != nil || !targets.isEmpty || hoveredID != nil
        presentationAllowed = false
        state = nil; hudLayout = nil; hoveredID = nil; isHidden = true; frame.size = .zero
        for button in targets.values { button.removeFromSuperview() }; targets = [:]
        chart = .project([],frontierIDs:[],size:.zero); if hadState { onHoverModel?(nil) }
    }
    public override func draw(_ dirtyRect: NSRect) {
        guard let state, let layout = hudLayout, let context = NSGraphicsContext.current?.cgContext else { return }
        let painted = CockpitHUDState(profile:state.profile,appearance:state.appearance,closed:state.closed,models:state.models,
            frontierIDs:state.frontierIDs,selectedID:state.selectedID,hoveredID:hoveredID ?? state.hoveredID)
        do { try skin.drawHUD(in:context,state:painted,layout:layout,chart:chart) }
        catch { onRenderingFailure?(error) }
    }
    fileprivate var acceptsModelActions: Bool { presentationAllowed && state != nil && !isHidden }
    public override func accessibilityPerformPress() -> Bool {
        guard acceptsModelActions else { return false }; onOpenEffort?(state?.selectedID); return true
    }
    public override func mouseDown(with event: NSEvent) { _ = accessibilityPerformPress() }
    public override func keyDown(with event: NSEvent) {
        if event.keyCode==53 { onReturn?() }
        else if event.keyCode==36 || event.keyCode==49 { onOpenEffort?(state?.selectedID) }
        else { super.keyDown(with:event) }
    }
    public override func viewDidHide() { super.viewDidHide(); hoveredID = nil; onHoverModel?(nil) }
    private func setHovered(_ id:String,hot:Bool) {
        if hot { guard presentationAllowed, state?.models.contains(where:{$0.id==id}) == true, !isHidden else { return }; hoveredID = id } else if hoveredID == id { hoveredID = nil }
        needsDisplay = true; onHoverModel?(hoveredID)
    }
    @objc private func choose(_ sender: NSButton) { if let id = sender.identifier?.rawValue, presentationAllowed, !isHidden, state?.models.contains(where:{$0.id==id}) == true { onOpenEffort?(id) } }
}
@MainActor private final class HUDTarget: NSButton {
    var onHover: ((Bool) -> Void)?
    private var area: NSTrackingArea?
    var keyboardEligible = true
    override var acceptsFirstResponder: Bool { keyboardEligible }
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled, (superview as? CockpitHUDView)?.acceptsModelActions == true, !isHiddenOrHasHiddenAncestor, let action else { return false }
        _ = sendAction(action,to:target); return true
    }
    override func draw(_ dirtyRect: NSRect) {}
    override func becomeFirstResponder() -> Bool { let result = super.becomeFirstResponder(); if result { onHover?(true) }; return result }
    override func resignFirstResponder() -> Bool { let result = super.resignFirstResponder(); onHover?(false); return result }
    override func updateTrackingAreas() {
        if let area { removeTrackingArea(area) }
        let next = NSTrackingArea(rect:.zero,options:[.mouseEnteredAndExited,.activeAlways,.inVisibleRect],owner:self,userInfo:nil)
        addTrackingArea(next); area = next; super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
    override func keyDown(with event: NSEvent) { if event.keyCode==53 { nextResponder?.keyDown(with:event) } else { super.keyDown(with:event) } }
}
