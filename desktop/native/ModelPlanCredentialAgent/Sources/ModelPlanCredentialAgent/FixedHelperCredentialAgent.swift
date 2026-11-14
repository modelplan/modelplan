// SPDX-License-Identifier: MIT
import Foundation
import CryptoKit
import Darwin
import ModelPlanEngineClient
import ModelPlanWire

/// Supplied by packaging, independently of RPC requests. A hash is an artifact pin,
/// not authentication of its caller. Real credential reads require R2.
public struct CredentialHelperPin: Codable, Sendable {
    public let schemaVersion: Int
    public let sha256: String
    public let bytes: Int
    public let inputSHA256: String
    public let bundleIdentifier: String
    public init(schemaVersion: Int = 1, sha256: String, bytes: Int, inputSHA256: String,
                bundleIdentifier: String = "ai.modelplan.credential-agent") {
        self.schemaVersion = schemaVersion; self.sha256 = sha256; self.bytes = bytes
        self.inputSHA256 = inputSHA256; self.bundleIdentifier = bundleIdentifier
    }
    func accepts(_ url: URL) -> Bool {
        func digest(_ value: String) -> Bool { value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) } }
        guard schemaVersion == 1, bundleIdentifier == "ai.modelplan.credential-agent",
              bytes > 0, bytes <= 32 * 1024 * 1024, digest(sha256), digest(inputSHA256) else { return false }
        var member = url.standardizedFileURL
        while member.path != "/" {
            guard let values = try? member.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == false else { return false }
            member.deleteLastPathComponent()
        }
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true, values.fileSize == bytes,
              let data = try? Data(contentsOf: url), data.count == bytes else { return false }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() == sha256
    }
}

/// Weak, thread-safe bridge to #365. It grants no authority until bound once.
/// The client owns its agent; the agent's fence must not retain the client.
public final class CredentialAgentAuthority: @unchecked Sendable {
    private let lock = NSLock()
    private weak var client: ProcessEngineClient?
    private var bound = false
    public init() {}
    public func bind(_ value: ProcessEngineClient) {
        lock.lock(); defer { lock.unlock() }
        precondition(!bound); bound = true; client = value
    }
    public func isCurrent(_ context: EngineDeliveryContext) -> Bool {
        lock.lock(); let value = client; lock.unlock()
        return value?.isCurrent(context) ?? false
    }
}

private final class HelperCall: @unchecked Sendable {
    private let lock = NSLock()
    private var result: WireCredentialResult?
    private var continuation: CheckedContinuation<WireCredentialResult, Never>?
    private var process: Process?
    func install(_ callback: CheckedContinuation<WireCredentialResult, Never>) {
        lock.lock()
        if let result { lock.unlock(); callback.resume(returning: result) }
        else { continuation = callback; lock.unlock() }
    }
    var stopped: Bool { lock.lock(); defer { lock.unlock() }; return result != nil }
    // Launch and cancellation are serialized: cancellation can never miss a child
    // between the final checkpoint and Process.run(). Only this child is terminated.
    func launch(_ child: Process) throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard result == nil else { return false }
        try child.run(); process = child; return true
    }
    func finish(_ value: WireCredentialResult, terminate: Bool = false) {
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        result = value; let callback = continuation; continuation = nil
        if terminate, let process, process.isRunning { process.terminate() }
        lock.unlock(); callback?.resume(returning: value)
    }
}

