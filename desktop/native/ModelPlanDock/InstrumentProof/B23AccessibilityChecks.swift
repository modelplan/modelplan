// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanDock

/// New B23 metadata/identity checks only. No window, screenshot, event injection or official palette proof.
@MainActor func b23CardAccessibilityChecks() throws -> Int {
    var checks=0
    func require(_ value:Bool,_ message:String)throws{checks+=1;if !value{throw NativeFailure(message:"B23: "+message)}}
    func descendants(_ view:NSView)->[NSView]{[view]+view.subviews.flatMap{descendants($0)}}
    let view=DockCardView(frame:.zero)
    var firstBar:NSView?,firstButton:NSButton?,received=[UInt64](),revision:UInt64=0
    view.onEnter={_,r in received.append(r)}
    for chinese in [false,true] {
        for theme in [NSAppearance.Name.aqua,.darkAqua] {
            revision+=1;view.appearance=NSAppearance(named:theme)
            let row=DockCardRow(id:"window.5h",kind:.quota,label:chinese ? "5 小时":"5 hours",value:"50%",detail:chinese ? "剩余额度":"Remaining quota",remainingFraction:0.5,tone:.normal)
            let content=DockCardContent(subscriptionID:"b23",revision:revision,name:"Synthetic",rows:[row],enterLabel:chinese ? "打开":"Open",dismissLabel:chinese ? "关闭":"Close")
            try view.apply(content,pinned:true)
            guard let bar=descendants(view).first(where:{$0.accessibilityIdentifier()=="dock.card.quota.window.5h"}),
                  let button=descendants(view).first(where:{$0.accessibilityIdentifier()=="dock.card.enter"}) as? NSButton else{throw NativeFailure(message:"B23: missing card controls")}
            try require(bar.accessibilityLabel()==row.label,"quota label uses the localized source row")
            try require(bar.accessibilityHelp()==row.value+" · "+row.detail,"quota readout and detail remain available")
            try require((bar.accessibilityValue() as? NSNumber)?.intValue==50,"quota value")
            try require((bar.accessibilityMinValue() as? NSNumber)?.intValue==0 && (bar.accessibilityMaxValue() as? NSNumber)?.intValue==100,"quota range")
            if let firstBar,let firstButton{try require(firstBar === bar && firstButton === button,"refresh must retain AX/focus object identity")}
            else{firstBar=bar;firstButton=button}
            _=button.sendAction(button.action,to:button.target)
            try require(received.last==revision,"retained button dispatches the current revision")
        }
    }
    let target=firstButton?.target,selector=firstButton?.action,count=received.count
    try view.apply(.init(subscriptionID:"b23",revision:revision+1,name:"Synthetic",rows:[]),pinned:false)
    if let selector{_ = NSApplication.shared.sendAction(selector,to:target,from:firstButton)}
    try require(received.count==count,"removed controls cannot dispatch a retained old selector")
    try require(firstButton?.isEnabled==false,"removed button retired")
    try require(firstBar?.isAccessibilityElement()==false,"removed quota AX node retired")
    view.dispose()
    let sliver=DockSliverView(frame:.init(x:0,y:0,width:16,height:16));sliver.onReveal={}
    try require(!sliver.isAccessibilityElement() && !sliver.accessibilityPerformPress(),"unconfigured sliver exposes no English placeholder/action")
    try sliver.apply(image:nil,logicalSize:.init(width:16,height:16),scale:1,accessibilityLabel:"显示订阅")
    try require(sliver.accessibilityLabel()=="显示订阅" && sliver.isAccessibilityElement(),"sliver uses the injected localized label")
    sliver.dispose();try require(!sliver.isAccessibilityElement() && !sliver.accessibilityPerformPress(),"disposed sliver retired")
    let tray=DockOverflowTrayView(frame:.zero);var selected=[String]();tray.onClick={selected.append($0)}
    let entry=DockOverflowEntry(id:"one",label:"订阅一",value:"50%",dragHelp:"拖动换顺序")
    try tray.apply([entry])
    guard let row=descendants(tray).first(where:{$0.accessibilityIdentifier()=="dock.overflow.one"}) else{throw NativeFailure(message:"B23: missing overflow row")}
    try require(!row.acceptsFirstResponder,"passive tray cannot take keyboard focus")
    tray.keyboardNavigationEnabled=true
    try require(row.becomeFirstResponder() && tray.keyboardTargetID=="one","explicit tray focus enters a real row")
    try require(row.accessibilityPerformPress() && selected==["one"],"overflow AX uses its admitted action")
    try tray.apply([.init(id:"one",label:"Subscription one",value:"40%",dragHelp:"Drag to reorder")])
    try require(row === descendants(tray).first(where:{$0.accessibilityIdentifier()=="dock.overflow.one"}),"overflow refresh preserves focus object")
    try require(row.accessibilityLabel()=="Subscription one · 40%","retained overflow row relocalizes")
    let two=DockOverflowEntry(id:"two",label:"Two",value:"20%",dragHelp:"Reorder")
    let three=DockOverflowEntry(id:"three",label:"Three",value:"30%",dragHelp:"Reorder")
    try tray.apply([entry,two,three])
    guard let middle=descendants(tray).first(where:{$0.accessibilityIdentifier()=="dock.overflow.two"}) else{throw NativeFailure(message:"B23: missing second row")}
    try require(middle.becomeFirstResponder() && tray.keyboardTargetID=="two","focus a non-first row")
    try tray.apply([three,two,entry])
    try require(middle === descendants(tray).first(where:{$0.accessibilityIdentifier()=="dock.overflow.two"}) && tray.keyboardTargetID=="two","reorder retains the focused row/target")
    try require(middle.nextKeyView === row,"reorder updates the key-view chain")
    let selectedCount=selected.count
    try tray.apply([three,entry])
    try require(tray.keyboardTargetID=="one","removed focused target falls back to the nearest surviving index")
    try require(!middle.acceptsFirstResponder && !middle.accessibilityPerformPress(),"removed focused row retired")
    try require(selected.count==selectedCount,"focus fallback never selects a subscription")
    try tray.apply([]);try require(tray.keyboardTargetID==nil,"empty tray has no fallback target")
    tray.dispose();try require(!row.accessibilityPerformPress() && !row.acceptsFirstResponder,"retired row cannot focus or act")
    return checks
}
