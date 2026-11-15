// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// Settings → Diagnostics → Export diagnostics…: the bundle holds the two logs (with rotated copies), ModelPlan's
/// own recent crash reports, the engine's reader report and the versions, and no known secret survives into it.
final class DiagnosticsBundleTests: XCTestCase {
    /// One plain-words canary planted in every input the bundle accepts (macrev2-963-1): no key, no token shape,
    /// nothing a pattern could catch. Only the per-file content policy can keep it out.
    static let canary = "synthetic private words"
    private let secrets = [DiagnosticsBundleTests.canary,
                           "sk-ant-api03-SYNTHETICsecretvalue0001", "synthetic-bearer-value-0002", "jane.synthetic@example.com",
                           "synthetic-person", "ghp_SYNTHETICgithubtoken000000000003", "synthetic-cookie-value-0004",
                           "c3ludGhldGljOnNhbXBsZQ", "synthetic-account-123", "synthetic reply words",
                           "synthetic-array-one", "synthetic-nested-id", "synthetic-deep-name", "synthetic-pretty-line"]

    private func folder(_ name: String = "diagnostics-bundle") throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(name + "-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private func write(_ text: String, _ url: URL, age: TimeInterval = 0) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-age)], ofItemAtPath: url.path)
    }
    private func script(_ body: String) throws -> URL {
        let url = try folder("diagnostics-helper").appendingPathComponent("modelplan")
        try ("#!/bin/sh\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func inputs(helper: URL?, summary: String = "app=1.2.3\ncli=0.5.61\nmacOS=15.1\nreaders=codex\nerrors=") throws -> DiagnosticsBundleInputs {
        let canary = Self.canary
        let logs = try folder("diagnostics-logs"), reports = try folder("diagnostics-reports")
        // ModelPlan.log and a rotated copy: real events, plus free text in the event grammar, a malformed line,
        // an unknown category and a key leak.
        try write("2026-11-14T20:12:59.882-08:00 error [cockpit] page-failure failure=appearanceWaitTimeout ageMs=108982\n"
                  + "2026-11-14T20:12:59.900-08:00 notice [engine] connection lost; restart attempt=2 delayMs=2000 client=1a2b3c4d\n"
                  + "2026-11-14T20:13:00.001-08:00 notice [lifecycle] leaked Authorization: Bearer synthetic-bearer-value-0002\n"
                  + "2026-11-14T20:13:00.002-08:00 info [readers] reader tool=codex state=failed cause=reader_error:auth_expired\n"
                  + "2026-11-14T20:13:00.003-08:00 info [settings] \(canary)\n"
                  + "2026-11-14T20:13:00.004-08:00 info [user-text] reader \(canary)\n"
                  + "\(canary) without a timestamp\n",
                  logs.appendingPathComponent("ModelPlan.log"))
        try write("2026-11-13T09:00:00.000-08:00 info [engine] connection ready client=1a2b3c4d\n"
                  + "2026-11-13T09:00:01.000-08:00 notice [consent] grant requested allow=[codex.local_history] deny=[] \(canary)\n",
                  logs.appendingPathComponent("ModelPlan.1.log"))
        // engine.log: a crash, a panic and fatal error with free text, an old-build record that starts with "--- ",
        // and arbitrary stderr records.
        try write("2026-11-14T20:14:13.399-08:00 pid=4242 --- started read-only\n"
                  + "2026-11-14T20:14:13.400-08:00 pid=4242 panic: synthetic failure token=sk-ant-api03-SYNTHETICsecretvalue0001\n"
                  + "2026-11-14T20:14:13.400-08:00 pid=4242 panic: \(canary)\n"
                  + "2026-11-14T20:14:13.400-08:00 pid=4242 fatal error: \(canary)\n"
                  + "2026-11-14T20:14:13.400-08:00 pid=4242 --- \(canary)\n"
                  + "2026-11-14T20:14:13.400-08:00 pid=4242 --- exited reason=exit status=2 \(canary)\n"
                  + "2026-11-14T20:14:13.400-08:00 pid=4242 \(canary)\n"
                  + "2026-11-14T20:14:13.400-08:00 pid=4242 goroutine 1 [running]:\n"
                  + "2026-11-14T20:14:13.400-08:00 pid=4242 main.main()\n"
                  + "2026-11-14T20:14:13.401-08:00 pid=4242 \t/Users/synthetic-person/src/main.go:5 +0x1d\n"
                  + "2026-11-14T20:14:13.402-08:00 pid=4242 {'reply': 'synthetic reply words'}\n"
                  + "\(canary) without a pid\n"
                  + "2026-11-14T20:14:13.402-08:00 pid=4242 --- exited reason=exit status=2\n",
                  logs.appendingPathComponent("engine.log"))
        // A real-shaped .ips report (header line + body) with private text in fields outside the allowlist, in an
        // allowed field with a disallowed value, and in nested, array and multi-line values.
        let header = #"{"app_name":"ModelPlanCommunity","app_version":"0.5.61","bundleID":"org.modelplan.community","os_version":"macOS 15.1 (24B83)","timestamp":"2026-11-14 20:14:13.00 -0800","incident_id":"4C4C4455-5555-3144-A1B2-0123456789AB","name":"ModelPlanCommunity","email":"jane.synthetic@example.com","note":"synthetic private words"}"#
        let body = """
        {
          "procName" : "ModelPlanCommunity",
          "procPath" : "/Users/synthetic-person/Applications/ModelPlan.app/Contents/MacOS/ModelPlanCommunity",
          "exception" : {"type" : "EXC_CRASH", "signal" : "SIGABRT", "codes" : "0x0000000000000000, 0x0000000000000000", "message" : "\(canary)"},
          "asi" : {"libswiftCore.dylib" : ["Fatal error: \(canary)"]},
          "prompt" : ["synthetic-array-one", "x"],
          "account" : {"id" : "synthetic-account-123", "org" : {"name" : "synthetic-deep-name"}},
          "messages" : [ {"content" : "synthetic-pretty-line"} ],
          "faultingThread" : 0,
          "threads" : [ {"id" : 1, "triggered" : true, "queue" : "com.apple.main-thread", "frames" : [
            {"imageOffset" : 4096, "symbol" : "closure #1 in ModelPlanCommunity.Cockpit.open()", "imageIndex" : 0},
            {"imageOffset" : 8192, "symbol" : "\(canary)", "imageIndex" : 0},
            {"imageOffset" : 9000, "symbol" : "main", "sourceFile" : "/Users/synthetic-person/src/main.swift", "sourceLine" : 12}
          ]} ],
          "usedImages" : [ {"name" : "ModelPlanCommunity", "uuid" : "4c4c4455-5555-3144-a1b2-0123456789ab", "base" : 4294967296, "arch" : "arm64", "path" : "/Users/synthetic-person/x"} ]
        }
        """
        try write(header + "\n" + body, reports.appendingPathComponent("ModelPlanCommunity-2026-11-14-201413.ips"), age: 3600)
        // An .ips that is not JSON: free text, a cookie, quoted credentials.
        try write("Process: modelplan [4242]\nCookie: session=synthetic-cookie-value-0004\n"
                  + #"{"Authorization": "Basic c3ludGhldGljOnNhbXBsZQ=="}"# + "\npanic: \(canary)\n",
                  reports.appendingPathComponent("modelplan-2026-11-14-201413.ips"), age: 7200)
        try write("panic: \(canary)", reports.appendingPathComponent("modelplan-2026-11-14-201500.crash"), age: 60)
        try write("someone else's crash", reports.appendingPathComponent("OtherApp-2026-11-14-201413.ips"))
        try write("too old", reports.appendingPathComponent("ModelPlanCommunity-2026-10-01-101010.ips"), age: 40 * 24 * 3600)
        try write("not a crash report", reports.appendingPathComponent("modelplan-notes.txt"))
        let files = ["ModelPlan.log", "ModelPlan.1.log", "engine.log"].map { logs.appendingPathComponent($0) }
        var value = DiagnosticsBundleInputs(logFiles: files, crashReports: reports, helper: helper,
            helperEnvironment: ["HOME": logs.path, "TMPDIR": logs.path, "PATH": "/usr/bin:/bin"], summary: summary)
        value.doctorTimeout = 5
        return value
    }
    private func doctorHelper() throws -> URL {
        try script("""
        if [ "$1 $2 $3" = "doctor readers --json" ]; then
          printf '{"readers":[{"provider":"codex","state":"fresh","consent":"allowed","cause":"synthetic private words","email":"synthetic-account-123"}],"message":"synthetic private words","debug":"token=ghp_SYNTHETICgithubtoken000000000003"}\\n'
          exit 0
        fi
        exit 64
        """)
    }
    private func allText(_ root: URL) throws -> String {
        let walker = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        return walker.compactMap { $0 as? URL }.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
    }

    func testStagedBundleHoldsTheExpectedFilesAndNoSecrets() throws {
        let staged = try folder("diagnostics-staged").appendingPathComponent("ModelPlan-diagnostics-test")
        let files = try DiagnosticsBundle.stage(try inputs(helper: try doctorHelper(),
            summary: "app=1.2.3\ncli=0.5.61\nmacOS=15.1\nreaders=\(Self.canary)\nerrors=\n\(Self.canary)"), into: staged)
        XCTAssertEqual(files, [
            "README.txt",
            "crash-reports/ModelPlanCommunity-2026-11-14-201413.ips",
            "crash-reports/modelplan-2026-11-14-201413.ips",
            "doctor-readers.json",
            "logs/ModelPlan.1.log",
            "logs/ModelPlan.log",
            "logs/engine.log",
            "versions.txt",
        ], "only .ips reports are taken")
        // Every file, one by one: no canary, no secret.
        for file in files {
            let text = try String(contentsOf: staged.appendingPathComponent(file), encoding: .utf8)
            for secret in secrets { XCTAssertFalse(text.contains(secret), "\(secret) reached \(file):\n\(text)") }
        }
        func read(_ file: String) throws -> String { try String(contentsOf: staged.appendingPathComponent(file), encoding: .utf8) }
        // ModelPlan.log keeps the real events and loses free words, malformed lines and unknown categories.
        let app = try read("logs/ModelPlan.log")
        XCTAssertTrue(app.contains("error [cockpit] page-failure failure=appearanceWaitTimeout ageMs=108982"), app)
        XCTAssertTrue(app.contains("notice [engine] connection lost; restart attempt=2 delayMs=2000 client=1a2b3c4d"), app)
        XCTAssertTrue(app.contains("info [readers] reader tool=codex state=failed cause=reader_error:auth_expired"), app)
        XCTAssertTrue(app.contains("info [settings] · · ·"), app)
        XCTAssertEqual(app.components(separatedBy: "[line omitted: ").count - 1, 2, app)
        XCTAssertTrue(try read("logs/ModelPlan.1.log").contains("grant requested allow=[codex.local_history] deny=[] · · ·"))
        // engine.log keeps exact app events and crash structure only; a "--- " record that is not an app event is projected.
        let engine = try read("logs/engine.log")
        for kept in ["pid=4242 --- started read-only", "pid=4242 panic: <message redacted, 61 bytes>",
                     "pid=4242 panic: <message redacted, 23 bytes>", "pid=4242 fatal error: <message redacted, 23 bytes>",
                     "pid=4242 goroutine 1 [running]:", "pid=4242 main.main()", "pid=4242 \t/Users/~/src/main.go:5 +0x1d",
                     "pid=4242 --- exited reason=exit status=2\n"] {
            XCTAssertTrue(engine.contains(kept), "\(kept) missing:\n\(engine)")
        }
        XCTAssertFalse(engine.contains("synthetic failure"))
        // The .ips report keeps identity, exception, frames and images; everything outside the allowlist is gone.
        let report = try read("crash-reports/ModelPlanCommunity-2026-11-14-201413.ips")
        for kept in ["\"app_name\":\"ModelPlanCommunity\"", "\"os_version\":\"macOS 15.1 (24B83)\"", "EXC_CRASH", "SIGABRT",
                     "closure #1 in ModelPlanCommunity.Cockpit.open()", "4c4c4455-5555-3144-a1b2-0123456789ab", "/Users/~/src/main.swift"] {
            XCTAssertTrue(report.contains(kept) || report.contains(kept.replacingOccurrences(of: "\":\"", with: "\" : \"")), "\(kept) missing:\n\(report)")
        }
        for gone in ["procPath", "asi", "prompt", "account", "messages", "\"email\"", "\"note\"", "\"path\""] {
            XCTAssertFalse(report.contains(gone), "\(gone) kept:\n\(report)")
        }
        XCTAssertTrue(report.contains("<omitted>"), "the canary frame symbol is refused, not kept")
        XCTAssertTrue(try read("crash-reports/modelplan-2026-11-14-201413.ips").hasPrefix("[report omitted: not an .ips crash report"))
        let doctor = try read("doctor-readers.json").replacingOccurrences(of: " : ", with: ":")
        XCTAssertTrue(doctor.contains("\"provider\":\"codex\""), doctor)
        XCTAssertTrue(doctor.contains("\"state\":\"fresh\""), doctor)
        XCTAssertTrue(doctor.contains("\"cause\":\"<omitted>\""), doctor)
        XCTAssertFalse(doctor.contains("message") || doctor.contains("debug") || doctor.contains("email"), doctor)
        let versions = try read("versions.txt")
        for line in ["app=1.2.3", "cli=0.5.61", "macOS=15.1", "readers=<omitted>", "arch="] { XCTAssertTrue(versions.contains(line), line) }
        let readme = try read("README.txt")
        XCTAssertTrue(readme.contains("Never included"))
        XCTAssertTrue(readme.contains("Nothing was uploaded"))
    }

    /// glm-963-2: a reply that arrives in several pipe reads is kept whole, not just its first chunk.
    func testDoctorOutputWrittenInChunksIsKeptWhole() throws {
        let chunked = try script("""
        printf '{"readers":['
        sleep 0.3
        printf '{"provider":"codex","state":"fresh"},'
        sleep 0.3
        printf '{"provider":"claude","state":"stale"}],"message":"ok"}\\n'
        """)
        let staged = try folder("diagnostics-chunked").appendingPathComponent("bundle")
        var value = try inputs(helper: chunked); value.doctorTimeout = 10
        let files = try DiagnosticsBundle.stage(value, into: staged)
        XCTAssertTrue(files.contains("doctor-readers.json"))
        let data = try Data(contentsOf: staged.appendingPathComponent("doctor-readers.json"))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let readers = try XCTUnwrap(object["readers"] as? [[String: Any]])
        XCTAssertEqual(readers.compactMap { $0["provider"] as? String }, ["codex", "claude"])
    }

    func testAnUnresponsiveOrMissingEngineIsReportedNotFatal() throws {
        let slow = try script("exec sleep 30")
        let staged = try folder("diagnostics-slow").appendingPathComponent("bundle")
        var value = try inputs(helper: slow); value.doctorTimeout = 0.5
        let files = try DiagnosticsBundle.stage(value, into: staged)
        XCTAssertTrue(files.contains("doctor-readers.txt"))
        XCTAssertFalse(files.contains("doctor-readers.json"))
        XCTAssertEqual(try String(contentsOf: staged.appendingPathComponent("doctor-readers.txt"), encoding: .utf8), "doctor readers unavailable: timeout\n")

        let none = try folder("diagnostics-none").appendingPathComponent("bundle")
        let withoutHelper = try DiagnosticsBundle.stage(try inputs(helper: nil), into: none)
        XCTAssertFalse(withoutHelper.contains { $0.hasPrefix("doctor-readers") })
    }

    func testExportWritesOneZipWithTheStagedFilesUnderOneFolder() throws {
        let destination = try folder("diagnostics-out").appendingPathComponent("ModelPlan-diagnostics-20261114-201500.zip")
        let files = try DiagnosticsBundle.export(try inputs(helper: try doctorHelper(), summary: "app=1.2.3\nreaders=\(Self.canary)"), to: destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.deletingLastPathComponent()
            .appendingPathComponent("." + destination.lastPathComponent + ".partial").path))
        let list = Process(), pipe = Pipe()
        list.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo"); list.arguments = ["-1", destination.path]
        list.standardOutput = pipe; list.standardError = FileHandle.nullDevice
        try list.run()
        let names = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        list.waitUntilExit()
        XCTAssertEqual(list.terminationStatus, 0)
        let entries = Set(names.split(separator: "\n").map(String.init).filter { !$0.hasSuffix("/") && !$0.hasPrefix("__MACOSX") })
        XCTAssertEqual(entries, Set(files.map { "ModelPlan-diagnostics-20261114-201500/" + $0 }))
        // What the user would send: unpack the archive itself and look for every canary.
        let unpacked = try folder("diagnostics-unpacked")
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto"); unzip.arguments = ["-x", "-k", destination.path, unpacked.path]
        try unzip.run(); unzip.waitUntilExit()
        XCTAssertEqual(unzip.terminationStatus, 0)
        let text = try allText(unpacked)
        XCTAssertTrue(text.contains("EXC_CRASH"), "the crash report itself is kept")
        for secret in secrets { XCTAssertFalse(text.contains(secret), "\(secret) reached the archive") }
    }

