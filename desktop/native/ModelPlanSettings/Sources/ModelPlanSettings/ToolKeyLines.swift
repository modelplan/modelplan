// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

/// Plain key lines for a tool row, shared by the Settings view (main actor) and the pure row model
/// (`SubscriptionRowModel`, nonisolated). Text only; nothing here reads a key.
public enum ToolKeyLines {
    public static func hasOpenCodeGoSubscription(_ tool: FirstRunTool) -> Bool { tool.routes.contains(.apiKeyApi) }
    /// G3-105: an installed tool whose subscription key is missing, in plain words; nil keeps the generic row.
    /// #910-2: detection also counts the OpenCode Go sign-in OpenCode saved itself, but the reader takes the key
    /// only from OPENCODE_API_KEY (D230: the saved key is checked for existence, never read). So a found
    /// subscription with the engine's key_missing row still says why no quota is shown.
    /// D90: with the optional key entry on the row (Settings), the line also points to it.
    public static func keyMissingLine(_ tool: FirstRunTool, keyEntry: Bool = false) -> SettingsText? {
        guard tool.tool == "opencodego" else { return nil }
        if keyEntry {
            if hasOpenCodeGoSubscription(tool) {
                return .init("An OpenCode Go sign-in was found, but ModelPlan does not read it, so no OpenCode Go quota is shown. Set the key in OPENCODE_API_KEY, or add it below, to show it. OpenCode's local history is still read.",
                             "找到了 OpenCode Go 登录，但 ModelPlan 不读取它，因此不显示 OpenCode Go 额度；把密钥设置到 OPENCODE_API_KEY 环境变量或在下面添加后才会显示。仍会读取 OpenCode 的本机历史记录。")
            }
            return .init("No OpenCode Go subscription key was found, so no OpenCode Go quota is shown. Add a key below to show it. OpenCode's local history is still read.",
                         "没有找到 OpenCode Go 订阅密钥，因此不显示 OpenCode Go 额度；在下面添加密钥后才会显示。仍会读取 OpenCode 的本机历史记录。")
        }
        if hasOpenCodeGoSubscription(tool) {
            return .init("An OpenCode Go sign-in was found, but ModelPlan does not read it yet, so no OpenCode Go quota is shown. Set the key in OPENCODE_API_KEY to show it. OpenCode's local history is still read.",
                         "找到了 OpenCode Go 登录，但 ModelPlan 暂不读取它，因此不显示 OpenCode Go 额度；把密钥设置到 OPENCODE_API_KEY 环境变量后才会显示。仍会读取 OpenCode 的本机历史记录。")
        }
        return .init("No OpenCode Go subscription key was found, so no OpenCode Go quota is shown. OpenCode's local history is still read.",
                     "没有找到 OpenCode Go 订阅密钥，因此不显示 OpenCode Go 额度；仍会读取 OpenCode 的本机历史记录。")
    }
}
