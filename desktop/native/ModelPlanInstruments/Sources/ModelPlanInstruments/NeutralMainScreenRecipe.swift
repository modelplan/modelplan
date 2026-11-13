// SPDX-License-Identifier: MIT
import AppKit
import CoreText

/// Complete ordinary system-font frame. Official registration/material stays injected.
@MainActor public final class NeutralMainScreenRecipe: MainScreenRecipeProvider {
    public init() {}
    public func font(_ request: EngineFontRequest) throws -> CTFont { try NeutralEngineTableRecipe().font(request) }
    public func image(_ id: String) throws -> CGImage { throw EngineTableError.missingResource(id) }
    private func width(_ text: String, size: Double) -> Double {
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        return CTLineGetTypographicBounds(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font])), nil, nil, nil)
    }
    public func minimumSize(for p: MainScreenPresentation) -> CGSize {
        var required = 520.0
        required = max(required, (p.titleVariants.map { width($0, size: 12) }.min() ?? 0) + 28,
                       (p.comparison == nil ? (p.lines.map { width($0, size: 10) }.max() ?? 0):0) + 28)
        if let c = p.comparison {
            let cell = c.columns.map { column in
                max(width(column.title + " " + (column.equality ?? ""), size: 11), width(column.effort + (column.configuration?.fast == true ? (p.language == .chinese ? " 快速" : " Fast") : ""), size: 12),
                    column.cells.map { width($0.text, size: 12) }.max() ?? 0) + 16
            }.max() ?? 0
            required = max(required, 88 + cell * 3 + 24)
            let widest=c.efforts.map{width(($0.recommended ? "★":"")+$0.title,size:11)}.max() ?? 0
            required=max(required,Double(c.efforts.count)*max(23,widest+8)+130)
        }
        for slot in p.footer {
            if case .option(let o) = slot {
                required = max(required, (o.choices.reduce(0) { $0 + width($1.title, size: 10) + 12 }) * Double(p.footer.count) + 24)
            }
        }
        let baseHeight = p.comparison == nil ? max(240, 118 + Double(p.lines.count) * 16 + (p.backLine == nil ? 0 : 22)) : 288
        let height = p.overview.map { max(baseHeight,NeutralOverviewRecipe.minimumHeight($0)) } ?? baseHeight
        return CGSize(width: ceil(required), height: height)
    }
    public func recipe(for p: MainScreenPresentation, size: CGSize) throws -> MainScreenRecipe {
        let minimum = minimumSize(for: p)
        guard size.width >= minimum.width, size.height >= minimum.height else { throw EngineTableError.invalidRecipe }
        let foreground = EngineInk(NSColor.labelColor), muted = EngineInk(NSColor.secondaryLabelColor)
        let background = EngineInk(NSColor.windowBackgroundColor), surface = EngineInk(NSColor.controlBackgroundColor)
        let rule = EngineInk(NSColor.separatorColor), blue = EngineInk(NSColor.systemBlue), gold = EngineInk(NSColor.systemYellow)
        let accent = EngineInk(NSColor.controlAccentColor)
        var commands: [EngineDrawingCommand] = [.fill(rect: CGRect(origin: .zero, size: size), radius: 0, ink: background)]
        var regions: [MainScreenHitRegion] = []
        var list:MainScreenListRecipe?
        var chart: ComparisonChartGeometry?
        func text(_ id: String, _ values: [String], _ r: CGRect, _ points: Double, _ ink: EngineInk, _ align: EngineTextAlignment = .left) {
            commands.append(.text(.init(id: id, variants: values, rect: r, font: .init(size: points), ink: ink, alignment: align)))
        }
        func key(_ id: String, _ r: CGRect, _ title: String, _ action: MainScreenAction, _ help: HelpExplanation, lit: Bool = false, value: String? = nil) {
            commands.append(.fill(rect: r, radius: 0, ink: surface))
            commands.append(.stroke(rect: r.insetBy(dx: 1, dy: 1), radius: 0, width: lit ? 2 : 1, ink: lit ? accent : rule))
            text(id + ".title", [title], r.insetBy(dx: 3, dy: 1), 11, foreground, .center)
            regions.append(.init(id: id, rect: r, action: action, label: title, help: help, value: value))
        }
        let pageWidth = (size.width - 30) / 4
        for (i, keyInfo) in p.pageKeys.enumerated() {
            key("screen.page.\(i)", CGRect(x: 6 + Double(i) * (pageWidth + 6), y: 4, width: pageWidth, height: 26),
                keyInfo.title, .page(keyInfo.page), p.pageHelp, lit: keyInfo.lit,
                value: p.language == .chinese ? (keyInfo.lit ? "已选" : "未选") : (keyInfo.lit ? "Selected" : "Not selected"))
        }
        let screen = CGRect(x: 6, y: 36, width: size.width - 12, height: size.height - 76)
        commands.append(.fill(rect: screen, radius: 0, ink: surface))
        var y = screen.minY + 8
        if let back = p.backLine {
            let r = CGRect(x: screen.minX + 6, y: y, width: screen.width - 12, height: 20)
            text("screen.back.title", [back], r, 11, foreground)
            regions.append(.init(id: "screen.back", rect: r, action: .back, label: back, help: p.returnHelp)); y += 22
        }
        if let compare=p.comparison {
            let header=CGRect(x:screen.minX+6,y:y,width:screen.width-12,height:14)
            let links=compare.websiteLinks,primaryWidth=width(links[0].title,size:10),secondaryWidth=width(links[1].title,size:10)
            let titleWidth=p.titleVariants.map{width($0,size:12)}.min() ?? 0
            let secondaryFits=titleWidth+primaryWidth+secondaryWidth+36<=header.width
            let shown=secondaryFits ? links:[links[0]],total=primaryWidth+(secondaryFits ? secondaryWidth+8:0)
            text("screen.title",p.titleVariants,CGRect(x:header.minX,y:y,width:max(1,header.width-total-24),height:14),12,foreground)
            regions.append(.init(id:"screen.title",rect:CGRect(x:header.minX,y:y,width:max(1,header.width-total-8),height:14),label:compare.modelName,help:compare.help,role:.readout,tabStop:false))
            if !compare.notes.isEmpty {text("compare.note",[compare.fastShown ? "⚡":"•"],CGRect(x:header.maxX-total-20,y:y,width:12,height:14),10,muted)}
            var x=header.maxX-total
            for (i,link) in shown.enumerated() {
                let w=width(link.title,size:10),rect=CGRect(x:x,y:y,width:w,height:14)
                text("compare.link.\(i)",[link.title],rect,10,muted)
                regions.append(.init(id:"compare.link.\(i)",rect:rect,action:.website(link),label:link.title,help:HelpCatalog(p.language).explanation(.link,context:.init(fact:link.title))))
                x+=w+8
            }
            y+=16
        } else {
            text("screen.title",p.titleVariants,CGRect(x:screen.minX+6,y:y,width:screen.width-12,height:20),12,foreground)
            regions.append(.init(id:"screen.title",rect:CGRect(x:screen.minX+6,y:y,width:screen.width-12,height:20),label:p.titleVariants.first ?? "",help:p.pageHelp,role:.readout,tabStop:false))
            y+=22
            for (i,line) in p.lines.enumerated() {text("screen.note.\(i)",[line],CGRect(x:screen.minX+6,y:y,width:screen.width-12,height:16),10,muted);y+=16}
        }
        if let compare = p.comparison {
            let labelWidth = 76.0, x = screen.minX + 8 + labelWidth, columnWidth = (screen.width - 16 - labelWidth) / 3, tableHeight = 96.0
            for (i, column) in compare.columns.enumerated() {
                let r = CGRect(x: x + Double(i) * columnWidth, y: y, width: columnWidth, height: tableHeight)
                let ink = column.light == .blue ? blue : column.light == .gold ? gold : column.light == .white ? foreground : muted
                let tint = column.light == .off || column.light == .dim ? surface : EngineInk(ink.red, ink.green, ink.blue, 0.12)
                commands.append(.fill(rect: r, radius: 0, ink: tint))
                commands.append(.stroke(rect: r.insetBy(dx: 1, dy: 1), radius: 0, width: 1, ink: rule))
                text("compare.\(i).role", [column.title + (column.equality.map { " " + $0 } ?? "")], CGRect(x: r.minX + 4, y: r.minY + 2, width: r.width - 8, height: 18), 10, ink, .center)
                if !column.unlit {
                    text("compare.\(i).effort", [column.effort + (column.configuration?.fast == true ? (p.language == .chinese ? " 快速" : " Fast") : "")], CGRect(x: r.minX + 4, y: r.minY + 20, width: r.width - 8, height: 18), 12, ink, .center)
                    for (j, cell) in column.cells.enumerated() {
                        text("compare.\(i).metric.\(j)", [cell.text], CGRect(x: r.minX + 4, y: r.minY + 40 + Double(j) * 18, width: r.width - 8, height: 18), 12, ink, .right)
                    }
                }
                let readings = column.cells.filter { !$0.text.isEmpty }.map { $0.metric.title(p.language) + " " + $0.text }.joined(separator: " · ")
                let label = [column.title, column.effort, column.equality, readings].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                regions.append(.init(id: "compare.column.\(i)", rect: r, label: label, help: compare.help, role: .readout, tabStop: false))
            }
            for (j, metric) in ComparisonMetric.allCases.enumerated() {
                text("compare.metric.\(j)", [metric.title(p.language)], CGRect(x: screen.minX + 8, y: y + 40 + Double(j) * 18, width: labelWidth - 6, height: 18), 11, muted)
            }
            let ladderY=screen.maxY-26,chartTop=y+tableHeight+8
            let slot=CGRect(x:screen.minX+4,y:chartTop,width:screen.width-8,height:ladderY-chartTop-18)
            if ComparisonPresentation.chartIsPresent(in:slot.size) {
                let plot=CGRect(x:slot.minX+36,y:slot.minY+6,width:slot.width-106,height:slot.height-14)
                chart=compare.chartGeometry(in:plot,labelBounds:slot)
                if let chart {
                    for tick in chart.axis.ticks {
                        let yy=chart.y(tick)
                        commands.append(.polyline(points:[.init(x:plot.minX,y:yy),.init(x:plot.maxX,y:yy)],width:tick==1 ? 1:0.5,ink:rule))
                        let gap=plot.height/Double(max(1,chart.axis.ticks.count-1))
                        if tick==1 || gap>=11 || tick==chart.axis.ticks.first || tick==chart.axis.ticks.last {
                            text("compare.tick.\(tick)",["×"+String(format:"%.3g",locale:Locale(identifier:"en_US_POSIX"),tick)],CGRect(x:slot.minX,y:yy-6,width:32,height:13),9,muted,.right)
                        }
                    }
                    for trace in chart.traces {
                        let ink=trace.metric == .ability ? foreground:muted
                        let dash:[Double]=trace.fast ? [4,2.5]:trace.metric == .time ? [1,2]:[]
                        for segment in trace.segments where segment.count>1 {commands.append(.polyline(points:segment.map(\.point),width:trace.metric == .ability ? 1.5:1,ink:ink,dash:dash))}
                        for point in trace.points.compactMap({$0}) {commands.append(.ellipse(rect:CGRect(x:point.point.x-1.2,y:point.point.y-1.2,width:2.4,height:2.4),ink:ink))}
                    }
                    for end in chart.endpoints {
                        commands.append(.polyline(points:[.init(x:end.anchor.x+2,y:end.anchor.y),.init(x:plot.maxX-2,y:end.anchor.y),.init(x:plot.maxX+8,y:end.y)],width:0.5,ink:muted))
                        text("compare.end.\(end.metric)",[(compare.fastShown && end.metric != .ability ? "⚡ ":"")+end.metric.title(p.language)],CGRect(x:plot.maxX+10,y:end.y-6,width:58,height:12),p.compact ? 8:9,muted)
                    }
                    for profile in chart.profiles {
                        for role in profile.roles {
                            let ink=role == .current ? foreground:role == .recommended ? gold:blue
                            let x=chart.x(chart.effortKeys.firstIndex(of:profile.configuration.effort)!)
                            commands.append(.polyline(points:[.init(x:x,y:plot.minY),.init(x:x,y:plot.maxY)],width:1,ink:ink,dash:role == .current ? []:role == .recommended ? [1,2]:[4,2.5]))
                            if profile.configuration.fast {text("compare.fast.\(role)",["⚡"],CGRect(x:x-4,y:slot.minY,width:10,height:9),8,ink)}
                            let radius=role == .current ? 2.0:role == .recommended ? 3.3:4.6
                            for point in profile.points.compactMap({$0}) {
                                let rect=CGRect(x:point.point.x-radius,y:point.point.y-radius,width:2*radius,height:2*radius)
                                if role == .current {commands.append(.ellipse(rect:rect,ink:ink))}
                                else {
                                    let circle=(0...32).map { i in CGPoint(x:point.point.x+radius*cos(Double(i)*2*Double.pi/32),y:point.point.y+radius*sin(Double(i)*2*Double.pi/32)) }
                                    commands.append(.polyline(points:circle,width:1,ink:ink,dash:role == .recommended ? [1,2]:[4,2.5]))
                                }
                            }
                        }
                    }
                    regions.append(.init(id:"compare.chart",rect:slot,label:compare.chartDescription,help:compare.help,role:.readout,tabStop:false,accessibilityDetails:compare.accessibilityDetails(for:chart)))
                }
            }
            let count=compare.efforts.count,ladderStart=screen.minX+40,keyWidth=(screen.width-114)/Double(max(1,count))
            for (i, effort) in compare.efforts.enumerated() {
                let value = [(effort.current ? (p.language == .chinese ? "当前" : "Current") : nil),
                             (effort.trial ? (p.language == .chinese ? "试" : "Try") : nil),
                             (effort.recommended ? (p.language == .chinese ? "★推荐" : "★ Recommended") : nil)].compactMap { $0 }.joined(separator: " · ")
                key("compare.effort.\(effort.key)", CGRect(x:ladderStart+Double(i)*keyWidth+1.5,y:ladderY,width:keyWidth-3,height:20),
                    (effort.recommended ? "★" : "") + effort.title, .effort(modelID: compare.modelID, key: effort.key), compare.help, lit: effort.trial || effort.current, value: value)
            }
        } else if let data=p.effort {
            let drawing=NeutralEffortPageRecipe.make(data,in:CGRect(x:screen.minX+6,y:y,width:screen.width-12,height:screen.maxY-y-4))
            commands+=drawing.commands;regions+=drawing.regions;list=drawing.list
        } else if let data=p.destinations {
            list=NeutralDestinationsRecipe.make(data,in:CGRect(x:screen.minX+6,y:y,width:screen.width-12,height:screen.maxY-y-4))
        } else if let data=p.session {
            list=NeutralDestinationsRecipe.detail(data,language:p.language,in:CGRect(x:screen.minX+6,y:y,width:screen.width-12,height:screen.maxY-y-4))
        } else if let history=p.history {
            list=NeutralSubscriptionHistoryRecipe.make(history,in:CGRect(x:screen.minX+6,y:y,width:screen.width-12,height:screen.maxY-y-4))
        } else if let subscription=p.subscription {
            list=NeutralSubscriptionRecipe.make(subscription,in:CGRect(x:screen.minX+6,y:y,width:screen.width-12,height:screen.maxY-y-4))
        } else if let overview = p.overview {
            let content = CGRect(x:screen.minX+8,y:y,width:screen.width-16,height:screen.maxY-y-4)
            let drawing = try NeutralOverviewRecipe.make(overview,in:content)
            commands += drawing.commands; regions += drawing.regions
        } else if p.lines.isEmpty {
            text("screen.empty", [p.language == .chinese ? "暂无信息" : "No information available"], CGRect(x: screen.minX + 8, y: y + 12, width: screen.width - 16, height: 24), 12, muted)
        } else {
            // Lines belong to the supplied page/body snapshot; no future page layout is implemented here.
        }
        let footerWidth = (size.width - 12 - Double(p.footer.count - 1) * 6) / Double(p.footer.count), footerY = size.height - 32
        for (i, slot) in p.footer.enumerated() {
            let r = CGRect(x: 6 + Double(i) * (footerWidth + 6), y: footerY, width: footerWidth, height: 26), id = "screen.footer.\(i)"
            switch slot {
            case .blank: commands.append(.fill(rect: r, radius: 0, ink: surface))
            case .back(let title): key(id, r, title, .back, p.returnHelp)
            case .fast(let model, let title, let off, let on, let selected, let help):
                commands.append(.fill(rect: r, radius: 0, ink: surface))
                commands.append(.stroke(rect: r.insetBy(dx: 1, dy: 1), radius: 0, width: 1, ink: rule))
                let third = r.width / 3
                text(id + ".title", [title], CGRect(x: r.minX, y: r.minY, width: third, height: r.height), 11, foreground, .center)
                text(id + ".off", [off], CGRect(x: r.minX + third, y: r.minY, width: third, height: r.height), 11, selected ? muted : foreground, .center)
                text(id + ".on", [on], CGRect(x: r.minX + third * 2, y: r.minY, width: third, height: r.height), 11, selected ? foreground : muted, .center)
                regions.append(.init(id: id, rect: r, action: .fast(modelID: model), label: title + " " + off + " | " + on, help: help, value: selected ? on : off))
            case .option(let option):
                let title = option.choices.map(\.title).joined(separator: " | ")
                commands.append(.fill(rect: r, radius: 0, ink: surface))
                commands.append(.stroke(rect: r.insetBy(dx: 1, dy: 1), radius: 0, width: 1, ink: rule))
                regions.append(.init(id: id, rect: r, action: .option(page: p.displayedPage, id: option.id, value: nil), label: title, help: option.help, enabled: option.choices.contains(where: \.enabled), value: option.selectedValue))
                let cw = r.width / Double(option.choices.count)
                for (j, choice) in option.choices.enumerated() {
                    let cr = CGRect(x: r.minX + Double(j) * cw, y: r.minY, width: cw, height: r.height)
                    text(id + ".choice.\(choice.value)", [choice.title], cr.insetBy(dx: 2, dy: 1), 10, option.selectedValue == choice.value ? foreground : muted, .center)
                    regions.append(.init(id: id + ".choice.\(choice.value)", rect: cr, action: .option(page: p.displayedPage, id: option.id, value: choice.value),
                        label: choice.title, help: option.help, role: .choice, enabled: choice.enabled, tabStop: false, value: option.selectedValue == choice.value ? "1" : "0"))
                }
            }
        }
        return MainScreenRecipe(size: size, commands: commands, regions: regions, chart: chart, focusInk: accent, list:list)
    }
}
