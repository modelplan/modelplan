// SPDX-License-Identifier: MIT
import Foundation

public enum FaderIntent: Equatable, Sendable {
    case selectModel(String), inspectModel(String), trialChanged(FaderTrial?)
    case favoritesChanged([String]), bankChanged(Int)
    /// A bank/favourite activation replaces a sourced main-screen view even at a bank boundary.
    case closeSourcedView
}
public enum FaderTiming {
    public static let glide = 0.280
    public static let readingFade = 0.080
    public static let favoritePress = 0.520
}
/// Local interaction state only. The host routes intents; no CLI/session or preference write.
public struct FaderBankController: Sendable {
    public private(set) var inputs: [FaderChannelInput] = []
    public private(set) var publicationUsable = false
    public private(set) var catalogueOnly = false
    public private(set) var bank = 0
    public private(set) var selectedModelID: String?
    public private(set) var favoriteIDs: [String] = []
    public private(set) var trial: FaderTrial?
    public private(set) var sourceHighlightID: String?
    public private(set) var draggingModelID: String?
    public private(set) var dragPosition: Double?
    public private(set) var previewModelID: String?, previewEffort: String?
    private struct Press: Sendable { let id: String; let deadline: Double; var completed: Bool }
    private var press: Press?
    public var nextDeadline: Double? { press.flatMap { $0.completed ? nil : $0.deadline } }
    public init() {}
    public var ordered: [FaderChannelInput] { FaderBankPresentation.ordered(inputs: publicationUsable || catalogueOnly ? inputs : [], favoriteIDs: favoriteIDs) }
    public var bankCount: Int { max(1, (ordered.count + 2) / 3) }
    private func model(_ id: String) -> InstrumentModel? { publicationUsable ? inputs.first { $0.model.id == id }?.model : nil }

