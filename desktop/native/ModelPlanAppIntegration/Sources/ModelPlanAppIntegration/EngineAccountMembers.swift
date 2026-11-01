// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire
import ModelPlanSettings

/// The App identity unit shared by Dock and Settings. Keys are never display copy.
public struct EngineAccountMember:Sendable {
    public let id:String
    public let rowID:String
    public let source:String
    public let subscriptionRef:String?
    public let duplicateTag:Int?
    public let isStable:Bool
    public var persistenceDisabledReason:SettingsText? {
        isStable ? nil:.init("can't be told apart until the account is verified","账号验证前无法区分")
    }
    public let row:RowsRow
    public let account:RowsAccount
    func name(english:Bool) -> String {
        let base=english ? row.name.en:row.name.zh
        guard let duplicateTag else { return base }
        return base + (english ? " · Account ":" · 账号 ") + String(duplicateTag)
    }
}

public struct EngineAccountMemberCatalogue:Sendable {
    public let members:[EngineAccountMember]
    /// Unexpected collisions of final keys remain withheld. Unbound same-source
    /// collisions instead get the explicitly session-only emitted-order key below.
    public let ambiguousKeys:Set<String>
    public let unstableKeys:Set<String>
    public let memberKeysByRow:[String:[String]]
    public init(rows:[RowsRow]) {
        let candidates=rows.flatMap { row -> [EngineAccountMember] in
            let unbound=Dictionary(grouping:row.accounts.filter{$0.subscriptionRef == nil},by:{$0.route.rawValue})
            var ordinals:[String:Int]=[:]
            return row.accounts.enumerated().map { index,account in
                let source=account.route.rawValue,base=row.id+"#"+source
                let unstable=account.subscriptionRef == nil && (unbound[source]?.count ?? 0) > 1
                let key:String
                if unstable {
                    let ordinal=(ordinals[source] ?? 0)+1
                    ordinals[source]=ordinal;key=base+"#"+String(ordinal)
                } else { key=account.subscriptionRef ?? base }
                return EngineAccountMember(id:key,rowID:row.id,source:source,subscriptionRef:account.subscriptionRef,
                    duplicateTag:row.accounts.count > 1 ? index+1:nil,isStable:!unstable,row:row,account:account)
            }
        }
        let grouped=Dictionary(grouping:candidates,by:\.id)
        memberKeysByRow=rows.reduce(into:[:]) { result,row in
            result[row.id]=candidates.filter{$0.rowID == row.id}.map(\.id)
        }
        ambiguousKeys=Set(grouped.filter{$0.value.count != 1}.keys)
        members=candidates.filter{grouped[$0.id]?.count == 1}
        unstableKeys=Set(members.filter{!$0.isStable}.map(\.id))
    }
    /// Recognize the declared temporary namespace even after a verified ref
    /// replaces that member, so old temporary choices cannot enter persistence.
    public func isUnstableKey(_ key:String) -> Bool {
        if unstableKeys.contains(key) { return true }
        guard let separator=key.lastIndex(of:"#"),key[..<separator].contains("#") else { return false }
        let suffix=String(key[key.index(after:separator)...])
        guard let ordinal=Int(suffix),ordinal > 0 else { return false }
        return String(ordinal) == suffix
    }
    /// Pure guard for the existing writer. Session choices must be held separately
    /// by that owner; this function never writes or promotes temporary keys.
    public func persistentPreferences(_ preferences:SettingsPreferences) -> SettingsPreferences {
        var result=preferences
        result.subscriptionSettings=result.subscriptionSettings.filter{!isUnstableKey($0.key)}
        result.subscriptions = .init(order:result.subscriptions.order.filter{!isUnstableKey($0)},
            hiddenIDs:result.subscriptions.hiddenIDs.filter{!isUnstableKey($0)})
        return result
    }
    /// Pure migration for the one shared Settings writer to commit. Explicit member choices win.
    /// Ambiguous row choices are dropped rather than copied to every member.
    public func migratingRowPreferences(_ preferences:SettingsPreferences) -> SettingsPreferences {
        var result=persistentPreferences(preferences)
        for (row,keys) in memberKeysByRow where !keys.contains(row) {
            let target=keys.count == 1 && members.contains(where:{$0.id == keys[0] && $0.isStable}) ? keys[0]:nil
            if let old=result.subscriptionSettings.removeValue(forKey:row),let target,result.subscriptionSettings[target] == nil {
                result.subscriptionSettings[target]=old
            }
            let hidden=result.subscriptions.hiddenIDs.remove(row) != nil
            if hidden,let target { result.subscriptions.hiddenIDs.insert(target) }
            let order=result.subscriptions.order.compactMap { $0 == row ? target:$0 }
            var seen=Set<String>()
            result.subscriptions = .init(order:order.filter{seen.insert($0).inserted},hiddenIDs:result.subscriptions.hiddenIDs)
        }
        return result
    }
}
