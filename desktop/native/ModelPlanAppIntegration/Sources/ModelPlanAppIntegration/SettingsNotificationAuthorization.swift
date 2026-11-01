// SPDX-License-Identifier: MIT
import ModelPlanSettings

/// OS boundary; implementations observe or request authorization only when asked.
@MainActor public protocol SettingsNotificationAuthorizationServing: AnyObject {
    func authorization() async -> NotificationAuthorization
    func requestAuthorization() async -> NotificationAuthorization
}
