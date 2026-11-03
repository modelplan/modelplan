// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanAppIntegration

final class M5CreditsDisplayFormatTests: XCTestCase {
    func testOnlyAbsentValuesAreMissing() {
        for unit in [M5CreditsDisplayFormat.Unit.credits, .init(identifier: "money", currencyIdentifier: "USD"), .init(identifier: nil)] {
            XCTAssertEqual(M5CreditsDisplayFormat.text(nil, unit: unit), .missing)
        }
        XCTAssertEqual(M5CreditsDisplayFormat.text(0, unit: .credits), .formatted("0"))
        XCTAssertEqual(M5CreditsDisplayFormat.text(-0.0, unit: .credits), .formatted("0"))
        XCTAssertEqual(M5CreditsDisplayFormat.text(-1_500, unit: .credits), .formatted("-1500"))
        XCTAssertEqual(M5CreditsDisplayFormat.text(999, unit: .credits), .formatted("999"))
        XCTAssertEqual(M5CreditsDisplayFormat.text(1_000, unit: .credits), .formatted("1k"))
    }

    func testThousandsRoundingAndMillionBoundary() {
        XCTAssertEqual(M5CreditsDisplayFormat.text(1_499, unit: .credits), .formatted("1k"))
        XCTAssertEqual(M5CreditsDisplayFormat.text(1_500, unit: .credits), .formatted("2k"))
        XCTAssertEqual(M5CreditsDisplayFormat.text(999_499, unit: .credits), .formatted("999k"))
        XCTAssertEqual(M5CreditsDisplayFormat.text(999_500, unit: .credits), .formatted("1000k"))
        XCTAssertEqual(M5CreditsDisplayFormat.text(1_000_000, unit: .credits), .formatted("1.0M"))
        XCTAssertEqual(M5CreditsDisplayFormat.text(1_150_000, unit: .credits), .formatted("1.1M"))
        XCTAssertEqual(M5CreditsDisplayFormat.text(1_250_000, unit: .credits), .formatted("1.3M"))
        XCTAssertEqual(M5CreditsDisplayFormat.text(Double(1_150_000).nextDown, unit: .credits), .formatted("1.1M"))
        XCTAssertEqual(M5CreditsDisplayFormat.text(Double(1_150_000).nextUp, unit: .credits), .formatted("1.2M"))
    }

    func testUnapprovedFiniteCreditsPreserveTheOriginalValueAndUnit() {
        for value in [0.123456789, 999.5, -1.5, -1e21, 1e21, Double.greatestFiniteMagnitude] {
            XCTAssertEqual(M5CreditsDisplayFormat.text(value, unit: .credits), .fallback(value: value, unit: .credits))
        }
    }

    func testCurrencyAndUnknownUnitPreserveTheOriginalValueAndUnit() {
        let usd = M5CreditsDisplayFormat.Unit(identifier: "money", currencyIdentifier: "USD")
        let eur = M5CreditsDisplayFormat.Unit(identifier: "money", currencyIdentifier: "EUR")
        let tokens = M5CreditsDisplayFormat.Unit(identifier: "tokens")
        let requests = M5CreditsDisplayFormat.Unit(identifier: "requests")
        let units = [usd, eur, tokens, requests, .init(identifier: nil), .init(identifier: "credits", currencyIdentifier: "USD")]
        // Before this contract, distinct USD/EUR and unknown units collapsed to the same result.
        XCTAssertNotEqual(M5CreditsDisplayFormat.text(4.5, unit: usd), M5CreditsDisplayFormat.text(4.5, unit: eur))
        XCTAssertNotEqual(M5CreditsDisplayFormat.text(4.5, unit: tokens), M5CreditsDisplayFormat.text(4.5, unit: requests))
        for unit in units {
            for value in [0.0, 4.5, 999.5, 1_500, 1_000_000, Double.greatestFiniteMagnitude] {
                XCTAssertEqual(M5CreditsDisplayFormat.text(value, unit: unit), .fallback(value: value, unit: unit))
            }
        }
        guard case .fallback(let value, let unit) = M5CreditsDisplayFormat.text(-0.0, unit: usd) else {
            return XCTFail("a signed zero with a currency must retain the original fact")
        }
        XCTAssertEqual(value.sign, .minus)
        XCTAssertEqual(unit, usd)
    }

    func testNonFiniteValuesAreInvalidNotMissing() {
        for unit in [M5CreditsDisplayFormat.Unit.credits, .init(identifier: "money", currencyIdentifier: "EUR"), .init(identifier: "tokens")] {
            for value in [Double.nan, Double.infinity, -Double.infinity] {
                XCTAssertEqual(M5CreditsDisplayFormat.text(value, unit: unit), .invalid(unit: unit))
            }
        }
    }

