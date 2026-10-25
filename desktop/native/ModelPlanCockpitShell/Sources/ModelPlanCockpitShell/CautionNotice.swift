// SPDX-License-Identifier: MIT
import Foundation

public enum CautionIdentityError: Error { case invalidComponent }

/// Stable source identity only. Display labels, locale, numeric readings and countdowns are not inputs.
public struct CautionEpisodeID: Hashable, Sendable {
    public let subscriptionID: String
    public let windowID: String?
    public let eventKind: String
    public let episodeID: String
    public init(subscriptionID: String, windowID: String?, eventKind: String, episodeID: String) throws {
        let components = [subscriptionID, eventKind, episodeID] + (windowID.map { [$0] } ?? [])
        guard components.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 4096 }) else {
            throw CautionIdentityError.invalidComponent
        }
        self.subscriptionID = subscriptionID; self.windowID = windowID
        self.eventKind = eventKind; self.episodeID = episodeID
    }
    /// Length framing avoids delimiter collisions, including Unicode identifiers and absent windows.
    var conditionID: String {
        func frame(_ value: String?) -> String {
            guard let value else { return "-:" }
            let canonical = value.precomposedStringWithCanonicalMapping
            return "\(canonical.utf8.count):\(canonical)"
        }
        return "caution:v1:" + [frame(subscriptionID), frame(windowID), frame(eventKind), frame(episodeID)].joined()
    }
}

public enum CautionNoticeLevel: Equatable, Sendable { case information, amber, red }
public struct CautionNotice: Equatable, Sendable {
    public let episode: CautionEpisodeID
    public let level: CautionNoticeLevel
    public init(episode: CautionEpisodeID, level: CautionNoticeLevel) { self.episode = episode; self.level = level }
}
extension CautionLampModel {
    /// Blue informational notices are excluded at the boundary, then the existing primitive owns all transitions.
    public mutating func update(notices: [CautionNotice], now: ContinuousClock.Instant = .now) {
        let conditions: [Condition] = notices.compactMap { notice in
            switch notice.level {
            case .information: return nil
            case .amber: return Condition(id: notice.episode.conditionID, severity: .amber)
            case .red: return Condition(id: notice.episode.conditionID, severity: .red)
            }
        }
        update(conditions, now: now)
    }
}
