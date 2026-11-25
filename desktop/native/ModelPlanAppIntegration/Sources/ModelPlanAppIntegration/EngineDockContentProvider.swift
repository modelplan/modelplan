// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import ModelPlanEngineStore
import ModelPlanDock
import ModelPlanWire
import ModelPlanSettings

/// Scheduling facts only; this type does not determine retained-value policy.
public enum EngineRecomputeDeadline: Equatable, Sendable {
    case scheduled(Date, hasUnknownDeadline: Bool)
    case unknown
    case none
}

/// An admitted window fact scoped to the same member key and projection. A
/// fallback member key is not a verified subscription identity. This does not
/// change the row's aggregate stale state or authorize cross-snapshot caching.
public struct EngineVerifiedWindow: Equatable, Sendable {
    public let memberID: String
    public let windowID: String
    public let remainingPercent: Double
    public let resetsAt: Date?
    public let issuedAt: Date
    public let until: Date
    /// A snapshot/generation token must additionally be checked by the host.
    public func isValid(memberID: String, windowID: String, at now: Date) -> Bool {
        now.timeIntervalSinceReferenceDate.isFinite && memberID == self.memberID && windowID == self.windowID && now >= issuedAt && now < until
    }
}

/// DOCK-3.2-50 / DOCK-3.3-09 (amended, D290 item 9): an earlier reading of one stable member, kept after its refresh
/// did not land. It is never a proof of currency: the host shows it only for a stale member, only until `until` (the
/// window's reset), and dims it an hour after `observedAt`. A retained window never alerts.
public struct EngineRetainedWindow: Equatable, Sendable {
    public let memberID: String
    public let windowID: String
    public let remainingPercent: Double
    public let resetsAt: Date?
    public let observedAt: Date
    public let until: Date
}

/// The content and scheduling facts from one synchronous Provider pass.
/// Host-owned snapshot tokens are still required to fence later callbacks.
public struct EngineContentAndDeadline: Sendable {
    public let content: DockContent
    public let deadline: EngineRecomputeDeadline
    public let verifiedWindows: [EngineVerifiedWindow]
    /// Kept readings from the same pass (WP-15); separate from `verifiedWindows`, which stay current-only.
    public var retainedWindows: [EngineRetainedWindow] = []
}

/// The merged generated row decoder rejects malformed non-null reset timestamps
/// as an invalid row. There is no runtime override for this decoder contract.
enum EngineResetTimestampContract {
    enum Assurance: Equatable { case unverified, malformedNonNullRejected }
    static let activeAssurance: Assurance = .malformedNonNullRejected

    static func date(_ stamp: WireTimestamp?) -> Date? {
        guard let stamp else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: stamp.rawValue) ?? ISO8601DateFormatter().date(from: stamp.rawValue)
    }

    /// Null is admissible only under the strict decoder and when the remaining
    /// independent window and account deadlines agree.
    static func bound(account: Date, window: Date, reset: Date?, assurance: Assurance) -> Date? {
        guard account.timeIntervalSinceReferenceDate.isFinite, window.timeIntervalSinceReferenceDate.isFinite else { return nil }
        if let reset {
            guard reset.timeIntervalSinceReferenceDate.isFinite, window == min(account, reset) else { return nil }
            return window
        }
        guard assurance == .malformedNonNullRejected, window == account else { return nil }
        return window
    }
}

/// Reads only already-admitted rows. The consumer must recompute after each
/// replacement or invalidation and use its own snapshot token to cancel timers.
public enum EngineDeadlineFacts {
    public static func evaluate(rows: [RowsRow], events: [EngineResetEvent] = [], eventRows: [RowsRow]? = nil, now: Date) -> EngineRecomputeDeadline {
        guard now.timeIntervalSinceReferenceDate.isFinite else { return .unknown }
        var next: Date?
        var unknown = false
        func includeDate(_ date: Date) {
            guard date.timeIntervalSinceReferenceDate.isFinite else { unknown = true; return }
            guard date > now else { return }
            if next.map({ date < $0 }) ?? true { next = date }
        }
        func include(_ stamp: WireTimestamp?) {
            guard let date = EngineResetTimestampContract.date(stamp) else { unknown = true; return }
            includeDate(date)
        }
        for row in rows where row.consent == .allowed || row.consent == .implicit || row.consent == .notRequired {
            let accounts = row.accounts.filter { $0.valueState == .current || $0.valueState == .retained }
            guard !accounts.isEmpty else { continue }
            include(row.expiresAt)
            for account in accounts {
                include(account.freshUntil)
                for window in account.windows where window.current {
                    include(window.validUntil)
                    if window.resetsAt != nil { include(window.resetsAt) }
                    else if let accountDate = EngineResetTimestampContract.date(account.freshUntil),
                            let windowDate = EngineResetTimestampContract.date(window.validUntil),
                            EngineResetTimestampContract.bound(account: accountDate, window: windowDate, reset: nil,
                                assurance: EngineResetTimestampContract.activeAssurance) != nil {
                        // The strict decoder distinguishes admitted null from malformed input.
                    } else { unknown = true }
                }
            }
        }
        // Use the same admitted member catalogue as reset presentation. In
        // particular, a retired catalogue row may still contain an account.
        let eventMembers = EngineAccountMemberCatalogue(rows: eventRows ?? rows).members
        for event in events where event.publishedAt < event.expiresAt {
            let matches = eventMembers.contains { member in
                member.rowID == event.rowID && (event.planIDs.map { $0.contains(member.account.plan.id) } ?? true)
            }
            guard matches else { continue }
            includeDate(event.publishedAt)
            includeDate(event.expiresAt)
            // D166: the confirmed dot ends before the event does; recompute then on the existing deadline path.
            if event.status == "confirmed" {
                includeDate((event.confirmedAt ?? event.publishedAt).addingTimeInterval(DockResetSignal.confirmedDotLifetime))
            } else if let through = event.scheduledThrough {
                // The card turns to "awaiting confirmation" when the forecast window ends.
                includeDate(through)
            }
        }
        if let next { return .scheduled(next, hasUnknownDeadline: unknown) }
        return unknown ? .unknown : .none
    }
}

