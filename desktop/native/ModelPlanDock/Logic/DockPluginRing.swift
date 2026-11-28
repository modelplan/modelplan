// SPDX-License-Identifier: MIT
import Foundation

/// A plugin's ring on the widget (D163, D236, D327), drawn in the subscription ring's place and size.
/// The outer arc is `outer` (solid) followed by `outerFaint` (the same ink, faint); the inner thin arc is `inner`.
/// D371 B4c (owner 11-21): the arcs take the status colour of what they measure (normal / amber / red, the quota
/// rings' family): `outerTone` for the outer arc, `innerTone` for the inner one; the number carries `readoutTone`.
/// The hover card uses `cardRows` instead of quota windows.
public struct DockPluginRing: Equatable, Sendable {
    /// sRGB 0–1. The resource plugin is orchid #da66c2.
    public var red: Double, green: Double, blue: Double
    public var outer: Double, outerFaint: Double, inner: Double?
    /// D371: the status tone of each arc (the faint segment follows the outer one).
    public var outerTone: DockQuotaStatus, innerTone: DockQuotaStatus
    public var readout: String, readoutTone: DockQuotaStatus
    /// B4f (owner 11-21): what VoiceOver reads for the ring when the drawn readout is the number alone ("77%" is drawn,
    /// "内存 77%" is read). Empty = `readout`.
    public var spokenReadout: String
    /// The readout VoiceOver reads: `spokenReadout`, else the drawn `readout`.
    public var accessibilityReadout: String { spokenReadout.isEmpty ? readout : spokenReadout }
    /// False under Reduce Motion.
    public var animates: Bool
    public var cardRows: [DockCardRow]
    public var cardFooter: String
    /// The card's cockpit entry label (D371 B4e: "在驾驶舱查看"; the footer row opens the plugin's big screen); empty = none.
    public var cardAction: String
    /// D371 B4e: the card header's right-hand text (the sampling cadence, "每 10 秒"); empty = none.
    public var cardSource: String
    public init(red: Double, green: Double, blue: Double, outer: Double, outerFaint: Double = 0, inner: Double?,
                readout: String, readoutTone: DockQuotaStatus = .normal, animates: Bool = true,
                cardRows: [DockCardRow] = [], cardFooter: String = "", cardAction: String = "", spokenReadout: String = "",
                outerTone: DockQuotaStatus = .normal, innerTone: DockQuotaStatus = .normal, cardSource: String = "") {
        self.cardSource = cardSource
        self.outerTone = outerTone; self.innerTone = innerTone
        self.red = red; self.green = green; self.blue = blue; self.outer = outer; self.outerFaint = outerFaint; self.inner = inner
        self.readout = readout; self.readoutTone = readoutTone; self.animates = animates; self.cardRows = cardRows; self.cardFooter = cardFooter
        self.cardAction = cardAction; self.spokenReadout = spokenReadout
    }
    /// "#rrggbb".
    public init?(hex: String, outer: Double, outerFaint: Double = 0, inner: Double?, readout: String,
                 readoutTone: DockQuotaStatus = .normal, animates: Bool = true, cardRows: [DockCardRow] = [], cardFooter: String = "",
                 cardAction: String = "", spokenReadout: String = "", outerTone: DockQuotaStatus = .normal, innerTone: DockQuotaStatus = .normal, cardSource: String = "") {
        guard hex.count == 7, hex.first == "#", let v = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255,
                  outer: outer, outerFaint: outerFaint, inner: inner, readout: readout, readoutTone: readoutTone,
                  animates: animates, cardRows: cardRows, cardFooter: cardFooter, cardAction: cardAction, spokenReadout: spokenReadout,
                  outerTone: outerTone, innerTone: innerTone, cardSource: cardSource)
    }
    /// The live card (macrevb-1096-4): rows, footer and action from the latest sample, replacing the ones captured at
    /// the last ring redraw.
    public func withCard(_ card: DockPluginCard) -> DockPluginRing {
        var next = self; next.cardRows = card.rows; next.cardFooter = card.footer; next.cardAction = card.action; next.cardSource = card.source; return next
    }
    /// The readout split for drawing (D236, D327: only the number takes a tone): "CPU 96%" → label "CPU ", number "96%".
    /// A readout without a space is all number.
    public static func readoutParts(_ readout: String) -> (label: String, number: String) {
        guard let space = readout.lastIndex(of: " ") else { return ("", readout) }
        let cut = readout.index(after: space)
        return (String(readout[..<cut]), String(readout[cut...]))
    }
    public var valid: Bool {
        let unit: (Double) -> Bool = { $0.isFinite && (0...1).contains($0) }
        return [red, green, blue, outer, outerFaint].allSatisfy(unit) && (inner.map(unit) ?? true) && outer + outerFaint <= 1 + 1e-9 &&
            !readout.isEmpty && readout.utf8.count <= 64 && spokenReadout.utf8.count <= 64 && cardRows.count <= 8
    }
}

