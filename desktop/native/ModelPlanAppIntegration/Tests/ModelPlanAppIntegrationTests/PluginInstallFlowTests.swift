// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
@testable import ModelPlanAppIntegration
@testable import ModelPlanSettings

@MainActor final class PluginInstallFlowTests: XCTestCase {
    private actor Wire: PluginInstallJSONTransport {
        let result: CommandResult
        var calls: [PluginInstallTool] = []
        init(_ data: Data, exit: Int32 = 0) { result = .init(exitCode:exit,stdout:data) }
        func installPluginJSON(_ tool: PluginInstallTool) async throws -> CommandResult { calls.append(tool); return result }
        func count() -> Int { calls.count }
    }
    private final class Guidance: CommunityPluginGuidance {
        var copies = 0, opens = 0
        var copyResult = true, openResult = true
        func copy(_ tool: PluginInstallTool) -> Bool { copies += 1; return copyResult }
        func openDocumentation(_ tool: PluginInstallTool) -> Bool { opens += 1; return openResult }
    }
    private final class Consent: CommunityConsentCommandPort {
        var availability: SettingsConnectionAvailability { .init(canInspect:true,canGrant:true,canForget:true) }
        var reads = 0, grants = 0
        func readCanonicalConsent() async throws -> ConsentPreview { reads += 1; XCTFail("Plugin action must not inspect usage"); throw SettingsConnectionFailure.unavailable }
        func applyConsentJSON(_ payload: Data) async throws { grants += 1; XCTFail("Plugin action must not grant usage") }
    }
    private actor NoReader: CLITransport {
        func execute(_ command: CLICommand) async throws -> CommandResult { XCTFail("No usage reader/helper"); throw TransportError.launchFailed }
    }
    private func data(_ tool: SettingsPluginTool, _ suffix: String) throws -> Data {
        try GeneratedAppCLIFixtures.data("fresh-plugin-install-"+tool.rawValue+"-"+suffix+".json")
    }
    private func data(_ suffix: String) throws -> Data {try data(.codex,suffix)}
    private func control(_ view: NSView, _ id: String) throws -> ConnectionButton {
        func find(_ view: NSView) -> ConnectionButton? {
            if let button = view as? ConnectionButton, button.accessibilityIdentifier()==id {return button}
            return view.subviews.lazy.compactMap(find).first
        }
        return try XCTUnwrap(find(view))
    }
    func testActualFactoryPluginControlNeedsOneConfirmationAndUsesNoUsagePort() async throws {
        let wire = Wire(try data("installed")), guide = Guidance(), consent = Consent(), noReader = NoReader()
        let installer = CommunityPluginInstaller(transport:wire,apiAvailable:true,guidance:guide,canPresent:{true})
        let backend = CommunityConnectionBackend(port:consent,desktop:.init(readOnly:noReader,normal:noReader),pluginInstaller:installer)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("plugin-flow-"+UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let app = SettingsApplicationCoordinator(store:try SettingsStore(url:folder.appendingPathComponent("settings.json")),apply:{_ in})
        let base = CommunitySettingsSession(application:app,canPresent:{false},environment:{.init()},activate:{XCTFail("No activation")})
        let entry = try CommunityApplicationFactory.connectSettings(base:base,application:app,backend:backend,canPresent:{false})
        defer {entry.flow.dispose()}
        try CommunityConnectionWiring.requireInstalled(entry,application:app,backend:backend)
        let view = SettingsConnectionsView(editor:app.editor)
        let button = try control(view,"connections.plugin.codex");XCTAssertTrue(button.isEnabled)
        let before = await wire.count();XCTAssertEqual(before,0)
        button.invoke?()
        guard case .awaitingConfirmation(let request) = app.editor.connections.phase else {return XCTFail("Missing real confirmation")}
        let unconfirmed = await wire.count();XCTAssertEqual(unconfirmed,0)
        await app.editor.connections.confirm(request.id);await app.editor.connections.confirm(request.id)
        XCTAssertEqual(app.editor.connections.phase,.pluginResult(.init(tool:.codex,status:.installed,completedSteps:2)))
        let after = await wire.count();XCTAssertEqual(after,1)
        XCTAssertEqual(consent.reads,0);XCTAssertEqual(consent.grants,0);XCTAssertEqual(guide.copies,0);XCTAssertEqual(guide.opens,0)
        XCTAssertNil(view.window)
    }
    func testActualBinaryCapturesMapAllStatusesForBothToolsWithoutFalseInstallation() async throws {
        let cases: [(String,SettingsPluginInstallStatus,Int,Int32)] = [("installed",.installed,2,0),("instructions",.instructions,0,0),("planned",.planned,0,0),("failed-first",.failed,0,1),("failed-manual-step",.failed,1,1)]
        for tool in SettingsPluginTool.allCases {for (suffix,status,completed,exit) in cases {
            let filename = "fresh-plugin-install-" + tool.rawValue + "-" + suffix + ".json"
            let capture = try XCTUnwrap(GeneratedAppCLIFixtures.manifest().entries.first { $0.file == filename })
            XCTAssertEqual(capture.exitCode, exit)
            let wire = Wire(try GeneratedAppCLIFixtures.data(filename), exit: capture.exitCode), guide = Guidance()
            let installer = CommunityPluginInstaller(transport:wire,apiAvailable:true,guidance:guide,canPresent:{true})
            let result = try await installer.install(tool)
            XCTAssertEqual(result.tool,tool);XCTAssertEqual(result.status,status);XCTAssertEqual(result.completedSteps,completed)
            XCTAssertEqual(result.isInstalled,status == .installed)
            XCTAssertEqual(guide.copies,status == .instructions ? 1:0);XCTAssertEqual(guide.opens,status == .instructions ? 1:0)
            if status == .instructions {XCTAssertEqual(result.guideDelivery,.init(copied:true,documentationRequested:true))}
        }}
    }
    func testUnverifiedComponentStartsNoCommandOrGuidance() async throws {
        let wire = Wire(try data("installed")),guide = Guidance()
        let installer = CommunityPluginInstaller(transport:wire,guidance:guide,canPresent:{true})
        XCTAssertTrue(installer.supportedTools.isEmpty)
        do {_ = try await installer.install(.codex);XCTFail("Unverified component accepted")}catch{XCTAssertEqual(error as? SettingsConnectionFailure,.unavailable)}
        let count = await wire.count();XCTAssertEqual(count,0);XCTAssertEqual(guide.copies,0);XCTAssertEqual(guide.opens,0)
    }
    func testMalformedUnrelatedOrInconsistentReceiptsNeverTriggerGuidance() async throws {
        for mutation in ["tool","commands","docs","completed","status","exit"] {
            var object = try GeneratedAppCLIFixtures.object("fresh-plugin-install-codex-installed.json")
            switch mutation {
            case "tool":object["tool"]="claude-code"
            case "commands":object["commands"]=[["sh","-c","untrusted"]]
            case "docs":object["docs"]="https://example.test/untrusted"
            case "completed":object["completed"]=1
            case "status":object["status"]="future-success"
            default:break
            }
            let wire = Wire(try JSONSerialization.data(withJSONObject:object),exit:mutation == "exit" ? 1:0),guide = Guidance()
            let installer = CommunityPluginInstaller(transport:wire,apiAvailable:true,guidance:guide,canPresent:{true})
            do {_ = try await installer.install(.codex);XCTFail("Invalid receipt accepted: "+mutation)}catch{XCTAssertEqual(error as? SettingsConnectionFailure,.invalidResponse)}
            XCTAssertEqual(guide.copies,0);XCTAssertEqual(guide.opens,0)
        }
    }
    func testActualFallbackControlsReportDeliveryAndNeverRepeatInstallation() async throws {
        let wire = Wire(try data("instructions")), guide = Guidance(), consent = Consent(), reader = NoReader()
        guide.copyResult = false; guide.openResult = false
        var visible = true
        let installer = CommunityPluginInstaller(transport: wire, apiAvailable: true, guidance: guide, canPresent: { visible })
        let backend = CommunityConnectionBackend(port: consent, desktop: .init(readOnly: reader, normal: reader), pluginInstaller: installer)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("plugin-guide-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: folder.appendingPathComponent("settings.json")), apply: { _ in })
        let base = CommunitySettingsSession(application: app, canPresent: { false }, environment: { .init() }, activate: { XCTFail("No activation") })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend, canPresent: { false })
        defer { entry.flow.dispose() }
        let view = SettingsConnectionsView(editor: app.editor), controller = app.editor.connections
        try control(view, "connections.plugin.codex").invoke?()
        guard case .awaitingConfirmation(let request) = controller.phase else { return XCTFail("No confirmation") }
        let copy = SettingsConnectionPresentation.confirmation(request.action)
        XCTAssertTrue(copy.english.contains("copied")); XCTAssertTrue(copy.chinese.contains("复制"))
        await controller.confirm(request.id)
        XCTAssertEqual(controller.phase, .pluginResult(.init(tool: .codex, status: .instructions, completedSteps: 0,
            guideDelivery: .init(copied: false, documentationRequested: false))))
        let failedCopy = SettingsConnectionPresentation.status(controller.phase)
        XCTAssertTrue(failedCopy.english.contains("could not")); XCTAssertTrue(failedCopy.chinese.contains("未能"))
        guide.copyResult = true; guide.openResult = true
        try control(view, "connections.pluginCopy.codex").invoke?()
        try control(view, "connections.pluginGuide.codex").invoke?()
        XCTAssertEqual(controller.phase, .pluginResult(.init(tool: .codex, status: .instructions, completedSteps: 0,
            guideDelivery: .init(copied: true, documentationRequested: true))))
        XCTAssertEqual(guide.copies, 2); XCTAssertEqual(guide.opens, 2)
        let calls = await wire.count(); XCTAssertEqual(calls, 1)
        visible = false
        XCTAssertFalse(controller.copyPluginInstructions(.codex)); XCTAssertFalse(controller.openPluginDocumentation(.codex))
        XCTAssertEqual(guide.copies, 2); XCTAssertEqual(guide.opens, 2)
        XCTAssertEqual(consent.reads, 0); XCTAssertEqual(consent.grants, 0); XCTAssertNil(view.window)
    }
    private actor DelayedWire: PluginInstallJSONTransport {
        private var result: CheckedContinuation<CommandResult, Never>?
        private var started: CheckedContinuation<Void, Never>?
        func installPluginJSON(_ tool: PluginInstallTool) async throws -> CommandResult {
            await withCheckedContinuation { continuation in
                result = continuation; started?.resume(); started = nil
            }
        }
        func waitForStart() async {
            if result != nil { return }
            await withCheckedContinuation { started = $0 }
        }
        func finish(_ data: Data) { result?.resume(returning: .init(exitCode: 0, stdout: data)); result = nil }
    }
    func testRetiredOrCancelledInstallCannotCopyCommandsOrOpenGuide() async throws {
        for cancel in [false, true] {
            var visible = true
            let wire = DelayedWire(), guide = Guidance()
            let installer = CommunityPluginInstaller(transport: wire, apiAvailable: true, guidance: guide, canPresent: { visible })
            let task = Task { try await installer.install(.codex) }
            await wire.waitForStart()
            if cancel { task.cancel() } else { visible = false }
            await wire.finish(try data("instructions"))
            do {
                let receipt = try await task.value
                XCTAssertFalse(cancel); XCTAssertNil(receipt.guideDelivery)
            } catch { XCTAssertTrue(cancel); XCTAssertTrue(error is CancellationError) }
            XCTAssertEqual(guide.copies, 0); XCTAssertEqual(guide.opens, 0)
        }
    }
    func testDefaultFactoryLeavesUnverifiedPluginActionsDisabledWithoutLaunchingAnything() throws {
        let consent = Consent(), reader = NoReader()
        let backend = CommunityConnectionBackend(port: consent, desktop: .init(readOnly: reader, normal: reader))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("plugin-unverified-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: folder.appendingPathComponent("settings.json")), apply: { _ in })
        let base = CommunitySettingsSession(application: app, canPresent: { false }, environment: { .init() }, activate: { XCTFail("No activation") })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend, canPresent: { false })
        defer { entry.flow.dispose() }
        let view = SettingsConnectionsView(editor: app.editor)
        XCTAssertTrue(app.editor.connections.availability.pluginTools.isEmpty)
        for tool in SettingsPluginTool.allCases { XCTAssertFalse(try control(view, "connections.plugin." + tool.rawValue).isEnabled) }
        XCTAssertEqual(consent.reads, 0); XCTAssertEqual(consent.grants, 0); XCTAssertNil(view.window)
    }
    func testFixedArgvAndInstructionMetadataMatchTheGeneratedCommandContract() throws {
        for tool in PluginInstallTool.allCases {
            XCTAssertEqual(tool.arguments,["plugin","install",tool.rawValue,"--json"])
            let receipt = try FeedDecoder.pluginInstall(data(SettingsPluginTool(rawValue:tool.rawValue)!,"installed"))
            XCTAssertEqual(receipt.tool,tool)
            XCTAssertEqual(receipt.docs,tool.documentationURL.absoluteString)
            XCTAssertEqual(receipt.commands.map{$0.joined(separator:" ")}.joined(separator:"\n"),tool.instructionText)
        }
    }
}
