// SPDX-License-Identifier: MIT
import AppKit

@MainActor private final class DockCardButton:NSButton {
    var invoke:(()->Void)?
    init(_ title:String,_ invoke:@escaping ()->Void){super.init(frame:.zero);self.title=title;self.invoke=invoke;bezelStyle = .rounded;target=self;action=#selector(pressed)}
    required init?(coder:NSCoder){fatalError()}
    @objc private func pressed(){invoke?()}
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
    init(fraction:Double?,on:NSColor,track:NSColor){self.fraction=fraction;self.on=on;self.track=track;super.init(frame:CGRect(x:0,y:0,width:96,height:10));setAccessibilityElement(true);setAccessibilityRole(.levelIndicator);setAccessibilityValue(fraction.map{NSNumber(value:$0*100)});setAccessibilityLabel("Quota")}
    required init?(coder:NSCoder){fatalError()}
    override var intrinsicContentSize:NSSize{NSSize(width:96,height:10)}
    override func draw(_ dirtyRect:NSRect){
        let gap:CGFloat=2,w=max(0,(bounds.width-9*gap)/10)
        for i in 0..<10{let r=CGRect(x:CGFloat(i)*(w+gap),y:0,width:w,height:bounds.height);track.setFill();r.fill()
            if let fraction{let fill=max(0,min(1,fraction*10-Double(i)));on.setFill();CGRect(x:r.minX,y:0,width:w*fill,height:r.height).fill()}}
    }
}
@MainActor public final class DockCardView:NSView {
    public var onEnter:((String,UInt64)->Void)?,onDismiss:(()->Void)?,onOpenURL:((URL)->Void)?
    public var permitsAction:((String,UInt64)->Bool)?
    private let stack=NSStackView();private var edges=[NSLayoutConstraint]();private var content:DockCardContent?,generation:UInt64=0,style=DockCardStyle()
    public override init(frame:NSRect){super.init(frame:frame);stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=8;stack.translatesAutoresizingMaskIntoConstraints=false;addSubview(stack)
        edges=[stack.leadingAnchor.constraint(equalTo:leadingAnchor,constant:12),stack.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-12),stack.topAnchor.constraint(equalTo:topAnchor,constant:12),stack.bottomAnchor.constraint(equalTo:bottomAnchor,constant:-12)];NSLayoutConstraint.activate(edges)}
    required init?(coder:NSCoder){fatalError()}
    public override var isFlipped:Bool{true}
    public func apply(_ value:DockCardContent,pinned:Bool,style:DockCardStyle? = nil,brandImage:NSImage?=nil)throws{
        generation &+= 1;content=nil;for view in stack.arrangedSubviews{stack.removeArrangedSubview(view);view.removeFromSuperview()}
        let style=style ?? DockCardStyle()
        try value.validate();guard style.width.isFinite,(160...800).contains(style.width),style.fontSize.isFinite,(8...24).contains(style.fontSize),style.padding.isFinite,(0...32).contains(style.padding),style.brandSize.isFinite,(8...48).contains(style.brandSize) else{throw DockArtworkError.invalidManifest}
        self.style=style;content=value;let token=generation
        for (i,c) in edges.enumerated(){c.constant=(i==1 || i==3) ? -style.padding:style.padding}
        func label(_ text:String)->NSTextField{let l=NSTextField(wrappingLabelWithString:text);l.font = .systemFont(ofSize:style.fontSize);l.textColor=style.ink;l.toolTip=nil;l.setAccessibilityLabel(text);return l}
        let head=NSStackView();head.orientation = .horizontal;head.spacing=8
        if let brandImage{let image=NSImageView(image:brandImage);image.imageScaling = .scaleProportionallyDown;image.setAccessibilityElement(false);image.widthAnchor.constraint(equalToConstant:style.brandSize).isActive=true;image.heightAnchor.constraint(equalToConstant:style.brandSize).isActive=true;head.addArrangedSubview(image)}
        head.addArrangedSubview(label([value.name,value.plan].filter{!$0.isEmpty}.joined(separator:" · ")));stack.addArrangedSubview(head)
        for text in [value.sourceAndAge,value.stateLabel] where !text.isEmpty{stack.addArrangedSubview(label(text))}
        for row in value.rows{
            let l=label(row.label);if row.kind == .extraQuota{l.toolTip=row.label}
            let h=NSStackView(views:[l]);h.orientation = .horizontal;h.spacing=8
            if row.kind == .quota || row.kind == .extraQuota{h.addArrangedSubview(DockCardBar(fraction:row.remainingFraction,on:style.quota[row.tone] ?? style.ink,track:style.track))}
            h.addArrangedSubview(label(row.value));h.setAccessibilityLabel([row.label,row.value,row.detail].filter{!$0.isEmpty}.joined(separator:" · "));stack.addArrangedSubview(h)
            if !row.detail.isEmpty{stack.addArrangedSubview(label(row.detail))}
        }
        for link in value.links{
            let button=DockCardButton(link.label){[weak self] in guard let self,self.current(value,token:token) else{return};self.onOpenURL?(link.url)};stack.addArrangedSubview(button)
        }
        if pinned{
            let enter=DockCardButton(value.enterLabel){[weak self] in guard let self,self.current(value,token:token) else{return};self.onEnter?(value.subscriptionID,value.revision)}
            let close=DockCardButton(value.dismissLabel){[weak self] in guard let self,self.current(value,token:token) else{return};self.onDismiss?()}
            let footer=NSStackView(views:[enter,close]);footer.orientation = .horizontal;stack.addArrangedSubview(footer)
        }
        frame.size=CGSize(width:style.width,height:max(40,stack.fittingSize.height+2*style.padding));setAccessibilityElement(false);needsDisplay=true
    }
    private func current(_ value:DockCardContent,token:UInt64)->Bool{
        guard !isHiddenOrHasHiddenAncestor,generation==token,content==value,permitsAction?(value.subscriptionID,value.revision) ?? true else{return false}
        return generation==token && content==value
    }
    public override func draw(_ dirtyRect:NSRect){style.background.setFill();bounds.fill()}
    public func dispose(){generation &+= 1;content=nil;onEnter=nil;onDismiss=nil;onOpenURL=nil;permitsAction=nil;for v in stack.arrangedSubviews{stack.removeArrangedSubview(v);v.removeFromSuperview()}}
}
