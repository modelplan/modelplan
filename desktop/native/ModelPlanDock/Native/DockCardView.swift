// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit

@MainActor private final class DockCardButton:NSButton {
    var invoke:(()->Void)?
    init(_ title:String,_ invoke:@escaping ()->Void){super.init(frame:.zero);self.title=title;self.invoke=invoke;bezelStyle = .rounded;target=self;action=#selector(pressed)}
    required init?(coder:NSCoder){fatalError()}
    @objc private func pressed(){invoke?()}
    func retire(){invoke=nil;isEnabled=false;target=nil;action=nil}
}
/// Neutral complete card; official geometry/material/font/brand image is an injected appearance input.
@MainActor public struct DockCardStyle {
    public var width:CGFloat=300,padding:CGFloat=12,fontSize:CGFloat=12,brandSize:CGFloat=16
    public var background:NSColor = .windowBackgroundColor,ink:NSColor = .labelColor,track:NSColor = .separatorColor
    public var quota:[DockQuotaStatus:NSColor]=[.normal:.controlAccentColor,.warning:.systemOrange,.critical:.systemRed,.unknown:.secondaryLabelColor]
    public init(){}
}
@MainActor private final class DockCardBar:NSView {
    var fraction:Double?,on:NSColor,track:NSColor
    init(row:DockCardRow,on:NSColor,track:NSColor){self.fraction=row.remainingFraction;self.on=on;self.track=track;super.init(frame:CGRect(x:0,y:0,width:96,height:10));setAccessibilityElement(true);setAccessibilityRole(.levelIndicator);setAccessibilityValue(row.remainingFraction.map{NSNumber(value:$0*100)});setAccessibilityMinValue(0);setAccessibilityMaxValue(100);setAccessibilityLabel(row.label);setAccessibilityHelp([row.value,row.detail].filter{!$0.isEmpty}.joined(separator:" · "));setAccessibilityIdentifier("dock.card.quota."+row.id)}
    required init?(coder:NSCoder){fatalError()}
    override var intrinsicContentSize:NSSize{NSSize(width:96,height:10)}
    func apply(row:DockCardRow,on:NSColor,track:NSColor){
        let changed=fraction != row.remainingFraction
        fraction=row.remainingFraction;self.on=on;self.track=track
        setAccessibilityLabel(row.label);setAccessibilityValue(fraction.map{NSNumber(value:$0*100)})
        setAccessibilityHelp([row.value,row.detail].filter{!$0.isEmpty}.joined(separator:" · "));needsDisplay=true
        if changed{NSAccessibility.post(element:self,notification:.valueChanged)}
    }
    override func draw(_ dirtyRect:NSRect){
        let gap:CGFloat=2,w=max(0,(bounds.width-9*gap)/10)
        for i in 0..<10{let r=CGRect(x:CGFloat(i)*(w+gap),y:0,width:w,height:bounds.height);track.setFill();r.fill()
            if let fraction{let fill=max(0,min(1,fraction*10-Double(i)));on.setFill();CGRect(x:r.minX,y:0,width:w*fill,height:r.height).fill()}}
    }
}
@MainActor public final class DockCardView:NSView {
    public var onEnter:((String,UInt64)->Void)?,onDismiss:(()->Void)?,onOpenURL:((URL)->Void)?
    public var permitsAction:((String,UInt64)->Bool)?
    private let stack=NSStackView();private var edges=[NSLayoutConstraint]()
    private var content:DockCardContent?,generation:UInt64=0,style=DockCardStyle()
    private var labels=[String:NSTextField](),buttons=[String:DockCardButton]()
    private var groups=[String:NSStackView](),bars=[String:DockCardBar]()
    public override init(frame:NSRect){
        super.init(frame:frame);stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=8
        stack.translatesAutoresizingMaskIntoConstraints=false;addSubview(stack)
        edges=[stack.leadingAnchor.constraint(equalTo:leadingAnchor,constant:12),stack.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-12),stack.topAnchor.constraint(equalTo:topAnchor,constant:12),stack.bottomAnchor.constraint(equalTo:bottomAnchor,constant:-12)]
        NSLayoutConstraint.activate(edges)
    }
    required init?(coder:NSCoder){fatalError()}
    public override var isFlipped:Bool{true}
    private func arrange(_ parent:NSStackView,_ children:[NSView]){
        let kept=Set(children.map{ObjectIdentifier($0)})
        for old in parent.arrangedSubviews where !kept.contains(ObjectIdentifier(old)){
            parent.removeArrangedSubview(old);old.removeFromSuperview()
        }
        for (index,child) in children.enumerated(){
            if let current=parent.arrangedSubviews.firstIndex(where:{$0 === child}){
                if current != index{parent.removeArrangedSubview(child);parent.insertArrangedSubview(child,at:index)}
            }else{parent.insertArrangedSubview(child,at:index)}
        }
    }
    public func apply(_ value:DockCardContent,pinned:Bool,style:DockCardStyle? = nil,brandImage:NSImage?=nil)throws{
        let replacing=content?.subscriptionID != value.subscriptionID
        generation &+= 1;content=nil
        if replacing{clear()}
        let style=style ?? DockCardStyle()
        do{
            try value.validate()
            guard style.width.isFinite,(160...800).contains(style.width),style.fontSize.isFinite,(8...24).contains(style.fontSize),
                  style.padding.isFinite,(0...32).contains(style.padding),style.brandSize.isFinite,(8...48).contains(style.brandSize) else{throw DockArtworkError.invalidManifest}
        }catch{clear();throw error}
        self.style=style;content=value;let token=generation
        for (i,c) in edges.enumerated(){c.constant=(i==1 || i==3) ? -style.padding:style.padding}
        var usedLabels=Set<String>(),usedGroups=Set<String>(),usedButtons=Set<String>(),usedBars=Set<String>()
        func label(_ id:String,_ text:String)->NSTextField{
            usedLabels.insert(id);let l=labels[id] ?? NSTextField(wrappingLabelWithString:"");labels[id]=l
            l.stringValue=text;l.font = .systemFont(ofSize:style.fontSize);l.textColor=style.ink;l.toolTip=nil
            l.setAccessibilityLabel(text);l.setAccessibilityIdentifier("dock.card.text."+id);return l
        }
        func group(_ id:String)->NSStackView{
            usedGroups.insert(id);let g=groups[id] ?? NSStackView();groups[id]=g
            g.orientation = .horizontal;g.spacing=8;return g
        }
        func button(_ id:String,_ title:String,_ invoke:@escaping ()->Void)->DockCardButton{
            usedButtons.insert(id);let b=buttons[id] ?? DockCardButton(title,invoke);buttons[id]=b
            b.title=title;b.invoke=invoke;b.setAccessibilityIdentifier("dock.card."+id);return b
        }
        let head=group("head");var heading=[NSView]()
        if let brandImage{
            let original=brandImage.copy() as! NSImage;original.isTemplate=false
            let image=NSImageView(image:original);image.contentTintColor=nil;image.imageScaling = .scaleProportionallyDown
            image.setAccessibilityElement(false);image.widthAnchor.constraint(equalToConstant:style.brandSize).isActive=true
            image.heightAnchor.constraint(equalToConstant:style.brandSize).isActive=true;heading.append(image)
        }
        heading.append(label("name",[value.name,value.plan].filter{!$0.isEmpty}.joined(separator:" · ")));arrange(head,heading)
        var children:[NSView]=[head]
        for (id,text) in [("source",value.sourceAndAge),("state",value.stateLabel)] where !text.isEmpty{children.append(label(id,text))}
        for row in value.rows{
            let l=label("row."+row.id+".label",row.label);if row.kind == .extraQuota{l.toolTip=row.label}
            let h=group("row."+row.id);var fields:[NSView]=[l]
            if row.kind == .quota || row.kind == .extraQuota{
                usedBars.insert(row.id)
                let bar=bars[row.id] ?? DockCardBar(row:row,on:style.quota[row.tone] ?? style.ink,track:style.track)
                bars[row.id]=bar;bar.apply(row:row,on:style.quota[row.tone] ?? style.ink,track:style.track);fields.append(bar)
            }
            fields.append(label("row."+row.id+".value",row.value));arrange(h,fields)
            h.setAccessibilityLabel([row.label,row.value,row.detail].filter{!$0.isEmpty}.joined(separator:" · "));children.append(h)
            if !row.detail.isEmpty{children.append(label("row."+row.id+".detail",row.detail))}
        }
        var occurrences=[URL:Int]()
        for link in value.links{
            let index=occurrences[link.url,default:0];occurrences[link.url]=index+1
            let digest=SHA256.hash(data:Data(link.url.absoluteString.utf8)).map{String(format:"%02x",$0)}.joined()
            children.append(button("link."+digest+".\(index)",link.label){[weak self] in
                guard let self,self.current(value,token:token) else{return};self.onOpenURL?(link.url)
            })
        }
        if pinned{
            let enter=button("enter",value.enterLabel){[weak self] in guard let self,self.current(value,token:token) else{return};self.onEnter?(value.subscriptionID,value.revision)}
            let close=button("close",value.dismissLabel){[weak self] in guard let self,self.current(value,token:token) else{return};self.onDismiss?()}
            let footer=group("footer");arrange(footer,[enter,close]);children.append(footer)
        }
        arrange(stack,children)
        for id in Array(buttons.keys) where !usedButtons.contains(id){buttons.removeValue(forKey:id)?.retire()}
        for id in Array(bars.keys) where !usedBars.contains(id){bars.removeValue(forKey:id)?.setAccessibilityElement(false)}
        labels=labels.filter{usedLabels.contains($0.key)};groups=groups.filter{usedGroups.contains($0.key)}
        frame.size=CGSize(width:style.width,height:max(40,stack.fittingSize.height+2*style.padding))
        setAccessibilityElement(false);needsDisplay=true
    }
    private func current(_ value:DockCardContent,token:UInt64)->Bool{
        guard !isHiddenOrHasHiddenAncestor,generation==token,content==value,permitsAction?(value.subscriptionID,value.revision) ?? true else{return false}
        return generation==token && content==value
    }
    private func clear(){
        content=nil;buttons.values.forEach{$0.retire()};bars.values.forEach{$0.setAccessibilityElement(false)}
        arrange(stack,[]);buttons.removeAll();bars.removeAll();labels.removeAll();groups.removeAll()
    }
    public override func draw(_ dirtyRect:NSRect){style.background.setFill();bounds.fill()}
    public func dispose(){generation &+= 1;clear();onEnter=nil;onDismiss=nil;onOpenURL=nil;permitsAction=nil}
}
