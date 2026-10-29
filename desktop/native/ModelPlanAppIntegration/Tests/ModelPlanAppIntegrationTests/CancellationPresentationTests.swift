// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class CancellationPresentationTests: XCTestCase {
    private final class Port: CommunityConsentCommandPort {
        let value: ConsentPreview
        var reads = 0, mutations = 0
        var paused = false
        var pending: CheckedContinuation<ConsentPreview, Never>?
        var availability: SettingsConnectionAvailability { .init(canInspect: true, canGrant: true, canForget: true) }
        init() throws {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "consent-v0.5.45-synthetic", withExtension: "json"))
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            object["mode"] = "automatic"
            var tools = try XCTUnwrap(object["tools"] as? [[String: Any]])
            for index in tools.indices { tools[index]["allowed"] = true }
            object["tools"] = tools
            value = try FeedDecoder.consentPreview(JSONSerialization.data(withJSONObject: object))
        }
        func readCanonicalConsent() async throws -> ConsentPreview {
            reads += 1
            if paused { return await withCheckedContinuation { pending = $0 } }
            return value
        }
        func applyConsentJSON(_ payload: Data) async throws { mutations += 1; XCTFail("No consent mutation in presentation regression") }
    }
    private actor Desktop: CLITransport {
        func execute(_ command: CLICommand) async throws -> CommandResult {
            XCTFail("No helper or reader execution in presentation regression"); throw TransportError.launchFailed
        }
    }
    private func composition() async throws -> (SettingsApplicationCoordinator, CommunityConnectionIntegration, Port) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cancel-presentation-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let application = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), apply: { _ in })
        await application.reload()
        _ = try await application.editor.completeFirstRun(options: .init(preferences: application.editor.snapshot!.preferences),
            action: .done, host: .standalone, expectedRevision: application.editor.snapshot!.revision)
        let port = try Port(), desktop = Desktop()
        let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: desktop, normal: desktop))
        let base = CommunitySettingsSession(application: application, canPresent: { false }, environment: { .init() }, activate: {})
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: application, backend: backend, canPresent: { false })
        try CommunityConnectionWiring.requireInstalled(entry, application: application, backend: backend)
        await entry.restorePreferences()
        XCTAssertEqual(application.editor.connections.phase, .idle)
        XCTAssertTrue(application.editor.connections.snapshot?.tools.contains { $0.authorization == .allowed } == true)
        return (application, entry, port)
    }
    func testHidingAnIdleConnectionsSurfaceDoesNotClaimARequestWasCancelled() async throws {
        let (application, entry, port) = try await composition()
        defer { entry.flow.dispose() }
        let view = SettingsConnectionsView(editor: application.editor)
        view.suspend() // SettingsWindowController hides the connections page on its initial General pane.
        XCTAssertEqual(application.editor.connections.phase, .idle)
        XCTAssertFalse(SettingsConnectionPresentation.status(application.editor.connections.phase).chinese.contains("取消"))
        XCTAssertEqual(port.reads, 1); XCTAssertEqual(port.mutations, 0); XCTAssertNil(view.window)
    }
    func testLifecycleSuspensionOfAnIdleFactoryDoesNotInventUserCancellation() async throws {
        let (application, entry, port) = try await composition()
        defer { entry.flow.dispose() }
        entry.suspend()
        XCTAssertEqual(application.editor.connections.phase, .idle)
        XCTAssertEqual(port.reads, 1); XCTAssertEqual(port.mutations, 0)
    }
    func testInactiveSecondSurfaceCannotRetireCanonicalInspectionOwnedElsewhere() async throws {
        let (application, entry, port) = try await composition()
        defer { entry.flow.dispose() }
        let inactive = SettingsConnectionsView(editor: application.editor)
        port.paused = true
        let read = Task { await application.editor.connections.refresh() }
        for _ in 0..<100 where port.pending == nil { await Task.yield() }
        let pending = try XCTUnwrap(port.pending)
        inactive.suspend()
        XCTAssertEqual(application.editor.connections.phase, .loading)
        pending.resume(returning: port.value); await read.value
        XCTAssertEqual(application.editor.connections.phase, .idle)
        XCTAssertEqual(port.reads, 2); XCTAssertEqual(port.mutations, 0)
    }
    func testOwnedInspectionSuspensionRejectsLateReceiptAndAllowsANewCheck() async throws {
        let (application, entry, port) = try await composition()
        defer { entry.flow.dispose() }
        let controller = application.editor.connections, original = controller.snapshot
        let presentation = UUID()
        port.paused = true
        let read = Task { await controller.refresh(presentationID: presentation) }
        for _ in 0..<100 where port.pending == nil { await Task.yield() }
        let pending = try XCTUnwrap(port.pending)
        controller.suspend(presentationID: presentation)
        XCTAssertEqual(controller.phase, .idle)
        pending.resume(returning: port.value); await read.value
        XCTAssertEqual(controller.snapshot, original); XCTAssertEqual(controller.phase, .idle)
        port.paused = false
        await controller.refresh(presentationID: presentation)
        XCTAssertEqual(controller.phase, .idle); XCTAssertEqual(port.reads, 3); XCTAssertEqual(port.mutations, 0)
    }
    func testOnlyTheConfirmationOwnerCanRetireItsPendingRequest() async throws {
        let (application, entry, port) = try await composition()
        defer { entry.flow.dispose() }
        let owner = SettingsConnectionsView(editor: application.editor)
        let other = SettingsConnectionsView(editor: application.editor)
        func find(_ view: NSView) -> ConnectionButton? {
            if let button = view as? ConnectionButton, button.accessibilityIdentifier() == "connections.disconnect.codex" { return button }
            return view.subviews.lazy.compactMap(find).first
        }
        let button = try XCTUnwrap(find(owner)); XCTAssertTrue(button.isEnabled)
        button.invoke?() // Synthetic action dispatch without presenting a window.
        guard case .awaitingConfirmation(let request) = application.editor.connections.phase else { return XCTFail("Expected confirmation") }
        other.suspend()
        XCTAssertEqual(application.editor.connections.phase, .awaitingConfirmation(request))
        owner.suspend()
        XCTAssertEqual(application.editor.connections.phase, .idle)
        await application.editor.connections.confirm(request.id)
        XCTAssertEqual(port.mutations, 0); XCTAssertEqual(port.reads, 1)
    }
    func testExplicitUserCancellationStillHasCancelledCopyAndCheckRecovers() async throws {
        let (application, entry, port) = try await composition()
        defer { entry.flow.dispose() }
        let controller = application.editor.connections
        let request = try XCTUnwrap(controller.requestForget(.codex))
        controller.cancel()
        XCTAssertEqual(controller.phase, .cancelled)
        XCTAssertTrue(SettingsConnectionPresentation.status(controller.phase).chinese.contains("取消"))
        await controller.confirm(request.id)
        XCTAssertEqual(port.mutations, 0)
        await controller.refresh()
        XCTAssertEqual(controller.phase, .idle); XCTAssertEqual(port.reads, 2)
    }

    func testCheckHiddenBeforeItsTaskStartsCannotPublishCancelledCopy() async throws {
        let (application, entry, port) = try await composition()
        defer { entry.flow.dispose() }
        let view = SettingsConnectionsView(editor: application.editor)
        func find(_ view: NSView) -> ConnectionButton? {
            if let button = view as? ConnectionButton, button.accessibilityIdentifier() == "connections.detect" { return button }
            return view.subviews.lazy.compactMap(find).first
        }
        let button = try XCTUnwrap(find(view)); XCTAssertTrue(button.isEnabled)
        button.invoke?(); view.suspend()
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(application.editor.connections.phase, .idle)
        XCTAssertEqual(port.reads, 1); XCTAssertEqual(port.mutations, 0)
    }

    func testOtherSurfaceQueuedConfirmCannotCancelTheOwnersConfirmation() async throws {
        let (application, entry, port) = try await composition()
        defer { entry.flow.dispose() }
        let owner = SettingsConnectionsView(editor: application.editor)
        let other = SettingsConnectionsView(editor: application.editor)
        func find(_ view: NSView, _ id: String) -> ConnectionButton? {
            if let button = view as? ConnectionButton, button.accessibilityIdentifier() == id { return button }
            return view.subviews.lazy.compactMap { find($0, id) }.first
        }
        let forget = try XCTUnwrap(find(owner, "connections.disconnect.codex"))
        XCTAssertTrue(forget.isEnabled); forget.invoke?()
        guard case .awaitingConfirmation(let request) = application.editor.connections.phase else { return XCTFail("Expected owner's confirmation") }
        let confirm = try XCTUnwrap(find(other, "connections.confirm"))
        XCTAssertTrue(confirm.isEnabled); confirm.invoke?(); other.suspend()
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(application.editor.connections.phase, .awaitingConfirmation(request))
        XCTAssertEqual(port.reads, 1); XCTAssertEqual(port.mutations, 0)
        let cancel = try XCTUnwrap(find(owner, "connections.cancel"))
        XCTAssertTrue(cancel.isEnabled); cancel.invoke?()
        XCTAssertEqual(application.editor.connections.phase, .cancelled)
        await application.editor.connections.confirm(request.id)
        XCTAssertEqual(port.mutations, 0)
    }

    func testConfirmingSurfaceOwnsTheDispatchedRequestWhenItSuspends() async throws {
        let (application, entry, port) = try await composition()
        defer { entry.flow.dispose() }
        let owner = SettingsConnectionsView(editor: application.editor)
        let confirming = SettingsConnectionsView(editor: application.editor)
        func find(_ view: NSView, _ id: String) -> ConnectionButton? {
            if let button = view as? ConnectionButton, button.accessibilityIdentifier() == id { return button }
            return view.subviews.lazy.compactMap { find($0, id) }.first
        }
        try XCTUnwrap(find(owner, "connections.disconnect.codex")).invoke?()
        guard case .awaitingConfirmation = application.editor.connections.phase else { return XCTFail("Expected confirmation") }
        port.paused = true
        try XCTUnwrap(find(confirming, "connections.confirm")).invoke?()
        for _ in 0..<100 where port.pending == nil { await Task.yield() }
        let pending = try XCTUnwrap(port.pending)
        let before = application.editor.connections.snapshot
        owner.suspend()
        XCTAssertTrue(application.editor.connections.isBusy, "The initiating surface no longer owns this dispatched confirmation")
        confirming.suspend()
        XCTAssertEqual(application.editor.connections.phase, .idle)
        pending.resume(returning: port.value)
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(application.editor.connections.phase, .idle)
        XCTAssertEqual(application.editor.connections.snapshot, before)
        XCTAssertEqual(port.mutations, 0)
    }

}
