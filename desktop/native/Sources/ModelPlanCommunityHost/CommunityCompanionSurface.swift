// SPDX-License-Identifier: MIT
import ModelPlanCore

/// An optional upper-app companion. The host forwards the existing store and lifecycle without
/// depending on Dock, Settings or AppIntegration, or activating the console on automatic resume.
@MainActor public protocol CommunityCompanionSurface: AnyObject {
    var showConsole: (() -> Void)? { get set }
    var showSettings: (() -> Void)? { get set }
    func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics)
    func setPresentationAllowed(_ allowed: Bool)
    func close()
}
