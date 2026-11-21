// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore

/// Presentation only: the containing app supplies its existing, freshness-filtered Dock projection.
public struct CommunityMenuBarPresentation: Equatable, Sendable {
    public let title: String
    public let detail: String
    public init(title: String, detail: String) { self.title = title; self.detail = detail }
    public static let empty = emptyReading(chinese: false)
    /// One language only (SET-9-38): the caller passes the chosen language.
    public static func emptyReading(chinese: Bool) -> Self {
        Self(title: "", detail: chinese ? "暂无可显示的当前读数，请打开设置" : "No current reading to show — open Settings")
    }
}
@MainActor public protocol CommunityMenuBarProviding {
    func make(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics, now: Date) -> CommunityMenuBarPresentation
}
