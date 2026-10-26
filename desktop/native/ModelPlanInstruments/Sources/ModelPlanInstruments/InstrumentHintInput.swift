// SPDX-License-Identifier: MIT
import Foundation

/// Typed consumer input only. The shared M1 arbiter owns dwell admission, the
/// 500 ms deadline, nine-kind priority, per-open/reveal budgets and persistence.
public struct FaderRestAnchor: Equatable, Sendable {
    public static let requiredRest = 0.5
    public let modelID: String, regionID: String
    public let travel: CGRect
    public init(modelID: String, regionID: String, travel: CGRect) {
        self.modelID = modelID; self.regionID = regionID; self.travel = travel
    }
}
public enum InstrumentHintCancellation: Equatable, Sendable {
    case movement, leave, pointerDown, keyboard, focusLoss, removal, layoutChange, teardown
}
public enum InstrumentHintInput: Equatable, Sendable {
    /// Rest begins/restarts here; this is not a request to display or consume a hint.
    case faderRestCandidate(anchor: FaderRestAnchor, pointer: CGPoint, at: Double)
    /// Cancels pending rest only; an already displayed hint remains arbiter-owned.
    case cancelFaderRest(InstrumentHintCancellation, at: Double)
}
public enum InstrumentHelpDefinitions {
    public static func todayAverage(_ language: InstrumentLanguage) -> String {
        language == .chinese
            ? "今日输出；今日平均生成速度为可测速输出 token 总量除以生成秒数总量，不是实时速度；按当前来源关联，非历史账户归属"
            : "Today’s output; today’s average generation speed is summed eligible output tokens divided by summed generation seconds, not live speed; current source binding, not historical account attribution"
    }
    public static func liveSpeed(_ language: InstrumentLanguage) -> String {
        language == .chinese
            ? "近 60 秒生成速度：合格请求至少 5 个样本；-- 表示不可用"
            : "Generation speed in the last 60 seconds; at least 5 eligible samples; -- means unavailable"
    }
}
