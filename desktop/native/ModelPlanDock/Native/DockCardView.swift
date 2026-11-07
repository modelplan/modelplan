// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit

@MainActor private final class DockCardButton:NSButton {
    var invoke:(()->Void)?,focusChanged:(()->Void)?
    override func becomeFirstResponder()->Bool { let accepted=super.becomeFirstResponder();if accepted{focusChanged?()};return accepted }
    override func resignFirstResponder()->Bool { let accepted=super.resignFirstResponder();if accepted{focusChanged?()};return accepted }
    init(_ title:String,_ invoke:@escaping ()->Void){super.init(frame:.zero);self.title=title;self.invoke=invoke;bezelStyle = .rounded;target=self;action=#selector(pressed)}
    required init?(coder:NSCoder){fatalError()}
    @objc private func pressed(){invoke?()}
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled, !isHiddenOrHasHiddenAncestor, let invoke else { return false }
        invoke()
        return true
    }
    func retire(){invoke=nil;focusChanged=nil;isEnabled=false;target=nil;action=nil}
}
/// Neutral complete card; official geometry/material/font/brand image is an injected appearance input.
/// Layout follows the accepted r7 card (card.js / dock.css .c7): a plate with a header
/// (mark, name over plan, read time on the right), an inset readout window with fixed
/// four-column rows (label / ten-segment bar / percent / time) and wide rows (label / value / detail).
@MainActor public struct DockCardStyle {
    public var width:CGFloat=300,padding:CGFloat=12,fontSize:CGFloat=12,brandSize:CGFloat=16
    /// Plate padding above and below the content (horizontal padding is `padding`).
    public var verticalPadding:CGFloat=12
    /// The ten-segment quota bar: size and gap between segments.
    public var barSize=CGSize(width:96,height:10),barGap:CGFloat=2
    /// The footer's enter/close buttons. The production widget card has none (owner D37, 11-06):
    /// an unpinned card closes when the pointer leaves, a keyboard-held card closes with Esc,
    /// and Settings lives in the widget's right-click menu.
    public var showsActions=true
    public var background:NSColor = .windowBackgroundColor,ink:NSColor = .labelColor,track:NSColor = .separatorColor
    /// Secondary text: plan, read time, row labels and times.
    public var muted:NSColor = .secondaryLabelColor
    /// Plate corner radius and its 1 pt inset seam (nil: no seam).
    public var plateRadius:CGFloat=8,seam:NSColor?=nil
    /// The inset readout window behind the rows (nil: rows sit on the plate).
    public var window:NSColor?=nil,windowSeam:NSColor?=nil
    public var windowRadius:CGFloat=8,windowPadding=NSEdgeInsets(top:5,left:7,bottom:5,right:7)
    /// Header: name size (semibold), small text size, gap after the mark, gap below the header.
    public var nameFontSize:CGFloat=13,smallFontSize:CGFloat=11,headerGap:CGFloat=8,headerBottomGap:CGFloat=7
    /// Row grid: label, bar and percent columns are fixed; the time column takes the rest.
    public var columns:[CGFloat]=[56,96,34],columnGap:CGFloat=5,rowMinimumHeight:CGFloat=18,rowGap:CGFloat=2
    /// Readout fonts (the LCD face) for percent values and for labels/times; nil uses the system
    /// monospaced font at `readoutSize` / `smallFontSize`.
    public var readoutFont:NSFont?=nil,readoutSmallFont:NSFont?=nil,readoutSize:CGFloat=11.5
    public var quota:[DockQuotaStatus:NSColor]=[.normal:.controlAccentColor,.warning:.systemOrange,.critical:.systemRed,.unknown:.secondaryLabelColor]
    /// Announced-reset ink (the card's ↺ section title).
    public var notice:NSColor = .systemBlue
    public init(){}
}
@MainActor private final class DockCardBar:NSView {
    var fraction:Double?,on:NSColor,track:NSColor
    var size=CGSize(width:96,height:10){didSet{invalidateIntrinsicContentSize();needsDisplay=true}}
    var gap:CGFloat=2{didSet{needsDisplay=true}}
    init(row:DockCardRow,on:NSColor,track:NSColor){self.fraction=row.remainingFraction;self.on=on;self.track=track;super.init(frame:CGRect(x:0,y:0,width:96,height:10));setAccessibilityElement(true);setAccessibilityRole(.levelIndicator);setAccessibilityValue(row.remainingFraction.map{NSNumber(value:$0*100)});setAccessibilityMinValue(0);setAccessibilityMaxValue(100);setAccessibilityLabel(row.label);setAccessibilityHelp([row.value,row.detail].filter{!$0.isEmpty}.joined(separator:" · "));setAccessibilityIdentifier("dock.card.quota."+row.id)}
    required init?(coder:NSCoder){fatalError()}
    override var intrinsicContentSize:NSSize{size}
    func apply(row:DockCardRow,on:NSColor,track:NSColor){
        let changed=fraction != row.remainingFraction
        fraction=row.remainingFraction;self.on=on;self.track=track
        setAccessibilityLabel(row.label);setAccessibilityValue(fraction.map{NSNumber(value:$0*100)})
        setAccessibilityHelp([row.value,row.detail].filter{!$0.isEmpty}.joined(separator:" · "));needsDisplay=true
        if changed{NSAccessibility.post(element:self,notification:.valueChanged)}
    }
    /// card.js lit(): whole segments of what is left; one stays lit while anything is left.
    static func litSegments(_ fraction:Double?)->Int{
        guard let fraction,fraction.isFinite,fraction>0 else{return 0}
        return max(1,min(10,Int((fraction*10).rounded())))
    }
    override func draw(_ dirtyRect:NSRect){
        let w=max(0,(bounds.width-9*gap)/10),lit=Self.litSegments(fraction)
        for i in 0..<10{
            let r=CGRect(x:CGFloat(i)*(w+gap),y:0,width:w,height:bounds.height)
            (i<lit ? on:track).setFill();NSBezierPath(roundedRect:r,xRadius:1,yRadius:1).fill()
        }
    }
}
/// Rows lay out top-down like the card itself.
@MainActor private final class DockCardRowView:NSView { override var isFlipped:Bool{true} }
@MainActor public final class DockCardView:NSView {
    public var onEnter:((String,UInt64)->Void)?,onDismiss:(()->Void)?,onOpenURL:((URL)->Void)?
    public var permitsAction:((String,UInt64)->Bool)?
    public var onFocusChange:(()->Void)?
    private var content:DockCardContent?,generation:UInt64=0,style=DockCardStyle()
    private var labels=[String:NSTextField](),buttons=[String:DockCardButton]()
    private var bars=[String:DockCardBar](),rowViews=[String:NSView](),brandView:NSImageView?
    /// The readout window in card coordinates (flipped), drawn behind the rows.
    private var windowRect:CGRect?
    public override init(frame:NSRect){super.init(frame:frame)}
    required init?(coder:NSCoder){fatalError()}
    public override var isFlipped:Bool{true}
    /// Geometry read by checks: the readout window and a row's visible cells, in card coordinates.
    @_spi(DockResourceChecks) public var readoutWindowForChecks:CGRect?{windowRect}
    @_spi(DockResourceChecks) public func rowCellsForChecks(_ id:String)->[CGRect]{
        guard let row=rowViews["row."+id] else{return []}
        return row.subviews.filter{!$0.isHidden}.map{row.convert($0.frame,to:self)}.sorted{$0.minX<$1.minX}
    }
    @_spi(DockResourceChecks) public func rowFrameForChecks(_ id:String)->CGRect?{rowViews["row."+id]?.frame}
    private func place(_ child:NSView,in parent:NSView){if child.superview !== parent{child.removeFromSuperview();parent.addSubview(child)}}
    private func setWraps(_ field:NSTextField,_ wraps:Bool){
        field.cell?.wraps=wraps;field.cell?.isScrollable = !wraps;field.usesSingleLineMode = !wraps
        field.maximumNumberOfLines=wraps ? 0:1;field.lineBreakMode=wraps ? .byWordWrapping : .byTruncatingTail
    }
    public func apply(_ value:DockCardContent,style:DockCardStyle? = nil,brandImage:NSImage?=nil,enterDisabledReason:String?=nil)throws{
        let replacing=content?.subscriptionID != value.subscriptionID
        generation &+= 1;content=nil
        if replacing { clear() }
        let style=style ?? DockCardStyle()
        do{
            try value.validate()
            guard style.width.isFinite,(160...800).contains(style.width),style.fontSize.isFinite,(8...24).contains(style.fontSize),
                  style.padding.isFinite,(0...32).contains(style.padding),style.verticalPadding.isFinite,(0...32).contains(style.verticalPadding),
                  style.brandSize.isFinite,(8...48).contains(style.brandSize),style.columns.count==3,
                  style.columns.allSatisfy({$0.isFinite && $0>0}) else{throw DockArtworkError.invalidManifest}
        }catch{clear();throw error}
        self.style=style;content=value;let token=generation
        var usedLabels=Set<String>(),usedButtons=Set<String>(),usedBars=Set<String>(),usedRows=Set<String>()
        let small=NSFont.systemFont(ofSize:style.smallFontSize)
        let readout:NSFont=style.readoutFont ?? .monospacedSystemFont(ofSize:style.readoutSize,weight:.regular)
        let readoutSmall:NSFont=style.readoutSmallFont ?? .monospacedSystemFont(ofSize:style.smallFontSize,weight:.regular)
        func label(_ id:String,_ text:String,font:NSFont,color:NSColor,wraps:Bool=false,alignment:NSTextAlignment = .left)->NSTextField{
            usedLabels.insert(id)
            let l=labels[id] ?? NSTextField(labelWithString:"")
            labels[id]=l
            l.stringValue=text;l.font=font;l.textColor=color;l.alignment=alignment;l.toolTip=nil;setWraps(l,wraps)
            l.setAccessibilityLabel(text);l.setAccessibilityIdentifier("dock.card.text."+id);return l
        }
        func natural(_ field:NSTextField)->CGSize{field.cell?.cellSize(forBounds:CGRect(x:0,y:0,width:10_000,height:10_000)) ?? field.fittingSize}
        func wrapped(_ field:NSTextField,width:CGFloat)->CGFloat{
            field.preferredMaxLayoutWidth=width
            return ceil(field.cell?.cellSize(forBounds:CGRect(x:0,y:0,width:width,height:10_000)).height ?? field.fittingSize.height)
        }
        func height(_ field:NSTextField,width:CGFloat)->CGFloat{
            field.lineBreakMode == .byWordWrapping ? wrapped(field,width:width) : ceil(natural(field).height)
        }
        func button(_ id:String,_ title:String,_ invoke:@escaping ()->Void)->DockCardButton{
            usedButtons.insert(id);let b=buttons[id] ?? DockCardButton(title,invoke);buttons[id]=b
            b.title=title;b.invoke=invoke;b.focusChanged={ [weak self] in self?.onFocusChange?() };b.setAccessibilityIdentifier("dock.card."+id);return b
        }
        let inner=style.width-2*style.padding
        var y=style.verticalPadding
        // Header: [mark] [name over plan] … [read time over state] (card.js cd-h).
        var headerHeight:CGFloat=0,x=style.padding
        if let brandImage{
            let original=brandImage.copy() as! NSImage;original.isTemplate=false
            let image=brandView ?? NSImageView(image:original);brandView=image
            image.image=original;image.contentTintColor=nil;image.imageScaling = .scaleProportionallyDown
            image.setAccessibilityElement(false);place(image,in:self)
            image.frame=CGRect(x:x,y:y,width:style.brandSize,height:style.brandSize)
            x+=style.brandSize+style.headerGap;headerHeight=style.brandSize
        }else{brandView?.removeFromSuperview();brandView=nil}
        var rightWidth:CGFloat=0,rightHeight:CGFloat=0
        var right=[NSTextField]()
        for (id,text,size) in [("source",value.sourceAndAge,style.smallFontSize),("state",value.stateLabel,style.smallFontSize-1)] where !text.isEmpty{
            let field=label(id,text,font:.systemFont(ofSize:size),color:style.muted,alignment:.right);right.append(field)
            let s=natural(field);rightWidth=max(rightWidth,ceil(s.width));rightHeight+=ceil(s.height)
        }
        rightWidth=min(rightWidth,inner*0.5)
        let nameWidth=max(40,style.width-style.padding-x-(rightWidth>0 ? rightWidth+style.headerGap:0))
        let name=label("name",value.name,font:.systemFont(ofSize:style.nameFontSize,weight:.semibold),color:style.ink)
        name.setAccessibilityLabel([value.name,value.plan].filter{!$0.isEmpty}.joined(separator:" · "))
        place(name,in:self);let nameHeight=ceil(natural(name).height)
        name.frame=CGRect(x:x,y:y,width:nameWidth,height:nameHeight)
        var leftHeight=nameHeight
        if !value.plan.isEmpty{
            let plan=label("plan",value.plan,font:small,color:style.muted);place(plan,in:self)
            let h=ceil(natural(plan).height);plan.frame=CGRect(x:x,y:y+nameHeight,width:nameWidth,height:h);leftHeight+=h
        }
        var headerY=y
        for field in right{
            place(field,in:self);let h=ceil(natural(field).height)
            field.frame=CGRect(x:style.width-style.padding-rightWidth,y:headerY,width:rightWidth,height:h);headerY+=h
        }
        headerHeight=max(headerHeight,leftHeight,rightHeight)
        if let brandView{brandView.frame.origin.y=y+(headerHeight-style.brandSize)/2}
        y+=headerHeight+style.headerBottomGap
        // Readout window with the fixed row grid (dock.css .cd-lcd / .cd-r, face.css 56/78/34/1fr).
        let pad=style.window == nil ? NSEdgeInsets(top:0,left:0,bottom:0,right:0) : style.windowPadding
        let rowWidth=inner-pad.left-pad.right
        let windowTop=y
        var rowY=y+pad.top
        let c=style.columns,g=style.columnGap
        for (index,row) in value.rows.enumerated(){
            if index>0{rowY+=style.rowGap}
            let rowID="row."+row.id
            usedRows.insert(rowID)
            let rowView=rowViews[rowID] ?? DockCardRowView();rowViews[rowID]=rowView;place(rowView,in:self)
            rowView.setAccessibilityElement(true);rowView.setAccessibilityRole(.group)
            rowView.setAccessibilityLabel([row.label,row.value,row.detail].filter{!$0.isEmpty}.joined(separator:" · "))
            let l=label(rowID+".label",row.label,font:readoutSmall,color:style.muted);place(l,in:rowView)
            if row.kind == .extraQuota{l.setAccessibilityLabel(row.label)} // DOCK-3.6-18: no native tooltip
            let toneColor=style.quota[row.tone] ?? style.ink
            let valueColor:NSColor = row.tone == .warning || row.tone == .critical ? toneColor : (row.remainingFraction == nil && row.tone == .unknown ? style.muted : style.ink)
            var cells:[(view:NSView,x:CGFloat,width:CGFloat)]=[]
            var detailBelow:NSTextField?
            if row.kind == .notice{
                // Announced public reset (card.js cd-ev): the title line in reset ink across the
                // whole window, then its explanation, both wrapping; no grid columns.
                l.textColor=style.notice;l.font=readout;setWraps(l,true)
                var title=[(view:l as NSView,x:CGFloat(0),width:rowWidth)]
                if !row.value.isEmpty{
                    let v=label(rowID+".value",row.value,font:readoutSmall,color:style.notice,wraps:true);place(v,in:rowView)
                    title.append((view:v as NSView,x:CGFloat(0),width:rowWidth))
                }
                var top:CGFloat=0
                for cell in title{
                    let h=wrapped(cell.view as! NSTextField,width:rowWidth)
                    cell.view.frame=CGRect(x:0,y:top,width:rowWidth,height:h);top+=h
                }
                var kept=Set(title.map{ObjectIdentifier($0.view)})
                if !row.detail.isEmpty{
                    let d=label(rowID+".detail",row.detail,font:readoutSmall,color:style.muted,wraps:true);place(d,in:rowView)
                    let h=wrapped(d,width:rowWidth);d.frame=CGRect(x:0,y:top,width:rowWidth,height:h);top+=h;kept.insert(ObjectIdentifier(d))
                }
                for child in rowView.subviews where !kept.contains(ObjectIdentifier(child)){child.removeFromSuperview()}
                let rowHeight=max(style.rowMinimumHeight,top)
                rowView.frame=CGRect(x:style.padding+pad.left,y:rowY,width:rowWidth,height:rowHeight)
                rowY+=rowHeight
                continue
            }
            if row.kind == .quota || row.kind == .extraQuota{
                usedBars.insert(row.id)
                let bar=bars[row.id] ?? DockCardBar(row:row,on:toneColor,track:style.track)
                bars[row.id]=bar;bar.apply(row:row,on:toneColor,track:style.track)
                bar.size=style.barSize;bar.gap=style.barGap;place(bar,in:rowView)
                let v=label(rowID+".value",row.value,font:readout,color:valueColor,alignment:.right);place(v,in:rowView)
                let timeX=c[0]+c[1]+c[2]+3*g,timeWidth=max(0,rowWidth-timeX)
                cells=[(view:l as NSView,x:CGFloat(0),width:c[0]),(view:bar as NSView,x:c[0]+g,width:c[1]),(view:v as NSView,x:c[0]+c[1]+2*g,width:c[2])]
                if !row.detail.isEmpty{
                    let d=label(rowID+".detail",row.detail,font:readoutSmall,color:style.muted,alignment:.right);place(d,in:rowView)
                    // The time column holds the detail when it fits on one line; a longer detail keeps
                    // every word, on its own line under the bar and percent columns.
                    if ceil(natural(d).width)<=timeWidth{cells.append((view:d as NSView,x:timeX,width:timeWidth))}
                    else{setWraps(d,true);d.alignment = .left;detailBelow=d}
                }
            }else{
                let restX=c[0]+g,restWidth=max(0,rowWidth-restX)
                let v=label(rowID+".value",row.value,font:readout,color:valueColor,wraps:true);place(v,in:rowView)
                var valueWidth=restWidth
                if !row.detail.isEmpty{
                    let d=label(rowID+".detail",row.detail,font:readoutSmall,color:style.muted,alignment:.right);place(d,in:rowView)
                    let dw=ceil(natural(d).width),vw=ceil(natural(v).width)
                    if vw+g+dw<=restWidth{valueWidth=restWidth-dw-g;cells.append((view:d as NSView,x:restX+valueWidth+g,width:dw))}
                    else{setWraps(d,true);d.alignment = .left;detailBelow=d}
                }
                cells.insert((view:v as NSView,x:restX,width:valueWidth),at:0);cells.insert((view:l as NSView,x:CGFloat(0),width:c[0]),at:0)
            }
            var rowHeight=style.rowMinimumHeight
            for cell in cells{if let field=cell.view as? NSTextField{rowHeight=max(rowHeight,height(field,width:cell.width))}}
            for cell in cells{
                let h:CGFloat,top:CGFloat
                if let field=cell.view as? NSTextField{
                    h=height(field,width:cell.width)
                    // Single-line cells centre on the row; a wrapped value starts on the first line.
                    top=field.lineBreakMode == .byWordWrapping ? max(0,(style.rowMinimumHeight-min(h,style.rowMinimumHeight))/2) : (rowHeight-h)/2
                }else{h=style.barSize.height;top=(rowHeight-h)/2}
                cell.view.frame=CGRect(x:cell.x,y:max(0,top),width:cell.width,height:h)
            }
            if let detailBelow{
                let dx=c[0]+g,dw=max(0,rowWidth-dx),dh=wrapped(detailBelow,width:dw)
                detailBelow.frame=CGRect(x:dx,y:rowHeight,width:dw,height:dh);rowHeight+=dh
            }
            let kept=Set(cells.map{ObjectIdentifier($0.view)}+(detailBelow.map{[ObjectIdentifier($0)]} ?? []))
            for child in rowView.subviews where !kept.contains(ObjectIdentifier(child)){child.removeFromSuperview()}
            rowView.frame=CGRect(x:style.padding+pad.left,y:rowY,width:rowWidth,height:rowHeight)
            rowY+=rowHeight
        }
        if value.rows.isEmpty{windowRect=nil;y=windowTop-style.headerBottomGap}
        else{
            rowY+=pad.bottom
            windowRect=style.window == nil ? nil : CGRect(x:style.padding,y:windowTop,width:inner,height:rowY-windowTop)
            y=rowY
        }
        // Source links (announced public reset): one flowing line in reading order.
        var occurrences=[URL:Int](),links=[DockCardButton]()
        for link in value.links{
            let index=occurrences[link.url,default:0];occurrences[link.url]=index+1
            let digest=SHA256.hash(data:Data(link.url.absoluteString.utf8)).map{String(format:"%02x",$0)}.joined()
            let b=button("link."+digest+".\(index)",link.label){[weak self] in
                guard let self,self.current(value,token:token) else{return};self.onOpenURL?(link.url)
            }
            b.isBordered=false;b.bezelStyle = .inline
            b.attributedTitle=NSAttributedString(string:link.label,attributes:[.font:small,.foregroundColor:style.muted])
            links.append(b)
        }
        if !links.isEmpty{
            y+=6
            var lineX=style.padding,lineHeight:CGFloat=0
            for b in links{
                place(b,in:self);let s=b.fittingSize,w=min(ceil(s.width),inner)
                if lineX>style.padding && lineX+w>style.width-style.padding{y+=lineHeight+2;lineX=style.padding;lineHeight=0}
                b.frame=CGRect(x:lineX,y:y,width:w,height:ceil(s.height))
                lineX+=w+10;lineHeight=max(lineHeight,ceil(s.height))
            }
            y+=lineHeight
        }
        if style.showsActions{
            let enter=button("enter",value.enterLabel){[weak self] in guard let self,self.current(value,token:token) else{return};self.onEnter?(value.subscriptionID,value.revision)}
            enter.isEnabled = enterDisabledReason == nil;enter.setAccessibilityHelp(enterDisabledReason)
            let close=button("close",value.dismissLabel){[weak self] in guard let self,self.current(value,token:token) else{return};self.onDismiss?()}
            y+=8
            var footerX=style.width-style.padding,footerHeight:CGFloat=0
            for b in [close,enter]{
                place(b,in:self);let s=b.fittingSize
                b.frame=CGRect(x:footerX-ceil(s.width),y:y,width:ceil(s.width),height:ceil(s.height));footerX-=ceil(s.width)+8;footerHeight=max(footerHeight,ceil(s.height))
            }
            y+=footerHeight
        }
        y+=style.verticalPadding
        setAccessibilityRole(.group);setAccessibilityLabel(value.name);setAccessibilityHelp(nil)
        for id in Array(buttons.keys) where !usedButtons.contains(id){if let b=buttons.removeValue(forKey:id){b.retire();b.removeFromSuperview()}}
        for id in Array(bars.keys) where !usedBars.contains(id){if let bar=bars.removeValue(forKey:id){bar.setAccessibilityElement(false);bar.removeFromSuperview()}}
        for id in Array(labels.keys) where !usedLabels.contains(id){labels.removeValue(forKey:id)?.removeFromSuperview()}
        for id in Array(rowViews.keys) where !usedRows.contains(id){if let row=rowViews.removeValue(forKey:id){row.setAccessibilityElement(false);row.removeFromSuperview()}}
        frame.size=CGSize(width:style.width,height:max(40,ceil(y)))
        setAccessibilityElement(true);needsDisplay=true
    }
    private func current(_ value:DockCardContent,token:UInt64)->Bool{
        guard !isHiddenOrHasHiddenAncestor,generation==token,content==value,permitsAction?(value.subscriptionID,value.revision) ?? true else{return false}
        return generation==token && content==value
    }
    private func clear(){
        content=nil;buttons.values.forEach{$0.retire()};bars.values.forEach{$0.setAccessibilityElement(false)}
        rowViews.values.forEach{$0.setAccessibilityElement(false)}
        subviews.forEach{$0.removeFromSuperview()}
        buttons.removeAll();bars.removeAll();labels.removeAll();rowViews.removeAll();brandView=nil;windowRect=nil
    }
    public override func draw(_ dirtyRect:NSRect){
        // Flat plate with a 1 pt inset seam; dark readout window with its own seam (face.css #card.c7).
        NSColor.clear.setFill();bounds.fill(using:.copy)
        style.background.setFill();NSBezierPath(roundedRect:bounds,xRadius:style.plateRadius,yRadius:style.plateRadius).fill()
        if let seam=style.seam{
            seam.setStroke()
            let edge=NSBezierPath(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),xRadius:max(0,style.plateRadius-0.5),yRadius:max(0,style.plateRadius-0.5))
            edge.lineWidth=1;edge.stroke()
        }
        if let windowRect,let fill=style.window{
            fill.setFill();NSBezierPath(roundedRect:windowRect,xRadius:style.windowRadius,yRadius:style.windowRadius).fill()
            if let seam=style.windowSeam{
                seam.setStroke()
                let edge=NSBezierPath(roundedRect:windowRect.insetBy(dx:0.5,dy:0.5),xRadius:max(0,style.windowRadius-0.5),yRadius:max(0,style.windowRadius-0.5))
                edge.lineWidth=1;edge.stroke()
            }
        }
    }
    public func dispose(){generation &+= 1;clear();setAccessibilityElement(false);onEnter=nil;onDismiss=nil;onOpenURL=nil;onFocusChange=nil;permitsAction=nil}
}
