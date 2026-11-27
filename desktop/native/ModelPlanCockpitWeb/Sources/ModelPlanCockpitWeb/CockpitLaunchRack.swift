// SPDX-License-Identifier: MIT
import AppKit
import ImageIO
import QuartzCore

/// CKP-SHELL-33: the menu-bar launch rack (owner D157-D160, D172, D175, D178, D181, D186-D188). Timings and distances
/// follow the accepted demo v8 (`menubar-rack-v8.html`, confirm folder 2026-11-12).
public enum CockpitLaunchRackTiming {
  /// Open from the icon: the docking boom starts sliding down out of the menu bar first (D430: one piece)...
  public static let rackOpen: TimeInterval = 0.25
  /// ...then the cockpit comes out from under the menu bar while the boom finishes its slide.
  public static let cockpitOpen: TimeInterval = 0.25
  /// D299 (amends D188, WP-17, CKP-SHELL-53): the two phases overlap. The rack still leads; the cockpit starts this long
  /// after the click, before the rack's visible part is out, so the whole open takes `overlappedOpen` (about 0.37 s)
  /// instead of 0.25 + 0.25 s.
  public static let cockpitOpenDelay: TimeInterval = 0.12
  public static var overlappedOpen: TimeInterval { cockpitOpenDelay + cockpitOpen }
  /// D299: at `elapsed` seconds into a rack-first open, the boom's slide (0-1) and the cockpit's own progress (0-1).
  /// The boom leads for its first third over `rackOpen`; the cockpit's progress carries the rest, so the boom is fully
  /// down exactly when the cockpit lands (and the clamp then closes, D439). Both only grow, without a jump.
  public static func openProgress(elapsed: TimeInterval) -> (rack: CGFloat, cockpit: CGFloat) {
    let visible = CGFloat(min(1, max(0, elapsed / rackOpen)))
    let cockpit = CGFloat(min(1, max(0, (elapsed - cockpitOpenDelay) / cockpitOpen)))
    return (min(1, visible / 3 + 2.0 / 3 * cockpit), cockpit)
  }
  /// The cockpit starts this far above its attached place (under the menu bar) and slides down.
  public static let openRise: CGFloat = 60
  /// A full extend or retract of the rack (tear-off, put back).
  public static let fullTravel: TimeInterval = 0.56
  /// Key detach: the short nozzle burn and the move out of the catch zone.
  public static let keyDetachBurn: TimeInterval = 0.6
  /// D459 (owner, 2026-11-26, "about 1-2 s"): a launch (key detach or drag tear-off) burns full thrust this long from
  /// the moment the cockpit leaves the boom; it covers the key detach's move and lands it on the short parked flame.
  public static let launchBurn: TimeInterval = 1.2
  /// Drag put-back released inside the catch zone: straight home along the rack.
  public static let rideHome: TimeInterval = 0.3
  /// D181: the catch zone (points). It acts only on a drag release; a detached cockpit never snaps by proximity.
  public static let catchZone: CGFloat = 40
  /// D181 addendum: the key-detach step, the catch zone plus a 16 pt margin.
  public static let landingStep: CGFloat = 56
  /// Key put-back flight time, from the demo: 520 ms + 0.9 ms per point of path, kept within 0.82-1.3 s.
  public static func flight(length: CGFloat) -> TimeInterval { min(1.3, max(0.82, 0.52 + Double(length) * 0.0009)) }
  /// G3-130 (owner, 11-18): a put back starts the rack's unfold and the cockpit's motion (key flight, near-home move,
  /// ride home) at the same moment, both at their normal speeds; neither waits for or speeds up the other. Where the rack
  /// is when the cockpit lands, from `rackExtension` (0-1) after `motion` seconds: fully out after a long flight, partly
  /// out after a short move, from where it then carries on at the same pace to its attached end state.
  public static func rackAtLanding(motion: TimeInterval, rackExtension: CGFloat) -> CGFloat {
    min(1, max(0, rackExtension) + CGFloat(max(0, motion) / fullTravel))
  }
}

