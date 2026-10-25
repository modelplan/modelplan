// SPDX-License-Identifier: MIT
import Foundation

public enum DockQuotaPeriod: String, Codable, Sendable {
    case fiveHour, day, week, month, other
    // These hints order known period kinds only. They are never a clock/duration observation.
    fileprivate var orderHint: Double {
        switch self { case .fiveHour:return 18_000;case .day:return 86_400;case .week:return 604_800;case .month,.other:return .infinity }
    }
}
public struct DockQuotaWindowInput: Sendable {
    public var id: String, period: DockQuotaPeriod, label: String
    public var remainingPercent: Double?, resetsAt: Date?, durationSeconds: TimeInterval?
    public init(id: String, period: DockQuotaPeriod, label: String, remainingPercent: Double?, resetsAt: Date?, durationSeconds: TimeInterval?) {
        self.id=id;self.period=period;self.label=label;self.remainingPercent=remainingPercent
        self.resetsAt=resetsAt;self.durationSeconds=durationSeconds
    }
    fileprivate var orderingHint: Double { durationSeconds.flatMap{$0.isFinite && $0>0 ? $0:nil} ?? period.orderHint }
}
public struct DockWorkingSignal: Sendable {
    public var subscriptionID: String?
    public var bindingVerified: Bool, fresh: Bool, observedOutput: Bool
    public init(subscriptionID: String?, bindingVerified: Bool, fresh: Bool, observedOutput: Bool) {
        self.subscriptionID=subscriptionID;self.bindingVerified=bindingVerified;self.fresh=fresh;self.observedOutput=observedOutput
    }
}
public struct DockInstrumentInput: Sendable {
    public var id: String, name: String, alias: String?, vendorResourceKey: String?
    public var windows: [DockQuotaWindowInput]
    public var selectedWindowID: String?
    public var showUsedPercent = false
    public var dataState: DockDataState = .unavailable
    public var working: DockWorkingSignal?
    public init(id: String, name: String, windows: [DockQuotaWindowInput]) {self.id=id;self.name=name;self.windows=windows}
}
public enum DockQuotaStatus: String, Codable, Sendable {case unknown, normal, warning, critical}
public struct DockQuotaArc: Equatable, Sendable {
    public let windowID: String, fraction: Double?, status: DockQuotaStatus
}
public struct DockInstrumentReading: Sendable {
    public let subscriptionID: String, name: String, alias: String?, vendorResourceKey: String?
    public let outer: DockQuotaArc?, inner: DockQuotaArc?
    public let selectedWindowID: String?, selectedWindowLabel: String?, selectedResetAt: Date?
    public let remainingPercent: Double?, readout: String, status: DockQuotaStatus
    public let timeLeftFraction: Double?
    /// Position count comes from the frozen appearance provider, not quota percentage or a ten-point helper.
    public func litTimePoints(positions: Int) -> Int? {
        guard (1...128).contains(positions),let timeLeftFraction else{return nil}
        return max(0,min(positions,Int(ceil(timeLeftFraction*Double(positions)))))
    }
    public let isWorking: Bool, jetEligible: Bool
}

/// Truth/identity projection only. Fixed artwork/ring geometry belongs to the injected appearance source.
public enum DockInstrumentProjection {
    public static func evaluate(_ input: DockInstrumentInput, now: Date, redBelow: Double = 16) throws -> DockInstrumentReading {
        guard !input.id.isEmpty, input.windows.allSatisfy({!$0.id.isEmpty}), Set(input.windows.map(\.id)).count==input.windows.count else {throw DockLogicError.invalidCatalogue}
        guard now.timeIntervalSinceReferenceDate.isFinite, redBelow.isFinite, (0...100).contains(redBelow) else {throw DockLogicError.invalidTime}
        func value(_ w: DockQuotaWindowInput) -> Double? {
            guard input.dataState == .fresh, w.resetsAt.map({$0>now}) ?? true,
                  let r=w.remainingPercent, r.isFinite, (0...100).contains(r) else {return nil}
            return r
        }
        func status(_ r: Double?) -> DockQuotaStatus {
            guard let r else{return .unknown}
            return r==0 || r<redBelow ? .critical : r<41 ? .warning : .normal
        }
        let sorted=input.windows.enumerated().sorted { a,b in
            let x=a.element.orderingHint,y=b.element.orderingHint
            return x==y ? a.offset<b.offset : x<y
        }.map(\.element)
        let outer=sorted.first, rest=Array(sorted.dropFirst())
        let inner=rest.first{$0.period == .week} ?? rest.last
        let selected=input.selectedWindowID.flatMap{id in input.windows.first{$0.id==id}}
            ?? input.windows.filter{value($0) != nil}.min{value($0)!<value($1)!} ?? input.windows.first
        let remaining=selected.flatMap(value), selectedStatus=status(remaining)
        let shown=remaining.map{input.showUsedPercent ? 100-$0:$0}
        let text=shown.map{v in (v.rounded()==v ? String(Int(v)):String(v))+"%"} ?? "--"
        var time:Double?
        if input.dataState == .fresh, let selected, let reset=selected.resetsAt, reset>now,
           let duration=selected.durationSeconds, duration.isFinite, duration>0 {
            time=max(0,min(1,reset.timeIntervalSince(now)/duration))
        }
        let working=input.working.map{$0.bindingVerified && $0.fresh && $0.observedOutput && $0.subscriptionID==input.id} == true && input.dataState == .fresh
        func arc(_ w:DockQuotaWindowInput?) -> DockQuotaArc? {w.map{let r=value($0);return DockQuotaArc(windowID:$0.id,fraction:r.map{$0/100},status:status(r))}}
        return DockInstrumentReading(subscriptionID:input.id,name:input.name,alias:input.alias,vendorResourceKey:input.vendorResourceKey,
            outer:arc(outer),inner:arc(inner),selectedWindowID:selected?.id,selectedWindowLabel:selected?.label,selectedResetAt:selected?.resetsAt,
            remainingPercent:remaining,readout:text,status:selectedStatus,timeLeftFraction:time,isWorking:working,jetEligible:working && remaining != nil)
    }
}
