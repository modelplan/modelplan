// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

final class EffortTests: XCTestCase {
    func comparison(_ current: EffortConfiguration?, _ trial: EffortConfiguration, rec: String = "medium", tier: InstrumentFastTier? = nil) -> EffortComparison {
        .init(model: Fixtures.model(current: current, rec: rec, tier: tier), trial: trial, publicationUsable: true)
    }

    func testF07CurrentIsReferenceForTableAndChart() throws {
        let cmp = comparison(.init("high"), .init("max"))
        XCTAssertEqual(cmp.panels.map(\.light), [.white, .blue, .gold])
        let current = try XCTUnwrap(cmp.panels[0].values), trial = try XCTUnwrap(cmp.panels[1].values)
        XCTAssertEqual(current.costRatio, 1); XCTAssertEqual(current.timeRatio, 1); XCTAssertEqual(current.abilityRatio, 1)
        XCTAssertEqual(trial.costRatio!, 2.8, accuracy: 1e-12)
        XCTAssertEqual(trial.timeRatio, 1.5); XCTAssertEqual(trial.abilityDelta, 15); XCTAssertEqual(trial.abilityRatio, 1.25)
        for panel in cmp.panels {
            XCTAssertEqual(cmp.profiles.first { $0.configuration == panel.configuration }?.values, panel.values)
        }
        XCTAssertEqual(cmp.panels[2].values?.costRatio, 2.0 / 3.0)
    }

    func testF07EqualityBacklightMatrixAndNoDuplicateProfile() {
        let cases: [(String, String, [ComparisonLight], Int)] = [
            ("high", "high", [.white, .off, .gold], 2),
            ("high", "medium", [.white, .gold, .gold], 2),
            ("medium", "high", [.gold, .blue, .gold], 2),
            ("medium", "medium", [.gold, .off, .gold], 1),
        ]
        for (current, trial, lights, count) in cases {
            let cmp = comparison(.init(current), .init(trial))
            XCTAssertEqual(cmp.panels.map(\.role), [.current, .trial, .recommended])
            XCTAssertEqual(cmp.panels.map(\.light), lights)
            XCTAssertEqual(cmp.profiles.count, count)
            if current == trial {
                XCTAssertNil(cmp.panels[1].values); XCTAssertNil(cmp.panels[1].label)
                XCTAssertTrue(cmp.panels[1].equalsCurrent)
            }
        }
        let all = comparison(.init("medium"), .init("medium"))
        XCTAssertEqual(all.profiles[0].roles, [.current, .recommended])
    }

    func testF06UnknownCurrentNeverNormalizesAgainstRecommendation() {
        for current in [nil, EffortConfiguration("missing")] {
            let cmp = comparison(current, .init("max"))
            XCTAssertEqual(cmp.panels[0].light, .dim); XCTAssertNil(cmp.panels[0].values)
            XCTAssertNil(cmp.panels[1].values?.costRatio); XCTAssertNil(cmp.panels[1].values?.abilityDelta)
            XCTAssertNil(cmp.panels[2].values?.timeRatio); XCTAssertTrue(cmp.profiles.isEmpty)
        }
    }

    func testF07FastIncludedInIdentityCostAndTaskTime() {
        let tier = InstrumentFastTier(costMultiplier: 6, speedMultiplier: 2, taskTimeUnknown: false, qualifier: "Published availability")
        let cmp = comparison(.init("high", fast: true), .init("high"), rec: "high", tier: tier)
        XCTAssertEqual(cmp.panels.map(\.light), [.white, .gold, .gold])
        XCTAssertEqual(cmp.panels[1].values?.costRatio, 1.0 / 6)
        XCTAssertEqual(cmp.panels[1].values?.timeRatio, 2)
        XCTAssertEqual(cmp.panels[1].values?.abilityRatio, 1)
        XCTAssertEqual(cmp.fastQualifier, "Published availability")
        let same = comparison(.init("high", fast: true), .init("high", fast: true), tier: tier)
        XCTAssertEqual(same.panels[1].light, .off)
        let noTime = InstrumentFastTier(costMultiplier: 6, speedMultiplier: 2, taskTimeUnknown: true)
        XCTAssertNil(comparison(.init("high"), .init("high", fast: true), tier: noTime).panels[1].values?.timeRatio)
    }

    func testF07MissingTierDoesNotSilentlyConvertFastToStandard() {
        let cmp = comparison(.init("high"), .init("high", fast: true))
        XCTAssertFalse(cmp.fastAvailable); XCTAssertEqual(cmp.panels[1].light, .dim)
        XCTAssertNil(cmp.panels[1].configuration)
        for tier in [InstrumentFastTier(costMultiplier: nil, speedMultiplier: 2, taskTimeUnknown: true),
                     .init(costMultiplier: 6, speedMultiplier: 0, taskTimeUnknown: false)] {
            let invalid = comparison(.init("high"), .init("high", fast: true), tier: tier)
            XCTAssertFalse(invalid.fastAvailable); XCTAssertNil(invalid.panels[1].configuration)
        }
    }

