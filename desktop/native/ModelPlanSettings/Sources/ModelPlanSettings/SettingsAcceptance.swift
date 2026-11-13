// SPDX-License-Identifier: MIT
import AppKit

/// Leaf observations for a caller-owned acceptance runner. They are never physical-input receipts.
@_spi(SettingsAcceptance) public enum SettingsAcceptanceSurface:String,Encodable,Equatable,Sendable {case settings,firstRun}
@_spi(SettingsAcceptance) public enum SettingsMarkedTextObservation:String,Encodable,Equatable,Sendable {case unobserved,marked,unmarked}
@_spi(SettingsAcceptance) public struct SettingsAcceptanceFocus:Encodable,Equatable,Sendable {
    public let actualRole:String?,initialRole:String?
    public let markedText:SettingsMarkedTextObservation
}
@_spi(SettingsAcceptance) public struct SettingsAcceptancePopup:Encodable,Equatable,Sendable {
    public let key:String,ordinal:Int,selectedIndex:Int,itemCount:Int
    public let enabled:Bool
}
@_spi(SettingsAcceptance) public struct SettingsAcceptanceState:Encodable,Equatable,Sendable {
    public let selectedPane:String,searchLength:Int,visibleKeys:[String]
    public let editingAliases:Int,unsavedAliases:Int
    public let popups:[SettingsAcceptancePopup]
}
@_spi(SettingsAcceptance) public struct FirstRunAcceptanceState:Encodable,Equatable,Sendable {
    public let active:Bool,pageValid:Bool,busy:Bool
    public let subscriptionCount:Int,readerCount:Int,checkedReaders:Int
    public let loginChecked:Bool,doneEnabled:Bool,helpEnabled:Bool
    public let focusOrder:[String],keyChainMatches:Bool
}
@_spi(SettingsAcceptance) public struct SettingsAcceptanceCheckpoint:Encodable,Equatable,Sendable {
    public let evidenceClass="observation-only"
    public let physicalInputEstablished=false
    public let surface:SettingsAcceptanceSurface
    public let editorRevision:UInt64?,storeRevision:UInt64
    public let consistentRevision:Bool,isSaving:Bool
    public let windowVisible:Bool,windowKey:Bool
    public let focus:SettingsAcceptanceFocus
    public let settings:SettingsAcceptanceState?
    public let firstRun:FirstRunAcceptanceState?
    /// Context supplied by the host, not an OS query or a service grant.
    public let loginStateFromContext:String
}

@MainActor func settingsAcceptanceFocus(window:NSWindow?,controls:[(String,NSView)])->SettingsAcceptanceFocus {
    func role(_ responder:NSResponder?)->String? {
        guard let responder else{return nil}
        for (name,view) in controls {
            if responder === view || (responder as? NSView)?.isDescendant(of:view)==true || (view as? NSControl)?.currentEditor() === responder {return name}
        }
        return "other"
    }
    let actual=role(window?.firstResponder)
    let marked:SettingsMarkedTextObservation
    if actual=="settings.alias" || actual=="settings.search",let editor=window?.firstResponder as? NSTextView {
        marked=editor.hasMarkedText() ? .marked:.unmarked
    }else{marked = .unobserved}
    return .init(actualRole:actual,initialRole:role(window?.initialFirstResponder),markedText:marked)
}
