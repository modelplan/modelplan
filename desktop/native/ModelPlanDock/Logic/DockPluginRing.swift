// SPDX-License-Identifier: MIT
import Foundation

/// A plugin's ring on the widget (D163, D236, D327), drawn in the subscription ring's place and size.
/// The outer arc is `outer` (solid) followed by `outerFaint` (the same ink, faint); the inner thin arc is `inner`.
/// The ring is always drawn in the plugin's own ink: it never takes a quota status colour. Only the readout's
/// number carries a tone (`readoutTone`). The hover card uses `cardRows` instead of quota windows.
public struct DockPluginRing: Equatable, Sendable {
    /// sRGB 0–1. The resource plugin is orchid #da66c2.
    public var red: Double, green: Double, blue: Double
    public var outer: Double, outerFaint: Double, inner: Double?
    public var readout: String, readoutTone: DockQuotaStatus
    /// False under Reduce Motion.
    public var animates: Bool
    public var cardRows: [DockCardRow]
    public var cardFooter: String
    public init(red: Double, green: Double, blue: Double, outer: Double, outerFaint: Double = 0, inner: Double?,
                readout: String, readoutTone: DockQuotaStatus = .normal, animates: Bool = true,
                cardRows: [DockCardRow] = [], cardFooter: String = "") {
        self.red = red; self.green = green; self.blue = blue; self.outer = outer; self.outerFaint = outerFaint; self.inner = inner
        self.readout = readout; self.readoutTone = readoutTone; self.animates = animates; self.cardRows = cardRows; self.cardFooter = cardFooter
    }
    /// "#rrggbb".
    public init?(hex: String, outer: Double, outerFaint: Double = 0, inner: Double?, readout: String,
                 readoutTone: DockQuotaStatus = .normal, animates: Bool = true, cardRows: [DockCardRow] = [], cardFooter: String = "") {
        guard hex.count == 7, hex.first == "#", let v = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255,
                  outer: outer, outerFaint: outerFaint, inner: inner, readout: readout, readoutTone: readoutTone,
                  animates: animates, cardRows: cardRows, cardFooter: cardFooter)
    }
    public var valid: Bool {
        let unit: (Double) -> Bool = { $0.isFinite && (0...1).contains($0) }
        return [red, green, blue, outer, outerFaint].allSatisfy(unit) && (inner.map(unit) ?? true) && outer + outerFaint <= 1 + 1e-9 &&
            !readout.isEmpty && readout.utf8.count <= 64 && cardRows.count <= 8
    }
}

/// How a plugin card row is drawn (D327 variant A): the matched row's label and number at full ink (`emphasised`),
/// the others at secondary ink; no background for the emphasis. `tinted` (a problem row) is the only background.
/// The bar takes the plugin ink, never a status colour; an amber or red number keeps its tone.
public struct DockCardPluginStyle: Equatable, Sendable {
    public var red: Double, green: Double, blue: Double
    /// The faint segment after the fill (memory: cached).
    public var faintFill: Double?
    /// A warning notch on the bar (CPU 70 %, disk 90 %).
    public var notch: Double?
    public var tinted: Bool
    public init(red: Double, green: Double, blue: Double, faintFill: Double? = nil, notch: Double? = nil, tinted: Bool = false) {
        self.red = red; self.green = green; self.blue = blue; self.faintFill = faintFill; self.notch = notch; self.tinted = tinted
    }
}

public enum DockPluginRingProjection {
    /// The reading for a plugin input: arcs in the plugin ink with a fixed `.normal` status, readout tone from the
    /// plugin, no quota clock, no working signal.
    public static func reading(_ input: DockInstrumentInput, ring: DockPluginRing) throws -> DockInstrumentReading {
        guard !input.id.isEmpty, ring.valid else { throw DockLogicError.invalidCatalogue }
        let outer = DockQuotaArc(windowID: "plugin.outer", fraction: ring.outer, status: .normal, remainingFraction: nil)
        let inner = ring.inner.map { DockQuotaArc(windowID: "plugin.inner", fraction: $0, status: .normal, remainingFraction: nil) }
        var reading = DockInstrumentReading(subscriptionID: input.id, name: input.name, alias: nil, vendorResourceKey: input.vendorResourceKey,
            duplicateAccountTag: nil, outer: outer, inner: inner, selectedWindowID: nil, selectedWindowLabel: nil, selectedResetAt: nil,
            remainingPercent: nil, readout: ring.readout, status: ring.readoutTone, dataState: .fresh, unavailableReason: nil,
            timeLeftFraction: nil, isWorking: false, jetEligible: false)
        reading.pluginRing = ring
        return reading
    }
}
