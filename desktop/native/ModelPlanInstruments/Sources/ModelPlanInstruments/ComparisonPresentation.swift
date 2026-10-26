// SPDX-License-Identifier: MIT
import Foundation

public enum ComparisonMetric: CaseIterable, Sendable {
    case ability, cost, time
    public func title(_ language: InstrumentLanguage) -> String {
        switch (self, language) {
        case (.ability, .chinese): return "能力"
        case (.cost, .chinese): return "成本"
        case (.time, .chinese): return "耗时"
        case (.ability, .english): return "Ability"
        case (.cost, .english): return "Cost"
        case (.time, .english): return "Time"
        }
    }
}
public struct ComparisonCellDisplay: Equatable, Sendable {
    public let metric: ComparisonMetric
    public let text: String
    public let tableValue: Double?
    public let chartRatio: Double?
}
public struct ComparisonColumnDisplay: Equatable, Sendable {
    public let role: ComparisonRole
    public let title: String, effort: String, equality: String?
    public let configuration: EffortConfiguration?
    public let light: ComparisonLight
    public let cells: [ComparisonCellDisplay]
    public var unlit: Bool { light == .off }
}
public struct ComparisonEffortKey: Equatable, Sendable {
    public let key: String, title: String
    public let current: Bool, trial: Bool, recommended: Bool
}
public struct ComparisonChartProfile: Equatable, Sendable {
    public let configuration: EffortConfiguration
    public let roles: [ComparisonRole]
    public let ratios: [Double?]
    public var primaryRole: ComparisonRole { roles.contains(.current) ? .current : roles.contains(.recommended) ? .recommended : .trial }
}
public struct ComparisonRatioAxis: Equatable, Sendable {
    public let maximum: Double
    public let ticks: [Double]
    public init?(values: [Double]) {
        let highest = max(1, values.filter { $0.isFinite && $0 >= 0 }.max() ?? 1)
        let expanded = highest * 1.08
        guard expanded.isFinite else { return nil }
        let rough = expanded / 4, power = pow(10, floor(log10(rough)))
        guard let step = [1.0, 2, 2.5, 5, 10].map({ $0 * power }).first(where: { $0 >= rough * 0.8 }),
              step.isFinite, step > 0 else { return nil }
        let maximum = ceil(expanded / step) * step, count = (maximum / step).rounded()
        guard maximum.isFinite, maximum >= 1, count.isFinite, count >= 1, count <= 256 else { return nil }
        var ticks = (0...Int(count)).map { Double(String(format: "%.10g", locale: Locale(identifier: "en_US_POSIX"), Double($0) * step))! }
        if !ticks.contains(1) { ticks.append(1) }
        self.maximum = maximum; self.ticks = Array(Set(ticks)).sorted()
    }
}
public struct ComparisonChartPoint: Equatable, Sendable {
    public let metric: ComparisonMetric
    public let ratio: Double
    public let point: CGPoint
}
public struct ComparisonProfileGeometry: Equatable, Sendable {
    public let configuration: EffortConfiguration
    public let roles: [ComparisonRole]
    public let points: [ComparisonChartPoint?]
    public var segments: [[ComparisonChartPoint]] {
        var result: [[ComparisonChartPoint]] = []
        for point in points {
            if let point {
                if result.isEmpty || result.last!.isEmpty { result.append([point]) }
                else { result[result.count - 1].append(point) }
            } else if !result.isEmpty, !result.last!.isEmpty { result.append([]) }
        }
        return result.filter { !$0.isEmpty }
    }
}
public struct ComparisonChartGeometry: Equatable, Sendable {
    public let plot: CGRect
    public let axis: ComparisonRatioAxis
    public let profiles: [ComparisonProfileGeometry]
    public func y(_ ratio: Double) -> Double { plot.maxY - ratio / axis.maximum * plot.height }
}
public struct ComparisonPresentation: Equatable, Sendable {
    public let modelID: String
    public let modelName: String
    public let titleVariants: [String]
    public let columns: [ComparisonColumnDisplay]
    public let efforts: [ComparisonEffortKey]
    public let chartProfiles: [ComparisonChartProfile]
    public let chartAxis: ComparisonRatioAxis?
    public let chartDescription: String
    public let notes: [String]
    public let fastAvailable: Bool
    public let trialFast: Bool
    public let help: HelpExplanation
    public let language: InstrumentLanguage
    public init(model: InstrumentModel, nameVariants: [String] = [], trial: EffortConfiguration?,
                publicationUsable: Bool, language: InstrumentLanguage) {
        self.language = language; modelID = model.id; modelName = model.name
        let chinese = language == .chinese
        let comparison = EffortComparison(model: model, trial: trial, publicationUsable: publicationUsable)
        var names = Set<String>()
        titleVariants = ([model.name] + nameVariants).filter { !$0.isEmpty && names.insert($0).inserted }
            .map { (chinese ? "比较 · " : "Compare · ") + $0 }
        columns = comparison.panels.map { panel in
            let title: String
            switch panel.role {
            case .current: title = chinese ? "当前" : "Current"
            case .trial: title = chinese ? "试" : "Try"
            case .recommended: title = chinese ? "★推荐" : "★ Rec"
            }
            let equality = panel.equalsCurrent && panel.role == .trial ? (chinese ? "= 当前" : "= current")
                : panel.equalsRecommended && panel.role != .recommended ? "= ★" : nil
            let hidden = panel.light == .off
            let cells = ComparisonMetric.allCases.map { metric -> ComparisonCellDisplay in
                let value: Double?, chartRatio: Double?
                switch metric {
                case .ability: value = panel.values?.abilityDelta; chartRatio = panel.values?.abilityRatio
                case .cost: value = panel.values?.costRatio; chartRatio = value
                case .time: value = panel.values?.timeRatio; chartRatio = value
                }
                let text = hidden ? "" : value == nil ? (panel.role == .current ? "--" : "—")
                    : metric == .ability ? Self.delta(value) : Self.multiple(value)
                return .init(metric: metric, text: text, tableValue: hidden ? nil : value, chartRatio: hidden ? nil : chartRatio)
            }
            return ComparisonColumnDisplay(role: panel.role, title: title,
                effort: hidden ? "" : panel.label ?? "--", equality: equality, configuration: panel.configuration,
                light: panel.light, cells: cells)
        }
        chartProfiles = comparison.profiles.map {
            .init(configuration: $0.configuration, roles: $0.roles,
                  ratios: [$0.values.abilityRatio, $0.values.costRatio, $0.values.timeRatio])
        }
        chartAxis = ComparisonRatioAxis(values: chartProfiles.flatMap { $0.ratios.compactMap { $0 } })
        let unknownCurrent = comparison.panels[0].configuration == nil
        chartDescription = unknownCurrent
            ? (chinese ? "当前档位未报告；无法计算相对当前配置的比值，不绘制比较线。" : "Current is unreported; ratios against Current are unavailable and no comparison lines are plotted.")
            : chartProfiles.isEmpty
            ? (chinese ? "当前参考值不可用；不绘制比较线。" : "Current reference values are unavailable; no comparison lines are plotted.")
            : (chinese ? "能力、成本和耗时均与当前配置比较；当前为白色 ×1，试为蓝色，推荐为淡金色。相同配置共享一条线，缺失值保留空隙。" : "Ability, cost and time ratios use Current: white ×1, blue Try and pale-gold recommendation. Equal configurations share one line; missing values remain gaps.")
        fastAvailable = comparison.fastAvailable
        trialFast = comparison.panels[1].configuration?.fast ?? false
        var note: [String] = []
        if unknownCurrent { note.append(chinese ? "当前未报告" : "Current unknown") }
        let fastShown = comparison.panels.contains { $0.configuration?.fast == true }
        if fastShown, let tier = model.fastTier, tier.usable {
            note.append((chinese ? "快速：速度 " : "Fast: speed ") + Self.factor(tier.speedMultiplier) + " · " + (chinese ? "成本 " : "cost ") + Self.factor(tier.costMultiplier))
            if tier.taskTimeUnknown { note.append(chinese ? "快速耗时未提供" : "Fast task time unavailable") }
            if let qualifier = tier.qualifier, !qualifier.isEmpty { note.append(qualifier) }
        }
        if publicationUsable {
            let keys = Set(comparison.panels.compactMap { $0.configuration?.effort })
            for effort in model.efforts where keys.contains(effort.key) {
                for qualifier in [effort.ability.qualifier, effort.cost.qualifier, effort.time.qualifier].compactMap({ $0 }) where !qualifier.isEmpty { note.append(qualifier) }
            }
        }
        var seen = Set<String>(); notes = note.filter { seen.insert($0).inserted }
        let current = comparison.panels[0].configuration, tried = comparison.panels[1].configuration
        var effortIDs = Set<String>()
        efforts = publicationUsable ? model.efforts.filter { effortIDs.insert($0.key).inserted }.map {
            .init(key: $0.key, title: $0.label, current: current?.effort == $0.key, trial: tried?.effort == $0.key && tried != current,
                  recommended: model.recommended == $0.key)
        } : []
        help = HelpCatalog(language).explanation(.comparison, context: .init(fact: model.name + " · " + chartDescription))
    }
    public func chartGeometry(in plot: CGRect) -> ComparisonChartGeometry? {
        guard let axis = chartAxis, [plot.minX, plot.minY, plot.width, plot.height].allSatisfy(\.isFinite),
              plot.width > 0, plot.height > 0 else { return nil }
        let profiles = chartProfiles.map { profile in
            let points = profile.ratios.enumerated().map { i, ratio -> ComparisonChartPoint? in
                guard let ratio else { return nil }
                return .init(metric: ComparisonMetric.allCases[i], ratio: ratio,
                    point: CGPoint(x: plot.minX + Double(i) * plot.width / 2, y: plot.maxY - ratio / axis.maximum * plot.height))
            }
            return ComparisonProfileGeometry(configuration: profile.configuration, roles: profile.roles, points: points)
        }
        return .init(plot: plot, axis: axis, profiles: profiles)
    }
    public static func multiple(_ value: Double?) -> String {
        guard let value = known(value) else { return "—" }
        return "×" + String(format: value >= 10 ? "%.0f" : "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
    public static func delta(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        if abs(value) <= 0.05 { return "±0" }
        return (value > 0 ? "+" : "−") + String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), abs(value))
    }
    private static func factor(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "×" + String(format: "%.8g", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