/// CKP-SHELL-33 / G3-130: where a put back's motion has the cockpit's origin at progress `t` (0-1), eased out cubically.
/// The key flight is one quadratic Bezier whose control point sits under home, so its last part runs straight up the
/// rack; the near-home move and the drag's ride home are straight. Every path starts exactly where the cockpit is and
/// is continuous: macrevb/macrev2-1038-1, a start above home (a detached cockpit on a display stacked above, or a drag
/// released just above home) was clamped to home's height on its first frame, a jump of up to a display's height.
public enum CockpitPutBackPath {
  public static func ease(_ t: CGFloat) -> CGFloat { 1 - pow(1 - max(0, min(1, t)), 3) }
  /// The flight's control point: under home by the catch zone, or at the start's height when that is lower still.
  public static func control(from p0: CGPoint, to d: CGPoint, zone: CGFloat) -> CGPoint { CGPoint(x: d.x, y: min(d.y - zone, p0.y)) }
  public static func flight(from p0: CGPoint, to d: CGPoint, zone: CGFloat, at t: CGFloat) -> CGPoint {
    let c = control(from: p0, to: d, zone: zone), k = ease(t), u = 1 - k
    return CGPoint(x: u * u * p0.x + 2 * u * k * c.x + k * k * d.x, y: u * u * p0.y + 2 * u * k * c.y + k * k * d.y)
  }
  public static func straight(from p0: CGPoint, to d: CGPoint, at t: CGFloat) -> CGPoint {
    let e = ease(t)
    return CGPoint(x: p0.x + (d.x - p0.x) * e, y: p0.y + (d.y - p0.y) * e)
  }
}

/// D187: where a key detach puts the cockpit. The first candidate that keeps the WHOLE cockpit inside the visible
/// frame (below the menu bar, above the Dock) and at least 56 pt from home: (1) straight down, (2) sideways toward the
/// screen centre; failing both, sideways toward the centre by the least that clears the catch zone, kept inside the
/// visible frame. Never partly off-screen. No diagonal (D187). D444: a detach never switches layout, so there are no
/// short-version candidates.
public enum CockpitDetachLanding {
  public enum Rule: String, Equatable, Sendable { case down, towardCentre, minimum }
  public struct Plan: Equatable, Sendable {
    public let frame: CGRect
    public let rule: Rule
  }
  public static func plan(home: CGRect, visible: CGRect) -> Plan {
    let step = CockpitLaunchRackTiming.landingStep
    func fits(_ frame: CGRect) -> Bool {
      frame.minX >= visible.minX - 0.5 && frame.maxX <= visible.maxX + 0.5 && frame.minY >= visible.minY - 0.5 && frame.maxY <= visible.maxY + 0.5
    }
    func direction(_ frame: CGRect) -> CGFloat { frame.midX < visible.midX ? 1 : -1 }
    let down = home.offsetBy(dx: 0, dy: -step)
    if fits(down) { return Plan(frame: down, rule: .down) }
    let side = home.offsetBy(dx: direction(home) * step, dy: 0)
    if fits(side) { return Plan(frame: side, rule: .towardCentre) }
    var frame = home.offsetBy(dx: direction(home) * (CockpitLaunchRackTiming.catchZone + 1), dy: 0)
    frame.origin.x = max(visible.minX, min(frame.minX, visible.maxX - frame.width))
    frame.origin.y = max(visible.minY, min(frame.minY, visible.maxY - frame.height))
    return Plan(frame: frame, rule: .minimum)
  }
}

