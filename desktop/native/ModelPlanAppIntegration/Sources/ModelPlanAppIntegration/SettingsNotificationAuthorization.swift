// SPDX-License-Identifier: MIT
import ModelPlanSettings
import UserNotifications

/// OS boundary; implementations observe or request authorization only when asked.
@MainActor public protocol SettingsNotificationAuthorizationServing: AnyObject {
    func authorization() async -> NotificationAuthorization
    func requestAuthorization() async -> NotificationAuthorization
}

/// A real OS request is made only in response to an explicit, admitted opt-in.
@MainActor final class SystemNotificationAuthorizationService: SettingsNotificationAuthorizationServing {
    func authorization() async -> NotificationAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        @unknown default: return .unavailable
        }
    }
    func requestAuthorization() async -> NotificationAuthorization {
        do { _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
        catch { return .unavailable }
        return await authorization()
    }
}
