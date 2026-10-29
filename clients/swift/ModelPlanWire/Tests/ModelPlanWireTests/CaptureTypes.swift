// SPDX-License-Identifier: MIT
// Code generated from Go capture roots. DO NOT EDIT.
import Foundation
import ModelPlanWire

func decodeCapture(_ type: String, _ data: Data) throws {
    switch type {
    case "RowsAccount": _ = try WireDecoder.decode(RowsAccount.self, from: data)
    case "RowsCredits": _ = try WireDecoder.decode(RowsCredits.self, from: data)
    case "RowsExpiryState": _ = try WireDecoder.decode(RowsExpiryState.self, from: data)
    case "RowsFailure": _ = try WireDecoder.decode(RowsFailure.self, from: data)
    case "RowsName": _ = try WireDecoder.decode(RowsName.self, from: data)
    case "RowsNextStep": _ = try WireDecoder.decode(RowsNextStep.self, from: data)
    case "RowsPlan": _ = try WireDecoder.decode(RowsPlan.self, from: data)
    case "RowsReason": _ = try WireDecoder.decode(RowsReason.self, from: data)
    case "RowsRow": _ = try WireDecoder.decode(RowsRow.self, from: data)
    case "RowsRowsSummary": _ = try WireDecoder.decode(RowsRowsSummary.self, from: data)
    case "RowsText": _ = try WireDecoder.decode(RowsText.self, from: data)
    case "RowsWindow": _ = try WireDecoder.decode(RowsWindow.self, from: data)
    case "WireCancelParams": _ = try WireDecoder.decode(WireCancelParams.self, from: data)
    case "WireConsentFacts": _ = try WireDecoder.decode(WireConsentFacts.self, from: data)
    case "WireConsentGrantParams": _ = try WireDecoder.decode(WireConsentGrantParams.self, from: data)
    case "WireConsentReceipt": _ = try WireDecoder.decode(WireConsentReceipt.self, from: data)
    case "WireConsentScope": _ = try WireDecoder.decode(WireConsentScope.self, from: data)
    case "WireCredentialRequest": _ = try WireDecoder.decode(WireCredentialRequest.self, from: data)
    case "WireCredentialResult": _ = try WireDecoder.decode(WireCredentialResult.self, from: data)
    case "WireDiagnostics": _ = try WireDecoder.decode(WireDiagnostics.self, from: data)
    case "WireEmpty": _ = try WireDecoder.decode(WireEmpty.self, from: data)
    case "WireEnvelope<WireRowsSnapshot>": _ = try WireDecoder.decode(WireEnvelope<WireRowsSnapshot>.self, from: data)
    case "WireErrorContext": _ = try WireDecoder.decode(WireErrorContext.self, from: data)
    case "WireFailure": _ = try WireDecoder.decode(WireFailure.self, from: data)
    case "WireHealth": _ = try WireDecoder.decode(WireHealth.self, from: data)
    case "WireHistoryItem": _ = try WireDecoder.decode(WireHistoryItem.self, from: data)
    case "WireHistoryPage": _ = try WireDecoder.decode(WireHistoryPage.self, from: data)
    case "WireHistoryQueryParams": _ = try WireDecoder.decode(WireHistoryQueryParams.self, from: data)
    case "WireInitializeParams": _ = try WireDecoder.decode(WireInitializeParams.self, from: data)
    case "WireInitializeResult": _ = try WireDecoder.decode(WireInitializeResult.self, from: data)
    case "WireNotification<WireRowsSnapshot>": _ = try WireDecoder.decode(WireNotification<WireRowsSnapshot>.self, from: data)
    case "WireRPCError": _ = try WireDecoder.decode(WireRPCError.self, from: data)
    case "WireRefreshRequestParams": _ = try WireDecoder.decode(WireRefreshRequestParams.self, from: data)
    case "WireRefreshScheduled": _ = try WireDecoder.decode(WireRefreshScheduled.self, from: data)
    case "WireRequest": _ = try WireDecoder.decode(WireRequest.self, from: data)
    case "WireRowsProjection": _ = try WireDecoder.decode(WireRowsProjection.self, from: data)
    case "WireRowsSnapshot": _ = try WireDecoder.decode(WireRowsSnapshot.self, from: data)
    case "WireScopeDiag": _ = try WireDecoder.decode(WireScopeDiag.self, from: data)
    case "WireSuccess<WireRowsSnapshot>": _ = try WireDecoder.decode(WireSuccess<WireRowsSnapshot>.self, from: data)
    default: throw WireDecodeError.invalidIdentity
    }
}
