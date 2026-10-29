// SPDX-License-Identifier: MIT
// Read-only, PID-scoped AX/window evidence. No input events, prompts or TCC writes.
import AppKit
import ApplicationServices
import ScreenCaptureKit
import ImageIO
import UniformTypeIdentifiers

@MainActor enum Evidence {
    static var nodes = 0
    static var visited = Set<CFHashCode>()
    static var truncated = false
    static var home = ""
    static var appPath = ""
    static var treeDeadline = 0.0

    static func write(_ value: [String: Any], _ url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted])
        try data.write(to: url, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    static func owned(_ pid: pid_t, _ app: URL) -> Bool {
        guard let running = NSRunningApplication(processIdentifier: pid), !running.isTerminated,
              let bundle = running.bundleURL else { return false }
        return bundle.standardizedFileURL == app.standardizedFileURL
    }
    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success ? result : nil
    }
    static func clean(_ text: String) -> String {
        String(text.replacingOccurrences(of: home, with: "$SYNTHETIC_HOME")
            .replacingOccurrences(of: appPath, with: "$APP").prefix(512))
    }
    static func node(_ element: AXUIElement, pid: pid_t, depth: Int) -> [String: Any]? {
        if nodes >= 4096 || depth > 12 || ProcessInfo.processInfo.systemUptime > treeDeadline {
            truncated = true; return nil
        }
        var owner: pid_t = 0
        guard AXUIElementGetPid(element, &owner) == .success, owner == pid else { return nil }
        let identity = CFHash(element)
        guard visited.insert(identity).inserted else { return nil }
        nodes += 1
        _ = AXUIElementSetMessagingTimeout(element, 0.2)
        var result: [String: Any] = ["pid": Int(pid)]
        for attribute in [kAXRoleAttribute, kAXSubroleAttribute, kAXIdentifierAttribute,
                          kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
            let raw = value(element, attribute)
            if let string = raw as? String {
                result[attribute] = clean(string)
            } else if let number = raw as? NSNumber {
                result[attribute] = number
            }
        }
        if let raw = value(element, kAXPositionAttribute), CFGetTypeID(raw) == AXValueGetTypeID() {
            var point = CGPoint.zero
            if AXValueGetValue(unsafeBitCast(raw, to: AXValue.self), .cgPoint, &point) {
                result["position"] = ["x": point.x, "y": point.y]
            }
        }
        if let raw = value(element, kAXSizeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() {
            var size = CGSize.zero
            if AXValueGetValue(unsafeBitCast(raw, to: AXValue.self), .cgSize, &size) {
                result["size"] = ["width": size.width, "height": size.height]
            }
        }
        if let children = value(element, kAXChildrenAttribute) as? [AXUIElement] {
            result["children"] = children.prefix(128).compactMap { node($0, pid: pid, depth: depth + 1) }
            if children.count > 128 { truncated = true }
        }
        return result
    }

    static func ax(pid: pid_t, app: URL, output: URL, wait: Double) async throws -> [String: Any] {
        guard AXIsProcessTrusted() else {
            return ["outcome": "unsupported", "reason": "accessibility-permission-missing"]
        }
        let element = AXUIElementCreateApplication(pid)
        _ = AXUIElementSetMessagingTimeout(element, 0.2)
        let deadline = ProcessInfo.processInfo.systemUptime + wait
        while ProcessInfo.processInfo.systemUptime < deadline {
            guard owned(pid, app) else { return ["outcome": "fail", "reason": "owned-app-ended"] }
            if let windows = value(element, kAXWindowsAttribute) as? [AXUIElement], !windows.isEmpty {
                treeDeadline = min(deadline, ProcessInfo.processInfo.systemUptime + 10)
                let tree = windows.prefix(32).compactMap { node($0, pid: pid, depth: 0) }
                guard !tree.isEmpty else { return ["outcome": "fail", "reason": "owned-ax-tree-empty"] }
                try write(["schemaVersion": 1, "pid": Int(pid), "windows": tree,
                           "nodes": nodes, "truncated": truncated], output.appendingPathComponent("ax-tree.json"))
                return ["outcome": "pass", "reason": "owned-windows-observed", "nodes": nodes,
                        "truncated": truncated]
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        return ["outcome": "timeout", "reason": "ax-window-deadline"]
    }

    static func screenshot(pid: pid_t, app: URL, output: URL) async -> [String: Any] {
        guard owned(pid, app) else { return ["outcome": "fail", "reason": "owned-app-ended"] }
        guard CGPreflightScreenCaptureAccess() else {
            return ["outcome": "unsupported", "reason": "screen-capture-permission-missing"]
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            guard let window = content.windows.first(where: {
                $0.owningApplication?.processID == pid && $0.windowLayer == 0 && $0.frame.width > 0 && $0.frame.height > 0
            }), owned(pid, app) else {
                return ["outcome": "unsupported", "reason": "owned-window-not-shareable"]
            }
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            config.width = max(1, min(4096, Int(window.frame.width * 2)))
            config.height = max(1, min(4096, Int(window.frame.height * 2)))
            config.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            guard owned(pid, app) else { return ["outcome": "fail", "reason": "owned-app-ended"] }
            let target = output.appendingPathComponent("window.png")
            guard let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil) else {
                return ["outcome": "fail", "reason": "png-destination-unavailable"]
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { return ["outcome": "fail", "reason": "png-write-failed"] }
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            return ["outcome": "pass", "reason": "owned-window-offscreen-capture", "ownerPID": Int(pid),
                    "windowID": window.windowID, "width": image.width, "height": image.height,
                    "captureMode": "desktopIndependentWindow", "screenComposite": false]
        } catch {
            return ["outcome": "unsupported", "reason": "screen-capture-unavailable"]
        }
    }
}

@main struct MacosAXProbe {
    @MainActor static func main() async {
        let arguments = CommandLine.arguments
        guard arguments.count == 5, let pid = Int32(arguments[1]), pid > 0,
              let seconds = Double(arguments[4]), seconds >= 1, seconds <= 45 else { exit(64) }
        let app = URL(fileURLWithPath: arguments[2], isDirectory: true).standardizedFileURL
        let output = URL(fileURLWithPath: arguments[3], isDirectory: true).standardizedFileURL
        Evidence.home = ProcessInfo.processInfo.environment["HOME"] ?? "/invalid-synthetic-home"
        Evidence.appPath = app.path
        // The launch can still be registering with AppKit; never inspect an unowned PID.
        let deadline = ProcessInfo.processInfo.systemUptime + seconds
        while !Evidence.owned(pid, app), ProcessInfo.processInfo.systemUptime < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        var report: [String: Any] = ["schemaVersion": 1, "pid": Int(pid), "permissionPrompts": false]
        do {
            if Evidence.owned(pid, app) {
                report["ax"] = try await Evidence.ax(pid: pid, app: app, output: output, wait: max(1, deadline-ProcessInfo.processInfo.systemUptime))
                report["screenshot"] = await Evidence.screenshot(pid: pid, app: app, output: output)
            } else {
                report["ax"] = ["outcome": "fail", "reason": "owned-app-unavailable"]
                report["screenshot"] = ["outcome": "unsupported", "reason": "owned-app-unavailable"]
            }
            if let screen = NSScreen.main {
                report["display"] = ["state": "available", "width": Int(screen.frame.width),
                    "height": Int(screen.frame.height), "scale": screen.backingScaleFactor,
                    "theme": NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? "dark" : "light",
                    "locale": "en_US"]
            } else { report["display"] = ["state": "unsupported"] }
            try Evidence.write(report, output.appendingPathComponent("report.json"))
        } catch { fputs("u14-ax-probe: evidence-write-failed\n", stderr); exit(1) }
    }
}
