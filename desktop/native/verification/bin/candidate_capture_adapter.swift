// SPDX-License-Identifier: MIT
// OS observations for candidate_capture.py. This tool never requests permission.
import AppKit
import ApplicationServices
import Foundation

struct Refusal: Error {}
func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1)
}
func rect(_ r: CGRect) -> [String: Double] {
  ["x": Double(r.origin.x), "y": Double(r.origin.y), "width": Double(r.width), "height": Double(r.height)]
}
func intersectContains(_ outer: CGRect, _ inner: CGRect) -> Bool {
  !inner.isEmpty && outer.contains(inner)
}
func inspect(pid: pid_t, executable: String) throws -> [String: Any] {
  guard CGPreflightScreenCaptureAccess() else { throw Refusal() }
  guard let app = NSRunningApplication(processIdentifier: pid),
    let actual = app.executableURL?.resolvingSymlinksInPath().path,
    actual == URL(fileURLWithPath: executable).resolvingSymlinksInPath().path
  else { throw Refusal() }
  guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
    let primary = NSScreen.screens.first else { throw Refusal() }
  let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
  let valid: [(Int, Int, Int, CGRect, String?)] = list.compactMap { item in
    guard let owner = item[kCGWindowOwnerPID as String] as? Int,
      let number = item[kCGWindowNumber as String] as? Int,
      let level = item[kCGWindowLayer as String] as? Int,
      let bounds = item[kCGWindowBounds as String] as? CFDictionary,
      let frame = CGRect(dictionaryRepresentation: bounds), !frame.isEmpty else { return nil }
    let candidateName = owner == Int(pid) ? item[kCGWindowName as String] as? String : nil
    return (owner, number, level, frame, candidateName)
  }
  let owned = valid.filter { $0.0 == Int(pid) }
  // A missing title can be a permission denial. Refuse, rather than infer it is safe.
  guard !owned.isEmpty, owned.contains(where: { ($0.4 ?? "").isEmpty == false }) else { throw Refusal() }
  let status = owned.filter { $0.2 == statusLevel }
  guard status.count == 1 else { throw Refusal() }
  let statusFrame = status[0].3
  let displays: [(CGRect, CGRect, CGFloat)] = NSScreen.screens.map { screen in
    let f = screen.frame
    let cg = CGRect(x: f.minX, y: primary.frame.maxY - f.maxY, width: f.width, height: f.height)
    let bar = CGRect(x: cg.minX, y: cg.minY, width: cg.width, height: NSStatusBar.system.thickness)
    return (cg, bar, screen.backingScaleFactor)
  }
  guard let display = displays.first(where: { intersectContains($0.1, statusFrame) }),
    display.2 == 1 || display.2 == 2 else { throw Refusal() }
  // The user authorised only eight points of padding within the menu-bar band.
  let crop = statusFrame.insetBy(dx: -8, dy: 0).intersection(display.1).integral
  guard intersectContains(display.1, crop), intersectContains(crop, statusFrame) else { throw Refusal() }
  let nearby = valid.filter { $0.0 != Int(pid) && $0.2 == statusLevel && intersectContains(display.1, $0.3) }
    .sorted { abs($0.3.midX - statusFrame.midX) < abs($1.3.midX - statusFrame.midX) }
  guard nearby.count >= 2 else { throw Refusal() }
  let windows: [[String: Any]] = owned.map { entry in
    ["id": entry.1, "ownerPID": entry.0, "layer": entry.2, "frame": rect(entry.3), "name": entry.4 ?? ""]
  }.sorted { ($0["id"] as? Int ?? 0) < ($1["id"] as? Int ?? 0) }
  let style = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleInterfaceStyle"] as? String
  return ["pid": Int(pid), "processVerified": true, "scale": Double(display.2),
    "appearance": style?.lowercased() == "dark" ? "dark" : "light",
    "displayFrame": rect(display.0), "menuBarFrame": rect(display.1), "cropFrame": rect(crop),
    "statusFrame": rect(statusFrame), "neighbourFrames": nearby.prefix(2).map { rect($0.3) },
    "windows": windows]
}
func checkImage(_ path: String) throws -> [String: Int] {
  guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
    let image = NSBitmapImageRep(data: data), image.pixelsWide > 0, image.pixelsHigh > 0 else { throw Refusal() }
  var visible = false
  // Check every pixel: an entirely black/transparent image is not evidence.
  for y in 0..<image.pixelsHigh {
    for x in 0..<image.pixelsWide {
      guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { throw Refusal() }
      if color.alphaComponent > 0 && max(color.redComponent, color.greenComponent, color.blueComponent) > 0.01 { visible = true; break }
    }
    if visible { break }
  }
  guard visible else { throw Refusal() }
  return ["width": image.pixelsWide, "height": image.pixelsHigh]
}
do {
  let args = CommandLine.arguments
  let result: [String: Any]
  if args.count == 4 && args[1] == "inspect", let pid = Int32(args[2]), pid > 0 {
    result = try inspect(pid: pid, executable: args[3])
  } else if args.count == 3 && args[1] == "check-image" {
    result = try checkImage(args[2])
  } else { throw Refusal() }
  let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
  FileHandle.standardOutput.write(data)
} catch { fail("capture unavailable: permission, candidate identity, status geometry, or image") }
