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
