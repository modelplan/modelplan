// SPDX-License-Identifier: MIT
import Foundation

/// A published metric and its compatibility basis. No scores or recommendations are computed here.
public struct PublishedMetric: Sendable {
    public let value: Double?
    public let basis: String?
    public let qualifier: String?
    public init(_ value: Double?, basis: String?, qualifier: String? = nil) {
        self.value = known(value); self.basis = basis; self.qualifier = qualifier
    }
    fileprivate func relative(to other: Self?) -> Double? {
        guard let other, let basis, basis == other.basis else { return nil }
        return ratio(value, other.value)
    }
    fileprivate func scaled(by factor: Double?) -> Self {
        guard let factor = known(factor), let value else { return Self(nil, basis: basis, qualifier: qualifier) }
        return Self(value * factor, basis: basis, qualifier: qualifier)
    }
}

public struct InstrumentEffort: Sendable {
    public let key: String
    public let label: String
    public let ability: PublishedMetric
    public let cost: PublishedMetric
    public let time: PublishedMetric
    public init(key: String, label: String, ability: PublishedMetric, cost: PublishedMetric, time: PublishedMetric) {
        self.key = key; self.label = label; self.ability = ability; self.cost = cost; self.time = time
    }
}

public struct EffortConfiguration: Equatable, Hashable, Sendable {
    public let effort: String
    public let fast: Bool
    public init(_ effort: String, fast: Bool = false) { self.effort = effort; self.fast = fast }
}

/// Caller supplies only the tier matched to this model and tool by the verified publication join.
public struct InstrumentFastTier: Sendable {
    public let costMultiplier: Double?
    public let speedMultiplier: Double?
    public let taskTimeUnknown: Bool
    public let qualifier: String?
    public var usable: Bool {
        guard let costMultiplier, let speedMultiplier else { return false }
        return costMultiplier > 0 && speedMultiplier > 0
    }
    public init(costMultiplier: Double?, speedMultiplier: Double?, taskTimeUnknown: Bool, qualifier: String? = nil) {
        self.costMultiplier = known(costMultiplier); self.speedMultiplier = known(speedMultiplier)
        self.taskTimeUnknown = taskTimeUnknown; self.qualifier = qualifier
    }
}

public struct InstrumentModel: Sendable {
    public let id: String
    public let name: String
    public let efforts: [InstrumentEffort]
    public let recommended: String?
    public let current: EffortConfiguration?
    public let fastTier: InstrumentFastTier?
    public let lineage: InstrumentLineage
    public init(id: String, name: String, efforts: [InstrumentEffort], recommended: String?,
                current: EffortConfiguration?, fastTier: InstrumentFastTier? = nil, lineage: InstrumentLineage = .init()) {
        self.id = id; self.name = name; self.efforts = efforts; self.recommended = recommended
        self.current = current; self.fastTier = fastTier; self.lineage = lineage
    }

    public func effort(_ key: String) -> InstrumentEffort? { efforts.first { $0.key == key } }
    public func olderBadge(_ language: InstrumentLanguage) -> String? {
        lineage.lineageStatus == "older" ? (language == .chinese ? "旧版" : "older") : nil
    }
    fileprivate func resolve(_ configuration: EffortConfiguration?) -> ResolvedEffort? {
        guard let configuration, let effort = effort(configuration.effort), !configuration.fast || fastTier?.usable == true else { return nil }
        let fast = configuration.fast
        let timeFactor = fast ? fastTier.flatMap { $0.taskTimeUnknown ? nil : ratio(1, $0.speedMultiplier) } : 1
        return ResolvedEffort(configuration: configuration, label: effort.label, ability: effort.ability,
                              cost: fast ? effort.cost.scaled(by: fastTier?.costMultiplier) : effort.cost,
                              time: effort.time.scaled(by: timeFactor))
    }
}

private struct ResolvedEffort {
    let configuration: EffortConfiguration
    let label: String
    let ability: PublishedMetric
    let cost: PublishedMetric
    let time: PublishedMetric
}

public enum ComparisonRole: Sendable { case current, trial, recommended }
public enum ComparisonLight: Sendable { case dim, off, white, blue, gold }
public struct ComparisonValues: Equatable, Sendable {
    public let abilityDelta: Double?
    public let abilityRatio: Double?
    public let costRatio: Double?
    public let timeRatio: Double?
    public var hasRatios: Bool { abilityRatio != nil || costRatio != nil || timeRatio != nil }
    fileprivate init(_ value: ResolvedEffort?, current: ResolvedEffort?) {
        abilityRatio = value?.ability.relative(to: current?.ability)
        if let a = value?.ability, let b = current?.ability, let basis = a.basis,
           basis == b.basis, let x = a.value, let y = b.value { abilityDelta = x - y }
        else { abilityDelta = nil }
        costRatio = value?.cost.relative(to: current?.cost)
        timeRatio = value?.time.relative(to: current?.time)
    }
}

public struct ComparisonPanel: Sendable {
    public let role: ComparisonRole
    public let configuration: EffortConfiguration?
    public let label: String?
    public let light: ComparisonLight
    public let equalsCurrent: Bool
    public let equalsRecommended: Bool
    /// nil for unknown current or the unlit equal-current trial; renderers cannot accidentally show its values.
    public let values: ComparisonValues?
}
public struct ComparisonProfile: Sendable {
    public let configuration: EffortConfiguration
    public let roles: [ComparisonRole]
    public let values: ComparisonValues
}