/// Runs only the pinned, bounded R2 denial helper. No in-process Security reader,
/// fallback, quota reader, caller anchor, URL or backend-enable flag is provided.
public final class FixedHelperCredentialAgent: CredentialAgent, @unchecked Sendable {
    private let executable: URL
    private let pin: CredentialHelperPin
    private let isCurrent: @Sendable (EngineDeliveryContext) -> Bool
    private let lock = NSLock()
    private var busy = false
    private let queue = DispatchQueue(label: "ModelPlan.U7.helper")
    public init(executable: URL, pin: CredentialHelperPin,
                isCurrent: @escaping @Sendable (EngineDeliveryContext) -> Bool) {
        self.executable = executable; self.pin = pin; self.isCurrent = isCurrent
    }
    /// The descriptor is part of the app's sealed resources, not a caller anchor.
    /// Missing or invalid packaging remains a denial; it never enables a fallback.
    public static func bundled(in bundle: Bundle = .main,
                               isCurrent: @escaping @Sendable (EngineDeliveryContext) -> Bool) -> FixedHelperCredentialAgent? {
        let root = bundle.bundleURL
        let descriptor = root.appendingPathComponent("Contents/Resources/credential-agent.json")
        guard let size = try? descriptor.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 4096,
              let data = try? Data(contentsOf: descriptor), data.count <= 4096,
              let pin = try? JSONDecoder().decode(CredentialHelperPin.self, from: data) else { return nil }
        return .init(executable: root.appendingPathComponent("Contents/Helpers/modelplan-credential-agent"), pin: pin, isCurrent: isCurrent)
    }
    private func acquire() -> Bool { lock.lock(); defer { lock.unlock() }; guard !busy else { return false }; busy = true; return true }
    private func release() { lock.lock(); busy = false; lock.unlock() }
    public func handle(_ operation: EngineCredentialOperation) async -> WireCredentialResult {
        @Sendable func outcome(_ kind: WireCredentialOutcome) -> WireCredentialResult {
            try! .init(operationId: operation.request.operationId, outcome: kind)
        }
        guard !Task.isCancelled else { return outcome(.canceled) }
        guard ContinuousClock.now < operation.deadline else { return outcome(.timeout) }
        guard isCurrent(operation.delivery) else { return outcome(.canceled) }
        guard operation.request.provider == "claude", operation.request.scope == "claude.account_usage.saved_login",
              !operation.request.interactive || operation.userAction != nil else { return outcome(.denied) }
        guard acquire() else { return outcome(.error) }
        let call = HelperCall()
        let deadline = min(operation.deadline, ContinuousClock.now.advanced(by: .seconds(5)))
        let timeout = Task {
            do { try await Task.sleep(until: deadline, clock: .continuous) } catch { return }
            call.finish(outcome(.timeout), terminate: true)
        }
        defer { timeout.cancel() }
        let result = await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { callback in
                call.install(callback)
                queue.async { [self] in
                    defer { release() }
                    guard !call.stopped else { return }
                    guard pin.accepts(executable) else { call.finish(outcome(.denied)); return }
                    guard ContinuousClock.now < deadline else { call.finish(outcome(.timeout)); return }
                    guard isCurrent(operation.delivery) else { call.finish(outcome(.canceled)); return }
                    let child = Process(), input = Pipe(), output = Pipe()
                    child.executableURL = executable; child.arguments = []
                    child.environment = ["PATH": "/usr/bin:/bin", "LANG": "C"]
                    guard fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1) == 0 else { call.finish(outcome(.error)); return }
                    child.standardInput = input; child.standardOutput = output; child.standardError = FileHandle.nullDevice
                    defer { try? input.fileHandleForWriting.close(); try? output.fileHandleForReading.close() }
                    do {
                        guard try call.launch(child) else { return }
                        defer { if child.isRunning { child.terminate() }; child.waitUntilExit() }
                        let request = try JSONEncoder().encode(operation.request)
                        guard request.count <= 65536 else { call.finish(outcome(.error)); return }
                        try input.fileHandleForWriting.write(contentsOf: request); try input.fileHandleForWriting.close()
                        var bytes = Data()
                        while let chunk = try output.fileHandleForReading.read(upToCount: 1024), !chunk.isEmpty {
                            guard bytes.count + chunk.count <= 8192 else { call.finish(outcome(.error), terminate: true); return }
                            bytes.append(chunk)
                        }
                        child.waitUntilExit()
                        guard !call.stopped else { return }
                        guard ContinuousClock.now < deadline else { call.finish(outcome(.timeout)); return }
                        guard isCurrent(operation.delivery) else { call.finish(outcome(.canceled)); return }
                        guard child.terminationStatus == 0,
                              let result = try? JSONDecoder().decode(WireCredentialResult.self, from: bytes),
                              result.operationId == operation.request.operationId, result.outcome == .denied,
                              result.accessToken == nil, result.expiresAt == nil else { call.finish(outcome(.error)); return }
                        call.finish(result)
                    } catch { call.finish(outcome(.error), terminate: true) }
                }
            }
        }, onCancel: { call.finish(outcome(.canceled), terminate: true) })
        if Task.isCancelled { return outcome(.canceled) }
        if ContinuousClock.now >= operation.deadline { return outcome(.timeout) }
        if !isCurrent(operation.delivery) { return outcome(.canceled) }
        return result
    }
}
