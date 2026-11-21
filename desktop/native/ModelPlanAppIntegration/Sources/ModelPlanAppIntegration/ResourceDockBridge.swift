// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanResources

/// The resource plugin on the widget (D324, D327): the sampler's face and hover card as one more ring in the Dock.
/// The ring is the subscription ring's size (D163): outer arc memory (solid used, faint cached), inner thin arc CPU,
/// always in orchid; only the readout's number takes a tone (D236). The card rows follow variant A. B4f (owner 11-21):
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
    public static let ink = "#da66c2"
    static let rgb = (red: Double(0xda) / 255, green: Double(0x66) / 255, blue: Double(0xc2) / 255)

    public static func tone(_ t: ResourceTone) -> DockQuotaStatus {
        switch t { case .normal: return .normal; case .warning: return .warning; case .critical: return .critical }
    }

    /// One card row: label · bar · % · side value. Variant A: `emphasised` is ink only (no background);
    /// `tinted` is the problem-row background; the bar is orchid and the number keeps an amber/red tone.
    public static func row(_ r: ResourceCard.Row) -> DockCardRow {
        var row = DockCardRow(id: "resource:" + r.id.rawValue, kind: .quota, label: r.label, value: "\(r.percent)%", detail: r.side,
                              remainingFraction: nil, fillFraction: .some(r.fill), tone: tone(r.tone), emphasised: r.ink == .full)
        row.plugin = DockCardPluginStyle(red: rgb.red, green: rgb.green, blue: rgb.blue, faintFill: r.cachedFill, notch: r.notch, tinted: r.tinted)
        return row
    }

    /// The hover card's rows, footer and its "驾驶舱大屏 ›" action (D327) for the Dock.
    public static func card(_ card: ResourceCard) -> DockPluginCard {
        DockPluginCard(rows: card.rows.map(row), footer: card.footer, action: card.screenLink)
    }

    public static func ring(face: ResourceFace, card: ResourceCard, language: ResourceLanguage) -> DockPluginRing? {
        let live = Self.card(card)
        return DockPluginRing(hex: ink, outer: min(1, max(0, face.memoryUsed)), outerFaint: min(1 - min(1, max(0, face.memoryUsed)), max(0, face.memoryCached)),
                              inner: min(1, max(0, face.cpu)), readout: "\(face.shown.percent)%", readoutTone: tone(face.shown.tone),
                              animates: face.animates, cardRows: live.rows, cardFooter: live.footer, cardAction: live.action,
                              spokenReadout: face.shown.text(language))
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
    public init(base: any DockContentProvider) { self.base = base }
    public func makeContent(_ context: DockContentContext) -> DockContent {
        let content = base.makeContent(context)
        guard let extra = resourceInput else { return content }
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
    public init(sampler: ResourceSampler, provider: ResourceDockContentProvider, language: @escaping () -> ResourceLanguage,
                refreshCard: @escaping () -> Void = {}, refresh: @escaping () -> Void) {
        self.sampler = sampler; self.provider = provider; self.language = language; self.refresh = refresh; self.refreshCard = refreshCard
        sampler.onRedraw = { [weak self] face in self?.redraw(face) }
        sampler.onCardChange = { [weak self] in self?.cardChanged() }
    }
    /// The card for the latest sample, the readout shown now and the current cadence.
    func card(_ shown: ResourceShown) -> ResourceCard? {
        guard let sample = sampler.history.samples.last, let interval = ResourceCadence.interval(sampler.visibility) else { return nil }
        return ResourceCard(sample: sample, shown: shown, cpuPeak: sampler.history.peakCPU, interval: interval, language: language())
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
    private func redraw(_ face: ResourceFace) {
        provider.resourceInput = ResourceDockBridge.input(face: face, card: card(face), language: language())
        refresh()
    }
    /// Plugin state, cockpit column and widget visibility; off removes the ring at once.
    public func setVisibility(_ v: ResourceVisibility) {
        sampler.setVisibility(v)
        if !v.pluginEnabled, provider.resourceInput != nil { provider.resourceInput = nil; refresh() }
    }
}
