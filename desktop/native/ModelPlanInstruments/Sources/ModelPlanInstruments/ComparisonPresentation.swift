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
    public let minimumPower:Int,maximumPower:Int
    public let maximum:Double
    public let ticks:[Double]
    public init?(values:[Double]) {
        let powers=[0.0]+values.filter{$0.isFinite && $0>0}.map{log2($0)}
        var low=floor(powers.min()!),high=ceil(powers.max()!)
        if low==high {low-=1;high+=1}
        guard low>=(-1074),high<=1023,high-low<=256 else{return nil}
        minimumPower=Int(low);maximumPower=Int(high);maximum=pow(2,high)
        ticks=(Int(low)...Int(high)).map{pow(2,Double($0))}
    }
    public func fraction(_ ratio:Double)->Double? {
        guard ratio.isFinite,ratio>0 else{return nil}
        return (Double(maximumPower)-log2(ratio))/Double(maximumPower-minimumPower)
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
public struct ComparisonMetricTrace:Equatable,Sendable {
    public let metric:ComparisonMetric
    public let fast:Bool
    public let points:[ComparisonChartPoint?]
    public var segments:[[ComparisonChartPoint]] {
        var result:[[ComparisonChartPoint]]=[]
        for point in points {
            if let point {if result.isEmpty || result.last!.isEmpty {result.append([point])} else{result[result.count-1].append(point)}}
            else if !result.isEmpty,!result.last!.isEmpty {result.append([])}
        }
        return result.filter{!$0.isEmpty}
    }
}
public struct ComparisonEndpointLabel:Equatable,Sendable {
    public let metric:ComparisonMetric
    public let anchor:CGPoint
    public let y:Double
}
public struct ComparisonChartGeometry: Equatable, Sendable {
    public let plot: CGRect
    public let axis: ComparisonRatioAxis
    public let profiles: [ComparisonProfileGeometry]
    public let traces:[ComparisonMetricTrace]
    public let endpoints:[ComparisonEndpointLabel]
    public let effortKeys:[String]
    public func y(_ ratio:Double)->Double {plot.minY+(axis.fraction(ratio) ?? 1)*plot.height}
    public func x(_ index:Int)->Double {plot.minX+(Double(index)+0.5)*plot.width/Double(max(1,effortKeys.count))}
}
public struct ComparisonEffortSample:Equatable,Sendable {
    public let configuration:EffortConfiguration
    public let ratios:[Double?]
}
public struct ComparisonPresentation: Equatable, Sendable {
    public let modelID: String
    public let modelName: String
    public let titleVariants: [String]
    public let columns: [ComparisonColumnDisplay]
    public let efforts: [ComparisonEffortKey]
    public let chartProfiles: [ComparisonChartProfile]
    public let chartAxis: ComparisonRatioAxis?
    public let publishedSamples:[ComparisonEffortSample]
    public let fastShown:Bool
    public let chartDescription: String
    public let notes: [String]
    public let fastAvailable: Bool
    public let trialFast: Bool
    public let help: HelpExplanation
    public let language: InstrumentLanguage
    public var websiteLinks:[InstrumentWebsiteLink] {[.compare(publicModelID:modelID,language:language),.methodology(comparison:true,language:language)]}
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
        publishedSamples=comparison.publishedSamples.map{.init(configuration:$0.configuration,ratios:[$0.values.abilityRatio,$0.values.costRatio,$0.values.timeRatio])}
        let domain=publishedSamples.flatMap{$0.ratios.compactMap{$0}}+chartProfiles.filter{!$0.roles.contains(.trial)}.flatMap{$0.ratios.compactMap{$0}}
        chartAxis=domain.contains{$0.isFinite && $0>0} ? ComparisonRatioAxis(values:domain):nil
        let unknownCurrent = comparison.panels[0].configuration == nil
        chartDescription = unknownCurrent
            ? (chinese ? "当前档位未报告；无法计算相对当前配置的比值，不绘制比较线。" : "Current is unreported; ratios against Current are unavailable and no comparison lines are plotted.")
            : chartProfiles.isEmpty
            ? (chinese ? "当前参考值不可用；不绘制比较线。" : "Current reference values are unavailable; no comparison lines are plotted.")
            : (chinese ? "横轴为发布档位；能力、成本和耗时以当前为基准，纵轴按倍数的对数排列。固定范围包含标准与支持的快速配置；缺失或非正值保留空隙。" : "Published efforts form x; ability, cost and time use Current on a log2 ratio axis. The fixed domain includes Standard and supported Fast configurations; missing/nonpositive values remain gaps.")
        fastAvailable = comparison.fastAvailable
        trialFast = comparison.panels[1].configuration?.fast ?? false
        var note: [String] = []
        if unknownCurrent { note.append(chinese ? "当前未报告" : "Current unknown") }
        fastShown = comparison.panels.contains { $0.configuration?.fast == true }
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
        help = HelpCatalog(language).explanation(.comparison, context: .init(fact: ([model.name,chartDescription]+notes).joined(separator:" · ")))
    }
    public static func chartIsPresent(in slot:CGSize)->Bool {slot.width.isFinite && slot.height.isFinite && slot.width>=160 && slot.height>=34}
    public func chartGeometry(in plot:CGRect,labelBounds:CGRect? = nil)->ComparisonChartGeometry? {
        guard let axis=chartAxis,[plot.minX,plot.minY,plot.width,plot.height,plot.maxX,plot.maxY].allSatisfy(\.isFinite),plot.width>0,plot.height>0,!efforts.isEmpty else{return nil}
        let keys=efforts.map(\.key)
        func x(_ i:Int)->Double {plot.minX+(Double(i)+0.5)*plot.width/Double(keys.count)}
        func point(_ ratio:Double?,_ metric:ComparisonMetric,_ i:Int)->ComparisonChartPoint? {
            guard let ratio,let fraction=axis.fraction(ratio) else{return nil}
            return .init(metric:metric,ratio:ratio,point:.init(x:x(i),y:plot.minY+fraction*plot.height))
        }
        var traces:[ComparisonMetricTrace]=[]
        for fast in [false,true] where !fast || fastShown {
            for (m,metric) in ComparisonMetric.allCases.enumerated() where !fast || metric != .ability {
                let points=keys.enumerated().map { i,key in point(publishedSamples.first{$0.configuration == .init(key,fast:fast)}?.ratios[m],metric,i) }
                traces.append(.init(metric:metric,fast:fast,points:points))
            }
        }
        let profiles=chartProfiles.compactMap { profile->ComparisonProfileGeometry? in
            guard let index=keys.firstIndex(of:profile.configuration.effort) else{return nil}
            return .init(configuration:profile.configuration,roles:profile.roles,points:ComparisonMetric.allCases.enumerated().map{point(profile.ratios[$0.offset],$0.element,index)})
        }
        let bounds=labelBounds ?? plot,ends=traces.filter{!$0.fast}.compactMap { trace->(ComparisonMetric,CGPoint)? in
            trace.points.compactMap{$0}.last.map{(trace.metric,$0.point)}
        }.sorted{$0.1.y<$1.1.y}
        let gap=min(bounds.height<44 ? 11.0:13.0,max(0,(bounds.height-12)/Double(max(1,ends.count-1))))
        var ys:[Double]=[]
        for end in ends {ys.append(max(bounds.minY+6,end.1.y,(ys.last ?? (bounds.minY+6-gap))+gap))}
        for i in ys.indices.reversed() {ys[i]=min(ys[i],i==ys.count-1 ? bounds.maxY-6:ys[i+1]-gap)}
        let labels=ends.enumerated().map{ComparisonEndpointLabel(metric:$0.element.0,anchor:$0.element.1,y:ys[$0.offset])}
        return .init(plot:plot,axis:axis,profiles:profiles,traces:traces,endpoints:labels,effortKeys:keys)
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
