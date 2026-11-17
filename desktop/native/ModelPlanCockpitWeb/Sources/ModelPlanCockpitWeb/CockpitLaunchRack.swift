// SPDX-License-Identifier: MIT
import AppKit
import ImageIO
import QuartzCore

/// CKP-SHELL-33: the menu-bar launch rack (owner D157-D160, D172, D175, D178, D181, D186-D188). Timings and distances
/// follow the accepted demo v8 (`menubar-rack-v8.html`, confirm folder 2026-11-12).
public enum CockpitLaunchRackTiming {
  /// Open from the icon: the rack's visible part (its first section) extends first...
  public static let rackOpen: TimeInterval = 0.25
  /// ...then the cockpit comes out from under the menu bar while the rest of the rack extends behind it.
  public static let cockpitOpen: TimeInterval = 0.25
  /// The cockpit starts this far above its attached place (under the menu bar) and slides down.
  public static let openRise: CGFloat = 60
  /// A full extend or retract of the rack (tear-off, put back).
  public static let fullTravel: TimeInterval = 0.56
  /// Key detach: the short nozzle burn and the move out of the catch zone.
  public static let keyDetachBurn: TimeInterval = 0.6
  /// Drag put-back released inside the catch zone: straight home along the rack.
  public static let rideHome: TimeInterval = 0.3
  /// D181: the catch zone (points). It acts only on a drag release; a detached cockpit never snaps by proximity.
  public static let catchZone: CGFloat = 40
  /// D181 addendum: the key-detach step, the catch zone plus a 16 pt margin.
  public static let landingStep: CGFloat = 56
  /// Key put-back flight time, from the demo: 520 ms + 0.9 ms per point of path, kept within 0.82-1.3 s.
  public static func flight(length: CGFloat) -> TimeInterval { min(1.3, max(0.82, 0.52 + Double(length) * 0.0009)) }
}

/// D187: where a key detach puts the cockpit. The first candidate that keeps the WHOLE cockpit inside the visible
/// frame (below the menu bar, above the Dock) and at least 56 pt from home: (1) straight down, (2) sideways toward the
/// screen centre; if neither fits, the short version is tried the same way; failing that, sideways toward the centre by
/// the least that clears the catch zone, kept inside the visible frame. Never partly off-screen. No diagonal (D187).
public enum CockpitDetachLanding {
  public enum Rule: String, Equatable, Sendable { case down, towardCentre, compactDown, compactTowardCentre, minimum }
  public struct Plan: Equatable, Sendable {
    public let frame: CGRect
    public let compact: Bool
    public let rule: Rule
  }
  public static func plan(home: CGRect, compactHome: CGRect?, visible: CGRect) -> Plan {
    let step = CockpitLaunchRackTiming.landingStep
    func fits(_ frame: CGRect) -> Bool {
      frame.minX >= visible.minX - 0.5 && frame.maxX <= visible.maxX + 0.5 && frame.minY >= visible.minY - 0.5 && frame.maxY <= visible.maxY + 0.5
    }
    func direction(_ frame: CGRect) -> CGFloat { frame.midX < visible.midX ? 1 : -1 }
    for (start, compact) in [(home, false)] + (compactHome.map { [($0, true)] } ?? []) {
      let down = start.offsetBy(dx: 0, dy: -step)
      if fits(down) { return Plan(frame: down, compact: compact, rule: compact ? .compactDown : .down) }
      let side = start.offsetBy(dx: direction(start) * step, dy: 0)
      if fits(side) { return Plan(frame: side, compact: compact, rule: compact ? .compactTowardCentre : .towardCentre) }
    }
    let base = compactHome ?? home
    var frame = base.offsetBy(dx: direction(base) * (CockpitLaunchRackTiming.catchZone + 1), dy: 0)
    frame.origin.x = max(visible.minX, min(frame.minX, visible.maxX - frame.width))
    frame.origin.y = max(visible.minY, min(frame.minY, visible.maxY - frame.height))
    return Plan(frame: frame, compact: compactHome != nil, rule: .minimum)
  }
}

/// The rack art's rows (px, top down) and the telescoping of its three sections, as the demo draws them.
public struct CockpitRackMast: Equatable, Sendable {
  public let cap: CGFloat, collar1: CGFloat, collar2: CGFloat, foot: CGFloat, beacon1: CGFloat, beacon2: CGFloat
  public static let night = CockpitRackMast(cap: 15, collar1: 702, collar2: 1119, foot: 1480, beacon1: 688, beacon2: 1107)
  public static let day = CockpitRackMast(cap: 21, collar1: 698, collar2: 1115, foot: 1476, beacon1: 685, beacon2: 1104)
  /// 400 x 1500 px art drawn as 40 x 150 pt.
  public static let pointsPerPixel: CGFloat = 0.1
  public static let width: CGFloat = 40
  public static let length: CGFloat = 150

