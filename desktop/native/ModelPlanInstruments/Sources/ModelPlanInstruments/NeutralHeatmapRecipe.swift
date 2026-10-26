// SPDX-License-Identifier: MIT
import AppKit

/// Ordinary calendar drawing. Official cell registration, intensity palette and typography stay private.
@MainActor enum NeutralHeatmapRecipe {
    static func make(_ display:OverviewPageDisplay,in area:CGRect,ink:EngineInk)throws -> (commands:[EngineDrawingCommand],regions:[MainScreenHitRegion]) {
        guard let geometry=OverviewHeatmapGeometry(display:display,area:area) else{throw EngineTableError.invalidRecipe}
        let zh=display.language == .chinese,muted=EngineInk(NSColor.secondaryLabelColor)
        let levels=[0.10,0.30,0.50,0.70,1.0]
        var commands:[EngineDrawingCommand]=[],regions:[MainScreenHitRegion]=[]
        func text(_ id:String,_ values:[String],_ rect:CGRect) {
            commands.append(.text(.init(id:id,variants:values,rect:rect,font:.init(size:10),ink:muted)))
        }
        func stepInk(_ step:Int)->EngineInk { .init(ink.red,ink.green,ink.blue,ink.alpha*levels[step]) }
        for hit in geometry.cells {
            let cell=hit.cell
            if let step=cell.intensity {commands.append(.fill(rect:hit.rect,radius:0,ink:stepInk(step)))}
            let help=display.explanation(cell)
            regions.append(.init(id:cell.id,rect:hit.hitRect,label:help.body,help:help,role:.readout,value:help.body,
                focusGroup:"overview.days",gridPosition:.init(column:cell.column,row:cell.row)))
        }
        let formatter=DateFormatter();formatter.calendar=display.snapshot.calendar;formatter.timeZone=display.snapshot.calendar.timeZone
        formatter.locale=Locale(identifier:zh ? "zh_CN":"en_US_POSIX")
        for (i,month) in geometry.months.enumerated() where month.rect.width>=20 {
            formatter.dateFormat=zh ? "M月":"MMM";let title=formatter.string(from:month.day)
            formatter.dateFormat="M"
            text("overview.month.\(i)",[title,formatter.string(from:month.day)],month.rect)
        }
        let pitch=geometry.cellSize+3
        for (row,label) in [(0,zh ? "一":"Mon"),(3,zh ? "四":"Thu"),(6,zh ? "日":"Sun")] {
            text("overview.weekday.\(row)",[label],CGRect(x:area.minX,y:geometry.grid.minY+Double(row)*pitch+geometry.cellSize/2-6,width:28,height:13))
        }
        if let coverage=display.coverageText {
            text("overview.coverage",[coverage],geometry.coverageRect)
            regions.append(.init(id:"overview.coverage",rect:geometry.coverageRect,label:coverage,
                help:.init(title:zh ? "点阵":"Grid",body:coverage),role:.readout))
        }
        let legend=geometry.legendRect
        text("overview.intensity.less",[zh ? "少":"Less"],CGRect(x:legend.minX,y:legend.minY,width:30,height:16))
        for step in 0...4 {
            commands.append(.fill(rect:CGRect(x:legend.minX+36+Double(step)*13,y:legend.minY+3,width:9,height:9),radius:0,ink:stepInk(step)))
        }
        text("overview.intensity.more",[zh ? "多":"More"],CGRect(x:legend.minX+106,y:legend.minY,width:40,height:16))
        let scale=zh ? "近26周每日用量；0为已记录的零，空白为无读数；其余四档由少到多。":"Daily usage over 26 weeks; zero is a reported zero, blank is no reading; four positive steps run from less to more."
        regions.append(.init(id:"overview.intensity",rect:CGRect(x:legend.minX,y:legend.minY,width:146,height:16),label:scale,
            help:.init(title:zh ? "点阵":"Grid",body:scale),role:.readout))
        if geometry.cells.isEmpty {
            let label=zh ? "无记录":"No record",rect=CGRect(x:geometry.grid.minX,y:geometry.grid.midY-8,width:geometry.grid.width,height:16)
            text("overview.heatmap.empty",[label],rect)
            regions.append(.init(id:"overview.heatmap.empty",rect:rect,label:label,help:.init(title:zh ? "点阵":"Grid",body:label),role:.readout))
        }
        return (commands,regions)
    }
}
