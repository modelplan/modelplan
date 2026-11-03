// SPDX-License-Identifier: MIT
import Foundation

/// An unwired presentation experiment for reported credits, not a data conversion.
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

    /// A separate, unwired presentation for balances whose unit is not known.
    /// Every case keeps the unit; finite values are retained exactly as supplied.
    enum NeutralResult: Equatable {
        case missing(unit: Unit)
        case invalid(bits: UInt64, unit: Unit)
        case notApplicable(value: Double?, unit: Unit)
        case fallback(value: Double, unit: Unit)
        case rendered(value: Double, unit: Unit, text: String, isApproximate: Bool)
    }

    enum UnitKnowledge: Equatable { case known, unknown }

    static func unknownUnitText(_ value: Double?, unit: Unit, knowledge: UnitKnowledge) -> NeutralResult {
        // The caller must establish that the unit is unknown; raw identifiers are not classified here.
        // Credits and money, or any explicitly identified currency, keep their own policies.
        guard knowledge == .unknown, unit.identifier != "credits", unit.identifier != "money", unit.currencyIdentifier == nil else {
            return .notApplicable(value: value, unit: unit)
        }
        guard let value else { return .missing(unit: unit) }
        guard value.isFinite else { return .invalid(bits: value.bitPattern, unit: unit) }
        if value == 0 { return .rendered(value: value, unit: unit, text: "0", isApproximate: false) }

        // Match existing project numeric formatting: POSIX decimal, no invented unit or currency.
        var number = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
        // Do not guess if formatting or parsing cannot preserve a finite numeric result.
        guard number.utf8.count <= 400,
              number.utf8.allSatisfy({ (48...57).contains($0) || $0 == 45 || $0 == 46 }),
              number.contains(".") else { return .fallback(value: value, unit: unit) }
        while number.last == "0" { number.removeLast() }
        if number.last == "." { number.removeLast() }
        guard let displayed = Double(number), displayed.isFinite else { return .fallback(value: value, unit: unit) }
        // Compare representable values rather than multiplying the Double by 100:
        // e.g. the formatted decimal 0.1 decodes to the same Double as the input.
        let approximate = displayed != value
        return .rendered(value: value, unit: unit, text: (approximate ? "≈" : "") + number, isApproximate: approximate)
    }

    static func text(_ value: Double?, unit: Unit) -> Result {
        guard let value else { return .missing }
        guard value.isFinite else { return .invalid(unit: unit) }
        guard unit == .credits else { return .fallback(value: value, unit: unit) }
        if value < 1_000 {
            // Fractional values and unbounded negative values need a display policy.
            guard value > -1_000_000_000_000_000, value.rounded(.towardZero) == value else { return .fallback(value: value, unit: unit) }
            return .formatted(String(Int(value)))
        }
        if value < 1_000_000 {
            return .formatted(String(Int((value / 1_000).rounded(.toNearestOrAwayFromZero))) + "k")
        }
        let millions = value / 1_000_000
        // Above this bound, leave number-to-string and overflow policy undecided.
        guard millions < 1_000_000_000_000_000 else { return .fallback(value: value, unit: unit) }
        // Round the exact binary value to one decimal, without rounding the
        // intermediate multiplication by 10. This preserves the 1.15 case.
        let bits = millions.bitPattern
        let exponent = Int((bits >> 52) & 0x7ff) - 1023 - 52
        let numerator = ((bits & ((UInt64(1) << 52) - 1)) | (UInt64(1) << 52)) * 10
        let shift = -exponent
        guard (1...63).contains(shift) else { return .fallback(value: value, unit: unit) }
        var tenths = numerator >> shift
        let remainder = numerator & ((UInt64(1) << shift) - 1)
        if remainder >= UInt64(1) << (shift - 1) { tenths += 1 }
        return .formatted("\(tenths / 10).\(tenths % 10)M")
    }
}