/// Shared host seam backed only by admitted app-server rows. Legacy context data is unused.
@MainActor public final class EngineDockContentProvider: DockContentProvider {
    public var resetEventState:() -> EngineRowsEventState = { .absentFromSchema }
    public private(set) var signals:[DockSubscriptionSignal] = []
    /// Facts from the latest makeContent pass, not a timer or a freshness claim.
    /// A consumer must discard its prior schedule on replacement/clear and
    /// invoke makeContent again before reading this value.
    public private(set) var recomputeDeadline: EngineRecomputeDeadline = .unknown
    public private(set) var verifiedWindows: [EngineVerifiedWindow] = []
    public private(set) var retainedWindows: [EngineRetainedWindow] = []
    /// WP-06 hook: the estimated cost text for a member's today row ("≈$10.2"). Unset in WP-15, so no ≈$ is shown yet.
    public var todayCost: ((String) -> String?)?
    /// Consumers must discard session placement and scope for these members on every refresh.
    public private(set) var memberInstability:[String:Bool] = [:]
    public var language="en"
    private var english:Bool { language == "en" }
    private func text(_ value:RowsText) -> String { english ? value.en : value.zh }
    private func text(_ value:RowsName) -> String { english ? value.en : value.zh }
    private let liveMenus = LivePrivateMenus()
    func bindDockMenuTracking(_ host: StaticDockPreviewHost) { liveMenus.watch(host) }
    func scrubInvalidatedMenus() { if source.dockContent.status == .cleared { liveMenus.scrubAll() } }
    public let source: EngineDockMenuProvider
    public init(source: EngineDockMenuProvider) { self.source = source }
    public func makeContentAndDeadline(_ context: DockContentContext) -> EngineContentAndDeadline {
        project(context)
    }
    public func makeContent(_ context: DockContentContext) -> DockContent {
        project(context).content
    }
    private func project(_ context: DockContentContext) -> EngineContentAndDeadline {
        let value = source.dockContent
        var inputs: [DockInstrumentInput] = []
        var reasons: [String: DockContentRow] = [:]
        let members=EngineAccountMemberCatalogue(rows:value.dockRows).members
        let passWindows = value.status == .ready ? verifiedWindowFacts(members, now: context.now) : []
        let passInstability=Dictionary(uniqueKeysWithValues:members.map { ($0.id,!$0.isStable) })
        let events:[EngineResetEvent]
        if case .available(let admitted)=resetEventState() { events=admitted } else { events=[] }
        // A window with a current proof is never also a kept reading (the host would refuse the pair).
        var passRetained: [EngineRetainedWindow] = []
        if value.status == .ready {
            for member in members {
                for window in member.account.windows {
                    guard let kept = retainedWindow(member, window, now: context.now),
                          !passWindows.contains(where: { $0.memberID == kept.memberID && $0.windowID == kept.windowID }) else { continue }
                    passRetained.append(kept)
                }
            }
        }
        var passDeadline = EngineDeadlineFacts.evaluate(rows: value.dockRows + value.menuRows, events: events, eventRows: value.dockRows, now: context.now)
        // A kept reading changes look an hour after it was read and disappears when its window resets: both are recompute times.
        var keptBoundaries: [Date] = []
        for kept in passRetained {
            keptBoundaries.append(kept.until)
            if let dims = DockStaleRule.dimsAt(observedAt: kept.observedAt, now: context.now) { keptBoundaries.append(dims) }
        }
        if let soonest = keptBoundaries.filter({ $0 > context.now }).min() {
            switch passDeadline {
            case .scheduled(let date, let unknown): passDeadline = .scheduled(min(date, soonest), hasUnknownDeadline: unknown)
            case .unknown: passDeadline = .scheduled(soonest, hasUnknownDeadline: true)
            case .none: passDeadline = .scheduled(soonest, hasUnknownDeadline: false)
            }
        }
        var passSignals:[DockSubscriptionSignal] = []
        for member in members {
            let row=member.row
            let input = makeInput(member, now: context.now)
            inputs.append(input)
            let message = message(row, now: context.now)
            let account=member.account
            let hasWindowSources = account.windows.contains { $0.source != nil }
            var resets:[String:Date]=[:]
            var descriptions:[String:String]=[:]
            for window in account.windows {
                if let reset=date(window.resetsAt) { resets[window.id]=reset }
                switch window.role {
                case .daily: descriptions[window.id]=english ? "Daily":"每日"
                case .monthly: descriptions[window.id]=english ? "Monthly":"每月"
                case .other,.unknown: descriptions[window.id]=text(window.label)
                case .session,.weekly:break
                }
            }
            var reserve:[DockCardRow]=[]
            let today = todayRow(member)
            let memberEvents=events.filter { event in
                event.rowID == member.rowID && event.publishedAt <= context.now && context.now < event.expiresAt &&
                (event.planIDs.map { $0.contains(member.account.plan.id) } ?? true)
            }
            let confirmedIDs=Set(memberEvents.filter{$0.status == "confirmed"}.compactMap(\.confirms))
            let preferred=memberEvents.filter { $0.status != "announced" || !confirmedIDs.contains($0.id) }
                .max { $0.publishedAt < $1.publishedAt }
            var signal=DockSubscriptionSignal(id:member.id);signal.dataState=input.dataState
            if let event=preferred {
                if event.status == "confirmed" {
                    let confirmedAt=event.confirmedAt ?? event.publishedAt
                    var reset=DockResetSignal(id:event.id,status:.confirmed,confirmedAt:confirmedAt,expiresAt:event.expiresAt)
                    reset.kind=event.isResetCredit ? .resetCredit : .directReset
                    // A local reading that restarted after the confirmation is an observation, not proof of the
                    // public event (same predicate as the notification).
                    reset.restartedReading = event.restartedReading(in: member.account)
                    signal.reset=reset
                } else {
                    var reset=DockResetSignal(id:event.id,status:.announced,announcedAt:event.publishedAt,scheduledThrough:event.expiresAt,expiresAt:event.expiresAt)
                    reset.kind=event.isResetCredit ? .resetCredit : .directReset
                    signal.reset=reset
                }
            }
            passSignals.append(signal)
            if let event = preferred {
                let wording = EngineResetEventWording(english: english)
                reserve.append(.init(id: "reset-event:" + event.id + ":" + event.status, kind: .notice,
                    label: wording.label(event), value: wording.title(event, now: context.now),
                    detail: wording.detail(rose: signal.reset?.restartedReading == true),
                    pill: event.status == "confirmed" ? (english ? "Confirmed" : "已确认") : (english ? "Announced" : "已预告")))
            }
            if let today { reserve.append(today) }
            let resetCount = resetCountRow(member, now: context.now)
            if let resetCount { reserve.append(resetCount.row) }
            if (row.consent == .allowed || row.consent == .implicit || row.consent == .notRequired),
               account.valueState == .current || account.valueState == .retained,
               let credits=account.credits,let balance=credits.balance,balance.isFinite,balance >= 0 {
                let lastKnown = account.valueState == .retained || row.state != .fresh ||
                    (date(row.expiresAt).map { context.now >= $0 } ?? false) ||
                    (date(account.freshUntil).map { context.now >= $0 } ?? false)
                func reserveDetail(_ detail: String = "") -> String {
                    [detail, lastKnown ? (english ? "Last known reading" : "上次读数") : ""].filter { !$0.isEmpty }.joined(separator: " · ")
                }
                switch credits.unit {
                case "credits":
                    let number:String?
                    switch M5CreditsDisplayFormat.text(balance,unit:.credits,english:english) {
                    case .formatted(let text): number=text
                    case .fallback(let value, _): number=String(value)
                    case .missing,.invalid: number=nil
                    }
                    if let number { reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Reserve":"储备",value:number+(english ? " credits":" 点数"),detail:reserveDetail(),hint:"credits")) }
                case "money":
                    // G3-103 follow-up: a reader that reports its currency (Grok: USD) shows it; only a balance
                    // without one keeps the "currency not reported" note.
                    if let code = credits.currency, let money = M5CreditsDisplayFormat.currencyText(balance, code: code, english: english) {
                        reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Balance":"余额",value:money,detail:reserveDetail(),hint:"money"))
                    } else {
                        reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Balance":"余额",value:M5CreditsDisplayFormat.moneyText(balance,english:english),detail:reserveDetail(english ? "Currency not reported":"未报告币种"),hint:"money"))
                    }
                default:
                    let unit=M5CreditsDisplayFormat.Unit(identifier:credits.unit)
                    switch M5CreditsDisplayFormat.unknownUnitText(balance,unit:unit,knowledge:.unknown,english:english) {
                    case .rendered(_,_,let text,_):
                        reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Reserve":"储备",value:text,detail:reserveDetail()))
                    case .fallback(let value,_),.notApplicable(let value?,_):
                        reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Reserve":"储备",value:String(value),detail:reserveDetail()))
                    case .missing,.invalid,.notApplicable(nil,_): break
                    }
                }
            }
            // D228/D233: a reading with a balance but no usage percentage needs no action, so the shared cause
            // table's sentence is only a small grey footnote at the bottom of the card (no fix line, no button).
            if row.reason.code == .usageNotReported,
               let entry = ReaderCauseTable.entry(code: "usage_not_reported", tool: row.id, toolName: member.name(english: english)) {
                reserve.append(.init(id: "usage-not-reported", kind: .footnote, label: "", value: entry.reason.value(english ? .english : .chinese)))
            }
            let cardState: DockCardReadingState
            if row.consent != .allowed && row.consent != .implicit && row.consent != .notRequired {
                cardState = .error
            } else if row.state == .pending {
                cardState = .loading
            } else if row.state == .failed {
                cardState = account.valueState == .retained && account.observedAt != nil ? .errorLastGood : .error
            } else if row.state == .stale || account.valueState == .retained ||
                        (date(row.expiresAt).map { context.now >= $0 } ?? false) ||
                        (date(account.freshUntil).map { context.now >= $0 } ?? false) {
                cardState = .stale
            } else {
                cardState = input.dataState == .fresh ? .ok : .error
            }
            let observations: [String: DockWindowObservation]? = hasWindowSources
                ? Dictionary(grouping: account.windows, by: \.id).compactMapValues { windows in
                    guard windows.count == 1, let window = windows.first else { return nil }
                    let observed = date(window.observedAt)
                    // A single unbound account, such as local Codex history, has no subscription
                    // reference but is still one stable member: its card keeps its source and age.
                    let verifiedRetained = account.valueState == .retained && member.isStable &&
                        (member.subscriptionRef == nil || member.subscriptionRef == member.id) && sourceState(member, now: context.now) == .stale &&
                        window.source?.isKnown == true && (observed.map { $0 <= context.now } ?? false)
                    return DockWindowObservation(sourceName: windowSourceName(window.source),
                                                 observedAt: observed, verifiedRetained: verifiedRetained)
                }
                : nil
            // D41: one plain sentence and one button, whatever the Keychain outcome was.
            let needsKeychain = row.id == "claude" && row.state == .needsKeychain
            let cause = needsKeychain ? nil : causeLine(member, now: context.now)
            let keychainReason: String = english ? "Keychain access needed" : "需要允许读取钥匙串"
            let messageReason: String = text(message.0.text)
            let reasonText: String
            if needsKeychain {
                reasonText = keychainReason
            } else if let causeReason = cause?.reason {
                reasonText = causeReason
            } else {
                reasonText = messageReason
            }
            let nextStepText: String
            if let causeNext = cause?.nextStep {
                nextStepText = causeNext
            } else if let messageNext = message.1 {
                nextStepText = text(messageNext.text)
            } else {
                nextStepText = ""
            }
            let planName: String = account.plan.name.map { text($0) } ?? ""
            let linkList = preferred.map(resetEventLinks) ?? []
            let presentation = DockContentRow(input: input, reason: reasonText, nextStep: nextStepText,
                originalObservedAt: date(account.observedAt), plan: planName,
                sourceName: sourceName(account.route), resetTimes: resets, windowDescriptions: descriptions,
                additionalRows: reserve, resetCountExpiry: resetCount?.expiry, links: linkList,
                windowObservations: observations, cardReadingState: cardState,
                runOutTimes: runOutTimes(member, forecasts: value.forecasts, now: context.now))
            reasons[member.id] = presentation
            if needsKeychain { reasons[member.id]?.actionLabel = english ? "Allow reading" : "允许读取" }
            // DOCK-3.8-53 (WP-15; was D87 slice 9's Settings link): any other named cause offers one more read.
            else if cause != nil { reasons[member.id]?.actionLabel = WidgetCardText.readAgain.value(english ? .english : .chinese) }
        }
        let status: String
        switch value.status {
        case .loading: status = english ? "Loading readings…" : "正在读取…"
        case .empty: status = english ? "No readings are available. Check Settings." : "暂无读数，请检查设置。"
        case .failed: status = EngineRowsText.readingServiceUnavailable.value(english ? .english : .chinese)
        case .cleared: status = english ? "Readings cleared. Waiting for current data." : "读数已清除，正在等待当前数据。"
        case .ready: status = value.summary.map { text($0.text) } ?? (english ? "Readings" : "读数")
        }
        let lines = EngineAccountMemberCatalogue(rows:value.menuRows).members.map { member -> String in
            let row=member.row
            let reading = try? DockInstrumentProjection.evaluate(makeInput(member, now: context.now), now: context.now)
            let number = reading?.remainingPercent.map { " · \(Int($0.rounded()))%" } ?? ""
            return member.name(english:english) + number + " · " + text(message(row, now: context.now).0.text)
        }
        // S9 (#1099 D322-2): a row on the Settings surface only (a free $0 Grok Build balance) has accounts but no
        // Dock member; its Settings line comes from the same account projection, from the Settings surface.
        let memberRows = Set(members.map(\.rowID)), memberIDs = Set(members.map(\.id))
        let settingsOnly = EngineAccountMemberCatalogue(rows: value.settingsRows.filter {
            !$0.accounts.isEmpty && !memberRows.contains($0.id) && !$0.surfaces.contains(.dock)
        }).members.filter { !memberIDs.contains($0.id) }
        let settingsOnlyIDs = Set(settingsOnly.map(\.id))
        let subscriptions: [SettingsSubscription] = (members + settingsOnly).map { member -> SettingsSubscription in
            let retainedFailure = (member.row.state == .stale || member.account.valueState == .retained)
                ? member.account.lastFailure?.code.rawValue : nil
            let failing = member.row.state == .failed || member.row.state == .needsAction
            let causeCode: String?
            // Only a member that is failing carries a cause; a stale but live row keeps its own status.
            if let retainedFailure {
                causeCode = retainedFailure
            } else if failing {
                causeCode = message(member.row, now: context.now).0.code.rawValue
            } else if settingsOnlyIDs.contains(member.id), member.row.reason.code == .usageNotReported {
                // The Settings line is the one place it is shown, so it says why (no usage percentage).
                causeCode = member.row.reason.code.rawValue
            } else {
                causeCode = nil
            }
            var planName: String = member.account.plan.name.map { text($0) } ?? ""
            // S9: "only the balance is shown" (usage_not_reported) holds on the Settings line too.
            if settingsOnlyIDs.contains(member.id), let balance = settingsBalance(member.account) {
                planName = planName.isEmpty ? balance : planName + " · " + balance
            }
            return SettingsSubscription(id: member.id,
                name: .init(member.name(english: true), member.name(english: false)),
                plan: planName, vendor: member.row.vendorKey ?? "",
                source: sourceState(member, now: context.now), isUnstable: !member.isStable,
                causeCode: causeCode, tool: member.row.id)
        }
        // SET-9-42: a reader that failed before any account or reading exists has no Dock member, yet its tool
        // still owns a Settings row carrying the cause. Build those rows from the Settings surface, not the Dock.
        let accountless: [SettingsSubscription] = value.settingsRows.compactMap { row in
            guard row.accounts.isEmpty, !memberRows.contains(row.id),
                  row.state == .failed || row.state == .needsAction || row.state == .needsKeychain else { return nil }
            let authorized = row.consent == .allowed || row.consent == .implicit || row.consent == .notRequired
            return SettingsSubscription(id: row.id, name: .init(row.name.en, row.name.zh), vendor: row.vendorKey ?? row.id,
                source: authorized ? .unavailable : .denied, isUnstable: true, causeCode: message(row, now: context.now).0.code.rawValue)
        }
        let content = DockContent(snapshot: .init(inputs: inputs, subscriptions: subscriptions + accountless,presentationRows: reasons),
                     menuStatusLines: lines.isEmpty ? [status] : lines, emptyText: status, signals:passSignals)
        verifiedWindows = passWindows; retainedWindows = passRetained; recomputeDeadline = passDeadline
        memberInstability = passInstability; signals = passSignals
        return .init(content: content, deadline: passDeadline, verifiedWindows: passWindows, retainedWindows: passRetained)
    }
    /// DOCK-3.8-51 (board-3): "≈$10.2 33.9M" on the left, "● 1 个在跑 · 66 t/s" on the right; an absent half is
    /// left out and the row is left out when both are. No "--" placeholders. The ≈$ half waits for WP-06 (`todayCost`).
    private func todayRow(_ member: EngineAccountMember) -> DockCardRow? {
        let today = member.account.today
        let language: SettingsLanguage = english ? .english : .chinese
        let running = today?.runningSessions.flatMap { $0 > 0 ? WidgetCardText.running($0).value(language) : nil }
        return DockTodayRow.make(label: WidgetCardText.today.value(language), cost: todayCost?(member.id),
                                 tokens: today?.observedTotalTokens ?? today?.observedOutputTokens, running: running, tokensPerSecond: today?.generationTps)
    }
    /// WP-15: the producer's run-out forecast (WP-03) for a current window of this same verified subscription, when it
    /// falls before the window's reset; the card writes "约40m用完" in place of the reset time and the footer can alert.
    private func runOutTimes(_ member: EngineAccountMember, forecasts: [WireCockpitForecast], now: Date) -> [String: Date] {
        guard let ref = member.subscriptionRef, member.isStable, member.id == ref, member.account.valueState == .current,
              member.row.consent == .allowed || member.row.consent == .implicit || member.row.consent == .notRequired else { return [:] }
        var result: [String: Date] = [:]
        for forecast in forecasts where forecast.source == member.row.id && forecast.subscriptionRef == ref {
            guard let window = member.account.windows.first(where: { $0.id == forecast.windowId && $0.current }),
                  let runsOut = date(forecast.runsOutAt), runsOut > now,
                  date(window.validUntil).map({ now < $0 }) ?? false else { continue }
            if let reset = date(window.resetsAt), reset <= runsOut { continue }
            result[window.id] = min(result[window.id] ?? runsOut, runsOut)
        }
        return result
    }
    /// DOCK-3.2-50 / DOCK-3.3-09 (amended): a stale member keeps the number it last read for a window until that window
    /// resets. Only a stable member that is its own subscription (or a single unbound account), with a known reading time
    /// and a producer-stated reset (never a guessed end). Never a current window, never a peer's value.
    private func retainedWindow(_ member: EngineAccountMember, _ window: RowsWindow, now: Date) -> EngineRetainedWindow? {
        let row = member.row, account = member.account
        let staleAfterExpiry = date(row.expiresAt).map { now >= $0 } == true && row.stateAfterExpiry?.state == .stale
        // WP-15 keeps producer-declared stale/retained readings until reset. A fresh row that merely reaches its validity
        // deadline is not a retained reading unless the producer explicitly declares that stale transition.
        guard row.state == .stale || account.valueState == .retained || staleAfterExpiry else { return nil }
        guard now.timeIntervalSinceReferenceDate.isFinite,
              row.consent == .allowed || row.consent == .implicit || row.consent == .notRequired,
              member.isStable, member.subscriptionRef == nil || member.subscriptionRef == member.id,
              account.valueState == .current || account.valueState == .retained,
              Set(account.windows.map(\.id)).count == account.windows.count,
              sourceState(member, now: now) == .stale,
              let percent = window.remainingPercent, percent.isFinite, (0...100).contains(percent),
              let observed = date(window.observedAt) ?? date(account.observedAt),
              observed.timeIntervalSinceReferenceDate.isFinite, observed <= now else { return nil }
        // macrevb-1051-1: only a producer-stated reset ends a kept reading. A guessed end (reading time plus duration) can
        // outlive the real reset by hours when the reading was taken near the window's end, so no reset means no kept value.
        guard let reset = date(window.resetsAt) else { return nil }
        let until = reset
        guard until.timeIntervalSinceReferenceDate.isFinite, until > now else { return nil }
        return .init(memberID: member.id, windowID: window.id, remainingPercent: percent, resetsAt: reset, observedAt: observed, until: until)
    }
    private func resetEventLinks(_ event: EngineResetEvent) -> [DockCardLink] {
        let order = english
            ? [("original", "Original"), ("aihot", "AIHot"), ("official", "Official source"), ("publication", "Source")]
            : [("aihot", "AIHot"), ("official", "官方来源"), ("original", "原文"), ("publication", "来源")]
        return order.flatMap { kind, label in
            event.sourceLinks.filter { $0.kind == kind }.map { DockCardLink(label: label, url: $0.url) }
        }
    }

    private func resetCountRow(_ member: EngineAccountMember, now: Date) -> (row: DockCardRow, expiry: Date?)? {
        let row = member.row, account = member.account
        guard row.consent == .allowed || row.consent == .implicit || row.consent == .notRequired,
              account.valueState == .current || account.valueState == .retained,
              let facts = account.resetCards, facts.state == .complete || facts.state == .partial,
              facts.count != nil || facts.earliestExpiresAt != nil else { return nil }
        let title = facts.count.map { "↺\($0)" } ?? "↺"
        var details: [String] = []
        if facts.state == .partial { details.append(english ? "Reported subset" : "已报告部分") }
        if facts.truncated { details.append(english ? "Details truncated" : "明细已截断") }
        if account.valueState == .retained || row.state != .fresh ||
            (date(row.expiresAt).map { now >= $0 } ?? false) ||
            (date(account.freshUntil).map { now >= $0 } ?? false) {
            details.append(english ? "Last known reading" : "上次读数")
        }
        return (.init(id: "reset-count", kind: .reserve, label: english ? "Reserve" : "储备", value: title, detail: details.joined(separator: " · ")),
                date(facts.earliestExpiresAt))
    }

    /// S9: a reported money balance for a Settings-only line ("$0.00"); nil without a finite money balance.
    private func settingsBalance(_ account: RowsAccount) -> String? {
        guard let credits = account.credits, let balance = credits.balance, balance.isFinite, balance >= 0,
              credits.unit == "money" else { return nil }
        if let code = credits.currency, let money = M5CreditsDisplayFormat.currencyText(balance, code: code, english: english) { return money }
        return M5CreditsDisplayFormat.moneyText(balance, english: english)
    }
    private func sourceState(_ member:EngineAccountMember,now:Date) -> SubscriptionSourceState {
        let row=member.row, account=member.account
        guard row.consent == .allowed || row.consent == .implicit || row.consent == .notRequired else { return .denied }
        if row.state == .off { return .readerDisabled }
        if row.state == .stale || account.valueState == .retained { return .stale }
        if row.state == .fresh && account.valueState == .current {
            if (date(row.expiresAt).map { now >= $0 } ?? false) ||
                (date(account.freshUntil).map { now >= $0 } ?? false) { return .stale }
            return .fresh
        }
        return .unavailable
    }
    private func date(_ stamp: WireTimestamp?) -> Date? {
        guard let stamp else { return nil }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: stamp.rawValue) ?? ISO8601DateFormatter().date(from: stamp.rawValue)
    }
    /// Preserve only independently matched members with explicit, still-future
    /// account/window evidence. Retained and unknown values are not promoted.
    private func verifiedWindowFacts(_ members: [EngineAccountMember], now: Date) -> [EngineVerifiedWindow] {
        guard now.timeIntervalSinceReferenceDate.isFinite else { return [] }
        return members.flatMap { member -> [EngineVerifiedWindow] in
            let row = member.row, account = member.account
            guard account.route.isKnown, account.route != .knownUnknown else { return [] }
            let memberKey: String
            if let subscriptionRef = member.subscriptionRef {
                guard member.id == subscriptionRef else { return [] }
                memberKey = subscriptionRef
            } else {
                // This is a snapshot-local display key, never a verified ref.
                guard member.isStable, member.id == row.id + "#" + account.route.rawValue else { return [] }
                memberKey = member.id
            }
            let rowCanContainCurrent = row.state == .fresh ||
                (row.state == .stale && (row.reason.code == .staleReading || row.reason.code == .observationTimeUnknown))
            guard member.isStable,
                  row.consent == .allowed || row.consent == .implicit || row.consent == .notRequired,
                  rowCanContainCurrent, let rowDeadline = date(row.expiresAt),
                  let accountDeadline = date(account.freshUntil), accountDeadline > now,
                  let observed = date(account.observedAt), observed <= now,
                  account.valueState == .current,
                  Set(account.windows.map(\.id)).count == account.windows.count else { return [] }
            if now >= rowDeadline && row.stateAfterExpiry?.state != .stale { return [] }
            return account.windows.compactMap { window -> EngineVerifiedWindow? in
                let reset = date(window.resetsAt)
                guard window.current, let windowObserved = date(window.observedAt), windowObserved <= now,
                      let deadline = date(window.validUntil), deadline > now,
                      let windowUntil = EngineResetTimestampContract.bound(account: accountDeadline, window: deadline, reset: reset,
                          assurance: EngineResetTimestampContract.activeAssurance), windowUntil > now,
                      let percent = window.remainingPercent, percent.isFinite, (0...100).contains(percent) else { return nil }
                let until = rowDeadline > now ? min(windowUntil, rowDeadline) : windowUntil
                return .init(memberID: memberKey, windowID: window.id, remainingPercent: percent, resetsAt: reset, issuedAt: now, until: until)
            }
        }
    }
    private func sourceName(_ route:RowsRoute) -> String {
        Self.sourceName(route, english: english)
    }
    static func sourceName(_ route: RowsRoute, english: Bool) -> String {
        switch route {
        case .savedLoginApi:return english ? "Saved sign-in":"已有登录"
        case .runtimeRpc:return english ? "Tool runtime":"工具运行时"
        case .localLog,.localSqlite:return english ? "Local history":"本地历史"
        case .apiKeyApi:return english ? "Configured key":"已配置密钥"
        case .browserSession:return english ? "Browser session":"浏览器会话"
        case .statusLine:return english ? "Tool status line":"工具状态栏"
        case .manual:return english ? "Manual reading":"手动读数"
        case .knownUnknown,.unknown:return english ? "Unknown source":"未知来源"
        }
    }
    private func windowSourceName(_ source: RowsWindowSource?) -> String {
        switch source {
        case .localHistory: return sourceName(.localLog)
        case .runtime: return sourceName(.runtimeRpc)
        case .savedLogin: return sourceName(.savedLoginApi)
        case .apiKey: return sourceName(.apiKeyApi)
        case .other: return english ? "Other source" : "其他来源"
        case .none, .unknown: return sourceName(.knownUnknown)
        }
    }
    /// D87 slice 4: a failed or stale row says its own cause from the shared table, in place of the
    /// engine's generic sentence. A stale reading names its age and the cause of the failed refresh.
    /// A code without a table entry returns nil and keeps the engine's text.
    private func causeLine(_ member: EngineAccountMember, now: Date) -> (reason: String, nextStep: String)? {
        let row = member.row, account = member.account
        let language: SettingsLanguage = english ? .english : .chinese
        let name = member.name(english: english)
        if row.state == .stale || account.valueState == .retained,
           let failure = account.lastFailure,
           let entry = ReaderCauseTable.entry(code: failure.code.rawValue, tool: row.id, toolName: name),
           let observed = date(account.observedAt) {
            return (ReaderCauseTable.staleLine(entry: entry, ageSeconds: Int(max(0, now.timeIntervalSince(observed))), language: language),
                    entry.action.value(language))
        }
        guard row.state == .failed || row.state == .needsAction,
              let entry = ReaderCauseTable.entry(code: message(row, now: now).0.code.rawValue, tool: row.id, toolName: name) else { return nil }
        return (entry.reason.value(language), entry.action.value(language))
    }
    private func message(_ row: RowsRow, now: Date) -> (RowsReason, RowsNextStep?) {
        if let expiry = date(row.expiresAt), now >= expiry, let after = row.stateAfterExpiry {
            return (after.reason, after.nextStep)
        }
        return (row.reason, row.nextStep)
    }
    /// D417: an extra window is named by what it is (MCP, Opus, Fable), from the engine's own short label, never "Other".
    /// Only a window the engine names (a model scope or the MCP allowance) takes that label; the rest keep the role heading.
    private func quotaLabel(_ window:RowsWindow) -> String {
        Self.rowLabel(role: window.role, limitKey: window.limitKey, scoped: window.modelScope != nil, name: text(window.label), english: english)
    }
    static func rowLabel(role:RowsRole, limitKey:String, scoped:Bool, name:String, english:Bool) -> String {
        if (scoped || limitKey == "mcp") && name.count <= 6 { return name }
        return quotaLabel(role, english: english)
    }
    private static func quotaLabel(_ role:RowsRole, english:Bool) -> String {
        switch role {
        case .session:return english ? "5h":"5小时"
        case .weekly:return english ? "Weekly":"每周"
        case .daily,.monthly,.other,.unknown:return english ? "Other":"其他"
        }
    }
    private func makeInput(_ member:EngineAccountMember, now: Date) -> DockInstrumentInput {
        let row=member.row
        var input = DockInstrumentInput(id: member.id, name: member.name(english:english), windows: [])
        // D42: most catalogue rows carry no vendor key; their tool ID names the mark.
        input.vendorResourceKey = row.vendorKey.flatMap { $0.isEmpty ? nil : $0 } ?? row.id
        input.duplicateAccountTag=member.duplicateTag
        // A non-fresh row remains non-fresh. The Dock model currently cannot
        // display a current weekly window while its overall input is non-fresh.
        let authorized = row.consent == .allowed || row.consent == .implicit || row.consent == .notRequired
        let rowCurrent = authorized && row.state == .fresh && (date(row.expiresAt).map { now < $0 } ?? true)
        let account=member.account
            let accountCurrent = rowCurrent && account.valueState == .current && (date(account.freshUntil).map { now < $0 } ?? true)
            var currentReading = false, keptReading = false
            for window in account.windows {
                let current = accountCurrent && window.current && (date(window.validUntil).map { now < $0 } ?? true)
                let period:DockQuotaPeriod
                switch window.role {
                case .session: period = .fiveHour
                case .daily: period = .day
                case .weekly: period = .week
                case .monthly: period = .month
                case .other,.unknown: period = .other
                }
                var projected=DockQuotaWindowInput(id: window.id, period: period, label: quotaLabel(window),
                    remainingPercent: current ? window.remainingPercent : nil,
                    resetsAt: current ? date(window.resetsAt) : nil,
                    durationSeconds: window.durationSeconds.map { Double($0) })
                // Only known plan-wide session, weekly and monthly limits participate.
                // Named, unknown and model-scoped pools remain card-only.
                let generalLimit = (period == .fiveHour && ["main", "five_hour"].contains(window.limitKey)) ||
                    (period == .week && ["main", "weekly"].contains(window.limitKey)) ||
                    (period == .month && ["main", "monthly"].contains(window.limitKey))
                projected.isGeneral = window.modelScope == nil && window.poolKey == "main" && generalLimit
                if current { currentReading = currentReading || window.remainingPercent != nil }
                else if let kept = retainedWindow(member, window, now: now) {
                    // DOCK-3.2-50: the earlier reading stays until its window resets; the host re-checks it.
                    projected.remainingPercent = kept.remainingPercent; projected.resetsAt = kept.resetsAt
                    projected.validity = .retained(observedAt: kept.observedAt, until: kept.until)
                    keptReading = true
                }
                input.windows.append(projected)
            }
        func rank(_ period:DockQuotaPeriod) -> Int {
            switch period { case .fiveHour:return 0;case .week:return 1;case .month:return 2;case .day:return 3;case .other:return 4 }
        }
        // Canonicalize each role's tightest first for rings and the shared pin consumer.
        input.windows.sort { left,right in
            if rank(left.period) != rank(right.period) { return rank(left.period) < rank(right.period) }
            let a=left.remainingPercent ?? .infinity,b=right.remainingPercent ?? .infinity
            return a == b ? left.id < right.id:a < b
        }
        // D228: a current balance-only reading (Grok's X Subscription: a balance, no usage percentage) is a
        // successful read. Its quota stays unknown ("--"), but the card is not presented as a failed one.
        let balanceOnly = accountCurrent && row.reason.code == .usageNotReported && account.credits?.balance != nil &&
            input.windows.allSatisfy { $0.remainingPercent == nil }
        input.dataState = currentReading || balanceOnly ? .fresh : keptReading ? .stale : .unavailable
        if source.dockContent.status == .ready, accountCurrent, member.isStable, let ref=member.subscriptionRef {
            let admitted=(account.activity ?? []).compactMap { activity -> Date? in
                guard activity.bindingVerified, activity.subscriptionRef == ref,
                      let recorded=date(activity.recordAt), let expiry=date(activity.expiresAt),
                      recorded <= now, now < expiry else { return nil }
                let grace:TimeInterval
                switch activity.phase {
                case .model: grace=90
                case .tool: grace=300
                case .fallback: grace=30
                case .finished,.unknown: return nil
                }
                guard abs(expiry.timeIntervalSince(recorded)-grace) < 0.001 else { return nil }
                return expiry
            }
            // One live, verified session is sufficient for this account only. Use
            // the member key, never its shared provider/row ID or a peer's rate.
            if let expiry=admitted.max() {
                input.working = .init(subscriptionID:member.id,bindingVerified:true,fresh:true,
                    observedOutput:false,observedInFlight:true,expiresAt:expiry)
            }
        }
        return input
    }

}
