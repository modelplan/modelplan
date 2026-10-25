// SPDX-License-Identifier: MIT
import Foundation

/// Catalog facts remain readable when personal data cannot be joined. No entitlement claim.
public struct ModelSelectionFeeds: Sendable {
    public let publication: PublicPublication?
    public let personal: PersonalSnapshot?
    public let personalUsable: Bool
    public let publicIsLastGood: Bool
    public init(publication: PublicPublication?, personal: PersonalSnapshot?, personalUsable: Bool,
                publicIsLastGood: Bool = false) {
        self.publication = publication; self.personal = personal
        self.personalUsable = personalUsable; self.publicIsLastGood = publicIsLastGood
    }
}