    func testUnknownUnitExactValuesAndIdentity() {
        let units = [M5CreditsDisplayFormat.Unit(identifier: nil), .init(identifier: ""),
                     .init(identifier: "other"), .init(identifier: "SYNTHETIC-UNIT-CANARY")]
        for unit in units {
            for (value, text) in [(0.0, "0"), (1.0, "1"), (0.1, "0.1"), (1.1, "1.1"),
                                  (3.25, "3.25"), (47.25, "47.25"), (-42.5, "-42.5")] {
                XCTAssertEqual(M5CreditsDisplayFormat.unknownUnitText(value, unit: unit, knowledge: .unknown),
                               .rendered(value: value, unit: unit, text: text, isApproximate: false))
            }
            guard case .rendered(let raw, let returnedUnit, let text, let approximate) =
                    M5CreditsDisplayFormat.unknownUnitText(-0.0, unit: unit, knowledge: .unknown) else {
                XCTFail("negative zero must remain a reported value"); continue
            }
            XCTAssertEqual(raw.bitPattern, (-0.0 as Double).bitPattern)
            XCTAssertEqual(returnedUnit, unit); XCTAssertEqual(text, "0"); XCTAssertFalse(approximate)
        }
    }

    func testUnknownUnitApproximationOnlyWhenDisplayedValueChanges() {
        let unit = M5CreditsDisplayFormat.Unit(identifier: "other")
        for (value, text) in [(247.538, "≈247.54"), (84.996, "≈85"),
                              (0.004, "≈0"), (0.30000000000000004, "≈0.3")] {
            XCTAssertEqual(M5CreditsDisplayFormat.unknownUnitText(value, unit: unit, knowledge: .unknown),
                           .rendered(value: value, unit: unit, text: text, isApproximate: true))
        }
        // Halfway rounding direction is not specified here; either result must be marked approximate.
        for value in [0.005, 1.005, -0.005] {
            guard case .rendered(let original, let returnedUnit, let text, let approximate) =
                    M5CreditsDisplayFormat.unknownUnitText(value, unit: unit, knowledge: .unknown) else {
                XCTFail("a finite midpoint must retain its source value"); continue
            }
            XCTAssertEqual(original.bitPattern, value.bitPattern); XCTAssertEqual(returnedUnit, unit)
            XCTAssertTrue(approximate); XCTAssertTrue(text.hasPrefix("≈"))
        }
    }

    func testUnknownUnitMissingNonFiniteAndLargeValuePreserveFacts() {
        let unit = M5CreditsDisplayFormat.Unit(identifier: "")
        XCTAssertEqual(M5CreditsDisplayFormat.unknownUnitText(nil, unit: unit, knowledge: .unknown), .missing(unit: unit))
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertEqual(M5CreditsDisplayFormat.unknownUnitText(value, unit: unit, knowledge: .unknown),
                           .invalid(bits: value.bitPattern, unit: unit))
        }
        let boundary = 1_000_000_000_000_000.0
        XCTAssertEqual(M5CreditsDisplayFormat.unknownUnitText(boundary, unit: unit, knowledge: .unknown),
                       .rendered(value: boundary, unit: unit, text: "1000000000000000", isApproximate: false))
        let huge = Double.greatestFiniteMagnitude
        switch M5CreditsDisplayFormat.unknownUnitText(huge, unit: unit, knowledge: .unknown) {
        case .rendered(let original, let returnedUnit, let text, let approximate):
            XCTAssertEqual(original.bitPattern, huge.bitPattern); XCTAssertEqual(returnedUnit, unit)
            XCTAssertFalse(approximate); XCTAssertEqual(Double(text), huge)
        case .fallback(let original, let returnedUnit):
            XCTAssertEqual(original.bitPattern, huge.bitPattern); XCTAssertEqual(returnedUnit, unit)
        default: XCTFail("finite values must not become missing or invalid")
        }
    }

    func testUnknownUnitFormatterDoesNotApplyToCreditsOrMoney() {
        for unit in [M5CreditsDisplayFormat.Unit.credits, .init(identifier: "money"),
                     .init(identifier: "other", currencyIdentifier: "USD")] {
            XCTAssertEqual(M5CreditsDisplayFormat.unknownUnitText(12.34, unit: unit, knowledge: .unknown),
                           .notApplicable(value: 12.34, unit: unit))
            XCTAssertEqual(M5CreditsDisplayFormat.unknownUnitText(nil, unit: unit, knowledge: .unknown),
                           .notApplicable(value: nil, unit: unit))
        }
        let known = M5CreditsDisplayFormat.Unit(identifier: "requests")
        XCTAssertEqual(M5CreditsDisplayFormat.unknownUnitText(12.34, unit: known, knowledge: .known),
                       .notApplicable(value: 12.34, unit: known))
    }
}
