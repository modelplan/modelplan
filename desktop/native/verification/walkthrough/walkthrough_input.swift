// SPDX-License-Identifier: MIT
// Synthetic-only helper for the hosted walkthrough (WALKTHROUGH.md). It reads window and
// accessibility state of one subject PID and posts mouse input on a disposable hosted runner.
// It never asks for permission and is not used on the owner's Macs: those keep pointer_drive.
// Build: swiftc -O walkthrough_input.swift -o walkthrough_input
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Metal

func emit(_ value: Any) {
    let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    FileHandle.standardOutput.write(data + Data([10]))
}
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}
func number(_ text: String) -> Double {
    guard let value = Double(text), value.isFinite else { fail("not a number: \(text)") }
    return value
}

// MARK: Host facts

func host() -> [String: Any] {
    let session = (CGSessionCopyCurrentDictionary() as? [String: Any]) ?? [:]
    let screens = NSScreen.screens.map { screen -> [String: Any] in
        ["frame": rect(screen.frame), "visible": rect(screen.visibleFrame), "scale": screen.backingScaleFactor]
    }
    return ["accessibilityTrusted": AXIsProcessTrusted(), "screenCapture": CGPreflightScreenCaptureAccess(),
            "postEvent": CGPreflightPostEventAccess(), "listenEvent": CGPreflightListenEventAccess(),
            "metalDevice": MTLCreateSystemDefaultDevice()?.name ?? "none", "screens": screens,
            "sessionOnConsole": session[kCGSessionOnConsoleKey as String] as? Bool ?? false,
            "sessionUser": session[kCGSessionUserNameKey as String] as? String ?? ""]
}
func rect(_ value: CGRect) -> [Double] {
    [value.minX, value.minY, value.width, value.height].map { Double($0) }
}

// MARK: Windows (global top-left coordinates, the same space as AX frames and CGEvent)

