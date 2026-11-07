// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// CKP-MFD-24, reader leg (SPEC 6.6) through the real window: reader rows carry "What it reads ↗",
/// local readers link /privacy#local and opt-in readers /privacy#controls, in both languages.
@MainActor final class SettingsReaderLinkTests: XCTestCase {
    private func open(_ language: SettingsLanguage) async throws -> (SettingsWindowController, SettingsEditor) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("settings-reads-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try SettingsStore(url: directory.appendingPathComponent("preferences.json"))
        try await store.update { $0.language = language }
        let editor = SettingsEditor(store: store)
        editor.onHostRequest = { _ in }
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare(); controller.selectPane("subscriptions")
        return (controller, editor)
    }

    func testReaderRowsLinkTheirPrivacyAnchors() async throws {
        let (controller, editor) = try await open(.english)
        var intents: [SettingsHostIntent] = []
        editor.onHostRequest = { intents.append($0.intent) }
        let detected = try XCTUnwrap(controller.actionControl(key: .detectedReaders))
        XCTAssertEqual(detected.title, "What it reads ↗")
        XCTAssertTrue(detected.sendAction(detected.action, to: detected.target))
        XCTAssertEqual(intents, [.openPublicLink(.privacyLocal)])
        XCTAssertEqual(SettingsPublicLink.privacyLocal.url.absoluteString, "https://modelplan.ai/privacy#local")
        XCTAssertEqual(SettingsPublicLink.privacyControls.url.absoluteString, "https://modelplan.ai/privacy#controls")
        for id in OptionalReaderID.allCases.map(\.rawValue) {
            guard let link = controller.readerLink(id: id) else { continue }
            intents = []
            XCTAssertEqual(link.title, "What it reads ↗")
            XCTAssertTrue(link.sendAction(link.action, to: link.target))
            XCTAssertEqual(intents, [.openPublicLink(.privacyControls)])
        }
        controller.close()
    }

    func testLinkTitleIsChineseInChinese() async throws {
        let (controller, _) = try await open(.chinese)
        XCTAssertEqual(try XCTUnwrap(controller.actionControl(key: .detectedReaders)).title, "读取了什么 ↗")
        controller.close()
    }
}