    @discardableResult public mutating func update(inputs: [FaderChannelInput], publicationUsable: Bool,
                                                   favoriteIDs: [String]? = nil, selectedModelID: String? = nil,
                                                   catalogueOnly: Bool = false) -> [FaderIntent] {
        self.inputs = inputs; self.publicationUsable = publicationUsable
        self.catalogueOnly = catalogueOnly && !publicationUsable
        if !publicationUsable { cancelGesture() }
        if let favoriteIDs { self.favoriteIDs = favoriteIDs.reduce(into: []) { if !$0.contains($1) { $0.append($1) } } }
        if let selectedModelID { self.selectedModelID = selectedModelID }
        bank = min(bank, bankCount - 1)
        if let selected = self.selectedModelID, model(selected) == nil { self.selectedModelID = nil }
        if let id = draggingModelID, model(id) == nil { cancelGesture() }
        if let press, model(press.id) == nil { self.press = nil }
        if let id = sourceHighlightID, model(id) == nil { sourceHighlightID = nil }
        if let trial, !valid(trial) { self.trial = nil; return [.trialChanged(nil)] }
        return []
    }
    private func valid(_ trial: FaderTrial) -> Bool {
        guard let model = model(trial.modelID), model.effort(trial.configuration.effort) != nil else { return false }
        return !trial.configuration.fast || model.fastTier?.usable == true
    }
    @discardableResult public mutating func setTrial(_ trial: FaderTrial?) -> Bool {
        guard trial == nil || valid(trial!) else { return false }
        self.trial = trial; return true
    }
    /// Mirrors the one main-screen source, without selecting a model or changing a trial.
    public mutating func setSourceHighlight(_ id: String?) {
        sourceHighlightID = id.flatMap { model($0) == nil ? nil : $0 }
    }
    public mutating func endTrial() -> [FaderIntent] {
        cancelGesture()
        guard trial != nil else { return [] }
        trial = nil; return [.trialChanged(nil)]
    }
    public mutating func selectModel(_ id: String) -> [FaderIntent] {
        guard let i = ordered.firstIndex(where: { $0.model.id == id }) else { return [] }
        let ended = endTrial(); selectedModelID = id; bank = i / 3
        return ended + [.selectModel(id), .bankChanged(bank)]
    }
    public mutating func changeBank(_ requested: Int) -> [FaderIntent] {
        sourceHighlightID = nil
        let ended = endTrial(), next = min(max(0, requested), bankCount - 1)
        guard next != bank else { return ended + [.closeSourcedView] }
        bank = next; return ended + [.closeSourcedView, .bankChanged(next)]
    }
    public mutating func tryEffort(modelID: String, key: String, toggle: Bool = false) -> [FaderIntent] {
        guard let model = model(modelID), model.effort(key) != nil else { return [] }
        let fast = trial?.modelID == modelID ? trial!.configuration.fast : model.current?.fast ?? false
        let next = FaderTrial(modelID: modelID, configuration: .init(key, fast: fast))
        guard valid(next) else { return [] }
        selectedModelID = modelID
        if toggle, trial == next { trial = nil; return [.selectModel(modelID), .trialChanged(nil)] }
        guard trial != next else { return [] }
        trial = next; return [.selectModel(modelID), .trialChanged(next)]
    }
    public mutating func step(modelID: String, upward: Bool) -> [FaderIntent] {
        guard let model = model(modelID), !model.efforts.isEmpty else { return [] }
        var ids = Set<String>(); let levels = model.efforts.filter { ids.insert($0.key).inserted }
        let shown = trial?.modelID == modelID ? trial?.configuration.effort : model.current?.effort
        let index = levels.firstIndex { $0.key == shown } ?? levels.firstIndex { $0.key == model.recommended } ?? 0
        let next = min(max(0, index + (upward ? 1 : -1)), levels.count - 1)
        return tryEffort(modelID: modelID, key: levels[next].key)
    }
    public mutating func beginDrag(modelID: String, position: Double, key: String? = nil) -> [FaderIntent] {
        guard model(modelID) != nil, position.isFinite else { return [] }
        press = nil; previewModelID = nil; previewEffort = nil; draggingModelID = modelID
        return moveDrag(position: position, key: key)
    }
    public mutating func moveDrag(position: Double, key: String? = nil) -> [FaderIntent] {
        guard position.isFinite, let id = draggingModelID, let model = model(id), !model.efforts.isEmpty else { return [] }
        let k = min(1, max(0, position)); dragPosition = k
        if let key, model.effort(key) != nil { return tryEffort(modelID: id, key: key) }
        var ids = Set<String>(); let levels = model.efforts.filter { ids.insert($0.key).inserted }
        let nearest = levels.indices.min { a, b in
            let ka = levels.count == 1 ? 0.5 : 1 - Double(a) / Double(levels.count - 1)
            let kb = levels.count == 1 ? 0.5 : 1 - Double(b) / Double(levels.count - 1)
            return abs(ka - k) < abs(kb - k)
        }!
        return tryEffort(modelID: id, key: levels[nearest].key)
    }
    public mutating func finishDrag() { draggingModelID = nil; dragPosition = nil }
    public mutating func cancelGesture() { finishDrag(); press = nil; previewModelID = nil; previewEffort = nil }
    public mutating func preview(modelID: String?, key: String?) {
        guard let modelID, let key, model(modelID)?.effort(key) != nil else { previewModelID = nil; previewEffort = nil; return }
        previewModelID = modelID; previewEffort = key
    }
    public mutating func beginLCDPress(modelID: String, at now: Double) {
        guard now.isFinite, model(modelID) != nil else { return }
        finishDrag(); press = Press(id: modelID, deadline: now + FaderTiming.favoritePress, completed: false)
    }
    public mutating func advance(at now: Double) -> [FaderIntent] {
        guard now.isFinite, var press, !press.completed, now >= press.deadline else { return [] }
        press.completed = true; self.press = press
        return toggleFavorite(press.id, preservingPress: true)
    }
    public mutating func releaseLCD(inside: Bool, at now: Double) -> [FaderIntent] {
        guard now.isFinite else { cancelGesture(); return [] }
        let due = advance(at: now)
        guard let press else { return due }
        self.press = nil
        guard inside, !press.completed else { return due }
        selectedModelID = press.id
        return due + [.selectModel(press.id), .inspectModel(press.id)]
    }
    public mutating func toggleFavorite(_ id: String) -> [FaderIntent] { toggleFavorite(id, preservingPress: false) }
    private mutating func toggleFavorite(_ id: String, preservingPress: Bool) -> [FaderIntent] {
        guard model(id) != nil else { return [] }
        let saved = press, ended = endTrial()
        sourceHighlightID = nil
        if preservingPress { press = saved }
        if favoriteIDs.contains(id) { favoriteIDs.removeAll { $0 == id } }
        else { favoriteIDs.insert(id, at: 0) }
        bank = 0
        return ended + [.closeSourcedView, .favoritesChanged(favoriteIDs), .bankChanged(0)]
    }
}
