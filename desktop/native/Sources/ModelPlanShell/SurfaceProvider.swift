// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore

/// Presentation-only seam. Scheduling, CLI commands, window policy and event routing stay with the app.
@MainActor public protocol NativeSurfaceProvider {
    func makeOverview() -> any NativeOverviewSurface
}
@MainActor public protocol NativeOverviewSurface: AnyObject {
    var view: NSView { get }
    func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics)
}

/// Complete neutral default; no official art, private checkout, WebKit or RealityKit dependency.
@MainActor public struct NeutralSurfaceProvider: NativeSurfaceProvider {
    public init() {}
    public func makeOverview() -> any NativeOverviewSurface { NeutralOverview() }
}
@MainActor private final class NeutralOverview: NativeOverviewSurface {
    let view = NSView()
    private let status = NSTextField(labelWithString: "Not connected")
    private let detail = NSTextField(wrappingLabelWithString: "")
    init() {
        let title = NSTextField(labelWithString:"Model Plan Community")
        title.font = .systemFont(ofSize:18, weight:.semibold)
        let intel = NSTextField(wrappingLabelWithString:"Intel 未测试，3D 效果可能卡顿 / Intel untested; 3D may stutter")
        intel.font = .systemFont(ofSize:11); intel.textColor = .secondaryLabelColor
        let stack = NSStackView(views:[title,status,detail,intel])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:20),
            stack.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-20),
            stack.topAnchor.constraint(equalTo:view.topAnchor,constant:20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo:view.bottomAnchor,constant:-20)])
    }
    func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics) {
        guard let snapshot else {
            status.stringValue = diagnostics.personal == "not-loaded" ? "Reading local snapshot…" : "Local data unavailable"
            detail.stringValue = "Read-only access only. No reader or permission is enabled here."
            return
        }
        status.stringValue = snapshot.presentation.actionable ? "Read-only snapshot" : "Unavailable or stale"
        detail.stringValue = "\(snapshot.presentation.quotas.count) quota windows · \(snapshot.presentation.live.filter(\.working).count) recently working sessions"
        if snapshot.publication == nil { detail.stringValue += "\nPublished recommendations unavailable" }
        if diagnostics.publicationWarning { detail.stringValue += "\nUsing dated, last-good public data" }
    }
}
