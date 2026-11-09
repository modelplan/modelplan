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
            let nullPolicy: String
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

    func testRowsSubscribeBusyFixtureIsTypedRPCError() throws {
        let failure = try WireDecoder.decode(WireFailure.self, from: data("rows-subscribe-busy.json"))
        XCTAssertEqual(failure.error.code, WireErrorCode.busy)
        XCTAssertEqual(failure.error.message, "busy")
        XCTAssertEqual(failure.error.data.sessionId, "s-synthetic")
    }
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

    func testCockpitThresholdIsStrictAndBounded() throws {
        let decoder = JSONDecoder()
        for value in [10, 15, 20, 25, 30, 40] {
            let json = "{\"redBelow\":\(value)}"
            XCTAssertEqual(try decoder.decode(WireCockpitQueryParams.self, from: Data(json.utf8)).redBelow, value)
        }
        for json in [#"{"redBelow":16}"#, #"{"redBelow":17}"#, #"{"redBelow":"15"}"#, #"{"redBelow":null}"#] {
            XCTAssertThrowsError(try decoder.decode(WireCockpitQueryParams.self, from: Data(json.utf8)))
        }
    }

    func testMalformedCockpitDetailsNeverDisappear() throws {
        let original = try object("WireCockpitData.json")
        var invalidVersion = original
        var details = try XCTUnwrap(invalidVersion["details"] as? [String: Any])
        details["version"] = 2
        invalidVersion["details"] = details
        try check("WireCockpitData", invalidVersion, accepted: false, context: "details version")
        var invalidReference = original
        details = try XCTUnwrap(invalidReference["details"] as? [String: Any])
        var subs = try XCTUnwrap(details["subscriptions"] as? [[String: Any]])
        subs[0]["subscriptionRef"] = "bad-reference"
        details["subscriptions"] = subs
        invalidReference["details"] = details
        try check("WireCockpitData", invalidReference, accepted: false, context: "details subscription")
        var missingTime = original
        details = try XCTUnwrap(missingTime["details"] as? [String: Any])
        var sessions = try XCTUnwrap(details["sessions"] as? [[String: Any]])
        sessions[0].removeValue(forKey: "lastObservedAt")
        details["sessions"] = sessions
        missingTime["details"] = details
        try check("WireCockpitData", missingTime, accepted: false, context: "details session time")
        sessions[0]["lastObservedAt"] = "2026-10-29T12:00:00Z"
        sessions[0]["sessionRef"] = "bad-reference"
        details["sessions"] = sessions
        missingTime["details"] = details
        try check("WireCockpitData", missingTime, accepted: false, context: "details session reference")
    }

    func testEveryRealGoCaptureUsesGeneratedProductionDecoder() throws {
        let catalog = try index()
        XCTAssertEqual(catalog.version, 1)
        XCTAssertEqual(catalog.cases.count, 91)
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
        XCTAssertEqual(fields, 122)
    }

    func testModelScopeAndResetEventsRejectMalformedValues() throws {
        for (file, type, field) in [("RowsWindow.json", "RowsWindow", "modelScope"),
                                    ("RowsWindow.json", "RowsWindow", "source"),
                                    ("WireDiagnostics.json", "WireDiagnostics", "refreshDecisions"),
                                    ("WireRefreshRequestParams.json", "WireRefreshRequestParams", "member"),
                                    ("WireMemberRefreshResult.json", "WireMemberRefreshResult", "notBefore"),
                                    ("WireMemberRefreshResult.json", "WireMemberRefreshResult", "reason"),
                                    ("WireRowsProjection.json", "WireRowsProjection", "resetEvents")] {
            var value = try object(file)
            value.removeValue(forKey: field)
            try check(type, value, accepted: true, context: type + " absent")
            value[field] = NSNull()
            try check(type, value, accepted: false, context: type + " null")
            value[field] = ["wrongType": true]
            try check(type, value, accepted: false, context: type + " wrong type")
        }
    }

    func testMalformedNestedModelScopeDoesNotBecomePlanWide() throws {
        var projection = try object("WireRowsProjection.json")
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        var accounts = try XCTUnwrap(rows[0]["accounts"] as? [[String: Any]])
        var windows = try XCTUnwrap(accounts[0]["windows"] as? [[String: Any]])
        windows[0]["modelScope"] = "malformed"
        accounts[0]["windows"] = windows
        rows[0]["accounts"] = accounts
        projection["rows"] = rows
        XCTAssertThrowsError(try WireDecoder.decode(WireRowsProjection.self, from: encoded(projection)))
    }

    func testResetCardFactsRejectMalformedNestedData() throws {
        var account = try object("RowsAccount.json")
        var facts = try XCTUnwrap(account["resetCards"] as? [String: Any])
        facts["state"] = "fabricated"
        account["resetCards"] = facts
        XCTAssertThrowsError(try WireDecoder.decode(RowsAccount.self, from: encoded(account)))
        account["resetCards"] = "malformed"
        XCTAssertThrowsError(try WireDecoder.decode(RowsAccount.self, from: encoded(account)))
        account["resetCards"] = NSNull()
        XCTAssertThrowsError(try WireDecoder.decode(RowsAccount.self, from: encoded(account)))
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


extension DecodeTests {
    func testSelectionRevisionPreservesAbsenceNullAndString() throws {
        for state in ["absent", "null", "string"] {
            var source = try object("WirePublicationResult.json")
            if state == "absent" { source.removeValue(forKey: "selectionRevision") }
            else { source["selectionRevision"] = state == "null" ? NSNull() : "synthetic-revision" }
            let value = try WireDecoder.decode(WirePublicationResult.self, from: encoded(source))
            let output = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? NSDictionary)
            let expected = source as NSDictionary
            XCTAssertEqual(output, expected, state + " must retain field presence and value")
            if state == "absent" { XCTAssertNil(value.selectionRevision) }
            else if state == "null" { XCTAssertEqual(value.selectionRevision, .null) }
            else { XCTAssertEqual(value.selectionRevision, .string("synthetic-revision")) }
        }
    }
}


