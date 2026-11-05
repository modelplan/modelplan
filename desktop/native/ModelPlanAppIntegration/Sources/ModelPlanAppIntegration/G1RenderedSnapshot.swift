// SPDX-License-Identifier: MIT
#if DEBUG
import AppKit
import QuartzCore
@_spi(DockResourceChecks) import ModelPlanDock

/// All frames are local to the parent, in points. `visible` means onscreen;
/// `mounted` and `evidence` attributes distinguish offscreen draws from window acceptance.
/// Missing observations are explicit, never model-derived defaults or synthetic success receipts.
public struct G1RenderedColor: Equatable, Sendable {
    public let r:Double,g:Double,b:Double,a:Double
    public init(_ r:Double,_ g:Double,_ b:Double,_ a:Double=1){self.r=r;self.g=g;self.b=b;self.a=a}
    public var hex:String { "#"+[r,g,b,a].map{String(format:"%02X",Int((max(0,min(1,$0))*255).rounded()))}.joined() }
    static func color(_ ink:DockInk)->Self{.init(ink.r,ink.g,ink.b,ink.a)}
    static func color(_ color:NSColor?,in view:NSView)->Self? {
        var result:Self?
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            if let c=color?.usingColorSpace(.sRGB){result = .init(c.redComponent,c.greenComponent,c.blueComponent,c.alphaComponent)}
        };return result
    }
    public func contrast(against background:Self)->Double? {
        guard a == 1,background.a == 1 else{return nil}
        func luminance(_ c:Self)->Double { func channel(_ v:Double)->Double{v<=0.04045 ? v/12.92:pow((v+0.055)/1.055,2.4)};return 0.2126*channel(c.r)+0.7152*channel(c.g)+0.0722*channel(c.b) }
        let x=luminance(self),y=luminance(background);return (max(x,y)+0.05)/(min(x,y)+0.05)
    }
}
public struct G1RenderedInteraction: Sendable {
    public var hover:Bool?,press:Bool?,disabled:Bool?
    public init(hover:Bool?=nil,press:Bool?=nil,disabled:Bool?=nil){self.hover=hover;self.press=press;self.disabled=disabled}
}
public struct G1RenderedElement: Sendable {
    public var identifier:String,role:String
    public var frame:CGRect?,visible:Bool?,text:String?
    public var ink:G1RenderedColor?,fill:G1RenderedColor?,background:G1RenderedColor?,contrastAgainstParent:Double?
    public var assetSource:String?,layerRoles:[String]=[],zOrder:Double?
    public var interaction=G1RenderedInteraction(),filters:[String]=[],effects:[String]=[],animationPhase:String?
    public var attributes:[String:String]=[:],unavailable:[String:String]=[:],children:[Self]=[]
    public init(_ identifier:String,role:String){self.identifier=identifier;self.role=role}
    public func element(_ id:String)->Self?{if identifier==id{return self};for child in children{if let found=child.element(id){return found}};return nil}
}
public struct G1RenderedSnapshot: Sendable {
    public let schemaVersion=1
    public let root:G1RenderedElement
    public let deliveryRevision:UInt64?
    public func element(_ id:String)->G1RenderedElement?{root.element(id)}
}

