// SPDX-License-Identifier: MIT
#if DEBUG && MODELPLAN_E2E_JOURNEY
import Foundation

/// Compiled only into the explicitly requested debug CI bundle, never release builds.
public enum CommunityJourneyCI {
    public static var enabled: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["MODELPLAN_APP_SMOKE"] == "1" && env["MODELPLAN_E2E_JOURNEY"] == "1"
    }
    public static var nativePanels: Bool {
        enabled && ProcessInfo.processInfo.environment["MODELPLAN_E2E_NATIVE_PANELS"] == "1"
    }
}
#endif
