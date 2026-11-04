// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

public enum EngineRowsEventState:Equatable,Sendable {
    /// The producer did not supply the optional field.
    case absentFromSchema
    case available([EngineResetEvent])
}

public struct EngineResetEvent:Equatable,Sendable {
    public let id:String, rowID:String, provider:String
    public let status:String, publishedAt:Date, expiresAt:Date
    public let planIDs:[String]?
    public let confirms:String?
    public let links:[EngineResetSourceLink]
    public init(id:String,rowID:String,provider:String,status:String,publishedAt:Date,expiresAt:Date,planIDs:[String]?,confirms:String?,links:[EngineResetSourceLink] = []) {
        self.id=id;self.rowID=rowID;self.provider=provider;self.status=status;self.publishedAt=publishedAt
        self.expiresAt=expiresAt;self.planIDs=planIDs;self.confirms=confirms;self.links=links
    }
    public func orderedLinks(english:Bool) -> [EngineResetSourceLink] {
        let order:[EngineResetSourceLink.Kind] = english ? [.original,.aihot,.official] : [.aihot,.original,.official]
        return order.compactMap { kind in links.first { $0.kind == kind } }
    }
}

public struct EngineResetSourceLink:Equatable,Sendable {
    public enum Kind:Equatable,Sendable { case aihot, original, official }
    public let kind:Kind
    public let url:URL
    /// Keep the App's link boundary at least as strict as the producer's.
    static func admit(_ value:RowsResetLink) -> Self? {
        let raw=value.url
        guard !raw.isEmpty, raw.utf8.count <= 2048, !raw.contains(where:{ "?#%".contains($0) }),
              let parts=URLComponents(string:raw), parts.scheme == "https", parts.user == nil, parts.password == nil,
              parts.port == nil, parts.query == nil, parts.fragment == nil, let host=parts.host?.lowercased(), let url=parts.url else { return nil }
        let authority=raw.dropFirst("https://".count).prefix { $0 != "/" }
        guard authority.lowercased() == host else { return nil }
        let path=parts.path
        func matches(_ pattern:String) -> Bool { path.range(of:pattern,options:.regularExpression) != nil }
        guard matches("^/[A-Za-z0-9][A-Za-z0-9/_-]*$") &&
                !matches("(?i)(^|[/_-])(user|users|profile|profiles|account|accounts|member|members|personal|private|settings|login|session|auth|token|secret|password|credential|api|key|email|me)([/_-]|$)") else { return nil }
        let kind:Kind
        switch value.type {
        case "aihot": guard host == "aihot.news", matches("(?i)^/[a-z0-9-]*reset[a-z0-9-]*$") else { return nil }; kind = .aihot
        case "original": guard ["x.com","twitter.com"].contains(host), matches("^/[A-Za-z0-9_]{1,15}/status/[0-9]{1,19}$") else { return nil }; kind = .original
        case "official":
            guard ["openai.com","help.openai.com","status.openai.com","platform.openai.com","developers.openai.com","anthropic.com","www.anthropic.com","support.anthropic.com","status.anthropic.com","docs.anthropic.com"].contains(host),
                  matches("(?i)^/(incidents|docs|en/docs|articles|news|index|research|blog|updates|releases)(/[a-z0-9_-]+)*$") else { return nil }; kind = .official
        default:return nil
        }
        return .init(kind:kind,url:url)
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
            return .init(id:event.id,rowID:event.rowId,provider:event.provider,status:event.status.rawValue,
                         publishedAt:published,expiresAt:expires,planIDs:event.planIds,confirms:event.confirms,
                         links:(event.source.links ?? []).compactMap(EngineResetSourceLink.admit))
        }
        return .available(decoded)
    }
}
