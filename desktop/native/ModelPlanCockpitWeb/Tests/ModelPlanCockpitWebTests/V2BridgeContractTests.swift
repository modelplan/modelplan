// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

final class V2BridgeContractTests: XCTestCase {
    let source = CockpitMessageSource(mainFrame: true, origin: "modelplan-cockpit://bundle")
    let capabilities = ["appearanceUpdates", "shellState", "shellActions"]
    func state() throws -> CockpitBridgeState {
        CockpitBridgeState(context: try .init(sessionID: UUID(), storeEpoch: "synthetic-v2", generation: 1))
    }
    func encode(_ value: [String: Any]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
    }
    func receipt(_ load: String, version: Int? = 2, capabilities: [String]? = ["appearanceUpdates", "shellState", "shellActions"]) throws -> [String: Any] {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(load.utf8)) as? [String: Any])
        object["shell"] = nil; object["appearance"] = nil; object["redBelow"] = nil; object["type"] = "ready"; object["sequence"] = "1"
        object["appearanceVersion"] = version; object["capabilities"] = capabilities
        return object
    }
    func testFrozenLoadIncludesInitialClosedShellAndNativeTier() throws {
        let value = try state()
        let raw = try value.load(.init(theme: .night, locale: .en, profile: .compact, reduceMotion: true, reduceTransparency: true, shutterClosed: true, detached: true), shell: .init(closed: true, attached: false, forcedClosed: true, tier: .compact))
        let load = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        XCTAssertEqual(load["version"] as? Int, 2)
        let appearance = try XCTUnwrap(load["appearance"] as? [String: Any])
        XCTAssertEqual(Set(appearance.keys), ["theme","locale","reduceMotion","reduceTransparency"])
        let shell = try XCTUnwrap(load["shell"] as? [String: Any])
        XCTAssertEqual(Set(shell.keys), ["profile", "attached", "forcedClosed", "tier", "scope"])
        XCTAssertEqual(shell["profile"] as? String, "closed")
        XCTAssertEqual(shell["tier"] as? String, "compact")
        XCTAssertEqual(shell["forcedClosed"] as? Bool, true)
        XCTAssertEqual(shell["attached"] as? Bool, false)
    }
    func testCommittedThresholdIsEncodedOnLoadAndEachAppearanceUpdate() throws {
        for threshold in [10, 16, 20, 25] {
            let value = try state()
            let load = try value.load(.init(theme: .night, locale: .en, profile: .full, redBelow: threshold), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(load.utf8)) as? [String: Any])
            XCTAssertEqual(body["redBelow"] as? Int, threshold)
            _ = try value.accept(encode(receipt(load)), source: source)
            let next = threshold == 10 ? 16 : 10
            let update = try value.setAppearance(.init(theme: .night, locale: .en, profile: .full, redBelow: next))
            let message = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(update.utf8)) as? [String: Any])
            XCTAssertEqual(message["redBelow"] as? Int, next)
        }
        XCTAssertEqual(CockpitAppearance(theme: .night, locale: .en, profile: .full, redBelow: 17).redBelow, 25)
    }
    func testRequiresVersionTwoAndAllThreeCapabilitiesBeforeAnyQuery() throws {
        let value = try state(), load = try value.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
        XCTAssertEqual(try value.accept(encode(receipt(load)), source: source), .ready)
        XCTAssertNotNil(value.queryTicket)
    }
    func testVersionOneEnvelopeCannotClaimVersionTwoCapabilities() throws {
        let value = try state(), load = try value.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
        var legacy = try receipt(load); legacy["version"] = 1
        XCTAssertThrowsError(try value.accept(encode(legacy), source: source))
        XCTAssertFalse(value.ready); XCTAssertNil(value.queryTicket)
    }
    func testLegacyReadyMustStayBlockedInsteadOfReadOnlyFallback() throws {
        let value = try state(), load = try value.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
        XCTAssertThrowsError(try value.accept(encode(receipt(load, version: nil, capabilities: nil)), source: source))
        XCTAssertFalse(value.ready); XCTAssertNil(value.queryTicket)
    }
    func testMissingDuplicateUnknownAndOverlongCapabilitiesFailClosed() throws {
        for capabilities in [["appearanceUpdates", "shellState"], ["appearanceUpdates", "shellState", "shellState"], ["appearanceUpdates", "shellState", "unknown"], ["appearanceUpdates", "shellState", "shellActions", "extra"]] {
            let value = try state(), load = try value.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
            XCTAssertThrowsError(try value.accept(encode(receipt(load, capabilities: capabilities)), source: source))
            XCTAssertNil(value.queryTicket)
        }
        let value = try state(), load = try value.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
        var old = try receipt(load); old["appearanceVersion"] = 1
        XCTAssertThrowsError(try value.accept(encode(old), source: source))
        XCTAssertNil(value.queryTicket)
    }
    func testCapabilityArrayIsTheOnlyBoundedContainerAndDuplicateKeysStillFail() throws {
        XCTAssertThrowsError(try FlatReply.parse("{\"capabilities\":[[\"shellActions\"]]}"))
        XCTAssertThrowsError(try FlatReply.parse("{\"other\":[\"shellActions\"]}"))
        let value = try state(), load = try value.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
        let raw = try encode(receipt(load))
        XCTAssertThrowsError(try value.accept("{\"appearanceVersion\":2," + raw.dropFirst(), source: source))
        XCTAssertNil(value.queryTicket)
    }
    func testAppearanceAndShellHaveSeparateExactFieldsAndKeepQueryIdentity() throws {
        let value = try state(), load = try value.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
        _ = try value.accept(encode(receipt(load)), source: source)
        XCTAssertEqual(value.appearanceVersion, 2)
        XCTAssertEqual(value.readyCapabilities, Set(capabilities))
        let ticket = value.queryTicket
        let header: Set<String> = ["version","pageId","requestId","sessionId","storeEpoch","generation","viewRevision","sequence","type"]
        let appearanceRaw = try value.setAppearance(.init(theme: .night, locale: .zhCN, profile: .compact, reduceMotion: true, reduceTransparency: true))
        let appearance = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(appearanceRaw.utf8)) as? [String: Any])
        XCTAssertEqual(Set(appearance.keys), header.union(["theme","locale","reduceMotion","reduceTransparency","redBelow"]))
        XCTAssertEqual(appearance["type"] as? String, "appearance")
        XCTAssertEqual(appearance["reduceTransparency"] as? Bool, true)
        let shellRaw = try value.setShell(.init(closed: false, attached: true, forcedClosed: true, tier: .compact))
        let shell = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(shellRaw.utf8)) as? [String: Any])
        XCTAssertEqual(Set(shell.keys), header.union(["profile","attached","forcedClosed","tier","scope"]))
        XCTAssertEqual(shell["profile"] as? String, "closed")
        XCTAssertEqual(shell["tier"] as? String, "compact")
        XCTAssertEqual(shell["version"] as? Int, 2)
        XCTAssertEqual(ticket, value.queryTicket)
        _ = try value.clear()
        XCTAssertThrowsError(try value.setShell(.init(closed: false, attached: true, forcedClosed: false, tier: .tall)))
    }
    func testOnlyContractShellActionsAreAdmittedAndVisibilityStillGatesThem() throws {
        let actions: [(String, CockpitIntent)] = [("close",.close),("detach",.detach),("putBack",.putBack),("shutterToggle",.shutterToggle)]
        for (action, expected) in actions {
            let value = try state(), load = try value.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
            _ = try value.accept(encode(receipt(load)), source: source)
            var object = try receipt(load, version: nil, capabilities: nil)
            object["type"] = "action"; object["action"] = action; object["sequence"] = "2"; object["requestId"] = UUID().uuidString
            XCTAssertThrowsError(try value.accept(encode(object), source: source))
            _ = try value.setVisibility(.init(visible: true, occluded: false, key: true))
            XCTAssertEqual(try value.accept(encode(object), source: source), .action(expected))
        }
        for action in ["toggleAttachment","toggleShutter","navigate"] {
            let value = try state(), load = try value.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
            _ = try value.accept(encode(receipt(load)), source: source)
            _ = try value.setVisibility(.init(visible: true, occluded: false, key: true))
            var object = try receipt(load, version: nil, capabilities: nil)
            object["type"] = "action"; object["action"] = action; object["sequence"] = "2"; object["requestId"] = UUID().uuidString
            XCTAssertThrowsError(try value.accept(encode(object), source: source))
        }
    }

}
