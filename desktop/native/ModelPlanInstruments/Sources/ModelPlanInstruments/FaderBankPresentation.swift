// SPDX-License-Identifier: MIT
import Foundation

public struct FaderVendorIdentity: Equatable, Sendable {
    public let subscriptionID: String
    public let name: String
    public let brandID: String
    public init(subscriptionID: String, name: String, brandID: String) {
        self.subscriptionID = subscriptionID; self.name = name; self.brandID = brandID
    }
}
/// Already ordered/eligible models and attributed sessions from the assembly join.
public struct FaderChannelInput: Sendable {
    public let model: InstrumentModel
    public let nameVariants: [String]
    public let vendors: [FaderVendorIdentity]
    public let sessions: [InstrumentSession]
    public let basisNote: String?
    public init(model: InstrumentModel, nameVariants: [String] = [], vendors: [FaderVendorIdentity] = [], sessions: [InstrumentSession] = [], basisNote: String? = nil) {
        self.model = model; self.nameVariants = nameVariants; self.vendors = vendors; self.sessions = sessions; self.basisNote = basisNote
    }
}
public struct FaderTrial: Equatable, Sendable {
    public let modelID: String
    public let configuration: EffortConfiguration
    public init(modelID: String, configuration: EffortConfiguration) { self.modelID = modelID; self.configuration = configuration }
}
public enum FaderIndicatorTone: Sendable { case idle, selected, realFast, trial }
public struct FaderEffortDisplay: Equatable, Sendable {
    public let key: String, label: String
    /// Zero is the top; one is the bottom. Single native settings sit at the centre.
    public let position: Double
    public let abilityFraction: Double?
    public let current: Bool, recommended: Bool, trial: Bool
    public let otherSessionCount: Int
}
public struct FaderChannelDisplay: Equatable, Sendable {
    public let id: String
    public let name: String
    public let nameVariants: [String]
    public let vendors: [FaderVendorIdentity]
    public let efforts: [FaderEffortDisplay]
    public let selected: Bool, favorite: Bool
    public let sourceHighlighted: Bool
    public let current: EffortConfiguration?
    public let trial: EffortConfiguration?
    public let realPosition: Double
    public let parked: Bool
    public let recommendedPosition: Double?
    public let ghostPosition: Double?
    public let dragPosition: Double?
    public let previewPosition: Double?
    public let indicatorTone: FaderIndicatorTone
    public let fastIndicator: Bool
    public let state: String
    public let stateVariants: [String]
    public let recommendation: String?
    public let costMultiple: String?
    public let costBasis: String?
    public let lcdHelp: HelpExplanation
    public let travelHelp: HelpExplanation
    public let indicatorHelp: HelpExplanation
    public var shownEffort: String? { trial?.effort ?? current?.effort }
}

/// Presentation only: no ranking, model switching, scoring or entitlement inference.
public struct FaderBankPresentation: Equatable, Sendable {
    public let bank: Int, bankCount: Int
    public let channels: [FaderChannelDisplay?]
    public let targetID: String?
    public let language: InstrumentLanguage
    public let compact: Bool
    public let bankLabel: String
    public let previousLabel: String, nextLabel: String
    public let emptyLabel: String?
    public var target: FaderChannelDisplay? { channels.compactMap { $0 }.first { $0.id == targetID } }