extension DecodeTests {
    func testOptionalRawRequestParamsRetainExplicitNull() throws {
        var source = try object("WireRequest.json")
        source["params"] = NSNull()
        let value = try WireDecoder.decode(WireRequest.self, from: encoded(source))
        XCTAssertEqual(value.params, .null)
        let output = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? NSDictionary)
        XCTAssertEqual(output, source as NSDictionary)
    }
}


extension DecodeTests {
    func testEveryDeclaredOptionalNullPolicyThroughProductionDecoder() throws {
        var distinct = 0
        var checked = 0
        for entry in try index().cases {
            for field in entry.optional {
                checked += 1
                XCTAssertTrue(["distinct", "coalesced", "forbidden"].contains(field.nullPolicy), entry.type + "." + field.field)
                var absent = try object(entry.file)
                absent.removeValue(forKey: field.field)
                var null = try object(entry.file)
                null[field.field] = NSNull()
                if field.nullPolicy == "distinct" {
                    distinct += 1
                    XCTAssertTrue(field.omission && field.null, "distinct declaration must admit all three states")
                    for source in [absent, null, try object(entry.file)] {
                        let bytes = try roundTripCapture(entry.type, encoded(source))
                        let output = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
                        XCTAssertEqual(output.keys.contains(field.field), source.keys.contains(field.field), entry.type + "." + field.field + " presence")
                        XCTAssertEqual(output[field.field] as? NSObject, source[field.field] as? NSObject, entry.type + "." + field.field + " value")
                    }
                } else if field.nullPolicy == "coalesced" && field.omission && field.null {
                    let a = try roundTripCapture(entry.type, encoded(absent))
                    let b = try roundTripCapture(entry.type, encoded(null))
                    let aFields = try XCTUnwrap(JSONSerialization.jsonObject(with: a) as? [String: Any])
                    let bFields = try XCTUnwrap(JSONSerialization.jsonObject(with: b) as? [String: Any])
                    XCTAssertEqual(aFields.keys.contains(field.field), bFields.keys.contains(field.field), entry.type + "." + field.field)
                    XCTAssertEqual(aFields[field.field] as? NSObject, bFields[field.field] as? NSObject, entry.type + "." + field.field)
                } else if field.nullPolicy == "forbidden" {
                    XCTAssertThrowsError(try roundTripCapture(entry.type, encoded(null)), entry.type + "." + field.field)
                }
            }
        }
        XCTAssertGreaterThan(checked, 0)
        XCTAssertGreaterThan(distinct, 0)
    }
}


