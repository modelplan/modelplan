// SPDX-License-Identifier: MIT
import AppKit

/// Host-owned callbacks only. No updater, browser/network call, Settings write or duplicate Help state.
@MainActor public final class DockStatusMenu:NSObject,NSMenuDelegate {
    public let menu=NSMenu()
    public var onMenuActuallyOpen:((Bool)->Void)?,onRestoreStatusFocus:(()->Void)?
    private let handlers:[DockMenuCommand:()->Void]
    private var helpRequested=false,disposed=false
    public private(set) var isActuallyOpen=false
    public init(labels:[DockMenuCommand:String],handlers:[DockMenuCommand:()->Void]){
        self.handlers=handlers;super.init();menu.delegate=self;menu.autoenablesItems=false
        for entry in DockMenuModel.entries(hasHelp:handlers[.help] != nil){
            if entry.separatorBefore{menu.addItem(.separator())}
            let item=NSMenuItem(title:labels[entry.command] ?? entry.command.rawValue,action:#selector(selected(_:)),keyEquivalent:"")
            item.target=self;item.representedObject=entry.command.rawValue;item.isEnabled=handlers[entry.command] != nil;menu.addItem(item)
        }
    }
    public func attach(to statusItem:NSStatusItem){statusItem.menu=menu}
    public func menuWillOpen(_ menu:NSMenu){isActuallyOpen=true;onMenuActuallyOpen?(true)}
    public func menuDidClose(_ menu:NSMenu){isActuallyOpen=false;onMenuActuallyOpen?(false)}
    public func perform(_ command:DockMenuCommand){
        guard !disposed,let action=handlers[command] else{return}
        if command == .help{helpRequested=true};action()
    }
    /// Called by the existing latched map's Esc/outside-click dismissal, not a second map implementation.
    public func helpDidDismiss(){guard helpRequested else{return};helpRequested=false;onRestoreStatusFocus?()}
    public func dispose(){guard !disposed else{return};disposed=true;menu.cancelTracking();if isActuallyOpen{isActuallyOpen=false;onMenuActuallyOpen?(false)};menu.delegate=nil;menu.removeAllItems();onMenuActuallyOpen=nil;onRestoreStatusFocus=nil;helpRequested=false}
    @objc private func selected(_ sender:NSMenuItem){guard let raw=sender.representedObject as? String,let command=DockMenuCommand(rawValue:raw) else{return};perform(command)}
}
@MainActor public final class DockSliverMenu:NSObject,NSMenuDelegate {
    public enum Command:String,Hashable {case openCockpit,settings,hideDock}
    public let menu=NSMenu()
    public private(set) var isActuallyOpen=false
    public var onMenuActuallyOpen:((Bool)->Void)?
    private let handlers:[Command:()->Void]
    public init(labels:[Command:String],handlers:[Command:()->Void]){self.handlers=handlers;super.init();menu.autoenablesItems=false;menu.delegate=self
        for command in [Command.openCockpit,.settings,.hideDock]{let item=NSMenuItem(title:labels[command] ?? command.rawValue,action:#selector(selected(_:)),keyEquivalent:"");item.target=self;item.representedObject=command.rawValue;item.isEnabled=handlers[command] != nil;menu.addItem(item)}}
    public func menuWillOpen(_ menu:NSMenu){isActuallyOpen=true;onMenuActuallyOpen?(true)}
    public func menuDidClose(_ menu:NSMenu){isActuallyOpen=false;onMenuActuallyOpen?(false)}
    @objc private func selected(_ sender:NSMenuItem){guard let raw=sender.representedObject as? String,let command=Command(rawValue:raw) else{return};handlers[command]?()}
}
/// Template-independent notice marker. The appearance owner supplies its registered rect/colors.
@MainActor public final class DockNoticeIndicatorView:NSView {
    public var notice:DockNotice?{didSet{needsDisplay=true}}
    public var colors:[DockNotice.Tone:NSColor]=[.amber:.systemOrange,.blue:.systemBlue,.white:.white]{didSet{needsDisplay=true}}
    public func apply(_ value:DockNotice?,firstAppearanceAnimation:CAAnimation?=nil,reducedMotion:Bool){
        wantsLayer=true;layer?.removeAnimation(forKey:"dock-notice-once");notice=value
        guard value != nil,!reducedMotion,let animation=firstAppearanceAnimation?.copy() as? CAAnimation,animation.duration.isFinite,(0...2).contains(animation.duration) else{return}
        animation.repeatCount=0;animation.repeatDuration=0;animation.isRemovedOnCompletion=true
        layer?.add(animation,forKey:"dock-notice-once")
    }
    public override func hitTest(_ point:NSPoint)->NSView?{nil}
    public override func draw(_ dirtyRect:NSRect){guard let notice else{return};let color=colors[notice.tone] ?? .secondaryLabelColor
        let path=NSBezierPath(ovalIn:bounds.insetBy(dx:1,dy:1));if notice.shape == .hollow{color.setStroke();path.lineWidth=1;path.stroke()}else{color.setFill();path.fill()}}
}
