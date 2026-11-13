// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

@MainActor final class B23FirstRunAccessibilityTests:XCTestCase {
    func testFirstRunHasStableLocalizedFocusOrderAndThemeMetadataWithoutPresentation() async throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("b23-first-run-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:directory)}
        let store=try SettingsStore(url:directory.appendingPathComponent("preferences.json"))
        let editor=SettingsEditor(store:store),controller=SettingsFirstRunController(editor:editor)
        await controller.prepare()
        let buttons=OptionalReaderID.allCases.compactMap{controller.readerButtons[$0]}+[controller.loginButton,controller.doneButton,controller.helpButton]
        XCTAssertTrue(controller.window?.initialFirstResponder === buttons.first)
        for (a,b) in zip(buttons,buttons.dropFirst()){XCTAssertTrue(a.nextKeyView === b)}
        for language in [SettingsLanguage.chinese,.english] {
            for theme in [SettingsTheme.day,.night] {
                try await store.update{$0.language=language;$0.theme=theme};await editor.reload()
                XCTAssertEqual(controller.window?.appearance?.name,theme == .day ? .aqua:.darkAqua)
                let page=try FirstRunPage(preferences:editor.snapshot!.preferences,context:editor.context)
                XCTAssertEqual(controller.loginButton.accessibilityHelp(),page.loginSubtitle.value(language))
                XCTAssertEqual(controller.doneButton.title,language == .chinese ? "完成":"Done")
                XCTAssertTrue(controller.window?.initialFirstResponder === buttons.first)
                for (index,id) in OptionalReaderID.allCases.enumerated(){XCTAssertTrue(controller.readerButtons[id] === buttons[index])}
            }
        }
        controller.suspend();controller.close()
    }
}
