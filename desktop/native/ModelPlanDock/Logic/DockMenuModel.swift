// SPDX-License-Identifier: MIT
import Foundation
public enum DockMenuCommand:String,CaseIterable,Hashable,Sendable {
    case website,methodology,privacy,checkForUpdates,help,settings,about,quit
}
public struct DockMenuEntry:Equatable,Sendable {
    public let command:DockMenuCommand,separatorBefore:Bool
}
public enum DockMenuModel {
    /// Optional Help preserves the original seven commands/two groups for callers without its callback.
    public static func entries(hasHelp:Bool)->[DockMenuEntry]{
        DockMenuCommand.allCases.filter{hasHelp || $0 != .help}.map{.init(command:$0,separatorBefore:$0 == .checkForUpdates || $0 == .quit)}
    }
}
public enum DockAcknowledgementEvent:Sendable {case cockpitOpening,dockRevealed}
extension DockAttentionState {
    public mutating func acknowledge(_ event:DockAcknowledgementEvent,signals:[DockSubscriptionSignal],at now:Date)throws{
        switch event{
        case .cockpitOpening:try acknowledgeCockpitOpen(signals,at:now)
        case .dockRevealed:try acknowledgeDockOpen(signals,at:now)
        }
    }
}
