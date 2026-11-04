// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

public enum EngineRowsEventState:Equatable,Sendable {
    /// The producer did not supply the optional field.
    case absentFromSchema
    case available([EngineResetEvent])
}

public struct EngineResetSourceLink: Equatable, Sendable {
    public let kind: String, url: URL
}
public struct EngineResetEvent:Equatable,Sendable {
    public let id:String, rowID:String, provider:String
    public let status:String, publishedAt:Date, expiresAt:Date
    public let planIDs:[String]?
    public let confirms:String?
    public let sourceLinks: [EngineResetSourceLink]
    public let scheduledFrom: Date?, scheduledThrough: Date?
    public init(id:String,rowID:String,provider:String,status:String,publishedAt:Date,expiresAt:Date,planIDs:[String]?,confirms:String?,sourceLinks:[EngineResetSourceLink]=[],scheduledFrom:Date?=nil,scheduledThrough:Date?=nil) {
        self.id=id;self.rowID=rowID;self.provider=provider;self.status=status
        self.publishedAt=publishedAt;self.expiresAt=expiresAt;self.planIDs=planIDs;self.confirms=confirms
        self.sourceLinks=sourceLinks;self.scheduledFrom=scheduledFrom;self.scheduledThrough=scheduledThrough
    }
}

/// Projects only explicit wire events; quota readings never create notices.
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
                  let published=date(event.publishedAt), let expires=date(event.expiresAt), published < expires else { return nil }
            if event.status == .confirmed && (event.confirms?.isEmpty ?? true) { return nil }
            guard seen.insert(event.rowId+"#"+event.id+"#"+event.status.rawValue).inserted else { return nil }
            var sourceLinks = [EngineResetSourceLink](), seenURLs = Set<URL>()
            if event.source.kind == "publication" {
                let candidates = [("publication", event.source.url)] + (event.source.links ?? []).prefix(8).map { ($0.type, Optional($0.url)) }
                for (kind, raw) in candidates where sourceLinks.count < 8 {
                    guard ["publication", "aihot", "original"].contains(kind), let raw, raw.utf8.count <= 2048,
                          let url = URL(string: raw), url.scheme?.lowercased() == "https", !(url.host ?? "").isEmpty,
                          url.user == nil, url.password == nil, seenURLs.insert(url).inserted else { continue }
                    sourceLinks.append(.init(kind:kind,url:url))
                }
            }
            let from = event.schedule.flatMap { date($0.from) }, through = event.schedule.flatMap { date($0.through) }
            let scheduled = from != nil && through != nil && from! <= through!
            return .init(id:event.id,rowID:event.rowId,provider:event.provider,status:event.status.rawValue,
                         publishedAt:published,expiresAt:expires,planIDs:event.planIds,confirms:event.confirms,
                         sourceLinks:sourceLinks,scheduledFrom:scheduled ? from:nil,scheduledThrough:scheduled ? through:nil)
        }
        return .available(decoded)
    }
}
