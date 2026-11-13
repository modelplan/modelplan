// SPDX-License-Identifier: MIT
import Foundation
public enum DockMenuCommand:String,CaseIterable,Hashable,Sendable {
    case website,methodology,privacy,help,settings,about,quit
}
public struct DockMenuEntry:Equatable,Sendable {
    public let command:DockMenuCommand,separatorBefore:Bool
}
public enum DockMenuModel {
    /// Start the app-actions group at Help when available, otherwise at Settings.
    public static func entries(hasHelp: Bool) -> [DockMenuEntry] {
        let firstAppAction: DockMenuCommand = hasHelp ? .help : .settings
        return DockMenuCommand.allCases.filter { hasHelp || $0 != .help }.map { command in
            .init(command: command, separatorBefore: command == firstAppAction || command == .quit)
        }
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
