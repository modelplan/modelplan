// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanSettings

/// Complete runtime observations, not an instruction to start a reader or infer membership.
public struct CommunityConnectionFacts: Sendable {
    public let connections: SettingsConnectionSnapshot
    public let about: SettingsAbout?
    public let licenseNotices: [SettingsLicenseNotice]?
    public init(connections: SettingsConnectionSnapshot, about: SettingsAbout? = nil,
                licenseNotices: [SettingsLicenseNotice]? = nil) {
        self.connections = connections; self.about = about; self.licenseNotices = licenseNotices
    }
    public func updating(_ prior: SettingsPageContext) -> SettingsPageContext {
        var next = prior
        next.subscriptions = connections.subscriptions.map { subscription in
            let reading = connections.tools.first { $0.tool == subscription.tool }?.quota
            let source: SubscriptionSourceState = reading == .available ? .fresh : reading == .stale ? .stale : .unavailable
            return .init(id: subscription.reference, name: subscription.name, plan: subscription.plan,
                         vendor: subscription.tool.rawValue, toolNames: [subscription.tool.title], source: source)
        }
        if let about { next.about = about }
        if let licenseNotices { next.licenseNotices = licenseNotices }
        return next
    }
}
public enum CommunityConnectionDestination: Equatable, Sendable { case allowUsage, connections, about }
public struct CommunityConnectionNextStep: Equatable, Sendable {
    public let title: SettingsText
    public let destination: CommunityConnectionDestination
    public static func forReason(_ reason: CommunityReaderReasonCategory) -> Self? {
        switch reason {
        case .fresh: return nil
        case .noConsent, .consentOrPrivacy, .readersOff, .consentChanged, .notEnabled, .notConnectedYet:
            return .init(title: .init("Allow in Settings", "授权读取"), destination: .allowUsage)
        case .updateRequired:
            return .init(title: .init("Check CLI in About", "在关于中检查 CLI"), destination: .about)
        default:
            return .init(title: .init("Check connections in Settings", "在设置中检查连接"), destination: .connections)
        }
    }
}
