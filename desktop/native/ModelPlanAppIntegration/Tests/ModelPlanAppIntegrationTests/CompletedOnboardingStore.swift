// SPDX-License-Identifier: MIT
import ModelPlanSettings

/// Owner 11-12 (E4): on a first launch the cockpit prewarm waits for the setup guide. Tests that exercise the cockpit
/// itself (not the first launch) start from a store whose setup is finished.
func completedOnboarding(_ store: SettingsStore) async throws -> SettingsStore {
    _ = try await store.update { preferences in
        for _ in OnboardingDefinition.task65.steps { preferences.onboarding.next() }
    }
    return store
}
