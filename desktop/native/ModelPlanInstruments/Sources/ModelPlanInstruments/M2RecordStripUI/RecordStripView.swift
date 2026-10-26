// SPDX-License-Identifier: MIT
import AppKit

/// P03 projection consumer only. M0 injects this NSView into the shell and owns its clock/visibility/navigation.
@MainActor public final class RecordStripView: NSView {
    public override var isFlipped:Bool { true }
    public var onNavigate:((MainScreenContent,MainScreenSource)->Void)?
    public var onRenderingFailure:((Error)->Void)?
    public var onReturn:(()->Void)?
    public private(set) var input:RecordStripViewInput?, recipe:RecordStripRecipe?
    public private(set) var glyphMetrics:[EngineGlyphMetric] = []
    private let provider:any RecordStripRecipeProvider
    private var controls:[String:RecordStripControl] = [:]
    private var hovered:RecordStripHover?
    private var allowed = true
    private let cursorLayer = CALayer()
    public init(provider:(any RecordStripRecipeProvider)? = nil) {
        let selected = provider ?? NeutralRecordStripRecipe()
        self.provider = selected;super.init(frame:CGRect(origin:.zero,size:selected.preferredSize(for:.compact)))
        wantsLayer = true;layer?.addSublayer(cursorLayer);cursorLayer.isHidden = true
        setAccessibilityElement(false);setAccessibilityIdentifier("record.strip")
    }
    public required init?(coder:NSCoder) { return nil }
    public override var intrinsicContentSize:NSSize { recipe?.drawing.size ?? frame.size }
    public func configure(_ proposed:RecordStripViewInput) throws {
        let lines = proposed.presentation.lines,ids = Set(lines.map(\.id))
        guard (1...2).contains(proposed.appearance.scale),lines.count <= (proposed.density == .full ? 5:3),ids.count==lines.count,
              lines.allSatisfy({!$0.id.isEmpty && $0.id.utf8.count<=1024 && [$0.tool,$0.model,$0.effort ?? "",$0.projectName ?? "",$0.age ?? ""].allSatisfy{$0.utf8.count<=4096}}) else { throw EngineTableError.invalidRecipe }
        let identities = proposed.identities.filter { ids.contains($0.key) }
        guard identities.values.allSatisfy({[$0.fullToolName ?? "",$0.shortModelName ?? "",$0.fullModelName ?? ""].allSatisfy{$0.utf8.count<=4096} && $0.vendorInk?.valid != false}) else { throw EngineTableError.invalidRecipe }
        let selected = proposed.selectedID.flatMap { ids.contains($0) ? $0:nil }
        let candidate = RecordStripViewInput(presentation:proposed.presentation,density:proposed.density,appearance:proposed.appearance,
            identities:identities,selectedID:selected,overflowSelected:proposed.overflowSelected,cursor:proposed.cursor)
        let size = provider.preferredSize(for:proposed.density)
        let next = try provider.recipe(for:candidate,size:size,hover:admittedHover(hovered,ids:ids,hasMore:proposed.presentation.overflow>0))
        try next.validate()
        guard next.rows.compactMap(\.id)==lines.map(\.id),next.drawing.size==size,(next.more != nil) == (proposed.presentation.overflow > 0) else { throw EngineTableError.invalidRecipe }
        if let cursor = candidate.cursor {
            guard let row = next.rows.first(where:{$0.id==cursor.recordID}),!cursor.rect.isNull,!cursor.rect.isInfinite,
                  cursor.rect.width>0,cursor.rect.height>0,row.frame.contains(cursor.rect) else { throw EngineTableError.invalidRecipe }
        }
        // Resolve resources before publishing data or changing the accessible target tree.
        _ = try EngineRecipeDrawing.raster(next.drawing,provider:provider,scale:1)
        input = candidate;recipe = next;frame.size = size
        hovered = admittedHover(hovered,ids:ids,hasMore:proposed.presentation.overflow>0)
        synchronizeControls();updateCursor();needsDisplay = true;invalidateIntrinsicContentSize()
    }
    public func setPresentationAllowed(_ allowed:Bool) {
        self.allowed = allowed
        if !allowed { refreshHover(nil) }
        updateAdmission();updateCursor();needsDisplay = true
    }
    public func stop() {
        allowed = false;input = nil;recipe = nil;hovered = nil;glyphMetrics = []
        for control in controls.values { control.removeFromSuperview() };controls = [:]
        cursorLayer.removeAllAnimations();cursorLayer.isHidden = true
    }
    public func control(for recordID:String)->NSControl? { controls["row:"+recordID] }
    public var moreControl:NSControl? { controls["more"] }
    public func helpTargets()->[RecordStripHelpTarget] {
        guard let input,let recipe else { return [] }
        return recipe.rows.compactMap { row in
            guard let id = row.id,input.presentation.lines.first(where:{$0.id==id})?.working==true,let frame = row.fields[.speed] else { return nil }
            return RecordStripHelpTarget(id:"record.live."+id,anchor:frame,text:InstrumentHelpDefinitions.liveSpeed(input.appearance.language))
        }
    }
    public override func draw(_ dirtyRect:NSRect) {
        guard let recipe,let context = NSGraphicsContext.current?.cgContext else { return }
        do { glyphMetrics = try EngineRecipeDrawing.draw(recipe.drawing,in:context,provider:provider) }
        catch { onRenderingFailure?(error) }
    }
    public func rasterImage(scale:Int) throws -> CGImage {
        guard let recipe else { throw EngineTableError.invalidRecipe }
        let result = try EngineRecipeDrawing.raster(recipe.drawing,provider:provider,scale:scale)
        glyphMetrics = result.1;return result.0
    }
    public override func viewDidHide() { super.viewDidHide();refreshHover(nil);updateAdmission();updateCursor() }
    public override func viewDidUnhide() { super.viewDidUnhide();updateAdmission();updateCursor() }
    public override func keyDown(with event:NSEvent) { if allowed && event.keyCode==53 { onReturn?() } else { super.keyDown(with:event) } }
    fileprivate func activate(_ key:String)->Bool {
        guard allowed,!isHiddenOrHasHiddenAncestor,let input else { return false }
        if key=="more",let destination = input.presentation.moreDestination { onNavigate?(destination,.recordOverflow);return true }
        if key.hasPrefix("row:") {
            let id = String(key.dropFirst(4));guard input.presentation.lines.contains(where:{$0.id==id}) else { return false }
            onNavigate?(.session(id),.record(id));return true
        }
        return false
    }
    private func admittedHover(_ hover:RecordStripHover?,ids:Set<String>,hasMore:Bool)->RecordStripHover? {
        switch hover {
        case .row(let id): return ids.contains(id) ? .row(id):nil
        case .more: return hasMore ? .more:nil
        case nil: return nil
        }
    }
    fileprivate func hover(_ key:String?,entered:Bool) {
        guard allowed,let key else { return }
        let target:RecordStripHover = key == "more" ? .more:.row(String(key.dropFirst(4)))
        if entered { refreshHover(target) } else if hovered==target { refreshHover(nil) }
    }
    private func refreshHover(_ target:RecordStripHover?) {
        guard let input,let old = recipe else { hovered = nil;return }
        let admitted = admittedHover(target,ids:Set(input.presentation.lines.map(\.id)),hasMore:input.presentation.overflow>0)
        do {
            let next = try provider.recipe(for:input,size:old.drawing.size,hover:admitted);try next.validate()
            // Pointer state may change ink, never the navigation/tooltip target geometry.
            guard next.rows==old.rows,next.more==old.more,next.drawing.size==old.drawing.size else { throw EngineTableError.invalidRecipe }
            _ = try EngineRecipeDrawing.raster(next.drawing,provider:provider,scale:1)
            recipe = next;hovered = admitted;needsDisplay = true
        } catch { onRenderingFailure?(error) }
    }
    private func updateAdmission() {
        for control in controls.values { control.isEnabled = allowed && !isHiddenOrHasHiddenAncestor }
    }
    fileprivate var focusInk:CGColor { (recipe?.drawing.focusInk ?? .init(0.3,0.6,1)).cgColor }
    private func updateCursor() {
        CATransaction.begin();CATransaction.setDisableActions(true)
        cursorLayer.isHidden = true;cursorLayer.removeAllAnimations()
        if allowed,!isHiddenOrHasHiddenAncestor,let cursor = input?.cursor,cursor.visible,let ink = recipe?.cursorInk {
            cursorLayer.frame = cursor.rect;cursorLayer.backgroundColor = ink.cgColor;cursorLayer.isHidden = false
        }
        CATransaction.commit()
    }
    private func synchronizeControls() {
        guard let input,let recipe else { return }
        var next:[String:RecordStripControl] = [:]
        func control(_ key:String,_ rect:CGRect)->RecordStripControl {
            let control = controls[key] ?? RecordStripControl(key:key)
            control.owner = self;control.frame = rect;control.isEnabled = allowed && !isHiddenOrHasHiddenAncestor;next[key] = control
            if control.superview==nil { addSubview(control) };return control
        }
        for row in recipe.rows {
            guard let id = row.id,let line = input.presentation.lines.first(where:{$0.id==id}) else { continue }
            let identity = input.identities[id],text = RecordStripRowText(line:line,identity:identity,language:input.appearance.language)
            let button = control("row:"+id,row.frame)
            button.state = input.selectedID == id ? .on:.off
            button.setAccessibilityLabel(text.accessibility);button.setAccessibilityIdentifier("record.row."+id)
            button.setAccessibilityValueDescription(line.working ? InstrumentHelpDefinitions.liveSpeed(input.appearance.language):line.age)
            button.toolTip = nil
            for view in button.subviews { view.removeFromSuperview() }
            for (field,name) in [(RecordStripField.tool,identity?.fullToolName ?? line.tool),(.project,line.projectName)] {
                guard let name,!name.isEmpty,let box = row.fields[field] else { continue }
                let area = RecordNameArea(frame:box.offsetBy(dx:-row.frame.minX,dy:-row.frame.minY));area.owner = self;area.key = "row:"+id
                area.toolTip = name;area.setAccessibilityElement(false);button.addSubview(area)
            }
        }
        if input.presentation.overflow>0,let more = recipe.more {
            let button = control("more",more),count = input.presentation.overflow,zh = input.appearance.language == .chinese
            var label = zh ? "另外 \(count) 个会话，打开去向·时间":"\(count) more \(count==1 ? "session":"sessions"); open Breakdown · Time"
            if input.presentation.runningOverflow>0 { label += zh ? "；其中 \(input.presentation.runningOverflow) 个运行中":"; \(input.presentation.runningOverflow) working" }
            button.state = input.overflowSelected ? .on:.off
            button.setAccessibilityLabel(label);button.setAccessibilityIdentifier("record.more");button.toolTip = nil
        }
        for (key,control) in controls where next[key]==nil { control.removeFromSuperview() };controls = next
    }
}
@MainActor private final class RecordStripControl:NSButton {
    let key:String
    weak var owner:RecordStripView?
    private var area:NSTrackingArea?
    override var acceptsFirstResponder:Bool { true }
    init(key:String) { self.key = key;super.init(frame:.zero);title = "";isBordered = false;target = self;action = #selector(press);focusRingType = .exterior }
    required init?(coder:NSCoder) { return nil }
    override func draw(_ dirtyRect:NSRect) {
        guard window?.firstResponder === self,let context = NSGraphicsContext.current?.cgContext else { return }
        context.setStrokeColor(owner?.focusInk ?? NSColor.keyboardFocusIndicatorColor.cgColor)
        context.setLineWidth(1);context.stroke(bounds.insetBy(dx:1,dy:1))
    }
    override func becomeFirstResponder()->Bool { needsDisplay = true;return true }
    override func resignFirstResponder()->Bool { needsDisplay = true;return true }
    @objc private func press() { _ = owner?.activate(key) }
    override func accessibilityPerformPress()->Bool { owner?.activate(key) ?? false }
    override func updateTrackingAreas() {
        if let area { removeTrackingArea(area) };let next = NSTrackingArea(rect:.zero,options:[.mouseEnteredAndExited,.activeAlways,.inVisibleRect],owner:self,userInfo:nil);addTrackingArea(next);area = next;super.updateTrackingAreas()
    }
    override func mouseEntered(with event:NSEvent) { owner?.hover(key,entered:true) }
    override func mouseExited(with event:NSEvent) { owner?.hover(key,entered:false) }
    override func keyDown(with event:NSEvent) {
        if [36,49,76].contains(event.keyCode) { _ = owner?.activate(key) }
        else if event.keyCode==53 { owner?.keyDown(with:event) }
        else { super.keyDown(with:event) }
    }
}
@MainActor private final class RecordNameArea:NSView {
    weak var owner:RecordStripView?
    var key = ""
    override func draw(_ dirtyRect:NSRect) {}
    override func mouseDown(with event:NSEvent) { _ = owner?.activate(key) }
}
