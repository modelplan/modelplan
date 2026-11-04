// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

/// The page's displayed-member identity rule, independently applied to the
/// authoritative typed response. Keys remain opaque UI identities, never I/O.
enum CockpitMemberScopes {
    static func keys(_ data:WireCockpitData) -> Set<String> {
        let verified=Set(data.subscriptions.map(\.subscriptionRef))
        var keys:Set<String>=["all"]
        var counts:[String:Int]=[:], ordinals:[String:Int]=[:]
        for row in data.projection.rows {
            for account in row.accounts where account.subscriptionRef.map({ !verified.contains($0) }) ?? true {
                counts[row.id+"#"+account.route.rawValue,default:0] += 1
            }
        }
        for row in data.projection.rows {
            for account in row.accounts {
                let key:String
                if let reference=account.subscriptionRef,verified.contains(reference) { key=reference }
                else {
                    let route=account.route.rawValue
                    let base=row.id+"#"+route
                    ordinals[base,default:0] += 1
                    key=(counts[base] ?? 0)>1 ? base+"#"+String(ordinals[base]!) : base
                }
                if isValidKey(key) { keys.insert(key) }
            }
        }
        return keys
    }
    /// Numbered fallbacks describe only one rendered member list, not an account.
    static func isIndexedFallback(_ key:String) -> Bool {
        guard isValidKey(key), let separator=key.lastIndex(of:"#") else { return false }
        let suffix=key[key.index(after:separator)...]
        return !suffix.isEmpty && suffix.utf8.allSatisfy { (48...57).contains($0) }
    }
    static func isValidKey(_ key:String) -> Bool {
        if key=="all" { return true }
        if key.utf8.count==16 && key.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) { return true }
        guard let last=key.lastIndex(of:"#") else { return false }
        let suffix=key[key.index(after:last)...]
        var base=key[...]
        if !suffix.isEmpty && suffix.utf8.allSatisfy({ (48...57).contains($0) }) {
            guard suffix.first != "0", let ordinal=Int(suffix), ordinal <= 1024 else { return false }
            base=key[..<last]
        }
        guard let separator=base.lastIndex(of:"#") else { return false }
        let row=base[..<separator], route=String(base[base.index(after:separator)...])
        return !row.isEmpty && row.utf16.count<=128 && !row.unicodeScalars.contains { $0.value<32 || $0.value==127 } && RowsRoute(rawValue:route).isKnown
    }
}
