// SPDX-License-Identifier: MIT
import Foundation
import Darwin

public enum CLICommand: String, Sendable, CaseIterable {
    case desktop, refreshAccount, publicationOffline, publication
    public var arguments: [String] {
        switch self {
        case .desktop: return ["desktop", "--json", "--read-only"]
        case .refreshAccount: return ["quota", "--refresh-account", "--quiet"]
        case .publicationOffline: return ["publication", "--json", "--offline"]
        case .publication: return ["publication", "--json"]
        }
    }
    public var timeout: TimeInterval {
        switch self {
        case .desktop, .refreshAccount: return 20
        case .publicationOffline: return 10
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
/// The executable is an explicit bundle path. No shell, PATH lookup or management command.
public actor ProcessCLITransport: CLITransport {
    private let executable: URL
    private let environment: [String: String]?
    private let timeoutOverride: TimeInterval?
    private var active = false
    public init(executable: URL, environment: [String: String]? = nil, timeoutOverride: TimeInterval? = nil) {
        self.executable = executable; self.environment = environment; self.timeoutOverride = timeoutOverride
    }
    public func execute(_ command: CLICommand) async throws -> CommandResult {
        guard !active else { throw TransportError.busy }
        active = true; defer { active = false }
        let session = ProcessSession(executable: executable, arguments: command.arguments, environment: environment,
                                     timeout: timeoutOverride ?? command.timeout)
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
    init(executable: URL, arguments: [String], environment: [String: String]?, timeout: TimeInterval) {
        self.executable = executable; self.arguments = arguments; self.environment = environment; self.timeout = timeout
    }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    private var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func run() throws -> CommandResult {
        guard !isCancelled else { throw TransportError.cancelled }
        let child = Process(), output = Pipe(), errors = Pipe()
        child.executableURL = executable; child.arguments = arguments; child.environment = environment
        child.standardOutput = output; child.standardError = errors; child.standardInput = FileHandle.nullDevice
        defer {
            try? output.fileHandleForReading.close(); try? errors.fileHandleForReading.close()
            try? output.fileHandleForWriting.close(); try? errors.fileHandleForWriting.close()
        }
        do { try child.run() } catch { throw TransportError.launchFailed }
        try? output.fileHandleForWriting.close(); try? errors.fileHandleForWriting.close()
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
