// SPDX-License-Identifier: MIT
import AppKit
import ObjectiveC

private var dockSliverMenuAssociationKey: UInt8 = 0

/// One caller-supplied menu row. A nil title denotes a separator; a nil action is read-only.
@MainActor public struct DockMenuPresentationItem {
    public let title: String?, accessibilityID: String?, keyEquivalent: String
    public let action: (() -> Void)?
    public let target: AnyObject?, selector: Selector?
    public init(title: String?, accessibilityID: String? = nil, keyEquivalent: String = "",
                target: AnyObject? = nil, selector: Selector? = nil, action: (() -> Void)? = nil) {
        self.title = title; self.accessibilityID = accessibilityID; self.keyEquivalent = keyEquivalent
        self.target = target; self.selector = selector; self.action = action
    }
}

/// Host-owned callbacks only. No updater, browser/network call, Settings write or duplicate Help state.
@MainActor public final class DockStatusMenu:NSObject,NSMenuDelegate {
    public let menu=NSMenu()
    public var onMenuActuallyOpen:((Bool)->Void)?,onRestoreStatusFocus:(()->Void)?
    private let handlers:[DockMenuCommand:()->Void]
    private var helpRequested=false,disposed=false
    private var presentedActions: [Int: () -> Void] = [:]
    public private(set) var isActuallyOpen=false
    public init(labels:[DockMenuCommand:String],handlers:[DockMenuCommand:()->Void]){
        self.handlers=handlers;super.init();menu.delegate=self;menu.autoenablesItems=false
        for entry in DockMenuModel.entries(hasHelp:handlers[.help] != nil){
            if entry.separatorBefore{menu.addItem(.separator())}
            let item=NSMenuItem(title:labels[entry.command] ?? entry.command.rawValue,action:#selector(selected(_:)),keyEquivalent:"")
            item.target=self;item.representedObject=entry.command.rawValue;item.isEnabled=handlers[entry.command] != nil;menu.addItem(item)
        }
    }
    /// Reconfigure the same tracked menu so privacy invalidation can scrub retained items.
    public func replace(with items: [DockMenuPresentationItem]) {
        guard !disposed else { return }
        presentedActions = [:]; menu.removeAllItems()
        for (index, value) in items.enumerated() {
            guard let title = value.title else { menu.addItem(.separator()); continue }
            let selector = value.selector ?? (value.action == nil ? nil : #selector(selectedPresentation(_:)))
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: value.keyEquivalent)
            item.target = value.selector == nil ? (value.action == nil ? nil : self) : value.target
            item.representedObject = index; item.isEnabled = selector != nil
            if let id = value.accessibilityID { item.setAccessibilityIdentifier(id) }
            if let action = value.action { presentedActions[index] = action }
            menu.addItem(item)
        }
    }
    @objc private func selectedPresentation(_ sender: NSMenuItem) {
        guard !disposed, let index = sender.representedObject as? Int else { return }; presentedActions[index]?()
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
    public func dispose(){guard !disposed else{return};disposed=true;menu.cancelTracking();if isActuallyOpen{isActuallyOpen=false;onMenuActuallyOpen?(false)};menu.delegate=nil;menu.removeAllItems();presentedActions=[:];onMenuActuallyOpen=nil;onRestoreStatusFocus=nil;helpRequested=false}
    @objc private func selected(_ sender:NSMenuItem){guard let raw=sender.representedObject as? String,let command=DockMenuCommand(rawValue:raw) else{return};perform(command)}
}
@MainActor public final class DockSliverMenu:NSObject,NSMenuDelegate {
    public enum Command:String,Hashable {case openCockpit,settings,hideDock}
    private var heldMenu: NSMenu? = NSMenu()
    private weak var transferredMenu: NSMenu?
    public var menu: NSMenu { guard let menu = heldMenu ?? transferredMenu else { preconditionFailure("Menu lifetime ended") }; return menu }
    public weak var owner: AnyObject?
    public private(set) var isActuallyOpen=false
    public var onMenuActuallyOpen:((Bool)->Void)?
    private let handlers:[Command:()->Void]
    private var presentedActions: [Int: () -> Void] = [:]
    public init(labels:[Command:String],handlers:[Command:()->Void]){self.handlers=handlers;super.init();menu.autoenablesItems=false;menu.delegate=self
        for command in [Command.openCockpit,.settings,.hideDock]{let item=NSMenuItem(title:labels[command] ?? command.rawValue,action:#selector(selected(_:)),keyEquivalent:"");item.target=self;item.representedObject=command.rawValue;item.isEnabled=handlers[command] != nil;menu.addItem(item)}}
    /// A returned menu retains its delegate without a menu/delegate ownership cycle.
    public func retainWithMenu() {
        let value = menu
        objc_setAssociatedObject(value, &dockSliverMenuAssociationKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        transferredMenu = value; heldMenu = nil
    }
    public func replace(with items: [DockMenuPresentationItem]) {
        presentedActions = [:]; menu.removeAllItems()
        for (index, value) in items.enumerated() {
            guard let title = value.title else { menu.addItem(.separator()); continue }
            let selector = value.selector ?? (value.action == nil ? nil : #selector(selectedPresentation(_:)))
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: value.keyEquivalent)
            item.target = value.selector == nil ? (value.action == nil ? nil : self) : value.target
            item.representedObject = index; item.isEnabled = selector != nil
            if let id = value.accessibilityID { item.setAccessibilityIdentifier(id) }
            if let action = value.action { presentedActions[index] = action }
            menu.addItem(item)
        }
    }
    @objc private func selectedPresentation(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }; presentedActions[index]?()
    }
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
    public func attach(to button: NSButton) {
        frame = NSRect(x: max(0, button.bounds.width - 7), y: max(0, button.bounds.height - 7), width: 7, height: 7)
        autoresizingMask = [.minXMargin, .minYMargin]
        if superview !== button { button.addSubview(self) }
    }
    public override func hitTest(_ point:NSPoint)->NSView?{nil}
    public override func draw(_ dirtyRect:NSRect){guard let notice else{return};let color=colors[notice.tone] ?? .secondaryLabelColor
        let path=NSBezierPath(ovalIn:bounds.insetBy(dx:1,dy:1));if notice.shape == .hollow{color.setStroke();path.lineWidth=1;path.stroke()}else{color.setFill();path.fill()}}
}
