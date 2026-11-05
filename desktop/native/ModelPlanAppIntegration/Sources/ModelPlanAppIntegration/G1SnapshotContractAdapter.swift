// SPDX-License-Identifier: MIT
#if DEBUG
import AppKit

/// Shared rev-2 vocabulary. Values are copied from the detailed rendered observation tree.
public typealias G1Color = G1RenderedColor
public enum G1Role: String, Sendable {
  case dock, ring, segment, ignition, logo, flame, lcd, card, cardRow, sliver
  case menu, menuItem, statusItem, settingsRow, control, cockpitShell, fader, mfd, porthole, notice, other
}
public enum G1Interaction: Sendable { case idle, hover, pressed, disabled }
public struct G1Notice: Sendable {
  public let id: String, surface: String, text: String, source: String?
}
public struct G1Element: Sendable {
  public let id: String
  public let role: G1Role
  public let frame: CGRect?
  public let visible: Bool, enabled: Bool
  public let text: String?
  public let ink: G1Color?, fill: G1Color?, contrastToParent: Double?
  public let imageSource: String?
  public let layerRoles: [String]
  public let interaction: G1Interaction
  public let filters: [String]
  public let transition: String?
  public let children: [G1Element]
  func find(_ target: String) -> Self? {
    if id == target { return self }
    return children.lazy.compactMap { $0.find(target) }.first
  }
  func all(role target: G1Role) -> [Self] {
    (role == target ? [self] : []) + children.flatMap { $0.all(role: target) }
  }
}

// Unknown visibility maps to false; idle means no observed active input, not hover acceptance.
// Detailed unavailable/evidence metadata stays on the composition tree. Only an observed
// screen-frame is exported: local coordinates and web CSS pixels are never relabelled as screen points.
enum G1ContractAdapter {
  static func element(_ node: G1RenderedElement, area: String? = nil) -> G1Element {
    let area = area ?? node.identifier
    let interaction: G1Interaction
    if node.interaction.disabled == true { interaction = .disabled }
    else if node.interaction.press == true { interaction = .pressed }
    else if node.interaction.hover == true { interaction = .hover }
    else { interaction = .idle }
    let frame = node.visible == true ? (node.coordinateSpace == "screen" ? node.frame : node.screenFrame) : nil
    let transition = ["idle", "settled", "open"].contains(node.animationPhase ?? "idle") ? nil : node.animationPhase
    return .init(id: node.identifier, role: role(node, area: area), frame: frame,
      visible: node.visible == true, enabled: node.interaction.disabled != true, text: node.text,
      ink: node.ink, fill: node.fill, contrastToParent: node.contrastAgainstParent,
      imageSource: node.assetSource, layerRoles: node.layerRoles, interaction: interaction,
      filters: node.filters + node.effects, transition: transition,
      children: node.children.map { element($0, area: area) })
  }
  private static func role(_ node: G1RenderedElement, area: String) -> G1Role {
    switch node.identifier {
    case "dock": return .dock
    case "card": return .card
    case "cockpit": return .cockpitShell
    case "dock.ignition": return .ignition
    case "dock.sliver": return .sliver
    default: break
    }
    switch node.role {
    case "nozzle": return .ring
    case "quota-segment": return .segment
    case "working-effect": return .flame
    default: break
    }
    if node.identifier.hasPrefix("dock.readout.") { return .lcd }
    if node.identifier.hasPrefix("dock.logo.") { return .logo }
    if let role = G1Role(rawValue: node.role) { return role }
    if area == "settings", node.text != nil { return .settingsRow }
    if area == "card", node.text != nil { return .cardRow }
    if ["AXButton", "AXCheckBox", "AXSlider", "AXTextField", "AXPopUpButton"].contains(node.role) { return .control }
    return .other
  }
}

extension EngineDockMenuApplication {
  /// Contract facade over the normal composition. Reads never drive inputs or prepare a surface.
  public func renderedSnapshotForChecks() -> G1RenderedSnapshot { composition.renderedSnapshotForChecks() }
  public func advanceClock(by seconds: TimeInterval) {
    guard let controls = g1InspectionControls else { NSLog("G1 clock input rejected: controls not bound"); return }
    do { try controls.advance(by: seconds) }
    catch { NSLog("G1 clock input rejected") }
  }
  public func movePointer(to point: CGPoint) {
    guard let controls = g1InspectionControls else { NSLog("G1 pointer input rejected: controls not bound"); return }
    do { try controls.setPointer(point) }
    catch { NSLog("G1 pointer input rejected") }
  }
  public func injectVerifiedSessionActivity(tool: String, member: String, active: Bool) {
    guard let controls = g1InspectionControls else { NSLog("G1 activity input rejected: controls not bound"); return }
    do { try controls.setVerifiedSessionActivity(tool: tool, member: member, active: active) }
    catch { NSLog("G1 activity input rejected") }
  }
}
#endif
