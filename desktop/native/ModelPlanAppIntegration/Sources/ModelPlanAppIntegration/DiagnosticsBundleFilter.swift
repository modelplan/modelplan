// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient

/// The content policy for every file in the diagnostics bundle. Each input is reduced to a closed grammar before
/// the redactor runs, so free text (a prompt, a reply, an account value, a panic message) cannot ride along in a
/// form no pattern anticipates:
/// - ModelPlan.log: `<timestamp> <level> [<category>] <event>` lines only; inside the event, `key=value` tokens with
///   bounded values, numbers, bracket markers, and words from the app's own event vocabulary. Any other word
///   becomes `·`; any other line becomes its length.
/// - engine.log: the exact `--- started…` / `--- exited reason=… status=N` app events; every stderr record goes
///   through `EngineStderrProjection` (crash structure only).
/// - crash reports: `.ips` JSON only, projected to an allowlist of fields (identity and version, exception type and
///   codes, threads with frames, binary images). Application-specific text, paths and everything else are dropped;
///   a report that is not `.ips` JSON becomes its length.
/// - doctor-readers.json: the reader fields of `modelplan doctor readers --json` with token values only.
/// - versions.txt: known keys with version-shaped values only.
public enum DiagnosticsBundleFilter {
    // MARK: ModelPlan.log