extension DecodeTests {
    func testHistorySelectorsMatchHandlerOmissionAndNullRules() throws {
        var omitted = try object("WireHistoryQueryParams.json")
        omitted.removeValue(forKey: "ref")
        omitted.removeValue(forKey: "cursor")
        let valid = try WireDecoder.decode(WireHistoryQueryParams.self, from: encoded(omitted))
        XCTAssertNil(valid.ref)
        XCTAssertNil(valid.cursor)
        for selector in ["ref", "cursor"] {
            var null = omitted
            null[selector] = NSNull()
            XCTAssertThrowsError(try WireDecoder.decode(WireHistoryQueryParams.self, from: encoded(null)), selector + " must be rejected before re-encoding")
        }
    }
}


extension DecodeTests {
    func testResetTimestampDistinguishesAbsentNullAndInvalidValues() throws {
        for mode in ["valid", "null", "missing", "invalid-string", "invalid-type"] {
            var message = try object("retired-with-account.json")
            var envelope = try XCTUnwrap(message["result"] as? [String: Any])
            var snapshot = try XCTUnwrap(envelope["data"] as? [String: Any])
            var projection = try XCTUnwrap(snapshot["projection"] as? [String: Any])
            var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
            let index = try XCTUnwrap(rows.firstIndex { $0["id"] as? String == "claude" })
            var accounts = try XCTUnwrap(rows[index]["accounts"] as? [[String: Any]])
            var windows = try XCTUnwrap(accounts[0]["windows"] as? [[String: Any]])
            switch mode {
            case "valid": windows[0]["resetsAt"] = "2026-10-29T12:00:00Z"
            case "null": windows[0]["resetsAt"] = NSNull()
            case "missing": windows[0].removeValue(forKey: "resetsAt")
            case "invalid-string": windows[0]["resetsAt"] = "not-a-timestamp"
            default: windows[0]["resetsAt"] = 42
            }
            accounts[0]["windows"] = windows; rows[index]["accounts"] = accounts
            projection["rows"] = rows; snapshot["projection"] = projection
            envelope["data"] = snapshot; message["result"] = envelope

            let decoded = try WireDecoder.decodeWithDiagnostics(WireSuccess<WireRowsSnapshot>.self, from: encoded(message))
            let output = decoded.value.result.data.projection.rows
            let selected = try XCTUnwrap(output.first { $0.id == "claude" })
            let healthy = try XCTUnwrap(output.first { $0.id == "codex" })
            let invalid = mode == "invalid-string" || mode == "invalid-type"
            XCTAssertEqual(decoded.invalidRowCount, invalid ? 1 : 0, mode)
            XCTAssertEqual(selected.invalid, invalid, mode)
            XCTAssertFalse(healthy.invalid, mode)
            XCTAssertEqual(healthy.accounts.first?.windows.first?.remainingPercent, 75, mode)
            if invalid {
                XCTAssertTrue(selected.accounts.isEmpty, mode)
            } else {
                let reset = try XCTUnwrap(selected.accounts.first?.windows.first).resetsAt
                XCTAssertEqual(reset?.rawValue, mode == "valid" ? "2026-10-29T12:00:00Z" : nil, mode)
            }
        }
    }

    func testCredentialOptionalNullsRespectOutcomePresence() throws {
        for outcome in ["canceled", "denied", "not_found", "interaction_required", "timeout", "error"] {
            var omitted = try object("WireCredentialResult.json")
            omitted["outcome"] = outcome
            omitted.removeValue(forKey: "accessToken")
            omitted.removeValue(forKey: "expiresAt")
            XCTAssertNoThrow(try WireDecoder.decode(WireCredentialResult.self, from: encoded(omitted)))
            for field in ["accessToken", "expiresAt"] {
                var null = omitted; null[field] = NSNull()
                XCTAssertThrowsError(try WireDecoder.decode(WireCredentialResult.self, from: encoded(null)), outcome + "." + field)
            }
        }
        for expiry in [false, true] {
            var ok = try object("WireCredentialResult.json")
            ok.removeValue(forKey: "expiresAt")
            if expiry { ok["expiresAt"] = NSNull() }
            XCTAssertNoThrow(try WireDecoder.decode(WireCredentialResult.self, from: encoded(ok)))
            ok.removeValue(forKey: "accessToken")
            XCTAssertThrowsError(try WireDecoder.decode(WireCredentialResult.self, from: encoded(ok)))
            ok["accessToken"] = NSNull()
            XCTAssertThrowsError(try WireDecoder.decode(WireCredentialResult.self, from: encoded(ok)))
        }
    }
}
