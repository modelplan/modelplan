// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanAssembly
import ModelPlanInstruments
import ModelPlanCockpitShell
import ModelPlanField

/// Public-only facts for the material supplier. No personal snapshot, account, or field extras.
public struct CommunityFieldScope: Equatable, Sendable {
    public let projection: FieldPublicProjection
    public let admittedPublicIDs: [String]
    public let configurations: [String: EffortConfiguration]
    public let appearance: FieldAppearance
    public let viewport: FieldViewport
    public init(projection: FieldPublicProjection, admittedPublicIDs: [String],
                configurations: [String: EffortConfiguration], appearance: FieldAppearance, viewport: FieldViewport) {
        self.projection = projection; self.admittedPublicIDs = admittedPublicIDs
        self.configurations = configurations; self.appearance = appearance; self.viewport = viewport
    }
}

/// Private suppliers provide their own frozen shell/frames and current-scope still admission.
/// The community edition uses the complete neutral provider below, without private resources.
@MainActor public struct CommunityCockpitSupply {
    public let skin: any CockpitShellSkin
    public let frames: (CockpitSurfaceLayout) throws -> InstrumentSurfaceFrames
    public let still: (CommunityFieldScope) throws -> CockpitStill?
    public init(skin: any CockpitShellSkin,
                frames: @escaping (CockpitSurfaceLayout) throws -> InstrumentSurfaceFrames,
                still: @escaping (CommunityFieldScope) throws -> CockpitStill?) {
        self.skin = skin; self.frames = frames; self.still = still
    }
    public static func neutral() -> Self {
        .init(skin: CommunityCockpitSkin(), frames: { layout in
            guard let e = layout.slots[.engines], let c = layout.slots[.console] else { throw InstrumentSurfaceError.invalidFrames }
            return try .init(engines: e.size, console: c.size,
                mainScreen: .init(x: 0, y: 0, width: 600, height: c.height),
                faders: .init(x: 640, y: 0, width: c.width - 640, height: c.height))
        }, still: { _ in nil })
    }
}

@MainActor private final class CommunityCockpitSkin: CockpitShellSkin {
    private let neutral = NeutralCockpitShellSkin()
    func layout(for state: CockpitSurfaceState) throws -> CockpitSurfaceLayout {
        .init(rootSize: .init(width: 1040, height: 900), drawableBounds: .init(x: 0, y: 0, width: 1040, height: 900),
            slots: [.window: .init(x: 0, y: 0, width: 1040, height: 200),
                    .engines: .init(x: 0, y: 210, width: 1040, height: 240),
                    .console: .init(x: 0, y: 460, width: 1040, height: 440)], expectedStillKey: nil)
    }
    func backdrop(for state: CockpitSurfaceState, layout: CockpitSurfaceLayout, matchingStill: CGImage?) throws -> CGImage {
        try neutral.backdrop(for: state, layout: layout, matchingStill: matchingStill)
    }
    func stationLayers(for state: CockpitSurfaceState, layout: CockpitSurfaceLayout) throws -> [CALayer] { [] }
    func discardTransientResources() {}
}