    static let categories: Set<String> = ["cockpit", "lifecycle", "engine", "readers", "dock", "consent", "settings"]
    /// Every bare word the app's own events use (DiagnosticsLog, CockpitFailureLog, CockpitTimingLog, Dock).
    /// A word outside it is shown as `·`: a new event word costs readability, never privacy.
    static let vocabulary: Set<String> = [
        "accepted", "after", "allowed", "appearance", "at", "attempt", "body", "build", "cancelled", "carry", "cause",
        "change", "clear", "close", "closed", "cockpit", "cold", "connection", "consent", "delivery-resync",
        "delivery-skipped", "diagnostics", "disclosure", "display", "display-non-finite", "dock", "drag", "edge", "end",
        "ended", "engine", "export", "exited", "extended", "failed", "failure", "feature", "finished", "gone", "grant",
        "hidden-visibility-late", "idle", "launch", "lifecycle", "lost", "notice-shown", "offline", "open",
        "open-retry", "page-failure", "page-reject", "page-resync", "panel", "presentation", "prewarm",
        "prewarm-unavailable", "read-only", "reader", "readers", "ready", "rebuild", "released",
        "rendered", "requested", "restart", "resume", "retry", "save", "settings", "shown", "start", "started",
        "starting", "stopped", "suspend", "tick", "timeout", "timing", "unavailable", "views", "wait", "warm-paint", "was",
        "---",
    ]
    private static func regex(_ pattern: String) -> NSRegularExpression? { try? NSRegularExpression(pattern: pattern) }
    private static func full(_ expression: NSRegularExpression?, _ text: String) -> NSTextCheckingResult? {
        expression?.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }
    private static let appLine = regex(#"^(\d{4}-\d{2}-\d{2}T[0-9:.]+(?:Z|[+-]\d{2}:\d{2})) (debug|info|notice|warning|error|fault) \[([a-z-]{1,20})\] (.*)$"#)
    private static let keyValue = regex(#"^[A-Za-z][A-Za-z0-9_.-]{0,40}=[A-Za-z0-9_.:,/+=\-\[\]()<>#@~]{0,200}$"#)
    private static let number = regex(#"^-?[0-9][0-9.]{0,20}$"#)
    private static let marker = regex(#"^\[?(?:redacted|email|cut|client=[a-z0-9]{1,16})\]?[;,]?$"#)

    public static func appLog(_ text: String) -> String {
        lines(text) { line in
            guard let match = full(appLine, line) else { return "[line omitted: \(line.utf8.count) bytes]" }
            let ns = line as NSString
            let category = ns.substring(with: match.range(at: 3))
            guard categories.contains(category) else { return "[line omitted: \(line.utf8.count) bytes]" }
            let event = ns.substring(with: match.range(at: 4)).split(separator: " ", omittingEmptySubsequences: false).map { raw -> String in
                let token = String(raw)
                if token.isEmpty || full(keyValue, token) != nil || full(number, token) != nil || full(marker, token) != nil { return token }
                let word = token.trimmingCharacters(in: CharacterSet(charactersIn: ";,:"))
                return vocabulary.contains(word) ? token : "·"
            }.joined(separator: " ")
            return [ns.substring(with: match.range(at: 1)), ns.substring(with: match.range(at: 2)), "[" + category + "]", event].joined(separator: " ")
        }
    }

    // MARK: engine.log

    private static let engineRecord = regex(#"^(\S+ pid=-?\d+ )(.*)$"#)
    private static let engineEvent = regex(#"^--- (?:started(?: offline)?(?: read-only)?|exited reason=(?:exit|signal) status=-?\d{1,5})$"#)

    public static func engineLog(_ text: String) -> String {
        lines(text) { line in
            guard let match = full(engineRecord, line) else { return "[line omitted: \(line.utf8.count) bytes]" }
            let ns = line as NSString
            let head = ns.substring(with: match.range(at: 1)), payload = ns.substring(with: match.range(at: 2))
            guard full(engineEvent, payload) == nil else { return line }
            return head + EngineStderrProjection.project(payload)
        }
    }

    // MARK: crash reports

    indirect enum Shape {
        case value(Rule), object([String: Shape]), array(Shape)
    }
    enum Rule {
        /// No spaces: identifiers, versions, uuids, hex, paths.
        case token
        /// A frame's function name. It may contain spaces ("closure #1 in Foo.bar()") only together with code
        /// punctuation (`.`, `(`, `<`, `#`, `$`, `_`, `:`), so plain words are refused.
        case symbol
        /// A fixed-shape string such as an OS version or timestamp.
        case pattern(String)
        var expression: NSRegularExpression? {
            switch self {
            case .token: return DiagnosticsBundleFilter.tokenRule
            case .symbol: return DiagnosticsBundleFilter.symbolRule
            case .pattern(let value): return DiagnosticsBundleFilter.regex(value)
            }
        }
    }
    static let tokenRule = regex(#"^[A-Za-z0-9_.:+\-/@]{0,200}$"#)
    static let symbolRule = regex(#"^(?=[^ ]*$|.*[.(<#$_:])[A-Za-z0-9_.:$<>()\[\]*&,/+@#~ '?-]{1,400}$"#)
    static let timestamp = Rule.pattern(#"^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]{5,15}(?: [+-][0-9]{4})?$"#)
    static let ipsHeader: Shape = .object([
        "app_name": .value(.token), "app_version": .value(.token), "build_version": .value(.token),
        "bundleID": .value(.token), "name": .value(.token), "incident_id": .value(.token), "slice_uuid": .value(.token),
        "bug_type": .value(.token), "platform": .value(.token), "timestamp": .value(timestamp),
        "os_version": .value(.pattern(#"^(?:macOS|Mac OS X) [0-9.]{1,12} \([0-9A-Za-z]{1,12}\)$"#)),
    ])
    static let ipsBody: Shape = .object([
        "procName": .value(.token), "parentProc": .value(.token), "cpuType": .value(.token), "captureTime": .value(timestamp),
        "uptime": .value(.token), "faultingThread": .value(.token),
        "osVersion": .object(["train": .value(.pattern(#"^macOS [0-9.]{1,12}$"#)), "build": .value(.token), "releaseType": .value(.token)]),
        "bundleInfo": .object(["CFBundleShortVersionString": .value(.token), "CFBundleVersion": .value(.token), "CFBundleIdentifier": .value(.token)]),
        "exception": .object(["type": .value(.token), "signal": .value(.token), "codes": .value(.pattern(#"^[0-9a-fx, ]{0,120}$"#))]),
        "termination": .object(["code": .value(.token), "namespace": .value(.token), "flags": .value(.token)]),
        "threads": .array(.object([
            "id": .value(.token), "triggered": .value(.token), "queue": .value(.token),
            "frames": .array(.object(["imageOffset": .value(.token), "symbol": .value(.symbol), "symbolLocation": .value(.token),
                                      "imageIndex": .value(.token), "sourceLine": .value(.token), "sourceFile": .value(.token),
                                      "inline": .value(.token)])),
        ])),
        "usedImages": .array(.object(["name": .value(.token), "uuid": .value(.token), "base": .value(.token), "size": .value(.token),
                                      "arch": .value(.token), "CFBundleShortVersionString": .value(.token), "CFBundleIdentifier": .value(.token)])),
    ])

    /// Keeps a value only where `shape` allows it; a disallowed string becomes "<omitted>", unknown keys are dropped.
    static func project(_ value: Any, _ shape: Shape) -> Any? {
        switch shape {
        case .value(let rule):
            if let text = value as? String {
                return full(rule.expression, text) != nil ? DiagnosticsRedactor.redact(text) : "<omitted>"
            }
            if let number = value as? NSNumber { return number }
            if let list = value as? [Any] { return list.prefix(64).compactMap { project($0, shape) } }
            return nil
        case .object(let fields):
            guard let dictionary = value as? [String: Any] else { return nil }
            var out: [String: Any] = [:]
            for (key, field) in fields { if let item = dictionary[key], let kept = project(item, field) { out[key] = kept } }
            return out
        case .array(let element):
            guard let list = value as? [Any] else { return nil }
            return list.prefix(4096).compactMap { project($0, element) }
        }
    }
    private static func json(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted]) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
    private static func parse(_ text: Substring) -> Any? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))
    }

    /// An `.ips` report is a one-line JSON header, then a JSON body. Anything else is replaced by its length.
    public static func crashReport(_ text: String) -> String {
        let omitted = "[report omitted: not an .ips crash report, \(text.utf8.count) bytes]\n"
        let parts = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard let first = parts.first, let header = parse(first), let headerOut = project(header, ipsHeader).flatMap(json) else { return omitted }
        guard parts.count > 1, !parts[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return headerOut + "\n" }
        guard let body = parse(parts[1]), let bodyOut = project(body, ipsBody).flatMap(json) else { return omitted }
        return headerOut + "\n" + bodyOut + "\n"
    }

    // MARK: doctor-readers.json

    static let doctorShape: Shape = .object([
        "consentStore": .value(.token),
        "readers": .array(.object([
            "provider": .value(.token), "detected": .value(.token), "consent": .value(.token), "admitted": .value(.token),
            "state": .value(.token), "windows": .value(.token), "last": .value(.token), "beta": .value(.token), "cause": .value(.token),
            "failures": .array(.object(["code": .value(.token), "at": .value(.token), "streakSeconds": .value(.token)])),
        ])),
    ])
    /// The reader fields only; the CLI's human message and anything not in the schema are dropped.
    public static func doctor(_ text: String) -> String? {
        guard let object = parse(Substring(text)), let kept = project(object, doctorShape).flatMap(json) else { return nil }
        return kept + "\n"
    }

    // MARK: versions.txt

    static let versionRules: [String: String] = [
        "generated": #"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z$"#,
        "appBundle": #"^(?:unknown|[0-9][0-9A-Za-z.+-]{0,30}(?: [0-9][0-9A-Za-z.+-]{0,30})?)$"#,
        "app": #"^[0-9A-Za-z.+-]{1,40}$"#, "cli": #"^[0-9A-Za-z.+-]{1,40}$"#, "macOS": #"^[0-9A-Za-z.+-]{1,40}$"#,
        "readers": #"^[A-Za-z0-9_.,:-]{0,400}$"#, "errors": #"^[A-Za-z0-9_.,:-]{0,400}$"#,
        "macOSBuild": #"^Version [0-9.]{1,12} \(Build [0-9A-Za-z]{1,12}\)$"#, "arch": #"^(?:arm64|x86_64)$"#,
    ]
    public static func versions(_ text: String) -> String {
        lines(text) { line in
            guard let equals = line.firstIndex(of: "=") else { return line.isEmpty ? "" : "[line omitted: \(line.utf8.count) bytes]" }
            let key = String(line[..<equals]), value = String(line[line.index(after: equals)...])
            guard let rule = versionRules[key] else { return "[line omitted: \(line.utf8.count) bytes]" }
            return full(regex(rule), value) != nil ? line : key + "=<omitted>"
        }
    }

    private static func lines(_ text: String, _ body: (String) -> String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { $0.isEmpty ? "" : body(String($0)) }.joined(separator: "\n")
    }
}
