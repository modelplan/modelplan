// SPDX-License-Identifier: MIT
import Foundation
import Darwin

/// Command selection is not consent. Production callers must gate normal mode on canonical admission.
public enum DesktopReadMode: Sendable { case readOnly, normal }

public enum CLICommand: String, Sendable, CaseIterable {
    case desktop, refreshAccount, publicationOffline, publication, detect
    public var arguments: [String] {
        switch self {
        case .detect: return ["detect", "--json"]
        case .desktop: return ["desktop", "--json", "--read-only"]
        case .refreshAccount: return ["quota", "--refresh-account", "--quiet"]
        case .publicationOffline: return ["publication", "--json", "--offline"]
        case .publication: return ["publication", "--json"]
        }
    }
    public var timeout: TimeInterval {
        switch self {
        case .desktop, .refreshAccount: return 20
        case .publicationOffline, .detect: return 10
        case .publication: return 30
        }
    }
}
public struct CommandResult: Sendable {
    public let exitCode: Int32
    public let stdout: Data
    public let warning: Bool
    public let stderrTruncated: Bool
    public init(exitCode: Int32, stdout: Data, warning: Bool = false, stderrTruncated: Bool = false) {
        self.exitCode = exitCode; self.stdout = stdout; self.warning = warning; self.stderrTruncated = stderrTruncated
    }
}
public enum TransportError: Error, Equatable, Sendable {
    case busy, launchFailed, timeout, cancelled, outputLimit, pipeFailure
}
public protocol CLITransport: Sendable {
    func execute(_ command: CLICommand) async throws -> CommandResult
}

/// One slot belongs to the transport until the owned child has exited, including cancellation.
/// The executable is an explicit bundle path. Only fixed typed ports may invoke it; no shell or executable PATH fallback.
public protocol ConsentJSONTransport: Sendable {
    func readConsentJSON() async throws -> CommandResult
    func grantConsentJSON(_ payload: Data) async throws -> CommandResult
}

public actor ProcessCLITransport: CLITransport, ConsentJSONTransport, PluginInstallJSONTransport {
    private let executable: URL
    private let environment: [String: String]?
    private let timeoutOverride: TimeInterval?
    private let desktopReadMode: DesktopReadMode
    private var active = false
    public init(executable: URL, environment: [String: String]? = nil, timeoutOverride: TimeInterval? = nil, desktopReadMode: DesktopReadMode = .readOnly) {
        self.executable = executable; self.environment = environment; self.timeoutOverride = timeoutOverride; self.desktopReadMode = desktopReadMode
    }
    public func execute(_ command: CLICommand) async throws -> CommandResult {
        let arguments = command == .desktop && desktopReadMode == .normal ? ["desktop", "--json"] : command.arguments
        return try await run(arguments: arguments, timeout: command.timeout)
    }
    public func readConsentJSON() async throws -> CommandResult {
        try await run(arguments: ["consent", "--json"], timeout: 10)
    }
    public func grantConsentJSON(_ payload: Data) async throws -> CommandResult {
        guard !payload.isEmpty, payload.count <= 65536 else { throw TransportError.outputLimit }
        return try await run(arguments: ["consent", "grant", "--json"], timeout: 20, input: payload)
    }
    public func installPluginJSON(_ tool: PluginInstallTool) async throws -> CommandResult {
        try await run(arguments: tool.arguments, timeout: 120)
    }
    private func run(arguments: [String], timeout: TimeInterval, input: Data? = nil) async throws -> CommandResult {
        guard !active else { throw TransportError.busy }
        active = true; defer { active = false }
        let session = ProcessSession(executable: executable, arguments: arguments, environment: environment,
                                     timeout: timeoutOverride ?? timeout, input: input)
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async { continuation.resume(with: Result { try session.run() }) }
            }
        }, onCancel: { session.cancel() })
    }
}

