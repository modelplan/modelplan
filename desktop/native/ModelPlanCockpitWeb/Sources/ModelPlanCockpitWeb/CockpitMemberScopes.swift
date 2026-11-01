// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

/// The page's displayed-member identity rule, independently applied to the
/// authoritative typed response. Keys remain opaque UI identities, never I/O.
enum CockpitMemberScopes {
    static func keys(_ data:WireCockpitData) -> Set<String> {
        let verified=Set(data.subscriptions.map(\.subscriptionRef))
        var keys:Set<String>=["all"]
        for row in data.projection.rows {
            for account in row.accounts {
                let key:String
                if let reference=account.subscriptionRef,verified.contains(reference) { key=reference }
                else { key=row.id+"#"+account.route.rawValue }
                if isValidKey(key) { keys.insert(key) }
            }
        }
        return keys
    }
    static func isValidKey(_ key:String) -> Bool {
        if key=="all" { return true }
        if key.utf8.count==16 && key.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) { return true }
        guard let separator=key.lastIndex(of:"#") else { return false }
        let row=key[..<separator], route=String(key[key.index(after:separator)...])
        return !row.isEmpty && row.utf16.count<=128 && !row.unicodeScalars.contains { $0.value<32 || $0.value==127 } && RowsRoute(rawValue:route).isKnown
    }
}