  public struct Section: Equatable, Sendable {
    /// Visible span in points below the menu bar (y down), and the art's top in the same space.
    public let top: CGFloat, bottom: CGFloat, artTop: CGFloat
  }
  public struct Geometry: Equatable, Sendable {
    public let sections: [Section]
    /// Collar beacon centres (points below the menu bar) and whether each is out.
    public let beacons: [(y: CGFloat, out: Bool)]
    public let progress: [CGFloat]
    public static func == (a: Self, b: Self) -> Bool {
      a.sections == b.sections && a.progress == b.progress && a.beacons.map { $0.y } == b.beacons.map { $0.y } && a.beacons.map { $0.out } == b.beacons.map { $0.out }
    }
  }
  static func easeInOut(_ t: CGFloat) -> CGFloat { t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }
  /// `extension` 0 (in the icon) ... 1 (fully out). Each section eases over its own third, the top one first; a
  /// section is clipped at the bottom collar of the one that holds it and the top one at the menu bar (y 0).
  public func geometry(at e: CGFloat) -> Geometry {
    let e = max(0, min(1, e)), k = Self.pointsPerPixel
    let p = [0, 1, 2].map { Self.easeInOut(max(0, min(1, e * 3 - CGFloat($0)))) }
    let rows = [(cap, collar1), (collar1, collar2), (collar2, foot)]
    let lengths = rows.map { ($0.1 - $0.0) * k }
    var d: [CGFloat] = [], acc: CGFloat = 0
    for i in 0..<3 { acc += lengths[i] * (1 - p[i]); d.append(acc) }
    let origin = -cap * k
    var clip: CGFloat = 0, sections: [Section] = []
    for i in 0..<3 {
      let top = max(clip, origin + rows[i].0 * k - d[i]), bottom = origin + rows[i].1 * k - d[i]
      sections.append(Section(top: top, bottom: bottom, artTop: origin - d[i]))
      clip = max(clip, bottom)
    }
    let b1 = origin + beacon1 * k - d[0], b2 = origin + beacon2 * k - d[1]
    return Geometry(sections: sections, beacons: [(b1, b1 > 1 && (p[0] > 0.99 || p[1] > 0)), (b2, b2 > 1 && (p[1] > 0.99 || p[2] > 0))], progress: p)
  }
}

/// The rack art from the verified cockpit bundle (the official edition the app ships).
struct CockpitRackArt {
  let night: CGImage?, day: CGImage?
  static func load(_ bundle: VerifiedCockpitBundle) -> CockpitRackArt {
    func image(_ name: String) -> CGImage? {
      guard let data = try? bundle.resource(path: "assets/rack/" + name), let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
      return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    return CockpitRackArt(night: image("mast-night.png"), day: image("mast-day.png"))
  }
}

/// Draws the rack from the menu bar down (flipped: y grows downward from the menu bar's bottom edge).
@MainActor final class CockpitRackView: NSView {
  var art = CockpitRackArt(night: nil, day: nil)
  var night = true { didSet { if night != oldValue { needsDisplay = true } } }
  var extensionValue: CGFloat = 0 { didSet { if extensionValue != oldValue { needsDisplay = true } } }
  var moving = false { didSet { if moving != oldValue { needsDisplay = true } } }
  /// In this view's coordinates: the part of the cockpit below its shoulder line. Nothing of the rack is drawn there.
  var maskedOut: CGRect? { didSet { if maskedOut != oldValue { needsDisplay = true } } }
  override var isFlipped: Bool { true }
  override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let mast = night ? CockpitRackMast.night : CockpitRackMast.day
    let geometry = mast.geometry(at: extensionValue)
    context.saveGState(); defer { context.restoreGState() }
    if let maskedOut, !maskedOut.isEmpty {
      context.addRect(bounds); context.addRect(maskedOut)
      context.clip(using: .evenOdd)
    }
    let image = night ? art.night : art.day
    let k = CockpitRackMast.pointsPerPixel
    for section in geometry.sections where section.bottom - section.top > 0.05 {
      let rect = CGRect(x: 0, y: section.top, width: CockpitRackMast.width, height: section.bottom - section.top)
      // The packaged app ships the official cockpit bundle, which carries the approved rack art (owner 11-01: the normal
      // build has the official appearance). A bundle without it draws no rack rather than a stand-in.
      guard let image else { continue }
      // Crop the art rows this span shows; CGImage crops use pixel rows from the top.
      let scale = CGFloat(image.width) / (CockpitRackMast.width / k)
      let rows = CGRect(x: 0, y: (section.top - section.artTop) / k * scale, width: CGFloat(image.width),
                        height: (section.bottom - section.top) / k * scale)
      guard let cropped = image.cropping(to: rows.integral) else { continue }
      context.saveGState()
      // The view is flipped; draw the image upright.
      context.translateBy(x: rect.minX, y: rect.maxY); context.scaleBy(x: 1, y: -1)
      context.draw(cropped, in: CGRect(origin: .zero, size: rect.size))
      context.restoreGState()
    }
    // Night: the collar beacons pulse amber while the rack moves (D160); day beacons stay unlit (D172).
    guard image != nil, night, moving else { return }
    for (index, beacon) in geometry.beacons.enumerated() where beacon.out {
      let progress = geometry.progress[min(index + 1, 2)]
      let alpha = 0.35 + 0.65 * sin(.pi * max(0, min(1, progress)))
      let colors = [NSColor(red: 1, green: 0.84, blue: 0.55, alpha: 0.95 * alpha), NSColor(red: 1, green: 0.67, blue: 0.16, alpha: 0.55 * alpha),
                    NSColor(red: 1, green: 0.59, blue: 0.12, alpha: 0)].map(\.cgColor) as CFArray
      guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.35, 0.7]) else { continue }
      let centre = CGPoint(x: CockpitRackMast.width / 2, y: beacon.y)
      context.drawRadialGradient(gradient, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 8, options: [])
    }
  }
}

