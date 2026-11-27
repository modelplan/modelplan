// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanResources

/// The resource plugin on the widget (D324, D327): the sampler's face and hover card as one more ring in the Dock.
/// The ring is the subscription ring's size (D163): outer arc memory (solid used, faint cached), inner thin arc CPU.
/// D371 B4c (owner 11-21): each arc, each card bar and the readout number take the status colour of what they measure
/// (normal / amber from 80 % / red from 90 %, 3-point hysteresis; the 11-13 round-4 status colour, the quota rings'
/// family), not the plugin's orchid. The card rows follow variant A. B4f (owner 11-21):
/// the readout under the ring is the percentage alone ("77%"); VoiceOver reads "内存 77%" (`spokenReadout`).
public enum ResourceDockBridge {
    public static let subscriptionID = "plugin:resources"
    /// A plugin ring's Dock ID is this prefix and the cockpit plugin ID.
    static let dockIDPrefix = "plugin:"
    /// Sample S17 (#1096 macrevb-1096-6): the cockpit plugin ID ("resources") for a plugin ring's Dock ID
    /// ("plugin:resources"). The cockpit bridge takes plugin IDs only (CockpitPluginWire.validID refuses the colon).
    public static func pluginID(dockID: String) -> String? {
        guard dockID.hasPrefix(dockIDPrefix) else { return nil }
        let id = String(dockID.dropFirst(dockIDPrefix.count))
        return id.isEmpty ? nil : id
    }
    /// The plugin's identity ink (the cockpit tab underline). Not used on the ring or the bars any more (D371).
    public static let ink = "#da66c2"
    /// The ring's base ink: the normal status colour (`DockPluginStatusColour`); the arcs take their own tone on top.
    static let normalInk = "#5ad9ba"

    public static func tone(_ t: ResourceTone) -> DockQuotaStatus {
        switch t { case .normal: return .normal; case .warning: return .warning; case .critical: return .critical }
    }

    /// One card row: label · bar · % · side value. Variant A: `emphasised` is ink only (no background);
    /// `tinted` is the problem-row background; the bar is orchid and the number keeps an amber/red tone.
    public static func row(_ r: ResourceCard.Row) -> DockCardRow {
        var row = DockCardRow(id: "resource:" + r.id.rawValue, kind: .quota, label: r.label, value: "\(r.percent)%", detail: r.side,
                              remainingFraction: nil, fillFraction: .some(r.fill), tone: tone(r.tone), emphasised: r.ink == .full)
        let colour = DockPluginStatusColour.rgb(row.tone)
        row.plugin = DockCardPluginStyle(red: colour.red, green: colour.green, blue: colour.blue, faintFill: r.cachedFill, tinted: r.tinted)
        return row
    }

    /// The hover card's rows, footer and its cockpit entry label ("在驾驶舱查看", D371 B4e) for the Dock.
    public static func card(_ card: ResourceCard) -> DockPluginCard {
        DockPluginCard(rows: card.rows.map(row), footer: card.footer, action: card.screenLink, source: card.cadence)
    }

    public static func ring(face: ResourceFace, card: ResourceCard, language: ResourceLanguage) -> DockPluginRing? {
        let live = Self.card(card)
        return DockPluginRing(hex: normalInk, outer: min(1, max(0, face.memoryUsed)), outerFaint: min(1 - min(1, max(0, face.memoryUsed)), max(0, face.memoryCached)),
                              inner: min(1, max(0, face.cpu)), readout: "\(face.shown.percent)%", readoutTone: tone(face.shown.tone),
                              animates: face.animates, cardRows: live.rows, cardFooter: live.footer, cardAction: live.action,
                              spokenReadout: face.shown.text(language),
                              outerTone: tone(face.levels.memory), innerTone: tone(face.levels.cpu), cardSource: live.source)
    }

    /// The Dock input for the resource ring; nil while there is no sample yet (the ring is not shown empty).
    public static func input(face: ResourceFace?, card: ResourceCard?, language: ResourceLanguage) -> DockInstrumentInput? {
        guard let face, let card, let ring = ring(face: face, card: card, language: language) else { return nil }
        var input = DockInstrumentInput(id: subscriptionID, name: language == .chinese ? "资源占用" : "Resources", windows: [])
        input.dataState = .fresh
        input.pluginRing = ring
        return input
    }
}

/// Adds the resource ring to another provider's content. B4 (owner 11-21): the ring comes after the subscription
/// rings, the cockpit's order (desktop/cockpit/src/plugin-layout.ts: subscriptions first, plugins after them). The
/// ring is outside the subscription order Settings commits (macrevb-1096-8), so the saved order never moves it; ids the
/// saved order does not cover follow it in catalogue order (SubscriptionOrder.orderedIDs), which keeps it last.
@MainActor public final class ResourceDockContentProvider: DockContentProvider {
    private let base: any DockContentProvider
    /// Set by the host on every admitted redraw; nil hides the ring (plugin off or no sample yet).
    public var resourceInput: DockInstrumentInput?
    /// B9 (owner 11-21): whether the base has admitted content now. Between a content clear and the next install
    /// (a rows refresh, a deadline replacement) the base is empty on purpose; the ring alone would then be painted and
    /// the subscription rings would vanish for a moment. nil = always admitted.
    var baseAdmitted: (() -> Bool)?
    public init(base: any DockContentProvider) { self.base = base }
    public func makeContent(_ context: DockContentContext) -> DockContent {
        let content = base.makeContent(context)
        // B9: no admitted subscription content, no ring: the widget is never redrawn with the plugin ring alone in a
        // replacement gap. Invariant: a shown subscription ring is removed only when its row is really gone.
        guard let extra = resourceInput, baseAdmitted?() ?? true else { return content }
        let s = content.snapshot
        let snapshot = CommunityDockSnapshot(inputs: s.inputs.filter { $0.id != extra.id } + [extra], subscriptions: s.subscriptions,
            presentationRows: s.presentationRows, unavailableReason: s.unavailableReason,
            readerDiagnostics: s.readerDiagnostics, emptyDiagnostic: s.emptyDiagnostic)
        return DockContent(snapshot: snapshot, menuStatusLines: content.menuStatusLines, emptyText: content.emptyText,
                           signals: content.signals, recomputeDeadline: content.recomputeDeadline)
    }
}