    /// macrev2-963-2: a helper that closes stdout and stays alive is stopped at the deadline; export goes on.
    func testDoctorThatLingersAfterClosingStdoutIsStoppedAtTheDeadline() throws {
        let lingering = try script("""
        printf '{"readers":[],"message":"ok"}\\n'
        exec 1>&-
        exec sleep 30
        """)
        let staged = try folder("diagnostics-linger").appendingPathComponent("bundle")
        var value = try inputs(helper: lingering); value.doctorTimeout = 1
        let started = Date()
        let files = try DiagnosticsBundle.stage(value, into: staged)
        XCTAssertLessThan(Date().timeIntervalSince(started), 8, "export waited on a lingering helper")
        XCTAssertTrue(files.contains("doctor-readers.json"))
    }

    func testOnlyModelPlanCrashReportsAreSelected() {
        for name in ["ModelPlan-2026-11-14-101010.ips", "ModelPlanCommunity-2026-11-14-101010.ips", "modelplan-2026-11-14-101010.ips"] {
            XCTAssertTrue(DiagnosticsBundle.isOurCrashReport(URL(fileURLWithPath: "/tmp/" + name)), name)
        }
        for name in ["Codex-2026-11-14.ips", "modelplan-notes.txt", "ZCode-modelplan.ips", "modelplan_2026.crash", "ModelPlan-x.diag"] {
            XCTAssertFalse(DiagnosticsBundle.isOurCrashReport(URL(fileURLWithPath: "/tmp/" + name)), name)
        }
    }

    func testDisclosureNamesWhatIsAndIsNotIncluded() {
        for language in SettingsLanguage.allCases {
            let text = DiagnosticsBundle.disclosure.value(language)
            XCTAssertTrue(text.contains("macOS"))
            XCTAssertTrue(text.contains("API"))
        }
        XCTAssertTrue(DiagnosticsBundle.disclosure.english.contains("Nothing is uploaded"))
        XCTAssertTrue(DiagnosticsBundle.disclosure.chinese.contains("不会上传"))
        XCTAssertEqual(DiagnosticsBundle.title.chinese, "导出诊断包")
    }
}
