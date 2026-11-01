// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

public enum EngineRowsEventState:Equatable,Sendable {
    /// Current public Rows schema has no announced-reset field. No inferred event,
    /// account fetch, popup, dot or notification can be produced from quota changes.
    case absentFromSchema
    case available([EngineResetEvent])
}

public struct EngineResetEvent:Equatable,Sendable {
    public let id:String, rowID:String, provider:String
    public let status:String, publishedAt:Date, expiresAt:Date
    public let planIDs:[String]?
    public let confirms:String?
}

/// Replace this boundary only against the published CLI/wire draft. Unknown JSON
/// fields are not an event contract and the existing typed decoder ignores them.
public enum EngineRowsEventDecoder {
    public static func decode(_ rows:WireRowsSnapshot?) -> EngineRowsEventState {
        guard let events=rows?.projection.resetEvents else { return .absentFromSchema }
        let rowIDs=Set(rows?.projection.rows.map(\.id) ?? [])
        func date(_ timestamp:WireTimestamp) -> Date? {
            let formatter=ISO8601DateFormatter(); formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
            return formatter.date(from:timestamp.rawValue) ?? ISO8601DateFormatter().date(from:timestamp.rawValue)
        }
        var seen=Set<String>()
        let decoded=events.compactMap { event -> EngineResetEvent? in
            guard event.version == 1, event.status.isKnown, rowIDs.contains(event.rowId),
                  let published=date(event.publishedAt), let expires=date(event.expiresAt), published < expires,
                  seen.insert(event.rowId+"#"+event.id).inserted else { return nil }
            // Confirmation must be linked to a previously admitted announcement;
            // until that stateful check is wired, do not surface confirmations.
            if event.status == .confirmed { return nil }
            return .init(id:event.id,rowID:event.rowId,provider:event.provider,status:event.status.rawValue,
                         publishedAt:published,expiresAt:expires,planIDs:event.planIds,confirms:event.confirms)
        }
        return .available(decoded)
    }
}
