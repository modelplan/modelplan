// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanShell

/// D164: the one place that decides where the app keeps its own state.
///
/// Normally that is the real profile (~/Library/Application Support, ~/Library/Caches).
/// `MODELPLAN_PROFILE_ROOT=<absolute dir>` (set by the test build's `ModelPlan First Run.command`
/// launcher or the packaged walkthrough, never by a production build) switches the app to a fresh
/// profile: every store the app or its bundled engine writes lives under that folder, the login item
/// and status-item position are not touched, and the engine child gets the same root so its config
/// and cache follow. Tool data (~/.codex, ~/.claude, ZCode…) is still found from HOME and read only
/// after first-run consent, exactly as for a new user.
///
/// Layout under the root:
///   app/Application Support   settings.json, reset/forecast ledgers, cockpit scope and cautions
///   app/Caches                the app's own cache folder and URL cache
///   engine/config             consent, connections, declared quota, local-usage and project-label choices
///   engine/cache              publication cache, history, perf, cycles, observed readings
public struct ProfileRoot: Sendable, Equatable {
    public static let environmentKey = "MODELPLAN_PROFILE_ROOT"
    /// The status-item position is remembered in the standard defaults domain under this name.
    public static let statusItemAutosaveName = "ModelPlanCommunity.StatusItem"

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case notAbsolute, notADirectory, overlapsRealProfile, linkedStore
        public var description: String {
            switch self {
            case .notAbsolute: return "it is empty or not an absolute path"
            case .linkedStore: return "something inside it is a symbolic link"
            case .notADirectory: return "it is not an existing folder"
            case .overlapsRealProfile: return "it overlaps the real profile"
            }
        }
    }

    /// nil when the app uses the real profile.
    public let root: URL?
    /// Stands in for ~/Library/Application Support.
    public let applicationSupport: URL
    /// Stands in for ~/Library/Caches.
    public let caches: URL

    public var isFresh: Bool { root != nil }
    /// ModelPlan's folder in Application Support: settings.json and the notification ledgers.
    public var modelPlanSupport: URL { applicationSupport.appendingPathComponent("ModelPlan", isDirectory: true) }
    /// A fresh profile never persists the status-item position (it lives in the standard defaults domain).
    public var statusItemAutosaveName: String? { isFresh ? nil : Self.statusItemAutosaveName }
    /// A fresh profile never registers or unregisters the real login item (SMAppService is per app, not per profile).
    public var allowsLoginItem: Bool { !isFresh }
    /// The engine's config and cache folders under a fresh profile (cli/internal/profile mirrors these).
    public var engineConfig: URL? { root?.appendingPathComponent("engine/config", isDirectory: true) }
    public var engineCache: URL? { root?.appendingPathComponent("engine/cache", isDirectory: true) }

    /// Every store the app or engine writes, by name. Under a fresh profile each one is inside `root`.
    public func stores(bundleIdentifier: String) -> [(name: String, url: URL)] {
        var value: [(name: String, url: URL)] = [
            ("settings", modelPlanSupport.appendingPathComponent("settings.json")),
            ("cockpit scope", modelPlanSupport.appendingPathComponent("cockpit-scope.json")),
            ("cockpit cautions", modelPlanSupport.appendingPathComponent("cockpit-cautions.json")),
            ("reset notifications", modelPlanSupport.appendingPathComponent("reset-notifications.json")),
            ("forecast notifications", modelPlanSupport.appendingPathComponent("forecast-notifications.json")),
            ("legacy settings", applicationSupport.appendingPathComponent("ModelPlan/Native/settings-v1.json")),
            ("legacy core preferences", applicationSupport.appendingPathComponent("ModelPlan/Native/community-v1.json")),
            ("self-test settings", applicationSupport.appendingPathComponent("ModelPlan/DockSelfTest/settings-v1.json")),
            ("app cache", caches.appendingPathComponent(bundleIdentifier, isDirectory: true)),
        ]
        if let urlCacheDirectory { value.append(("URL cache", urlCacheDirectory)) }
        if let engineConfig, let engineCache { value += [("engine config", engineConfig), ("engine cache", engineCache)] }
        return value
    }

    /// A fresh profile keeps URLSession's disk cache inside it instead of ~/Library/Caches/<bundle id>.
    public var urlCacheDirectory: URL? { isFresh ? caches.appendingPathComponent("URLCache", isDirectory: true) : nil }

    /// The engine child's environment: a fresh profile always passes its root; the real profile never does.
    public func childEnvironment(_ environment: [String: String]) -> [String: String] {
        var value = environment
        value[Self.environmentKey] = root?.path
        return value
    }

    /// The real profile, from the system's folders.
    public static func real(fileManager: FileManager = .default) -> ProfileRoot {
        let home = fileManager.homeDirectoryForCurrentUser
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? home.appendingPathComponent("Library/Application Support", isDirectory: true)
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? home.appendingPathComponent("Library/Caches", isDirectory: true)
        return ProfileRoot(root: nil, applicationSupport: support, caches: caches)
    }

    /// No key: the real profile. A present key that is empty, not an absolute existing folder, overlaps the real
    /// profile or holds a linked store is refused; it never falls back to the real profile.
    public static func resolve(environment: [String: String], fileManager: FileManager = .default) throws -> ProfileRoot {
        let real = real(fileManager: fileManager)
        // Only an absent key means the real profile; an empty value is a failed selection, not "unset".
        guard let raw = environment[environmentKey] else { return real }
        guard !raw.isEmpty, raw.hasPrefix("/") else { throw Failure.notAbsolute }
        let root = URL(fileURLWithPath: raw, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw Failure.notADirectory
        }
        let home = fileManager.homeDirectoryForCurrentUser.standardizedFileURL.resolvingSymlinksInPath()
        let realStores = [home, real.modelPlanSupport, real.caches, home.appendingPathComponent(".config/modelplan"),
                          home.appendingPathComponent("Library/Preferences")]
            .map { $0.standardizedFileURL.resolvingSymlinksInPath() }
        // The root may not be the home folder or an ancestor of it, nor sit inside a real store.
        if realStores.contains(where: { Self.contains(root, $0) || ($0 != home && Self.contains($0, root)) }) {
            throw Failure.overlapsRealProfile
        }
        // Nothing under the root may be a symbolic link: neither the app nor the engine creates one there, and a
        // planted link could lead any store back into the real profile. The whole tree is walked without following
        // links, so every store path built under the root, including ones added later, is covered.
        if containsLink(root, fileManager: fileManager) { throw Failure.linkedStore }
        return ProfileRoot(root: root,
                           applicationSupport: root.appendingPathComponent("app/Application Support", isDirectory: true),
                           caches: root.appendingPathComponent("app/Caches", isDirectory: true))
    }

    static func containsLink(_ root: URL, fileManager: FileManager) -> Bool {
        var unreadable = false
        guard let walker = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [],
                                                  errorHandler: { _, _ in unreadable = true; return false }) else { return true }
        for case let url as URL in walker {
            guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]) else { return true }
            if values.isSymbolicLink == true { return true }
        }
        return unreadable
    }

    /// Resolved once per launch. An unusable root stops the app before anything is written.
    public static let current: ProfileRoot = {
        do { return try resolve(environment: ProcessInfo.processInfo.environment) } catch {
            fputs("ModelPlan: \(environmentKey) is unusable (\(error)); not starting, so the real profile stays untouched.\n", stderr)
            exit(64)
        }
    }()

    /// Call first thing at launch under a fresh profile: volatile defaults that keep AppKit from restoring or
    /// saving window state, the URL cache moved inside the profile, and a bundled engine that knows the root.
    /// An engine too old to honour the root would write the real profile, so the app refuses to start instead.
    public func prepareLaunch(helper: URL) {
        guard isFresh else { return }
        // The registration domain is in memory only; nothing is written to the real defaults domain.
        UserDefaults.standard.register(defaults: ["ApplePersistenceIgnoreState": true, "NSQuitAlwaysKeepsWindows": false])
        if let urlCacheDirectory {
            URLCache.shared = URLCache(memoryCapacity: 4 << 20, diskCapacity: 32 << 20, directory: urlCacheDirectory)
        }
        guard Self.engineHonoursRoot(helper: helper) else {
            fputs("ModelPlan: the bundled engine does not support \(Self.environmentKey); not starting, so the real profile stays untouched.\n", stderr)
            exit(65)
        }
    }

    /// `modelplan --help` writes nothing; an engine that honours the root names it there.
    static func engineHonoursRoot(helper: URL) -> Bool {
        let process = Process(), pipe = Pipe()
        process.executableURL = helper; process.arguments = ["--help"]
        process.environment = ["PATH": "/usr/bin:/bin"]
        process.standardInput = FileHandle.nullDevice; process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return false }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return process.terminationStatus == 0 && output.contains(environmentKey + "=")
    }

    /// The login item a fresh profile shows: unavailable, and never registered or unregistered.
    @MainActor static func unavailableLoginItem() -> PulseLoginItem {
        PulseLoginItem(isAppBundle: false, service: UnavailableLoginService())
    }

    private static func contains(_ parent: URL, _ child: URL) -> Bool {
        let p = parent.path.hasSuffix("/") ? String(parent.path.dropLast()) : parent.path
        return child.path == p || child.path.hasPrefix(p + "/")
    }
}

@MainActor private final class UnavailableLoginService: PulseLoginService {
    var state: PulseLoginState { .unavailable }
    func register() throws {}
    func unregister() throws {}
}
