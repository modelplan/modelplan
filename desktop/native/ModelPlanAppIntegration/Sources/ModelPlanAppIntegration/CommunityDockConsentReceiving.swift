// SPDX-License-Identifier: MIT
import ModelPlanCore

/// In-memory presentation facts from the same canonical readback that controls the desktop gate.
/// This port does not grant consent or enable a reader.
@MainActor public protocol CommunityDockConsentReceiving: AnyObject {
    func updateDockConsent(_ preview: ConsentPreview?)
}
