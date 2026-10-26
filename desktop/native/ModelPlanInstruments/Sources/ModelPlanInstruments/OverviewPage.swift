// SPDX-License-Identifier: MIT
import Foundation

public struct OverviewSeriesIdentity: Equatable, Sendable {
    public let id: String, name: String, shortName: String
    public let ink: EngineInk?
    public init(id: String, name: String, shortName: String? = nil, ink: EngineInk? = nil) {
        self.id=id; self.name=name; self.shortName=shortName ?? name; self.ink=ink
    }
}
/// A host-owned, already-localized offline information row. No update state/store/network is owned here.
public struct OverviewInformationRow: Equatable, Sendable {
    public let id: String, text: String
    public let actionLabel: String?
    public init(id: String, text: String, actionLabel: String? = nil) { self.id=id; self.text=text; self.actionLabel=actionLabel }
}
public struct OverviewNoticeDisplay: Equatable, Sendable {
    public let id: String, text: String
    public let severity: NoticeSeverity
}
public struct OverviewBucketValue: Equatable, Sendable {
    public let subscriptionID: String
    public let tokens: Double?
}
public struct OverviewBucketDisplay: Equatable, Sendable {
    public let start: Date, end: Date
    public let values: [OverviewBucketValue]
    public let total: Double?, recordedTotal: Double?
    public let partial: Bool
    public var id: String { "overview.bucket." + String(start.timeIntervalSinceReferenceDate.bitPattern,radix:16) }
}
public struct OverviewChartData: Equatable, Sendable {
    public let range: UsageRange
    public let buckets: [OverviewBucketDisplay]
    init(_ chart: UsageChart, range: UsageRange) {
        self.range=range
        buckets=chart.buckets.map { b in .init(start:b.start,end:b.end,
            values:b.segments.map { .init(subscriptionID:$0.subscriptionID,tokens:$0.tokens) },
            total:b.total,recordedTotal:b.recordedTotal,partial:b.partial) }
    }
}
/// Reuses the existing expiry/attribution/calendar projections once per input update.
/// Changing a local footer option selects a retained range; it never rereads data or changes subscriptions.
public struct OverviewPageSnapshot: Equatable, Sendable {
    public let scope: InstrumentScope
    public let today: Double?, days30: Double?
    public let notices: [OverviewNoticeDisplay]
    public let series: [OverviewSeriesIdentity]
    public let charts: [OverviewChartData]
    public let calendar: Calendar
    public let information: OverviewInformationRow?
    /// Stable neutral palette slot, independent of scope/order and process hash randomization.
    public func paletteSlot(for id: String) -> Int {
        Int(id.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 } % 6)
    }
    public let initialRange: UsageRange, initialMode: UsageChartMode
    public init(columns: [EngineColumn], daily: [InstrumentUsageBucket], hourly: [InstrumentUsageBucket],
        notices: [InstrumentNotice], identities: [OverviewSeriesIdentity] = [], scope: InstrumentScope,
        now: Date, calendar: Calendar, initialRange: UsageRange = .days7, initialMode: UsageChartMode = .stacked,
        reportedTodaySources: [SourceTokenTotal]? = nil, reportedThirtyDaySources: [SourceTokenTotal]? = nil,
        information: OverviewInformationRow? = nil) {
        self.scope=scope; self.calendar=calendar; self.information=information; self.initialRange=initialRange; self.initialMode=initialMode
        let p=OverviewPresentation(columns:columns,daily:daily,hourly:hourly,notices:notices,scope:scope,range:initialRange,
            coverageStart:nil,now:now,calendar:calendar,mode:initialMode,
            reportedTodaySources:reportedTodaySources,reportedThirtyDaySources:reportedThirtyDaySources)
        today=p.todayTokens; days30=p.thirtyDayTokens
        self.notices=p.notices.map { .init(id:$0.id,text:$0.text,severity:$0.severity) }
        var seen=Set<String>()
        series=p.chart.subscriptionIDs.filter { seen.insert($0).inserted }.map { id in
            identities.first { $0.id == id } ?? .init(id:id,name:id)
        }
        charts=[UsageRange.hours24,.days7,.days30].map { range in
            OverviewChartData(UsageChart(rows:range == .hours24 ? hourly:daily,subscriptionIDs:p.chart.subscriptionIDs,
                range:range,now:now,calendar:calendar),range:range)
        }
    }
    var valid: Bool {
        series.count<=128 && Set(series.map(\.id)).count==series.count
            && series.allSatisfy { !$0.id.isEmpty && $0.id.utf8.count<=256 && $0.name.utf8.count<=4096 && $0.shortName.utf8.count<=4096 }
            && notices.count<=128 && Set(notices.map(\.id)).count==notices.count
            && notices.allSatisfy { !$0.id.isEmpty && $0.text.utf8.count<=4096 }
            && (information.map { !$0.id.isEmpty && $0.id.utf8.count<=256 && $0.text.utf8.count<=4096 && ($0.actionLabel?.utf8.count ?? 0)<=4096 } ?? true)
    }
    public func footer(_ language: InstrumentLanguage) -> [MainScreenFooterOption?] {
        let zh=language == .chinese,help=HelpCatalog(language).explanation(.option)
        return [nil,
            .init(id:"overview.range",choices:[.init("24",title:"24h"),.init("7",title:"7"),.init("30",title:"30")],selectedValue:Self.rangeKey(initialRange),help:help),
            .init(id:"overview.mode",choices:[.init("stack",title:zh ? "叠":"Stack"),.init("split",title:zh ? "分":"Split")],selectedValue:initialMode == .stacked ? "stack":"split",help:help)]
    }
    public func pageContent(language: InstrumentLanguage) -> MainScreenPageContent {
        .init(.overview, options: footer(language), overview: self)
    }
    public static func rangeKey(_ range: UsageRange) -> String { range == .hours24 ? "24":range == .days7 ? "7":"30" }
    public func display(rangeKey: String?, modeKey: String?, language: InstrumentLanguage) -> OverviewPageDisplay {
        let range:UsageRange=rangeKey == "24" ? .hours24:rangeKey == "30" ? .days30:rangeKey == "7" ? .days7:initialRange
        return .init(snapshot:self,chart:charts.first{$0.range==range}!,mode:modeKey == "split" ? .split:modeKey == "stack" ? .stacked:initialMode,language:language)
    }
}
public struct OverviewPageDisplay: Equatable, Sendable {
    public let snapshot: OverviewPageSnapshot
    public let chart: OverviewChartData
    public let mode: UsageChartMode
    public let language: InstrumentLanguage
    public var todayText: String { InstrumentFormat(language).tokens(snapshot.today) }
    public var days30Text: String { InstrumentFormat(language).tokens(snapshot.days30) }
    public func visibleNotices(limit: Int) -> (notices:[OverviewNoticeDisplay],more:Int,information:OverviewInformationRow?) {
        let limit=max(0,limit),all=snapshot.notices
        let count=all.count>limit ? max(0,limit-1):min(limit,all.count)
        return (Array(all.prefix(count)),(all.count>limit ? all.count-count:0),all.count<limit ? snapshot.information:nil)
    }
    public func explanation(_ bucket: OverviewBucketDisplay) -> HelpExplanation {
        let format=InstrumentFormat(language),zh=language == .chinese
        let stamp=DateFormatter();stamp.calendar=snapshot.calendar;stamp.timeZone=snapshot.calendar.timeZone
        stamp.locale=Locale(identifier:zh ? "zh_CN":"en_US_POSIX")
        // The numeric offset distinguishes repeated local hours, including non-whole-hour zones.
        stamp.dateFormat=chart.range == .hours24 ? "HH:mm 'GMT'XXX":zh ? "M月d日":"MMM d"
        let total=bucket.total.map { format.tokens($0) }
            ?? bucket.recordedTotal.map { format.tokens($0)+(zh ? " · 部分":" · partial") }
            ?? (zh ? "未记录":"No record")
        let lines=[stamp.string(from:bucket.start)+" · "+total]+bucket.values.map { value in
            (snapshot.series.first{$0.id==value.subscriptionID}?.name ?? value.subscriptionID)+" "+format.tokens(value.tokens)
        }
        return HelpExplanation(title:zh ? "用量":"Usage",body:lines.joined(separator:"\n"))
    }
}
public struct OverviewBar: Equatable, Sendable {
    public let bucketID: String, subscriptionID: String
    public let value: Double, rect: CGRect
}
public struct OverviewBucketGeometry: Equatable, Sendable {
    public let bucket: OverviewBucketDisplay
    public let hitRect: CGRect
}
/// Ordinary bar layout. Gaps consume display space only; zero/missing values never receive fake height.
public struct OverviewChartGeometry: Equatable, Sendable {
    public let plot: CGRect
    public let maximum: Double
    public let bars: [OverviewBar]
    public let buckets: [OverviewBucketGeometry]
    public init?(display: OverviewPageDisplay, plot: CGRect, stackGap: Double = 2, bucketGap: Double = 2) {
        guard [plot.minX,plot.minY,plot.width,plot.height,stackGap,bucketGap].allSatisfy(\.isFinite),
              plot.width>0,plot.height>0,stackGap>=0,bucketGap>=0,!display.chart.buckets.isEmpty else{return nil}
        self.plot=plot
        let input=display.chart.buckets,series=display.snapshot.series,stack=display.mode == .stacked
        let maxValue=stack ? input.compactMap(\.recordedTotal).max():input.flatMap{$0.values.compactMap(\.tokens)}.max()
        maximum=max(1,maxValue ?? 0)
        let available=plot.height-(stack ? Double(max(0,series.count-1))*stackGap:0)
        guard available>0 else{return nil}
        let pitch=plot.width/Double(input.count),width=pitch-bucketGap
        guard width>0,series.isEmpty || stack || width/Double(series.count)>0 else{return nil}
        var bars:[OverviewBar]=[],buckets:[OverviewBucketGeometry]=[]
        for (i,bucket) in input.enumerated() {
            let x=plot.minX+Double(i)*pitch;var bottom=plot.maxY
            buckets.append(.init(bucket:bucket,hitRect:CGRect(x:x,y:plot.minY,width:pitch,height:plot.height)))
            for (j,value) in bucket.values.enumerated() {
                guard let v=value.tokens,v>0 else{continue}
                let h=(v/maximum)*(stack ? available:plot.height)
                let w=stack ? width:width/Double(max(1,series.count))
                let r=CGRect(x:x+bucketGap/2+(stack ? 0:Double(j)*w),y:stack ? bottom-h:plot.maxY-h,width:w,height:h)
                guard [r.minX,r.minY,r.width,r.height].allSatisfy(\.isFinite),r.minY>=plot.minY-0.001 else{return nil}
                bars.append(.init(bucketID:bucket.id,subscriptionID:value.subscriptionID,value:v,rect:r))
                if stack {bottom=r.minY-stackGap}
            }
        }
        self.bars=bars;self.buckets=buckets
    }
}
