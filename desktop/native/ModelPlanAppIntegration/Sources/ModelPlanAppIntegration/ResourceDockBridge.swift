// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanResources

/// The resource plugin on the widget (D324, D327): the sampler's face and hover card as one more ring in the Dock.
/// The ring is the subscription ring's size (D163): outer arc memory (solid used, faint cached), inner thin arc CPU,
/// always in orchid; only the readout's number takes a tone (D236). The card rows follow variant A.
public enum ResourceDockBridge {
    public static let subscriptionID = "plugin:resources"
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

    public static func ring(face: ResourceFace, card: ResourceCard, language: ResourceLanguage) -> DockPluginRing? {
        DockPluginRing(hex: ink, outer: min(1, max(0, face.memoryUsed)), outerFaint: min(1 - min(1, max(0, face.memoryUsed)), max(0, face.memoryCached)),
                       inner: min(1, max(0, face.cpu)), readout: face.shown.text(language), readoutTone: tone(face.shown.tone),
                       animates: face.animates, cardRows: card.rows.map(row), cardFooter: card.footer)
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

/// Adds the resource ring to another provider's content. The ring comes first unless the user ordered it elsewhere
/// (unknown ids follow the saved order, SubscriptionOrder.orderedIDs).
@MainActor public final class ResourceDockContentProvider: DockContentProvider {
    private let base: any DockContentProvider
    /// Set by the host on every admitted redraw; nil hides the ring (plugin off or no sample yet).
    public var resourceInput: DockInstrumentInput?
    public init(base: any DockContentProvider) { self.base = base }
    public func makeContent(_ context: DockContentContext) -> DockContent {
        let content = base.makeContent(context)
        guard let extra = resourceInput else { return content }
        let s = content.snapshot
        let snapshot = CommunityDockSnapshot(inputs: [extra] + s.inputs.filter { $0.id != extra.id }, subscriptions: s.subscriptions,
            presentationRows: s.presentationRows, unavailableReason: s.unavailableReason,
            readerDiagnostics: s.readerDiagnostics, emptyDiagnostic: s.emptyDiagnostic)
        return DockContent(snapshot: snapshot, menuStatusLines: content.menuStatusLines, emptyText: content.emptyText,
                           signals: content.signals, recomputeDeadline: content.recomputeDeadline)
    }
}

/// Connects the one ResourceSampler to the widget: every admitted redraw (≥ 1 point change, D324) rebuilds the
/// resource input and asks the Dock to refresh; turning the plugin off removes the ring.
@MainActor public final class ResourceWidgetBinding {
    public let provider: ResourceDockContentProvider
    private let sampler: ResourceSampler
    private let language: () -> ResourceLanguage
    private let refresh: () -> Void
    public init(sampler: ResourceSampler, provider: ResourceDockContentProvider, language: @escaping () -> ResourceLanguage,
                refresh: @escaping () -> Void) {
        self.sampler = sampler; self.provider = provider; self.language = language; self.refresh = refresh
        sampler.onRedraw = { [weak self] face in self?.redraw(face) }
    }
    /// The card for the latest sample (the hover card reads it at hover time through the Dock input).
    func card(_ face: ResourceFace) -> ResourceCard? {
        guard let sample = sampler.history.samples.last, let interval = ResourceCadence.interval(sampler.visibility) else { return nil }
        return ResourceCard(sample: sample, shown: face.shown, cpuPeak: sampler.history.peakCPU, interval: interval, language: language())
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
