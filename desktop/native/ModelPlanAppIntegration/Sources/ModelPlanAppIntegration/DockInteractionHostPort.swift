// SPDX-License-Identifier: MIT
import ModelPlanDock

/// The host owns drawing and input; the Settings consumer owns controller
/// construction/lifecycle and accepting or rejecting canonical order requests.
@MainActor public protocol DockInteractionHostPort: AnyObject {
    func interactionEnvironment() -> DockInteractionEnvironment
    func installInteraction(_ controller: DockInteractionController)
    func uninstallInteraction(_ controller: DockInteractionController)
}
