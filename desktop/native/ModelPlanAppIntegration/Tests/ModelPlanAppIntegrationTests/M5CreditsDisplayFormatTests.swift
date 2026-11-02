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
}