    public init(inputs: [FaderChannelInput], requestedBank: Int = 0, selectedModelID: String? = nil,
                favoriteIDs: [String] = [], trial: FaderTrial? = nil, sourceModelID: String? = nil, draggingModelID: String? = nil,
                dragPosition: Double? = nil, previewModelID: String? = nil, previewEffort: String? = nil,
                publicationUsable: Bool, language: InstrumentLanguage,
                compact: Bool, showProjectNames: Bool = true, now: Date) {
        let ordered = Self.ordered(inputs: publicationUsable ? inputs : [], favoriteIDs: favoriteIDs)
        let page = FaderBank(models: ordered.map(\.model), bank: requestedBank)
        bank = page.bank; bankCount = page.count; self.language = language; self.compact = compact
        let chinese = language == .chinese, format = InstrumentFormat(language), help = HelpCatalog(language)
        bankLabel = chinese ? "第\(page.bank + 1)组/共\(page.count)组" : "Bank \(page.bank + 1)/\(page.count)"
        previousLabel = chinese ? "上一组推杆（键 [）" : "Previous fader bank (key [)"
        nextLabel = chinese ? "下一组推杆（键 ]）" : "Next fader bank (key ])"
        emptyLabel = ordered.isEmpty ? (chinese ? "模型资料不可用" : "Model information unavailable") : nil
        let shown = Array(ordered.dropFirst(page.bank * 3).prefix(3))
        var result: [FaderChannelDisplay?] = shown.map { input in
            let model = input.model
            var seen = Set<String>()
            let efforts = model.efforts.filter { seen.insert($0.key).inserted }
            let current = model.current.flatMap { config in efforts.contains { $0.key == config.effort } ? config : nil }
            let tried = trial.flatMap { $0.modelID == model.id ? $0.configuration : nil }
            let comparison = EffortComparison(model: model, trial: tried, publicationUsable: publicationUsable)
            let validTrial = comparison.panels.first { $0.role == .trial }?.configuration
            let lcd = FaderLCD(model: model, trial: validTrial, publicationUsable: publicationUsable, language: language, compact: compact)
            func position(_ key: String?) -> Double? {
                guard let key, let i = efforts.firstIndex(where: { $0.key == key }) else { return nil }
                return efforts.count == 1 ? 0.5 : 1 - Double(i) / Double(efforts.count - 1)
            }
            let recPosition = position(model.recommended)
            let real = position(current?.effort) ?? recPosition ?? 0.5
            var sessionIDs = Set<String>()
            let sessions = input.sessions.filter { $0.model == model.id && $0.evidence.usable(at: now) && sessionIDs.insert($0.id).inserted }
            let values = efforts.compactMap { $0.ability.value }
            let bases = Set(efforts.compactMap { $0.ability.value == nil ? nil : $0.ability.basis })
            let compatible = bases.count == 1 && efforts.filter { $0.ability.value != nil }.allSatisfy { $0.ability.basis != nil }
            let low = values.min(), high = values.max()
            let levels = efforts.enumerated().map { i, effort -> FaderEffortDisplay in
                let fraction: Double?
                if compatible, let value = effort.ability.value, let low, let high { fraction = high > low ? (value - low) / (high - low) : 1 }
                else { fraction = nil }
                let others = effort.key == current?.effort ? 0 : sessions.filter { $0.effort == effort.key }.count
                return FaderEffortDisplay(key: effort.key, label: effort.label,
                    position: efforts.count == 1 ? 0.5 : 1 - Double(i) / Double(efforts.count - 1), abilityFraction: fraction,
                    current: effort.key == current?.effort, recommended: effort.key == model.recommended,
                    trial: effort.key == validTrial?.effort, otherSessionCount: others)
            }
            let selected = selectedModelID == model.id
            let fast = model.fastTier?.usable == true && (validTrial?.fast ?? current?.fast ?? false)
            let tone: FaderIndicatorTone = validTrial != nil ? .trial : fast ? .realFast : selected ? .selected : .idle
            let basis = lcd.costBasis.map { value in
                value == .trialOverCurrent ? (chinese ? "当前" : "vs current") : (chinese ? "当前/★推荐" : "current / recommended")
            }
            var fact = model.name + " · " + (chinese ? "当前 " : "Current ")
                + (current.flatMap { model.effort($0.effort)?.label } ?? "--")
                + " · ★" + (model.recommended.flatMap { model.effort($0)?.label } ?? "--")
            if let multiple = lcd.multiple, let basis { fact += " · " + multiple + " " + basis }
            if let qualifier = model.fastTier?.qualifier, fast { fact += " · " + qualifier }
            if let basis = input.basisNote { fact += " · " + basis }
            let summaries = sessions.prefix(6).map { s in
                [s.tool, showProjectNames ? s.projectName : nil, s.effort, s.working(now: now) ? (chinese ? "运行中" : "running") : format.age(s.endedAt ?? s.lastAt, now: now)]
                    .compactMap { $0 }.joined(separator: " · ")
            }.joined(separator: "; ")
            let indicator = model.name + " · " + (validTrial != nil ? (chinese ? "在试" : "trying") : selected ? (chinese ? "已选" : "selected") : (chinese ? "未选" : "not selected"))
                + (fast ? (chinese ? " · 快速" : " · Fast") : "") + (summaries.isEmpty ? "" : " · " + summaries)
            let drag = draggingModelID == model.id ? dragPosition.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil } : nil
            var vendorIDs = Set<String>()
            let vendors = input.vendors.filter { vendorIDs.insert($0.subscriptionID).inserted }
            let variants = ([model.name] + input.nameVariants).filter { !$0.isEmpty }
            return FaderChannelDisplay(id: model.id, name: model.name, nameVariants: variants, vendors: vendors, efforts: levels,
                selected: selected, favorite: favoriteIDs.contains(model.id), sourceHighlighted: sourceModelID == model.id, current: current, trial: validTrial,
                realPosition: real, parked: current == nil, recommendedPosition: recPosition,
                ghostPosition: validTrial?.effort == current?.effort ? nil : position(validTrial?.effort), dragPosition: drag,
                previewPosition: previewModelID == model.id && previewEffort != (validTrial?.effort ?? current?.effort) ? position(previewEffort) : nil,
                indicatorTone: tone, fastIndicator: fast, state: lcd.state,
                stateVariants: language == .english && lcd.state == "Try = current" ? [lcd.state, "Try = Now"] : [lcd.state], recommendation: lcd.recommendation,
                costMultiple: lcd.multiple, costBasis: basis, lcdHelp: help.explanation(.effortLCD, context: .init(fact: fact)),
                travelHelp: help.explanation(.effort, context: .init(fact: fact)), indicatorHelp: help.explanation(.working, context: .init(fact: indicator)))
        }
        while result.count < 3 { result.append(nil) }
        channels = result
        targetID = shown.first { $0.model.id == selectedModelID }?.model.id ?? shown.first?.model.id
    }
    public static func ordered(inputs: [FaderChannelInput], favoriteIDs: [String]) -> [FaderChannelInput] {
        var ids = Set<String>(); let unique = inputs.filter { ids.insert($0.model.id).inserted }
        let byID = Dictionary(uniqueKeysWithValues: unique.map { ($0.model.id, $0) })
        var pins = Set<String>()
        let favorites = favoriteIDs.compactMap { id -> FaderChannelInput? in guard pins.insert(id).inserted else { return nil }; return byID[id] }
        return favorites + unique.filter { !pins.contains($0.model.id) }
    }
}
