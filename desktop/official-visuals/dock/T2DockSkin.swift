// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import CoreGraphics
import Foundation
import ModelPlanDock

/// Translates the accepted geometry and checked resource names into the generic
/// renderer's data-only skin. All coordinates remain in study space.
public enum T2DockSkin {
    public static func make(geometry g: T2Geometry, rows: [DockInstrumentReading], showsPercentages: Bool) throws -> DockInstrumentSkin {
        let d = g.input.diameter, unit = d / 52
        let bounds = g.outline.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
            .union(g.ignitionBounds.insetBy(dx: -4 * unit, dy: -4 * unit)).integral
        guard !bounds.isNull, !bounds.isEmpty else { throw T2Geometry.InputError.invalidGeometry }
        func rect(_ r: CGRect) -> [[CGFloat]] { [[r.minX, r.minY], [r.width, r.height]] }
        func box(_ p: CGPoint, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: p.x-w/2,y:p.y-h/2,width:w,height:h) }
        let names = ["a1-01-bell-wall", "a1-03-deep-centre", "a1-02-throat-lip", "a1-04-exit-lip"]
        let sourceSize = d <= 44 ? 44 : 52
        let layers = names.map { "\($0)-\(sourceSize)px@3x.webp" }
        let available = Dictionary(uniqueKeysWithValues: rows.map { ($0.subscriptionID, $0) })
        let logos = ["openai":"logo-openai", "claude":"logo-claude", "cursor":"logo-cursor", "copilot":"logo-copilot", "kimi":"logo-kimi", "opencode":"logo-opencode"]
        let outerWidth = d * 0.058, innerWidth = d * 0.031
        let outerRadius = d/2 - 1 - outerWidth/2
        let innerRadius = outerRadius - outerWidth/2 - 2 - innerWidth/2
        // dock-view renders the source nozzle at 52 and scales it as a unit.
        let clockRadius = (52.0/2 + 2.2) * unit
        let clockDots = max(24, Int((2 * CGFloat.pi * (52.0/2 + 2.2) / 4.8).rounded()))
        var stations = [[String: Any]]()
        for station in g.stations {
            var recipe: [String: Any] = [
                "centre": [station.centre.x, station.centre.y], "diameter": d,
                "logicalPoints": Int(d), "readout": rect(box(station.readoutCentre, 56*unit, 16*unit)),
                "eventRect": rect(box(CGPoint(x:station.readoutCentre.x+22*unit,y:station.readoutCentre.y), 12*unit, 12*unit)),
                "glyphRect": rect(box(station.centre, d*0.27, d*0.27)), "layers": layers, "glyphs": logos,
                "outer": ["radius":outerRadius,"width":outerWidth,"minimumVisibleFraction":1.0/60,"opacity":1.0,"trackOpacity":1.0],
                "inner": ["radius":innerRadius,"width":innerWidth,"minimumVisibleFraction":1.0/60,"opacity":0.85,"trackOpacity":0.65],
                "clock": ["radius":clockRadius,"dotRadius":0.65*unit,"backWidth":1.5*unit,"positions":clockDots],
                "notchWidth":d*0.014,"caseInnerRadius":max(0,innerRadius-innerWidth/2-1),
                "showsReadout":showsPercentages, "fallbackVendorName":true
            ]
            if let id=station.subscription?.id, let reading=available[id] {
                recipe["subscriptionID"] = id
                if let alias=reading.alias, !alias.isEmpty { recipe["aliasRect"] = rect(box(CGPoint(x:station.readoutCentre.x,y:station.readoutCentre.y-12*unit),56*unit,12*unit)) }
            } else if station.isOverflow { recipe["overflowCount"] = g.overflow.count }
            else if station.isEmpty { recipe["placeholderLabel"] = "+" }
            stations.append(recipe)
        }
        let button = g.button, guardSize=34*unit
        let fixed: [[String: Any]] = [
            ["resource":"a5-outer-contact-shadow-56x56@3x.png", "rect":rect(box(button,guardSize*56/52,guardSize*56/52)), "opacity":0.30],
            ["resource":"a5-cap-night-idle-44x44@3x.png", "rect":rect(box(button,guardSize*44/52,guardSize*44/52))],
            ["resource":"a5-inner-contact-shadow-52x52@3x.png", "rect":rect(box(button,guardSize,guardSize)), "opacity":0.33],
            ["resource":"a5-recessed-guard-52x52@3x.png", "rect":rect(box(button,guardSize,guardSize))]
        ]
        func ink(_ r: Double,_ g: Double,_ b: Double,_ a: Double=1) -> [String:Double] { ["r":r/255,"g":g/255,"b":b/255,"a":a] }
        let palette: [String: [String: Double]] = ["body":ink(16,19,24),"case":ink(5,6,8),"track":ink(255,255,255,28/255),"notch":ink(14,17,22),"normal":ink(90,217,186),"warning":ink(234,193,123),"critical":ink(239,68,68),"unknown":ink(125,134,142),"clock":ink(255,255,255,0.6),"clockBack":ink(5,6,8,0.55),"text":ink(255,255,255),"lcdWhite":ink(233,237,240),"alias":ink(230,233,235),"noticeBlue":ink(159,210,255),"noticeAmber":ink(234,193,123),"noticeWhite":ink(255,255,255)]
        let text: [String: Any] = ["fontResource":"font-jetbrains-mono","size":11*unit,"weight":400]
        let alias: [String: Any] = ["useSystemUIFont":true,"size":10*unit,"weight":400]
        let object: [String: Any] = ["schemaVersion":1,"bounds":rect(bounds),"bodyPolygon":g.outline.map{[$0.x,$0.y]},"fixedLayers":fixed,"stations":stations,"palette":palette,"text":text,"aliasText":alias,"readoutPalette":["normal":"lcdWhite"]]
        return try JSONDecoder().decode(DockInstrumentSkin.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
