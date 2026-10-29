// SPDX-License-Identifier: MIT
import Foundation
import Dispatch
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// One owned child. Blocking pipe work runs on dedicated queues, never an actor executor.
final class EngineProcess: @unchecked Sendable {
    let id: UUID
    let process: Process
    private let input = Pipe()
    private let output = Pipe()
    private let errors = Pipe()
    private let writer = DispatchQueue(label: "modelplan.engine.stdin")
    private let lock = NSLock()
    private var aborted = false
    private var inputClosed = false
    private let writeTimeout: Double

    init(id: UUID, configuration: EngineClientConfiguration, writeTimeout: Double,
         frame: @escaping @Sendable (UUID, Data) async -> Void,
         ended: @escaping @Sendable (UUID, Bool) async -> Void) throws {
        self.id = id
        self.writeTimeout = writeTimeout
        self.process = Process()
        process.executableURL = configuration.executableURL
        process.arguments = ["app-server"] + (configuration.offline ? ["--offline"] : []) + (configuration.readOnly ? ["--read-only"] : [])
        process.environment = configuration.allowedEnvironment
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        for handle in [input.fileHandleForWriting, input.fileHandleForReading,
                       output.fileHandleForReading, output.fileHandleForWriting,
                       errors.fileHandleForReading, errors.fileHandleForWriting] {
            _ = fcntl(handle.fileDescriptor, F_SETFD, FD_CLOEXEC)
        }
        process.terminationHandler = { _ in
            // Let stdout drain before classifying exit, especially a final
            // protocol_mismatch error. A leaked child pipe cannot wait forever.
            Task { try? await Task.sleep(for: .seconds(1)); await ended(id, false) }
        }
        do { try process.run() } catch {
            for handle in [input.fileHandleForWriting, input.fileHandleForReading,
                           output.fileHandleForReading, output.fileHandleForWriting,
                           errors.fileHandleForReading, errors.fileHandleForWriting] { try? handle.close() }
            throw EngineClientError.interrupted(.notSent)
        }
        // These parent copies must not keep the child's stdin/stdout alive.
        try? input.fileHandleForReading.close()
        try? output.fileHandleForWriting.close()
        try? errors.fileHandleForWriting.close()
        let fd = input.fileHandleForWriting.fileDescriptor
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        DispatchQueue(label: "modelplan.engine.stdout").async { [self] in
            let handle = output.fileHandleForReading
            defer { try? handle.close() }
            var decoder = LineFramer()
            var buffer = [UInt8](repeating: 0, count: 16_384)
            do {
                while true {
                    let size = read(handle.fileDescriptor, &buffer, buffer.count)
                    if size == 0 { try decoder.finish(); break }
                    if size < 0 {
                        if errno == EINTR { continue }
                        throw EngineClientError.protocolViolation
                    }
                    for bytes in try decoder.append(Data(buffer.prefix(size))) {
                        // One outstanding handoff bounds frame tasks while actor ingress
                        // stays independent of consumer/credential acknowledgments.
                        let ack = DispatchSemaphore(value: 0)
                        Task { await frame(id, bytes); ack.signal() }
                        ack.wait()
                    }
                }
                Task { await ended(id, false) }
            } catch { Task { await ended(id, true) } }
        }
        DispatchQueue(label: "modelplan.engine.stderr").async { [self] in
            let handle = errors.fileHandleForReading
            defer { try? handle.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let size = read(handle.fileDescriptor, &buffer, buffer.count)
                if size == 0 { return }
                if size < 0 && errno != EINTR { return }
                // Never retain/log raw child stderr or include it in an Error.
            }
        }
    }

    private func canWrite() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return !aborted && !inputClosed
    }
    private func markAborted() {
        lock.lock(); aborted = true; lock.unlock()
    }

    func send(_ bytes: Data, timeout: Double? = nil) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writer.async { [self] in
                do { try writeFrame(bytes, timeout: timeout); continuation.resume() }
                catch { continuation.resume(throwing: EngineClientError.interrupted(.connectionLost)) }
            }
        }
    }

    private func writeFrame(_ bytes: Data, timeout: Double?) throws {
        guard canWrite() else { throw EngineClientError.interrupted(.connectionLost) }
        // SIGPIPE is blocked only on this worker during this write. Never change
        // the host app's process-wide signal disposition.
        var pipeSignal = sigset_t()
        var oldMask = sigset_t()
        sigemptyset(&pipeSignal); sigaddset(&pipeSignal, SIGPIPE)
        let masked = pthread_sigmask(SIG_BLOCK, &pipeSignal, &oldMask) == 0
        var before = sigset_t(); sigpending(&before)
        let wasPending = sigismember(&before, SIGPIPE) == 1
        defer {
            if masked {
                var pending = sigset_t(); sigpending(&pending)
                if !wasPending && sigismember(&pending, SIGPIPE) == 1 {
                    var received: Int32 = 0
                    _ = sigwait(&pipeSignal, &received)
                }
                _ = pthread_sigmask(SIG_SETMASK, &oldMask, nil)
            }
        }
        let deadline = ProcessInfo.processInfo.systemUptime + min(writeTimeout, timeout ?? writeTimeout)
        try bytes.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                guard canWrite(), ProcessInfo.processInfo.systemUptime < deadline else { throw EngineClientError.protocolViolation }
                let count = write(input.fileHandleForWriting.fileDescriptor, raw.baseAddress!.advanced(by: offset), raw.count - offset)
                if count > 0 { offset += count; continue }
                if count < 0 && errno == EINTR { continue }
                guard count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) else { throw EngineClientError.protocolViolation }
                var descriptor = pollfd(fd: input.fileHandleForWriting.fileDescriptor, events: Int16(POLLOUT), revents: 0)
                _ = poll(&descriptor, 1, 25)
            }
        }
    }

    func closeInput() async {
        await withCheckedContinuation { continuation in
            writer.async { [self] in
                lock.lock()
                let close = !inputClosed
                inputClosed = true
                lock.unlock()
                if close { try? input.fileHandleForWriting.close() }
                continuation.resume()
            }
        }
    }

    private func cleanupPause() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) { continuation.resume() }
        }
    }
    func finish() async -> Bool {
        markAborted()
        await closeInput()
        let graceful = ProcessInfo.processInfo.systemUptime + 2
        while process.isRunning && ProcessInfo.processInfo.systemUptime < graceful { await cleanupPause() }
        if process.isRunning { process.terminate() }
        let terminate = ProcessInfo.processInfo.systemUptime + 2
        while process.isRunning && ProcessInfo.processInfo.systemUptime < terminate { await cleanupPause() }
        if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
        // Process's termination handler owns reaping; await completion without
        // blocking a cooperative executor. SIGKILL leaves no running child.
        let reap = ProcessInfo.processInfo.systemUptime + 1
        while process.isRunning && ProcessInfo.processInfo.systemUptime < reap { await cleanupPause() }
        return !process.isRunning
    }
}