/// CKP-SHELL-33 (owner D430, D439, D446, D447): the docking boom. One piece, never telescoping: it slides down out of the
/// menu bar with its clamp open, and when the cockpit is home the clamp closes on the lug on the canopy frame with a small
/// settle; a put back or detach runs the reverse. Its upper part, mount plate included, stays tucked behind the menu bar
/// (coordinator decision C, 11-25: the 10 pt gap is unchanged, so only the lower shaft and the clamp show; with the
/// shutter closed only the clamp shows, closed on the lug on the shell's top edge). Nothing animates at rest.
public enum CockpitDockingBoom {
  /// The art's anchor points as fractions of the cut boom art (the open and closed poses share one frame, plate edge to
  /// plate edge and plate top to clamp bottom) and of the lug art.
  public struct Metrics: Equatable, Sendable {
    /// The boom art's height over its width.
    public let aspect: CGFloat
    /// The clamp's grip centre, where the lug's pin sits when it is closed (fractions of the art's height and width).
    public let gripY: CGFloat, gripX: CGFloat
    /// The first row (fraction of the height) where the closed pose differs from the open one: the clamp.
    public let clampTop: CGFloat
    /// The lug's drawn width as a fraction of the boom's width, its height over width, and its pin's tip and centre as
    /// fractions of the lug art's width and height. The lug's base bottom sits on the canopy line.
    public let lugWidth: CGFloat, lugAspect: CGFloat, lugPinTip: CGFloat, lugPinY: CGFloat
  }
  /// Measured on the v8x exports (boom crop 630 x 1414 px, lug crop 956 x 554 px, before the half-size downscale): the
  /// closed jaws' gap centre is row 1285; the lug is scaled so its 267 px pin is 56 px (the gap is 60 px) and placed so
  /// its upright stands just right of the jaw tips, the pin reaching into the clamp; the poses differ from row 1193.
  public static let metrics = Metrics(aspect: 1414.0 / 630, gripY: 1285.0 / 1414, gripX: 380.0 / 630, clampTop: 1193.0 / 1414,
                                      lugWidth: 0.318, lugAspect: 554.0 / 956, lugPinTip: 1.0 / 956, lugPinY: 269.5 / 554)
  /// #1207 bounds for the status-item width, and the width used before any status item was measured.
  public static let nominalWidth: CGFloat = 40
  /// D378 with decision C: the menu-bar edge anchor of a hidden status item is as wide as a boom whose clamp alone fills
  /// the 10 pt gap (42 pt), so that boom has one width with the shutter open or closed and its left side stays on the
  /// notch's right edge either way.
  public static var edgeAnchorWidth: CGFloat {
    max(nominalWidth, clampOnlyWidth(line: CockpitShellLayout.menuBarGap).rounded(.up))
  }
  public static let minimumWidth: CGFloat = 24
  public static let maximumWidth: CGFloat = 96
  /// The panel's height below the menu bar. The boom never reaches below the canopy line, far above this.
  public static let length: CGFloat = 150
  /// The settle as the clamp closes (and opens): the boom dips this fraction of its width at mid-travel (less on a closed
  /// shell, `settle(width:restSplit:closed:)`).
  public static let settleDepth: CGFloat = 0.025
  /// The clamp's travel between open and closed.
  public static let clampTravel: TimeInterval = 0.14

  /// A status-item width bounded for very narrow or unusually wide items; an invalid one is the nominal width.
  static func width(for slot: CGFloat) -> CGFloat {
    guard slot.isFinite, slot > 0 else { return nominalWidth }
    return min(maximumWidth, max(minimumWidth, slot))
  }
  /// D447 (owner, 11-25): the boom is as wide as the status item's WIDEST occupied width. The item changes width with its
  /// text, so the widest width seen this session is kept and the boom never shrinks below it.
  public struct WidthTracker: Equatable, Sendable {
    public private(set) var widest: CGFloat = 0
    public init() {}
    public mutating func observe(_ slot: CGFloat) { if slot.isFinite, slot > widest { widest = slot } }
    public var width: CGFloat { widest > 0 ? CockpitDockingBoom.width(for: widest) : nominalWidth }
  }

