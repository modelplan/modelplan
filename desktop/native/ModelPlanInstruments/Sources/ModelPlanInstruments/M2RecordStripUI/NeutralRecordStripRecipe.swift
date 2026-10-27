// SPDX-License-Identifier: MIT
import AppKit
import CoreText

/// Complete resource-free community appearance. Frozen brand geometry/fonts are injected separately.
@MainActor public final class NeutralRecordStripRecipe: RecordStripRecipeProvider {
    public init() {}
    public func preferredSize(for density: RecordStripDensity) -> CGSize {
        CGSize(width: 700, height: density == .full ? 152 : 104)
    }
    public func font(_ request: EngineFontRequest) throws -> CTFont {
        guard request.resourceID == nil else { throw EngineTableError.missingResource(request.resourceID!) }
        return NSFont.monospacedSystemFont(ofSize: request.size, weight: .regular) as CTFont
    }
    public func image(_ resourceID: String) throws -> CGImage { throw EngineTableError.missingResource(resourceID) }
    public func recipe(for input: RecordStripViewInput, size: CGSize, hover: RecordStripHover?) throws -> RecordStripRecipe {
        let foreground = EngineInk(input.appearance.dark ? NSColor.white : .black)
        let muted = EngineInk(input.appearance.dark ? NSColor.lightGray : .darkGray)
        let background = EngineInk(input.appearance.dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.95, alpha: 1))
        var commands: [EngineDrawingCommand] = [.fill(rect: CGRect(origin: .zero, size: size), radius: 4, ink: background)]
        var rows: [RecordStripRowLayout] = [], cursors: [RecordStripCursor] = []
        let widths: [Double] = [6, 78, 90, 60, 154, 94, 78]
        let fields = RecordStripField.allCases
        for (index, line) in input.presentation.lines.enumerated() {
            let frame = CGRect(x: 8, y: 6 + index * 24, width: 684, height: 24)
            var boxes: [RecordStripField: CGRect] = [:], x = frame.minX
            for (field, width) in zip(fields, widths) {
                boxes[field] = CGRect(x: x, y: frame.minY, width: width, height: frame.height); x += width + 4
            }
            rows.append(.init(id: line.id, frame: frame, fields: boxes))
            if line.working,let cell = boxes[.age] {
                cursors.append(.init(recordID:line.id,rect:CGRect(x:cell.maxX-5,y:cell.midY-5,width:5,height:10),visible:true,blinkDuration:1))
            }
            if input.selectedID == line.id || hover == .row(line.id) {
                commands.append(.fill(rect: frame, radius: 2, ink: .init(0.3, 0.5, 0.8, 0.2)))
            }
            commands.append(.fill(rect: CGRect(x: frame.minX, y: frame.minY + 8, width: 6, height: 8), radius: 1,
                                  ink: input.identities[line.id]?.vendorInk ?? muted))
            let text = RecordStripRowText(line: line, identity: input.identities[line.id], language: input.appearance.language)
            for (field, value) in [(RecordStripField.tool, text.tool), (.model, text.model), (.effort, text.effort), (.project, text.project), (.speed, text.speed), (.age, text.age)] {
                let box = boxes[field]!, font = try font(.init(size: 11))
                var shown = value
                func advance(_ value: String) -> Double {
                    CTLineGetTypographicBounds(CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: [.font: font])), nil, nil, nil)
                }
                if advance(shown) > box.width {
                    while !shown.isEmpty && advance(shown + "…") > box.width { shown.removeLast() }
                    shown += "…"
                }
                commands.append(.text(.init(id: "record.\(line.id).\(field.rawValue)", variants: [shown], rect: box,
                                           font: .init(size: 11), ink: field == .age ? muted : foreground,
                                           alignment: field == .speed || field == .age ? .right : .left)))
            }
        }
        let more = input.presentation.overflow > 0 ? CGRect(x: size.width - 80, y: size.height - 22, width: 72, height: 18) : nil
        if let more {
            if input.overflowSelected || hover == .more { commands.append(.fill(rect: more, radius: 2, ink: .init(0.3, 0.5, 0.8, 0.2))) }
            commands.append(.text(.init(id: "record.more", variants: ["+\(input.presentation.overflow) ›"], rect: more,
                                       font: .init(size: 11), ink: foreground, alignment: .right)))
        }
        return .init(drawing: .init(size: size, commands: commands, regions: [], focusInk: .init(0.3, 0.6, 1)), rows: rows, more: more, cursors:cursors)
    }
}