func windows(pid: Int32) -> [[String: Any]] {
    let list = (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
    return list.compactMap { info -> [String: Any]? in
        guard (info[kCGWindowOwnerPID as String] as? Int32) == pid,
              let bounds = info[kCGWindowBounds as String] as? [String: Double] else { return nil }
        return ["id": info[kCGWindowNumber as String] as? Int ?? 0,
                "layer": info[kCGWindowLayer as String] as? Int ?? 0,
                "onScreen": info[kCGWindowIsOnscreen as String] as? Bool ?? false,
                "alpha": info[kCGWindowAlpha as String] as? Double ?? 0,
                "name": info[kCGWindowName as String] as? String ?? "",
                "bounds": [bounds["X"] ?? 0, bounds["Y"] ?? 0, bounds["Width"] ?? 0, bounds["Height"] ?? 0]]
    }
}

// MARK: Accessibility

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
func frame(_ element: AXUIElement) -> [Double]? {
    guard let position = attribute(element, kAXPositionAttribute), let size = attribute(element, kAXSizeAttribute),
          CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
    var origin = CGPoint.zero, extent = CGSize.zero
    AXValueGetValue(position as! AXValue, .cgPoint, &origin)
    AXValueGetValue(size as! AXValue, .cgSize, &extent)
    return [origin.x, origin.y, extent.width, extent.height].map { Double($0) }
}
func text(_ element: AXUIElement, _ name: String) -> String? {
    guard let value = attribute(element, name) else { return nil }
    if let string = value as? String { return string.isEmpty ? nil : String(string.prefix(160)) }
    if let number = value as? NSNumber { return number.stringValue }
    return nil
}
struct Walk { var left: Int; let depthLimit: Int }
func describe(_ element: AXUIElement, depth: Int, walk: inout Walk) -> [String: Any]? {
    guard walk.left > 0 else { return nil }
    walk.left -= 1
    var node: [String: Any] = [:]
    for (key, name) in [("role", kAXRoleAttribute), ("subrole", kAXSubroleAttribute), ("id", kAXIdentifierAttribute),
                        ("title", kAXTitleAttribute), ("label", kAXDescriptionAttribute), ("value", kAXValueAttribute),
                        ("help", kAXHelpAttribute), ("dom", "AXDOMIdentifier")] {
        if let value = text(element, name) { node[key] = value }
    }
    if let value = frame(element) { node["frame"] = value }
    if depth < walk.depthLimit, let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement], !children.isEmpty {
        node["children"] = children.compactMap { describe($0, depth: depth + 1, walk: &walk) }
    }
    return node
}
func application(_ pid: Int32) -> AXUIElement { AXUIElementCreateApplication(pid) }
func tree(pid: Int32) -> [String: Any] {
    var walk = Walk(left: 6000, depthLimit: 40)
    let app = application(pid)
    var out: [String: Any] = ["windows": [], "extras": []]
    if let list = attribute(app, kAXWindowsAttribute) as? [AXUIElement] {
        out["windows"] = list.compactMap { describe($0, depth: 0, walk: &walk) }
    }
    if let extras = attribute(app, "AXExtrasMenuBar") {
        out["extras"] = describe(extras as! AXUIElement, depth: 0, walk: &walk) ?? [:]
    }
    return out
}
func find(_ element: AXUIElement, attribute name: String, equals wanted: String, depth: Int, left: inout Int) -> AXUIElement? {
    guard left > 0, depth < 40 else { return nil }
    left -= 1
    if text(element, name) == wanted { return element }
    for child in (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
        if let hit = find(child, attribute: name, equals: wanted, depth: depth + 1, left: &left) { return hit }
    }
    return nil
}
func press(pid: Int32, by key: String, value: String) -> Bool {
    var left = 6000
    let app = application(pid)
    let name = key == "title" ? kAXTitleAttribute : kAXIdentifierAttribute
    var roots = (attribute(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    if let extras = attribute(app, "AXExtrasMenuBar") { roots.append(extras as! AXUIElement) }
    for root in roots {
        if let hit = find(root, attribute: name, equals: value, depth: 0, left: &left) {
            return AXUIElementPerformAction(hit, kAXPressAction as CFString) == .success
        }
    }
    return false
}

// MARK: Input

func post(_ type: CGEventType, _ point: CGPoint, _ button: CGMouseButton = .left, clicks: Int64 = 1) {
    guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button) else {
        fail("cannot create event")
    }
    event.setIntegerValueField(.mouseEventClickState, value: clicks)
    event.post(tap: .cghidEventTap)
}
func glide(from: CGPoint, to: CGPoint, seconds: Double, type: CGEventType) {
    let steps = max(2, Int(seconds * 60))
    for step in 1...steps {
        let t = Double(step) / Double(steps)
        post(type, CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
        usleep(UInt32(seconds / Double(steps) * 1_000_000))
    }
}
func cursor() -> CGPoint { CGEvent(source: nil)?.location ?? .zero }
func key(_ code: CGKeyCode) {
    for down in [true, false] {
        CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)?.post(tap: .cghidEventTap)
        usleep(40_000)
    }
}

// MARK: Display

func modes() -> [[String: Any]] {
    let options = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
    let list = (CGDisplayCopyAllDisplayModes(CGMainDisplayID(), options) as? [CGDisplayMode]) ?? []
    return list.map { ["width": $0.width, "height": $0.height, "pixelWidth": $0.pixelWidth, "pixelHeight": $0.pixelHeight] }
}
/// The largest mode with the requested point size, preferring more pixels (HiDPI) when offered.
func setMode(width: Int, height: Int) -> Bool {
    let options = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
    let list = (CGDisplayCopyAllDisplayModes(CGMainDisplayID(), options) as? [CGDisplayMode]) ?? []
    guard let mode = list.filter({ $0.width == width && $0.height == height }).max(by: { $0.pixelWidth < $1.pixelWidth }) else { return false }
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success else { return false }
    CGConfigureDisplayWithDisplayMode(config, CGMainDisplayID(), mode, nil)
    return CGCompleteDisplayConfiguration(config, .permanently) == .success
}

// MARK: Pixels

func bitmap(_ path: String) -> (pixels: [UInt8], width: Int, height: Int) {
    guard let image = NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fail("cannot read image") }
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let drawn: Bool = pixels.withUnsafeMutableBytes { bytes in
        guard let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else { fail("cannot draw image") }
    return (pixels, width, height)
}
/// Distinct coarse colours and the share of the most common one: a black or uniform render fails.
/// `red` counts strongly red pixels, which only the critical ring paints on the widget.
func stats(path: String) -> [String: Any] {
    let (pixels, width, height) = bitmap(path)
    var counts: [UInt16: Int] = [:]
    var red = 0
    for index in stride(from: 0, to: pixels.count, by: 4) {
        let bucket = UInt16(pixels[index] >> 4) << 8 | UInt16(pixels[index + 1] >> 4) << 4 | UInt16(pixels[index + 2] >> 4)
        counts[bucket, default: 0] += 1
        if pixels[index] > 170, pixels[index + 1] < 90, pixels[index + 2] < 90 { red += 1 }
    }
    return ["width": width, "height": height, "colours": counts.count, "red": red,
            "dominantShare": Double(counts.values.max() ?? 0) / Double(max(1, width * height))]
}
/// Share of pixels whose channels differ by more than 24 of 255. Sizes must match.
func difference(_ first: String, _ second: String) -> [String: Any] {
    let a = bitmap(first), b = bitmap(second)
    guard a.width == b.width, a.height == b.height else { fail("image sizes differ") }
    var changed = 0
    for index in stride(from: 0, to: a.pixels.count, by: 4) {
        if (0..<3).contains(where: { abs(Int(a.pixels[index + $0]) - Int(b.pixels[index + $0])) > 24 }) { changed += 1 }
    }
    return ["changedShare": Double(changed) / Double(max(1, a.width * a.height))]
}
/// What the accessibility system itself reports at a screen point, as VoiceOver's mouse tracking asks.
func hit(x: Double, y: Double) -> [String: Any] {
    var element: AXUIElement?
    guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(x), Float(y), &element) == .success, let element else { return [:] }
    return ["id": text(element, kAXIdentifierAttribute) ?? "", "label": text(element, kAXDescriptionAttribute) ?? ""]
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { fail("usage: host|modes|setmode|windows|tree|press|move|click|rightclick|down|held|up|key|stats|diff|hit") }
switch (command, arguments.count) {
case ("host", 1): emit(host())
case ("windows", 2): emit(windows(pid: Int32(number(arguments[1]))))
case ("tree", 2): emit(tree(pid: Int32(number(arguments[1]))))
case ("modes", 1): emit(modes())
case ("setmode", 3): emit(["set": setMode(width: Int(number(arguments[1])), height: Int(number(arguments[2])))])
case ("press", 4): emit(["pressed": press(pid: Int32(number(arguments[1])), by: arguments[2], value: arguments[3])])
case ("stats", 2): emit(stats(path: arguments[1]))
case ("diff", 3): emit(difference(arguments[1], arguments[2]))
case ("hit", 3): emit(hit(x: number(arguments[1]), y: number(arguments[2])))
case ("key", 2):
    guard let code = ["escape": CGKeyCode(53), "return": CGKeyCode(36), "space": CGKeyCode(49)][arguments[1]] else { fail("unknown key") }
    key(code)
    emit(["key": arguments[1]])
case ("move", 3), ("move", 4):
    let target = CGPoint(x: number(arguments[1]), y: number(arguments[2]))
    glide(from: cursor(), to: target, seconds: arguments.count == 4 ? number(arguments[3]) : 0.3, type: .mouseMoved)
    emit(["at": [Double(cursor().x), Double(cursor().y)]])
case ("click", 3), ("rightclick", 3):
    let target = CGPoint(x: number(arguments[1]), y: number(arguments[2]))
    let right = command == "rightclick"
    glide(from: cursor(), to: target, seconds: 0.25, type: .mouseMoved)
    usleep(120_000)
    post(right ? .rightMouseDown : .leftMouseDown, target, right ? .right : .left)
    usleep(60_000)
    post(right ? .rightMouseUp : .leftMouseUp, target, right ? .right : .left)
    emit(["clicked": [Double(target.x), Double(target.y)]])
// A held drag is three calls so the runner can photograph the carried state in between.
case ("down", 3):
    let start = CGPoint(x: number(arguments[1]), y: number(arguments[2]))
    glide(from: cursor(), to: start, seconds: 0.25, type: .mouseMoved)
    usleep(150_000)
    post(.leftMouseDown, start)
    usleep(150_000)
    emit(["down": [Double(start.x), Double(start.y)]])
case ("held", 4):
    let end = CGPoint(x: number(arguments[1]), y: number(arguments[2]))
    glide(from: cursor(), to: end, seconds: number(arguments[3]), type: .leftMouseDragged)
    emit(["held": [Double(end.x), Double(end.y)]])
case ("up", 1):
    post(.leftMouseUp, cursor())
    emit(["up": [Double(cursor().x), Double(cursor().y)]])
default: fail("bad command")
}