public struct ComparisonPublishedSample:Sendable {
    public let configuration:EffortConfiguration
    public let values:ComparisonValues
}
public struct EffortComparison: Sendable {
    public let panels: [ComparisonPanel]
    public let profiles: [ComparisonProfile]
    public let fastAvailable: Bool
    public let fastQualifier: String?
    public let publishedSamples:[ComparisonPublishedSample]

    public init(model: InstrumentModel, trial: EffortConfiguration?, publicationUsable: Bool) {
        let current = publicationUsable ? model.resolve(model.current) : nil
        let recommended = publicationUsable ? model.resolve(model.recommended.map { EffortConfiguration($0) }) : nil
        let tried = publicationUsable ? model.resolve(trial) : nil
        fastAvailable = publicationUsable && model.fastTier?.usable == true
        fastQualifier = fastAvailable ? model.fastTier?.qualifier : nil
        var seen=Set<String>()
        let efforts=publicationUsable ? model.efforts.filter{seen.insert($0.key).inserted}:[]
        publishedSamples=([false]+(fastAvailable ? [true]:[])).flatMap { fast in
            efforts.map { effort in
                let config=EffortConfiguration(effort.key,fast:fast)
                return ComparisonPublishedSample(configuration:config,values:ComparisonValues(model.resolve(config),current:current))
            }
        }
        var result: [ComparisonPanel] = []
        for (role, value) in [(ComparisonRole.current, current), (.trial, tried), (.recommended, recommended)] {
            let equalCurrent = value != nil && current != nil && value?.configuration == current?.configuration
            let equalRec = value != nil && recommended != nil && value?.configuration == recommended?.configuration
            let hidden = role == .trial && equalCurrent
            let light: ComparisonLight = hidden ? .off : value == nil ? .dim : equalRec || role == .recommended ? .gold : role == .current ? .white : .blue
            result.append(ComparisonPanel(role: role, configuration: value?.configuration, label: hidden ? nil : value?.label,
                                          light: light, equalsCurrent: equalCurrent, equalsRecommended: equalRec,
                                          values: hidden || value == nil ? nil : ComparisonValues(value, current: current)))
        }
        panels = result
        var profiles: [ComparisonProfile] = []
        for panel in result {
            guard let config = panel.configuration, let values = panel.values, values.hasRatios else { continue }
            if let i = profiles.firstIndex(where: { $0.configuration == config }) {
                let old = profiles[i]
                profiles[i] = ComparisonProfile(configuration: config, roles: old.roles + [panel.role], values: values)
            } else { profiles.append(ComparisonProfile(configuration: config, roles: [panel.role], values: values)) }
        }
        self.profiles = profiles
    }
}

public enum FaderCostBasis: Sendable { case currentOverRecommended, trialOverCurrent }
public struct FaderLCD: Sendable {
    public let state: String
    public let recommendation: String?
    public let multiple: String?
    public let costBasis: FaderCostBasis?

    public init(model: InstrumentModel, trial: EffortConfiguration?, publicationUsable: Bool,
                language: InstrumentLanguage, compact: Bool) {
        let format = InstrumentFormat(language)
        let current = publicationUsable ? model.resolve(model.current) : nil
        let rec = publicationUsable ? model.resolve(model.recommended.map { EffortConfiguration($0) }) : nil
        let tried = publicationUsable ? model.resolve(trial) : nil
        let follows = current != nil && current?.configuration == rec?.configuration
        if let tried {
            let equalCurrent = current?.configuration == tried.configuration
            let equalRec = rec?.configuration == tried.configuration
            let prefix = language == .chinese ? "试 " : "Try "
            state = prefix + (equalCurrent ? (language == .chinese ? "= 当前" : "= current") : equalRec ? "= ★" : tried.label)
            recommendation = nil
            let cost = !equalCurrent && !equalRec && !(compact && language == .english)
                ? format.costMultiple(tried.cost.relative(to: current?.cost)) : nil
            multiple = cost; costBasis = cost == nil ? nil : .trialOverCurrent
        } else {
            state = follows ? "★" + (current?.label ?? "--") : current?.label ?? "--"
            recommendation = follows ? nil : rec.map { "★" + $0.label }
            let cost = !follows && !(compact && (rec?.label.count ?? 0) > 3)
                ? format.costMultiple(current?.cost.relative(to: rec?.cost)) : nil
            multiple = cost; costBasis = cost == nil ? nil : .currentOverRecommended
        }
    }
}

/// Native effort order is preserved; no fixed five-setting ladder or cross-vendor sorting.
public struct FaderBank: Sendable {
    public let bank: Int
    public let count: Int
    public let models: [InstrumentModel?]
    public init(models: [InstrumentModel], bank requested: Int) {
        var ids = Set<String>()
        let unique = models.filter { ids.insert($0.id).inserted }
        count = max(1, (unique.count + 2) / 3)
        bank = min(max(0, requested), count - 1)
        let shown = Array(unique.dropFirst(bank * 3).prefix(3))
        self.models = (0..<3).map { $0 < shown.count ? shown[$0] : nil }
    }
}