private final class ProcessSession: @unchecked Sendable {
    let executable: URL, arguments: [String], environment: [String: String]?, timeout: TimeInterval
    private let lock = NSLock()
    private var cancelled = false
    private let input: Data?
    init(executable: URL, arguments: [String], environment: [String: String]?, timeout: TimeInterval, input: Data? = nil) {
        self.executable = executable; self.arguments = arguments; self.environment = environment; self.timeout = timeout; self.input = input
    }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    private var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func run() throws -> CommandResult {
        guard !isCancelled else { throw TransportError.cancelled }
        let child = Process(), output = Pipe(), errors = Pipe()
        let inputPipe = input == nil ? nil : Pipe()
        child.executableURL = executable; child.arguments = arguments
        // Leave the inherited environment untouched unless the caller supplies an override.
        // This uses Foundation’s default inheritance when no override was requested.
        if let environment { child.environment = environment }
        child.standardOutput = output; child.standardError = errors; child.standardInput = inputPipe?.fileHandleForReading ?? FileHandle.nullDevice
        defer {
            try? inputPipe?.fileHandleForReading.close(); try? inputPipe?.fileHandleForWriting.close()
            try? output.fileHandleForReading.close(); try? errors.fileHandleForReading.close()
            try? output.fileHandleForWriting.close(); try? errors.fileHandleForWriting.close()
        }
        do { try child.run() } catch { throw TransportError.launchFailed }
        try? output.fileHandleForWriting.close(); try? errors.fileHandleForWriting.close()
        try? inputPipe?.fileHandleForReading.close()
        let inputFD = inputPipe?.fileHandleForWriting.fileDescriptor
        if let inputFD { _ = fcntl(inputFD, F_SETFL, fcntl(inputFD, F_GETFL) | O_NONBLOCK); _ = fcntl(inputFD, F_SETNOSIGPIPE, 1) }
        var inputOffset = 0, inputClosed = false
        let fds = [output.fileHandleForReading.fileDescriptor, errors.fileHandleForReading.fileDescriptor]
        for fd in fds { _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) }
        let clock = ContinuousClock(), start = ContinuousClock.now
        var failure: TransportError?, stoppedAt: ContinuousClock.Instant?, exitedAt: ContinuousClock.Instant?
        var stdout = Data(), stderrBytes = 0, open = [true, true]
        var buffer = [UInt8](repeating: 0, count: 16384)
        while true {
            let now = clock.now
            if failure == nil {
                if isCancelled { failure = .cancelled }
                else if start.duration(to: now) >= .seconds(timeout) { failure = .timeout }
            }
            if failure != nil, child.isRunning {
                if stoppedAt == nil { child.terminate(); stoppedAt = now }
                else if stoppedAt!.duration(to: now) >= .milliseconds(200) { _ = kill(child.processIdentifier, SIGKILL) }
            }
            if let input, let inputFD, !inputClosed, failure == nil {
                let count = input.withUnsafeBytes { bytes in
                    Darwin.write(inputFD, bytes.baseAddress!.advanced(by: inputOffset), min(4096, input.count - inputOffset))
                }
                if count > 0 { inputOffset += count }
                else if count < 0 && errno != EAGAIN && errno != EINTR { failure = .pipeFailure }
                if inputOffset == input.count || failure != nil {
                    try? inputPipe?.fileHandleForWriting.close(); inputClosed = true
                }
            }
            var polls = fds.enumerated().map { pollfd(fd: open[$0.offset] ? $0.element : -1, events: Int16(POLLIN | POLLHUP), revents: 0) }
            let polled = polls.withUnsafeMutableBufferPointer { Darwin.poll($0.baseAddress, nfds_t($0.count), 10) }
            if polled < 0 && errno != EINTR { failure = failure ?? .pipeFailure }
            for index in 0..<2 where open[index] && polls[index].revents != 0 {
                // Bound work per drain so a noisy child cannot starve timeout/cancellation checks.
                for _ in 0..<32 {
                    let count = Darwin.read(fds[index], &buffer, buffer.count)
                    if count == 0 { open[index] = false; break }
                    if count < 0 { if errno != EAGAIN && errno != EINTR { failure = failure ?? .pipeFailure; open[index] = false }; break }
                    if index == 0 {
                        if stdout.count + count > FeedDecoder.maximumBytes { failure = failure ?? .outputLimit }
                        else if failure == nil { stdout.append(contentsOf: buffer.prefix(count)) }
                    } else { stderrBytes = min(65537, stderrBytes + count) }
                }
            }
            if !child.isRunning {
                if exitedAt == nil { exitedAt = now }
                if !open.contains(true) || exitedAt!.duration(to: now) >= .milliseconds(100) { break }
            }
        }
        child.waitUntilExit()
        if let failure { throw failure }
        return CommandResult(exitCode: child.terminationStatus, stdout: stdout, warning: stderrBytes > 0, stderrTruncated: stderrBytes > 65536)
    }
}
