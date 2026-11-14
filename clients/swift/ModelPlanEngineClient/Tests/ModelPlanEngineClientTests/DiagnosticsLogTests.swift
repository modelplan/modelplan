// SPDX-License-Identifier: MIT
import Foundation
import XCTest
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
@testable import ModelPlanEngineClient

final class DiagnosticsLogTests: XCTestCase {
    private func folder() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("diagnostics-log-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private func text(_ url: URL) -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
    private func waitFor(_ timeout: TimeInterval = 10, _ condition: () -> Bool) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { XCTFail("condition not reached in time"); throw CocoaError(.userCancelled) }
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    // MARK: rotation

    func testRotationKeepsAFixedNumberOfBoundedFilesNewestFirst() throws {
        let file = RotatingLogFile(url: try folder().appendingPathComponent("ModelPlan.log"), maxBytes: 1024, maxFiles: 3)
        func name(_ index: Int) -> String { "line-" + String(String(index + 1000).dropFirst()) + " " }
        for index in 0..<200 { file.append(name(index) + String(repeating: "x", count: 80)) }
        let files = file.existingFiles
        XCTAssertEqual(files.map(\.lastPathComponent), ["ModelPlan.log", "ModelPlan.1.log", "ModelPlan.2.log"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.file(generation: 3).path), "only maxFiles generations are kept")
        for url in files {
            let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
            XCTAssertLessThanOrEqual(size, 1024, url.lastPathComponent)
            XCTAssertGreaterThan(size, 0, url.lastPathComponent)
        }
        XCTAssertTrue(text(files[0]).contains("line-199 "), "the live file has the newest line")
        XCTAssertFalse(files.contains { text($0).contains("line-000 ") }, "the oldest lines rotate away")
        let newestOld = text(files[1]).components(separatedBy: "\n").compactMap { $0.split(separator: " ").first }.last
        let oldestCurrent = text(files[0]).components(separatedBy: "\n").compactMap { $0.split(separator: " ").first }.first
        XCTAssertLessThan(String(try XCTUnwrap(newestOld)), String(try XCTUnwrap(oldestCurrent)), "generation 1 is older than the live file")
    }

    func testAppendingContinuesAnExistingFileAfterRelaunch() throws {
        let url = try folder().appendingPathComponent("engine.log")
        let first = RotatingLogFile(url: url); first.append("before relaunch"); first.flush()
        let second = RotatingLogFile(url: url); second.append("after relaunch"); second.flush()
        XCTAssertEqual(text(url), "before relaunch\nafter relaunch\n")
        #if canImport(Darwin)
        let mode = (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(mode, 0o600, "the log is readable by its owner only")
        #endif
    }

    func testAnOverlongLineIsCut() throws {
        let url = try folder().appendingPathComponent("ModelPlan.log")
        let file = RotatingLogFile(url: url)
        file.append(String(repeating: "y", count: RotatingLogFile.maxLineBytes * 3)); file.flush()
        XCTAssertLessThan(text(url).utf8.count, RotatingLogFile.maxLineBytes + 16)
        XCTAssertTrue(text(url).hasSuffix(" [cut]\n"))
    }

    // MARK: redaction

    /// Known secrets in every shape the app could meet: none survives, and ordinary diagnostic text is untouched.
    func testRedactionRemovesKnownSecrets() {
        // Assembled at run time so no token-shaped literal sits in the source (push protection rejects one).
        let slack = "xo" + "xb-1234567890-SYNTHETICslack"
        let secrets = [
            "sk-ant-api03-SYNTHETICsecretvalue0001", "sk-proj-SYNTHETICopenaikey0002",
            "ghp_SYNTHETICgithubtoken000000000003", slack,
            "AKIASYNTHETIC0000004", "AIzaSyntheticGoogleKey000000000000000005",
            "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJzeW50aGV0aWMifQ.c3ludGhldGljLXNpZ25hdHVyZQ",
            "synthetic-bearer-value-0006", "synthetic-cookie-value-0007", "synthetic-password-0008",
            "SyntheticOpaqueTokenAAAA0000BBBB1111CCCC", "jane.synthetic@example.com", "synthetic-person",
            "synthetic-session-0009", "synthetic-refresh-0010",
        ]
        let inputs = [
            "panic: request failed token=sk-ant-api03-SYNTHETICsecretvalue0001",
            "OPENAI_API_KEY=sk-proj-SYNTHETICopenaikey0002 exported",
            "git said ghp_SYNTHETICgithubtoken000000000003 is invalid",
            "slack " + slack,
            "aws AKIASYNTHETIC0000004 google AIzaSyntheticGoogleKey000000000000000005",
            "jwt eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJzeW50aGV0aWMifQ.c3ludGhldGljLXNpZ25hdHVyZQ",
            "Authorization: Bearer synthetic-bearer-value-0006",
            "Cookie: session=synthetic-cookie-value-0007; theme=dark",
            #"{"password": "synthetic-password-0008", "count": 3}"#,
            "blob SyntheticOpaqueTokenAAAA0000BBBB1111CCCC end",
            "account jane.synthetic@example.com signed in",
            "open /Users/synthetic-person/.codex/auth.json failed",
            "session_id=synthetic-session-0009&refresh_token=synthetic-refresh-0010",
            // glm-963-1: quoted values under credential, account and user-text keys, and unquoted user text.
            #"{"Authorization": "Basic c3ludGhldGljOnNhbXBsZQ=="}"#,
            #"{"account_id":"synthetic-account-123","accountEmail":"synthetic-mail-0011"}"#,
            "prompt: synthetic private words",
            "{'response': 'synthetic response words'}",
            "Authorization: Basic c3ludGhldGljOnNhbXBsZQ== user=synthetic-user-77",
        ]
        let output = inputs.map(DiagnosticsRedactor.redact).joined(separator: "\n")
        for leaked in ["c3ludGhldGljOnNhbXBsZQ", "synthetic-account-123", "synthetic-mail-0011", "synthetic private words",
                       "synthetic response words", "synthetic-user-77"] {
            XCTAssertFalse(output.contains(leaked), "\(leaked) survived redaction:\n\(output)")
        }
        for secret in secrets { XCTAssertFalse(output.contains(secret), "\(secret) survived redaction:\n\(output)") }
        XCTAssertTrue(output.contains("/Users/~/.codex/auth.json"))
        XCTAssertTrue(output.contains(DiagnosticsRedactor.marker))
        let kept = [
            "open page=warm-ready clickMs=1074 tokens=5 rebuilds=0",
            "reader codex state=failed cause=reader_error:auth_expired",
            "binary image 4C4C4455-5555-3144-A1B2-0123456789AB",
            "goroutine 1 [running]: main.main() /src/main.go:5 +0x1d",
            "connection lost; restart attempt=2 delayMs=2000 client=1a2b3c4d",
        ]
        for line in kept { XCTAssertEqual(DiagnosticsRedactor.redact(line), line) }
    }

    func testFileLinesAreRedactedBeforeTheyReachTheDisk() throws {
        let url = try folder().appendingPathComponent("ModelPlan.log")
        let log = DiagnosticsLog()
        log.configure(app: RotatingLogFile(url: url), engine: nil)
        log.record("lifecycle", .notice, "synthetic leak api_key=sk-ant-api03-SYNTHETICsecretvalue0001", systemLog: false)
        log.record("lifecycle", .debug, "debug lines stay out of the file", systemLog: false)
        log.app?.flush()
        let written = text(url)
        XCTAssertFalse(written.contains("SYNTHETICsecretvalue0001"))
        XCTAssertTrue(written.contains("notice [lifecycle] synthetic leak api_key=" + DiagnosticsRedactor.marker))
        XCTAssertFalse(written.contains("debug lines"))
        XCTAssertNotNil(written.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}"#, options: .regularExpression), "each line starts with a timestamp")
    }

    func testSafeIDsAndErrorNames() {
        XCTAssertEqual(DiagnosticsLog.safeID("codex.local_history"), "codex.local_history")
        XCTAssertEqual(DiagnosticsLog.safeID("jane@example.com"), "other")
        XCTAssertEqual(DiagnosticsLog.safeID(String(repeating: "a", count: 65)), "other")
        XCTAssertEqual(DiagnosticsLog.errorName(EngineClientError.interrupted(.connectionLost)), "interrupted")
        XCTAssertEqual(DiagnosticsLog.errorName(EngineClientError.notReady), "notReady")
    }

    // MARK: engine stderr

    func testStderrLinesSplitAndCutLongRuns() {
        var lines = EngineStderrLines(limit: 8)
        XCTAssertEqual(lines.append(Array("one\ntwo".utf8)), ["one"])
        XCTAssertEqual(lines.append(Array("\n0123456789".utf8)), ["two", "01234567"])
        XCTAssertEqual(lines.finish(), "89")
        XCTAssertNil(lines.finish())
    }

    private func fakeHelper(_ body: String) throws -> URL {
        let url = try folder().appendingPathComponent("modelplan")
        try ("#!/bin/sh\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }
    private func run(_ helper: URL, log: RotatingLogFile) throws -> String {
        let home = try folder()
        let configuration = EngineClientConfiguration(executableURL: helper, applicationVersion: "synthetic-diagnostics",
            allowedEnvironment: ["HOME": home.path, "TMPDIR": home.path], engineLog: log)
        let process = try EngineProcess(id: UUID(), configuration: configuration, writeTimeout: 1, frame: { _, _ in }, ended: { _, _ in })
        try waitFor { log.flush(); return text(log.url).contains("--- exited") && !process.process.isRunning }
        // The stderr reader drains after the exit; give it a moment to reach the end of the pipe.
        Thread.sleep(forTimeInterval: 0.3)
        log.flush()
        let finished = expectation(description: "finished")
        Task { _ = await process.finish(); finished.fulfill() }
        wait(for: [finished], timeout: 10)
        return text(log.url)
    }

    /// A Go panic writes its trace to stderr and exits 2. The trace and the exit status survive in engine.log,
    /// with secrets and the user's folder name replaced.
    func testPanickingHelperStderrAndExitStatusAreKept() throws {
        let helper = try fakeHelper("""
        printf 'panic: synthetic failure token=sk-ant-api03-SYNTHETICsecretvalue0001\\n\\ngoroutine 1 [running]:\\nmain.main()\\n\\t/Users/synthetic-person/src/main.go:5 +0x1d\\n' >&2
        exit 2
        """)
        let log = RotatingLogFile(url: try folder().appendingPathComponent("engine.log"))
        let written = try run(helper, log: log)
        XCTAssertTrue(written.contains("panic: synthetic failure token=" + DiagnosticsRedactor.marker), written)
        XCTAssertTrue(written.contains("goroutine 1 [running]:"), written)
        XCTAssertTrue(written.contains("/Users/~/src/main.go:5 +0x1d"), written)
        XCTAssertTrue(written.contains("--- started"), written)
        XCTAssertTrue(written.contains("--- exited reason=exit status=2"), written)
        XCTAssertFalse(written.contains("SYNTHETICsecretvalue0001"))
        XCTAssertFalse(written.contains("synthetic-person"))
    }

    /// glm-963-1: quoted credentials, account identifiers and user-written text in unstructured helper stderr never
    /// reach engine.log, while the panic line around them survives.
    func testHelperStderrWithCredentialsAccountsAndPromptTextIsRedacted() throws {
        let helper = try fakeHelper("""
        printf '%s\\n' '{"Authorization": "Basic c3ludGhldGljOnNhbXBsZQ=="}' '{"account_id":"synthetic-account-123"}' 'prompt: synthetic private words' "{'reply': 'synthetic reply words'}" 'panic: user=synthetic-user-77 message="synthetic chat message"' >&2
        exit 2
        """)
        let log = RotatingLogFile(url: try folder().appendingPathComponent("engine.log"))
        let written = try run(helper, log: log)
        for leaked in ["c3ludGhldGljOnNhbXBsZQ", "synthetic-account-123", "synthetic private words", "synthetic reply words",
                       "synthetic-user-77", "synthetic chat message"] {
            XCTAssertFalse(written.contains(leaked), "\(leaked) reached engine.log:\n\(written)")
        }
        XCTAssertTrue(written.contains(#"{"Authorization": "[redacted]"}"#), written)
        XCTAssertTrue(written.contains(#"{"account_id":"[redacted]"}"#), written)
        XCTAssertTrue(written.contains("prompt: [redacted]"), written)
        XCTAssertTrue(written.contains("panic: user=[redacted]"), written)
        XCTAssertTrue(written.contains("--- exited reason=exit status=2"), written)
    }

    func testHelperKilledBySignalIsRecorded() throws {
        let helper = try fakeHelper("printf 'about to crash\\n' >&2\nkill -TERM $$")
        let log = RotatingLogFile(url: try folder().appendingPathComponent("engine.log"))
        let written = try run(helper, log: log)
        XCTAssertTrue(written.contains("about to crash"), written)
        XCTAssertTrue(written.contains("--- exited reason=signal status=\(SIGTERM)"), written)
    }
}
