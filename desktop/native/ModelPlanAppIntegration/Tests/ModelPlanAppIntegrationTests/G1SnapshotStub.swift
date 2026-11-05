// G1SnapshotStub.swift: shared, do not edit (coordinator 2026-11-05).
// Path in every G1 PR: desktop/native/ModelPlanAppIntegration/Tests/ModelPlanAppIntegrationTests/G1SnapshotStub.swift
// The file is identical in every PR, so merges never conflict. It goes away in one coordinator PR when M2's
// G1RenderedSnapshot seam lands on main. Contract: handoffs/shared/g1-snapshot-contract.md
import AppKit
import CoreGraphics
@testable import ModelPlanAppIntegration

enum G1Seams { static let snapshotAvailable = false }

struct G1RenderedSnapshot {
    let dock: G1Element
    let card: G1Element?
    let settings: G1Element?
    let cockpit: G1Element?
    let menu: G1Element?
    let statusItem: G1Element
    let notices: [G1Notice]
    func find(_ id: String) -> G1Element? { fatalError("stub") }
    func all(role: G1Role) -> [G1Element] { fatalError("stub") }
}

struct G1Element {
    let id: String
    let role: G1Role
    let frame: CGRect
    let visible: Bool
    let enabled: Bool
    let text: String?
    let ink: G1Color?
    let fill: G1Color?
    let contrastToParent: Double?
    let imageSource: String?
    let layerRoles: [String]
    let interaction: G1Interaction
    let filters: [String]
    let transition: String?
    let children: [G1Element]
}

enum G1Interaction { case idle, hover, pressed, disabled }
enum G1Role { case dock, ring, segment, ignition, logo, flame, lcd, card, cardRow, sliver,
              menu, menuItem, statusItem, settingsRow, control, cockpitShell, fader, mfd, porthole, notice, other }
struct G1Color: Equatable { let r, g, b, a: Double; let hex: String }
struct G1Notice { let id: String; let surface: String; let text: String; let source: String? }

@MainActor extension EngineDockMenuApplication {
    func renderedSnapshotForChecks() -> G1RenderedSnapshot { fatalError("stub") }
    func advanceClock(by seconds: TimeInterval) { fatalError("stub") }
    func movePointer(to point: CGPoint) { fatalError("stub") }
    func injectVerifiedSessionActivity(_ tool: String, active: Bool) { fatalError("stub") }
}