/// Connects the one ResourceSampler to the widget: every admitted redraw (≥ 1 point change, D324) rebuilds the
/// resource input and asks the Dock to refresh; turning the plugin off removes the ring.
/// macrevb-1096-4: the hover card does not wait for a redraw. The Dock reads `liveCard()` whenever it builds the card,
/// and `refreshCard` runs after every admitted sample and cadence change so an open card follows at once.
@MainActor public final class ResourceWidgetBinding {
    public let provider: ResourceDockContentProvider
    private let sampler: ResourceSampler
    private let language: () -> ResourceLanguage
    private let refresh: () -> Void
    private let refreshCard: () -> Void
    /// G3-161: repaints only the Resources ring; false = it could not, run the full `refresh`.
    private let refreshRing: (DockInstrumentInput) -> Bool
    public init(sampler: ResourceSampler, provider: ResourceDockContentProvider, language: @escaping () -> ResourceLanguage,
                refreshCard: @escaping () -> Void = {}, refreshRing: @escaping (DockInstrumentInput) -> Bool = { _ in false },
                refresh: @escaping () -> Void) {
        self.sampler = sampler; self.provider = provider; self.language = language; self.refresh = refresh; self.refreshCard = refreshCard
        self.refreshRing = refreshRing
        sampler.onRedraw = { [weak self] face in self?.redraw(face) }
        sampler.onCardChange = { [weak self] in self?.cardChanged() }
    }
    /// The card for the latest sample, the readout shown now and the current cadence.
    func card(_ shown: ResourceShown) -> ResourceCard? {
        guard let sample = sampler.history.samples.last, let interval = ResourceCadence.interval(sampler.visibility) else { return nil }
        return ResourceCard(sample: sample, shown: shown, cpuPeak: sampler.history.peakCPU, interval: interval, language: language(), levels: sampler.levels)
    }
    func card(_ face: ResourceFace) -> ResourceCard? { card(face.shown) }
    /// What the hover card shows now (nil while there is no sample or the plugin is off).
    public func liveCard() -> DockPluginCard? {
        guard sampler.visibility.pluginEnabled, let shown = sampler.shown, let card = card(shown) else { return nil }
        return ResourceDockBridge.card(card)
    }
    private func cardChanged() {
        guard provider.resourceInput != nil else { return }
        refreshCard()
    }
    /// B9: no widget redraw while the subscription content is between a clear and its next install; that install
    /// redraws with the latest ring. A redraw in the gap painted the plugin ring alone and the subscription rings
    /// vanished for a moment.
    private var baseAdmitted: Bool { provider.baseAdmitted?() ?? true }
    /// What the ring shows: the rounded numbers and tones. Two faces with the same key look the same.
    private struct RingKey: Equatable {
        let shown: ResourceShown, memoryTone: ResourceTone, cpuTone: ResourceTone
        let memory: Int, cached: Int, cpu: Int, animates: Bool, language: ResourceLanguage
        init(_ face: ResourceFace, _ language: ResourceLanguage) {
            shown = face.shown; memoryTone = face.levels.memory; cpuTone = face.levels.cpu; animates = face.animates; self.language = language
            memory = Int((face.memoryUsed * 100).rounded()); cached = Int((face.memoryCached * 100).rounded()); cpu = Int((face.cpu * 100).rounded())
        }
    }
    private var drawnKey: RingKey?
    /// G3-161: a sample whose displayed numbers and tones equal the drawn ones repaints nothing (the open card still
    /// follows through `onCardChange`). A changed one repaints the ring alone; the full Dock pass is the fallback.
    private func redraw(_ face: ResourceFace) {
        let lang = language()
        let key = RingKey(face, lang)
        if key == drawnKey, provider.resourceInput != nil { return }
        guard let input = ResourceDockBridge.input(face: face, card: card(face), language: lang) else {
            drawnKey = nil; provider.resourceInput = nil
            if baseAdmitted { refresh() }
            return
        }
        drawnKey = key; provider.resourceInput = input
        if baseAdmitted, !refreshRing(input) { refresh() }
    }
    /// Plugin state, cockpit column and widget visibility; off removes the ring at once.
    public func setVisibility(_ v: ResourceVisibility) {
        sampler.setVisibility(v)
        if !v.pluginEnabled { drawnKey = nil }
        if !v.pluginEnabled, provider.resourceInput != nil { provider.resourceInput = nil; if baseAdmitted { refresh() } }
    }
}
