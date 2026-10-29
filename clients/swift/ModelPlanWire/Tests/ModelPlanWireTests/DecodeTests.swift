// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire

private struct CaptureIndex: Decodable {
    struct Entry: Decodable {
        struct Mutation: Decodable {
            let field: String
            let omission: Bool
            let null: Bool
            let wrongType: Bool
            let strict: Bool
        }
        let file: String
        let type: String
        let optional: [Mutation]
        let required: [String]
    }
    let version: Int
    let cases: [Entry]
}

final class DecodeTests: XCTestCase {
    private var captures: URL {
        if let path = ProcessInfo.processInfo.environment["MODELPLAN_CAPTURE_DIR"] {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures").standardizedFileURL
    }
    private func data(_ name: String) throws -> Data { try Data(contentsOf: captures.appendingPathComponent(name)) }
    private func object(_ name: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data(name)) as? [String: Any])
    }
    private func encoded(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
    private func index() throws -> CaptureIndex { try JSONDecoder().decode(CaptureIndex.self, from: data("index.json")) }
    private func check(_ type: String, _ value: [String: Any], accepted: Bool, context: String) throws {
        let bytes = try encoded(value)
        if accepted { XCTAssertNoThrow(try decodeCapture(type, bytes), context) }
        else { XCTAssertThrowsError(try decodeCapture(type, bytes), context) }
    }

    func testEveryRealGoCaptureUsesGeneratedProductionDecoder() throws {
        let catalog = try index()
        XCTAssertEqual(catalog.version, 1)
        XCTAssertEqual(catalog.cases.count, 39)
        for entry in catalog.cases {
            XCTAssertNoThrow(try decodeCapture(entry.type, data(entry.file)), entry.type)
            var future = try object(entry.file)
            future["futureExtension"] = ["displayOnly": ["new", "data"]]
            try check(entry.type, future, accepted: true, context: entry.type + " unknown field")
        }
    }

    func testEveryOptionalFieldOmittedNullAndWrongType() throws {
        var fields = 0
        for entry in try index().cases {
            for field in entry.optional {
                fields += 1
                var omitted = try object(entry.file)
                omitted.removeValue(forKey: field.field)
                try check(entry.type, omitted, accepted: field.omission, context: entry.type + "." + field.field + " omitted")
                var null = try object(entry.file)
                null[field.field] = NSNull()
                try check(entry.type, null, accepted: field.null, context: entry.type + "." + field.field + " null")
                var wrongType = try object(entry.file)
                wrongType[field.field] = ["wrongType": true]
                try check(entry.type, wrongType, accepted: field.wrongType, context: entry.type + "." + field.field + " type")
            }
        }
        XCTAssertEqual(fields, 47)
    }

    func testRequiredFieldsRemainRequired() throws {
        for entry in try index().cases {
            for field in entry.required {
                var omitted = try object(entry.file)
                omitted.removeValue(forKey: field)
                try check(entry.type, omitted, accepted: false, context: entry.type + "." + field)
                var null = try object(entry.file)
                null[field] = NSNull()
                try check(entry.type, null, accepted: false, context: entry.type + "." + field + " null")
            }
        }
    }

    func testHistoryModelRegressionDoesNotLoseRows() throws {
        let rows = try WireDecoder.decode(WireSuccess<WireRowsSnapshot>.self, from: data("production-rows.json"))
        let expected = rows.result.data.projection.rows.map(\.id)
        XCTAssertEqual(expected, ["declared:team"])
        for mode in ["omitted", "null", "wrong-type"] {
            var page = try object("WireHistoryPage.json")
            var items = try XCTUnwrap(page["items"] as? [[String: Any]])
            if mode == "omitted" { items[0].removeValue(forKey: "model") }
            if mode == "null" { items[0]["model"] = NSNull() }
            if mode == "wrong-type" { items[0]["model"] = ["bad": true] }
            page["items"] = items
            let decoded = try WireDecoder.decode(WireHistoryPage.self, from: encoded(page))
            XCTAssertNil(decoded.items[0].model)
            XCTAssertEqual(rows.result.data.projection.rows.map(\.id), expected)
        }
        // A required history field error remains a feature failure, never an empty rows snapshot.
        XCTAssertThrowsError(try WireDecoder.decode(WireHistoryPage.self, from: Data("{\"items\":null}".utf8)))
        XCTAssertEqual(rows.result.data.projection.rows.map(\.id), expected)
    }

    func testOptionalDisplayMutationsPreserveNestedRowIDs() throws {
        let original = try object("WireSuccess.json")
        let expected = try WireDecoder.decode(WireSuccess<WireRowsSnapshot>.self, from: encoded(original)).result.data.projection.rows.map(\.id)
        let rowFields = try XCTUnwrap(index().cases.first { $0.type == "RowsRow" }).optional
        for field in rowFields where !field.strict {
            var message = original
            var result = try XCTUnwrap(message["result"] as? [String: Any])
            var snapshot = try XCTUnwrap(result["data"] as? [String: Any])
            var projection = try XCTUnwrap(snapshot["projection"] as? [String: Any])
            var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
            rows[0][field.field] = ["wrongType": true]
            projection["rows"] = rows; snapshot["projection"] = projection; result["data"] = snapshot; message["result"] = result
            let decoded = try WireDecoder.decode(WireSuccess<WireRowsSnapshot>.self, from: encoded(message))
            XCTAssertEqual(decoded.result.data.projection.rows.map(\.id), expected)
        }
    }

    func testUnknownDisplayEnumsRoundTripAndAuthorizationFailsClosed() throws {
        let state = try JSONDecoder().decode(RowsState.self, from: Data("\"future_state\"".utf8))
        XCTAssertEqual(state, .unknown("future_state"))
        XCTAssertEqual(try JSONDecoder().decode(RowsState.self, from: JSONEncoder().encode(state)), state)
        var row = try object("RowsRow.json")
        row["state"] = "future_state"
        let decoded = try WireDecoder.decode(RowsRow.self, from: encoded(row))
        XCTAssertEqual(decoded.state, .unknown("future_state"))
        row["consent"] = "future_grant"
        XCTAssertThrowsError(try WireDecoder.decode(RowsRow.self, from: encoded(row)))
        var facts = try object("WireConsentScope.json")
        facts["state"] = "future_grant"
        XCTAssertThrowsError(try WireDecoder.decode(WireConsentScope.self, from: encoded(facts)))
        facts["state"] = "allowed"; facts["keychain"] = "future_choice"
        XCTAssertThrowsError(try WireDecoder.decode(WireConsentScope.self, from: encoded(facts)))
    }

    func testInvalidIdentitiesVersionsAndBoundsRejectExplicitly() throws {
        var row = try object("RowsRow.json")
        for id in ["", "bad/path", "user\nidentity"] {
            row["id"] = id
            XCTAssertThrowsError(try WireDecoder.decode(RowsRow.self, from: encoded(row)))
        }
        var account = try object("RowsAccount.json")
        account["subscriptionRef"] = "personal-email@example.invalid"
        XCTAssertThrowsError(try WireDecoder.decode(RowsAccount.self, from: encoded(account)))
        var envelope = try object("WireEnvelope.json")
        envelope["sessionId"] = ""
        XCTAssertThrowsError(try WireDecoder.decode(WireEnvelope<WireRowsSnapshot>.self, from: encoded(envelope)))
        envelope = try object("WireEnvelope.json"); envelope["consentGeneration"] = 8
        XCTAssertThrowsError(try WireDecoder.decode(WireEnvelope<WireRowsSnapshot>.self, from: encoded(envelope)))
        var initialize = try object("WireInitializeResult.json")
        initialize["protocolVersion"] = "99.0"
        XCTAssertThrowsError(try WireDecoder.decode(WireInitializeResult.self, from: encoded(initialize)))
        initialize["protocolVersion"] = "1.99"
        XCTAssertNoThrow(try WireDecoder.decode(WireInitializeResult.self, from: encoded(initialize)))
        var query = try object("WireHistoryQueryParams.json")
        for limit in [0, 501] {
            query["limit"] = limit
            XCTAssertThrowsError(try WireDecoder.decode(WireHistoryQueryParams.self, from: encoded(query)))
        }
        query["limit"] = 500
        XCTAssertNoThrow(try WireDecoder.decode(WireHistoryQueryParams.self, from: encoded(query)))
    }

    func testExactIntegerIDsAndExplicitNullEncoding() throws {
        let result = try WireDecoder.decode(WireSuccess<WireRowsSnapshot>.self, from: data("production-rows.json"))
        XCTAssertEqual(result.id, .signed(9_007_199_254_740_993))
        let roundtrip = try WireDecoder.decode(WireSuccess<WireRowsSnapshot>.self, from: JSONEncoder().encode(result))
        XCTAssertEqual(roundtrip.id, result.id)
        var item = try object("WireHistoryItem.json")
        item.removeValue(forKey: "model")
        let history = try WireDecoder.decode(WireHistoryItem.self, from: encoded(item))
        let encodedItem = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(history)) as? [String: Any])
        XCTAssertTrue(encodedItem["model"] is NSNull)
        XCTAssertEqual(history.at.rawValue, "2026-10-29T12:00:00.123456789Z")
    }

    func testCredentialDescriptionsRedactedAndTokenPlacementRejected() throws {
        let credential = try WireDecoder.decode(WireCredentialResult.self, from: data("WireCredentialResult.json"))
        XCTAssertFalse(String(describing: credential).contains("TOKEN-CANARY-U4"))
        XCTAssertFalse(String(reflecting: credential).contains("TOKEN-CANARY-U4"))
        var denied = try object("WireCredentialResult.json")
        denied["outcome"] = "denied"
        XCTAssertThrowsError(try WireDecoder.decode(WireCredentialResult.self, from: encoded(denied)))
        denied.removeValue(forKey: "accessToken"); denied.removeValue(forKey: "expiresAt")
        XCTAssertNoThrow(try WireDecoder.decode(WireCredentialResult.self, from: encoded(denied)))
        denied["accessToken"] = NSNull()
        XCTAssertThrowsError(try WireDecoder.decode(WireCredentialResult.self, from: encoded(denied)))
        var rows = try object("WireSuccess.json")
        rows["extension"] = ["accessToken": "TOKEN-CANARY-U4"]
        XCTAssertThrowsError(try WireDecoder.decode(WireSuccess<WireRowsSnapshot>.self, from: encoded(rows)))
    }

    func testDuplicateRowsAndOversizedFramesAreRejected() throws {
        var projection = try object("RowsProjection.json")
        let row = try XCTUnwrap(projection["rows"] as? [[String: Any]])[0]
        projection["rows"] = [row, row]
        XCTAssertThrowsError(try WireDecoder.decode(RowsProjection.self, from: encoded(projection)))
        XCTAssertThrowsError(try WireDecoder.decode(WireEmpty.self, from: Data(repeating: 32, count: WireProtocol.maxFrameBytes + 1)))
    }
}