/// Conversion of the existing Assembly result, with no eligibility/order/scoring computation.
@MainActor private final class CommunityCockpitInputs: CockpitInstrumentInputProviding {
    func input(for o: CockpitInstrumentObservation) throws -> InstrumentSurfaceInput {
        let selected = o.selection.instruments
        let usable = selected != nil && selected?.publicDefaultFallback == false
        let table = engineInputs(o)
        let channels = o.selection.models.map { FaderChannelInput(model: $0, basisNote: o.selection.modelAvailabilityNotes[$0.id]) }
        let effort = EffortPageSnapshot(models: o.selection.models, selection: selected,
            publication: selected?.publication, publicationUsable: usable, scope: o.scope, language: o.language)
        return try .init(observationID: (selected?.publication.publicationID ?? "unavailable") + "-" + String(o.now.timeIntervalSince1970),
            columns: table.columns, identities: table.identities, channels: channels,
            selection: selected, publication: selected?.publication, publicationUsable: usable,
            scope: o.scope, language: o.language, now: o.now, compact: false, showProjectNames: o.showProjectNames,
            pages: [.init(.overview, lines: [o.selection.selectionNotice ?? o.selection.emptyStateMessage]),
                    .init(.effort, effort: effort),
                    .init(.subscriptions, lines: [o.language == .chinese ? "选择额度表中的订阅查看当前范围。" : "Choose a subscription in the engine table for its current scope."]),
                    .init(.destinations, lines: [o.language == .chinese ? "去向详情尚未接入此视图。" : "Destination details are not connected to this view."])],
            readers: [.init(sourceID: "desktop", state: .unknown, evidence: .init(freshness: .unknown))])
    }
    /// Reuses Core's expiry/binding verdicts; no duplicate reader, ownership inference or TTL.
    private func engineInputs(_ o: CockpitInstrumentObservation) -> (columns: [EngineColumn], identities: [String: EngineTableIdentity]) {
        guard let snapshot = o.snapshot else { return ([], [:]) }
        let accounts = (snapshot.personal.accounts ?? []).filter { $0.subscription?.status == "verified" }
        let grouped = Dictionary(grouping: accounts, by: { $0.subscription!.subscriptionRef })
        var columns: [EngineColumn] = [], identities: [String: EngineTableIdentity] = [:]
        var seen = Set<String>()
        for account in accounts {
            guard let id = account.subscription?.subscriptionRef, seen.insert(id).inserted else { continue }
            let rows = grouped[id] ?? []
            var windows: [InstrumentQuota] = []
            for (rowIndex, row) in rows.enumerated() {
                for (index, window) in (row.windows ?? []).enumerated() {
                    let readings = snapshot.presentation.quotas.filter { $0.subscription == id && $0.source == row.source && $0.kind == window.kind }
                    let reading = readings.count == 1 ? readings.first : nil
                    let period: QuotaPeriod
                    if window.windowMinutes == 300 { period = .fiveHours }
                    else if window.windowMinutes == 10080 { period = .weekly }
                    else { period = .other(window.kind) }
                    windows.append(.init(id: row.source + ":" + String(rowIndex) + ":" + window.kind + ":" + String(index), period: period,
                        remaining: reading?.remaining, resetsAt: window.resetsAt?.date, durationMinutes: window.windowMinutes,
                        readable: snapshot.presentation.actionable && reading != nil && reading?.reason == nil))
                }
            }
            let quotas = QuotaRows(windows: windows, now: o.now)
            let evidence = InstrumentEvidence(source: account.source, observedAt: account.observedAt?.date,
                validUntil: snapshot.personal.validUntil?.date,
                freshness: snapshot.presentation.actionable ? .fresh : .stale,
                reason: snapshot.presentation.unavailableReason)
            columns.append(.init(id: id, quotas: quotas, todayTokens: nil, todayGenerationTPS: nil, evidence: evidence))
            identities[id] = .init(name: account.plan ?? account.source, shortName: account.plan ?? account.source, brandID: account.source)
        }
        return (columns, identities)
    }
}

@MainActor enum CommunityCockpitFactory {
    static func make(mainScreen: MainScreenView, supply: CommunityCockpitSupply,
                     preferences: PreferenceFile?, window: any CommunityFieldWindow) throws -> CockpitInstrumentComposition {
        let shell = CockpitShellSurface(skin: supply.skin)
        try shell.configure(.init(profile: .full, closed: false, appearance: .init()))
        let composition = CockpitInstrumentComposition(mainScreen: mainScreen, shell: shell,
            provider: CommunityCockpitInputs(), frames: {
                guard let layout = shell.surfaceLayout else { throw InstrumentSurfaceError.invalidFrames }
                return try supply.frames(layout)
            })
        let field = CommunityCockpitField(shell: shell, supply: supply, preferences: preferences, window: window)
        composition.field = field
        return composition
    }
}
