// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

final class StructureTests: XCTestCase {
    private func oneStep() throws -> OnboardingDefinition {
        try .init(steps: [.init(id: .init(rawValue: "synthetic-setup"), title: .init("Synthetic setup", "合成设置"))])
    }
    private func file() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("modelplan-structure-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("preferences.json")
    }
    func testRegroupingAndOrderComeOnlyFromInputWithoutChangingPreferenceValues() throws {
        let p = SettingsPreferences(), context = SettingsPageContext()
        let original = try SettingsCatalogue.rows(preferences: p, context: context)
        let keys = Array(SettingKey.allCases.reversed())
        let structure = try SettingsStructure(panes: [
            .init(id: "synthetic-first", title: .init("Synthetic first", "合成第一组"), groups: [
                .init(id: "top", title: .init("Synthetic top", "合成上组"), keys: Array(keys.prefix(3))),
                .init(id: "next", title: .init("Synthetic next", "合成下组"), keys: Array(keys.dropFirst(3).prefix(5))),
            ]),
            .init(id: "synthetic-second", title: .init("Synthetic second", "合成第二组"), groups: [.init(id: "rest", keys: Array(keys.dropFirst(8)))]),
        ])
        let regrouped = try SettingsCatalogue.rows(preferences: p, context: context, structure: structure)
        XCTAssertEqual(regrouped.map(\.key), keys)
        XCTAssertEqual(Array(regrouped.prefix(3)).map(\.groupID), Array(repeating: "top", count: 3))
        XCTAssertEqual(Array(regrouped.prefix(8)).map(\.paneID), Array(repeating: "synthetic-first", count: 8))
        let values = Dictionary(uniqueKeysWithValues: original.map { ($0.key, $0.value) })
        XCTAssertTrue(regrouped.allSatisfy { values[$0.key] == $0.value })
        let selected = try SettingsCatalogue.rows(preferences: p, context: context, paneID: "synthetic-second", structure: structure)
        XCTAssertEqual(selected.map(\.key), Array(keys.dropFirst(8)))
        XCTAssertEqual(try SettingsCatalogue.rows(preferences: p, context: context, query: "合成上组", structure: structure).map(\.key), Array(keys.prefix(3)))
        XCTAssertEqual(try SettingsCatalogue.rows(preferences: p, context: context, query: "Synthetic second", structure: structure).map(\.key), Array(keys.dropFirst(8)))
        XCTAssertNil(regrouped.first?.pane) // Custom IDs are not confined to the draft enum.
    }
    func testInvalidTablesFailRatherThanDroppingOrDuplicatingControls() throws {
        let all = SettingKey.allCases
        func pane(_ id: String, _ groups: [SettingsGroupDefinition]) -> SettingsPaneDefinition { .init(id: id, title: .init("Test", "测试"), groups: groups) }
        XCTAssertNoThrow(try SettingsStructure(panes: SettingsStructure.provisional.panes))
        XCTAssertThrowsError(try SettingsStructure(panes: []))
        XCTAssertThrowsError(try SettingsStructure(panes: [pane("a", [.init(id: "one", keys: Array(all.dropFirst()))])]))
        XCTAssertThrowsError(try SettingsStructure(panes: [pane("a", [.init(id: "one", keys: all + [.theme])])]))
        XCTAssertThrowsError(try SettingsStructure(panes: [pane("a", [.init(id: "one", keys: all)]), pane("a", [.init(id: "two", keys: [.theme])])]))
        XCTAssertThrowsError(try SettingsStructure(panes: [pane("a", [.init(id: "one", keys: [.theme]), .init(id: "one", keys: Array(all.dropFirst()))])]))
        XCTAssertThrowsError(try SettingsStructure(panes: [pane("", [.init(id: "one", keys: all)])]))
    }
    func testOneStepFlowDerivesStartEndCompletionAndReplayFromItsDefinition() throws {
        let flow = try oneStep(); var state = OnboardingState(definition: flow)
        XCTAssertEqual(state.step.rawValue, "synthetic-setup"); XCTAssertFalse(state.completed)
        state.back(in: flow); XCTAssertEqual(state.step, flow.steps[0].id)
        state.demonstrateTrial(in: flow); XCTAssertFalse(state.trialDemonstrated)
        state.recordLesson(.hold, holdAvailable: true, in: flow); XCTAssertNil(state.lesson)
        state.next(in: flow); XCTAssertTrue(state.completed); XCTAssertTrue(state.isValid(in: flow))
        state.next(in: flow); state.back(in: flow); XCTAssertTrue(state.completed)
        var restored = try JSONDecoder().decode(OnboardingState.self, from: JSONEncoder().encode(state))
        restored.reconcile(in: flow); XCTAssertEqual(restored, state)
        restored.replay(in: flow); XCTAssertFalse(restored.completed); XCTAssertEqual(restored.step, flow.steps[0].id)
    }
    func testReorderedFlowUsesDeclaredPositionsAndCapabilities() throws {
        let flow = try OnboardingDefinition(steps: [
            .init(id: .dockLocation, title: .init("First", "第一步"), capabilities: .dockLesson),
            .init(id: .welcome, title: .init("Middle", "中间"), capabilities: .trialDemo),
            .init(id: .detectedSubscriptions, title: .init("Last", "最后")),
        ])
        var state = OnboardingState(definition: flow)
        state.recordLesson(.quick, holdAvailable: false, in: flow); XCTAssertEqual(state.lesson, .quick)
        state.next(in: flow); XCTAssertEqual(state.step, .welcome)
        state.demonstrateTrial(in: flow); XCTAssertTrue(state.trialDemonstrated)
        state.back(in: flow); XCTAssertEqual(state.step, .dockLocation)
        state.next(in: flow); state.next(in: flow); XCTAssertEqual(state.step, .detectedSubscriptions); XCTAssertFalse(state.completed)
        state.next(in: flow); XCTAssertTrue(state.completed)
        state.reconcile(); XCTAssertFalse(state.completed); XCTAssertEqual(state.step, .welcome) // Old completion is not the new final step.
    }
    func testChangedDefinitionCannotReuseCompletionEvenWhenFinalIDStaysTheSame() throws {
        let start = OnboardingStepDefinition(id: .init(rawValue: "start"), title: .init("Start", "开始"))
        let finish = OnboardingStepDefinition(id: .init(rawValue: "finish"), title: .init("Finish", "结束"))
        let before = try OnboardingDefinition(steps: [start, finish])
        let after = try OnboardingDefinition(steps: [start, .init(id: .init(rawValue: "extra"), title: .init("Extra", "附加")), finish])
        var state = OnboardingState(definition: before); state.next(in: before); state.next(in: before)
        XCTAssertTrue(state.completed)
        var restored = try JSONDecoder().decode(OnboardingState.self, from: JSONEncoder().encode(state))
        restored.reconcile(in: after)
        XCTAssertFalse(restored.completed); XCTAssertEqual(restored.step, start.id)
        restored.next(in: after); XCTAssertEqual(restored.step.rawValue, "extra")
    }
    func testInvalidDefinitionsAndObsoleteProgressRecoverSafely() throws {
        XCTAssertThrowsError(try OnboardingDefinition(steps: []))
        let step = OnboardingStepDefinition(id: .welcome, title: .init("Test", "测试"))
        XCTAssertThrowsError(try OnboardingDefinition(steps: [step, step]))
        XCTAssertThrowsError(try OnboardingDefinition(steps: [.init(id: .init(rawValue: ""), title: .init("Test", "测试"))]))
        XCTAssertThrowsError(try OnboardingDefinition(steps: [.init(id: .welcome, title: .init("Test", "测试"), capabilities: .init(rawValue: 4))]))
        let flow = try oneStep()
        for data in ["{\"step\":99,\"completed\":true}", "{\"step\":\"removed\",\"completed\":true}", "{\"step\":{},\"completed\":true}", "{\"step\":\"\",\"completed\":true}", "{}"] {
            var state = try JSONDecoder().decode(OnboardingState.self, from: Data(data.utf8))
            state.reconcile(in: flow)
            XCTAssertEqual(state.step, flow.steps[0].id); XCTAssertFalse(state.completed)
            XCTAssertNil(state.lesson); XCTAssertFalse(state.trialDemonstrated)
        }
        var legacy = try JSONDecoder().decode(OnboardingState.self, from: Data("{\"step\":2}".utf8))
        legacy.reconcile(); XCTAssertEqual(legacy.step, .detectedSubscriptions)
    }
    func testCustomFlowRestartAndDefinitionChangePreserveUnrelatedPreferences() async throws {
        let url = try file(), flow = try oneStep(), store = try SettingsStore(url: url, onboardingDefinition: flow)
        let initial = await store.snapshot(); XCTAssertEqual(initial.preferences.onboarding.step, flow.steps[0].id)
        try await store.update { p in p.theme = .night; p.showProjectNames = false; p.onboarding.next(in: flow) }
        let bytes = try Data(contentsOf: url)
        let restarted = try SettingsStore(url: url, onboardingDefinition: flow)
        let restored = await restarted.snapshot()
        XCTAssertTrue(restored.preferences.onboarding.completed); XCTAssertEqual(restored.preferences.onboarding.step, flow.steps[0].id)
        let changed = try SettingsStore(url: url)
        let recovered = await changed.snapshot()
        XCTAssertFalse(recovered.preferences.onboarding.completed); XCTAssertEqual(recovered.preferences.onboarding.step, .welcome)
        XCTAssertEqual(recovered.preferences.theme, .night); XCTAssertFalse(recovered.preferences.showProjectNames)
        XCTAssertFalse(recovered.preferences.notifications.optedIn); XCTAssertEqual(try Data(contentsOf: url), bytes) // Read never rewrites recovery.
    }
    func testInvalidStoredProgressRecoversWithoutResettingPrivacyOrFile() async throws {
        let url = try file(), flow = try oneStep()
        let json = "{\"schemaVersion\":1,\"preferences\":{\"showProjectNames\":false,\"theme\":\"night\",\"onboarding\":{\"step\":\"\",\"completed\":true}}}"
        try Data(json.utf8).write(to: url)
        let store = try SettingsStore(url: url, onboardingDefinition: flow), snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.preferences.onboarding.step, flow.steps[0].id); XCTAssertFalse(snapshot.preferences.onboarding.completed)
        XCTAssertFalse(snapshot.preferences.showProjectNames); XCTAssertFalse(snapshot.preferences.notifications.optedIn)
        XCTAssertEqual(snapshot.preferences.theme, .night); XCTAssertEqual(try String(contentsOf: url), json)
    }
}