/// A plugin's hover card as it is now (macrevb-1096-4): the host reads it when the card is built, so the card never
/// waits for a ring redraw.
public struct DockPluginCard: Equatable, Sendable {
    public var rows: [DockCardRow]
    public var footer: String
    public var action: String
    /// D371 B4e: the header's right-hand text (the sampling cadence).
    public var source: String
    public init(rows: [DockCardRow], footer: String, action: String = "", source: String = "") { self.rows = rows; self.footer = footer; self.action = action; self.source = source }
}

/// How a plugin card row is drawn (D327 variant A): the matched row's label and number at full ink (`emphasised`),
/// the others at secondary ink; no background for the emphasis. `tinted` (a problem row) is the only background.
/// D371: the bar takes the row's status colour (normal / amber / red, `DockPluginStatusColour`), as does an amber or red number.
public struct DockCardPluginStyle: Equatable, Sendable {
    public var red: Double, green: Double, blue: Double
    /// The faint segment after the fill (memory: cached).
    public var faintFill: Double?
    public var tinted: Bool
    public init(red: Double, green: Double, blue: Double, faintFill: Double? = nil, tinted: Bool = false) {
        self.red = red; self.green = green; self.blue = blue; self.faintFill = faintFill; self.tinted = tinted
    }
}

/// D371 B4c: the status colours of a plugin's ring and bars where there is no skin palette (the neutral edition and the
/// card): the cockpit's `--st-ok #5ad9ba`, `--st-mid #eac17b`, `--st-low #ef4444` (prototype-theme.css).
public enum DockPluginStatusColour {
    /// sRGB 0–1.
    public static func rgb(_ tone: DockQuotaStatus) -> (red: Double, green: Double, blue: Double) {
        func c(_ v: UInt32) -> (red: Double, green: Double, blue: Double) { (Double((v >> 16) & 0xff) / 255, Double((v >> 8) & 0xff) / 255, Double(v & 0xff) / 255) }
        switch tone {
        case .warning: return c(0xeac17b)
        case .critical: return c(0xef4444)
        case .normal, .unknown: return c(0x5ad9ba)
        }
    }
}

public enum DockPluginRingProjection {
    /// The reading for a plugin input: arcs carry their own status tone (D371: the renderer draws it in the skin's
    /// normal / warning / critical ink, as a quota ring), readout tone from the plugin, no quota clock, no working signal.
    public static func reading(_ input: DockInstrumentInput, ring: DockPluginRing) throws -> DockInstrumentReading {
        guard !input.id.isEmpty, ring.valid else { throw DockLogicError.invalidCatalogue }
        let outer = DockQuotaArc(windowID: "plugin.outer", fraction: ring.outer, status: ring.outerTone, remainingFraction: nil)
        let inner = ring.inner.map { DockQuotaArc(windowID: "plugin.inner", fraction: $0, status: ring.innerTone, remainingFraction: nil) }
        var reading = DockInstrumentReading(subscriptionID: input.id, name: input.name, alias: nil, vendorResourceKey: input.vendorResourceKey,
            duplicateAccountTag: nil, outer: outer, inner: inner, selectedWindowID: nil, selectedWindowLabel: nil, selectedResetAt: nil,
            remainingPercent: nil, readout: ring.readout, status: ring.readoutTone, dataState: .fresh, unavailableReason: nil,
            timeLeftFraction: nil, isWorking: false, jetEligible: false)
        reading.pluginRing = ring
        return reading
    }
}