/// The rack's own borderless panel, under the cockpit, hanging from the menu bar icon. It never takes input.
@MainActor final class CockpitLaunchRack {
  private(set) var panel: NSPanel?
  private let view = CockpitRackView(frame: .zero)
  /// The icon the rack hangs from (screen coordinates) and the menu bar's bottom edge under it.
  private(set) var icon: CGRect?
  private var orderedBelow = 0
  init(art: CockpitRackArt) { view.art = art }
  var extensionValue: CGFloat { view.extensionValue }
  var isVisible: Bool { panel?.isVisible == true && view.extensionValue > 0 }
  /// The rack's frame for this icon: 40 pt wide, centred on the icon, from the menu bar's bottom edge down 150 pt.
  static func frame(icon: CGRect) -> CGRect {
    CGRect(x: (icon.midX - CockpitRackMast.width / 2).rounded(), y: icon.minY - CockpitRackMast.length,
           width: CockpitRackMast.width, height: CockpitRackMast.length)
  }
  /// Places the rack under `icon` and below `cockpit`, hidden inside `cockpitFrame` below its shoulder line.
  func update(icon: CGRect?, cockpit: NSWindow?, hidden cockpitHidden: CGRect?, extended value: CGFloat, moving: Bool) {
    self.icon = icon
    guard let icon, let cockpit, value > 0 else { panel?.orderOut(nil); orderedBelow = 0; view.extensionValue = max(0, value); return }
    let frame = Self.frame(icon: icon)
    if panel == nil {
      let made = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
      made.isOpaque = false; made.backgroundColor = .clear; made.hasShadow = false
      made.ignoresMouseEvents = true; made.hidesOnDeactivate = false; made.isReleasedWhenClosed = false
      made.level = CockpitWindowController.panelLevel
      made.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
      made.contentView = view
      panel = made
    }
    guard let panel else { return }
    if panel.frame != frame { panel.setFrame(frame, display: false) }
    view.frame = CGRect(origin: .zero, size: frame.size)
    view.night = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) != .aqua
    view.extensionValue = value
    view.moving = moving
    // Screen rect -> the flipped view's coordinates (y down from the menu bar edge).
    view.maskedOut = cockpitHidden.map { CGRect(x: $0.minX - frame.minX, y: frame.maxY - $0.maxY, width: $0.width, height: $0.height) }
    // Just below the cockpit, at the cockpit's level; this also orders a hidden rack in.
    if !panel.isVisible || cockpit.windowNumber != orderedBelow { panel.order(.below, relativeTo: cockpit.windowNumber); orderedBelow = cockpit.windowNumber }
  }
  func close() { panel?.orderOut(nil); panel?.close(); panel = nil; orderedBelow = 0 }
}
