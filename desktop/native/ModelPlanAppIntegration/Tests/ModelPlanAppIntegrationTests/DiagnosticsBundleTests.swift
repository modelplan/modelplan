// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// Settings → Diagnostics → Export diagnostics…: the bundle holds the two logs (with rotated copies), ModelPlan's
/// own recent crash reports, the engine's reader report and the versions, and no known secret survives into it.
final class DiagnosticsBundleTests: XCTestCase {
    private let secrets = ["sk-ant-api03-SYNTHETICsecretvalue0001", "synthetic-bearer-value-0002", "jane.synthetic@example.com",
                           "synthetic-person", "ghp_SYNTHETICgithubtoken000000000003", "synthetic-cookie-value-0004"]

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

    private func inputs(helper: URL?) throws -> DiagnosticsBundleInputs {
        let logs = try folder("diagnostics-logs"), reports = try folder("diagnostics-reports")
        try write("2026-11-14T20:12:59.882-08:00 error [cockpit] page-failure failure=appearanceWaitTimeout\n"
                  + "2026-11-14T20:13:00.001-08:00 notice [lifecycle] leaked Authorization: Bearer synthetic-bearer-value-0002\n",
                  logs.appendingPathComponent("ModelPlan.log"))
        try write("2026-11-13T09:00:00.000-08:00 info [engine] connection ready\n", logs.appendingPathComponent("ModelPlan.1.log"))
        try write("2026-11-14T20:14:13.400-08:00 pid=4242 panic: synthetic failure token=sk-ant-api03-SYNTHETICsecretvalue0001\n"
                  + "2026-11-14T20:14:13.401-08:00 pid=4242 \t/Users/synthetic-person/src/main.go:5 +0x1d\n"
                  + "2026-11-14T20:14:13.402-08:00 pid=4242 --- exited reason=exit status=2\n",
                  logs.appendingPathComponent("engine.log"))
        try write(#"{"app_name":"ModelPlanCommunity","userID":501,"email":"jane.synthetic@example.com","path":"/Users/synthetic-person/Applications/ModelPlan.app"}"#,
                  reports.appendingPathComponent("ModelPlanCommunity-2026-11-14-201413.ips"), age: 3600)
        try write("Process: modelplan [4242]\nCookie: session=synthetic-cookie-value-0004\n",
                  reports.appendingPathComponent("modelplan-2026-11-14-201413.ips"), age: 7200)
        try write("someone else's crash", reports.appendingPathComponent("OtherApp-2026-11-14-201413.ips"))
        try write("too old", reports.appendingPathComponent("ModelPlanCommunity-2026-10-01-101010.ips"), age: 40 * 24 * 3600)
        try write("not a crash report", reports.appendingPathComponent("modelplan-notes.txt"))
        let files = ["ModelPlan.log", "ModelPlan.1.log", "engine.log"].map { logs.appendingPathComponent($0) }
        var value = DiagnosticsBundleInputs(logFiles: files, crashReports: reports, helper: helper,
            helperEnvironment: ["HOME": logs.path, "TMPDIR": logs.path, "PATH": "/usr/bin:/bin"],
            summary: "app=1.2.3\ncli=0.5.61\nmacOS=15.1\nreaders=codex\nerrors=")
        value.doctorTimeout = 5
        return value
    }
    private func doctorHelper() throws -> URL {
        try script("""
        if [ "$1 $2 $3" = "doctor readers --json" ]; then
          printf '{"readers":[{"provider":"codex","state":"fresh","consent":"allowed"}],"message":"ok","debug":"token=ghp_SYNTHETICgithubtoken000000000003"}\\n'
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
        let files = try DiagnosticsBundle.stage(try inputs(helper: try doctorHelper()), into: staged)
        XCTAssertEqual(files, [
            "README.txt",
            "crash-reports/ModelPlanCommunity-2026-11-14-201413.ips",
            "crash-reports/modelplan-2026-11-14-201413.ips",
            "doctor-readers.json",
            "logs/ModelPlan.1.log",
            "logs/ModelPlan.log",
            "logs/engine.log",
            "versions.txt",
        ])
        let text = try allText(staged)
        for secret in secrets { XCTAssertFalse(text.contains(secret), "\(secret) reached the bundle") }
        // The diagnostic substance survives redaction.
        XCTAssertTrue(text.contains("page-failure failure=appearanceWaitTimeout"))
        XCTAssertTrue(text.contains("panic: synthetic failure token=" + DiagnosticsRedactor.marker))
        XCTAssertTrue(text.contains("/Users/~/src/main.go:5 +0x1d"))
        XCTAssertTrue(text.contains("--- exited reason=exit status=2"))
        let doctor = try String(contentsOf: staged.appendingPathComponent("doctor-readers.json"), encoding: .utf8)
        XCTAssertTrue(doctor.contains(#""provider":"codex","state":"fresh""#))
        let versions = try String(contentsOf: staged.appendingPathComponent("versions.txt"), encoding: .utf8)
        for line in ["app=1.2.3", "cli=0.5.61", "macOS=15.1", "macOSBuild=", "arch="] { XCTAssertTrue(versions.contains(line), line) }
        let readme = try String(contentsOf: staged.appendingPathComponent("README.txt"), encoding: .utf8)
        XCTAssertTrue(readme.contains("Never included"))
        XCTAssertTrue(readme.contains("Nothing was uploaded"))
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
        let files = try DiagnosticsBundle.export(try inputs(helper: try doctorHelper()), to: destination)
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
    }

    func testOnlyModelPlanCrashReportsAreSelected() {
        for name in ["ModelPlan-2026-11-14-101010.ips", "ModelPlanCommunity-2026-11-14-101010.ips", "modelplan-2026-11-14-101010.ips", "modelplan_2026.crash"] {
            XCTAssertTrue(DiagnosticsBundle.isOurCrashReport(URL(fileURLWithPath: "/tmp/" + name)), name)
        }
        for name in ["Codex-2026-11-14.ips", "modelplan-notes.txt", "ZCode-modelplan.ips"] {
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