@MainActor enum G1SnapshotReader {
    static func native(_ view:NSView,id:String,background:G1RenderedColor?=nil,order:Int=0,depth:Int=0)->G1RenderedElement {
        let identifier=view.accessibilityIdentifier() ?? id
        var node=G1RenderedElement(identifier,role:view.accessibilityRole()?.rawValue ?? String(reflecting:type(of:view)))
        node.frame=view.frame;node.visible = !view.isHiddenOrHasHiddenAncestor && view.window?.isVisible == true
        node.zOrder=Double(order);node.assetSource=(view as? NSImageView)?.image?.name()
        node.attributes=["renderer":String(reflecting:type(of:view)),"mounted":String(view.superview != nil),"evidence":"retained-native-view"]
        node.background=background
        if let layer=view.layer {
            node.fill=layer.backgroundColor.flatMap{G1RenderedColor.color(NSColor(cgColor:$0),in:view)}
            node.filters=(layer.filters ?? []).map{String(reflecting:type(of:$0))}
            node.effects=(layer.backgroundFilters ?? []).map{String(reflecting:type(of:$0))}
            if layer.shadowOpacity>0 {node.effects.append("shadow:opacity=\(layer.shadowOpacity),radius=\(layer.shadowRadius)")}
            let animations=layer.animationKeys() ?? []
            if !animations.isEmpty{node.animationPhase=animations.joined(separator:",");node.effects+=animations.map{"animation:"+$0}}
            node.attributes["opacity"]=String(layer.opacity);node.attributes["layerZPosition"]=String(Double(layer.zPosition))
        }
        if let effect=view as? NSVisualEffectView {node.effects.append("visual-effect:material=\(effect.material.rawValue),blend=\(effect.blendingMode.rawValue)");node.unavailable["background"]="Composited visual-effect backdrop is not a solid colour"}
        if let text=view as? NSTextField {
            node.text=text.stringValue;node.ink=G1RenderedColor.color(text.textColor,in:view)
            if text.drawsBackground{node.fill=G1RenderedColor.color(text.backgroundColor,in:view)}
            node.interaction.disabled = !text.isEnabled
        } else if let button=view as? NSButton {
            node.text=button.title;node.interaction.disabled = !button.isEnabled;node.interaction.press=button.isHighlighted
            if button.attributedTitle.length>0,let color=button.attributedTitle.attribute(.foregroundColor,at:0,effectiveRange:nil) as? NSColor {node.ink=G1RenderedColor.color(color,in:view)}
            node.attributes["controlState"]=String(button.state.rawValue)
        } else if let control=view as? NSControl {node.interaction.disabled = !control.isEnabled}
        node.contrastAgainstParent=node.ink.flatMap{ink in (node.fill ?? node.background).flatMap{ink.contrast(against:$0)}}
        if node.ink != nil && node.contrastAgainstParent == nil{node.unavailable["contrastAgainstParent"]="No observed opaque backdrop"}
        node.unavailable["hover"]="No native hover receipt supplied"
        if depth<32 { node.children=view.subviews.enumerated().map{native($0.element,id:identifier+"/\($0.offset)",background:node.fill ?? node.background,order:$0.offset,depth:depth+1)} }
        else {node.unavailable["children"]="Inspection depth limit"}
        return node
    }
    static func dock(_ host:StaticDockPreviewHost)->G1RenderedElement {
        let view=host.dockView
        var root=native(view,id:"dock");root.role="quota-widget";root.identifier="dock"
        let viewport=view.presentedSkinForChecks?.bounds ?? .zero
        func local(_ rect:CGRect)->CGRect {rect.offsetBy(dx:-viewport.minX,dy:-viewport.minY)}
        if let face=view.renderedFaceMaterialForChecks {
            var node=G1RenderedElement("dock.face",role:"material")
            node.frame=view.bounds;node.visible=root.visible;node.assetSource=face.materialSourceIdentity
            node.layerRoles=face.materialLayerRoles;node.zOrder=0
            node.attributes=["evidence":"completed-raster-pass","pixelWidth":String(Double(face.pixelSize.width)),"pixelHeight":String(Double(face.pixelSize.height))]
            node.unavailable["fill"]="Non-uniform supplied material; no invented solid colour"
            root.children.append(node)
        }
        for (index,layer) in view.renderedLayerRolesForChecks.enumerated() {
            var node=G1RenderedElement("dock.layer.\(index)",role:layer.role)
            node.assetSource=layer.resource;node.zOrder=Double(index);node.visible=root.visible
            if let id=layer.subscriptionID{node.attributes["subscriptionID"]=id}
            root.children.append(node)
        }
        for (index,resource) in view.renderedResourceFiltersForChecks.enumerated() {
            var node=G1RenderedElement("dock.resource.\(index)",role:"image")
            node.frame=local(resource.target);node.assetSource=resource.resource;node.visible=root.visible
            node.filters=["interpolation:\(resource.interpolationQuality.rawValue)"]
            node.attributes=["preservesSourcePixels":String(resource.preservesSourcePixels),"fitsVisibleGlyph":String(resource.fitsVisibleGlyph)]
            if let id=resource.subscriptionID{node.attributes["subscriptionID"]=id};root.children.append(node)
        }
        for id in view.renderedWidgetValuesForChecks.keys.sorted() {
            guard let value=view.renderedWidgetValuesForChecks[id],let layout=view.renderedReadoutBackingForChecks[id] else{continue}
            var node=G1RenderedElement("dock.readout."+id,role:"text")
            node.frame=local(layout.frame);node.text=value.text;node.ink = .color(value.ink);node.visible=root.visible
            node.attributes=["remainingPercent":value.remainingPercent.map{String($0)} ?? "unknown","quotaRole":value.quotaRole.rawValue,"colorRole":value.colorRole,"opacity":String(value.opacity),"evidence":"completed-text-pass"]
            node.unavailable["background"]="Text is drawn on the textured face, with no dedicated backing"
            root.children.append(node)
        }
        for (id,alias) in view.renderedAliasBackingForChecks.sorted(by:{$0.key<$1.key}) {
            var node=G1RenderedElement("dock.alias."+id,role:"text");node.frame=local(alias.frame);node.text=alias.text;node.ink = .color(alias.ink);node.visible=root.visible;root.children.append(node)
        }
        for (id,logo) in view.renderedLogosForChecks.sorted(by:{$0.key<$1.key}) {
            var node=G1RenderedElement("dock.logo."+id,role:"image");node.frame=local(logo.frame);node.assetSource=logo.resource;node.text=logo.fallbackText;node.ink=logo.tint.map(G1RenderedColor.color);node.visible=root.visible
            node.attributes=["colourTreatment":logo.colourTreatment.rawValue,"opacity":String(logo.opacity)];root.children.append(node)
        }
        if let geometry=host.resolvedT2CurvatureForChecks {
            root.attributes["geometrySourceIdentity"]=host.geometrySourceIdentityForChecks
            root.attributes["gap"]=String(Double(geometry.gap));root.attributes["radius"]=String(Double(geometry.radius))
        }
        return root
    }
}

extension EngineDockMenuApplication {
    /// Sole consumer entry for G1 presentation observations. Does not lay out, draw, show or query a service.
    public func renderedSnapshotForChecks()->G1RenderedSnapshot {
        var root=G1RenderedElement("app",role:"application")
        root.children=[G1SnapshotReader.dock(composition.dock)]
        var card=G1SnapshotReader.native(composition.dock.card,id:"card",background:nil);card.identifier="card";card.role="card"
        if let material=composition.dock.card.renderedMaterialForChecks{card.fill=G1RenderedColor.color(material.background,in:composition.dock.card);card.layerRoles=material.passRoles}
        root.children.append(card)
        for area in ["settings","cockpit"] {var node=G1RenderedElement(area,role:area);node.unavailable["surface"]="Surface has not been prepared";root.children.append(node)}
        return .init(root:root,deliveryRevision:composition.store.snapshot.delivery?.revision)
    }
}
#endif
