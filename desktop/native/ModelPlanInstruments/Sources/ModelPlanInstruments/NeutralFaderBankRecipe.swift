// SPDX-License-Identifier: MIT
import AppKit
import CoreText

/// Ordinary independent system-font controls; no official coordinates, palette or art.
@MainActor public final class NeutralFaderBankRecipe: FaderBankRecipeProvider {
    public init() {}
    public func font(_ request: EngineFontRequest) throws -> CTFont { try NeutralEngineTableRecipe().font(request) }
    public func image(_ resourceID: String) throws -> CGImage { throw EngineTableError.missingResource(resourceID) }
    public func minimumSize(for p: FaderBankPresentation) -> CGSize {
        let levels = p.channels.compactMap { $0?.efforts.count }.max() ?? 0
        let lcd = p.compact ? 76.0 : 100.0
        return CGSize(width: 330, height: 32 + lcd + 12 + max(88, Double(max(0, levels - 1)) * 20 + 16) + 32)
    }
    public func recipe(for p: FaderBankPresentation, size: CGSize) throws -> FaderBankRecipe {
        let minimum = minimumSize(for: p)
        guard size.width >= minimum.width, size.height >= minimum.height else { throw EngineTableError.invalidRecipe }
        let foreground = EngineInk(NSColor.labelColor), muted = EngineInk(NSColor.secondaryLabelColor)
        let surface = EngineInk(NSColor.controlBackgroundColor), rule = EngineInk(NSColor.separatorColor)
        let accent = EngineInk(NSColor.controlAccentColor), blue = EngineInk(NSColor.systemBlue), star = EngineInk(NSColor.systemYellow)
        var commands: [EngineDrawingCommand] = [.fill(rect: CGRect(origin: .zero, size: size), radius: 0, ink: EngineInk(NSColor.windowBackgroundColor))]
        var regions: [FaderHitRegion] = [], caps: [FaderCapSurface] = []
        let gap = 12.0, scaleWidth = 72.0, width = (size.width - scaleWidth - 3 * gap) / 3
        let lcdHeight = p.compact ? 76.0 : 100.0, top = 28.0 + lcdHeight + 16, bottom = size.height - 36
        let travelTop = top + 8, travelBottom = bottom - 8
        let help = HelpCatalog(p.language)
        func text(_ id: String, _ variants: [String], _ r: CGRect, _ points: Double, _ ink: EngineInk,
                  _ alignment: EngineTextAlignment = .left, fade: Bool = false) {
            commands.append(.text(.init(id: id, variants: variants, rect: r, font: .init(size: points), ink: ink,
                                        alignment: alignment, transitionDuration: fade ? FaderTiming.readingFade : 0)))
        }
        func key(_ id: String, _ r: CGRect, _ title: String, _ action: FaderRegionAction, _ enabled: Bool, _ explanation: HelpExplanation) {
            commands.append(.fill(rect: r, radius: 0, ink: surface)); commands.append(.stroke(rect: r.insetBy(dx: 1, dy: 1), radius: 0, width: 1, ink: rule))
            text(id + ".text", [title], r, 11, enabled ? foreground : muted, .center)
            regions.append(.init(id: id, rect: r, action: action, label: explanation.title, help: explanation, enabled: enabled))
        }
        for slot in 0..<3 {
            let x = gap + Double(slot) * (width + gap), lcd = CGRect(x: x, y: 26, width: width, height: lcdHeight)
            commands.append(.fill(rect: lcd, radius: 0, ink: surface))
            commands.append(.fill(rect: CGRect(x: lcd.midX - 2, y: top, width: 4, height: bottom - top), radius: 0, ink: rule))
            guard let channel = p.channels[slot] else { continue }
            let prefix = "fader.slot.\(slot)"
            let indicator = CGRect(x: lcd.midX - 3, y: 10, width: 6, height: 6)
            let indicatorInk = channel.indicatorTone == .trial ? blue : channel.indicatorTone == .idle ? muted : foreground
            commands.append(.ellipse(rect: indicator, ink: indicatorInk))
            if channel.fastIndicator { text(prefix + ".fast", ["⚡"], CGRect(x: lcd.midX + 5, y: 3, width: 18, height: 16), 11, indicatorInk) }
            regions.append(.init(id: prefix + ".indicator", rect: CGRect(x: x, y: 2, width: width, height: 20), role: .readout,
                                 label: channel.name, help: channel.indicatorHelp, tabStop: false, modelID: channel.id))
            if !channel.vendors.isEmpty {
                let w = width / Double(channel.vendors.count)
                for i in channel.vendors.indices { commands.append(.fill(rect: CGRect(x: x + Double(i) * w, y: 26, width: max(1, w - 1), height: 3), radius: 0, ink: accent)) }
            }
            text(prefix + ".name", channel.nameVariants, CGRect(x: x + 4, y: 32, width: width - 8, height: 17), 11, foreground)
            if channel.favorite { text(prefix + ".favorite", ["•"], CGRect(x: lcd.maxX - 12, y: 32, width: 8, height: 12), 10, foreground) }
            let barGap = 2.0, barWidth = min(7, max(1, (width - 8 - Double(max(0, channel.efforts.count - 1)) * barGap) / Double(max(1, channel.efforts.count))))
            for (i, effort) in channel.efforts.enumerated() {
                let height = effort.abilityFraction.map { 3 + $0 * 10 } ?? 1
                let r = CGRect(x: x + 4 + Double(i) * (barWidth + barGap), y: 63 - height, width: barWidth, height: height)
                commands.append(.fill(rect: r, radius: 0, ink: effort.current ? foreground : rule))
                if effort.recommended { commands.append(.fill(rect: CGRect(x: r.minX, y: r.minY - 3, width: r.width, height: 2), radius: 0, ink: star)) }
                if effort.trial { commands.append(.fill(rect: CGRect(x: r.minX, y: r.maxY - 2, width: r.width, height: 2), radius: 0, ink: blue)) }
            }
            text(prefix + ".state", channel.stateVariants, CGRect(x: x + 4, y: 65, width: width - 8, height: 18), 12,
                 channel.trial == nil ? foreground : blue, fade: true)
            if let recommendation = channel.recommendation {
                text(prefix + ".recommendation", [recommendation + (channel.costMultiple.map { " · " + $0 } ?? ""), recommendation],
                     CGRect(x: x + 4, y: 84, width: width - 8, height: max(1, lcd.maxY - 84)), 10, star)
            } else if let multiple = channel.costMultiple, let basis = channel.costBasis {
                if p.language == .english {
                    text(prefix + ".cost", [multiple], CGRect(x: x + 4, y: 84, width: width - 8, height: 10), 9, muted)
                    text(prefix + ".basis", [basis], CGRect(x: x + 4, y: 95, width: width - 8, height: 10), 9, muted)
                } else { text(prefix + ".cost", [multiple + " " + basis], CGRect(x: x + 4, y: 84, width: width - 8, height: max(1, lcd.maxY - 84)), 9, muted) }
            }
            regions.append(.init(id: prefix + ".lcd", rect: lcd, action: .lcd(channel.id), label: channel.name, help: channel.lcdHelp, modelID: channel.id))
            let travel = CGRect(x: x, y: top, width: width, height: bottom - top)
            let shown = channel.efforts.firstIndex { $0.key == channel.shownEffort }
            regions.append(.init(id: prefix + ".travel", rect: travel, role: .slider, action: .travel(channel.id), label: channel.name,
                                 help: channel.travelHelp, enabled: !channel.efforts.isEmpty, modelID: channel.id,
                                 levelCount: channel.efforts.count, shownIndex: shown, top: travelTop, bottom: travelBottom,
                                 detents: channel.efforts.map { .init(key: $0.key, position: $0.position) }))
            for effort in channel.efforts {
                let y = travelTop + effort.position * (travelBottom - travelTop)
                commands.append(.fill(rect: CGRect(x: lcd.midX - 14, y: y, width: 28, height: 1), radius: 0, ink: rule))
                if effort.recommended { text(prefix + ".star", ["★"], CGRect(x: lcd.midX + 18, y: y - 6, width: 14, height: 13), 10, star) }
                if effort.otherSessionCount > 0 { text(prefix + ".other." + effort.key, ["•\(effort.otherSessionCount)"], CGRect(x: x, y: y - 6, width: 20, height: 13), 9, muted) }
            }
            func cap(_ kind: FaderCapKind, _ suffix: String, _ position: Double, _ ink: EngineInk, _ opacity: Float, _ pointer: Bool = false) {
                let r = CGRect(x: lcd.midX - 16, y: travelTop + position * (travelBottom - travelTop) - 5, width: 32, height: 10)
                let local = CGRect(origin: .zero, size: r.size)
                caps.append(.init(id: prefix + suffix, modelID: channel.id, kind: kind, frame: r,
                                  commands: [.fill(rect: local, radius: 0, ink: ink)], opacity: opacity, pointerOwned: pointer))
            }
            cap(.real, ".real", channel.realPosition, foreground, channel.parked ? 0.4 : 1)
            if let ghost = channel.dragPosition ?? channel.ghostPosition { cap(.ghost, ".ghost", ghost, blue, 0.75, channel.dragPosition != nil) }
            if let preview = channel.previewPosition, channel.dragPosition == nil {
                let r = CGRect(x: lcd.midX - 16, y: travelTop + preview * (travelBottom - travelTop) - 5, width: 32, height: 10)
                caps.append(.init(id: prefix + ".preview", modelID: channel.id, kind: .preview, frame: r,
                                  commands: [.stroke(rect: CGRect(origin: .zero, size: r.size).insetBy(dx: 1, dy: 1), radius: 0, width: 1, ink: blue)]))
            }
        }
        if let target = p.target {
            let x = size.width - scaleWidth
            for effort in target.efforts {
                let y = travelTop + effort.position * (travelBottom - travelTop)
                let r = CGRect(x: x, y: y - 10, width: scaleWidth, height: 20)
                text("scale." + effort.key, [effort.label], r, 10, foreground)
                regions.append(.init(id: "fader.level." + effort.key, rect: r, action: .effort(target.id, effort.key),
                                     label: effort.label, help: target.travelHelp, tabStop: false, modelID: target.id))
            }
        }
        if let empty = p.emptyLabel { text("empty", [empty], CGRect(x: 12, y: 40, width: size.width - 24, height: 30), 12, muted, .center) }
        if p.bankCount > 1 {
            let y = size.height - 24
            key("fader.bank.previous", CGRect(x: 12, y: y, width: 28, height: 20), "◀", .bank(p.bank - 1), p.bank > 0,
                help.explanation(.bank, context: .init(fact: p.previousLabel)))
            text("bank", [p.bankLabel], CGRect(x: 44, y: y, width: size.width - 88, height: 20), 10, foreground, .center)
            key("fader.bank.next", CGRect(x: size.width - 40, y: y, width: 28, height: 20), "▶", .bank(p.bank + 1), p.bank + 1 < p.bankCount,
                help.explanation(.bank, context: .init(fact: p.nextLabel)))
        }
        return FaderBankRecipe(size: size, commands: commands, regions: regions, caps: caps, focusInk: accent)
    }
}
