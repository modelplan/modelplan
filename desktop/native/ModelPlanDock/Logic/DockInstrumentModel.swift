// SPDX-License-Identifier: MIT
import Foundation

public enum DockQuotaPeriod: String, Codable, Sendable {
    case fiveHour, day, week, month, other
    // These hints order known period kinds only. They are never a clock/duration observation.
    fileprivate var orderHint: Double {
        switch self { case .fiveHour:return 18_000;case .day:return 86_400;case .week:return 604_800;case .month:return 2_592_000;case .other:return .infinity }
    }
}
public struct DockQuotaWindowInput: Sendable {
    public var id: String, period: DockQuotaPeriod, label: String
    public var remainingPercent: Double?, resetsAt: Date?, durationSeconds: TimeInterval?
    /// Participation in named general quota presentation. False is not itself a
    /// model-scope claim; that classification needs an explicit wire field.
    public var isGeneral = true
    public init(id: String, period: DockQuotaPeriod, label: String, remainingPercent: Double?, resetsAt: Date?, durationSeconds: TimeInterval?) {
        self.id=id;self.period=period;self.label=label;self.remainingPercent=remainingPercent
        self.resetsAt=resetsAt;self.durationSeconds=durationSeconds
    }
}
public struct DockWorkingSignal: Sendable {
    public var subscriptionID: String?
    public var bindingVerified: Bool, fresh: Bool, observedOutput: Bool
    /// Explicit admitted turn evidence is distinct from observed token output.
    public var observedInFlight: Bool
    public var expiresAt: Date?
    public init(subscriptionID: String?, bindingVerified: Bool, fresh: Bool, observedOutput: Bool,
                observedInFlight: Bool = false, expiresAt: Date? = nil) {
        self.subscriptionID=subscriptionID;self.bindingVerified=bindingVerified;self.fresh=fresh;self.observedOutput=observedOutput
        self.observedInFlight=observedInFlight;self.expiresAt=expiresAt
    }
}
public struct DockInstrumentInput: Sendable {
    public var id: String, name: String, alias: String?, vendorResourceKey: String?
    public var duplicateAccountTag:Int?
    public var windows: [DockQuotaWindowInput]
    public var selectedWindowID: String?
    public var showUsedPercent = false
    public var dataState: DockDataState = .unavailable
    public var unavailableReason:String?
    public var working: DockWorkingSignal?
    public init(id: String, name: String, windows: [DockQuotaWindowInput]) {self.id=id;self.name=name;self.windows=windows}
}
public enum DockQuotaStatus: String, Codable, Hashable, Sendable {case unknown, normal, warning, critical}
public struct DockQuotaArc: Equatable, Sendable {
    public let windowID: String, fraction: Double?, status: DockQuotaStatus
}
public struct DockInstrumentReading: Sendable {
    public let subscriptionID: String, name: String, alias: String?, vendorResourceKey: String?
    public let duplicateAccountTag:Int?
    public let outer: DockQuotaArc?, inner: DockQuotaArc?
    public let selectedWindowID: String?, selectedWindowLabel: String?, selectedResetAt: Date?
    public let remainingPercent: Double?, readout: String, status: DockQuotaStatus
    public let dataState:DockDataState
    public let unavailableReason:String?
    public let timeLeftFraction: Double?
    /// Position count comes from the frozen appearance provider, not quota percentage or a ten-point helper.
    public func litTimePoints(positions: Int) -> Int? {
        guard (1...128).contains(positions),let timeLeftFraction else{return nil}
        return max(0,min(positions,Int(ceil(timeLeftFraction*Double(positions)))))
    }
    public let isWorking: Bool, jetEligible: Bool
    /// Gallery-only fixture: the prototype varies level independently of its fixed 75% arc.
    @_spi(DockResourceChecks) public func comparisonFixture(status: DockQuotaStatus) -> DockInstrumentReading {
        let fixtureOuter = outer.map { DockQuotaArc(windowID: $0.windowID, fraction: $0.fraction, status: status) }
        return DockInstrumentReading(subscriptionID: subscriptionID, name: name, alias: alias, vendorResourceKey: vendorResourceKey,
            duplicateAccountTag:duplicateAccountTag,
            outer: fixtureOuter, inner: inner, selectedWindowID: selectedWindowID, selectedWindowLabel: selectedWindowLabel,
            selectedResetAt: selectedResetAt, remainingPercent: remainingPercent, readout: readout, status: status,
            dataState: dataState, unavailableReason:unavailableReason, timeLeftFraction: timeLeftFraction, isWorking: isWorking, jetEligible: jetEligible)
    }
}