    func testF18PublicationMismatchWithholdsAllScoredValues() {
        let cmp = EffortComparison(model: Fixtures.model(), trial: .init("max"), publicationUsable: false)
        XCTAssertTrue(cmp.panels.allSatisfy { $0.values == nil && $0.configuration == nil })
        XCTAssertTrue(cmp.profiles.isEmpty); XCTAssertFalse(cmp.fastAvailable)
        let lcd = FaderLCD(model: Fixtures.model(), trial: .init("max"), publicationUsable: false, language: .chinese, compact: false)
        XCTAssertEqual(lcd.state, "--"); XCTAssertNil(lcd.multiple)
    }

    func testF06MissingAndIncompatibleMetricsAndZeroDenominator() {
        let efforts = [
            InstrumentEffort(key: "a", label: "A", ability: .init(0, basis: "a"), cost: .init(0, basis: "cost"), time: .init(nil, basis: "t")),
            InstrumentEffort(key: "b", label: "B", ability: .init(4, basis: "different"), cost: .init(8, basis: "cost"), time: .init(9, basis: "t")),
        ]
        let cmp = EffortComparison(model: Fixtures.model(current: .init("a"), rec: "b", efforts: efforts), trial: .init("b"), publicationUsable: true)
        XCTAssertNil(cmp.panels[1].values?.abilityDelta); XCTAssertNil(cmp.panels[1].values?.abilityRatio)
        XCTAssertNil(cmp.panels[1].values?.costRatio); XCTAssertNil(cmp.panels[1].values?.timeRatio)
        XCTAssertNil(PublishedMetric(.infinity, basis: "a").value)
    }

    func testF06LCDHasDifferentNormalAndTrialCostBases() {
        let model = Fixtures.model()
        let normal = FaderLCD(model: model, trial: nil, publicationUsable: true, language: .chinese, compact: false)
        XCTAssertEqual(normal.state, "High"); XCTAssertEqual(normal.recommendation, "★Med")
        XCTAssertEqual(normal.multiple, "×1.5"); XCTAssertEqual(normal.costBasis, .currentOverRecommended)
        let trial = FaderLCD(model: model, trial: .init("max"), publicationUsable: true, language: .chinese, compact: false)
        XCTAssertEqual(trial.state, "试 Max"); XCTAssertEqual(trial.multiple, "×2.8")
        XCTAssertEqual(trial.costBasis, .trialOverCurrent)
        for key in ["high", "medium"] {
            let equal = FaderLCD(model: model, trial: .init(key), publicationUsable: true, language: .chinese, compact: false)
            XCTAssertNil(equal.multiple)
            XCTAssertEqual(equal.state, key == "high" ? "试 = 当前" : "试 = ★")
        }
        let star = FaderLCD(model: Fixtures.model(current: .init("medium")), trial: nil, publicationUsable: true, language: .english, compact: false)
        XCTAssertEqual(star.state, "★Med"); XCTAssertNil(star.multiple)
    }

    func testF06LCDCompactRulesAndTwoSignificantDigits() {
        let en = FaderLCD(model: Fixtures.model(), trial: .init("max"), publicationUsable: true, language: .english, compact: true)
        XCTAssertNil(en.multiple)
        let zh = FaderLCD(model: Fixtures.model(), trial: .init("max"), publicationUsable: true, language: .chinese, compact: true)
        XCTAssertEqual(zh.multiple, "×2.8")
        let longRec = FaderLCD(model: Fixtures.model(current: .init("low"), rec: "high"), trial: nil, publicationUsable: true, language: .english, compact: true)
        XCTAssertNil(longRec.multiple)
        let fmt = InstrumentFormat(.english)
        for (value, expected) in [(1.0, "×1"), (1.534, "×1.5"), (12.89, "×13"), (0.00734, "×0.0073"), (0, "×0")] {
            XCTAssertEqual(fmt.costMultiple(value), expected)
        }
        XCTAssertNil(fmt.costMultiple(.nan)); XCTAssertNil(fmt.costMultiple(-1))
    }

    func testF04F06OnePerModelAndNativeLaddersRemainUnchanged() {
        let six = (0..<6).map { InstrumentEffort(key: "e\($0)", label: "E\($0)", ability: Fixtures.metric(Double($0)), cost: Fixtures.metric(1), time: Fixtures.metric(nil)) }
        let single = Fixtures.model(current: nil, rec: "e0", efforts: [six[0]], id: "single")
        let many = Fixtures.model(rec: "e2", efforts: six, id: "many")
        let bank = FaderBank(models: [single, single, many], bank: 0)
        XCTAssertEqual(bank.count, 1); XCTAssertEqual(bank.models.compactMap { $0?.id }, ["single", "many"])
        XCTAssertEqual(bank.models[0]?.efforts.count, 1); XCTAssertEqual(bank.models[1]?.efforts.map(\.key), six.map(\.key))
        XCTAssertNil(FaderLCD(model: single, trial: nil, publicationUsable: true, language: .chinese, compact: false).multiple)
    }
}
