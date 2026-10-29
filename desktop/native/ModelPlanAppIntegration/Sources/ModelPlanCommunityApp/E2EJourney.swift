// SPDX-License-Identifier: MIT
#if DEBUG && MODELPLAN_E2E_JOURNEY
import AppKit
import ModelPlanCore
import ModelPlanSettings
import ModelPlanCommunityHost
import ModelPlanAppIntegration

@MainActor private final class JourneyFirstRunSurface: SettingsWindowSurface {
    let controller: SettingsFirstRunController
    private(set) var presentations = 0
    init(_ editor: SettingsEditor) { controller = SettingsFirstRunController(editor: editor) }
    func prepare() async { await controller.prepare() }
    func show(paneID: String?) { presentations += 1 /* Real destination, without ordering a CI window. */ }
    func hide() { controller.suspend(); controller.window?.orderOut(nil) }
}

/// Drives only the retained UI controller. No CLI calls, cache edits, clock overrides or refresh calls.
@MainActor enum E2EJourney {
    private static var surface: JourneyFirstRunSurface?
    private static var records = [[String: Any]]()
    static func makeFirstRun(_ editor: SettingsEditor) -> any SettingsWindowSurface {
        let value = JourneyFirstRunSurface(editor); surface = value; return value
    }
    private static func wait(_ seconds: Double, _ predicate: @MainActor () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(seconds))
        while ContinuousClock.now < deadline {
            if predicate() { return true }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return predicate()
    }
    private static func record(_ step: Int, _ facts: [String: Any]) {
        var value = facts; value["step"] = step; records.append(value)
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_E2E_REPORT"],
              let data = try? JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "steps": records], options: [.sortedKeys]) else { return }
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
    private static var profile: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["CODEX_HOME"] ?? "/invalid-e2e-profile")
    }
    private static func calls(failed: Bool) -> [Double] {
        let url = profile.appendingPathComponent("e2e-calls.jsonl")
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 65536,
              let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            guard let data = String(line).data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  event["failed"] as? Bool == failed,
                  let milliseconds = event["at"] as? Double else { return nil }
            return milliseconds / 1000
        }
    }
    private static func values(_ dock: StaticDockPreviewHost) -> [Double] {
        dock.journeyRows.compactMap { $0["remainingPercent"] as? Double }
    }
    private static func fixtureValueIsRendered(_ dock: StaticDockPreviewHost) -> Bool {
        dock.journeyRows.contains {
            $0["provider"] as? String == "codex" && $0["accountAssociated"] as? Bool == true && $0["readout"] as? String == "37%"
        }
    }
    private static func freshFeed(_ dock: StaticDockPreviewHost, after time: Double) -> Bool {
        // CLI timestamps may have whole-second precision. Require a later second, never an older poll.
        (dock.journeyFeedGeneratedAt?.timeIntervalSince1970 ?? 0) >= floor(time) + 1
    }
    private static func labels(_ view: NSView) -> [String] {
        if let field = view as? NSTextField { return [field.stringValue] }
        if let button = view as? NSButton { return [button.title] + view.subviews.flatMap(labels) }
        return view.subviews.flatMap(labels)
    }
    private static func allow(_ controller: SettingsConnectionController) async -> Bool {
        guard let snapshot = controller.snapshot else { return false }
        var intent = SettingsConnectionIntent(snapshot: snapshot)
        for tool in SettingsConnectionTool.allCases { intent.select(tool, enabled: tool == .codex) }
        guard let confirmation = controller.requestAllow(intent) else { return false }
        await controller.confirm(confirmation.id)
        return controller.snapshot?.tools.contains { $0.tool == .codex && $0.authorization == .allowed } == true
    }
    static func run(delegate: CommunityDelegate, dock: StaticDockPreviewHost, backend: CommunityConnectionBackend,
                    consent: CommunityCLIConsentPort) async {
        _ = await wait(30) { delegate.settingsIntegration != nil }
        guard let integration = delegate.settingsIntegration as? CommunityConnectionIntegration else {
            for step in 1...6 { record(step, ["blocked": "retained-settings-missing"]) }; exit(0)
        }
        await integration.restorePreferences()
        let controller = integration.flow.application.editor.connections
        _ = await wait(20) { surface != nil && !controller.isBusy }
        let detected = controller.snapshot?.tools.contains { $0.tool == .codex && $0.presence == .detected } == true
        let listed = surface?.controller.window?.contentView.map { labels($0).contains { $0.contains("Codex") } } == true
        record(1, ["detected": detected, "listedInFirstRun": listed, "backendBound": controller.isBound(to: backend),
                   "snapshotPresent": controller.snapshot != nil, "canonicalGenerationPresent": controller.snapshot?.consentGeneration != nil,
                   "toolCount": controller.snapshot?.tools.count ?? 0, "controllerPhase": String(describing: controller.phase),
                   "consentReadStatus": consent.journeyReadStatus ?? "disabled",
                   "fixtureExecutablePresent": ProcessInfo.processInfo.environment["MODELPLAN_CODEX"].map { FileManager.default.isExecutableFile(atPath: $0) } ?? false,
                   "providerReadsBeforeGrant": calls(failed: false).count + calls(failed: true).count])

        let granted = await allow(controller)
        record(2, ["granted": granted, "apiAvailable": backend.settingsConnectionAvailability.canGrant,
                   "controllerPhase": String(describing: controller.phase),
                   "releaseIdentityVerified": CommunityConsentBundleIdentity.matches(bundle: Bundle.main.bundleURL),
                   "debugAdmission": CommunityJourneyCI.enabled])

        _ = await wait(granted ? 100 : 1) {
            guard let last = calls(failed: false).last else { return false }
            return freshFeed(dock, after: last)
        }
        let success = calls(failed: false)
        record(3, ["providerReads": success.count, "postProviderSnapshot": success.last.map { freshFeed(dock, after: $0) } ?? false,
                   "nativePanelsVisible": dock.isVisible])

        _ = await wait(success.isEmpty ? 1 : 75) {
            fixtureValueIsRendered(dock)
        }
        let sawValue = fixtureValueIsRendered(dock)
        record(4, ["renderedRows": dock.journeyRows])

        let revokeAt = Date().timeIntervalSince1970
        if let confirmation = controller.requestForget(.codex) { await controller.confirm(confirmation.id) }
        let revoked = controller.snapshot?.tools.contains {
            $0.tool == .codex && ($0.authorization == .denied || $0.authorization == .noConsent)
        } == true
        _ = await wait(revoked ? 90 : 1) { freshFeed(dock, after: revokeAt) && values(dock).isEmpty }
        record(5, ["revoked": revoked, "valueSeenBefore": sawValue, "values": values(dock),
                   "postRevokeSnapshot": freshFeed(dock, after: revokeAt), "rows": dock.journeySnapshot?.inputs.count ?? 0])

        // Change only the synthetic provider's own control file, never a ModelPlan cache or identity.
        let fixture = profile.standardizedFileURL
        let fixtureIsSynthetic = fixture.path.hasPrefix(NSHomeDirectory() + "/")
        if fixtureIsSynthetic { try? Data("unreadable\n".utf8).write(to: fixture.appendingPathComponent("e2e-mode"), options: .atomic) }
        let failuresBefore = calls(failed: true).count
        let regranted: Bool
        if fixtureIsSynthetic { regranted = await allow(controller) } else { regranted = false }
        _ = await wait(regranted ? 130 : 1) {
            guard calls(failed: true).count > failuresBefore, let last = calls(failed: true).last else { return false }
            return freshFeed(dock, after: last)
        }
        let failures = calls(failed: true)
        let unreadableRows = dock.journeyRows.filter {
            $0["provider"] as? String == "codex" && $0["readout"] as? String == "--" && !($0["reason"] as? String ?? "").isEmpty
        }
        let beforeNavigation = surface?.presentations ?? 0
        var rowActionDispatched = false
        if let rowIndex = unreadableRows.first?["rowIndex"] as? Int, dock.journeyOpenCard(at: rowIndex) {
            rowActionDispatched = dock.journeyPressCardEnter()
        }
        let settingsReached = await wait(rowActionDispatched ? 10 : 0) {
            guard let surface, surface.presentations > beforeNavigation,
                  surface.controller.editor === integration.flow.application.editor,
                  let view = surface.controller.window?.contentView else { return false }
            return labels(view).contains { $0.contains("Codex") } && controller.isBound(to: backend)
        }
        record(6, ["regranted": regranted, "unreadableObserved": failures.count > failuresBefore,
                   "postErrorSnapshot": failures.last.map { freshFeed(dock, after: $0) } ?? false,
                   "rows": dock.journeyRows.count, "reasonRows": unreadableRows,
                   "values": values(dock), "rowActionDispatched": rowActionDispatched,
                   "settingsDestinationReached": settingsReached])
        exit(0)
    }
}
#endif
