// SPDX-License-Identifier: MIT
import Foundation

public enum OverviewVisualization: Sendable { case bars, heatmap }
public struct OverviewHeatmapCell: Equatable, Sendable {
    public let bucket: OverviewBucketDisplay
    public let column: Int, row: Int
    /// nil is missing, 0 is a reported zero, 1...4 are the retained model's positive steps.
    public let intensity: Int?
    public let covered: Bool
    public var id: String { "overview.day." + String(bucket.start.timeIntervalSinceReferenceDate.bitPattern,radix:16) }
}
public struct OverviewHeatmapData: Equatable, Sendable {
    public let cells: [OverviewHeatmapCell]
    public let coverageStart: Date?
    public let shortCoverage: Bool
    public let englishCoverage: String?, chineseCoverage: String?
    public var grid: [OverviewHeatmapCell?] { (0..<182).map { $0<cells.count ? cells[$0]:nil } }
    init(_ map: UsageHeatmap, ids: [String], now: Date, calendar: Calendar, coverageStart: Date?) {
        self.coverageStart=map.coverageStart;shortCoverage=map.shortCoverage
        englishCoverage=map.coverageDescription(language:.english,calendar:calendar)
        chineseCoverage=map.coverageDescription(language:.chinese,calendar:calendar)
        cells=map.cells.map { cell in
            // Unknown coverage does not invent a recording start. A real reading proves only its own day.
            let covered=cell.intensity != nil || ids.contains { id in
                (map.coverageBySubscription[id] ?? coverageStart).map {
                    $0<=now && calendar.startOfDay(for:$0)<=cell.day
                } ?? false
            }
            return .init(bucket:.init(start:cell.day,end:calendar.date(byAdding:.day,value:1,to:cell.day)!,
                values:ids.map{.init(subscriptionID:$0,tokens:cell.perSubscription[$0] ?? nil)},
                total:cell.completeTotal,recordedTotal:cell.total,partial:cell.partial),column:cell.column,row:cell.row,
                intensity:cell.intensity,covered:covered)
        }
    }
}
public extension OverviewPageDisplay {
    var coverageText: String? {
        let map=snapshot.heatmap
        return language == .chinese ? map.chineseCoverage:map.englishCoverage
    }
    func explanation(_ cell: OverviewHeatmapCell) -> HelpExplanation {
        explanation(cell.bucket,calendarDay:true)
    }
}
public struct OverviewHeatmapHit: Equatable, Sendable {
    public let cell: OverviewHeatmapCell
    public let rect: CGRect, hitRect: CGRect
}
public struct OverviewHeatmapMonth: Equatable, Sendable {
    public let day: Date
    public let rect: CGRect
}
/// Generic calendar packing; no official cell registration, palette, material or typography.
public struct OverviewHeatmapGeometry: Equatable, Sendable {
    public let area: CGRect, grid: CGRect
    public let cellSize: Double
    public let cells: [OverviewHeatmapHit]
    public let months: [OverviewHeatmapMonth]
    public let coverageRect: CGRect, legendRect: CGRect
    public init?(display: OverviewPageDisplay, area: CGRect) {
        guard [area.minX,area.minY,area.width,area.height].allSatisfy(\.isFinite),area.width>0,area.height>0 else{return nil}
        let gap=3.0,left=30.0,header=18.0,legend=20.0,coverage=display.coverageText == nil ? 0.0:18.0
        let width=area.width-left,height=area.height-header-legend-coverage
        let side=floor(min(16,(width-25*gap)/26,(height-6*gap)/7))
        guard side>=3 else{return nil}
        self.area=area;cellSize=side
        let pitch=side+gap,w=26*side+25*gap,h=7*side+6*gap
        let grid=CGRect(x:area.minX+left+(width-w)/2,y:area.minY+header+(height-h)/2,width:w,height:h)
        self.grid=grid
        cells=display.snapshot.heatmap.cells.filter(\.covered).map { cell in
            let rect=CGRect(x:grid.minX+Double(cell.column)*pitch,y:grid.minY+Double(cell.row)*pitch,width:side,height:side)
            return .init(cell:cell,rect:rect,hitRect:rect.insetBy(dx:-gap/2,dy:-gap/2))
        }
        var markers:[(Date,Int)]=[]
        if let first=display.snapshot.heatmap.cells.first?.bucket.start {
            let calendar=display.snapshot.calendar
            for column in 0..<26 {
                let date=calendar.date(byAdding:.day,value:column*7,to:first)!,previous=calendar.date(byAdding:.day,value:-7,to:date)!
                if column==0 || calendar.component(.month,from:date) != calendar.component(.month,from:previous) {
                    markers.append((date,column))
                }
            }
        }
        months=markers.enumerated().map { i,marker in
            let next=i+1<markers.count ? markers[i+1].1:26
            return .init(day:marker.0,rect:CGRect(x:grid.minX+Double(marker.1)*pitch,y:area.minY,
                width:Double(next-marker.1)*pitch-gap,height:16))
        }
        coverageRect=CGRect(x:area.minX,y:area.maxY-legend-coverage,width:area.width,height:coverage)
        legendRect=CGRect(x:area.minX,y:area.maxY-legend,width:area.width,height:legend)
    }
}
