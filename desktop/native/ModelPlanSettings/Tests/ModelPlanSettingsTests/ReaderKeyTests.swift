// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// Synthetic keys only.
private let fakeKey = "fake-test-key-0001"

@MainActor private final class FakeKeyBackend: ReaderKeyBackend {
    struct Call: Equatable { let verb: String; let key: String?; let region: ReaderKeyRegion? }
    private(set) var calls: [Call] = []
    private(set) var allowed: [ReaderKeyProvider] = []
    private var stored: ReaderKeyStatus
    var testOutcome: ReaderKeyOutcome = .ok
    var allowResult = true
    init(stored: ReaderKeyStatus = .init(present: false, region: nil)) { self.stored = stored }
    func setTestOutcome(_ outcome: ReaderKeyOutcome) { testOutcome = outcome }
    func status(_ provider: ReaderKeyProvider) async -> ReaderKeyStatus { stored }
    func set(_ provider: ReaderKeyProvider, key: String, region: ReaderKeyRegion?) async -> ReaderKeyReply {
        calls.append(.init(verb: "set", key: key, region: region)); stored = .init(present: true, region: region)
        return .init(outcome: .saved, status: stored)
    }
    func test(_ provider: ReaderKeyProvider, key: String?, region: ReaderKeyRegion?) async -> ReaderKeyReply {
        calls.append(.init(verb: "test", key: key, region: region)); return .init(outcome: testOutcome, status: stored)
    }
    func remove(_ provider: ReaderKeyProvider) async -> ReaderKeyReply {
        calls.append(.init(verb: "remove", key: nil, region: nil)); stored = .init(present: false, region: nil)
        return .init(outcome: .removed, status: stored)
    }
    func allowReading(_ provider: ReaderKeyProvider) async -> Bool { allowed.append(provider); return allowResult }
}

