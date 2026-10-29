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
        XCTAssertEqual(catalog.cases.count, 47)
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
        XCTAssertEqual(fields, 55)
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
        envelope = try object("WireEnvelope.json"); envelope["consentGeneration"] = -1
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

    func testRealGoRetiredAccountRemainsValidAlongsideHealthyRow() throws {
        let result = try WireDecoder.decodeWithDiagnostics(WireSuccess<WireRowsSnapshot>.self, from: data("retired-with-account.json"))
        let rows = result.value.result.data.projection.rows
        XCTAssertEqual(Set(rows.map(\.id)), Set(["codex", "claude"]))
        let retired = try XCTUnwrap(rows.first { $0.id == "codex" })
        XCTAssertEqual(retired.consent, .retired)
        XCTAssertEqual(retired.reason.code, .catalogueRetired)
        XCTAssertEqual(retired.accounts.count, 1)
        XCTAssertFalse(retired.invalid)
        XCTAssertTrue(rows.allSatisfy { !$0.invalid })
        XCTAssertEqual(result.invalidRowCount, 0)
        XCTAssertEqual(result.value.result.data.projection.invalidRowCount, 0)
    }

    func testSemanticRowFailureKeepsHealthyRowsAndExposesSafePlaceholder() throws {
        for mutation in ["denied", "unset", "cleanup", "unknown-consent", "unknown-kind", "bad-account-reference"] {
            var message = try object("retired-with-account.json")
            var envelope = try XCTUnwrap(message["result"] as? [String: Any])
            var snapshot = try XCTUnwrap(envelope["data"] as? [String: Any])
            var projection = try XCTUnwrap(snapshot["projection"] as? [String: Any])
            var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
            let offset = try XCTUnwrap(rows.firstIndex { ($0["id"] as? String) == "claude" })
            if mutation == "denied" || mutation == "unset" { rows[offset]["consent"] = mutation }
            if mutation == "unknown-consent" { rows[offset]["consent"] = "future_grant" }
            if mutation == "unknown-kind" { rows[offset]["kind"] = "future_identity_kind" }
            if mutation == "cleanup" {
                var reason = try XCTUnwrap(rows[offset]["reason"] as? [String: Any])
                reason["code"] = "cleanup_pending"; rows[offset]["reason"] = reason
            }
            if mutation == "bad-account-reference" {
                var accounts = try XCTUnwrap(rows[offset]["accounts"] as? [[String: Any]])
                accounts[0]["subscriptionRef"] = "unverified-reference"
                rows[offset]["accounts"] = accounts
            }
            rows[offset]["invalid"] = false // Wire data cannot bypass the local marker.
            projection["rows"] = rows; snapshot["projection"] = projection
            envelope["data"] = snapshot; message["result"] = envelope
            let result = try WireDecoder.decodeWithDiagnostics(WireSuccess<WireRowsSnapshot>.self, from: encoded(message))
            let recovered = result.value.result.data.projection
            XCTAssertEqual(Set(recovered.rows.map(\.id)), Set(["claude", "codex"]), mutation)
            XCTAssertEqual(result.invalidRowCount, 1, mutation)
            XCTAssertEqual(recovered.invalidRowCount, 1, mutation)
            let invalid = try XCTUnwrap(recovered.rows.first { $0.id == "claude" })
            XCTAssertTrue(invalid.invalid, mutation)
            XCTAssertTrue(invalid.accounts.isEmpty, mutation)
            XCTAssertNil(invalid.vendorKey); XCTAssertNil(invalid.nextStep)
            XCTAssertNil(invalid.expiresAt); XCTAssertNil(invalid.stateAfterExpiry)
            let healthy = try XCTUnwrap(recovered.rows.first { $0.id == "codex" })
            XCTAssertFalse(healthy.invalid, mutation)
            XCTAssertEqual(healthy.accounts.count, 1, mutation)
            XCTAssertEqual(healthy.accounts[0].windows[0].remainingPercent, 75, mutation)
            XCTAssertThrowsError(try JSONEncoder().encode(result.value), mutation)
        }
        let clean = try WireDecoder.decodeWithDiagnostics(WireSuccess<WireRowsSnapshot>.self, from: data("retired-with-account.json"))
        XCTAssertEqual(clean.invalidRowCount, 0) // Diagnostics belong to this decode, not a global latch.
    }

    func testEnvelopeFailuresAndMalformedFramesStillRejectWholeMessage() throws {
        for field in ["sessionId", "storeEpoch", "consentGeneration"] {
            var message = try object("retired-with-account.json")
            var envelope = try XCTUnwrap(message["result"] as? [String: Any])
            if field == "consentGeneration" { envelope[field] = -1 } else { envelope[field] = "" }
            message["result"] = envelope
            XCTAssertThrowsError(try WireDecoder.decodeWithDiagnostics(WireSuccess<WireRowsSnapshot>.self, from: encoded(message)), field)
        }
        XCTAssertThrowsError(try WireDecoder.decodeWithDiagnostics(WireSuccess<WireRowsSnapshot>.self, from: Data("{".utf8)))
    }

    func testQueryReferenceAndCursorNeverSilentlyChangeMeaning() throws {
        for field in ["ref", "cursor"] {
            let malformedValues: [Any] = [123, ["unexpected": true]]
            for malformed in malformedValues {
                var query = try object("WireHistoryQueryParams.json")
                query[field] = malformed
                XCTAssertThrowsError(try WireDecoder.decode(WireHistoryQueryParams.self, from: encoded(query)), field)
            }
        }
    }

    func testCredentialRequestWrapperAndAmbiguousResponsesFailClosed() throws {
        var request = try object("WireRequest.json")
        request["method"] = "credentials/result"
        request["params"] = try object("WireCredentialResult.json")
        let valid = try WireDecoder.decode(WireRequest.self, from: encoded(request))
        XCTAssertFalse(String(reflecting: valid).contains("TOKEN-CANARY-U4"))
        var params = try object("WireCredentialResult.json")
        params["outcome"] = "denied"
        request["params"] = params
        XCTAssertThrowsError(try WireDecoder.decode(WireRequest.self, from: encoded(request)))
        var success = try object("WireSuccess.json")
        success["error"] = ["code": -32099]
        XCTAssertThrowsError(try WireDecoder.decode(WireSuccess<WireRowsSnapshot>.self, from: encoded(success)))
        let failure = try WireDecoder.decode(WireFailure.self, from: data("null-error.json"))
        XCTAssertNil(failure.id)
        let maximum = try WireDecoder.decode(WireRequestID.self, from: Data("18446744073709551615".utf8))
        XCTAssertEqual(maximum, .unsigned(UInt64.max))
    }

    func testDuplicateRowsAndOversizedFramesAreRejected() throws {
        var projection = try object("WireRowsProjection.json")
        let row = try XCTUnwrap(projection["rows"] as? [[String: Any]])[0]
        projection["rows"] = [row, row]
        XCTAssertThrowsError(try WireDecoder.decode(WireRowsProjection.self, from: encoded(projection)))
        XCTAssertThrowsError(try WireDecoder.decode(WireEmpty.self, from: Data(repeating: 32, count: WireProtocol.maxFrameBytes + 1)))
    }
}