  /// How far above the canopy line the clamp's top edge is, per point of boom width: the lug's pin height plus the
  /// clamp's art from its top row down to the grip.
  static func clampRise(_ m: Metrics = metrics) -> CGFloat {
    m.lugWidth * m.lugAspect * (1 - m.lugPinY) + m.aspect * (m.gripY - m.clampTop)
  }
  /// Decision C (macrev2-1207-2): with the shutter closed only the clamp shows, at every width. The narrowest boom whose
  /// clamp alone fills the gap down to `line` at rest (its shaft stays behind the menu bar; the clamp's settle is capped
  /// to the headroom that leaves, so the travel never shows shaft either, D449's ~41.5 pt).
  public static func clampOnlyWidth(line: CGFloat) -> CGFloat { max(0, line) / clampRise() }
  /// The width the boom is drawn at: the widest status width (D447), and while the shutter closes (`closed` 0 open ... 1
  /// closed, following the slab) at least `clampOnlyWidth`, so a narrow item's boom shows no shaft on the closed shell.
  /// Continuous in `closed`, so a shutter toggle never jumps.
  public static func drawnWidth(widest: CGFloat, line: CGFloat, closed: CGFloat) -> CGFloat {
    let c = max(0, min(1, closed.isFinite ? closed : 1))
    return widest + c * max(0, clampOnlyWidth(line: line) - widest)
  }

  public enum Clamp: Equatable, Sendable { case open, closing, closed, opening }
  /// D439 (macrev2-1207-1): a departure (key detach, the icon close) first opens the clamp and holds the cockpit and the
  /// boom still for this long; only then do they move. At once under Reduce Motion.
  public static func releaseHold(closure: CGFloat, reduceMotion: Bool) -> TimeInterval {
    reduceMotion ? 0 : TimeInterval(max(0, min(1, closure.isFinite ? closure : 0))) * clampTravel
  }
  /// The clamp closes only once the boom is fully down and the cockpit is home (its lug is there); otherwise it opens.
  public static func clampTarget(slide: CGFloat, cockpitHome: Bool) -> CGFloat { slide >= 1 && cockpitHome ? 1 : 0 }
  public static func clampPhase(closure: CGFloat, target: CGFloat) -> Clamp {
    if closure == target { return target >= 1 ? .closed : .open }
    return target > closure ? .closing : .opening
  }
  static func easeInOut(_ t: CGFloat) -> CGFloat { t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }

  public struct Pose: Equatable, Sendable {
    /// The whole boom in the panel's flipped coordinates (y down from the menu bar's edge). Its top is above 0 (behind the
    /// menu bar) whenever it does not fit the gap; the panel clips it there.
    public let boom: CGRect
    /// 0 open ... 1 closed.
    public let closure: CGFloat
    /// The lug on the canopy line, or nil while the cockpit is not attached.
    public let lug: CGRect?
  }
  /// How far the boom dips at mid-travel of the clamp. Decision C (macrev2-1207-2): with the shutter closed (`closed` 1)
  /// the dip never brings the shaft below the menu bar: it is at most the shaft's headroom above the bar at rest (`restSplit`
  /// is the shaft's lower end at rest, below the bar when positive). Open (`closed` 0) the full settle; continuous between.
  static func settle(width w: CGFloat, restSplit: CGFloat, closed: CGFloat) -> CGFloat {
    let full = w * settleDepth, k = max(0, min(1, closed.isFinite ? closed : 1))
    return full * (1 - k) + k * min(full, max(0, -restSplit))
  }
  /// `line`: the canopy line under the boom, in points below the menu bar. `slide`: 0 (tucked into the menu bar) ... 1
  /// (down, at rest). `closed`: how closed the shutter is (0-1). The boom moves as one rigid piece: only its offset
  /// changes, never its length.
  public static func pose(width w: CGFloat, line: CGFloat, slide: CGFloat, closure: CGFloat, lugShown: Bool, closed: CGFloat = 0,
                          metrics m: Metrics = metrics) -> Pose {
    let h = w * m.aspect, lugWidth = w * m.lugWidth, lugHeight = lugWidth * m.lugAspect
    let restTop = line - lugHeight * (1 - m.lugPinY) - h * m.gripY
    let s = easeInOut(max(0, min(1, slide))), c = max(0, min(1, closure))
    let dip = settle(width: w, restSplit: restTop + h * m.clampTop, closed: closed)
    let top = -h + (restTop + h) * s + dip * sin(.pi * c)
    let lug = lugShown ? CGRect(x: w * m.gripX - lugWidth * m.lugPinTip, y: line - lugHeight, width: lugWidth, height: lugHeight) : nil
    return Pose(boom: CGRect(x: 0, y: top, width: w, height: h), closure: c, lug: lug)
  }
}