@MainActor final class ReaderKeyTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { view.subviews + view.subviews.flatMap(descendants) }
    private func find<T: NSView>(_ root: NSView, _ id: String, as: T.Type) -> T? {
        descendants(root).first { $0.accessibilityIdentifier() == id } as? T
    }
    private func type(_ view: ReaderKeyEntryView, _ text: String) {
        let id = "readerkey." + view.entry.provider.rawValue
        let field = find(view, id + ".field", as: NSSecureTextField.self)!
        field.stringValue = text
        view.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
    }
    private func button(_ view: ReaderKeyEntryView, _ verb: String) -> ConnectionButton {
        find(view, "readerkey." + view.entry.provider.rawValue + "." + verb, as: ConnectionButton.self)!
    }
    private func made(_ provider: ReaderKeyProvider, _ backend: FakeKeyBackend, language: SettingsLanguage = .english) -> ReaderKeyEntryView {
        ReaderKeyEntryView(entry: .init(provider: provider, backend: backend), language: language)
    }

    func testFieldIsSecureAndButtonsFollowWhatWasTyped() async {
        let view = made(.zai, FakeKeyBackend())
        await view.entry.load()
        XCTAssertNotNil(find(view, "readerkey.zai.field", as: NSSecureTextField.self))
        XCTAssertNotNil(find(view, "readerkey.zai.region", as: NSPopUpButton.self))
        XCTAssertFalse(button(view, "test").isEnabled); XCTAssertFalse(button(view, "save").isEnabled)
        XCTAssertFalse(button(view, "remove").isEnabled)
        type(view, "  " + fakeKey + "\n")
        XCTAssertTrue(button(view, "test").isEnabled); XCTAssertTrue(button(view, "save").isEnabled)
        XCTAssertFalse(button(view, "remove").isEnabled, "nothing is saved yet")
    }
    func testOpenCodeGoHasNoRegionPicker() {
        let view = made(.opencodego, FakeKeyBackend())
        XCTAssertNil(find(view, "readerkey.opencodego.region", as: NSPopUpButton.self))
        XCTAssertNotNil(find(view, "readerkey.opencodego.field", as: NSSecureTextField.self))
    }
    func testSaveSendsTrimmedKeyWithRegionThenClearsTheField() async {
        let backend = FakeKeyBackend()
        let view = made(.zai, backend)
        await view.entry.load()
        view.entry.region = .china
        type(view, "  " + fakeKey + "\n")
        await view.entry.save()
        let calls = backend.calls
        XCTAssertEqual(calls, [.init(verb: "test", key: fakeKey, region: .china), .init(verb: "set", key: fakeKey, region: .china)], "Save tests the key first")
        XCTAssertEqual(backend.allowed, [.zai], "a saved key turns that provider on")
        XCTAssertEqual(find(view, "readerkey.zai.field", as: NSSecureTextField.self)?.stringValue, "", "the typed key must not stay on screen")
        XCTAssertEqual(view.entry.typed, "")
        XCTAssertTrue(button(view, "remove").isEnabled)
        XCTAssertEqual(find(view, "readerkey.zai.result", as: NSTextField.self)?.stringValue, ReaderKeyOutcome.saved.message.english)
    }
    func testTestUsesTypedKeyThenTheSavedOneAndShowsRefusedAndLapsedApart() async {
        let backend = FakeKeyBackend(stored: .init(present: true, region: .global))
        let view = made(.zai, backend)
        await view.entry.load()
        XCTAssertTrue(button(view, "test").isEnabled, "a saved key can be tested with an empty field")
        backend.setTestOutcome(.keyRefused)
        await view.entry.test()
        let refused = find(view, "readerkey.zai.result", as: NSTextField.self)?.stringValue
        backend.setTestOutcome(.planLapsed)
        type(view, fakeKey)
        await view.entry.test()
        let lapsed = find(view, "readerkey.zai.result", as: NSTextField.self)?.stringValue
        XCTAssertNotEqual(refused, lapsed)
        XCTAssertEqual(refused, ReaderKeyOutcome.keyRefused.message.english)
        XCTAssertEqual(lapsed, ReaderKeyOutcome.planLapsed.message.english)
        let calls = backend.calls
        XCTAssertEqual(calls.map(\.key), [nil, fakeKey])
    }
    func testSaveAfterAnOkTestDoesNotTestAgainAndABadKeyIsNeverSaved() async {
        let backend = FakeKeyBackend()
        let view = made(.zai, backend)
        type(view, fakeKey); await view.entry.test(); await view.entry.save()
        XCTAssertEqual(backend.calls.map(\.verb), ["test", "set"])
        let bad = FakeKeyBackend(); bad.setTestOutcome(.keyRefused)
        let other = made(.zai, bad)
        type(other, fakeKey); await other.entry.save()
        XCTAssertEqual(bad.calls.map(\.verb), ["test"], "a refused key is not saved")
        XCTAssertTrue(bad.allowed.isEmpty)
        XCTAssertEqual(find(other, "readerkey.zai.result", as: NSTextField.self)?.stringValue, ReaderKeyOutcome.keyRefused.message.english)
    }
    func testFailedConsentGrantIsReportedNotHidden() async {
        let backend = FakeKeyBackend(); backend.allowResult = false
        let view = made(.opencodego, backend)
        type(view, fakeKey); await view.entry.save()
        XCTAssertTrue(find(view, "readerkey.opencodego.result", as: NSTextField.self)!.stringValue.contains("Permissions"))
        XCTAssertTrue(backend.calls.map(\.verb).contains("set"))
    }
    func testRemoveDropsTheSavedKey() async {
        let backend = FakeKeyBackend(stored: .init(present: true, region: .china))
        let view = made(.zai, backend)
        await view.entry.load()
        XCTAssertEqual(view.entry.region, .china, "the saved region comes back")
        await view.entry.remove()
        let calls = backend.calls
        XCTAssertEqual(calls.map(\.verb), ["remove"])
        XCTAssertFalse(button(view, "remove").isEnabled)
    }
    func testButtonPressRunsTheEngineCall() async {
        let backend = FakeKeyBackend()
        let view = made(.opencodego, backend)
        type(view, fakeKey)
        button(view, "save").invoke?()
        for _ in 0..<500 { if backend.calls.count >= 2 { break }; await Task.yield() }
        let calls = backend.calls
        XCTAssertEqual(calls, [.init(verb: "test", key: fakeKey, region: nil), .init(verb: "set", key: fakeKey, region: nil)])
    }
    func testHelpLineAndBothLanguages() {
        let zh = made(.zai, FakeKeyBackend(), language: .chinese)
        let help = descendants(zh).compactMap { ($0 as? NSTextField)?.stringValue }
        XCTAssertTrue(help.contains("保存在本机，只发送到 api.z.ai / open.bigmodel.cn 用于读取套餐用量"))
        XCTAssertEqual(button(zh, "save").title, "保存")
        let go = made(.opencodego, FakeKeyBackend(), language: .english)
        XCTAssertTrue(descendants(go).compactMap { ($0 as? NSTextField)?.stringValue }.contains("Stored on this Mac and sent only to opencode.ai to read plan usage"))
    }
    func testDismissClearsTheTypedKey() {
        let view = made(.zai, FakeKeyBackend())
        type(view, fakeKey)
        view.entry.dismiss()
        XCTAssertEqual(find(view, "readerkey.zai.field", as: NSSecureTextField.self)?.stringValue, "")
    }
    func testWireOutcomeWordsMap() {
        XCTAssertEqual(ReaderKeyOutcome(wire: "key_refused"), .keyRefused)
        XCTAssertEqual(ReaderKeyOutcome(wire: "plan_lapsed"), .planLapsed)
        XCTAssertEqual(ReaderKeyOutcome(wire: "anything else"), .failed)
        for outcome in [ReaderKeyOutcome.saved, .removed, .ok, .keyRefused, .planLapsed, .noKey, .unreachable, .failed, .notAccepted] {
            XCTAssertFalse(outcome.message.english.isEmpty); XCTAssertFalse(outcome.message.chinese.isEmpty)
            XCTAssertFalse(outcome.message.english.contains(fakeKey))
        }
    }
}