/// Truth/identity projection only. Fixed artwork/ring geometry belongs to the injected appearance source.
public enum DockInstrumentProjection {
    public static func evaluate(_ input: DockInstrumentInput, now: Date, redBelow: Double = 25) throws -> DockInstrumentReading {
        guard !input.id.isEmpty, input.windows.allSatisfy({!$0.id.isEmpty}), Set(input.windows.map(\.id)).count==input.windows.count else {throw DockLogicError.invalidCatalogue}
        guard now.timeIntervalSinceReferenceDate.isFinite, redBelow.isFinite, (0...100).contains(redBelow) else {throw DockLogicError.invalidTime}
        func value(_ w: DockQuotaWindowInput) -> Double? {
            guard input.dataState == .fresh, w.resetsAt.map({$0>now}) ?? true,
                  let r=w.remainingPercent, r.isFinite, (0...100).contains(r) else {return nil}
            return r
        }
        func status(_ r: Double?) -> DockQuotaStatus {
            guard let r else{return .unknown}
            return r<=redBelow ? .critical : r<41 ? .warning : .normal
        }
        let general=input.windows.filter(\.isGeneral)
        // Match the study's ringWindows ordering by typed window length. Restricted
        // model and named pools have already been excluded from `general`.
        let sorted=general.enumerated().sorted { left,right in
            let a=left.element.period.orderHint,b=right.element.period.orderHint
            return a == b ? left.offset < right.offset : a < b
        }.map(\.element)
        let outer=sorted.first, rest=Array(sorted.dropFirst())
        let inner=rest.first { $0.period == .week } ?? rest.last
        let selected=input.selectedWindowID.flatMap{id in general.first{$0.id==id}}
            ?? general.filter{value($0) != nil}.min{value($0)!<value($1)!} ?? general.first
        let remaining=selected.flatMap(value), selectedStatus=status(remaining)
        let shown=remaining.map{input.showUsedPercent ? 100-$0:$0}
        let text=shown.map{v in (v.rounded()==v ? String(Int(v)):String(v))+"%"} ?? "--"
        var time:Double?
        if input.dataState == .fresh, let selected, let reset=selected.resetsAt, reset>now,
           let duration=selected.durationSeconds, duration.isFinite, duration>0 {
            time=max(0,min(1,reset.timeIntervalSince(now)/duration))
        }
        let working=input.working.map { signal in
            signal.bindingVerified && signal.fresh && signal.subscriptionID == input.id &&
            (signal.observedOutput || (signal.observedInFlight && signal.expiresAt != nil)) &&
            (signal.expiresAt.map { now < $0 } ?? true)
        } == true && input.dataState == .fresh
        func arc(_ w:DockQuotaWindowInput?) -> DockQuotaArc? {w.map{let r=value($0);return DockQuotaArc(windowID:$0.id,fraction:r.map{$0/100},status:status(r))}}
        return DockInstrumentReading(subscriptionID:input.id,name:input.name,alias:input.alias,vendorResourceKey:input.vendorResourceKey,duplicateAccountTag:input.duplicateAccountTag,
            outer:arc(outer),inner:arc(inner),selectedWindowID:selected?.id,selectedWindowLabel:selected?.label,selectedResetAt:selected?.resetsAt,
            remainingPercent:remaining,readout:text,status:selectedStatus,dataState:input.dataState,
            unavailableReason:remaining == nil ? input.unavailableReason : nil,timeLeftFraction:time,isWorking:working,jetEligible:working && remaining != nil)
    }
}
