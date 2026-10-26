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
                       (p.lines.map { width($0, size: 10) }.max() ?? 0) + 28)
        if let c = p.comparison {
            let cell = c.columns.map { column in
                max(width(column.title + " " + (column.equality ?? ""), size: 11), width(column.effort + (column.configuration?.fast == true ? (p.language == .chinese ? " 快速" : " Fast") : ""), size: 12),
                    column.cells.map { width($0.text, size: 12) }.max() ?? 0) + 16
            }.max() ?? 0
            required = max(required, 88 + cell * 3 + 24)
            required = max(required, c.efforts.reduce(0) { $0 + width(($1.recommended ? "★" : "") + $1.title, size: 11) + 18 } + 24)
        }
        for slot in p.footer {
            if case .option(let o) = slot {
                required = max(required, (o.choices.reduce(0) { $0 + width($1.title, size: 10) + 12 }) * Double(p.footer.count) + 24)
            }
        }
        let height = p.comparison == nil ? max(240, 118 + Double(p.lines.count) * 16 + (p.backLine == nil ? 0 : 22)) : 288 + Double(p.lines.count) * 16
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
        text("screen.title", p.titleVariants, CGRect(x: screen.minX + 6, y: y, width: screen.width - 12, height: 20), 12, foreground)
        regions.append(.init(id: "screen.title", rect: CGRect(x: screen.minX + 6, y: y, width: screen.width - 12, height: 20),
                             label: p.comparison?.modelName ?? p.titleVariants.first ?? "", help: p.comparison?.help ?? p.pageHelp, role: .readout, tabStop: false))
        y += 22
        for (i, line) in p.lines.enumerated() {
            text("screen.note.\(i)", [line], CGRect(x: screen.minX + 6, y: y, width: screen.width - 12, height: 16), 10, muted); y += 16
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
            let ladderY = screen.maxY - 26, chartTop = y + tableHeight + 8, available = ladderY - chartTop - 18
            if available >= 34, !compare.chartProfiles.isEmpty {
                let plot = CGRect(x: screen.minX + 44, y: chartTop + 4, width: screen.width - 70, height: available - 4)
                chart = compare.chartGeometry(in: plot)
                if let chart {
                    for tick in chart.axis.ticks {
                        let yy = chart.y(tick)
                        commands.append(.polyline(points: [CGPoint(x: plot.minX, y: yy), CGPoint(x: plot.maxX, y: yy)], width: tick == 1 ? 1.5 : 0.5, ink: rule))
                        text("compare.tick.\(tick)", ["×" + String(format: "%.3g", tick)], CGRect(x: screen.minX + 5, y: yy - 6, width: 35, height: 13), 9, muted, .right)
                    }
                    for (i, metric) in ComparisonMetric.allCases.enumerated() {
                        let labelX: CGFloat = plot.minX + CGFloat(i) * plot.width / 2 - 30
                        text("compare.axis.\(i)", [metric.title(p.language)], CGRect(x: labelX, y: plot.maxY + 2, width: 60, height: 14), 9, muted, .center)
                    }
                    for profile in chart.profiles {
                        let ink = profile.roles.contains(.current) ? foreground : profile.roles.contains(.recommended) ? gold : blue
                        for segment in profile.segments where segment.count > 1 { commands.append(.polyline(points: segment.map(\.point), width: 1.3, ink: ink)) }
                        for role in profile.roles {
                            let radius = role == .current ? 2.0 : role == .recommended ? 3.0 : 4.0
                            for point in profile.points.compactMap({ $0 }) {
                                let r = CGRect(x: point.point.x - radius, y: point.point.y - radius, width: radius * 2, height: radius * 2)
                                if role == .current { commands.append(.ellipse(rect: r, ink: foreground)) }
                                else { commands.append(.stroke(rect: r, radius: radius, width: 1, ink: role == .recommended ? gold : blue)) }
                            }
                        }
                    }
                    regions.append(.init(id: "compare.chart", rect: CGRect(x: screen.minX + 4, y: chartTop, width: screen.width - 8, height: available + 14),
                                         label: compare.chartDescription, help: compare.help, role: .readout, tabStop: false))
                }
            }
            let count = compare.efforts.count, keyWidth = (screen.width - 12) / Double(max(1, count))
            for (i, effort) in compare.efforts.enumerated() {
                let value = [(effort.current ? (p.language == .chinese ? "当前" : "Current") : nil),
                             (effort.trial ? (p.language == .chinese ? "试" : "Try") : nil),
                             (effort.recommended ? (p.language == .chinese ? "★推荐" : "★ Recommended") : nil)].compactMap { $0 }.joined(separator: " · ")
                key("compare.effort.\(effort.key)", CGRect(x: screen.minX + 6 + Double(i) * keyWidth, y: ladderY, width: keyWidth - 3, height: 20),
                    (effort.recommended ? "★" : "") + effort.title, .effort(modelID: compare.modelID, key: effort.key), compare.help, lit: effort.trial || effort.current, value: value)
            }
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
        return MainScreenRecipe(size: size, commands: commands, regions: regions, chart: chart, focusInk: accent)
    }
}
