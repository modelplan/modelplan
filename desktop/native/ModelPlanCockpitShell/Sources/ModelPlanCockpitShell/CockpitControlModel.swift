// SPDX-License-Identifier: MIT
import AppKit

/// A content view may expose registered controls beyond its layout slot, within the vessel bounds.
@MainActor public protocol CockpitOverflowHitTesting: AnyObject { var interactionBounds: CGRect { get } }

@MainActor public protocol CockpitPresentationConsumer: AnyObject {
    func setPresentationAllowed(_ allowed: Bool)
    func stop()
}
