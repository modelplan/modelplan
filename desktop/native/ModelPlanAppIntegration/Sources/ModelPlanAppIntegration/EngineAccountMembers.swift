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
        isStable ? nil:.init("Unverified account — changes can't be saved yet","未验证账号，暂不能保存设置")
    }
    public let row:RowsRow
    public let account:RowsAccount
    /// D40 / DOCK-3.5-01: subscriptions that share a name keep it plain for the first one and
    /// add " · 2", " · 3" for the rest. A user alias replaces the number where the name is shown
    /// with its alias (the card header: `withDuplicateAlias`).
    func name(english:Bool) -> String {
        let base=english ? row.name.en:row.name.zh
        guard let duplicateTag, duplicateTag > 1 else { return base }
        return base + " · " + String(duplicateTag)
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
        let drafts=rows.flatMap { row -> [(key:String,source:String,unstable:Bool,row:RowsRow,account:RowsAccount)] in
            let unbound=Dictionary(grouping:row.accounts.filter{$0.subscriptionRef == nil},by:{$0.route.rawValue})
            var ordinals:[String:Int]=[:]
            return row.accounts.map { account in
                let source=account.route.rawValue,base=row.id+"#"+source
                let unstable=account.subscriptionRef == nil && (unbound[source]?.count ?? 0) > 1
                let key:String
                if unstable {
                    let ordinal=(ordinals[source] ?? 0)+1
                    ordinals[source]=ordinal;key=base+"#"+String(ordinal)
                } else { key=account.subscriptionRef ?? base }
                return (key,source,unstable,row,account)
            }
        }
        // D40: members that share a displayed name, within a row or across rows, are numbered
        // in delivery order; a unique name carries no tag.
        func nameKey(_ row:RowsRow) -> String { row.name.en+"\u{0}"+row.name.zh }
        let sharing=Dictionary(grouping:drafts,by:{nameKey($0.row)}).mapValues(\.count)
        var seen=[String:Int]()
        let candidates=drafts.map { draft -> EngineAccountMember in
            let name=nameKey(draft.row)
            seen[name,default:0]+=1
            return EngineAccountMember(id:draft.key,rowID:draft.row.id,source:draft.source,subscriptionRef:draft.account.subscriptionRef,
                duplicateTag:(sharing[name] ?? 0) > 1 ? seen[name]:nil,isStable:!draft.unstable,row:draft.row,account:draft.account)
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
