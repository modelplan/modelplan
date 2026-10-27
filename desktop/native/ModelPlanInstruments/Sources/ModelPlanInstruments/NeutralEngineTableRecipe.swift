// SPDX-License-Identifier: MIT
import AppKit
import CoreText

/// A complete, ordinary system-font table. Official styling is not a fallback dependency.
@MainActor public final class NeutralEngineTableRecipe: EngineTableRecipeProvider {
    public init() {}
    public func image(_ resourceID: String) throws -> CGImage { throw EngineTableError.missingResource(resourceID) }
    public func font(_ request: EngineFontRequest) throws -> CTFont {
        guard request.resourceID == nil else { throw EngineTableError.missingResource(request.resourceID!) }
        let weight: NSFont.Weight = request.weight >= 600 ? .semibold : request.weight >= 500 ? .medium : .regular
        let font = request.monospaced ? NSFont.monospacedSystemFont(ofSize: request.size, weight: weight) : NSFont.systemFont(ofSize: request.size, weight: weight)
        return CTFontCreateWithName(font.fontName as CFString, request.size, nil)
    }
    public func recipe(for p: EngineTablePresentation, size: CGSize) throws -> EngineTableRecipe {
        guard size.width >= 300, size.height >= 180 else { throw EngineTableError.invalidRecipe }
        let ink = EngineInk(NSColor.labelColor), muted = EngineInk(NSColor.secondaryLabelColor)
        let background = EngineInk(NSColor.windowBackgroundColor), surface = EngineInk(NSColor.controlBackgroundColor)
        let rule = EngineInk(NSColor.separatorColor), accent = EngineInk(NSColor.controlAccentColor)
        let help = HelpCatalog(p.language)
        var commands: [EngineDrawingCommand] = [.fill(rect: CGRect(origin: .zero, size: size), radius: 0, ink: background)]
        var regions: [EngineHitRegion] = []
        let left: CGFloat = 68, gap: CGFloat = 8, keyHeight: CGFloat = 28
        let pagerHeight: CGFloat = p.pageCount > 1 ? 28 : 0
        let lcd = CGRect(x: 0, y: keyHeight + gap, width: size.width, height: size.height - keyHeight - gap - pagerHeight)
        commands.append(.fill(rect: lcd, radius: 0, ink: surface))
        let width = (size.width - left) / CGFloat(p.tracks)
        let rowHeight = lcd.height / CGFloat(p.labels.count)
        func text(_ id: String, _ variants: [String], _ rect: CGRect, _ fontSize: Double, _ color: EngineInk,
                  _ alignment: EngineTextAlignment = .left, _ weight: Double = 400) {
            commands.append(.text(.init(id: id, variants: variants, rect: rect, font: .init(size: fontSize, weight: weight), ink: color, alignment: alignment)))
        }
        func underline(_ rect:CGRect,_ color:EngineInk,_ selected:Bool) {
            commands.append(.fill(rect:CGRect(x:rect.minX+8,y:rect.maxY-6,width:max(1,rect.width-16),height:3),radius:0,
                ink:.init(color.red,color.green,color.blue,selected ? 1:0.22)))
        }
        func key(_ id: String, _ rect: CGRect, _ title: String, _ explanation: HelpExplanation, _ intent: EngineTableIntent,
                 selected: Bool = false, enabled: Bool = true, label: String? = nil, nameTooltipTarget: EngineNameTooltipTarget? = nil) {
            commands.append(.fill(rect: rect.insetBy(dx: 1, dy: 1), radius: 0, ink: surface))
            commands.append(.stroke(rect: rect.insetBy(dx: 1, dy: 1), radius: 0, width: selected ? 2 : 1, ink: selected ? accent : rule))
            text(id + ".text", [title], rect.insetBy(dx: 5, dy: 1), 11, enabled ? ink : muted, .center)
            let accessibleLabel = label ?? (intent == .openSubscriptionsSettings ? p.addLabel : title)
            regions.append(.init(id: id, rect: rect, label: accessibleLabel, help: explanation, intent: intent, enabled: enabled, selected: selected, nameTooltipTarget: nameTooltipTarget))
        }
        let all = CGRect(x: 0, y: 0, width: left - 4, height: keyHeight)
        key("engine.all", all, p.allLabel, p.allKeyHelp, .selectScope(.all), selected: p.scope == .all, label: p.allKeyLabel)
        underline(all,EngineInk(NSColor.white),p.scope == .all)
        for i in 0..<p.tracks {
            let keyRect = CGRect(x: left + CGFloat(i) * width, y: 0, width: width, height: keyHeight)
            if let col = p.columns[i] {
                let scope: InstrumentScope = col.selected ? .all : .subscription(col.id)
                key("engine.subscription." + col.id, keyRect, col.identity.shortName, col.keyHelp, .selectScope(scope), selected: col.selected, label: col.keyLabel, nameTooltipTarget: .subscriptionKey(col.id))
                underline(keyRect,accent,col.selected)
            } else {
                key("engine.empty.\(p.page * 6 + i).key", keyRect, "—", help.explanation(.control, context: .init(fact: p.addLabel)), .openSubscriptionsSettings)
            }
        }
        if let empty = p.emptyLabel {
            text("engine.empty.message", [empty], lcd.insetBy(dx: 10, dy: 10), 11, muted, .center)
            for i in 0..<p.tracks {
                let frame = CGRect(x: left + CGFloat(i) * width, y: lcd.minY, width: width, height: lcd.height)
                regions.append(.init(id: "engine.empty.\(i).body", rect: frame, label: p.addLabel,
                                     help: help.explanation(.control, context: .init(fact: p.addLabel)), intent: .openSubscriptionsSettings, tabStop: false))
            }
            return EngineTableRecipe(size: size, commands: commands, regions: regions, focusInk: accent)
        }
        for row in 0..<p.labels.count {
            text("engine.label.\(row)", [p.labels[row]], CGRect(x: 4, y: lcd.minY + CGFloat(row) * rowHeight, width: left - 8, height: rowHeight), 10, muted)
        }
        // Empty columns never receive their own fill, glass, placeholder numbers or bars.
        for i in 0..<p.tracks {
            let x = left + CGFloat(i) * width
            let frame = CGRect(x: x, y: lcd.minY, width: width, height: lcd.height)
            commands.append(.fill(rect: CGRect(x: x, y: lcd.minY, width: 1, height: lcd.height), radius: 0, ink: rule))
            guard let col = p.columns[i] else {
                regions.append(.init(id: "engine.empty.\(p.page * 6 + i).body", rect: frame, label: p.addLabel,
                                     help: help.explanation(.control, context: .init(fact: p.addLabel)), intent: .openSubscriptionsSettings, tabStop: false))
                continue
            }
            if col.caution >= .amber {
                let color = col.caution == .critical ? NSColor.systemRed : .systemOrange
                commands.append(.fill(rect: frame, radius: 0, ink: EngineInk(color.withAlphaComponent(0.12))))
            }
            for row in 0..<3 {
                guard let cell = col.cells[row] else { continue }
                let area = CGRect(x: x + 6, y: lcd.minY + CGFloat(row) * rowHeight, width: width - 12, height: rowHeight)
                let valueColor = cell.level == .critical ? EngineInk(NSColor.systemRed) : cell.level == .amber ? EngineInk(NSColor.systemOrange) : ink
                let value = cell.amount + cell.suffix
                let fontSize: Double = p.tracks >= 5 ? 14 : 17
                let valueFont = try font(.init(size: fontSize, weight: 600))
                let line = CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): valueFont]))
                let advance = min(area.width, CTLineGetTypographicBounds(line, nil, nil, nil))
                let valueRect = CGRect(x: area.minX, y: area.minY + 2, width: max(1, advance), height: rowHeight * 0.48)
                text("engine.\(col.id).\(row).value", [value], valueRect, fontSize, valueColor, .left, 600)
                text("engine.\(col.id).\(row).note", cell.notes, CGRect(x: valueRect.maxX + 3, y: valueRect.minY, width: max(1, area.maxX - valueRect.maxX - 3), height: valueRect.height), 10, muted, .right)
                let barY = area.maxY - 10
                let barWidth = (area.width - 9 * 2) / 10
                for n in 0..<10 {
                    let filled = n < (cell.litSegments ?? 0)
                    let status = cell.level == .critical ? NSColor.systemRed : cell.level == .amber ? .systemOrange : .systemGreen
                    let rect = CGRect(x: area.minX + CGFloat(n) * (barWidth + 2), y: barY, width: barWidth, height: 4)
                    commands.append(.fill(rect: rect, radius: 0, ink: filled ? EngineInk(status) : rule))
                    if let dots = cell.timeDots {
                        commands.append(.ellipse(rect: CGRect(x: rect.midX - 1, y: barY + 6, width: 2, height: 2), ink: n < dots ? ink : rule))
                    }
                }
                regions.append(.init(id: "engine.\(col.id).row.\(row)", rect: area, label: cell.accessibilityLabel,
                                     help: cell.help, role: .readout))
            }
            let today = CGRect(x: x + 6, y: lcd.minY + 3 * rowHeight, width: width - 12, height: rowHeight)
            text("engine.\(col.id).today", [col.todayTokens ?? ""], today, 11, ink)
            text("engine.\(col.id).speed", [col.todaySpeed.map { $0 + " t/s" } ?? ""], today, 10, muted, .right)
            regions.append(.init(id: "engine.\(col.id).today", rect: today, label: col.todayHelp.accessibleDescription, help: col.todayHelp, role: .readout))
            if p.hasReserve {
                let reserve = CGRect(x: x + 6, y: lcd.minY + 4 * rowHeight, width: width - 12, height: rowHeight)
                for (n, variants) in col.reserveLines.prefix(2).enumerated() {
                    text("engine.\(col.id).reserve.\(n)", variants, CGRect(x: reserve.minX, y: reserve.minY + CGFloat(n) * 13, width: reserve.width, height: 13), 10, ink)
                }
                regions.append(.init(id: "engine.\(col.id).reserve", rect: reserve, label: col.reserveHelp.accessibleDescription, help: col.reserveHelp, role: .readout))
            }
        }
        if p.pageCount > 1 {
            let y = size.height - pagerHeight + 4, button: CGFloat = 24
            let total = button * 2 + CGFloat(p.pageCount) * 16
            let start = size.width - total
            key("engine.page.previous", CGRect(x: start, y: y, width: button, height: 20), "◀", help.explanation(.page, context: .init(fact: p.previousLabel)), .changePage(p.page - 1), enabled: p.page > 0)
            for indicator in p.pageIndicators {
                let rect = CGRect(x: start + button + CGFloat(indicator.page) * 16, y: y, width: 16, height: 20)
                let color = indicator.caution == .critical ? EngineInk(NSColor.systemRed) : indicator.caution == .amber ? EngineInk(NSColor.systemOrange) : indicator.current ? ink : muted
                commands.append(.ellipse(rect: CGRect(x: rect.midX - 2, y: rect.midY - 2, width: 4, height: 4), ink: color))
                regions.append(.init(id: "engine.page.\(indicator.page)", rect: rect, label: indicator.help.accessibleDescription, help: indicator.help, role: .image))
            }
            key("engine.page.next", CGRect(x: size.width - button, y: y, width: button, height: 20), "▶", help.explanation(.page, context: .init(fact: p.nextLabel)), .changePage(p.page + 1), enabled: p.page + 1 < p.pageCount)
        }
        return EngineTableRecipe(size: size, commands: commands, regions: regions, focusInk: accent)
    }
}
