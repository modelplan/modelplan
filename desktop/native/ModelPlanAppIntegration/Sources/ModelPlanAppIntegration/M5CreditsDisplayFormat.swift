// SPDX-License-Identifier: MIT
import Foundation

/// Display-only formatting for reported credits; underlying values are unchanged.
enum M5CreditsDisplayFormat {
    struct Unit: Equatable {
        /// Preserve the wire unit and any independently reported currency verbatim.
        let identifier: String?
        let currencyIdentifier: String?

        init(identifier: String?, currencyIdentifier: String? = nil) {
            self.identifier = identifier
            self.currencyIdentifier = currencyIdentifier
        }
        static let credits = Unit(identifier: "credits")
    }
    enum Result: Equatable {
        case missing
        case formatted(String)
        /// Preserve the finite value and unit; the caller must not treat this as missing.
        case fallback(value: Double, unit: Unit)
        /// A non-finite number is present but cannot be shown as a real balance.
        case invalid(unit: Unit)
    }

    /// A separate presentation for balances whose unit is not known.
    /// Every case keeps the unit; finite values are retained exactly as supplied.
    enum NeutralResult: Equatable {
        case missing(unit: Unit)
        case invalid(bits: UInt64, unit: Unit)
        case notApplicable(value: Double?, unit: Unit)
        case fallback(value: Double, unit: Unit)
        case rendered(value: Double, unit: Unit, text: String, isApproximate: Bool)
    }

    enum UnitKnowledge: Equatable { case known, unknown }

    private static func integerText(_ value: Double, english: Bool) -> String? {
        guard value.isFinite, value >= 0 else { return nil }
        if value == 0 { return "0" }
        if value < 1 { return "<1" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: english ? "en_US" : "zh_CN")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.maximumIntegerDigits = 309
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value.rounded(.toNearestOrAwayFromZero)))
    }

    static func unknownUnitText(_ value: Double?, unit: Unit, knowledge: UnitKnowledge, english: Bool = true) -> NeutralResult {
        // The caller must establish that the unit is unknown; raw identifiers are not classified here.
        // Credits and money, or any explicitly identified currency, keep their own policies.
        guard knowledge == .unknown, unit.identifier != "credits", unit.identifier != "money", unit.currencyIdentifier == nil else {
            return .notApplicable(value: value, unit: unit)
        }
        guard let value else { return .missing(unit: unit) }
        guard value.isFinite else { return .invalid(bits: value.bitPattern, unit: unit) }
        guard let text = integerText(value, english: english) else { return .fallback(value: value, unit: unit) }
        return .rendered(value: value, unit: unit, text: text, isApproximate: value > 0 && (value < 1 || value != value.rounded(.toNearestOrAwayFromZero)))
    }

    static func text(_ value: Double?, unit: Unit, english: Bool = true) -> Result {
        guard let value else { return .missing }
        guard value.isFinite else { return .invalid(unit: unit) }
        guard unit == .credits else { return .fallback(value: value, unit: unit) }
        if value < 0 {
            // Retain the prior non-production negative fallback behaviour.
            guard value > -1_000_000_000_000_000, value.rounded(.towardZero) == value else { return .fallback(value: value, unit: unit) }
            return .formatted(String(Int(value)))
        }
        guard let text = integerText(value, english: english) else { return .fallback(value: value, unit: unit) }
        return .formatted(text)
    }
}