/// The boom art from the verified cockpit bundle (the official edition the app ships): the single place it is loaded.
/// Night art only for now (D447: acceptable); the day appearance uses it too.
struct CockpitRackArt {
  let open: CGImage?, closed: CGImage?, lug: CGImage?
  static let files = ["boom-open.png", "boom-closed.png", "lug.png"]
  static func load(_ bundle: VerifiedCockpitBundle) -> CockpitRackArt {
    func image(_ name: String) -> CGImage? {
      guard let data = try? bundle.resource(path: "assets/rack/" + name), let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
      return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    return CockpitRackArt(open: image(files[0]), closed: image(files[1]), lug: image(files[2]))
  }
}

/// Draws the boom from the menu bar down (flipped: y grows downward from the menu bar's bottom edge).
@MainActor final class CockpitRackView: NSView {
  var art = CockpitRackArt(open: nil, closed: nil, lug: nil)
  var pose: CockpitDockingBoom.Pose? { didSet { if pose != oldValue { needsDisplay = true } } }
  /// In this view's coordinates: the part of the cockpit below its shoulder line. Nothing of the boom is drawn there.
  var maskedOut: CGRect? { didSet { if maskedOut != oldValue { needsDisplay = true } } }
  override var isFlipped: Bool { true }
  override func draw(_ dirtyRect: NSRect) {
    // The packaged app ships the official cockpit bundle with the approved art (owner 11-01); a bundle without it draws
    // no boom rather than a stand-in.
    guard let context = NSGraphicsContext.current?.cgContext, let pose, let open = art.open else { return }
    context.saveGState(); defer { context.restoreGState() }
    if let maskedOut, !maskedOut.isEmpty {
      context.addRect(bounds); context.addRect(maskedOut)
      context.clip(using: .evenOdd)
    }
    func paint(_ image: CGImage, in rect: CGRect, alpha: CGFloat = 1, clip: CGRect? = nil) {
      context.saveGState()
      if let clip { context.clip(to: clip) }
      context.setAlpha(alpha)
      // The view is flipped; draw the image upright.
      context.translateBy(x: rect.minX, y: rect.maxY); context.scaleBy(x: 1, y: -1)
      context.interpolationQuality = .high
      context.draw(image, in: CGRect(origin: .zero, size: rect.size))
      context.restoreGState()
    }
    if let lug = pose.lug, let image = art.lug { paint(image, in: lug) }
    let boom = pose.boom, split = boom.minY + boom.height * CockpitDockingBoom.metrics.clampTop
    let shaft = CGRect(x: boom.minX, y: boom.minY, width: boom.width, height: split - boom.minY)
    let clamp = CGRect(x: boom.minX, y: split, width: boom.width, height: boom.maxY - split)
    paint(open, in: boom, clip: shaft)
    // The poses share the shaft; only the clamp cross-fades between open and closed.
    guard let closed = art.closed, pose.closure > 0 else { paint(open, in: boom, clip: clamp); return }
    if pose.closure < 1 { paint(open, in: boom, alpha: 1 - pose.closure, clip: clamp) }
    paint(closed, in: boom, alpha: pose.closure, clip: clamp)
  }
}

/// The rack's own borderless panel, under the cockpit, hanging from the menu bar icon. It never takes input.
@MainActor final class CockpitLaunchRack {
  private(set) var panel: NSPanel?
  private let view = CockpitRackView(frame: .zero)
  /// The icon the rack hangs from (screen coordinates) and the menu bar's bottom edge under it.
  private(set) var icon: CGRect?
  /// The cockpit window and level the rack was last ordered below (G3-156: a level change needs a re-order too).
  private var orderedBelow: (number: Int, level: NSWindow.Level)?
  init(art: CockpitRackArt) { view.art = art }
  /// D447: the widest status-item width seen this session (shared by every cockpit window of the process).
  static var statusWidths = CockpitDockingBoom.WidthTracker()
  /// The last known canopy line under the boom, in points below the menu bar, and how closed the shutter is there (0-1),
  /// kept while the cockpit is away from home.
  private(set) var line: CGFloat = CockpitShellLayout.menuBarGap
  private(set) var closed: CGFloat = 0
  var pose: CockpitDockingBoom.Pose? { view.pose }
  /// The boom follows the widest status-item width, centred on the icon, from the menu bar's bottom edge down 150 pt.
  static func frame(icon: CGRect, width: CGFloat? = nil) -> CGRect {
    let width = width ?? CockpitDockingBoom.width(for: icon.width)
    return CGRect(x: (icon.midX - width / 2).rounded(), y: icon.minY - CockpitDockingBoom.length,
                  width: width, height: CockpitDockingBoom.length)
  }
  /// Places the boom under `icon` and below `cockpit`, hidden inside `cockpitHidden` below its shoulder line. `line` is
  /// the attached cockpit's canopy line (screen y) when known; `slide`, `closure` and `lugShown` set the pose.
  /// `width` overrides the widest status width (D378: the menu-bar edge anchor of a hidden item uses its own width).
  func update(icon: CGRect?, width own: CGFloat? = nil, cockpit: NSWindow?, hidden cockpitHidden: CGRect?, line canopy: (y: CGFloat, closed: CGFloat)?,
              slide value: CGFloat, closure: CGFloat, lugShown: Bool) {
    self.icon = icon
    if let icon, let canopy, canopy.y.isFinite { line = max(0, icon.minY - canopy.y); closed = canopy.closed }
    guard let icon, let cockpit, value > 0 || closure > 0 else { panel?.orderOut(nil); orderedBelow = nil; view.pose = nil; return }
    let widest = own ?? (Self.statusWidths.widest > 0 ? Self.statusWidths.width : CockpitDockingBoom.width(for: icon.width))
    let frame = Self.frame(icon: icon, width: CockpitDockingBoom.drawnWidth(widest: widest, line: line, closed: closed).rounded(.up))
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
    view.pose = CockpitDockingBoom.pose(width: frame.width, line: line, slide: value, closure: closure, lugShown: lugShown, closed: closed)
    // Screen rect -> the flipped view's coordinates (y down from the menu bar edge).
    view.maskedOut = cockpitHidden.map { CGRect(x: $0.minX - frame.minX, y: frame.maxY - $0.maxY, width: $0.width, height: $0.height) }
    // G3-156 (owner, build 2): the rack is ALWAYS behind the cockpit. Ordering below another window does not change a
    // window's level, so the rack takes the cockpit's level first: a detaching or flying cockpit is at `.normal`
    // (G3-102) and a rack left at the attached level drew over its canopy for the whole detach and put back. Then just
    // below the cockpit; this also orders a hidden rack in.
    if panel.level != cockpit.level { panel.level = cockpit.level }
    if !panel.isVisible || orderedBelow?.number != cockpit.windowNumber || orderedBelow?.level != cockpit.level {
      panel.order(.below, relativeTo: cockpit.windowNumber); orderedBelow = (cockpit.windowNumber, cockpit.level)
    }
  }
  /// G3-156: whether the rack's panel is behind `cockpit` in the window server's front-to-back order (nil when the rack
  /// is not on screen). A lower level is behind; at the same level the on-screen order decides.
  func isBehind(_ cockpit: NSWindow) -> Bool? {
    guard let panel, panel.isVisible else { return nil }
    if panel.level != cockpit.level { return panel.level.rawValue < cockpit.level.rawValue }
    let order = NSWindow.windowNumbers(options: []) ?? []
    guard let rack = order.firstIndex(of: NSNumber(value: panel.windowNumber)),
          let front = order.firstIndex(of: NSNumber(value: cockpit.windowNumber)) else { return false }
    return rack > front
  }
  func close() { panel?.orderOut(nil); panel?.close(); panel = nil; orderedBelow = nil }
}
